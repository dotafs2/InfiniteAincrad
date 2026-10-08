shader_type spatial;
render_mode specular_schlick_ggx;
// Opaque optical-depth illusion: avoids per-pixel transparent ice sorting.
varying vec3 local_position;
void vertex() { local_position=VERTEX; }
void fragment() {
    float snow=smoothstep(.60,.74,COLOR.r);
    float layer=sin(local_position.y*14.0+sin(local_position.x*9.0+local_position.z*5.0)*1.15);
    float stratum=smoothstep(.96,.995,layer)*(1.0-snow)*smoothstep(-.1,.3,sin(local_position.z*12.0+local_position.x*7.0));
    float edge=pow(1.0-clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0),3.0);
    vec3 ice=COLOR.rgb*vec3(.85,.95,1.10);
    ALBEDO=mix(ice,vec3(.70,.82,.91),snow)+vec3(.018,.035,.046)*stratum;
    ROUGHNESS=mix(.17,.48,snow);
    METALLIC=0.0;
    SPECULAR=mix(.85,.28,snow);
    EMISSION=(vec3(.025,.105,.15)+edge*vec3(.12,.27,.34))*(1.0-snow)*.40;
}
