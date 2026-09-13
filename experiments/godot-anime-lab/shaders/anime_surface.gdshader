// =============================================================================
// anime_surface.gdshader — 逐表面（per-surface）动画/卡通表面着色器
// -----------------------------------------------------------------------------
// 职责：
//   1. fragment() 只决定“表面本身是什么”：顶点色 × 贴图 × 材质色、剪影 alpha、
//      法线方向、粗糙度/高光强度提示。这里不做任何屏幕空间处理。
//   2. light() 逐光源做 Lambert 卡通分层：DIFFUSE_LIGHT += ramp * 偏色 *
//      LIGHT_COLOR / PI。ALBEDO 不在这里重复相乘——引擎会把光贡献与 ALBEDO
//      组合（官方文档的 light() 约定），重复乘会让颜色发暗/发灰。
//   3. 风格旋钮全部来自 anime_style.gdshaderinc 的 const，材质不覆盖它们，
//      所以改一个文件就能让所有预览模型一起变。
//
// 本 shader 不是官方 SAO 着色器，也不是行业标准；只是本项目自用的一套风格模板。
// =============================================================================
shader_type spatial;
// cull_disabled：V2 植被是双面叶簇，需要背面可见；房屋是闭合体，关掉剔除只是
// 多画一层背面，不影响正确性（法线是否翻转由 material_two_sided_normal 控制）。
render_mode cull_disabled;

#include "res://shaders/anime_style.gdshaderinc"

uniform sampler2D material_albedo : source_color, hint_default_white, filter_linear_mipmap_anisotropic;
uniform sampler2D material_normal : hint_normal, filter_linear_mipmap;
uniform vec4  material_tint : source_color = vec4(1);          // 材质基色（乘在顶点色/贴图上）
uniform float material_use_texture : hint_range(0.0, 1.0) = 0.0; // 1 = 使用 material_albedo
uniform float material_texture_strength : hint_range(0.0, 1.0) = 1.0; // 与 STYLE_TEXTURE_STRENGTH 相乘
uniform float material_use_vertex_color : hint_range(0.0, 1.0) = 1.0; // V2/住宅用 COLOR 作为底色
uniform float material_normal_strength : hint_range(0.0, 1.0) = 0.0;  // 法线贴图默认关闭（避免噪带）
uniform float material_two_sided_normal : hint_range(0.0, 1.0) = 0.0; // 植被背面翻转法线
uniform float material_alpha_scissor : hint_range(0.0, 1.0) = 0.0;    // 1 = 用 discard 做 alpha 裁剪
uniform float material_alpha_threshold : hint_range(0.0, 1.0) = 0.5;
uniform float material_wind : hint_range(0.0, 1.0) = 0.0;             // 1 = 该材质随 UV2 摆动
uniform float material_roughness : hint_range(0.0, 1.0) = 0.85;
uniform float material_specular : hint_range(0.0, 1.0) = 0.35;

void vertex() {
	// V2 植被风：UV2.x = 柔韧权重，UV2.y = 相位，UV.y = 叶尖。数据来自资产本身。
	// 非植被材质 material_wind = 0，顶点完全不动。
	if (material_wind > 0.0 && STYLE_WIND_SCALE > 0.0) {
		float t = TIME * STYLE_WIND_SPEED;
		vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float anchor = smoothstep(0.015, 0.22, VERTEX.y); // 越靠近根部越不动
		float weight = UV2.x * anchor * material_wind * STYLE_WIND_SCALE;
		float gust = sin(t * 0.73 + world.x * 0.18 + world.z * 0.13);
		float sway = sin(t * 1.55 + world.x * 0.45 + world.z * 0.31) + 0.28 * gust;
		float flutter = sin(t * 4.2 + UV2.y * 6.28318 + world.x * 1.3) * UV.y * 0.014;
		VERTEX.x += weight * (sway * 0.072 + flutter);
		VERTEX.z += weight * (sway * 0.038 - flutter * 0.7);
		VERTEX.y -= weight * abs(sway) * 0.008;
	}
}

void fragment() {
	vec3 base = material_tint.rgb;
	if (material_use_vertex_color > 0.5) {
		base *= COLOR.rgb;
	}
	if (material_use_texture > 0.5) {
		vec4 tex = texture(material_albedo, UV);
		if (material_alpha_scissor > 0.5 && tex.a < material_alpha_threshold) {
			discard; // alpha 裁剪走 discard，保持不透明通道（否则描边拿不到深度）
		}
		float k = clamp(STYLE_TEXTURE_STRENGTH * material_texture_strength, 0.0, 1.0);
		base = mix(base, base * tex.rgb, k);
	} else if (material_alpha_scissor > 0.5 && COLOR.a < material_alpha_threshold) {
		discard;
	}
	ALBEDO = base;

	// 艺术化地板色：环境光在 WorldEnvironment 里被显式关闭，这里用 EMISSION 自己
	// 加一层“作者指定的暗部地板”（等价于 ambient = albedo * 地板色，但由本文件掌控）。
	// 没有光源时模型也不会全黑；这不代表物理环境光，README 里写明。
	EMISSION = ALBEDO * STYLE_SHADOW_FLOOR * STYLE_FLOOR_STRENGTH;

	if (material_normal_strength > 0.0) {
		NORMAL_MAP = texture(material_normal, UV).rgb;
		NORMAL_MAP_DEPTH = material_normal_strength;
	}
	if (material_two_sided_normal > 0.5 && !FRONT_FACING) {
		NORMAL = -NORMAL; // 植被双面：背面法线翻转，避免背面全黑
	}
	ROUGHNESS = material_roughness;
	SPECULAR = material_specular;
}

void light() {
	float ndl = dot(normalize(NORMAL), normalize(LIGHT));
	float ramp = style_toon_ramp(ndl);
	vec3 tint = style_tint(ramp);
	// 引擎会在本函数返回后把光贡献与 ALBEDO 组合，所以这里不再乘 ALBEDO。
	DIFFUSE_LIGHT += ramp * tint * LIGHT_COLOR * ATTENUATION / PI;
	if (STYLE_SPECULAR > 0.0) {
		vec3 half_vec = normalize(normalize(LIGHT) + normalize(VIEW));
		float s = pow(max(dot(normalize(NORMAL), half_vec), 0.0), STYLE_SPECULAR_SHARPNESS);
		SPECULAR_LIGHT += s * STYLE_SPECULAR * LIGHT_COLOR * ATTENUATION / PI * step(0.02, ramp);
	}
}
