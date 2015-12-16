#include <TargetConditionals.h>
#import "AudioController.h"
#include <stdint.h>
#import <MediaPlayer/MediaPlayer.h>
#import "CAStreamBasicDescription.h"
#import <CoreAudio/CoreAudioTypes.h>

#include <iostream>
using std::cerr;
using std::endl;

//#define WARN_SKIPPED_BUFFERS 1
#define NUM_CHANNELS 2
#define MAX_BUFFER_LEN 1024
#define DEFAULT_INPUT_GAIN 0.4f

namespace {
#ifdef WARN_SKIPPED_BUFFERS
  const UInt32 EXPECTED_FRAME_COUNT = 512;
#endif

  bool print_error(OSStatus error, std::string message) {
    if (error == noErr)
      return false;
    cerr << message << ".  Error code: " << error << endl;
    return true;
  }
}

#pragma mark -Audio Session Property Listener

void chgListener(	void *                  inClientData,
                 AudioSessionPropertyID	inID,
                 UInt32                  inDataSize,
                 const void *            inData)
{

  if (inID == kAudioSessionProperty_AudioRouteChange)
  {
#if __has_feature(objc_arc)
    AudioController *THIS = (__bridge AudioController *)inClientData;
#else
    AudioController *THIS = (AudioController *)inClientData;
#endif
    [THIS routeChanged];
    bool connected = [THIS hasHeadphones];
    if (THIS->_config.measurement_mode)
      [THIS measurementMode:connected];

    THIS->_config.routeChange_callback(connected);
  }
}

// audio render procedure, don't allocate memory, don't take any locks, don't waste time
static OSStatus renderInputFloat(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData)
{
  // Perform some sanity checks
  if (*ioActionFlags != 0)
    printf("Unexpected action flags!\n");

#ifdef WARN_SKIPPED_BUFFERS
  static Float64 last_sample_time = 0.0f;
  if ((last_sample_time != 0.0f) && (inTimeStamp->mSampleTime - last_sample_time != EXPECTED_FRAME_COUNT))
  {
    printf("Skipped %f samples!\n", (inTimeStamp->mSampleTime - last_sample_time));
  }
  last_sample_time = inTimeStamp->mSampleTime;
#endif

#if __has_feature(objc_arc)
  AudioController *THIS = (__bridge AudioController *)inRefCon;
#else
  AudioController *THIS = (AudioController *)inRefCon;
#endif

  // Ask the mic input to render its audio
  if (THIS->_config.enable_input)
  {
    OSStatus err = AudioUnitRender(THIS->mOutput, ioActionFlags, inTimeStamp, 1, inNumberFrames, ioData);
    if (err)
    {
      printf("PerformThru: error %d\n", (int)err);
      if (THIS->_config.inputRenderError_callback)
        THIS->_config.inputRenderError_callback(err);
    }
  }
  float* input_buf = (float*)ioData->mBuffers[0].mData;

  if (THIS->_config.audio_callback)
    THIS->_config.audio_callback(inNumberFrames, &input_buf, THIS->_outputBuffer, THIS->_config.userdata);

  // Get a pointer to the dataBuffer of the AudioBufferList
  float *outA[2];
  for (int i = 0; i < NUM_CHANNELS; i++)
    outA[i] = (float *)ioData->mBuffers[i].mData;

  // Loop through the callback buffer, generating samples (this should be a memcopy now, or we should be feeding the passed in buffer down to the audio code y0)
  for (UInt32 i = 0; i < inNumberFrames; ++i) {
    for (UInt32 c = 0; c < NUM_CHANNELS; c++) {
      outA[c][i] = THIS->_outputBuffer[c][i];
    }
  }
  return noErr;
}

