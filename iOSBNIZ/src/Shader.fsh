//
//  Shader.fsh
//  gl_thing
//
//  Created by Brian Richardson on 11/21/15.
//  Copyright © 2015 pure-imagination.com. All rights reserved.
//

uniform sampler2D frame;

varying lowp vec2 tc;

void main()
{
  gl_FragColor = texture2D(frame, tc);
}
