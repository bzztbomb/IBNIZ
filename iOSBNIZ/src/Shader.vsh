//
//  Shader.vsh
//  gl_thing
//
//  Created by Brian Richardson on 11/21/15.
//  Copyright © 2015 pure-imagination.com. All rights reserved.
//

attribute vec2 position;
attribute vec2 texCoord;

uniform vec2 offset;
uniform vec2 scale;

varying highp vec2 tc;

void main()
{
  tc = texCoord;
  gl_Position = vec4((position.x * scale.x) + offset.x, (position.y * scale.y) + offset.y, 0, 1);
}
