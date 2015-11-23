//
//  Shader.fsh
//  gl_thing
//
//  Created by Brian Richardson on 11/21/15.
//  Copyright © 2015 pure-imagination.com. All rights reserved.
//

uniform sampler2D page;

varying lowp vec2 tc;

void main()
{
  highp vec4 tex = texture2D(page, tc);
  // 0000.FFFF -> aabb.ggrr
  highp float y = tex.g;
  // Convert to -0.5..0.5
  highp float u = tex.b <= 0.5 ? tex.b : -(1.0 - tex.b);
  highp float v = tex.a <= 0.5 ? tex.a : -(1.0 - tex.a);
  y = 1.1643 * (y - 0.0625);
  highp float r = clamp(y+1.5958*v, 0.0, 1.0);
  highp float g = clamp(y-0.39173*u-0.81290*v,0.0, 1.0);
  highp float b = clamp(y+2.017*u, 0.0, 1.0);
  gl_FragColor = vec4(r,g,b,1.0);
}
