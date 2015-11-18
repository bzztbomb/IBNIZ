//
//  ViewController.m
//  iOSBNIZ
//
//  Created by Brian Richardson on 11/11/15.
//  Copyright © 2015 bzztbomb.com. All rights reserved.
//

#import "ViewController.h"

#define IBNIZ_MAIN
#include "ibniz.h"

#define WIDTH 256

@interface ViewController () {
  uint8_t rgb[WIDTH*WIDTH*4];
  int lastFrame;
}

@property (weak, nonatomic) IBOutlet UIImageView *displayImage;

@end

@implementation ViewController


- (void)viewDidLoad {
  [super viewDidLoad];
  
  vm_init();
//  vm_compile("ppp AADD.FFFF");
  vm_compile("^/");
//  vm_compile("ppp 1111.FFFF");
  vm_init();
  
  [NSTimer scheduledTimerWithTimeInterval:1.0f/160.0f target:self selector:@selector(frame:) userInfo:nil repeats:YES];
}

uint8_t clamp(int val) {
  if (val <= 0)
    return 0;
  if (val >= 255)
    return 255;
  return (uint8_t) val;
}

- (void) uploadFrame {
  int x,y;
  if (vm.visiblepage == lastFrame)
    return;
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

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

- (void) frame:(NSTimer*) timer {
  vm_run();
  [self uploadFrame];
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

