extends Node3D
## Isolated animation review fixture, explicitly separate from gameplay.
func _ready() -> void:
	var env:=WorldEnvironment.new()
	var settings:=Environment.new()
	settings.background_mode=Environment.BG_COLOR
	settings.background_color=Color("152338")
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color=Color("a7c9e3")
	settings.ambient_light_energy=.65
	env.environment=settings;add_child(env)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-45,-30,0);light.shadow_enabled=true;add_child(light)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.keep_aspect=Camera3D.KEEP_WIDTH;camera.size=5.4;add_child(camera)
	camera.position=Vector3(2.7,2.3,6);camera.look_at(Vector3(0,.7,0));camera.current=true
	var mat:=StandardMaterial3D.new();mat.vertex_color_use_as_albedo=true;mat.roughness=.8
	for i in 3:
		var model:Node3D=load("res://assets/city_kit/193_slim_01.glb").instantiate();add_child(model)
		model.position.x=(i-1)*1.45;model.rotation.y=-.45
		for mesh in model.find_children("*","MeshInstance3D",true,false):mesh.material_override=mat
		var animator:AnimationPlayer=model.find_child("AnimationPlayer",true,false)
		var clip:String=["Idle","Walk","Run"][i];animator.get_animation(clip).loop_mode=Animation.LOOP_LINEAR;animator.play(clip)
		var label:=Label3D.new();label.text=clip.to_upper();label.font_size=52;label.pixel_size=.005;label.position=Vector3((i-1)*1.45,1.78,0);label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.no_depth_test=true;add_child(label)
		var foot:=MeshInstance3D.new();var mesh:=CylinderMesh.new();mesh.top_radius=.55;mesh.bottom_radius=.55;mesh.height=.08;foot.mesh=mesh;foot.position=Vector3((i-1)*1.45,-.05,0)
		var floor_mat:=StandardMaterial3D.new();floor_mat.albedo_color=Color("586b81");foot.material_override=floor_mat;add_child(foot)
	var canvas:=CanvasLayer.new();add_child(canvas)
	var title:=Label.new();title.text="STICK FIGURE / ANIMATION PREVIEW";title.position=Vector2(30,42);title.add_theme_font_size_override("font_size",22);canvas.add_child(title)
	var detail:=Label.new();detail.text="Imported Blender rig · real Godot animation playback";detail.position=Vector2(30,78);detail.add_theme_font_size_override("font_size",16);canvas.add_child(detail)
	if OS.has_feature("web"):JavaScriptBridge.eval("window.__showcaseReady=true")
