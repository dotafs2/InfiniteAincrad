shader_type spatial;
uniform vec4 wall_color : source_color = vec4(0.6,0.31,0.22,1.0);
uniform vec4 glass_color : source_color = vec4(0.26,0.48,0.59,1.0);
uniform float floors=4.0;
uniform float columns=3.0;
uniform bool glass_tower=false;
uniform float visibility=1.0;
varying vec3 local_normal;
void vertex(){local_normal=NORMAL;}
void fragment(){
    vec2 cell=fract(UV*vec2(columns,floors));
    float side=1.0-step(0.7,abs(local_normal.y));
    vec2 edge=abs(cell-0.5);
    float opening=(1.0-step(glass_tower?0.47:0.27,edge.x))*(1.0-step(glass_tower?0.48:0.34,edge.y))*side;
    float frame=(1.0-step(glass_tower?0.49:0.31,edge.x))*(1.0-step(glass_tower?0.50:0.38,edge.y))*side;
    vec3 pane=mix(glass_color.rgb,glass_color.rgb*0.64,step(0.48,cell.x));
    pane=mix(pane,glass_color.rgb*1.25,step(0.66,cell.y)*0.4);
    float cross=1.0-step(0.018,min(abs(cell.x-0.5),abs(cell.y-0.5)));
    vec3 color=mix(wall_color.rgb,vec3(0.68,0.64,0.54),frame);
    color=mix(color,mix(pane,vec3(0.61,0.62,0.57),cross*0.65),opening);
    ALBEDO=color; ROUGHNESS=mix(0.88,0.3,opening); ALPHA=visibility;
}