// audio render procedure, don't allocate memory, don't take any locks, don't waste time
static OSStatus renderInput(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData)
{
  // Perform some sanity checks
  if (*ioActionFlags != 0)
    printf("Unexpected action flags!\n");

#ifdef WARN_SKIPPED_BUFFERS
  static Float64 last_sample_time = 0.0f;
  if ((last_sample_time != 0.0f) && (inTimeStamp->mSampleTime - last_sample_time != EXPECTED_FRAME_COUNT))
  {
    printf("Skipped %f samples!\n", (inTimeStamp->mSampleTime - last_sample_time));
  }
  last_sample_time = inTimeStamp->mSampleTime;
#endif

#if __has_feature(objc_arc)
  AudioController *THIS = (__bridge AudioController *)inRefCon;
#else
  AudioController *THIS = (AudioController *)inRefCon;
#endif

  // Ask the mic input to render its audio
  if (THIS->_config.enable_input)
  {
    OSStatus err = AudioUnitRender(THIS->mOutput, ioActionFlags, inTimeStamp, 1, inNumberFrames, ioData);
    if (err)
    {
      printf("PerformThru: error %d\n", (int)err);
      if (THIS->_config.inputRenderError_callback)
        THIS->_config.inputRenderError_callback(err);
    }
  }
  float* input_buf = (float*)ioData->mBuffers[0].mData;

  if (THIS->_config.audio_callback)
    THIS->_config.audio_callback(inNumberFrames, &input_buf, THIS->_outputBuffer, THIS->_config.userdata);

  // Get a pointer to the dataBuffer of the AudioBufferList
  Fixed *outA[2];
  for (int i = 0; i < NUM_CHANNELS; i++)
    outA[i] = (Fixed*)ioData->mBuffers[i].mData;

  // Loop through the callback buffer, generating samples
  for (UInt32 i = 0; i < inNumberFrames; ++i) {
    for (UInt32 c = 0; c < NUM_CHANNELS; c++) {
      //XXX use accelerate vector multiply
      //2 ** 24 [8.24 fixed point] -1..1
      float mult = c == 0 ? 16777216.0 : 16777216.0 / 1.0;
      outA[c][i] = ((Fixed)(THIS->_outputBuffer[c][i] * mult));
    }
  }
  return noErr;
}

@interface AudioController () {
  bool _graphReady;
  float _inputGain;
}
@end

@implementation AudioController

@synthesize mOutput;

-(id) init {
  if ((self = [super init]))
  {
    _graphReady = false;
    _outputBuffer = new float*[NUM_CHANNELS];
    for (unsigned int i = 0; i < NUM_CHANNELS; i++)
      _outputBuffer[i] = new float[MAX_BUFFER_LEN];
    _inputGain = DEFAULT_INPUT_GAIN;
  }
  return self;
}

-(void) dealloc {
  DisposeAUGraph(mGraph);
#if !__has_feature(objc_arc)
  [super dealloc];
#endif
}

-(void)inputGain:(Float32)gain {
  _inputGain = gain;
  OSErr ret = AudioSessionSetProperty(kAudioSessionProperty_InputGainScalar, sizeof(gain), &gain);
  if (ret != noErr)
    cerr << "couldn't set input gain to: " << gain << endl;
}

- (void) volume:(Float32) value {
  MPMusicPlayerController * musicPlayer = [MPMusicPlayerController applicationMusicPlayer];
  musicPlayer.volume = value;
}

- (Float32) getVolume
{
  MPMusicPlayerController * musicPlayer = [MPMusicPlayerController applicationMusicPlayer];
  return musicPlayer.volume;
}

// Called by callback when audio route changes, usrs shouldn't call this.
- (void) routeChanged
{
  [self inputGain:_inputGain];
}

- (void) measurementMode:(bool)on
{
  UInt32 mode = on ? kAudioSessionMode_Measurement : kAudioSessionMode_Default;
  OSErr err = AudioSessionSetProperty(kAudioSessionProperty_Mode, sizeof(mode), &mode);
  if (err != noErr)
    printf("Couldn't set measurment mode to %s\n", on ? "on" : "off");
}

-(void)startAUGraph
{
  [self stopAUGraph];
  [self initGraph];
  if (!_graphReady)
    return;
 
  Boolean isRunning = false;
  AUGraphIsRunning(mGraph, &isRunning);
  if (isRunning)
    return;
  [self initGraph];
  OSStatus result = AUGraphStart(mGraph);
  if (result)
  {
    printf("AUGraphStart result %d %08X %4.4s", (int) result, (int) result,
           (char*) &result);
  }
}

