//
//  ViewController.m
//  iOSBNIZ
//
//  Created by Brian Richardson on 11/11/15.

// TODO:
//  Launch screen / icon

#import "ViewController.h"
#import <OpenGLES/ES2/glext.h>
#import "AudioController.h"
#import "KeysIBNIZ.h"

extern "C" {
#define IBNIZ_MAIN
#include "ibniz.h"
#include "ios_texts.i"
}

#define WIDTH 256
#define PLAYBACKGAP 16

#define BUFFER_OFFSET(i) ((char *)NULL + (i))

void reset_start();
void checkmediaformats();
void scheduler_check();
int getticks();

enum
{
  UNIFORM_PAGE,
  UNIFORM_SCALE,
  UNIFORM_OFFSET,
  NUM_UNIFORMS
};
GLint uniforms[NUM_UNIFORMS];

// PosX,Y / texU,V
static const GLfloat squareVertices[] = {
  -1.0f, -1.0f,   0.0f, 1.0f,  // lower left
  1.0f, -1.0f,   1.0f, 1.0f,   // lower right
  -1.0f,  1.0f,  0.0f,  0.0f,  // upper left
  1.0f,  1.0f,   1.0f,  0.0f, // upper right
};

@interface ViewController () <UITableViewDataSource, UIAlertViewDelegate> {
  GLuint _program;

  GLuint _vertexArray;
  GLuint _vertexBuffer;

  GLuint _page;

  int _lastPage;

  AudioController* _audioController;

  NSTimer* _timer;
  CGSize _kbSize;
  NSArray<UIView *>* _views;
  int _currView;

  NSArray<NSString *>* _files;
  NSMutableArray<UIGestureRecognizer*>* _pans;
  KeysIBNIZ* _keys;
}

@property (strong, nonatomic) EAGLContext *context;
@property (weak, nonatomic) IBOutlet UITextView *programText;
@property (weak, nonatomic) IBOutlet UITextView *helpText;
@property (weak, nonatomic) IBOutlet UIView *loadSaveView;
@property (weak, nonatomic) IBOutlet UIView *blankView;
@property (weak, nonatomic) IBOutlet UITableView *filesTableView;

- (void)setupGL;
- (void)tearDownGL;

- (BOOL)loadShaders;
- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file;
- (BOOL)linkProgram:(GLuint)prog;
- (BOOL)validateProgram:(GLuint)prog;

@end

@implementation ViewController

void audio_callback(unsigned int frames, float ** input_buffer, float ** output_buffer, void * user_data);

- (void)viewDidLoad {
  [super viewDidLoad];

  [self becomeFirstResponder];

  _views = @[self.blankView, self.programText, self.helpText, self.loadSaveView];

  _pans = [[NSMutableArray alloc] init];
  for (UIView* v in _views) {
    v.hidden = YES;
    UITapGestureRecognizer* tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(restartTime:)];
    tap.numberOfTouchesRequired = 2;
    [v addGestureRecognizer:tap];
    UISwipeGestureRecognizer* swipeLeft = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeLeft:)];
    swipeLeft.direction = UISwipeGestureRecognizerDirectionLeft;
    [v addGestureRecognizer:swipeLeft];
    UISwipeGestureRecognizer* swipeRight = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeRight:)];
    swipeRight.direction = UISwipeGestureRecognizerDirectionRight;
    [v addGestureRecognizer:swipeRight];
    UIPanGestureRecognizer* panIt = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panning:)];
    panIt.enabled = NO;
    [v addGestureRecognizer:panIt];
    [_pans addObject:panIt];
  }
  _currView = 1;
  _views[_currView].hidden = NO;

  self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];

  if (!self.context) {
    NSLog(@"Failed to create ES context");
  }

  GLKView *view = (GLKView *)self.view;
  view.context = self.context;
  self.preferredFramesPerSecond = 60;
  [self setupGL];

  _audioController = [[AudioController alloc] init];
  AudioConfig config;
  config.sampleRate = 44100;
  config.enable_input = false;
  config.audio_callback = audio_callback;
  config.userdata = (void*) CFBridgingRetain(self);
  [_audioController initializeAUGraph:config];

  _timer = [NSTimer scheduledTimerWithTimeInterval:1.0f/60.0f target:self selector:@selector(timerFired:) userInfo:nil repeats:YES];

  // const char* start_program = "ppp AADD.FFFF";
  // const char* start_program = "^/";
  // const char* start_program = "^xp";
  // const char* start_program = "ppp 1111.FFFF";
  // const char* start_program = "d3r15&*";
