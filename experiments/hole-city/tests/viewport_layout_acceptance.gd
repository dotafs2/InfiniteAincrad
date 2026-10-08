extends SceneTree
## Tall-phone safe-area geometry and input transforms, independent of the world.
## Physical dimensions below come from the preserved iPhone16 Pro Max QA report;
## this fixture does not establish that a new native binary is installed.
const Layout=preload("res://fidelity/viewport_layout.gd")
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:
	check(ProjectSettings.get_setting("display/window/stretch/mode")=="canvas_items","The full-resolution canvas does not letterbox the 3D world")
	check(ProjectSettings.get_setting("display/window/stretch/aspect")=="expand","Root rendering expands across the portrait screen")
	check(ProjectSettings.get_setting("display/window/handheld/orientation")==1,"Native orientation remains portrait")
	var physical:=Rect2(0,186,1320,2580)
	var safe_points:=Layout.safe_rect_from_pixels(Vector2(440,956),Vector2(1320,2868),physical)
	check(safe_points.is_equal_approx(Rect2(0,62,440,860)),"Retina safe pixels map once into 440x956 points")
	for viewport in [Vector2(440,956),Vector2(1320,2868),Vector2(540,1173)]:
		var safe:=Layout.safe_rect_from_pixels(viewport,Vector2(1320,2868),physical)
		var layout:=Layout.fit(viewport,safe)
		var bounds:=Rect2(layout.position,layout.size*layout.scale)
		check(bounds.position.is_equal_approx(safe.position),"Phone canvas begins at the real safe top: "+str(viewport))
		check(bounds.size.is_equal_approx(safe.size),"Phone canvas consumes the entire safe height and width: "+str(viewport))
		check(layout.size.y>1055.0 and layout.size.y<1056.0,"Tall phone provides extra logical room instead of a centered 960-unit sheet: "+str(viewport))
		check(layout.scale.x==layout.scale.y and is_equal_approx(layout.size.x,540),"Phone controls preserve shape and authored width: "+str(viewport))
		var transform:=Transform2D(Vector2(layout.scale.x,0),Vector2(0,layout.scale.y),layout.position)
		for point in [Vector2(24,24),Vector2(270,layout.size.y*.5),Vector2(516,layout.size.y-24)]:
			var projected:Vector2=transform*point
			check(safe.has_point(projected) and (transform.affine_inverse()*projected).is_equal_approx(point),"Top, center and bottom touches stay inside safe bounds and round-trip: "+str(viewport)+" / "+str(point))
	for viewport in [Vector2(540,960),Vector2(390,844),Vector2(768,1024),Vector2(960,540)]:
		var safe:=Rect2(Vector2(12,24),viewport-Vector2(24,48))
		var layout:=Layout.fit(viewport,safe)
		var bounds:=Rect2(layout.position,layout.size*layout.scale)
		check(safe.grow(.001).encloses(bounds),"Short, tablet and landscape layouts remain wholly safe: "+str(viewport))
		check(is_equal_approx(bounds.position.y,safe.position.y) and is_equal_approx(bounds.end.y,safe.end.y),"Canvas anchors retain both safe edges: "+str(viewport))
		check(layout.scale.x==layout.scale.y and layout.size.y>=959.99,"Short screens fit without stretching touch targets: "+str(viewport))
	check(Layout.safe_rect_from_pixels(Vector2(440,956),Vector2.ZERO,physical)==Rect2(0,0,440,956),"An unavailable native pixel size falls back to the full viewport")
	check(Layout.safe_rect_from_pixels(Vector2(440,956),Vector2(1320,2868),Rect2())==Rect2(0,0,440,956),"A not-yet-populated native safe area has a valid startup fallback")
	var clamped:=Layout.safe_rect_from_pixels(Vector2(440,956),Vector2(1320,2868),Rect2(-30,180,1380,2760))
	check(clamped.is_equal_approx(Rect2(0,60,440,896)),"A physical rectangle is clipped to the actual viewport")
	var outside:=Layout.fit(Vector2(440,956),Rect2(900,900,50,50))
	check(outside.safe==Rect2(0,0,440,956) and outside.position==Vector2.ZERO,"A disjoint safe rectangle cannot move the UI outside the screen")
	print("VIEWPORT_LAYOUT_ACCEPTANCE "+JSON.stringify({"checks":checks,"failures":failures,"ok":failures.is_empty(),"physical_new_build_verified":false}))
	quit(0 if failures.is_empty() else 1)
