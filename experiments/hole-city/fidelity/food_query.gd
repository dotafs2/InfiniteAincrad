extends RefCounted
## Exact spatial admission queries; moving/partially fallen objects remain live.
const CELL:=8.0
var cells:Dictionary={}
var body_cells:Dictionary={}
var active:Dictionary={}
func register(body:Node3D)->void:
	if body_cells.has(body.get_instance_id()) or active.has(body.get_instance_id()):return
	if not body.freeze or body.get_meta("scripted_actor",false) or body.get_meta("traffic",false):
		activate(body);return
	var at:Vector3=body.interaction_position()
	var cell:=Vector2i(floori(at.x/CELL),floori(at.z/CELL))
	if not cells.has(cell):cells[cell]=[]
	cells[cell].append(body);body_cells[body.get_instance_id()]=cell
func activate(body:Node3D)->void:
	var id:=body.get_instance_id()
	if body_cells.has(id):
		cells[body_cells[id]].erase(body);body_cells.erase(id)
	active[id]=body
func query(at:Vector3,reach:float,include_active:=true)->Array[Node3D]:
	var result:Array[Node3D]=[]
	var low:=Vector2i(floori((at.x-reach)/CELL),floori((at.z-reach)/CELL))
	var high:=Vector2i(floori((at.x+reach)/CELL),floori((at.z+reach)/CELL))
	var reach2:=reach*reach
	var search:Array=[]
	if (high.x-low.x+1)*(high.y-low.y+1)>cells.size()*2:
		for cell in cells:
			if cell.x>=low.x and cell.x<=high.x and cell.y>=low.y and cell.y<=high.y:search.append(cell)
	else:
		for x in range(low.x,high.x+1):
			for z in range(low.y,high.y+1):search.append(Vector2i(x,z))
	for cell in search:
		for body in cells.get(cell,[]):
			if not is_instance_valid(body) or body.consumed:continue
			var p:Vector3=body.interaction_position()
			if Vector2(p.x-at.x,p.z-at.z).length_squared()<=reach2:result.append(body)
	if not include_active:return result
	var expired:=[]
	for id in active:
		var body=active[id]
		if not is_instance_valid(body):expired.append(id);continue
		if body.consumed:continue
		var p:Vector3=body.interaction_position()
		if Vector2(p.x-at.x,p.z-at.z).length_squared()<=reach2:result.append(body)
	for id in expired:active.erase(id)
	return result

func scan(holes:Array)->Array[Node3D]:
	var seen:={};var result:Array[Node3D]=[]
	for hole in holes:
		if not hole.active:continue
		for body in query(hole.position,hole.radius*.9,false):
			var id:=body.get_instance_id()
			if not seen.has(id):seen[id]=true;result.append(body)
	var expired:=[]
	for id in active:
		var body=active[id]
		if not is_instance_valid(body):expired.append(id);continue
		if body.consumed:continue
		# Claims only need the cheap ownership check in scan_food. Compute each
		# unclaimed moving fixture's expensive rim position once for all holes.
		if is_instance_valid(body.claimed_by):result.append(body);continue
		var at:Vector3=body.interaction_position()
		for hole in holes:
			if hole.active and Vector2(at.x-hole.position.x,at.z-hole.position.z).length_squared()<pow(hole.radius*.9,2):
				result.append(body);break
	for id in expired:active.erase(id)
	return result
