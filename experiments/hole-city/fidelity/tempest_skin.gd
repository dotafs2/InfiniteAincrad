extends Node3D
## One original cosmetic assembly. All event debris uses a fixed 32-slot pool.
## It observes confirmed collection/combat, never changes physics or rewards.
const Flow=preload("res://fidelity/shaders/tempest.gdshader")
const CAPACITY:=32
const CLOUD_LOBES:=9
const HEIGHT:=1.42
var clock_time:=0.0
var object_energy:=0.0
var rival_energy:=0.0
var object_events:=0
var rival_events:=0
var particles:Array[Dictionary]=[]
var pool:MultiMeshInstance3D
var clouds:MultiMeshInstance3D
var funnel:MeshInstance3D
var shock:MeshInstance3D
var lightning:MeshInstance3D
var cursor:=0
var burst_color:=Color("d9b3fa")
var rival_color:=Color("d2b1f1")
var shock_color:=Color(.78,.48,.91)
var bolt_color:=Color(1.0,.76,.38)
var mats:Array[ShaderMaterial]=[]

func flow(s:Node,kind:int)->ShaderMaterial:
	var mat:ShaderMaterial=s.shader_material(Flow)
	mat.set_shader_parameter("surface_kind",kind)
	mats.append(mat)
	return mat

func point(u:float,v:float)->Vector3:
	var r:=.13+pow(v,1.20)*.67
	var bend:=Vector3(sin(v*3.8)*.145,0,cos(v*4.1)*.075)*v
	return Vector3(cos(u*TAU)*r,.09+v*HEIGHT,sin(u*TAU)*r)+bend

func funnel_mesh()->ArrayMesh:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in 32:
		for y in 12:
			for c in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
				var u:float=(x+c.x)/32.0;var v:float=(y+c.y)/12.0
				st.set_uv(Vector2(u,v));st.set_normal(Vector3(cos(u*TAU),-.5,sin(u*TAU)).normalized())
				st.add_vertex(point(u,v))
	return st.commit()

func triangle(st:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,uvs:Array)->void:
	var normal:=-(b-a).cross(c-a).normalized()
	for i in 3:
		st.set_normal(normal);st.set_uv(uvs[i]);st.add_vertex([a,b,c][i])

func cloud_mesh()->ArrayMesh:
	# A shallow, scalloped cloud bank replaces the perfectly flat square plane.
	# UVs stay planar so the drifting density field has no polar seam.
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment in 32:
		for row in 2:
			var vertices:Array[Vector3]=[];var uvs:Array[Vector2]=[]
			for corner in [Vector2(0,0),Vector2(1,1),Vector2(1,0),Vector2(0,0),Vector2(0,1),Vector2(1,1)]:
				var a:float=(segment+corner.x)*TAU/32.0
				var f:float=(row+corner.y)/2.0
				var lobe:=.94+.035*sin(a*7.0+.5)+.025*sin(a*11.0)
				var r:=f*1.38*lobe
				var y:=sin(f*PI)*(.025+.012*sin(a*5.0+.7))
				var p:=Vector3(cos(a)*r,y,sin(a)*r)
				vertices.append(p);uvs.append(Vector2(p.x,p.z)/2.8+Vector2.ONE*.5)
			triangle(st,vertices[0],vertices[1],vertices[2],uvs.slice(0,3))
			triangle(st,vertices[3],vertices[4],vertices[5],uvs.slice(3,6))
	return st.commit()

