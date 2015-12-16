//
//  AudioController.h
//  playbin
//
//  Created by Brian Richardson on 3/26/12.
//  Copyright 2012 Knowhere Studios Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

typedef void (*audiocallback_t)(unsigned int frames, float ** input_buffer, float ** output_buffer, void * user_data);
typedef void (*routeChangeCallback_t)(bool headphonesAndMic);
typedef void (*inputRenderError_t)(int err);

struct AudioConfig
{
  int sampleRate;
  audiocallback_t audio_callback;
  routeChangeCallback_t routeChange_callback;
  inputRenderError_t inputRenderError_callback;
  bool enable_input;
  bool measurement_mode;
  
  void* userdata;
  
  AudioConfig()
  {
    sampleRate = -1; // -1 is system default
    enable_input = true;
    audio_callback = NULL;
    routeChange_callback = NULL;
    userdata = NULL;
    measurement_mode = false;
    inputRenderError_callback = NULL;
  }
};

@interface AudioController : NSObject {
  @public
    AUGraph mGraph;
    AudioUnit mMixer;
    AudioUnit mOutput;

    AudioConfig _config;
    float ** _outputBuffer;
}

@property (nonatomic, assign)	AudioUnit mOutput;

- (void) initializeAUGraph:(AudioConfig)config;
- (void) startAUGraph;
- (void) stopAUGraph;
- (void) inputGain:(Float32)gain; //between 0 and 1
- (void) volume:(Float32)value; //between 0 and 1
- (Float32) getVolume;
// Called by callback when audio route changes, usrs shouldn't call this.
- (void) routeChanged;
- (void) measurementMode:(bool)on;
- (bool) hasHeadphones;
- (Float64) sampleRate;

void propListener(void * inClientData, AudioSessionPropertyID inID, UInt32 inDataSize, const void * inData);

@end
