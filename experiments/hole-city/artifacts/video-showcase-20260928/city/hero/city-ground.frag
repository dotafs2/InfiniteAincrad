#version 150
in vec3 N;in vec3 P;in vec3 C;uniform int ground;uniform float fx_time;out vec4 output_color;


uniform vec2 road_x = vec2(-27.0,29.0);
uniform vec2 road_z = vec2(-2.0,-30.0);
uniform float road_half_width = 4.1;
uniform bool food_theme = false;
uniform sampler2D food_city_atlas;
uniform vec4 sidewalk_0;
uniform vec4 sidewalk_1;
uniform vec4 sidewalk_2;
uniform vec4 sidewalk_3;
uniform vec4 city_walk_0;
uniform vec4 city_walk_1;
uniform vec4 city_walk_2;
uniform vec4 city_walk_3;
uniform vec4 city_park_0;
uniform vec4 city_park_1;
uniform vec4 city_park_2;
uniform vec4 city_park_3;
uniform vec4 city_courtyard;
float walk_edge(vec2 p, vec4 area){
    vec2 d=abs(p-area.xy-area.zw*.5)-area.zw*.5;
    return max(d.x,d.y);
}

vec3 city_color(){
    vec2 p=P.xz;
    vec2 patch_id=floor(p*0.35);
    float patch_hash=fract(sin(dot(patch_id,vec2(17.13,41.71)))*18321.17);
    bool parking=!food_theme && abs(p.x)<19.0 && p.y>17.0 && p.y<36.0;
    bool road=abs(p.x-road_x.x)<road_half_width || abs(p.x-road_x.y)<road_half_width || abs(p.y-road_z.x)<road_half_width || abs(p.y-road_z.y)<road_half_width;
    vec3 color=food_theme?vec3(.83,.94,.75):vec3(.84,.86,.79);
    if(parking||road)color=(food_theme?vec3(.86,.64,.61):vec3(.38,.43,.49));
    else{vec2 slab=step(vec2(0.025),fract(p/1.4));color*=mix(0.84,1.0,slab.x*slab.y);}
    if(parking){
        float stripe=1.0-step(0.055,abs(mod(p.x+18.0,3.7)-0.1));
        if((p.y<14.0 && p.y>8.0)||(p.y>29.0&&p.y<35.0))color=mix(color,vec3(0.74,0.71,0.54),stripe);
    }
    if(road){
        float axis=min(min(abs(p.x-road_x.x),abs(p.x-road_x.y)),min(abs(p.y-road_z.x),abs(p.y-road_z.y)));
        if(axis<0.055&&mod(p.x+p.y+120.0,3.0)>1.2)color=vec3(0.73,0.69,0.52);
    }
    float sidewalk=min(min(walk_edge(p,sidewalk_0),walk_edge(p,sidewalk_1)),min(walk_edge(p,sidewalk_2),walk_edge(p,sidewalk_3)));
    if(sidewalk<0.0 && !road){
        vec2 tile=step(vec2(.025),fract(p/1.4));
        color=(food_theme?vec3(1.0,.90,.77):vec3(.94,.94,.88))*mix(.86,1.0,tile.x*tile.y);
        if(sidewalk>-.14)color=food_theme?vec3(.93,.72,.55):vec3(.70,.74,.77);
    }
    if(!food_theme){
        float park=min(min(walk_edge(p,city_park_0),walk_edge(p,city_park_1)),min(walk_edge(p,city_park_2),walk_edge(p,city_park_3)));
        park=min(park,walk_edge(p,city_courtyard));
        if(park<0.0 && !road)color=mix(vec3(.40,.65,.27),vec3(.53,.72,.35),step(.2,fract(p.x*.13+p.y*.09)));
        // Painted on the same physically cut terrain: a mouth removes paths
        // and park turf together, with no opaque overlay spanning its opening.
        float walk=min(min(abs(walk_edge(p,city_walk_0)),abs(walk_edge(p,city_walk_1))),min(abs(walk_edge(p,city_walk_2)),abs(walk_edge(p,city_walk_3))));
        if(walk<1.05 && !road){
            vec2 tile=step(vec2(.028),fract(p/1.4));
            color=vec3(.94,.92,.82)*mix(.86,1.0,tile.x*tile.y);
            if(walk>.90)color=vec3(.68,.72,.73);
        }
    }
    if(food_theme){
        // Cool mint separates warm pastry/gold from pink, berry and cream toppings.
        color=pow(vec3(.39,.83,.70),vec3(2.2));
        vec2 slab=step(vec2(.025),fract(p/3.2));
        color*=mix(.94,1.0,slab.x*slab.y);
        if(road){
            color=pow(vec3(.97,.90,.73),vec3(2.2));
            float axis=min(min(abs(p.x-road_x.x),abs(p.x-road_x.y)),min(abs(p.y-road_z.x),abs(p.y-road_z.y)));
            if(axis<.09 && mod(p.x+p.y+120.0,3.0)>1.2)color=pow(vec3(1.0,.48,.60),vec3(2.2));
            if(axis>road_half_width-.20)color=pow(vec3(.98,.42,.56),vec3(2.2));
        }else if(sidewalk<0.0){
            color=pow(vec3(1.0,.77,.43),vec3(2.2));
            vec2 wafer=abs(fract(p/1.25)-.5);
            if(wafer.x>.45 || wafer.y>.45)color*=.86;
            if(sidewalk>-.15)color=pow(vec3(1.0,.95,.81),vec3(2.2));
        }
    }
    if(food_theme){color=texture(food_city_atlas,(p+vec2(80.0))/160.0).rgb;}
    float damp_patch=food_theme?0.0:step(0.82,patch_hash)*0.035;
    color=mix(color,color*vec3(0.68,0.78,0.86),damp_patch*(0.5+0.5*sin(fx_time*0.12+patch_hash*6.28)));
    return color;
}
uniform bool is_facade;in vec2 UV;in vec3 local_normal;

