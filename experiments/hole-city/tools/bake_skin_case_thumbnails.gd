extends SceneTree
## Offline actual-model thumbnail baker. No Game instance, saves or commerce.
## Run on a real GPU with -- --test --output=/absolute/new/output/directory.
const Catalog=preload("res://fidelity/skin_catalog.gd")
const Visual=preload("res://fidelity/skin_visual.gd")
const SIZE:=256
const MARGIN:=5
const SETTLE_STEPS:=36
const SETTLE_DELTA:=1.0/60.0
const MAX_FRAME_ATTEMPTS:=4
var output:=""
var checks:=0
var failures:Array[String]=[]
var rows:Array[Dictionary]=[]
var viewport:SubViewport
var stage:Node3D
var camera:Camera3D

func _initialize()->void:
	run.call_deferred()

func check(ok:bool,message:String)->bool:
	checks+=1
	if not ok:
		failures.append(message)
		push_error(message)
	return ok

func draw_frames(count:=3)->void:
	for _i in count:
		await process_frame
		await RenderingServer.frame_post_draw

func image_alpha(image:Image)->Dictionary:
	var transparent:=0
	var partial:=0
	var visible:=0
	var min_x:=SIZE
	var min_y:=SIZE
	var max_x:=-1
	var max_y:=-1
	for y in SIZE:
		for x in SIZE:
			var alpha:=image.get_pixel(x,y).a
			if alpha<=1.0/255.0:transparent+=1
			if alpha>1.0/255.0 and alpha<254.0/255.0:partial+=1
			# Ignore effectively invisible antialias samples for the framing bound.
			if alpha>.015:
				visible+=1
				min_x=mini(min_x,x);min_y=mini(min_y,y)
				max_x=maxi(max_x,x);max_y=maxi(max_y,y)
	return {"transparent_pixels":transparent,"partial_alpha_pixels":partial,
		"visible_pixels":visible,"bounds_px":[min_x,min_y,maxi(0,max_x-min_x+1),maxi(0,max_y-min_y+1)],
		"within_margin":visible>0 and min_x>=MARGIN and min_y>=MARGIN and max_x<SIZE-MARGIN and max_y<SIZE-MARGIN}

func build_stage()->void:
	viewport=SubViewport.new()
	viewport.name="CaseThumbnailBakeViewport"
	viewport.size=Vector2i(SIZE,SIZE)
	viewport.own_world_3d=true
	viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d=Viewport.MSAA_4X
	root.add_child(viewport)
	stage=Node3D.new();viewport.add_child(stage)
	var environment_node:=WorldEnvironment.new()
	var environment:=Environment.new()
	environment.background_mode=Environment.BG_CLEAR_COLOR
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color("b7c8e0")
	environment.ambient_light_energy=.66
	environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	environment_node.environment=environment
	stage.add_child(environment_node)
	var key:=DirectionalLight3D.new()
	key.name="ThumbnailKey"
	key.rotation_degrees=Vector3(-58,-32,0)
	key.light_energy=1.50
	key.shadow_enabled=false
	stage.add_child(key)
	var fill:=DirectionalLight3D.new()
	fill.name="ThumbnailFill"
	fill.rotation_degrees=Vector3(-26,125,0)
	fill.light_energy=.40
	fill.light_color=Color("c4dcff")
	fill.shadow_enabled=false
	stage.add_child(fill)
	camera=Camera3D.new()
	camera.name="ThumbnailCamera"
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect=Camera3D.KEEP_HEIGHT
	camera.position=Vector3(3.2,5.7,5.0)
	stage.add_child(camera)
	camera.current=true

func write_manifest()->bool:
	var result:={
		"scope":"Actual Godot GPU SkinVisual idle models, including their preview mouth. Transparent offline renders; no image composition and no gameplay/reward event.",
		"checks":checks,"failures":failures,"complete":failures.is_empty() and rows.size()==200,
		"expected_skins":200,"baked_skins":rows.size(),"dimensions":[SIZE,SIZE],
		"transparent_background":true,"reusable_subviewports":1,"directional_lights":2,
		"settle_steps":SETTLE_STEPS,"settle_delta_seconds":SETTLE_DELTA,
		"camera_framing":"SkinVisual.frame_preview(card=true), minimum3.8 with8percent margin; bounded12percent expansion when alpha touches5px frame margin.",
		"engine":Engine.get_version_info(),"display_server":DisplayServer.get_name(),
		"catalog_sha256":FileAccess.get_sha256("res://fidelity/skin_catalog.gd"),
		"skin_visual_sha256":FileAccess.get_sha256("res://fidelity/skin_visual.gd"),
		"baker_sha256":FileAccess.get_sha256("res://tools/bake_skin_case_thumbnails.gd"),
		"skins":rows,
	}
	var file:=FileAccess.open(output.path_join("manifest.json"),FileAccess.WRITE)
	if file==null:
		push_error("Cannot write thumbnail manifest: "+error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(result,"\t")+"\n")
	file.flush();file.close()
	return true

