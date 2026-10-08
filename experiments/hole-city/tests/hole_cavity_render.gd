extends SceneTree
## Render the production cut slab and hole over the real food-base color.
## Radius/angle fixtures are diagnostics, never marketing gameplay evidence.
class Fixture extends Node3D:
	var holes:Array[Node3D]=[]
var directory:=""
func _initialize()->void:run.call_deferred()
func run()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):directory=arg.trim_prefix("--capture-dir=")
	assert(not directory.is_empty());DirAccess.make_dir_recursive_absolute(directory)
	var view:=SubViewport.new();view.size=Vector2i(384,384);view.own_world_3d=true
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	var fixture:=Fixture.new();view.add_child(fixture)
	var hole:=load("res://scripts/hole.gd").new() as Node3D
	fixture.add_child(hole);fixture.holes.append(hole);hole.label.hide();hole.rim.hide()
	var shader:=ShaderMaterial.new();shader.shader=load("res://fidelity/asphalt.gdshader")
	shader.set_shader_parameter("food_theme",true)
	shader.set_shader_parameter("food_city_atlas",load("res://assets/food_city/streets.png"))
	var ground:=load("res://fidelity/cut_ground.gd").new() as Node3D
	fixture.add_child(ground);ground.build(fixture,shader)
	var base:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(200,3,200)
	base.mesh=box;base.position.y=-4.9;var material:=StandardMaterial3D.new()
	material.albedo_color=Color("edb36d");material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	base.material_override=material;fixture.add_child(base)
	var env:=WorldEnvironment.new();env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color.WHITE
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=1
	fixture.add_child(env)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	fixture.add_child(camera);camera.current=true
	var checks:=0;var failures:=[];var rows:=[]
	for radius in [.85,3.5,7.2]:
		hole.radius=radius;hole._sync_shape();ground.sync();camera.size=radius*2.8
		for pitch in [45.0,65.0]:
			camera.position=Vector3(0,sin(deg_to_rad(pitch)),cos(deg_to_rad(pitch)))*40
			camera.look_at(Vector3.ZERO)
			for _i in 4:await RenderingServer.frame_post_draw
			var image:=view.get_texture().get_image();var maximum:=0.0
			for fraction in [.0,.3,.6]:
				for angle in 8:
					var point:=Vector3(cos(TAU*angle/8)*radius*fraction,0,sin(TAU*angle/8)*radius*fraction)
					var pixel:=camera.unproject_position(point);var color:=image.get_pixelv(Vector2i(pixel))
					var brightness:=maxf(color.r,maxf(color.g,color.b));maximum=maxf(maximum,brightness)
					checks+=1
					if brightness>.16:failures.append("Interior exposes ground/base at radius %s pitch %s fraction %s angle %s"%[radius,pitch,fraction,angle])
			image.save_png(directory+"/r%s-p%s.png"%[radius,pitch])
			rows.append({"radius":radius,"pitch":pitch,"maximum_interior_channel":maximum})
	var result:={"checks":checks,"failures":failures,"rows":rows,"scope":"Real GPU pixels through production cut-ground and hole materials; isolated radius/camera fixtures."}
	FileAccess.open(directory+"/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("HOLE_CAVITY_RENDER "+JSON.stringify({"checks":checks,"failures":failures}))
	if is_instance_valid(hole.hole):hole.hole.free()
	view.free();await process_frame;quit(0 if failures.is_empty() else 1)
