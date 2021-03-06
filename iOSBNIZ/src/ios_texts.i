char*welcometext=
  "\n"
  "\n"
  "\\IBNIZ\n\\1.1C00-NORELEASE\n"
  "\\by viznut\n"
  "\\www.pelulamu.net/viznut/\n\n"
  "\\iOS\n\\version 1.1\n"
  "\\port by bzztbomb\n"
  "\\bzztbomb.com/\n"
  "\n"
  "\\Swipe left for help.\n";

char*helpscreen=
 ////////////////////////////////
"\\IBNIZ\n\\1.1C00-NORELEASE\n"
"\\by viznut\n"
"\\www.pelulamu.net/viznut/\n\n"
"\\iOS\n\\version 1.1\n"
"\\port by bzztbomb\n"
"\\bzztbomb.com/\n"
"\n"
"IBNIZ quick reference"
"\n"
"============= UI ==============="
"\n"
"Swipe left and right for modes\n"
"Mode 0: Program hiden\n"
"Mode 1: Program displayed\n"
"Mode 2: Help\n"
"Mode 3: Load/Save programs\n"
"\n"
"Shake to toggle swipe mode. "
"If swipe mode is off, touches "
"and drags are sent to the user input"
" opcode (U)"
"\n"
"======== IBNIZ language ========"
"\n"
"One character per operation.\n"
"Number format 16.16 fixedpoint.\n"
"Immediates in uppercase hex.\n"
"Implicit whole-program loop\n"
"  with 'Mw' on each cycle.\n"
"\n"
"Arithmetic:\n"
"\n"
"+ - * / % & | ^ ~ are as in C\n"
"\n"
"q:sqrt s:sin a:atan2 r:ror l:shl"
"\n"
"< : zero if <0 else keep\n"
"> : zero if >0 else keep\n"
"= : 1 if zero else 0\n"
"\n"
"Stack manipulation:\n"
"\n"
"  1 d = 1 1     2 1 x = 1 2\n"
"1 1 p = 1     3 2 1 v = 2 1 3\n"
 "\n"
"N) = copy from N places down\n"
"N( = store to N places down\n"
"\n"
"Memory manipulation:\n"
"\n"
"N@ = load value from MEM[N]\n"
"MN! = store value M to MEM[N]\n"
"\n"
"Conditionals:\n"
"\n"
"N?M;   = if N!=0 then M\n"
"N?M:O; = if N!=0 then M else O\n"
"\n"
"Loops:\n"
"\n"
"NX...L execute '...' N times\n"
"i = index of inner X loop\n"
"j = index of outer X loop\n"
"[...N] repeat '...' until N==0\n"
"\n"
"Subroutines:\n"
"\n"
"N{...} define subroutine\n"
"      (store pointer to MEM[N]) "
"NV     run subroutine N\n"
"\n"
"Return stack:\n"
"\n"
"R     pop from rstack to stack\n"
"P     pop from stack to rstack\n"
"\n"
"User input:\n"
"\n"
"U     return 0000.YYXX where\n"
"      YYXX = mouse position\n"
"\n"
"Data segment:\n"
"\n"
"NG   fetch N bits of data\n"
"$    start data segment where\n"
"0-F  data digits\n"
"bqoh digit size 1-4 bits\n"
"\n"
"Data segment is stored in\n"
"MEM[0...] on each VM reset\n"
"\n"
"Specials:\n"
"\n"
"w : push loop vars (t or t y x) "
"M : separate audio/vidoe code\n"
"T : terminate program\n"
"\\ : comment line\n"
", : blank, separate numbers\n"
"\n"
"======= Examples =======\n"
"\n"
"Copy to editor and run:\n\n"
"^x6r-\n\n"
"ddd***\n\n"
"d3r15&*\n\n"
"dd6r*3r&\n\n"
"^x7r+Md8r&\n\n"
"v8rsdv*vv*^\n\n"
"d6r|5*wdAr&+\n\n"
"v8rsdv*vv*^wpp8r-\n\n"
"ax8r+3lwd*xd*+q1x/x5r+^\n\n"
"v8rds4X3)Lx~2Xv*vv*+i!L1@2@&\n\n"
"6{^^ddd***1%}5{v8rsdv*vv*^wpp8r-}4{v8rdsx.6+s4X3)Lx~2Xv*vv*+i!L1@2@^}"
"3{ax8r+3lwd*xd*+q1x/x6r+^}2)6r3&3+V55A9^Md6r|5*wdAr&+\n\n"
"Full docs & latest IBNIZ:\n"
"http://pelulamu.net/ibniz/\n";