//  const char* start_program = "ppp FFFF.FFFF";
  const char* start_program = "d3r15&*";
  self.programText.text = [NSString stringWithFormat:@"%s\n%s",welcometext, start_program];

  vm_init();
  vm_compile(start_program);
  vm_init();
  [_audioController startAUGraph];

  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWasShown:) name:UIKeyboardDidShowNotification object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillBeHidden:) name:UIKeyboardWillHideNotification object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(programChanged:)
                                               name:UITextViewTextDidChangeNotification
                                             object:nil];

  NSArray* shadows = @[self.programText, self.helpText];
  for (UITextView* view in shadows) {
    CALayer* layer = view.layer;
    layer.shadowColor = [[UIColor blackColor] CGColor];
    layer.shadowOffset = CGSizeMake(0.0f, 0.0f);
    layer.shadowOpacity = 1.0f;
    layer.shadowRadius = 2.0f;
  }
  _keys = [[KeysIBNIZ alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height / 4.0f)];
  _keys.textView = self.programText;
  ViewController* __weak weakSelf = self;
  _keys.changed = ^() {
    [weakSelf programChanged:nil];
  };
  _keys.resetTimeRequested = ^() {
    reset_start();
  };
  self.programText.inputView = _keys;
  self.programText.font = [UIFont fontWithName:@"C64ProMono" size:16];
  self.helpText.font = [UIFont fontWithName:@"C64ProMono" size:12];
  self.helpText.text = [NSString stringWithUTF8String:helpscreen];

  self.filesTableView.backgroundColor = [UIColor clearColor];
}

- (void) dealloc {
  [self tearDownGL];

  if ([EAGLContext currentContext] == self.context) {
    [EAGLContext setCurrentContext:nil];
  }
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];

  if ([self isViewLoaded] && ([[self view] window] == nil)) {
    self.view = nil;

    [self tearDownGL];

    if ([EAGLContext currentContext] == self.context) {
      [EAGLContext setCurrentContext:nil];
    }
    self.context = nil;
  }
}

- (BOOL)prefersStatusBarHidden {
  return YES;
}

- (void)timerFired:(NSTimer*)timer {
  checkmediaformats();
  scheduler_check();

  // Run until we have a new frame or 1/60 of a second has passed.  Seems to be ok, can improve later.
  uint32_t prevT = getticks();
  char old_page = vm.visiblepage;
  while (getticks() - prevT < (1000/70) && old_page == vm.visiblepage) {
    vm_run();
    checkmediaformats();
    scheduler_check();
  }
  [self update];
  vm.specialcontextstep=3;
}

- (void)programChanged:(NSNotification*)sender {
  NSString* str = self.programText.text;
  vm_compile([str UTF8String]);
  vm_init();
//  reset_start();
}

- (void) animateIt:(int) direction {
  if ((_currView == 0) && (direction == -1))
    return;
  if ((_currView == _views.count -1) && (direction == 1))
    return;

  UIView* currVisible = _views[_currView];
  UIView* newView = _views[_currView+direction];
  _currView += direction;

  CGFloat xOffset = self.view.frame.size.width;
  CGPoint newViewCenter = newView.center;
  newViewCenter.x += xOffset * direction;
  newView.center = newViewCenter;
  newViewCenter.x -= xOffset * direction;
  newView.alpha = 0.0;
  newView.hidden = NO;

  CGPoint currVisibleCenter = currVisible.center;
  CGPoint currVisibleOriginal = currVisibleCenter;
  currVisibleCenter.x -= xOffset * direction;

  [UIView animateWithDuration:0.3 animations:^{
    newView.center = newViewCenter;
    currVisible.center = currVisibleCenter;
    newView.alpha = 1.0f;
    currVisible.alpha = 0.0f;
  } completion:^(BOOL finished) {
    currVisible.hidden = YES;
    currVisible.center = currVisibleOriginal;
    if (_currView != 1)
      [self.programText resignFirstResponder];
    if (_currView == 3) {
      [self loadFiles];
      [self.filesTableView reloadData];
    }
  }];

}

- (void) restartTime:(id) sender {
  reset_start();
}

- (void) swipeLeft:(UISwipeGestureRecognizer*) recognizer {
  [self animateIt:1];
}

- (void) swipeRight:(UISwipeGestureRecognizer*) recognizer {
  [self animateIt:-1];
}

- (void) panning:(UIPanGestureRecognizer*) recognizer {
  CGPoint coord = [recognizer locationInView:recognizer.view];
  CGSize sz = recognizer.view.frame.size;
  coord.x = (coord.x / sz.width) * 255;
  coord.y = (coord.y / sz.height) * 255;
  uint32_t x = ((uint32_t) coord.x) << 8;
  uint32_t y = ((uint32_t) coord.y);
  vm.userinput = y | x;
}