uniform vec4 wall_color  = vec4(0.6,0.31,0.22,1.0);
uniform vec4 glass_color  = vec4(0.26,0.48,0.59,1.0);
uniform float floors=4.0;
uniform float columns=3.0;
uniform bool glass_tower=false;
uniform float visibility=1.0;


vec3 facade_color(){
    vec2 cell=fract(UV*vec2(columns,floors));
    vec2 id=floor(UV*vec2(columns,floors));
    float window_hash=fract(sin(dot(id,vec2(12.9898,78.233)))*43758.5453);
    float side=1.0-step(0.7,abs(local_normal.y));
    vec2 edge=abs(cell-0.5);
    float opening=(1.0-step(glass_tower?0.47:0.27,edge.x))*(1.0-step(glass_tower?0.48:0.34,edge.y))*side;
    float frame=(1.0-step(glass_tower?0.49:0.31,edge.x))*(1.0-step(glass_tower?0.50:0.38,edge.y))*side;
    vec3 pane=mix(glass_color.rgb,glass_color.rgb*0.64,step(0.48,cell.x));
    pane=mix(pane,glass_color.rgb*1.25,step(0.66,cell.y)*0.4);
    float window_pulse=0.72+0.28*sin(fx_time*(0.25+window_hash*0.18)+window_hash*6.28318);
    vec3 neon=mix(vec3(0.18,0.72,0.95),vec3(1.0,0.36,0.12),step(0.57,window_hash));
    pane+=neon*0.10*window_pulse*opening;
    float cross=1.0-step(0.018,min(abs(cell.x-0.5),abs(cell.y-0.5)));
    vec3 color=mix(wall_color.rgb,vec3(0.68,0.64,0.54),frame);
    color=mix(color,mix(pane,vec3(0.61,0.62,0.57),cross*0.65),opening);
    return color+neon*0.07*window_pulse*opening;
}
void main(){vec3 c=ground==1?city_color():(is_facade?facade_color():C);float light=.64+.38*max(0.,dot(normalize(N),normalize(vec3(-.38,.82,.42))));output_color=vec4(pow(max(c*light,vec3(0.)),vec3(1./2.2)),1.);}
