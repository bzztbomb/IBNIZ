//
//  KeysIBNIZ.m
//  iOSBNIZ
//
//  Created by Brian Richardson on 1/10/16.
//  Copyright © 2016 bzztbomb.com. All rights reserved.
//

#import "IBNIZButton.h"
#import "KeysIBNIZ.h"

struct opcode_t {
  const char *symbol;
  const char *name;
  const char *description;
};

char NEWLINE = 0xFF;
char BLANK_SPACE = 0xFE;
char TOGGLE_COLOR = 0xFD;

struct opcode_t opcodes[] = {
    // Immediates
    {"0", "loadimm", "(-- val)"},
    {"1", "loadimm", "(-- val)"},
    {"2", "loadimm", "(-- val)"},
    {"3", "loadimm", "(-- val)"},
    {"4", "loadimm", "(-- val)"},
    {"5", "loadimm", "(-- val)"},
    {"6", "loadimm", "(-- val)"},
    {"7", "loadimm", "(-- val)"},
    {"8", "loadimm", "(-- val)"},
    {"9", "loadimm", "(-- val)"},
    {"A", "loadimm", "(-- val)"},
    {"B", "loadimm", "(-- val)"},
    {"C", "loadimm", "(-- val)"},
    {"D", "loadimm", "(-- val)"},
    {"E", "loadimm", "(-- val)"},
    {"F", "loadimm", "(-- val)"},
    {".", "loadimm", "(-- val)"},
    {",", "separator", ""},
    {&BLANK_SPACE, "", ""},
    {"\\", "comment", "ignore characters in source code until newline"},
    // ARITHMETIC
    {&TOGGLE_COLOR, "", ""},
    {"+", "add", "(a b -- a+b)"},
    {"-", "sub", "(a b -- a-b)"},
    {"*", "mul", "(a b -- a*b)"},
    {"/", "div", "(a b -- a/b, 0 if b==0)"},
    {"%", "mod", "(a b -- a MOD b, 0 if b==0)"},
    {"q", "sqrt", "(a -- square root of a; 0 if a<0)"},
    {"&", "and", "(a b -- a AND b)"},
    {"|", "or", "(a b -- a OR b)"},
    {"^", "xor", "(a b -- a XOR b)"},
    {"r", "right", "(a b -- a ROR b)"},
    {"l", "left", "(a b -- a << b)"},
    {"~", "neg", "(a -- NOT a)"},
    {&NEWLINE, "", ""},
    {"s", "sin", "(a -- sin(a*2PI))"},
    {"a", "atan", "(a b -- atan2(a,b)/2PI)"},
    {"<", "isneg", "(a -- a if a<0, else 0)"},
    {">", "ispos", "(a -- a if a>0, else 0)"},
    {"=", "iszero", "(a -- 1 if a==0, else 0)"},
    {&TOGGLE_COLOR, "", ""},
    // STACK MANIPULATION
    {"d", "dup", "(a -- a a)"},
    {"p", "pop", "(a --)           same as Forth's DROP"},
    {"x", "exchange", "(a b -- b a)     same as Forth's SWAP"},
    {"v", "trirot", "(a b c -- b c a) same as Forth's ROT"},
    {")", "pick", "(i -- val)       load value from STACK[top-1-i]"},
    {"(", "bury", "(val i --)       store value to STACK[top-2-i]"},
    {&TOGGLE_COLOR, "", ""},
    // EXTERIOR LOOP
    {"M", "mediaswitch", "switches between audio and video context"},
    {"w", "whereami", "pushes exterior loop variable(s) on stack"},
    {"T", "terminate", "stops program execution"},
    {&TOGGLE_COLOR, "", ""},
    // MEMORY MANIPULATION
    {"@", "load", "(addr -- val)"},
    {"!", "store", "(val addr --)"},
    {&TOGGLE_COLOR, "", ""},
    // CONDITIONALS
    {"?", "if", "(cond --) ; if cond==0, skip until 'else' or 'endif'"},
    {":", "else", "skip until after next 'endif'"},
    {";", "endif", "nop; marks end of conditional block when skipping"},
    {&TOGGLE_COLOR, "", ""},
    // LOOPS
    {"X", "times", "(i0 --) loop i0 times (push i0 and insptr on rstack)"},
    {"L", "loop", "        decrement RSTACK[top-1], jump back if non-0"},
    {"i", "index", "(-- i)  load value from RSTACK[top-1]"},
    {"j", "outdex", "(-- j)  load value from RSTACK[top-3]"},
    {"[", "do", "        begin loop (push insptr on rstack)"},
    {"]", "while", "(cond --) jump back if cond!=0"},
    {"J", "jump", "(v --)  set instruction pointer to value v"},
    {&TOGGLE_COLOR, "", ""},
    // SUBROUTINES
    {"{", "defsub", "(i --)  define subroutine (store pointer to MEM[i])"},
    {"}", "return", "        end of subroutine; pop insptr from rstack"},
    {"V", "visit", "(i --)  visit subroutine pointed to by MEM[i]"},
    {&TOGGLE_COLOR, "", ""},
    // RETURN STACK MANIP
    {"R", "retaddr", "(-- val)   (val --)     moves from rstack to stack"},
    {"P", "pushtors", "(val --)  (-- val)     moves from stack to rstack"},
    {&TOGGLE_COLOR, "", ""},
    // USER INPUT
    {"U", "userin", "(-- inword)     get data from input device"},
    {&TOGGLE_COLOR, "", ""},
    {&NEWLINE, "", ""},
    // DATA SEGMENT
    {"G", "getdata", "(numbits -- data)"},
    {"$", "startdata", "end code segment, start data segment"},
    {"b", "binary", "sets digit length to 1 bit"},
    {"q", "quarternary", "sets digit length to 2 bits"},
    {"o", "octal", "sets digit length to 3 bits"},
    {"h", "hexadecimal", "sets digit length to 4 bits (default)"},
    {nullptr, "", ""}};

