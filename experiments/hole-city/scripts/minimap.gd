extends Control
var game: Node
var redraw_clock := 0.0

func _process(delta: float) -> void:
	redraw_clock -= delta
	if redraw_clock <= 0.0:
		redraw_clock = 0.12
		queue_redraw()

func point(at: Vector3) -> Vector2:
	return Vector2(at.x+39.0,at.z+39.0)/78.0*size

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("1d3944"))
	for lane in [-32.0,-16.0,0.0,16.0,32.0]:
		var p: float = (lane+39.0)/78.0
		draw_line(Vector2(p*size.x,0),Vector2(p*size.x,size.y),Color("34525a"),3.0)
		draw_line(Vector2(0,p*size.y),Vector2(size.x,p*size.y),Color("34525a"),3.0)
	if not is_instance_valid(game.city) or not is_instance_valid(game.player):return
	for item in game.city.foods:
		if not is_instance_valid(item) or item.consumed or is_instance_valid(item.claimed_by):continue
		var tint := Color("8ac1ae") if item.can_fit(game.player) else Color("597079")
		draw_circle(point(item.global_position),1.2,tint)
	for h in game.holes:
		if not h.active:continue
		var r := maxf(3.5,h.radius/78.0*size.x)
		draw_circle(point(h.global_position),r,h.color)
		draw_circle(point(h.global_position),r*0.58,Color("122b38"))
