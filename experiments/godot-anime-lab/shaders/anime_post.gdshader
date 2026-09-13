// =============================================================================
// anime_post.gdshader — 可选的、克制的深度描边 + 轻微饱和度后处理
// -----------------------------------------------------------------------------
// 挂在相机前的 2x2 全屏四边形上，是 spatial 后处理：
//   * Godot 4.3+ 反向 Z：POSITION = vec4(VERTEX.xy, 1.0, 1.0) 直接给出裁剪空间坐标；
//   * 深度用 INV_PROJECTION_MATRIX 线性化，只看相对深度差 —— 只描轮廓，不做整屏
//     色阶海报化（那是另一种做法，本模板不采用）；
//   * 不做全屏法线描边（植被法线很吵，会满屏噪线）；
//   * 采样的是“不透明通道之后、透明通道之前”的屏幕纹理，所以它不是最终合成器：
//     看不到之后绘制的半透明物。见 README 的限制说明。
// 标签：Forward+ 专用写法（ANIME_POST_LABEL）。
// =============================================================================
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, shadows_disabled, fog_disabled, blend_mix;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform float outline_strength : hint_range(0.0, 1.0) = 0.45;
uniform float outline_thickness : hint_range(0.25, 4.0) = 1.2;
uniform vec3  outline_color : source_color = vec3(0.07, 0.06, 0.10);
uniform float saturation : hint_range(0.0, 2.0) = 1.08;

// 注意：Godot 的内建变量（INV_PROJECTION_MATRIX 等）只能在它所属的函数里使用，
// 所以这里必须把矩阵当参数传进来，不能在 helper 里直接引用。
float post_linear_depth(vec2 uv, mat4 inv_projection) {
	float d = texture(depth_tex, uv).r;
	vec4 view = inv_projection * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -(view.z / view.w);
}

void vertex() {
	// 四边形 local 坐标是 ±1：直接写裁剪空间坐标。反向 Z 下 z=w=1 就是最近平面，
	// 所以它永远贴满相机、不受相机变换与投影影响。
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	// 用深度纹理自身尺寸算步长：不依赖 SCREEN_PIXEL_SIZE/VIEWPORT_SIZE 这些内建名。
	vec2 texel = outline_thickness / vec2(textureSize(depth_tex, 0));
	float center = post_linear_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
	float d1 = post_linear_depth(SCREEN_UV + vec2(texel.x, 0.0), INV_PROJECTION_MATRIX);
	float d2 = post_linear_depth(SCREEN_UV - vec2(texel.x, 0.0), INV_PROJECTION_MATRIX);
	float d3 = post_linear_depth(SCREEN_UV + vec2(0.0, texel.y), INV_PROJECTION_MATRIX);
	float d4 = post_linear_depth(SCREEN_UV - vec2(0.0, texel.y), INV_PROJECTION_MATRIX);
	// 相对深度差：远处同样的强度也会被压小，减少噪线
	float ref = max(center, 0.001);
	float edge = (abs(d1 - center) + abs(d2 - center) + abs(d3 - center) + abs(d4 - center)) / ref;
	edge = smoothstep(0.06, 0.26, edge) * outline_strength;

	vec3 col = texture(screen_tex, SCREEN_UV).rgb;
	float luma = dot(col, vec3(0.2126, 0.7152, 0.0722));
	col = mix(vec3(luma), col, saturation);
	ALBEDO = mix(col, outline_color, clamp(edge, 0.0, 1.0));
	ALPHA = 1.0; // 写在透明通道 = 屏幕纹理之后绘制；材质 render_priority 取负值先画
}