-(void)stopAUGraph
{
  Boolean isRunning = false;
  AUGraphIsRunning(mGraph, &isRunning);
  if (isRunning)
  {
    AUGraphStop(mGraph);
    DisposeAUGraph(mGraph);
  }
}

- (Float64) sampleRate
{
  Float64 rate = 0;
  UInt32 size = sizeof(rate);
  OSStatus status = AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareSampleRate, &size, (void*) &rate);
  return status == noErr ? rate : 0;
}

-(void)initGraph
{
  OSStatus result = noErr;
  UInt32 size = 0;

  Float64 sampleRate = _config.sampleRate;
  if (sampleRate > 0)
    AudioSessionSetProperty(kAudioSessionProperty_PreferredHardwareSampleRate, sizeof(sampleRate), (void*) &sampleRate);

  result = NewAUGraph(&mGraph);
  print_error(result, "couldn't create new AU graph");

  AUNode outputNode;
  AUNode mixerNode;

  AudioComponentDescription mixer_desc;
  memset(&mixer_desc, 0, sizeof(AudioComponentDescription));
  mixer_desc.componentType = kAudioUnitType_Mixer;
  mixer_desc.componentSubType = kAudioUnitSubType_MultiChannelMixer;
  mixer_desc.componentManufacturer = kAudioUnitManufacturer_Apple;

  AudioComponentDescription output_desc;
  memset(&output_desc, 0, sizeof(AudioComponentDescription));
  output_desc.componentType = kAudioUnitType_Output;
#ifndef TARGET_OS_IPHONE
  output_desc.componentSubType = kAudioUnitSubType_DefaultOutput;
#else
  output_desc.componentSubType = kAudioUnitSubType_RemoteIO;
#endif
  output_desc.componentManufacturer = kAudioUnitManufacturer_Apple;

  result = AUGraphAddNode(mGraph, &output_desc, &outputNode);
  print_error(result, "couldn't add output node");
  result = AUGraphAddNode(mGraph, &mixer_desc, &mixerNode);
  print_error(result, "couldn't add mixer node");

  result = AUGraphConnectNodeInput(mGraph, mixerNode, 0, outputNode, 0);
  print_error(result, "couldn't connect mixer to output node");
  result = AUGraphOpen(mGraph);
  print_error(result, "couldn't open graph");

  result = AUGraphNodeInfo(mGraph, mixerNode, NULL, &mMixer);
  print_error(result, "AUGraphNodeInfo failed for mixer");

  result = AUGraphNodeInfo(mGraph, outputNode, NULL, &mOutput);
  print_error(result, "AUGraphNodeInfo failed for output");

  if (_config.enable_input)
  {
    UInt32 one = 1;
    result = AudioUnitSetProperty(mOutput, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &one, sizeof(one)); //, "couldn't enable input on the remote I/O unit");
    if (result != noErr)
      printf("error enabling input: %d\n", (int)result);
  }

  // Set up our mixer
  UInt32 numbuses = 1;
  size = sizeof(numbuses);
  result = AudioUnitSetProperty(mMixer, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, 0, &numbuses, size);
  print_error(result, "AudioUnitSetProperty failed for mixer element count");

  CAStreamBasicDescription desc;
  for (int i = 0; i < numbuses; i++)
  {
    result = AudioUnitSetParameter(mMixer, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, 0, 1.0, 0);
    print_error(result, "AudioUnitSetParameter failed for mixer volume");
    size = sizeof(desc);
    result = AudioUnitGetProperty(mMixer, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, i, &desc, &size);
    print_error(result, "AudioUnitGetProperty failed for mixer stream format");
    desc.mSampleRate = _config.sampleRate > 0 ? _config.sampleRate : [self sampleRate];
    desc.ChangeNumberChannels(2, false);
    result = AudioUnitSetProperty(mMixer, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, i, &desc, sizeof(desc));
    print_error(result, "AudioUnitSetProperty failed for mixer stream format");

    AURenderCallbackStruct renderCallbackStruct;

    renderCallbackStruct.inputProc = ((desc.mFormatFlags & kAudioFormatFlagIsFloat) ? &renderInputFloat : &renderInput);
    renderCallbackStruct.inputProcRefCon = (void*) CFBridgingRetain(self);
    result = AUGraphSetNodeInputCallback(mGraph, mixerNode, i, &renderCallbackStruct);
    print_error(result, "AUGraphSetNodeInputCallback failed");
  }
  result = AudioUnitGetProperty(mOutput, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &desc, &size);
  print_error(result, "AudioUnitGetProperty failed for output stream format");

  // Set up out output
  result = AudioUnitGetProperty(mMixer, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &desc, &size);
  print_error(result, "AudioUnitGetProperty failed for output stream format");

  desc.ChangeNumberChannels(NUM_CHANNELS, false);
  desc.mSampleRate = _config.sampleRate > 0 ? _config.sampleRate : [self sampleRate];
  result = AudioUnitSetProperty(mMixer, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &desc, size);
  print_error(result, "AudioUnitSetProperty failed for output stream format");
  result = AudioUnitSetParameter(mMixer, kMultiChannelMixerParam_Volume, kAudioUnitScope_Output, 0, 1.0, 0);
  print_error(result, "AudioUnitSetParameter failed for mixer volume");
  result = AUGraphInitialize(mGraph);
  print_error(result, "AUGraphInitialize failed");
//  CAShow(mGraph);

  //set default input gain
  [self inputGain:DEFAULT_INPUT_GAIN];
}

