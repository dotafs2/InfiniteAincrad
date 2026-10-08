extends Node3D
## Persistent soldiers, batched visuals, individual deterministic fire clocks.
var game: Node3D
var members: Array[Dictionary] = []
var batches: Array[MultiMeshInstance3D] = []
var parts: Array[Transform3D] = []
var direction_batch: MultiMeshInstance3D
var contact_batch: MultiMeshInstance3D
var visual_tier:=-1
var next_id := 0
var shield_core:MeshInstance3D
var upgrade_rings:MultiMeshInstance3D
var hurtbox_radius:=0.30
var current_scale := 1.0
var columns := 1
var spacing := 0.8

func setup(owner_game: Node3D) -> void:
	game=owner_game
	shield_core=MeshInstance3D.new();game.add_child(shield_core)
	var quad:=PlaneMesh.new();quad.size=Vector2(0.90,0.90);shield_core.mesh=quad
	var mat:=ShaderMaterial.new();mat.shader=preload("res://assets/shaders/squad_ring.gdshader");shield_core.material_override=mat
	shield_core.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	upgrade_rings=MultiMeshInstance3D.new();game.add_child(upgrade_rings)
	var rings:=MultiMesh.new();rings.transform_format=MultiMesh.TRANSFORM_3D
	var ring_mesh:=PlaneMesh.new();ring_mesh.size=Vector2.ONE*1.6;rings.mesh=ring_mesh;rings.instance_count=36;rings.visible_instance_count=0
	upgrade_rings.multimesh=rings;upgrade_rings.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring_mat:=ShaderMaterial.new();ring_mat.shader=preload("res://assets/shaders/squad_ring.gdshader");ring_mat.set_shader_parameter("ring_color",Color(1.0,0.68,0.12,0.8));upgrade_rings.material_override=ring_mat
	reset()

func reset() -> void:
	members.clear();next_id=0
	members.append({"id":next_id,"clock":0.0,"position":Vector3.ZERO});next_id+=1
	rebuild()

func add_member() -> bool:
	if members.size()>=game.Campaign.MAX_SQUAD: return false
	members.append({"id":next_id,"clock":0.025*(next_id%8),"position":Vector3.ZERO});next_id+=1
	rebuild()
	game.metrics.soldiers+=1
	return true

func model_scale() -> float:
	var nominal:float=[2.15,1.68,0.92,0.92][game.tier]
	return nominal*lerpf(1.0,0.68,clampf((members.size()-1)/10.0,0,1))

func half_width() -> float:
	return (columns-1)*spacing*0.5+([0.35,0.62,0.92,0.92][game.tier]*current_scale)

func center_limit() -> float:
	return maxf(0.4,5.05-half_width())

func muzzle(index: int) -> Vector3:
	var height:float=[0.60,1.05,1.80,1.80][game.tier]*current_scale
	return members[index].position+Vector3(0,height,-0.40*current_scale)

func rebuild() -> void:
	columns=mini(6,ceili(sqrt(members.size())))
	current_scale=model_scale()
	spacing=[0.53,0.86,1.57,1.57][game.tier]*current_scale
	if visual_tier==game.tier and not batches.is_empty():
		for batch in batches: batch.multimesh.visible_instance_count=maxi(0,members.size()-1)
		var footprint:Dictionary=game.ShadowFootprints.DATA[["infantry","gunner","mech","mech"][game.tier]]
		direction_batch.multimesh.mesh.size=footprint.size*current_scale
		contact_batch.multimesh.mesh.size=Vector2(0.8,0.64)*current_scale
		for batch in [direction_batch,contact_batch]: batch.multimesh.visible_instance_count=maxi(0,members.size()-1)
		game.player_model.scale=Vector3.ONE*current_scale
		game._set_player_shadow();update_visuals()
		return
	visual_tier=game.tier
	for child in get_children(): remove_child(child);child.queue_free()
	batches.clear();parts.clear()
	columns=mini(6,ceili(sqrt(members.size())))
	current_scale=model_scale()
	spacing=[0.53,0.86,1.57,1.57][game.tier]*current_scale
	var proto:Node3D=game.model(["infantry","gunner","mech","mech"][game.tier])
	var meshes:Array=[];game._collect_meshes(proto,Transform3D.IDENTITY,meshes)
	for part in meshes:
		var batch:=MultiMeshInstance3D.new();var mm:=MultiMesh.new()
		mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=part.mesh;mm.instance_count=35;mm.visible_instance_count=maxi(0,members.size()-1)
		batch.multimesh=mm;add_child(batch);batches.append(batch);parts.append(part.transform)
	proto.free()
	var footprint:Dictionary=game.ShadowFootprints.DATA[["infantry","gunner","mech","mech"][game.tier]]
	direction_batch=_shadow_batch(footprint.size*current_scale,footprint.texture,0.56)
	contact_batch=_shadow_batch(Vector2(0.8,0.64)*current_scale,null,0.44)
	game.player_model.scale=Vector3.ONE*current_scale
	game._set_player_shadow()
	update_visuals()

