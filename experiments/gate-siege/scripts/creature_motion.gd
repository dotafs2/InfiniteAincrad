extends RefCounted
## Manual articulated motion shares gameplay time, including pause and death.
static func find(node: Node, wanted: String) -> Node3D:
	if node is Node3D and String(node.name).begins_with(wanted): return node
	for child in node.get_children():
		var result=find(child,wanted)
		if result: return result
	return null
static func pose(node: Node3D, kind: String, clock: float, attack: float=0.0, death: float=0.0) -> void:
	if kind in ["dragon","drake"]:
		var left:=find(node,"WingL");var right:=find(node,"WingR");var tail:=find(node,"Tail")
		var flap:=sin(clock*6.4)*0.58+0.16
		if left: left.rotation.z=-flap;left.rotation.x=-0.65
		if right: right.rotation.z=flap;right.rotation.x=-0.65
		if tail: tail.rotation.y=sin(clock*3.2)*0.20
		node.position.y=0.85+sin(clock*3.2)*0.12+attack*0.15
		node.rotation.x=sin(clock*3.2)*0.04+attack*0.16
	elif kind in ["golem","shield"]:
		for side in ["L","R"]:
			var sign:float=-1 if side=="L" else 1
			var arm:=find(node,"Arm"+side);var leg:=find(node,"Leg"+side)
			if arm: arm.rotation.x=sin(clock*5.2)*0.12*sign-attack*1.1
			if leg: leg.rotation.x=sin(clock*5.2)*0.20*sign
	else:
		for side in ["L","R"]:
			for i in range(3):
				var leg:=find(node,"Leg"+side+str(i))
				if leg: leg.rotation.y=sin(clock*11+i*PI*0.66+(0 if side=="L" else PI))*0.28
		node.position.y=absf(sin(clock*11))*0.045
	if death>0:
		node.rotation.z=death*1.4
		node.position.y-=death*1.1