-(void)initializeAUGraph:(AudioConfig)config
{
  OSStatus result = noErr;

  _config = config;
#if (TARGET_IPHONE_SIMULATOR)
  _config.enable_input = false;
#endif

  result = AudioSessionInitialize(NULL, NULL, NULL, NULL);
  print_error(result, "couldn't initialize audio session");
  UInt32 cat = kAudioSessionCategory_PlayAndRecord;
  result = AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(cat), &cat);
  print_error(result, "couldn't set audio session property to play and record");

  if (config.measurement_mode) {
    UInt32 mode = kAudioSessionMode_Measurement;
    result = AudioSessionSetProperty(kAudioSessionProperty_Mode, sizeof(mode), &mode);
    print_error(result, "Couldn't set to measurment mode");
  }

  UInt32 override = TRUE;
  result = AudioSessionSetProperty(kAudioSessionProperty_OverrideCategoryDefaultToSpeaker, sizeof(override), &override);
  print_error(result, "couldn't override default routing to receiver instead of spaker");

  //set the io buffer duration
  Float32 duration_seconds = 0.010;
#ifdef DUMP_LATENCY
  result =
#endif
  AudioSessionSetProperty(kAudioSessionProperty_PreferredHardwareIOBufferDuration, sizeof(duration_seconds), &duration_seconds);

#ifdef DUMP_LATENCY
  UInt32 size = sizeof(duration_seconds);
  result = AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareIOBufferDuration, &size, &duration_seconds);
  if (!print_error(result, "couldn't get io buffer duration"))
    printf("Hardware io buffer duration %f seconds\n", duration_seconds);

  result = AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareInputLatency, &size, &duration_seconds);
  if (!print_error(result, "couldn't get input latency"))
    printf("Input latency %f seconds\n", duration_seconds);

  result = AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareOutputLatency, &size, &duration_seconds);
  if (!print_error(result, "couldn't get output latency"))
    printf("Output latency %f seconds\n", duration_seconds);
#endif

  if (_config.routeChange_callback)
  {
#if __has_feature(objc_arc)
    void* selfRef = (__bridge void *)self;
#else
    void* selfRef = (void*) self;
#endif
    result = AudioSessionAddPropertyListener(kAudioSessionProperty_AudioRouteChange, chgListener, selfRef);
    print_error(result, "couldn't add property listener");
    //init check
    chgListener(selfRef, kAudioSessionProperty_AudioRouteChange, 4, NULL);
  }

  [self initGraph];

  _graphReady = true;
}

- (bool) hasHeadphones
{
  CFStringRef route;
  UInt32 size = sizeof(CFStringRef);
  AudioSessionGetProperty(kAudioSessionProperty_AudioRoute, &size, &route);
  bool connected = true;
  if (route) //if there is no route, we say we're connected, is there something better to do?
    connected = CFStringCompare(route, CFSTR("HeadsetInOut"), NULL) == kCFCompareEqualTo;
  return connected;
}

@end
