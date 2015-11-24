//
//  ViewController.m
//  iOSBNIZ
//
//  Created by Brian Richardson on 11/11/15.
//  Copyright © 2015 bzztbomb.com. All rights reserved.
//

#import "ViewController.h"
#import <OpenGLES/ES2/glext.h>

#define IBNIZ_MAIN
#include "ibniz.h"

#define WIDTH 256

#define BUFFER_OFFSET(i) ((char *)NULL + (i))

void reset_start();
void checkmediaformats();

enum
{
  UNIFORM_PAGE,
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

@interface ViewController () {
  GLuint _program;
  
  GLuint _vertexArray;
  GLuint _vertexBuffer;
  
  GLuint _page;
  
  int _lastPage;
}

@property (strong, nonatomic) EAGLContext *context;
@property (weak, nonatomic) IBOutlet UILabel *debugLabel;

- (void)setupGL;
- (void)tearDownGL;

- (BOOL)loadShaders;
- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file;
- (BOOL)linkProgram:(GLuint)prog;
- (BOOL)validateProgram:(GLuint)prog;

@end

@implementation ViewController


- (void)viewDidLoad {
  [super viewDidLoad];

  self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
  
  if (!self.context) {
    NSLog(@"Failed to create ES context");
  }
  
  GLKView *view = (GLKView *)self.view;
  view.context = self.context;
  self.preferredFramesPerSecond = 60;
  [self setupGL];
  
  
  vm_init();
  vm_compile("");
//  vm_compile("ppp AADD.FFFF");
//  vm_compile("^/");
//  vm_compile("^xp");
//  vm_compile("ppp 1111.FFFF");
  vm_init();
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

- (IBAction)programChanged:(id)sender {
  UITextField* field = (UITextField*) sender;
  
  vm_compile([field.text UTF8String]);
  vm_init();
  reset_start();
}

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
  int runs = 0;
  while (vm.visiblepage == _lastPage && runs++ < 32) {
    vm_run();
    checkmediaformats();
  }
  if (vm.visiblepage == _lastPage)
    return;
  vm.specialcontextstep=3;
  

  self.debugLabel.text = vm.videomode?@"t":@"tyx";
  
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
  
  glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

@end

static CFTimeInterval start = 0;

void reset_start() {
  start = CACurrentMediaTime();
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
//    DEBUG(stderr,"audio stack underrun; shut it off!\n");
//    ui.audio_off=1;
    vm.spchange[1]=vm.wcount[1]=0;
//    pauseaudio(1);
  }
  
  if(vm.wcount[0]==0) return;
  
  // t-video in tyx-video mode produces 2 words extra per wcount
  if((vm.videomode==0) && (vm.spchange[0]-vm.wcount[0]*2==1))
  {
    vm.videomode=1;
//    DEBUG(stderr,"switched to t-video (sp changed by %d with %d w)\n",
//          vm.spchange[0],vm.wcount);
  }
  else if((vm.videomode==1) && (vm.spchange[0]+vm.wcount[0]*2==1))
  {
    vm.videomode=0;
//    DEBUG(stderr,"switched to tyx-video");
  }
  
  if((vm.videomode==1) && (vm.spchange[1]+vm.wcount[1]*2==1))
  {
//    DEBUG(stderr,"A<=>V detected!\n");
    switchmediacontext();
    vm.videomode=0;
    /* prevent loop */
    vm.spchange[0]=0; vm.wcount[0]=0;
    vm.spchange[1]=0; vm.wcount[1]=0;
  }
}