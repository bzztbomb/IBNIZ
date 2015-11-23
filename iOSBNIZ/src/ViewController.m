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

enum
{
  UNIFORM_FRAME,
  NUM_UNIFORMS
};
GLint uniforms[NUM_UNIFORMS];

// PosX,Y / texU,V
static const GLfloat squareVertices[] = {
  -1.0f, -1.0f,   1.0f, 1.0f,
  1.0f, -1.0f,   1.0f, 0.0f,
  -1.0f,  1.0f,  0.0f,  1.0f,
  1.0f,  1.0f,   0.0f,  0.0f,
};

@interface ViewController () {
  GLuint _program;
  
  GLKMatrix4 _modelViewProjectionMatrix;
  GLKMatrix3 _normalMatrix;
  float _rotation;
  
  GLuint _vertexArray;
  GLuint _vertexBuffer;
  
  GLuint _frame;
  
  uint8_t rgb[WIDTH*WIDTH*4];
  int lastFrame;
}

@property (strong, nonatomic) EAGLContext *context;
@property (strong, nonatomic) GLKBaseEffect *effect;

@property (weak, nonatomic) IBOutlet UIImageView *displayImage;

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
  
  [self setupGL];
  
  
  vm_init();
//  vm_compile("ppp AADD.FFFF");
  vm_compile("^/");
//  vm_compile("ppp 1111.FFFF");
  vm_init();
  
//  [NSTimer scheduledTimerWithTimeInterval:1.0f/160.0f target:self selector:@selector(frame:) userInfo:nil repeats:YES];
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
  
  // Dispose of any resources that can be recreated.
}

- (BOOL)prefersStatusBarHidden {
  return YES;
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
  
  glGenTextures(1, &_frame);
  glBindTexture(GL_TEXTURE_2D, _frame);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
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
  uniforms[UNIFORM_FRAME] = glGetUniformLocation(_program, "frame");
  
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
  while (![self updateRGB])
    vm_run();

  glBindTexture(GL_TEXTURE_2D, _frame);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, WIDTH, WIDTH, 0, GL_RGBA, GL_UNSIGNED_BYTE, rgb);
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
  glClearColor(0.05f, 0.05f, 0.05f, 1.0f);
  glClear(GL_COLOR_BUFFER_BIT);
  
  glBindVertexArrayOES(_vertexArray);
  glUseProgram(_program);

  glActiveTexture(GL_TEXTURE0);
  glBindTexture(GL_TEXTURE_2D, _frame);
  glUniform1i(uniforms[UNIFORM_FRAME], 0);
  
  glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}


#pragma - mark ibniz
uint8_t clamp(int val) {
  if (val <= 0)
    return 0;
  if (val >= 255)
    return 255;
  return (uint8_t) val;
}

- (BOOL) updateRGB {
  int x,y;
  if (vm.visiblepage == lastFrame)
    return NO;
  lastFrame = vm.visiblepage;
  uint32_t*s=(uint32_t*) vm.mem+0xE0000+(vm.visiblepage<<16);
  
  // Source format:  32bit->VVUU.YYYY, VV and UU are signed
  uint8_t* target = rgb;
  for (y=0; y < 256; y++) {
    for (x=0; x < 256; x++) {
      uint32_t a = s[0];
      s++;
      int8_t iv = (a & 0xff000000) >> 24;
      int8_t iu = (a & 0x00ff0000) >> 16;
      uint16_t iy = (a & 0x0000ffff); // yuv->rgb wants 0..255, will revisit
      
      // AADD.FFFF from screenshot -> 139, 254, 195
      // this code.. -> 141, 362, 208, close.. need to revisit
      float y = iy / 65535.0f;
      float u = iu / 255.0f;
      float v = iv / 255.0f;
      
      y=1.1643*(y-0.0625);
      
      float r=y+1.5958*v;
      float g=y-0.39173*u-0.81290*v;
      float b=y+2.017*u;
      
      r *= 255.0f;
      g *= 255.0f;
      b *= 255.0f;
      
      *target++ = clamp(r);
      *target++ = clamp(g);
      *target++ = clamp(b);
      *target++ = 0xFF;
    }
  }
  return YES;
}

- (void) uploadFrame {
  if (![self updateRGB])
    return;
  
  CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, rgb, WIDTH*WIDTH*4, NULL);
  //a reasonable guess
  CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
  int bitsPerComponent = 8;
  int bitsPerPixel = 32;
  int bytesPerRow = 4 * WIDTH;
  
  CGImageRef imageRef = CGImageCreate(WIDTH, WIDTH, bitsPerComponent, bitsPerPixel, bytesPerRow, colorSpaceRef, kCGBitmapByteOrderDefault, provider, NULL, NO, kCGRenderingIntentDefault);
  self.displayImage.image = [UIImage imageWithCGImage:imageRef];
  CGImageRelease(imageRef);
  CGDataProviderRelease(provider);
}

- (void) frame:(NSTimer*) timer {
  vm_run();
//  [self uploadFrame];
}

@end

int getticks()
{
  static CFTimeInterval start = 0;
  if (start == 0)
    start = CACurrentMediaTime();
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