@interface KeysIBNIZ () <UITextViewDelegate> {
  NSArray<UIView *> *_commonKeys;
  UIScrollView *_scroll;
  UIView *_accessoryView; // for keyboard toggle
  bool _ibnizKeyboard;
  UILabel *_helpLabel;
  NSTimer *_helpTimer;
  UILabel *_modeLabel;
  IBNIZButton *_timeButton;
  UILabel *_debugLabel;
}

@end

@implementation KeysIBNIZ

- (id)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    self.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1.0];
    CGRect r = frame;
    r.origin = CGPointMake(0, 0);
    _scroll = [[UIScrollView alloc] initWithFrame:r];
    _scroll.pagingEnabled = YES;
    CGSize sz = frame.size;
    sz.height *= 3;
    _scroll.contentSize = sz;
    [self addSubview:_scroll];
    [self createKeys];
    [self createAccessoryView];
    _ibnizKeyboard = true;
    _helpLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 300, 60)];
    _helpLabel.lineBreakMode = NSLineBreakByWordWrapping;
    _helpLabel.numberOfLines = 0;
    _helpLabel.textColor = [UIColor colorWithWhite:1.0 alpha:1.0];
    _helpLabel.backgroundColor =
        [UIColor colorWithRed:0.3 green:0.3 blue:0.3 alpha:1.0];
    _helpLabel.hidden = YES;
    [self addSubview:_helpLabel];
  }
  return self;
}

// 3x10 keys,
// backspace, change kb, val up, val down

- (void)createKeys {
  bool lightColor = false;
  for (int i = 0; opcodes[i].symbol != nullptr; i++) {
    if (opcodes[i].symbol == &TOGGLE_COLOR) {
      lightColor = !lightColor;
      continue;
    }
    CGRect buttonRect = CGRectMake(0, 0, 10, 10);
    IBNIZButton *btn = [[IBNIZButton alloc] initWithFrame:buttonRect];
    btn.lightColor = lightColor;
    if (opcodes[i].symbol != &NEWLINE && opcodes[i].symbol != &BLANK_SPACE) {
      [btn setTitle:[NSString stringWithUTF8String:opcodes[i].symbol]
           forState:UIControlStateNormal];
      [btn addTarget:self
                    action:@selector(buttonHit:)
          forControlEvents:UIControlEventTouchUpInside];
      [btn addTarget:self
                    action:@selector(buttonDown:)
          forControlEvents:UIControlEventTouchDown];
      [btn addTarget:self
                    action:@selector(hideHelp:)
          forControlEvents:UIControlEventTouchUpOutside];
    } else {
      btn.hidden = YES; // CHEESE!
    }
    btn.tag = i;
    [_scroll addSubview:btn];
  }

  CGRect buttonRect = CGRectMake(0, 0, 10, 10);
  _timeButton = [[IBNIZButton alloc] initWithFrame:buttonRect];
  _timeButton.titleLabel.font = [UIFont fontWithName:@"C64ProMono" size:10];
  [_timeButton addTarget:self
                  action:@selector(resetTimeHit:)
        forControlEvents:UIControlEventTouchUpInside];
  [self addSubview:_timeButton];

  //
  IBNIZButton *spaceBtn = [[IBNIZButton alloc] initWithFrame:buttonRect];
  [spaceBtn setTitle:@" " forState:UIControlStateNormal];
  [spaceBtn addTarget:self
                action:@selector(buttonHit:)
      forControlEvents:UIControlEventTouchUpInside];
  IBNIZButton *backspaceBtn = [[IBNIZButton alloc] initWithFrame:buttonRect];
  [backspaceBtn setTitle:@"<-" forState:UIControlStateNormal];
  [backspaceBtn addTarget:self
                   action:@selector(backspace:)
         forControlEvents:UIControlEventTouchUpInside];
  IBNIZButton *enterBtn = [[IBNIZButton alloc] initWithFrame:buttonRect];
  if ([[UIDevice currentDevice] userInterfaceIdiom] ==
      UIUserInterfaceIdiomPhone)
    enterBtn.titleLabel.font = [UIFont fontWithName:@"C64ProMono" size:10];
  [enterBtn setTitle:@"ENTER" forState:UIControlStateNormal];
  [enterBtn addTarget:self
                action:@selector(enterHit:)
      forControlEvents:UIControlEventTouchUpInside];
  _commonKeys = @[ spaceBtn, backspaceBtn, enterBtn ];
  for (UIView *v in _commonKeys)
    [self addSubview:v];

  _debugLabel = [[IBNIZLabel alloc] initWithFrame:buttonRect];
  _debugLabel.numberOfLines = 0;
  _debugLabel.text = @"FPS: 60\nMOPS: 2309234\n";
  [_scroll addSubview:_debugLabel];

  [self layoutSubviews];
}