- (BOOL) canBecomeFirstResponder {
  return YES;
}

- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event {
  if (motion == UIEventSubtypeMotionShake)
  {
    for (UIGestureRecognizer* gesture in _pans)
      gesture.enabled = !gesture.enabled;
  }
}

#pragma mark - File load/save
- (NSString*) documentDir {
  NSArray *myPathList =  NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  NSString* docPath = [myPathList objectAtIndex:0];
  return docPath;
}

- (void) loadFiles {
  _files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[self documentDir] error:nil];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  if (!_files)
    [self loadFiles];
  return _files.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"BasicTableCell"];
  cell.layer.backgroundColor = [UIColor blackColor].CGColor;
  cell.layer.borderColor = [UIColor whiteColor].CGColor;
  cell.layer.borderWidth = 2;
  cell.textLabel.font = [UIFont fontWithName:@"C64ProMono" size:16];
  cell.textLabel.text = [_files objectAtIndex:indexPath.row];
  return cell;
}

- (IBAction)loadHit:(id)sender {
  NSIndexPath* path = [self.filesTableView indexPathForSelectedRow];
  if (path.row >= _files.count)
    return;
  NSString* name = [NSString stringWithFormat:@"%@/%@", [self documentDir], [_files objectAtIndex:path.row]];
  self.programText.text = [NSString stringWithContentsOfFile:name encoding:NSUTF8StringEncoding error:nil];
  [self programChanged:nil];
  [self animateIt:-2];
}

- (IBAction)saveHit:(id)sender {
  UIAlertView* view = [[UIAlertView alloc] initWithTitle:@"Filename"
                                                 message:@"Enter filename"
                                                delegate:self
                                       cancelButtonTitle:@"Cancel"
                                       otherButtonTitles:@"OK", nil];
  view.alertViewStyle = UIAlertViewStylePlainTextInput;
  [view show];
}

//UIAlertViewDelegate
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
  //okay
  if (buttonIndex != 1)
    return;
  NSString* name = [NSString stringWithFormat:@"%@/%@", [self documentDir], [[alertView textFieldAtIndex:0] text]];
  NSString* data = self.programText.text;
  [data writeToFile:name atomically:NO encoding:NSUTF8StringEncoding error:nil];
  [self loadFiles];
  [self.filesTableView reloadData];
}


#pragma mark - GL
- (void)setupGL
{
  [EAGLContext setCurrentContext:self.context];

  [self loadShaders];

  glGenVertexArraysOES(1, &_vertexArray);
  glBindVertexArrayOES(_vertexArray);

  glGenBuffers(1, &_vertexBuffer);
  glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
  glBufferData(GL_ARRAY_BUFFER, sizeof(squareVertices), squareVertices, GL_STATIC_DRAW);

  glEnableVertexAttribArray(GLKVertexAttribPosition);
  glVertexAttribPointer(GLKVertexAttribPosition, 2, GL_FLOAT, GL_FALSE, 16, BUFFER_OFFSET(0));
  glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
  glVertexAttribPointer(GLKVertexAttribTexCoord0, 2, GL_FLOAT, GL_FALSE, 16, BUFFER_OFFSET(8));

  glBindVertexArrayOES(0);

  glGenTextures(1, &_page);
  glBindTexture(GL_TEXTURE_2D, _page);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
}

- (void)tearDownGL
{
  [EAGLContext setCurrentContext:self.context];

  glDeleteBuffers(1, &_vertexBuffer);
  glDeleteVertexArraysOES(1, &_vertexArray);

  if (_program) {
    glDeleteProgram(_program);
    _program = 0;
  }
}

#pragma mark -  OpenGL ES 2 shader compilation

