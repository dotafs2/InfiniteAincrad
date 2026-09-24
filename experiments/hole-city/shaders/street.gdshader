shader_type spatial;
render_mode cull_back;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    vec2 p = world_position.xz;
    vec2 street = abs(mod(p + vec2(8.0), vec2(16.0)) - vec2(8.0));
    float road = 1.0 - step(2.4, min(street.x, street.y));
    vec3 pavement = vec3(0.71, 0.76, 0.73);
    vec3 asphalt = vec3(0.23, 0.32, 0.36);
    vec3 col = mix(pavement, asphalt, road);
    float lane_x = (1.0-step(0.075,street.x)) * step(0.9, mod(p.y+64.0,3.0));
    float lane_y = (1.0-step(0.075,street.y)) * step(0.9, mod(p.x+64.0,3.0));
    if (road>0.5 && max(street.x,street.y)>3.0) col=mix(col,vec3(0.93,0.83,0.54),max(lane_x,lane_y)*0.8);
    float crossing_x=(1.0-step(1.7,street.x))*step(3.2,street.y)*(1.0-step(4.5,street.y))*step(0.5,mod(p.x+64.0,0.85));
    float crossing_y=(1.0-step(1.7,street.y))*step(3.2,street.x)*(1.0-step(4.5,street.x))*step(0.5,mod(p.y+64.0,0.85));
    col=mix(col,vec3(0.88,0.89,0.79),max(crossing_x,crossing_y));
    float slab=step(0.025,mod(p.x+64.0,1.2))*step(0.025,mod(p.y+64.0,1.2));
    col*=mix(0.91,1.0,mix(slab,1.0,road));
    ALBEDO=col; ROUGHNESS=0.95;
}
