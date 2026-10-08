extends "res://fidelity/rim_body.gd"
## Coupling changes ownership of scripted motion, never the swallowing rules.
var train:WeakRef
var train_index:=-1
var attached:=true
var route_distance:=0.0

func uncouple()->void:
	if not attached:return
	var controller=train.get_ref() if train!=null else null
	if controller!=null:controller.detach_from(train_index)
	else:attached=false

func begin_swallow(hole:Node3D)->bool:
	if not can_fit(hole):return false
	uncouple()
	return super.begin_swallow(hole)

func begin_pull(hole:Node3D)->bool:
	if not can_fit(hole):return false
	uncouple()
	return super.begin_pull(hole)