- (BOOL)loadShaders
{
  GLuint vertShader, fragShader;
  NSString *vertShaderPathname, *fragShaderPathname;

  // Create shader program.
  _program = glCreateProgram();

  // Create and compile vertex shader.
  vertShaderPathname = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"vsh"];
  if (![self compileShader:&vertShader type:GL_VERTEX_SHADER file:vertShaderPathname]) {
    NSLog(@"Failed to compile vertex shader");
    return NO;
  }

  // Create and compile fragment shader.
  fragShaderPathname = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"fsh"];
  if (![self compileShader:&fragShader type:GL_FRAGMENT_SHADER file:fragShaderPathname]) {
    NSLog(@"Failed to compile fragment shader");
    return NO;
  }

  // Attach vertex shader to program.
  glAttachShader(_program, vertShader);

  // Attach fragment shader to program.
  glAttachShader(_program, fragShader);

  // Bind attribute locations.
  // This needs to be done prior to linking.
  glBindAttribLocation(_program, GLKVertexAttribPosition, "position");
  glBindAttribLocation(_program, GLKVertexAttribTexCoord0, "texCoord");

  // Link program.
  if (![self linkProgram:_program]) {
    NSLog(@"Failed to link program: %d", _program);

    if (vertShader) {
      glDeleteShader(vertShader);
      vertShader = 0;
    }
    if (fragShader) {
      glDeleteShader(fragShader);
      fragShader = 0;
    }
    if (_program) {
      glDeleteProgram(_program);
      _program = 0;
    }

    return NO;
  }

  // Get uniform locations.
  uniforms[UNIFORM_PAGE] = glGetUniformLocation(_program, "page");
  uniforms[UNIFORM_SCALE] = glGetUniformLocation(_program, "scale");
  uniforms[UNIFORM_OFFSET] = glGetUniformLocation(_program, "offset");

  // Release vertex and fragment shaders.
  if (vertShader) {
    glDetachShader(_program, vertShader);
    glDeleteShader(vertShader);
  }
  if (fragShader) {
    glDetachShader(_program, fragShader);
    glDeleteShader(fragShader);
  }

  return YES;
}

- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file
{
  GLint status;
  const GLchar *source;

  source = (GLchar *)[[NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil] UTF8String];
  if (!source) {
    NSLog(@"Failed to load vertex shader");
    return NO;
  }

  *shader = glCreateShader(type);
  glShaderSource(*shader, 1, &source, NULL);
  glCompileShader(*shader);

#if defined(DEBUG)
  GLint logLength;
  glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
  if (logLength > 0) {
    GLchar *log = (GLchar *)malloc(logLength);
    glGetShaderInfoLog(*shader, logLength, &logLength, log);
    NSLog(@"Shader compile log:\n%s", log);
    free(log);
  }
#endif

  glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
  if (status == 0) {
    glDeleteShader(*shader);
    return NO;
  }

  return YES;
}

- (BOOL)linkProgram:(GLuint)prog
{
  GLint status;
  glLinkProgram(prog);

#if defined(DEBUG)
  GLint logLength;
  glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
  if (logLength > 0) {
    GLchar *log = (GLchar *)malloc(logLength);
    glGetProgramInfoLog(prog, logLength, &logLength, log);
    NSLog(@"Program link log:\n%s", log);
    free(log);
  }
#endif

  glGetProgramiv(prog, GL_LINK_STATUS, &status);
  if (status == 0) {
    return NO;
  }

  return YES;
}

- (BOOL)validateProgram:(GLuint)prog
{
  GLint logLength, status;

  glValidateProgram(prog);
  glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
  if (logLength > 0) {
    GLchar *log = (GLchar *)malloc(logLength);
    glGetProgramInfoLog(prog, logLength, &logLength, log);
    NSLog(@"Program validate log:\n%s", log);
    free(log);
  }

  glGetProgramiv(prog, GL_VALIDATE_STATUS, &status);
  if (status == 0) {
    return NO;
  }

  return YES;
}

#pragma - mark mainloop
- (void) update {
  if (vm.visiblepage == _lastPage)
    return;

  _keys.mode = vm.videomode?@"t":@"tyx";
  _keys.time = [NSString stringWithFormat:@"%04X", gettimevalue()&0xFFFF];

  _lastPage = vm.visiblepage;

  uint32_t*s=(uint32_t*) vm.mem+0xE0000+(vm.visiblepage<<16);
  glBindTexture(GL_TEXTURE_2D, _page);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, WIDTH, WIDTH, 0, GL_RGBA, GL_UNSIGNED_BYTE, s);
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
  glClearColor(0.05f, 0.05f, 0.05f, 1.0f);
  glClear(GL_COLOR_BUFFER_BIT);

  glBindVertexArrayOES(_vertexArray);
  glUseProgram(_program);

  glActiveTexture(GL_TEXTURE0);
  glBindTexture(GL_TEXTURE_2D, _page);

  glUniform1i(uniforms[UNIFORM_PAGE], 0);

  // Scale/offset so that we are square, and we avoid the keyboard
  CGSize sz = self.view.frame.size;
  sz.height -= _kbSize.height;
  GLfloat xScale = sz.width < sz.height ? 1.0 : sz.height / sz.width;
  GLfloat yScale = sz.height < sz.width ? 1.0 : sz.width / sz.height;
  yScale *= sz.height / self.view.frame.size.height;

  glUniform2f(uniforms[UNIFORM_SCALE], xScale, yScale);

  GLfloat yOffset = _kbSize.height > 0 ? 1.0 - yScale : 0.0;
  glUniform2f(uniforms[UNIFORM_OFFSET], 0, yOffset);

  glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

