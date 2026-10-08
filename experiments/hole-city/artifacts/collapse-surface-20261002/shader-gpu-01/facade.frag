#version 150
uniform bool probe_bool_shadow = false;
// Translate the probe readback pixel through one complete Bayer tile. The
// actual shipped threshold and fragment discard execute without replacement.
uniform vec2 probe_pixel_offset = vec2(0.0);
#define IN_SHADOW_PASS probe_bool_shadow
#define FRAGCOORD vec4(gl_FragCoord.xy + probe_pixel_offset, gl_FragCoord.zw)
const bool OUTPUT_IS_SRGB = true;
uniform float TIME = 0.0;
uniform vec3 VERTEX = vec3(0.0);
uniform vec4 INSTANCE_CUSTOM = vec4(0.0);
uniform vec4 COLOR = vec4(0.8, 0.4, 0.2, 1.0);
uniform vec3 NORMAL = vec3(0.0, 1.0, 0.0);
uniform vec3 VIEW = vec3(0.0, 1.0, 0.0);
uniform vec2 UV = vec2(0.3);
uniform vec2 UV2 = vec2(0.3);
uniform vec2 SCREEN_UV = vec2(0.5);
uniform vec2 VIEWPORT_SIZE = vec2(64.0);
uniform vec3 CAMERA_POSITION_WORLD = vec3(0.0, 18.0, 14.0);
uniform vec3 CAMERA_DIRECTION_WORLD = vec3(0.0, -1.0, 0.0);
uniform mat4 MODEL_MATRIX = mat4(1.0);
uniform mat3 MODEL_NORMAL_MATRIX = mat3(1.0);
uniform mat4 VIEW_MATRIX = mat4(1.0);
uniform mat4 INV_VIEW_MATRIX = mat4(1.0);
uniform mat4 MAIN_CAM_INV_VIEW_MATRIX = mat4(1.0);
uniform mat4 PROJECTION_MATRIX = mat4(1.0);
uniform mat4 INV_PROJECTION_MATRIX = mat4(1.0);
vec3 ALBEDO = vec3(1.0);
vec3 EMISSION = vec3(0.0);
float ROUGHNESS = 1.0;
float METALLIC = 0.0;
float SPECULAR = 0.5;
float ALPHA = 1.0;
out vec4 probe_color;

uniform vec4 wall_color= vec4(0.6,0.31,0.22,1.0);
uniform vec4 glass_color= vec4(0.26,0.48,0.59,1.0);
uniform float floors=4.0;
uniform float columns=3.0;
uniform bool glass_tower=false;
uniform float visibility=1.0;
uniform vec3 local_normal;

// FILTERING_HELPERS_BEGIN
float coverage_integral(float x, float duty) {
    return floor(x) * duty + min(fract(x), duty);
}
float coverage_repeat(float x, float begin, float width, float period, float pixel_span) {
    float span = max(pixel_span / period, 0.0001);
    float center = (x - begin) / period;
    float duty = clamp(width / period, 0.0, 1.0);
    return clamp((coverage_integral(center + span * 0.5, duty) - coverage_integral(center - span * 0.5, duty)) / span, 0.0, 1.0);
}
// FILTERING_HELPERS_END


void shipped_fragment() {
    vec2 grid = UV*vec2(columns,floors);
    // Differentiate continuous UV coordinates, never the discontinuous cell.
    vec2 pixel_span = fwidth(grid);
    vec2 id = floor(grid);
    float window_hash = fract(sin(dot(id,vec2(12.9898,78.233)))*43758.5453);
    float side = 1.0-step(.7,abs(local_normal.y));
    vec2 opening_half = glass_tower ? vec2(.47,.48) : vec2(.27,.34);
    vec2 frame_half = glass_tower ? vec2(.49,.50) : vec2(.31,.38);
    vec2 open_axis = vec2(coverage_repeat(grid.x,.5-opening_half.x,2.0*opening_half.x,1.0,pixel_span.x),
                         coverage_repeat(grid.y,.5-opening_half.y,2.0*opening_half.y,1.0,pixel_span.y));
    float opening = open_axis.x * open_axis.y * side;
    float frame = coverage_repeat(grid.x,.5-frame_half.x,2.0*frame_half.x,1.0,pixel_span.x)
                * coverage_repeat(grid.y,.5-frame_half.y,2.0*frame_half.y,1.0,pixel_span.y) * side;
    // Integrate pane subdivisions only inside the window. Multiplying two
    // independently filtered masks would change its average color at distance.
    float shade_x = coverage_repeat(grid.x,.48,.5+opening_half.x-.48,1.0,pixel_span.x);
    float shade_y = coverage_repeat(grid.y,.66,.5+opening_half.y-.66,1.0,pixel_span.y);
    float shade_area = shade_x * open_axis.y * side;
    float top_area = open_axis.x * shade_y * side;
    float shade_top_area = shade_x * shade_y * side;
    // Cell-specific animation is resolved nearby, then approaches its mean
    // before cells become subpixel. Window/frame coverage itself is retained.
    float cell_detail = 1.0-smoothstep(.35,1.0,max(pixel_span.x,pixel_span.y));
    float window_pulse = mix(.72,.72+.28*sin(TIME*(.25+window_hash*.18)+window_hash*6.28318),cell_detail);
    vec3 neon = mix(vec3(.18,.72,.95),vec3(1.0,.36,.12),mix(.43,step(.57,window_hash),cell_detail));
    float cross_x = coverage_repeat(grid.x,.482,.036,1.0,pixel_span.x);
    float cross_y = coverage_repeat(grid.y,.482,.036,1.0,pixel_span.y);
    float cross_area = (cross_x*open_axis.y + cross_y*open_axis.x - cross_x*cross_y) * side;
    // The vertical bar is wholly in the shaded half; the horizontal bar is
    // below the top highlight. These intersections preserve the original art.
    float cross_shade = (cross_x*open_axis.y + cross_y*shade_x - cross_x*cross_y) * side;
    float cross_top = cross_x*shade_y*side;
    vec3 pane_area = glass_color.rgb*(opening-.36*shade_area+.10*top_area+.144*shade_top_area) + neon*.10*window_pulse*opening;
    vec3 cross_pane_area = glass_color.rgb*(cross_area-.36*cross_shade+.244*cross_top) + neon*.10*window_pulse*cross_area;
    vec3 color = wall_color.rgb*(1.0-frame) + vec3(.68,.64,.54)*(frame-opening)
               + pane_area - .65*cross_pane_area + vec3(.61,.62,.57)*.65*cross_area;
    ALBEDO=color; ROUGHNESS=mix(.88,.3,opening); EMISSION=neon*.07*window_pulse*opening; ALPHA=visibility;
}

void main(){shipped_fragment();probe_color=vec4(1.0);}
