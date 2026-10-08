shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float palette_mix=0.0;
uniform vec4 palette_primary:source_color=vec4(0.1,0.4,0.6,1.0);
uniform vec4 palette_secondary:source_color=vec4(0.8,0.9,1.0,1.0);
uniform float fx_time = 0.0;
varying float visible_drop;
void vertex() {
 float until_impact = mod(INSTANCE_CUSTOM.x * 3.0 - mod(fx_time,3.0) + 3.0,3.0);
 float flight = 0.66;
 visible_drop = step(until_impact,flight);
 float progress = 1.0 - clamp(until_impact/flight,0.0,1.0);
 float height = 0.07 + 1.43 * (1.0-progress*progress);
 mat4 facing = mat4(INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
  INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
  INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz),MODEL_MATRIX[3]);
 facing[3].y += height * length(MODEL_MATRIX[1].xyz);
 MODELVIEW_MATRIX = VIEW_MATRIX * facing;
 VERTEX.xy *= INSTANCE_CUSTOM.y;
}
void fragment() {
 vec2 p=UV*2.0-1.0;
 float head=exp(-p.x*p.x*13.0-pow((p.y-0.40)*3.2,2.0));
 float tail=exp(-p.x*p.x*45.0)*(1.0-smoothstep(0.15,1.0,-p.y))*0.45;
 float edge=1.0-smoothstep(0.85,1.0,abs(p.y));
 ALBEDO=mix(vec3(0.18,0.70,0.66),vec3(0.92,1.0,0.95),head);
 ALPHA=(head+tail)*edge*visible_drop*0.85;
 // A variant changes color only; density, alpha and intake timing stay identical.
 float value=clamp(dot(ALBEDO,vec3(.2126,.7152,.0722)),0.0,1.0);
 ALBEDO=mix(ALBEDO,mix(palette_primary.rgb*.36,palette_secondary.rgb,value),palette_mix);
}
