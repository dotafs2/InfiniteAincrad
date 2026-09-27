shader_type spatial;
varying vec3 pos;
void vertex(){pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
    vec2 p=pos.xz;
    vec2 patch_id=floor(p*0.35);
    float patch_hash=fract(sin(dot(patch_id,vec2(17.13,41.71)))*18321.17);
    bool parking=abs(p.x)<19.0 && p.y>7.0 && p.y<36.0;
    bool road=abs(p.x+27.0)<4.1 || abs(p.x-29.0)<4.1 || abs(p.y+2.0)<4.1 || abs(p.y+30.0)<4.1;
    vec3 color=vec3(0.65,0.65,0.59);
    if(parking||road)color=vec3(0.28,0.28,0.29);
    else{vec2 slab=step(vec2(0.025),fract(p/1.4));color*=mix(0.84,1.0,slab.x*slab.y);}
    if(parking){
        float stripe=1.0-step(0.055,abs(mod(p.x+18.0,3.7)-0.1));
        if((p.y<14.0 && p.y>8.0)||(p.y>29.0&&p.y<35.0))color=mix(color,vec3(0.74,0.71,0.54),stripe);
    }
    if(road){
        float axis=min(min(abs(p.x+27.0),abs(p.x-29.0)),min(abs(p.y+2.0),abs(p.y+30.0)));
        if(axis<0.055&&mod(p.x+p.y+120.0,3.0)>1.2)color=vec3(0.73,0.69,0.52);
    }
    float damp_patch=step(0.82,patch_hash)*0.035;
    color=mix(color,color*vec3(0.68,0.78,0.86),damp_patch*(0.5+0.5*sin(TIME*0.12+patch_hash*6.28)));
    ALBEDO=color;ROUGHNESS=0.96;
}
