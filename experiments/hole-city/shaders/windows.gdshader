shader_type spatial;
uniform vec4 wall_color : source_color = vec4(0.45,0.66,0.73,1.0);
uniform float floors=5.0;
uniform float columns=3.0;
void fragment() {
    vec2 tile=fract(UV * vec2(columns,floors));
    float pane=step(0.2,tile.x)*step(tile.x,0.8)*step(0.22,tile.y)*step(tile.y,0.73);
    float sides=1.0-step(0.7,abs(NORMAL.y));
    vec3 glass=vec3(0.16,0.32,0.40);
    ALBEDO=mix(wall_color.rgb,glass,pane*sides);
    ROUGHNESS=mix(0.86,0.3,pane*sides);
}
