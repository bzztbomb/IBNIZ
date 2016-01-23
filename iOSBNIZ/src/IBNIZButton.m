//
//  IBNIZButton.m
//  iOSBNIZ
//
//  Created by Brian Richardson on 1/22/16.
//  Copyright © 2016 bzztbomb.com. All rights reserved.
//

#import "IBNIZButton.h"

@implementation IBNIZButton

-(id) initWithCoder:(NSCoder *)aDecoder {
  if (self = [super initWithCoder:aDecoder]) {
    [self commonInit];
  }
  return self;
}

-(id) initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    [self commonInit];
  }
  return self;
}

-(void) commonInit {
  self.titleLabel.font = [UIFont fontWithName:@"C64ProMono" size:20];
  self.layer.backgroundColor = [UIColor blackColor].CGColor;
  self.layer.borderColor = [UIColor whiteColor].CGColor;
  self.layer.borderWidth = 2;
}

@end
