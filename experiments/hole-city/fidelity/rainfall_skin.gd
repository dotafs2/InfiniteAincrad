extends Node3D
## Cosmetic rain. Shallow-water waves are baked; drop flight is GPU-animated.
const Bake=preload("res://fidelity/rainfall_bake.gd")
const CAPACITY:=24
var clock_time:=0.0
var object_events:=0
var rival_events:=0
var intake_energy:=0.0
var rival_energy:=0.0
var impact_age:=4.0
var water:ShaderMaterial
var drops:MultiMeshInstance3D
var clouds:MultiMeshInstance3D
var splash:MultiMeshInstance3D
var shock:MeshInstance3D
var splash_age:=2.0
var contact_age:=3.0
var contact_events:=0
var intake:Node3D
var shock_color:=Color(.89,.98,.93)

func confirmed_object(body:Node3D)->void:
	# Confirmed collection only ripples. It must never replay the object mesh.
	var at:=to_local(body.global_position)
	var flat:=Vector2(at.x,at.z).limit_length(.40)
	water_contact(to_global(Vector3(flat.x,.075,flat.y)))

func water_contact(world_position:Vector3)->void:
	var local:=to_local(world_position)
	water.set_shader_parameter("contact_origin",Vector2(local.x,local.z))
	contact_age=0.0;contact_events+=1
	intake_energy=maxf(intake_energy,.55)

func pool(mesh:Mesh,count:int,mat:Material,colored:=false)->MultiMeshInstance3D:
	var instance:=MultiMeshInstance3D.new();add_child(instance)
	instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.multimesh=MultiMesh.new();instance.multimesh.transform_format=MultiMesh.TRANSFORM_3D
	instance.multimesh.use_custom_data=true;instance.multimesh.use_colors=colored
	instance.multimesh.mesh=mesh;instance.multimesh.instance_count=count
	instance.material_override=mat
	instance.custom_aabb=AABB(Vector3(-1.7,-.2,-1.7),Vector3(3.4,2.8,3.4))
	return instance

func water_mesh()->ArrayMesh:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment in 48:
		for row in 10:
			var vertices:Array[Vector3]=[]
			for c in [Vector2(0,0),Vector2(1,1),Vector2(1,0),Vector2(0,0),Vector2(0,1),Vector2(1,1)]:
				var a:float=(segment+c.x)*TAU/48.0
				var r:float=(row+c.y)*1.23/10.0
				vertices.append(Vector3(cos(a)*r,.075,sin(a)*r))
			for k in [0,3]:
				var normal:=-(vertices[k+1]-vertices[k]).cross(vertices[k+2]-vertices[k]).normalized()
				for i in range(k,k+3):
					st.set_normal(normal);st.set_uv(Vector2(vertices[i].x,vertices[i].z)/2.6+Vector2.ONE*.5);st.add_vertex(vertices[i])
	return st.commit()

func build(s:Node)->void:
	intake=preload("res://fidelity/rainfall_intake.gd").new();add_child(intake)
	if is_instance_valid(s.mouth):s.mouth.hide()
	s.main_ring.free()
	water=s.shader_material(preload("res://fidelity/shaders/rainfall_water.gdshader"))
	water.set_shader_parameter("wave_atlas",preload("res://assets/skins/rainfall/shallow_water_atlas.png"))
	water.render_priority=-2
	s.main_ring=s.mesh_part(self,water_mesh(),Vector3.ZERO,water)
	var rain_mat:ShaderMaterial=s.shader_material(preload("res://fidelity/shaders/rainfall_drops.gdshader"))
	var rain_quad:=QuadMesh.new();rain_quad.size=Vector2(.055,.23)
	drops=pool(rain_quad,Bake.DROP_DATA.size(),rain_mat)
	for i in Bake.DROP_DATA.size():
		var d:Vector4=Bake.DROP_DATA[i]
		drops.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(d.x,0,d.y)))
		drops.multimesh.set_instance_custom_data(i,Color(d.z/Bake.PERIOD,d.w,0,0))
	var cloud_mat:ShaderMaterial=s.shader_material(preload("res://fidelity/shaders/rainfall_cloud.gdshader"))
	var cloud_quad:=QuadMesh.new();cloud_quad.size=Vector2.ONE
	clouds=pool(cloud_quad,7,cloud_mat)
	for i in 7:
		var angle:=float(i)*TAU/7.0
		var at:=Vector3(cos(angle)*.47,1.70+.06*sin(i*2.1),sin(angle)*.47)
		clouds.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3(.82,.40,1)),at))
		clouds.multimesh.set_instance_custom_data(i,Color(i*.147,i*.081,0,0))
	var splash_mesh:=PrismMesh.new();splash_mesh.size=Vector3(.045,.085,.035)
	var splash_mat:StandardMaterial3D=s.flat_material(Color("8ee7c0"));splash_mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	splash_mat.vertex_color_use_as_albedo=true;splash_mat.albedo_color=Color.WHITE
	splash=pool(splash_mesh,CAPACITY,splash_mat,true)
	for i in CAPACITY:splash.multimesh.set_instance_color(i,Color("f4eee0") if i%3==0 else Color("6cdcca"))
	splash.multimesh.visible_instance_count=0
	var ring_mat:StandardMaterial3D=s.flat_material(Color("e1faf0"));ring_mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	shock=s.band(self,.50,.53,ring_mat,32);shock.visible=false

	if int(s.variant_index)>0:
		shock_color=Color(s.accent)
		for material in [water,rain_mat,cloud_mat]:
			material.set_shader_parameter("palette_mix",1.0)
			material.set_shader_parameter("palette_primary",Color(s.tint))
			material.set_shader_parameter("palette_secondary",Color(s.accent))
		for i in CAPACITY:splash.multimesh.set_instance_color(i,Color(s.accent) if i%3==0 else Color(s.tint))

func begin_intake()->void:
	intake_energy=maxf(intake_energy,.35)

func absorb(is_rival:bool,_source_color:=Color.WHITE)->void:
	if is_rival:
		rival_events+=1;rival_energy=1.0;impact_age=0.0;splash_age=0.0
	else:
		object_events+=1;intake_energy=minf(intake_energy+.45,1.0)

func advance(delta:float)->void:
	intake.advance(delta)
	clock_time+=delta;impact_age+=delta;splash_age+=delta;contact_age+=delta
	intake_energy=maxf(0,intake_energy-delta*1.9)
	rival_energy=maxf(0,rival_energy-delta/1.3)
	water.set_shader_parameter("intake",intake_energy)
	water.set_shader_parameter("rival",rival_energy)
	water.set_shader_parameter("impact_age",impact_age)
	water.set_shader_parameter("contact_age",contact_age)
	shock.visible=rival_energy>0.0
	if shock.visible:
		shock.scale=Vector3.ONE*(1.0+impact_age*2.0);shock.scale.y=.20
		shock.material_override.albedo_color=Color(shock_color,rival_energy*.55)
	splash.multimesh.visible_instance_count=CAPACITY if splash_age<.8 else 0
	if splash_age<.8:
		for i in CAPACITY:
			var angle:=float(i)*2.399963
			var speed:=.65+float(i%4)*.1
			var p:=Vector3(cos(angle),0,sin(angle))*(.30+splash_age*speed)
			p.y=.08+splash_age*2.1-splash_age*splash_age*2.6
			var size:float=(1.0-splash_age/.8)*(.65+float(i%3)*.17)
			splash.multimesh.set_instance_transform(i,Transform3D(Basis.from_euler(Vector3(splash_age*3,angle,0)).scaled(Vector3.ONE*size),p))