- (void)keyboardWasShown:(NSNotification*)notification {
  NSDictionary* info = [notification userInfo];
  CGRect r = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
  r = [self.view convertRect:r fromView:self.view.window];
  _kbSize.height = self.view.frame.size.height - r.origin.y;
}

-(void)keyboardWillBeHidden:(NSNotification*)notification {
  _kbSize = CGSizeMake(0, 0);
}

@end

static CFTimeInterval start = 0;
static uint32_t auplayptr = 0;
static uint32_t auplaytime = 0;
static volatile int in_audio = 0;

void reset_start() {
  for (; in_audio; ) {} // try an wait for the buffer to get played
  start = CACurrentMediaTime();
  auplayptr = auplaytime = 0;
  vm.videotime = 0;
  vm.audiotime = 0;
  vm.prevsp[1] = 0;
}

int getticks()
{
  if (start == 0)
    reset_start();
  return (CACurrentMediaTime() - start) * 1000.0f;
}

uint32_t getcorrectedticks()
{
//  uint32_t t;
//  if(ui.runstat==1) t=getticks()-ui.timercorr;
//  else t=ui.paused_since-ui.timercorr;
//  return t;
  return getticks();
}

uint32_t gettimevalue()
{
  uint32_t t=getcorrectedticks();
  return (t*3)/50; // milliseconds to 60Hz-frames
}

void waitfortimechange()
{
  // TODO: Implement!
}

void checkmediaformats()
{
  if(vm.wcount[1]!=0 && vm.spchange[1]<=0)
  {
    NSLog(@"audio stack underrun; shut it off!\n");
//    ui.audio_off=1;
    vm.spchange[1]=vm.wcount[1]=0;
//    pauseaudio(1);
  }

  if(vm.wcount[0]==0) return;

  // t-video in tyx-video mode produces 2 words extra per wcount
  if((vm.videomode==0) && (vm.spchange[0]-vm.wcount[0]*2==1))
  {
    vm.videomode=1;
    NSLog(@"switched to t-video (sp changed by %d with %d w)\n",
          vm.spchange[0],vm.wcount[0]);
  }
  else if((vm.videomode==1) && (vm.spchange[0]+vm.wcount[0]*2==1))
  {
    vm.videomode=0;
   NSLog(@"switched to tyx-video");
  }

  if((vm.videomode==1) && (vm.spchange[1]+vm.wcount[1]*2==1))
  {
   NSLog(@"A<=>V detected!\n");
    switchmediacontext();
    vm.videomode=0;
    /* prevent loop */
    vm.spchange[0]=0; vm.wcount[0]=0;
    vm.spchange[1]=0; vm.wcount[1]=0;
  }
}

/*** scheduling logic (not really that ui_sdl-specific) ***/

void scheduler_check()
{
  /*
   audiotime incs by 1 per frametick
   auplaytime incs by 1<<16 per frametick
   auplayptr incs by 1<<32 per 1<<22-inc of auplaytime
   */
  uint32_t playback_at = auplaytime+(auplayptr>>10);
  uint32_t auwriter_at = vm.audiotime*65536+vm.prevsp[1]*64;

  if((vm.prevsp[1]>0) && playback_at>auwriter_at)
  {
   NSLog(@"%x > %x! (sp %x & %x) jumping forward\n",playback_at,auwriter_at,
         vm.sp,vm.cosp);
    vm.audiotime=((auplaytime>>16)&~63)+64;
    vm.preferredmediacontext=1;
  }
  else if(playback_at+PLAYBACKGAP*0x10000>auwriter_at)
    vm.preferredmediacontext=1;
  else
    vm.preferredmediacontext=0;
}

void audio_callback(unsigned int frames, float ** input_buffer, float ** output_buffer, void * user_data) {
  in_audio = 1;
  uint32_t aupp0=auplayptr;
  for(int i = 0; i < frames; i++)
  {
    int16_t ival = (vm.mem[0xd0000+((auplayptr>>16)&0xffff)]+0x8000);
    float val = (float) ival / (float) INT16_MAX;
//    val *= 0.0f;
    output_buffer[0][i] = val;
    output_buffer[1][i] = val;
    auplayptr+=0x164A9; /* (61440<<16)/44100 */
    // todo later: some interpolation/filtering
  }
  if(aupp0>auplayptr)
  {
    auplaytime+=64*65536;
  }
  in_audio = 0;
}

