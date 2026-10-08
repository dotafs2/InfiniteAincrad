extends SceneTree
## Actual renderer comparison against StandardMaterial, without gloss.
var directory:=""
func _initialize()->void:run.call_deferred()
func colored_quad(tint:Color)->ArrayMesh:
	var base:=QuadMesh.new();base.size=Vector2(1.8,1.8)
	var a:=base.surface_get_arrays(0)
	var colors:=PackedColorArray();colors.resize(a[Mesh.ARRAY_VERTEX].size());colors.fill(tint)
	a[Mesh.ARRAY_COLOR]=colors
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a);return mesh
func run()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):directory=arg.trim_prefix("--capture-dir=")
	assert(not directory.is_empty());DirAccess.make_dir_recursive_absolute(directory)
	var view:=SubViewport.new();view.size=Vector2i(256,128);view.own_world_3d=true
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	var env:=WorldEnvironment.new();env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color.BLACK
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=1
	view.add_child(env)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=4
	camera.keep_aspect=Camera3D.KEEP_WIDTH;camera.position.z=3;view.add_child(camera);camera.current=true
	var reference:=MeshInstance3D.new();reference.position.x=-1;view.add_child(reference)
	var actual:=MeshInstance3D.new();actual.position.x=1;view.add_child(actual)
	var standard:=StandardMaterial3D.new();standard.vertex_color_use_as_albedo=true
	standard.vertex_color_is_srgb=true;standard.roughness=.5
	reference.material_override=standard
	var glaze:=ShaderMaterial.new();glaze.shader=load("res://fidelity/food_glaze.gdshader")
	glaze.set_shader_parameter("glaze_strength",0);actual.material_override=glaze
	var results:=[];var failures:=[]
	for html in ["ff398c","49d6fa","9854ed","ffab12","78311b","fff3ce"]:
		var tint:=Color(html);tint.a=.5
		reference.mesh=colored_quad(tint);actual.mesh=colored_quad(tint)
		for i in 4:await RenderingServer.frame_post_draw
		var image:=view.get_texture().get_image();image.save_png(directory+"/"+html+".png")
		var left:=image.get_pixel(64,64);var right:=image.get_pixel(192,64)
		var error:=maxf(absf(left.r-right.r),maxf(absf(left.g-right.g),absf(left.b-right.b)))
		results.append({"source":html,"standard":left,"food":right,"maximum_channel_error":error})
		if error>2.0/255.0:failures.append(html)
	var file:=FileAccess.open(directory+"/result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":6,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"results":results,"scope":"Real GPU framebuffer against StandardMaterial; not a headless algebra-only check."},"\t"))
	print("FOOD_SRGB_RENDER "+JSON.stringify({"checks":6,"failures":failures}))
	view.free();await process_frame;quit(0 if failures.is_empty() else 1)
