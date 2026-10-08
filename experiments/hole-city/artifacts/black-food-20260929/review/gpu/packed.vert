#version 150
in uvec4 instance_color_custom_data;
uniform vec4 probe_vertex_color;
uniform bool standalone;
out vec4 actual_color;
float half_value(uint bits) {
    uint exponent=(bits>>10u)&31u;uint mantissa=bits&1023u;
    float magnitude=exponent==0u ? float(mantissa)*exp2(-24.0) : (1.0+float(mantissa)/1024.0)*exp2(float(exponent)-15.0);
    return (bits&32768u)!=0u ? -magnitude:magnitude;
}
vec2 unpackHalf2x16(uint bits){return vec2(half_value(bits&65535u),half_value(bits>>16u));}
void main(){
    vec2 p=vec2((gl_VertexID<<1)&2,gl_VertexID&2);gl_Position=vec4(p*2.0-1.0,0.0,1.0);
    // Pinned Godot scene-ed1daf0bf.glsl lines 651-656, same four components.
    vec4 color_interp=probe_vertex_color;
    vec4 instance_color;
    instance_color.xy=unpackHalf2x16(instance_color_custom_data.x);
    instance_color.zw=unpackHalf2x16(instance_color_custom_data.y);
    if(!standalone)color_interp*=instance_color;
    actual_color=color_interp;
}
