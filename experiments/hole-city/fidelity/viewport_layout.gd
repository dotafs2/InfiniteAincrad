extends RefCounted
## The world fills the screen. UI uses the full safe height with uniform targets.
const DESIGN:=Vector2(540,960)

static func fit(viewport:Vector2,safe:Rect2)->Dictionary:
	var screen:=Rect2(Vector2.ZERO,viewport)
	var area:=screen.intersection(safe)
	if not area.has_area():area=screen
	var factor:=minf(area.size.x/DESIGN.x,area.size.y/DESIGN.y)
	factor=maxf(factor,.001)
	# Tall phones expose more world and more usable UI space. Preserve the
	# authored width, but let top and bottom anchors span the actual safe height
	# instead of centering a fixed 960-unit sheet inside it.
	var canvas_size:=Vector2(DESIGN.x,area.size.y/factor)
	var at:=area.position+Vector2((area.size.x-DESIGN.x*factor)*.5,0)
	return {"position":at,"scale":Vector2.ONE*factor,"size":canvas_size,"safe":area}

static func safe_rect_from_pixels(viewport:Vector2,pixels:Vector2,physical:Rect2)->Rect2:
	var screen:=Rect2(Vector2.ZERO,viewport)
	if pixels.x<=0 or pixels.y<=0:return screen
	var ratio:=viewport/pixels
	var area:=screen.intersection(Rect2(physical.position*ratio,physical.size*ratio))
	return area if area.has_area() else screen

static func safe_rect(viewport:Vector2)->Rect2:
	if OS.get_name()!="iOS":return Rect2(Vector2.ZERO,viewport)
	var pixels:=Vector2(DisplayServer.window_get_size())
	var physical:=DisplayServer.get_display_safe_area()
	return safe_rect_from_pixels(viewport,pixels,Rect2(physical))
