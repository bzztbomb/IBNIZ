//
//  Shader.vsh
//  gl_thing
//
//  Created by Brian Richardson on 11/21/15.
//  Copyright © 2015 pure-imagination.com. All rights reserved.
//

attribute vec2 position;
attribute vec2 texCoord;

varying highp vec2 tc;

void main()
{
  tc = texCoord;
  gl_Position = vec4(position.x, position.y, 0, 1);
}
