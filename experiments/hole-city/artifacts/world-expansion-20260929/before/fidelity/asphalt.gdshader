shader_type spatial;
varying vec3 pos;
uniform vec2 road_x = vec2(-27.0,29.0);
uniform vec2 road_z = vec2(-2.0,-30.0);
uniform float road_half_width = 4.1;
uniform bool food_theme = false;
uniform sampler2D food_city_atlas : source_color, filter_linear_mipmap, repeat_disable;
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

// FILTERING_HELPERS_BEGIN
// Integrate a band over its pixel footprint, retaining the area of thin lines.
float coverage_interval(float x, float begin, float end, float pixel_span) {
    float span = max(pixel_span, 0.0001);
    return clamp((min(x + span * 0.5, end) - max(x - span * 0.5, begin)) / span, 0.0, 1.0);
}
float coverage_integral(float x, float duty) {
    return floor(x) * duty + min(fract(x), duty);
}
// A box-filtered periodic band. The integral crosses seams and converges to the
// duty cycle when multiple repeats fit inside a pixel, rather than blinking.
float coverage_repeat(float x, float begin, float width, float period, float pixel_span) {
    float span = max(pixel_span / period, 0.0001);
    float center = (x - begin) / period;
    float duty = clamp(width / period, 0.0, 1.0);
    return clamp((coverage_integral(center + span * 0.5, duty) - coverage_integral(center - span * 0.5, duty)) / span, 0.0, 1.0);
}
// FILTERING_HELPERS_END

float walk_edge(vec2 p, vec4 area) {
    vec2 d = abs(p - area.xy - area.zw * .5) - area.zw * .5;
    return max(d.x, d.y);
}
float inside_edge(float distance_to_edge, float pixel_span) {
    float span = max(pixel_span, .0001);
    return clamp(.5 - distance_to_edge / span, 0.0, 1.0);
}
float paving(vec2 p, vec2 pixel_span, float seam_fraction) {
    float begin = 1.4 * seam_fraction;
    return coverage_repeat(p.x, begin, 1.4 - begin, 1.4, pixel_span.x)
         * coverage_repeat(p.y, begin, 1.4 - begin, 1.4, pixel_span.y);
}
void vertex() { pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    vec2 p = pos.xz;
    // Derivatives are taken before fract/floor or divergent material branches.
    vec2 pixel_span = fwidth(p);
    float edge_span = max(pixel_span.x, pixel_span.y);
    float dash_coord = p.x + p.y + 120.0;
    float dash_span = fwidth(dash_coord);
    float park_coord = p.x * .13 + p.y * .09;
    float park_span = fwidth(park_coord);
    vec3 color;
    if (food_theme) {
        // This atlas is the authored street/path plan; its imported mip chain
        // filters the same colors and layout at oblique and distant views.
        color = texture(food_city_atlas, (p + vec2(80.0)) / 160.0).rgb;
    } else {
        float road = max(max(coverage_interval(p.x, road_x.x-road_half_width, road_x.x+road_half_width, pixel_span.x),
                             coverage_interval(p.x, road_x.y-road_half_width, road_x.y+road_half_width, pixel_span.x)),
                         max(coverage_interval(p.y, road_z.x-road_half_width, road_z.x+road_half_width, pixel_span.y),
                             coverage_interval(p.y, road_z.y-road_half_width, road_z.y+road_half_width, pixel_span.y)));
        float parking = coverage_interval(p.x, -19.0, 19.0, pixel_span.x) * coverage_interval(p.y, 17.0, 36.0, pixel_span.y);
        color = vec3(.84,.86,.79) * mix(.84, 1.0, paving(p, pixel_span, .025));
        color = mix(color, vec3(.38,.43,.49), max(parking, road));
        float stripe = coverage_repeat(p.x + 18.0, .045, .11, 3.7, pixel_span.x);
        float parking_rows = max(coverage_interval(p.y, 8.0, 14.0, pixel_span.y), coverage_interval(p.y, 29.0, 35.0, pixel_span.y));
        color = mix(color, vec3(.74,.71,.54), stripe * parking * parking_rows);
        float centerline = max(max(coverage_interval(p.x, road_x.x-.055, road_x.x+.055, pixel_span.x),
                                   coverage_interval(p.x, road_x.y-.055, road_x.y+.055, pixel_span.x)),
                               max(coverage_interval(p.y, road_z.x-.055, road_z.x+.055, pixel_span.y),
                                   coverage_interval(p.y, road_z.y-.055, road_z.y+.055, pixel_span.y)));
        float dash = coverage_repeat(dash_coord, 1.2, 1.8, 3.0, dash_span);
        color = mix(color, vec3(.73,.69,.52), road * centerline * dash);
        float sidewalk = min(min(walk_edge(p,sidewalk_0),walk_edge(p,sidewalk_1)), min(walk_edge(p,sidewalk_2),walk_edge(p,sidewalk_3)));
        vec3 sidewalk_color = vec3(.94,.94,.88) * mix(.86, 1.0, paving(p,pixel_span,.025));
        sidewalk_color = mix(sidewalk_color, vec3(.70,.74,.77), inside_edge(-.14-sidewalk, edge_span));
        color = mix(color, sidewalk_color, inside_edge(sidewalk, edge_span) * (1.0-road));
        float park = min(min(walk_edge(p,city_park_0),walk_edge(p,city_park_1)), min(walk_edge(p,city_park_2),walk_edge(p,city_park_3)));
        park = min(park, walk_edge(p,city_courtyard));
        vec3 grass = mix(vec3(.40,.65,.27), vec3(.53,.72,.35), coverage_repeat(park_coord,.2,.8,1.0,park_span));
        color = mix(color, grass, inside_edge(park,edge_span) * (1.0-road));
        // These marks remain on the physically cut ground, with no overlay
        // spanning a hole. Nominal route boundaries are unchanged.
        float walk = min(min(abs(walk_edge(p,city_walk_0)),abs(walk_edge(p,city_walk_1))), min(abs(walk_edge(p,city_walk_2)),abs(walk_edge(p,city_walk_3))));
        vec3 walk_color = vec3(.94,.92,.82) * mix(.86,1.0,paving(p,pixel_span,.028));
        walk_color = mix(walk_color,vec3(.68,.72,.73),inside_edge(.90-walk,edge_span));
        color = mix(color,walk_color,inside_edge(walk-1.05,edge_span)*(1.0-road));
        vec2 patch_id = floor(p*.35);
        float patch_hash = fract(sin(dot(patch_id,vec2(17.13,41.71)))*18321.17);
        float patch_detail = 1.0-smoothstep(.4,1.0,edge_span*.35);
        float damp = step(.82,patch_hash)*.035*(.5+.5*sin(TIME*.12+patch_hash*6.28));
        damp = mix(.18*.035*.5,damp,patch_detail);
        color = mix(color,color*vec3(.68,.78,.86),damp);
    }
    ALBEDO = color;
    ROUGHNESS = .96;
}
