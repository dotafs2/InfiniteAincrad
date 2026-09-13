// =============================================================================
// anime_style.gdshaderinc — 共享动画风格常量（唯一真源 / single source of truth）
// -----------------------------------------------------------------------------
// anime_surface.gdshader 通过 #include 引用本文件。所有预览模型共用同一个
// Shader 资源，所以：只改这里的常量，全部模型一起变。
//
// 为什么这里用 const 做共享旋钮（这是本模板的**取舍**，不是唯一正确做法）：
//   材质（ShaderMaterial）保存的是 uniform 的“当前值”。一旦材质里存了某个
//   uniform 的值，它就固定成材质自己的数据，改 shader 默认值不会影响它。
//   把风格值写成 const，就能“改一个文件、所有材质一起变”，也便于直接读代码。
//   另一种同样有效的做法是 Godot 的全局 shader uniform（global uniform +
//   Project Settings → Shader Globals），可以运行时改；本模板没有混用两套机制，
//   是为了让“谁在覆盖谁”一目了然。
//
// 声明：这不是官方《刀剑神域》着色器，也不是任何行业标准。它是一份**可扩展的
// 学习模板**（分层、共享数据、后处理怎么接），不是做完的生产级动画渲染系统；
// 行业里的 NPR 做法很多，本文件只代表其中一种简单选择。
// =============================================================================

// ---- 明暗分层（在 light() 里逐光源计算）------------------------------------
const float STYLE_THRESHOLD = 0.42;  // 亮/暗分界阈值 0..1，越大暗部越多
const float STYLE_SOFTNESS  = 0.05;  // 分层过渡宽度，越小越硬（0.005 近似硬边）
const float STYLE_HIGHLIGHT_GAIN = 1.28; // 受光段的亮度增益（1.0 = 单层平光）

// ---- 艺术化“地板”色（不是物理环境光；WorldEnvironment 的环境光已关闭）------
const vec3  STYLE_SHADOW_FLOOR   = vec3(0.30, 0.33, 0.42); // 冷调背光地板色
const float STYLE_FLOOR_STRENGTH = 0.70;                   // 0 = 完全没有地板色

// ---- 暗部 / 亮部偏色 -------------------------------------------------------
const vec3 STYLE_SHADOW_TINT = vec3(0.86, 0.90, 1.00); // 偏冷的暗部
const vec3 STYLE_LIGHT_TINT  = vec3(1.03, 1.00, 0.95); // 偏暖的亮部

// ---- 克制的镜面高光 --------------------------------------------------------
const float STYLE_SPECULAR           = 0.14; // 0 = 关闭高光
const float STYLE_SPECULAR_SHARPNESS = 40.0;

// ---- 贴图 / 顶点色强度 -----------------------------------------------------
const float STYLE_TEXTURE_STRENGTH = 1.0; // 0 = 只用纯色，1 = 完全使用原始贴图

// ---- 风（仅 V2 植被：UV2.x 权重、UV2.y 相位；其它模型由材质开关关掉）--------
const float STYLE_WIND_SCALE = 0.0; // 0 = 全场景停风（默认关，编辑低功耗；想看风改 1.0）
const float STYLE_WIND_SPEED = 1.0;

// ---- 公共函数 --------------------------------------------------------------

// 卡通分层：半 Lambert → 0..STYLE_HIGHLIGHT_GAIN 的台阶
float style_toon_ramp(float ndl) {
	float lit = clamp(ndl * 0.5 + 0.5, 0.0, 1.0);
	float soft = max(STYLE_SOFTNESS, 0.0005);
	float base = smoothstep(STYLE_THRESHOLD - soft, STYLE_THRESHOLD + soft, lit);
	float upper = smoothstep(STYLE_THRESHOLD + 0.20, STYLE_THRESHOLD + 0.20 + soft, lit);
	return base + upper * (STYLE_HIGHLIGHT_GAIN - 1.0);
}

// 亮暗偏色
vec3 style_tint(float ramp) {
	return mix(STYLE_SHADOW_TINT, STYLE_LIGHT_TINT, clamp(ramp, 0.0, 1.0));
}
