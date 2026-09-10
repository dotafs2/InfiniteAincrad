extends Control
## Native vector scenery. All counters are supplied by the authoritative kernel.
const SKY := Color("d5e2e6")
const INK := Color("243946")
const STONE := Color("adb8b3")
const WATER := Color("418ba4")
const COPPER := Color("ae704a")
const LEAF := Color("718d76")

var well_water := 0
var carried_water := 0
var consumed_water := 0
var enabled := false
var activity := "井水够不到，先想想办法。"
var motion := true
var pulse := 0.0
var font: Font

func _ready() -> void:
	custom_minimum_size = Vector2(540, 405)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Noto Sans CJK SC", "Arial"])
	set_process(false)

func update_world(water: int, carried: int, consumed: int, active: bool, caption: String) -> void:
	well_water = water
	carried_water = carried
	consumed_water = consumed
	enabled = active
	activity = caption
	pulse = 1.0 if motion else 0.0
	set_process(motion)
	queue_redraw()

func _process(delta: float) -> void:
	pulse = maxf(0.0, pulse - delta * 0.7)
	queue_redraw()
	if pulse == 0.0:
		set_process(false)

func _polygon(vertices: Array, tint: Color) -> void:
	draw_colored_polygon(PackedVector2Array(vertices), tint)

func _text(at: Vector2, value: String, pixels: int = 16, tint: Color = INK) -> void:
	draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, tint)