func bake_one(definition:Dictionary)->bool:
	var id:String=str(definition.id)
	var model:Node3D=Visual.new()
	stage.add_child(model)
	model.build(definition,true)
	model.set_process(false)
	model.frame_preview(camera,true)
	# Reuse the runtime family framing, with modest padding for cached square cards.
	camera.size=maxf(camera.size,3.8)*1.08
	for _i in SETTLE_STEPS:model._process(SETTLE_DELTA)
	# Every rendered family uses authored fx_time uniforms; no rival/item callback
	# or automatic animation process is allowed during this idle capture.
	var image:Image
	var alpha:Dictionary={}
	var attempts:=0
	for attempt in MAX_FRAME_ATTEMPTS:
		attempts=attempt+1
		await draw_frames()
		image=viewport.get_texture().get_image()
		if not check(image!=null and not image.is_empty(),"Actual GPU image exists: "+id):
			model.free();return false
		if not check(image.get_width()==SIZE and image.get_height()==SIZE,"Exact256square image: "+id):
			model.free();return false
		alpha=image_alpha(image)
		if bool(alpha.within_margin):break
		camera.size*=1.12
	var valid:=true
	valid=check(image.detect_alpha()!=Image.ALPHA_NONE,"PNG retains alpha channel: "+id) and valid
	valid=check(int(alpha.transparent_pixels)>SIZE*SIZE/4,"Background is transparent rather than opaque: "+id) and valid
	valid=check(int(alpha.visible_pixels)>160,"Actual model has visible GPU pixels: "+id) and valid
	valid=check(bool(alpha.within_margin),"Authored model stays inside capture margin: "+id) and valid
	if valid:
		var path:=output.path_join(id+".png")
		valid=check(image.save_png(path)==OK,"Actual model PNG saves: "+id)
		if valid:
			var file:=FileAccess.open(path,FileAccess.READ)
			valid=check(file!=null,"Saved PNG can be reopened: "+id)
			if file!=null:
				var bytes:=file.get_length();file.close()
				rows.append({"id":id,"name":definition.name,"model_id":definition.get("model_id",id),
					"rarity":definition.rarity,"variant_index":definition.get("variant_index",0),
					"file":id+".png","sha256":FileAccess.get_sha256(path),"bytes":bytes,
					"camera_size":camera.size,"camera_position":[camera.position.x,camera.position.y,camera.position.z],
					"camera_rotation":[camera.rotation.x,camera.rotation.y,camera.rotation.z],
					"frame_attempts":attempts,"alpha":alpha})
	model.free()
	await process_frame
	return valid

func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):
		push_error("Thumbnail baking requires --test; no user saves are accessed.");quit(2);return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	if not output.is_absolute_path() or output.begins_with("res://") or output.begins_with("user://"):
		push_error("Pass an absolute filesystem --output directory.");quit(2);return
	if not check(DisplayServer.get_name()!="headless","A real GPU display is required"):
		quit(2);return
	if not check(Catalog.DEFS.size()==200,"The actual catalog contains exactly200 skins"):
		quit(2);return
	if not check(not FileAccess.file_exists(output.path_join("manifest.json")),"Refuse to replace an existing bake manifest"):
		quit(2);return
	var ids:Dictionary={}
	for definition in Catalog.DEFS:
		var id:String=str(definition.id)
		if not check(not id.is_empty() and id.is_valid_filename() and not ids.has(id),"Safe unique output identity: "+id):
			quit(2);return
		ids[id]=true
		if not check(not FileAccess.file_exists(output.path_join(id+".png")),"Refuse to overwrite previous thumbnail: "+id):
			quit(2);return
	if not check(DirAccess.make_dir_recursive_absolute(output)==OK,"Output directory is writable"):
		quit(2);return
	AudioServer.set_bus_mute(0,true)
	RenderingServer.set_default_clear_color(Color(0,0,0,0))
	root.size=Vector2i(SIZE,SIZE)
	build_stage()
	for definition in Catalog.DEFS:
		var baked:bool=await bake_one(definition)
		if not baked:break
		if rows.size()%20==0:print("SKIN_CASE_THUMBNAIL_PROGRESS "+str(rows.size())+"/200")
	check(rows.size()==200,"Every catalog ID has one actual transparent thumbnail")
	var manifest_ok:=write_manifest()
	print("SKIN_CASE_THUMBNAILS "+JSON.stringify({"checks":checks,"failures":failures,"baked":rows.size(),"output":output,"manifest_written":manifest_ok}))
	viewport.free();await process_frame
	quit(0 if failures.is_empty() and manifest_ok else 1)
