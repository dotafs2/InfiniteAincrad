shader_type spatial;
render_mode cull_disabled;
varying vec3 world_position;
varying float cavity_wall;
uniform float world_half=100.0;
uniform float city_outer_road=84.0;
uniform float city_outer_half_width=3.2;
uniform vec2 road_x;
uniform vec2 road_z;
uniform float road_half_width;
uniform bool food_theme;
uniform vec4 sidewalk_0;
uniform vec4 sidewalk_1;
uniform vec4 sidewalk_2;
uniform vec4 sidewalk_3;
void vertex(){ world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; cavity_wall=1.0-step(.5,abs(NORMAL.y)); }
void fragment(){
 vec2 p=world_position.xz;
 float sweep=sin(p.x*.035+p.y*.012)*3.5+sin(p.y*.082)*1.6;
 float river=abs(p.x*.43+p.y*.90+12.0+sweep);
 float lagoon=length((p-vec2(63.,-66.))*vec2(.055,.080));
 float bay=length((p-vec2(-68.,55.))*vec2(.048,.065));
 float ice=max(1.-smoothstep(5.,12.,river),max(1.-smoothstep(.7,1.4,lagoon),1.-smoothstep(.65,1.2,bay)));
 float undulation=sin(p.x*.095+sin(p.y*.035)*2.)*.5+.5;
 vec3 snow=mix(vec3(.54,.58,.65),vec3(.69,.73,.79),undulation*.55+.30);
 vec3 blue=mix(vec3(.07,.25,.42),vec3(.22,.53,.69),undulation*.65+.2);
 float contour=abs(sin(p.x*.047+p.y*.080+sin(p.y*.039)*1.2));
 float frostline=1.-smoothstep(.015,.04+max(fwidth(p.x),fwidth(p.y))*.025,contour);
 vec3 color=mix(snow,blue,ice);
 color+=vec3(.025,.045,.05)*frostline*ice;
 float border=smoothstep(world_half-4.,world_half,max(abs(p.x),abs(p.y)));
 color=mix(color,vec3(.14,.34,.48),border*.42);
 ALBEDO=mix(color,vec3(.01,.03,.06),cavity_wall);
 ROUGHNESS=mix(.72,.20,ice);SPECULAR=mix(.25,.8,ice);
}
