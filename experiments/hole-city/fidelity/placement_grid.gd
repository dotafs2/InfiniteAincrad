extends RefCounted
## Startup-only spatial index for physical footprints. No per-frame scans.
const CELL:=4.0
var cells:Dictionary={}
var bounds:Dictionary={}
func keys(rect:Rect2)->Array[Vector2i]:
	var result:Array[Vector2i]=[]
	for x in range(floori(rect.position.x/CELL),floori(rect.end.x/CELL)+1):
		for y in range(floori(rect.position.y/CELL),floori(rect.end.y/CELL)+1):result.append(Vector2i(x,y))
	return result
func put(id:int,rect:Rect2)->void:
	if bounds.has(id):
		for key in keys(bounds[id]):cells[key].erase(id)
	bounds[id]=rect
	for key in keys(rect):
		if not cells.has(key):cells[key]=[]
		cells[key].append(id)
func clear_at(rect:Rect2,exclude:Array)->bool:
	for key in keys(rect):
		for id in cells.get(key,[]):
			if id not in exclude and rect.intersects(bounds[id]):return false
	return true
