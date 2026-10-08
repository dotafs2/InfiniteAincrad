extends SceneTree
## Isolated GPU contact sheet; does not instantiate gameplay or edit source assets.
var frames:=0
var reports:Array=[]
var panels:Array[SubViewport]=[]
var font=preload("res://assets/fonts/Barlow-ExtraBold.ttf")
const W:=384
const H:=350

func _initialize() -> void:
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.size=Vector2i(W*4,H*3)
	root.content_scale_size=Vector2i(W*4,H*3)
	DisplayServer.window_set_size(root.size)
	var bg:=ColorRect.new();bg.color=Color("17212d");bg.size=Vector2(root.size);root.add_child(bg)
	var specs=[
		["Original crowd · 1,948 tris","models/zombie",false],
		["Near · 320 tris · one surface","mobile/zombie_near",false],
		["Mid · 144 tris · one surface","mobile/zombie_mid",false],
		["Far · 66 tris · one surface","mobile/zombie_far",false],
		["Original infantry · 3,410 tris","models/infantry",false],
		["Mobile infantry · 2,199 tris","mobile/infantry",false],
		["Original gunner · 14,308 / 12 surfaces","models/gunner",false],
		["Mobile gunner · 3,599 / 2 surfaces","mobile/gunner",false],
		["Original mech · 14,256 / 7 surfaces","models/mech",false],
		["Mobile mech · 3,700 / 3 surfaces","mobile/mech",false],
		["Near · 180 actual MultiMesh instances","mobile/zombie_near",true],
		["Far · 180 actual MultiMesh instances","mobile/zombie_far",true]]
	for i in range(specs.size()):
		make_panel(i,specs[i][0],specs[i][1],specs[i][2])

func find_mesh(n:Node) -> MeshInstance3D:
	if n is MeshInstance3D:return n
	for c in n.get_children():
		var found=find_mesh(c)
		if found:return found
	return null

func inspect_mesh(n:Node,key:String) -> Dictionary:
	var mesh:=find_mesh(n)
	assert(mesh!=null,key)
	var triangles:=0
	var flags:Array=[]
	for s in range(mesh.mesh.get_surface_count()):
		var arrays:=mesh.mesh.surface_get_arrays(s)
		triangles+=arrays[Mesh.ARRAY_INDEX].size()/3 if arrays[Mesh.ARRAY_INDEX]!=null and not arrays[Mesh.ARRAY_INDEX].is_empty() else arrays[Mesh.ARRAY_VERTEX].size()/3
		var mat:=mesh.get_active_material(s) as StandardMaterial3D
		assert(mat!=null,key)
		var has_colors:bool=arrays[Mesh.ARRAY_COLOR]!=null and not arrays[Mesh.ARRAY_COLOR].is_empty()
		flags.append({"surface":s,"has_colors":has_colors,"import_vertex_albedo":mat.vertex_color_use_as_albedo,"import_srgb":mat.vertex_color_is_srgb,"metallic":mat.metallic,"roughness":mat.roughness})
		if has_colors:
			mat.vertex_color_use_as_albedo=true
			mat.vertex_color_is_srgb=false
	var aabb:=mesh.mesh.get_aabb()
	return {"key":key,"triangles":triangles,"surfaces":mesh.mesh.get_surface_count(),"aabb_min":[aabb.position.x,aabb.position.y,aabb.position.z],"aabb_max":[aabb.end.x,aabb.end.y,aabb.end.z],"materials":flags}

func make_panel(i:int,title:String,key:String,batch:bool) -> void:
	var origin:=Vector2((i%4)*W,(i/4)*H)
	var container:=SubViewportContainer.new();container.position=origin+Vector2(3,32);container.size=Vector2(W-6,H-35);root.add_child(container)
	var vp:=SubViewport.new();vp.size=Vector2i(W-6,H-35);vp.own_world_3d=true;vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;vp.msaa_3d=Viewport.MSAA_2X;container.add_child(vp);panels.append(vp)
	var world:=Node3D.new();vp.add_child(world)
	var env:=WorldEnvironment.new();var e:=Environment.new();e.background_mode=Environment.BG_COLOR;e.background_color=Color("293747");e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color("e2e8ef");e.ambient_light_energy=.3;env.environment=e;world.add_child(env)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-45,-35,0);light.light_energy=.65;light.shadow_enabled=true;world.add_child(light)
	var floor:=MeshInstance3D.new();var fm:=BoxMesh.new();fm.size=Vector3(15,.05,15);floor.mesh=fm;floor.position.y=-.035;var mat:=StandardMaterial3D.new();mat.albedo_color=Color("566272");mat.roughness=.9;floor.material_override=mat;world.add_child(floor)
	var packed:=load("res://assets/"+key+".glb") as PackedScene
	assert(packed!=null,key)
	var actor:=packed.instantiate() as Node3D
	var report:=inspect_mesh(actor,key);reports.append(report)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;world.add_child(camera)
	if batch:
		var mesh:=find_mesh(actor)
		assert(mesh.mesh.get_surface_count()==1,key)
		var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true;mm.mesh=mesh.mesh;mm.instance_count=180
		var n:=MultiMeshInstance3D.new();n.multimesh=mm;world.add_child(n)
		for k in range(180):
			mm.set_instance_transform(k,Transform3D(Basis(Vector3.UP,PI),Vector3(-2.75+(k%18)*.324,0,-float(k/18)*.43)))
			mm.set_instance_color(k,Color.WHITE)
		actor.free();camera.size=6.4;camera.look_at_from_position(Vector3(0,6,7),Vector3(0,0,-1.5))
	else:
		var height:float=report.aabb_max[1]-report.aabb_min[1]
		var scale_factor:=1.8/height
		actor.scale=Vector3.ONE*scale_factor;actor.position.x=-.8;actor.rotation.y=PI-.20;world.add_child(actor)
		var rear:=packed.instantiate() as Node3D;inspect_mesh(rear,key);rear.scale=actor.scale;rear.position.x=.85;rear.rotation.y=-.20;world.add_child(rear)
		camera.size=3.5;camera.look_at_from_position(Vector3(0,3.4,6),Vector3(0,.9,0))
	var label:=Label.new();label.text=title;label.position=origin+Vector2(8,6);label.add_theme_font_override("font",font);label.add_theme_font_size_override("font_size",15);label.add_theme_color_override("font_color",Color("e9f2ff"));root.add_child(label)

func _process(_delta:float) -> bool:
	frames+=1
	if frames==40:
		for vp in panels:vp.render_target_update_mode=SubViewport.UPDATE_DISABLED
		root.get_texture().get_image().save_png("res://assets/mobile/gpu-contact.png")
		var f:=FileAccess.open("res://assets/mobile/gpu-validation.json",FileAccess.WRITE)
		f.store_string(JSON.stringify({"device":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"viewport":[W*4,H*3],"models":reports,"scope":"GPU art import/contact only; no phone FPS claim."},"  "))
		print("MOBILE_GPU_CONTACT_OK ",reports.size()," asset panels rendered")
		quit()
	return false