func _shadow_batch(size: Vector2, texture: Texture2D, opacity: float) -> MultiMeshInstance3D:
	var batch:=MultiMeshInstance3D.new();var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D
	var plane:=PlaneMesh.new();plane.size=size;mm.mesh=plane;mm.instance_count=35;mm.visible_instance_count=maxi(0,members.size()-1)
	batch.multimesh=mm;batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat:=ShaderMaterial.new();mat.shader=preload("res://assets/shaders/contact_shadow.gdshader")
	mat.set_shader_parameter("use_texture",texture!=null)
	if texture: mat.set_shader_parameter("shadow_texture",texture)
	mat.set_shader_parameter("opacity",opacity);mat.set_shader_parameter("clip_to_road",true)
	batch.material_override=mat;add_child(batch);return batch

func update_visuals() -> void:
	if members.is_empty(): return
	var center:=clampf(game.player_x,-center_limit(),center_limit())
	game.player_x=center
	var fp:Dictionary=game.ShadowFootprints.DATA[["infantry","gunner","mech","mech"][game.tier]]
	for i in range(members.size()):
		var row:=i/columns;var col:=i%columns
		var row_count:=mini(columns,members.size()-row*columns)
		var position:=Vector3(center+(col-(row_count-1)*0.5)*spacing,0,game.PLAYER_Z+row*spacing*0.59)
		members[i].position=position
		if i==0:
			game.player.position=position+Vector3(0,absf(sin(game.sim_time*10))*0.018,0)
			continue
		var pose:=Transform3D(Basis(Vector3.RIGHT,sin(game.sim_time*22+i)*0.015).scaled(Vector3.ONE*current_scale),position+Vector3(0,absf(sin(game.sim_time*10+i))*0.018,0))
		for k in range(batches.size()): batches[k].multimesh.set_instance_transform(i-1,pose*parts[k])
		direction_batch.multimesh.set_instance_transform(i-1,Transform3D(Basis.IDENTITY,position+Vector3(fp.center.x*current_scale,0.018,fp.center.y*current_scale)))
		contact_batch.multimesh.set_instance_transform(i-1,Transform3D(Basis.IDENTITY,position+Vector3(0,0.025,0)))
	direction_batch.visible=game.effective_quality!="high"
	shield_core.position=hurtbox_position()+Vector3(0,0.04,0)
	upgrade_rings.multimesh.visible_instance_count=members.size() if game.upgrade_flash>0 else 0
	if game.upgrade_flash>0:
		upgrade_rings.material_override.set_shader_parameter("ring_color",Color(1.0,0.7,0.14,minf(1,game.upgrade_flash*3)))
		for i in range(members.size()):
			var ring_size:float=current_scale*(1.1+(0.8-game.upgrade_flash)*1.3)
			upgrade_rings.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*ring_size),members[i].position+Vector3(0,0.15+(0.8-game.upgrade_flash)*0.75,0)))
	game._update_player_shadow()

func step(delta: float) -> void:
	# The game updates the formation once before recruitment and firing.
	for i in range(members.size()):
		var member:Dictionary=members[i]
		member.clock-=delta
		if member.clock<=0:
			member.clock+=game.Campaign.weapon_interval(game.weapon_mode,game.tier)
			game.fire_member(i)

func right_edge() -> float:
	var edge:float=-100
	for member in members: edge=maxf(edge,member.position.x+0.25)
	return edge

func hurtbox_position() -> Vector3:
	return Vector3(game.player_x,0,game.PLAYER_Z-3.2)
