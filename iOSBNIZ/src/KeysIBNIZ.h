//
//  KeysIBNIZ.h
//  iOSBNIZ
//
//  Created by Brian Richardson on 1/10/16.
//  Copyright © 2016 bzztbomb.com. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface KeysIBNIZ : UIView

@property (weak, nonatomic) UITextView* textView;
@property (nonatomic, copy) void (^changed)();
@property (assign, nonatomic) NSString* mode;
@property (assign, nonatomic) NSString* time;
@property (assign, nonatomic) NSString* debugString;
@property (nonatomic, copy) void (^resetTimeRequested)();

@end