func build(s:Node)->void:
	# The opaque collection-preview disk would slice through the soft billboards.
	if is_instance_valid(s.mouth):s.mouth.hide()
	s.main_ring.free()
	s.main_ring=s.mesh_part(self,cloud_mesh(),Vector3(0,.055,0),flow(s,0))
	s.main_ring.material_override.render_priority=-3
	# Restore nine smaller, varied lobes while retaining one material/draw.
	clouds=MultiMeshInstance3D.new();add_child(clouds)
	clouds.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	clouds.multimesh=MultiMesh.new();clouds.multimesh.transform_format=MultiMesh.TRANSFORM_3D
	clouds.multimesh.use_custom_data=true
	var quad:=QuadMesh.new();quad.size=Vector2.ONE
	clouds.multimesh.mesh=quad;clouds.multimesh.instance_count=CLOUD_LOBES
	clouds.custom_aabb=AABB(Vector3(-1.55,-.4,-1.55),Vector3(3.1,1.4,3.1))
	var billow_mat:ShaderMaterial=s.shader_material(preload("res://fidelity/shaders/tempest_billow.gdshader"))
	mats.append(billow_mat);clouds.material_override=billow_mat
	for puff in CLOUD_LOBES:
		var angle:=float(puff)*TAU/float(CLOUD_LOBES)+.2
		var orbit:=.75+.06*sin(puff*2.3)
		var at:=Vector3(cos(angle)*orbit,.24+.08*sin(puff*1.7),sin(angle)*orbit)
		var size:=Vector3(.91+.14*sin(puff*2.0),.67+.12*cos(puff*1.8),1)
		clouds.multimesh.set_instance_transform(puff,Transform3D(Basis.IDENTITY.scaled(size),at))
		clouds.multimesh.set_instance_custom_data(puff,Color(puff*.137,puff*.083,0,0))
	funnel=s.mesh_part(self,funnel_mesh(),Vector3.ZERO,flow(s,1))
	var shock_mat:StandardMaterial3D=s.flat_material(Color("d8a8f2"))
	shock_mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	shock=s.band(self,.98,1.025,shock_mat,24);shock.visible=false
	var bolt_mat:StandardMaterial3D=s.flat_material(Color("ffe3a0"))
	bolt_mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	bolt_mat.cull_mode=BaseMaterial3D.CULL_DISABLED;bolt_mat.render_priority=2
	var bolts:=SurfaceTool.new();bolts.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in 2:
		var a:=float(j)*PI
		var previous:=Vector3.ZERO
		for k in 5:
			var at:=Vector3(cos(a+.2*sin(k*4.0))*(.28+k*.18),1.20-k*.21,sin(a+.2*sin(k*4.0))*(.28+k*.18))
			if k>0:
				var width:=Vector3(cos(a+PI/2),0,sin(a+PI/2))*.026
				triangle(bolts,previous-width,previous+width,at+width,[Vector2.ZERO,Vector2.RIGHT,Vector2.ONE])
				triangle(bolts,previous-width,at+width,at-width,[Vector2.ZERO,Vector2.ONE,Vector2.DOWN])
			previous=at
	lightning=s.mesh_part(self,bolts.commit(),Vector3.ZERO,bolt_mat);lightning.visible=false
	pool=MultiMeshInstance3D.new();add_child(pool)
	pool.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pool.multimesh=MultiMesh.new();pool.multimesh.transform_format=MultiMesh.TRANSFORM_3D
	pool.multimesh.use_colors=true
	var chip:=PrismMesh.new();chip.size=Vector3(.06,.12,.035)
	pool.multimesh.mesh=chip;pool.multimesh.instance_count=CAPACITY
	var dust:StandardMaterial3D=s.flat_material(Color.WHITE)
	dust.vertex_color_use_as_albedo=true;dust.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	pool.material_override=dust
	for i in CAPACITY:
		particles.append({"age":2.0,"life":1.0,"angle":0.0,"radius":1.0,"rival":false,"color":Color.WHITE})
		pool.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO),Vector3.ZERO))

	if int(s.variant_index)>0:
		burst_color=Color(s.tint).lerp(Color(s.accent),.35)
		rival_color=Color(s.accent);shock_color=burst_color;bolt_color=Color(s.accent)
		for material in mats:
			material.set_shader_parameter("palette_mix",1.0)
			material.set_shader_parameter("palette_primary",Color(s.tint))
			material.set_shader_parameter("palette_secondary",Color(s.accent))

func absorb(is_rival:bool,source_color:=Color("e8c5ff"))->void:
	if is_rival:rival_events+=1;rival_energy=1.0
	else:object_events+=1;object_energy=minf(1.0,object_energy+.48)
	var count:=12 if is_rival else 4
	for j in count:
		particles[cursor]={"age":0.0,"life":1.35 if is_rival else .65,"angle":clock_time*3.0+j*2.39996,"radius":.7+float(j%5)*.12,"rival":is_rival,"color":source_color.lerp(rival_color,.65) if is_rival else burst_color}
		cursor=(cursor+1)%CAPACITY

func advance(delta:float)->void:
	clock_time+=delta
	object_energy=maxf(0.0,object_energy-delta*1.8)
	rival_energy=maxf(0.0,rival_energy-delta/.95)
	for mat in mats:mat.set_shader_parameter("surge",maxf(object_energy*.45,rival_energy))
	clouds.rotation.y=-clock_time*.16
	funnel.rotation.y=-clock_time*.24
	var swell:=1.0+rival_energy*.14+object_energy*.026
	funnel.scale=Vector3(swell,1.0+rival_energy*.12,swell)
	shock.visible=rival_energy>0.0
	if shock.visible:
		var expansion:=1.0+(1.0-rival_energy)*1.0
		shock.scale=Vector3(expansion,.3,expansion)
		shock.material_override.albedo_color=Color(shock_color,rival_energy*.45)
	lightning.visible=rival_energy>.45
	if lightning.visible:
		lightning.rotation.y=clock_time*1.4
		lightning.material_override.albedo_color=Color(bolt_color,rival_energy)
	for i in CAPACITY:
		var p:Dictionary=particles[i]
		if p.age>=p.life:continue
		p.age+=delta
		var t:float=clampf(p.age/p.life,0,1)
		if t>=1:
			pool.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO),Vector3.ZERO))
			continue
		var angle:float=p.angle+t*(7.0 if p.rival else 5.5)
		var r:float=p.radius*(.6+t*1.1 if p.rival else 1.0-t*.92)
		var y:float=.12+sin(t*PI)*(.95 if p.rival else .40)
		var size:float=sin(t*PI)* (1.7 if p.rival else .65)
		var transform:=Transform3D(Basis.from_euler(Vector3(t*4,angle,t*2)).scaled(Vector3.ONE*size),Vector3(cos(angle)*r,y,sin(angle)*r))
		pool.multimesh.set_instance_transform(i,transform)
		pool.multimesh.set_instance_color(i,Color(p.color,1.0-t))
