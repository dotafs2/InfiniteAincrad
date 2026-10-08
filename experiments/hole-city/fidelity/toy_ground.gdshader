shader_type spatial;
render_mode cull_disabled;

// A fairytale garden with warm cobbled royal boulevards. The same physically cut slab
// carries the surface and dark mouth walls; no overlay can bridge a hole.
varying vec3 world_position;
varying float cavity_wall;
uniform float world_half = 100.0;
uniform float city_outer_road = 84.0;
uniform float city_outer_half_width = 3.2;
// Preserve the shared ground builder's parameter interface.
uniform vec2 road_x;
uniform vec2 road_z;
uniform float road_half_width;
uniform bool food_theme;
uniform vec4 sidewalk_0;
uniform vec4 sidewalk_1;
uniform vec4 sidewalk_2;
uniform vec4 sidewalk_3;

float band(float value, float center, float half_width, float footprint) {
    return 1.0 - smoothstep(half_width - footprint, half_width + footprint, abs(value-center));
}

float meadow_hash(vec2 p) {
    return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);
}
float meadow_noise(vec2 p) {
    vec2 cell=floor(p);
    vec2 local=fract(p);
    vec2 blend=local*local*(3.0-2.0*local);
    return mix(mix(meadow_hash(cell),meadow_hash(cell+vec2(1,0)),blend.x),
               mix(meadow_hash(cell+vec2(0,1)),meadow_hash(cell+vec2(1,1)),blend.x),blend.y);
}

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    cavity_wall = 1.0 - step(.5, abs(NORMAL.y));
}

void fragment() {
    vec2 p = world_position.xz;
    vec2 footprint = max(fwidth(p), vec2(.001));
    float edge = max(footprint.x, footprint.y);
    // Broad lawn tones stay readable at the gameplay camera's distance.
    vec3 meadow = vec3(.095, .28, .145);
    vec3 garden = vec3(.19, .37, .19);
    float patch = .5 + .5 * sin(p.x * .11) * sin(p.y * .14);
    vec3 district = mix(meadow, garden, patch);
    float blade = meadow_noise(p * 5.0) - .5;
    district *= 1.0 + blade * .12 * (1.0-smoothstep(.08,.35,edge));
    // Read the same six boulevard centerlines as the physical parcel plan.
    float road_distance = min(min(abs(p.x+44.0),abs(p.x)),abs(p.x-44.0));
    road_distance = min(road_distance,min(min(abs(p.y+36.0),abs(p.y-18.0)),abs(p.y-60.0)));
    float outer_coordinate = max(abs(p.x),abs(p.y));
    float outer_distance = abs(outer_coordinate-city_outer_road);
    float lane = max(1.0-smoothstep(3.6-edge,3.6+edge,road_distance),
        1.0-smoothstep(city_outer_half_width-edge,city_outer_half_width+edge,outer_distance));
    float verge = max(1.0-smoothstep(4.05-edge,4.05+edge,road_distance),
        1.0-smoothstep(city_outer_half_width+.45-edge,city_outer_half_width+.45+edge,outer_distance));
    // The two northern palaces sit in royal forecourts, with a broad east/west
    // approach and separate lawn panels. This decorates the cut slab itself.
    vec2 royal = vec2(abs(p.x)-22.0,p.y+64.0);
    float court_distance = length(royal/vec2(1.12,1.0));
    float court = 1.0-smoothstep(16.2-edge,16.2+edge,court_distance);
    float court_rim = 1.0-smoothstep(16.7-edge,16.7+edge,court_distance);
    lane=max(lane,court);verge=max(verge,court_rim);
    // Repeated district courts are paving around the actual existing keeps,
    // not visual platforms, extra collision surfaces or immovable props.
    vec2 parcel = vec2(abs(p.x)-23.0,min(abs(p.y-41.0),abs(p.y+10.0)));
    float local_court = max(abs(parcel.x)-6.2,abs(parcel.y)-7.0);
    lane=max(lane,1.0-smoothstep(-edge,edge,local_court));
    verge=max(verge,1.0-smoothstep(.35-edge,.35+edge,local_court));
    // Mown lawn stripes are broad enough to survive the ordinary play camera.
    float mowing = sin(p.x*.43 + p.y*.11)*.5+.5;
    district *= mix(.93,1.04,mowing);
    // Offset stone courses, antialiased in world space; no separate plane
    // can cover a player's physically cut opening.
    vec2 paving = p / vec2(1.6, .85);
    paving.x += mod(floor(paving.y), 2.0) * .5;
    vec2 stone_edge = min(fract(paving), 1.0-fract(paving));
    vec2 mortar_width = max(fwidth(paving), vec2(.008));
    float stone = smoothstep(.022-mortar_width.x,.022+mortar_width.x,stone_edge.x)
                * smoothstep(.027-mortar_width.y,.027+mortar_width.y,stone_edge.y);
    float paving_detail = 1.0-smoothstep(.35,.9,edge);
    vec3 pavement = mix(vec3(.40,.37,.30),vec3(.69,.64,.51), mix(1.0,stone,paving_detail));
    // Dark blue inlay gives entrances a deliberate scale without shiny ground.
    float court_ring = band(court_distance,14.8,.17,edge);
    float boulevard_inlay = band(road_distance,2.95,.075,edge)*(1.0-court);
    pavement=mix(pavement,vec3(.23,.33,.37),max(court_ring,boulevard_inlay)*.7);
    vec3 color = mix(district,vec3(.79,.71,.52),verge);
    color = mix(color,pavement,lane);
    float border = smoothstep(world_half-3.0,world_half,outer_coordinate);
    color = mix(color,vec3(.07,.20,.12),border*.55);
    ALBEDO = mix(color,vec3(.003,.006,.010),cavity_wall);
    ROUGHNESS = mix(.95,.73,lane);
    SPECULAR = .18;
}
