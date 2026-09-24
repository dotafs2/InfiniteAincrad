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
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.keep_aspect=Camera3D.KEEP_WIDTH;camera.size=8.2;add_child(camera)
	camera.position=Vector3(0,6.0,10);camera.look_at(Vector3(0,.75,0));camera.current=true
	var mat:=StandardMaterial3D.new();mat.vertex_color_use_as_albedo=true;mat.roughness=.8
	var roles:Array=["police","thief","mech","fat_fries","firefighter","chef","skateboarder","photographer","jogger","musician","construction","nurse","cyclist","superhero","delivery","dancer"]
	var actions:Array=["Chase","Sneak","Patrol","Eat_Fries","Hose","Flip","Skate","Shoot","Jog","Strum","Hammer","Care","Pedal","Hero_Pose","Carry","Dance"]
	for i in roles.size():
		var model:Node3D=load("res://assets/city_kit/%03d_%s_01.glb"%[193+i,roles[i]]).instantiate();add_child(model)
		model.position=Vector3((i%4-1.5)*2.15,0,(i/4-1.5)*1.75);model.rotation.y=-.35
		for mesh in model.find_children("*","MeshInstance3D",true,false):mesh.material_override=mat
		var animator:AnimationPlayer=model.find_child("AnimationPlayer",true,false)
		var clip:String=actions[i];animator.get_animation(clip).loop_mode=Animation.LOOP_LINEAR;animator.play(clip)
		var label:=Label3D.new();label.text=roles[i].replace("_"," ").to_upper()+"\n"+clip.replace("_"," ").to_upper();label.font_size=28;label.line_spacing=-8;label.pixel_size=.0045;label.position=Vector3((i%4-1.5)*2.15,1.62,(i/4-1.5)*1.75);label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.no_depth_test=true;add_child(label)
		var foot:=MeshInstance3D.new();var mesh:=CylinderMesh.new();mesh.top_radius=.55;mesh.bottom_radius=.55;mesh.height=.08;foot.mesh=mesh;foot.position=Vector3((i%4-1.5)*2.15,-.05,(i/4-1.5)*1.75)
		var floor_mat:=StandardMaterial3D.new();floor_mat.albedo_color=Color("586b81");foot.material_override=floor_mat;add_child(foot)
	var canvas:=CanvasLayer.new();add_child(canvas)
	var title:=Label.new();title.text="STICK FIGURE / ANIMATION PREVIEW";title.position=Vector2(30,42);title.add_theme_font_size_override("font_size",22);canvas.add_child(title)
	var detail:=Label.new();detail.text="Imported Blender rig · real Godot animation playback";detail.position=Vector2(30,78);detail.add_theme_font_size_override("font_size",16);canvas.add_child(detail)
	if OS.has_feature("web"):JavaScriptBridge.eval("window.__showcaseReady=true")