func _draw() -> void:
	if not font:
		return
	var factor := minf(size.x / 720.0, size.y / 450.0)
	draw_set_transform(Vector2((size.x - 720.0 * factor) / 2.0, 0), 0, Vector2.ONE * factor)
	draw_rect(Rect2(0, 0, 720, 450), SKY)
	draw_circle(Vector2(579, 75), 38, Color("ecede0"))
	# A quiet courtyard above a visible well section: the water has a place.
	_polygon([Vector2(0, 180), Vector2(0, 102), Vector2(155, 70), Vector2(266, 135), Vector2(266, 210)], Color("bacacb"))
	_polygon([Vector2(477, 173), Vector2(477, 110), Vector2(639, 81), Vector2(720, 124), Vector2(720, 205)], Color("bccdcc"))
	draw_rect(Rect2(28, 165, 186, 108), Color("d9d9ca"))
	_polygon([Vector2(7, 171), Vector2(114, 111), Vector2(235, 171)], Color("687584"))
	draw_rect(Rect2(82, 207, 42, 66), Color("87918a"))
	draw_rect(Rect2(146, 196, 32, 34), Color("677b82"))
	draw_line(Vector2(162, 196), Vector2(162, 230), Color("e1dfcc"), 3)
	draw_line(Vector2(146, 213), Vector2(178, 213), Color("e1dfcc"), 3)
	draw_rect(Rect2(519, 176, 169, 100), Color("d7d6c8"))
	_polygon([Vector2(502, 181), Vector2(597, 131), Vector2(711, 181)], Color("79818b"))
	draw_rect(Rect2(557, 211, 39, 65), Color("a4a895"))
	draw_rect(Rect2(634, 205, 24, 34), Color("7c9293"))
	draw_rect(Rect2(0, 274, 720, 61), Color("c2c5b6"))
	for row in range(3):
		for col in range(10):
			var x := col * 86 - (40 if row % 2 == 0 else 0)
			draw_line(Vector2(x, 281 + row * 20), Vector2(x + 68, 281 + row * 20), Color("acb5ab"), 1)
	draw_rect(Rect2(0, 335, 720, 115), Color("344b58"))
	_text(Vector2(27, 362), "井下剖面 / 有限的水", 15, Color("d2e3e6"))
	# Well stonework, opening and the gated bucket rig.
	draw_rect(Rect2(295, 267, 130, 125), Color("788c92"))
	draw_rect(Rect2(308, 287, 104, 111), Color("263f4e"))
	var level := minf(float(well_water), 1.0) * 58.0
	draw_rect(Rect2(312, 394 - level, 96, level), WATER)
	for i in range(3):
		draw_line(Vector2(317 + i * 30, 400 - level), Vector2(336 + i * 30, 400 - level), Color("b6d8dc"), 2)
	draw_style_box(_well_rim(), Rect2(285, 258, 150, 35))
	draw_arc(Vector2(360, 270), 52, 0, PI, 32, Color("607c87"), 5, true)
	if enabled:
		draw_line(Vector2(292, 274), Vector2(292, 182), COPPER, 8)
		draw_line(Vector2(427, 274), Vector2(427, 182), COPPER, 8)
		draw_line(Vector2(288, 182), Vector2(431, 182), COPPER, 9)
		draw_circle(Vector2(360, 186), 12, Color("47535c"))
		draw_arc(Vector2(360, 186), 9, 0, TAU, 24, Color("d6b182"), 3, true)
		var bucket_y := 242.0 + sin(pulse * PI) * 43.0
		draw_line(Vector2(360, 186), Vector2(360, bucket_y), Color("dab785"), 3)
		_polygon([Vector2(348, bucket_y), Vector2(372, bucket_y), Vector2(368, bucket_y + 23), Vector2(352, bucket_y + 23)], Color("b28660"))
		draw_line(Vector2(350, bucket_y + 9), Vector2(370, bucket_y + 9), Color("526978"), 3)
	# Focus resident, same fixture identity before and after installation.
	var person := Vector2(469, 279)
	draw_set_transform(Vector2((size.x - 720.0 * factor) / 2.0, 0) + person * factor, 0, Vector2.ONE * factor)
	draw_ellipse_shadow()
	draw_line(Vector2(-7, 5), Vector2(-9, 19), INK, 6)
	draw_line(Vector2(7, 5), Vector2(11, 19), INK, 6)
	_polygon([Vector2(-12, -34), Vector2(12, -34), Vector2(17, 8), Vector2(-17, 8)], Color("786883"))
	draw_circle(Vector2(0, -46), 13, Color("554e60"))
	draw_circle(Vector2(0, -42), 10, Color("dcb99c"))
	draw_arc(Vector2(0, -46), 13, PI, TAU, 20, Color("554e60"), 8, true)
	draw_line(Vector2(-11, -27), Vector2(-21, -6), Color("786883"), 7)
	draw_line(Vector2(11, -27), Vector2(22, -6), Color("786883"), 7)
	if carried_water > 0:
		draw_rect(Rect2(18, -7, 15, 15), WATER)
		draw_arc(Vector2(25.5, -7), 7, PI, TAU, 12, Color("c9dbe0"), 2, true)
	draw_set_transform(Vector2((size.x - 720.0 * factor) / 2.0, 0), 0, Vector2.ONE * factor)
	_text(Vector2(441, 222), "Luna", 17)
	for pot_x in [47, 666]:
		draw_rect(Rect2(pot_x, 291, 23, 24), COPPER)
		draw_line(Vector2(pot_x + 11, 293), Vector2(pot_x + 11, 259), LEAF, 4)
		draw_circle(Vector2(pot_x + 4, 274), 10, LEAF)
		draw_circle(Vector2(pot_x + 20, 266), 10, LEAF)
	_text(Vector2(30, 40), "独立试验庭院", 19)
	_text(Vector2(30, 64), "测试居民 · 并非原档迁移", 14, Color("526975"))
	_text(Vector2(28, 390), "井内 %d  +  随身 %d  +  已饮用 %d" % [well_water, carried_water, consumed_water], 17, Color("e4eff0"))
	_text(Vector2(28, 419), activity, 15, Color("c4d5d9"))

func draw_ellipse_shadow() -> void:
	draw_circle(Vector2(0, 15), 20, Color(0.17, 0.25, 0.27, 0.12))

func _well_rim() -> StyleBoxFlat:
	var rim := StyleBoxFlat.new()
	rim.bg_color = STONE
	rim.border_color = Color("789095")
	rim.set_border_width_all(3)
	rim.set_corner_radius_all(12)
	return rim