- (void)createAccessoryView {
  _accessoryView = [[UIView alloc]
      initWithFrame:CGRectMake(0, 0, self.frame.size.width, 40)];
  CGRect r = CGRectMake(0, 0, self.frame.size.width / 4, 40);
  IBNIZButton *btn;

  btn = [[IBNIZButton alloc] initWithFrame:r];
  NSString *toggle =
      [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad
          ? @"Toggle KB"
          : @"KB";
  [btn setTitle:toggle forState:UIControlStateNormal];
  [btn addTarget:self
                action:@selector(toggleKeys:)
      forControlEvents:UIControlEventTouchUpInside];
  [_accessoryView addSubview:btn];

  r.origin.x += r.size.width;
  btn = [[IBNIZButton alloc] initWithFrame:r];
  [btn setTitle:@"UP" forState:UIControlStateNormal];
  [btn addTarget:self
                action:@selector(valueChange:)
      forControlEvents:UIControlEventTouchUpInside];
  [_accessoryView addSubview:btn];

  r.origin.x += r.size.width;
  btn = [[IBNIZButton alloc] initWithFrame:r];
  [btn setTitle:@"DOWN" forState:UIControlStateNormal];
  btn.tag = 1;
  [btn addTarget:self
                action:@selector(valueChange:)
      forControlEvents:UIControlEventTouchUpInside];
  [_accessoryView addSubview:btn];

  r.origin.x += r.size.width;
  _modeLabel = [[IBNIZLabel alloc] initWithFrame:r];
  [_accessoryView addSubview:_modeLabel];
}

- (void)setMode:(NSString *)mode {
  if ([mode compare:_mode] != NSOrderedSame) {
    _mode = mode;
    _modeLabel.text = [NSString stringWithFormat:@" %@", mode];
  }
}

- (void)setTime:(NSString *)time {
  _time = time;
  [_timeButton setTitle:time forState:UIControlStateNormal];
}

- (void)setDebugString:(NSString *)debugString {
  _debugString = debugString;
  _debugLabel.text = debugString;
}

- (void)setTextView:(UITextView *)textView {
  _textView = textView;
  _textView.delegate = self;
}

- (void)layoutSubviews {
  [super layoutSubviews];
  const CGSize sz = self.frame.size;

  CGRect pageRect = CGRectMake(0, 0, sz.width, sz.height);
  _scroll.frame = pageRect;
  _scroll.contentSize = CGSizeMake(sz.width, sz.height * 3);

  CGRect r = CGRectMake(0, 0, sz.width / 10, sz.height / 4);
  for (UIView *key in _scroll.subviews) {
    key.frame = r;
    r.origin.x += r.size.width;
    if (r.origin.x + r.size.width > sz.width ||
        opcodes[key.tag].symbol == &NEWLINE) {
      r.origin.x = 0;
      r.origin.y += r.size.height;
    }
  }
  r.origin.y += r.size.height;
  r.origin.x = 0;
  r.size.width = sz.width;
  r.size.height *= 2;
  _debugLabel.frame = r;

  CGSize commonSz =
      CGSizeMake((sz.width / 2) / _commonKeys.count, sz.height / 4);
  CGRect commonRect = CGRectMake(sz.width / 2, commonSz.height * 3,
                                 commonSz.width, commonSz.height);
  for (UIView *v in _commonKeys) {
    v.frame = commonRect;
    commonRect.origin.x += commonSz.width;
  }

  commonRect = CGRectMake(sz.width / 2, commonSz.height * 3, commonSz.width,
                          commonSz.height);
  commonRect.origin.x -= commonRect.size.width;
  _timeButton.frame = commonRect;

  r = CGRectMake(0, 0, self.frame.size.width / _accessoryView.subviews.count,
                 40);
  for (UIView *v in _accessoryView.subviews) {
    v.frame = r;
    r.origin.x += r.size.width;
  }
}

- (BOOL)textViewShouldBeginEditing:(UITextField *)textField {
  textField.inputAccessoryView = _accessoryView;
  return YES;
}

- (void)insertString:(NSString *)s {
  if (!self.textView)
    return;
  NSMutableString *string =
      [NSMutableString stringWithString:self.textView.text];
  NSRange r = [self.textView selectedRange];
  [string insertString:s atIndex:r.location];
  self.textView.text = string;
  r.location++;
  r.length = 0;
  dispatch_async(dispatch_get_main_queue(), ^{
    self.textView.selectedRange = r;
  });
  [self hideHelp:nil];
  self.changed();
}

- (void)buttonHit:(IBNIZButton *)sender {
  [self insertString:sender.titleLabel.text];
}

- (void)enterHit:(IBNIZButton *)sender {
  [self insertString:@"\n"];
}

- (void)resetTimeHit:(IBNIZButton *)sender {
  self.resetTimeRequested();
}

- (void)buttonDown:(IBNIZButton *)sender {
  _helpLabel.hidden = YES;
  _helpLabel.text =
      [NSString stringWithFormat:@"%s %s", opcodes[sender.tag].name,
                                 opcodes[sender.tag].description];
  CGRect ref =
      [_helpLabel.superview convertRect:sender.frame fromView:sender.superview];

  CGRect r = _helpLabel.frame;
  r.origin.x = ref.origin.x;
  if (r.origin.x + r.size.width > self.frame.size.width) {
    r.origin.x = self.frame.size.width - r.size.width;
  }
  r.origin.y = ref.origin.y - r.size.height;
  _helpLabel.frame = r;

  [_helpTimer invalidate];
  _helpTimer = [NSTimer scheduledTimerWithTimeInterval:0.50
                                                target:self
                                              selector:@selector(showHelp:)
                                              userInfo:nil
                                               repeats:NO];
}

- (void)showHelp:(id)sender {
  _helpLabel.hidden = NO;
}

- (void)hideHelp:(id)sender {
  [_helpTimer invalidate];
  _helpLabel.hidden = YES;
}

- (void)toggleKeys:(IBNIZButton *)sender {
  _ibnizKeyboard = !_ibnizKeyboard;
  self.textView.inputView = _ibnizKeyboard ? self : nil;
  [self.textView reloadInputViews];
}

- (void)backspace:(IBNIZButton *)sender {
  if (!self.textView)
    return;
  NSMutableString *string =
      [NSMutableString stringWithString:self.textView.text];
  NSRange range = [self.textView selectedRange];
  if (range.length <= 0) {
    range.location--;
    range.length = 1;
  }
  [string deleteCharactersInRange:range];
  self.textView.text = string;
  range.length = 0;
  dispatch_async(dispatch_get_main_queue(), ^{
    self.textView.selectedRange = range;
  });
  self.changed();
  [self hideHelp:nil];
}

- (void)valueChange:(IBNIZButton *)sender {
  if (!self.textView)
    return;
  NSRange range = [self.textView selectedRange];
  NSMutableString *string =
      [NSMutableString stringWithString:self.textView.text];
  if (range.location >= [string length])
    return;
  unichar c = [string characterAtIndex:range.location];
  unichar new_c = c;
  if (sender.tag == 0) {
    switch (c) {
    case '9':
      new_c = 'A';
      break;
    case 'F':
      new_c = '0';
      break;
    default:
      if ((c >= '0' && c <= '8') || (c >= 'A' && c <= 'E')) {
        new_c++;
      }
      break;
    }
  } else {
    switch (c) {
    case '0':
      new_c = 'F';
      break;
    case 'A':
      new_c = '9';
      break;
    default:
      if ((c >= '1' && c <= '9') || (c >= 'B' && c <= 'F')) {
        new_c--;
      }
      break;
    }
  }
  if (c != new_c) {
    range.length = 1;
    [string deleteCharactersInRange:range];
    [string insertString:[NSString stringWithCharacters:&new_c length:1]
                 atIndex:range.location];
    self.textView.text = string;
    range.length = 0;
    dispatch_async(dispatch_get_main_queue(), ^{
      self.textView.selectedRange = range;
    });
    self.changed();
    [self hideHelp:nil];
  }
}

@end
