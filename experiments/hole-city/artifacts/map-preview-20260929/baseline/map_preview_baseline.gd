extends SceneTree
## Read-only preview-state baseline from the preserved exported package.
signal frame_finished
var game:Node3D
func _initialize()->void:run.call_deferred()
func mark_frame_finished()->void:frame_finished.emit()
func natural_frames(count:int)->void:
	for i in count:
		await process_frame
		mark_frame_finished.call_deferred()
		await frame_finished
func optional_node(owner:Node,field:String)->Dictionary:
	for entry in owner.get_property_list():
		if entry.name==field:
			var value:Variant=owner.get(field)
			return {"property_exists":true,"node":value if value is Node3D and is_instance_valid(value) else null}
	return {"property_exists":false,"node":null}
func vector(value:Vector3)->Array:return [value.x,value.y,value.z]
func sample(map_id:String)->Dictionary:
	game.select_map(map_id)
	var model:Node3D=game.ui.hero_models
	var preview:Dictionary=optional_node(model,"preview")
	var pivot:Dictionary=optional_node(model,"pivot")
	var root_before:Vector3=model.rotation
	var preview_before:Variant=vector(preview.node.rotation) if preview.node!=null else null
	var pivot_before:Variant=vector(pivot.node.rotation) if pivot.node!=null else null
	var processing_before:=model.is_processing()
	var models:=model.find_children("*","MeshInstance3D",true,false)
	var batch_views:=model.find_children("*","MultiMeshInstance3D",true,false)
	var visible_batch_instances:=0
	for view in batch_views:
		if view.multimesh!=null:visible_batch_instances+=view.multimesh.instance_count if view.multimesh.visible_instance_count<0 else view.multimesh.visible_instance_count
	var counts:={"mesh_instance_nodes":models.size(),"multimesh_instance_nodes":batch_views.size(),"expanded_mesh_instance_count":models.size()+visible_batch_instances,"rigid_body_nodes":model.find_children("*","RigidBody3D",true,false).size(),"collision_shape_nodes":model.find_children("*","CollisionShape3D",true,false).size()}
	await natural_frames(30)
	var preview_after:Variant=vector(preview.node.rotation) if preview.node!=null else null
	var pivot_after:Variant=vector(pivot.node.rotation) if pivot.node!=null else null
	return {"map":map_id,"phase":game.phase,"menu_screen":game.ui.menu_screen,"hero_visible":game.ui.hero.visible,"model_script":model.get_script().resource_path,"processing_before":processing_before,"processing_after":model.is_processing(),"natural_process_frames":30,"root_rotation_before":vector(root_before),"root_rotation_after":vector(model.rotation),"root_y_delta":angle_difference(root_before.y,model.rotation.y),"preview_property_exists":preview.property_exists,"preview_node_valid":preview.node!=null,"preview_rotation_before":preview_before,"preview_rotation_after":preview_after,"preview_y_delta":angle_difference(preview_before[1],preview_after[1]) if preview.node!=null else null,"pivot_property_exists":pivot.property_exists,"pivot_node_valid":pivot.node!=null,"pivot_rotation_before":pivot_before,"pivot_rotation_after":pivot_after,"pivot_y_delta":angle_difference(pivot_before[1],pivot_after[1]) if pivot.node!=null else null,"counts":counts}
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	var samples:Array=[]
	for map_id in ["city","food"]:samples.append(await sample(map_id))
	var result:={"version":ProjectSettings.get_setting("application/config/version"),"samples":samples,"scope":"Read-only old-package home-menu process and scene structure; no rendering, screenshot, browser access, CPU timing or save mutation. Expected non-rotation is an observed baseline, not an engine error."}
	print("MAP_PREVIEW_BASELINE "+JSON.stringify(result))
	game.free();await process_frame;quit()
