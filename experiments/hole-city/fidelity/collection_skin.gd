extends Node3D
## Tiered cosmetic responses and original animated assemblies. No physics/save access.
const Geometry=preload("res://fidelity/collection_geometry.gd")
const Rarity=preload("res://fidelity/skin_rarity.gd")
const Sculpt=preload("res://fidelity/skin_sculpt.gd")
const CAPACITIES:Array[int]=[4,8,10,12,16,16]
static var _particle_meshes:Dictionary={}
var skin_id:=""
var model_id:=""
var rank:=0
var profile:="chips"
var animated_root:Node3D
var motion_specs:Array=[]
var particles:MultiMeshInstance3D
var active_count:=0
var item_events:=0
var rival_events:=0
var rival_active:=false
var age:=10.0
var lifetime:=0.0
var clock_time:=0.0
var primary:=Color.WHITE
var secondary:=Color.WHITE
var pulse:=0.0
var _event_seed:=0
var field_material:ShaderMaterial

func build(s:Node3D,make_geometry:=true)->void:
	skin_id=str(s.skin_id);model_id=str(s.model_id)
	rank=maxi(0,Rarity.index_of(str(s.rarity_id)))
	primary=Color(s.tint);secondary=Color(s.accent)
	profile=profile_for(model_id)
	name="CollectionSkin_"+skin_id
	if make_geometry:
		var old:MeshInstance3D=s.main_ring
		var result:Dictionary=Geometry.build(s,self)
		s.main_ring=result.main_ring;animated_root=result.animated_root
		motion_specs=result.get("motions",[])
		if is_instance_valid(old):old.free()
	else:
		animated_root=s.ornaments
	for spec in motion_specs:
		var node:Node3D=spec.node
		spec["rest_transform"]=node.transform
	if model_id=="aurora_rift":_build_aurora(s)
	particles=MultiMeshInstance3D.new();particles.name="TieredFeedbackPool"
	particles.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.custom_aabb=AABB(Vector3(-3,-.1,-3),Vector3(6,2,6))
	var batch:=MultiMesh.new();batch.transform_format=MultiMesh.TRANSFORM_3D
	batch.use_colors=true;batch.mesh=particle_mesh(profile)
	batch.instance_count=CAPACITIES[rank];batch.visible_instance_count=0
	particles.multimesh=batch
	var mat:=StandardMaterial3D.new();mat.vertex_color_use_as_albedo=true
	mat.roughness=.30 if profile in ["crystals","arcs","bubbles"] else .55
	mat.metallic=.30 if profile=="sparks" else 0.0
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	particles.material_override=mat;particles.visible=false;add_child(particles)
	set_meta("cosmetic_only",true);set_meta("profile",profile)
	set_meta("pool_capacity",CAPACITIES[rank]);set_process(false)

static func profile_for(family:String)->String:
	if family in ["moss_bloom","sakura_pavilion","pineapple_top","coral_reef"]:return "petals"
	if family in ["music_stage","pocket_arcade"]:return "notes"
	if family in ["copper_ring","clockwork_key","clockwork_orbit","satellite_dish","rocket_port"]:return "sparks"
	if family in ["shard","crystal_crown","core_shell"]:return "crystals"
	if family in ["cinder","phoenix_nest","dragon_roost","lantern"]:return "embers"
	if family in ["orbit","prism_vale","aurora_rift","gravitas"]:return "arcs"
	if family in ["tide","jelly_veil","storm_cloud","frog_pond"]:return "bubbles"
	if family in ["royal_gate","carnival_tent","rainbow_bridge","frosted_cake"]:return "confetti"
	return "chips"

static func particle_mesh(kind:String)->Mesh:
	if _particle_meshes.has(kind):return _particle_meshes[kind]
	var mesh:Mesh
	if kind=="notes":
		var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for spec in [[Vector3(-.18,-.25,0),Vector3(.60,.35,.18)],[Vector3(.10,.18,0),Vector3(.16,.95,.18)],[Vector3(.29,.58,0),Vector3(.52,.15,.18)]]:
			var box:=BoxMesh.new();box.size=spec[1]
			st.append_from(box,0,Transform3D(Basis.IDENTITY,spec[0]))
		mesh=st.commit()
	elif kind in ["petals","confetti","arcs","embers"]:
		mesh=Sculpt.bevel([Vector2(-.35,0),Vector2(-.15,-.60),Vector2(.24,-.36),Vector2(.38,.16),Vector2(.10,.55),Vector2(-.22,.30)],.10)
	elif kind=="bubbles":
		var bead:=SphereMesh.new();bead.radius=.4;bead.height=.8;bead.radial_segments=6;bead.rings=3;mesh=bead
	elif kind=="crystals":
		var shard:=PrismMesh.new();shard.size=Vector3(.5,1.0,.36);mesh=shard
	else:
		var chip:=BoxMesh.new();chip.size=Vector3(.3,.9,.2) if kind=="sparks" else Vector3(.7,.5,.5);mesh=chip
	_particle_meshes[kind]=mesh;return mesh

func _build_aurora(s:Node3D)->void:
	# One bounded translucent ribbon; no raymarch, texture simulation or extra lights.
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 48:
		for c in [Vector2(0,0),Vector2(1,1),Vector2(1,0),Vector2(0,0),Vector2(0,1),Vector2(1,1)]:
			var u:float=(float(i)+c.x)/48.0
			var a:float=u*TAU;var r:float=1.12+c.y*.30
			var y:float=.16+c.y*(.60+.24*sin(a*2.0))
			st.set_uv(Vector2(u,c.y));st.set_normal(Vector3(sin(a),.4,cos(a)).normalized())
			st.add_vertex(Vector3(sin(a)*r,y,cos(a)*r))
	field_material=s.shader_material(preload("res://fidelity/shaders/collection_aurora.gdshader"))
	field_material.set_shader_parameter("primary",primary);field_material.set_shader_parameter("secondary",secondary)
	var field:MeshInstance3D=s.mesh_part(self,st.commit(),Vector3.ZERO,field_material)
	field.name="AuroraCurtain";field.extra_cull_margin=.18

func absorb(is_rival:bool,_source_color:=Color.WHITE)->void:
	if is_rival:rival_events+=1
	else:item_events+=1
	if rival_active and not is_rival:return
	rival_active=is_rival;age=0.0
	lifetime=(.66+rank*.045) if is_rival else .24
	active_count=CAPACITIES[rank] if is_rival else (2 if rank<3 else 3)
	pulse=1.0 if is_rival else .18
	_event_seed=(_event_seed+1)%37
	particles.visible=true;particles.multimesh.visible_instance_count=active_count
	for i in active_count:particles.multimesh.set_instance_color(i,primary if i%3!=1 else secondary)
	_update_particles()

func advance(delta:float)->void:
	var step:=maxf(0.0,delta);clock_time+=step;age+=step
	var energy:=maxf(0.0,1.0-age/maxf(.001,lifetime))*pulse
	if is_instance_valid(animated_root):
		var bounce:=sin(minf(age/.38,1.0)*TAU)*pow(maxf(0.0,1.0-age/.38),1.5)*pulse
		animated_root.scale=Vector3(1.0+absf(bounce)*.022,1.0-bounce*.13,1.0+absf(bounce)*.022)
	for spec in motion_specs:
		var part:Node3D=spec.node
		var rest:Transform3D=spec.rest_transform
		var role:String=str(spec.get("role","pulse"))
		var phase:float=float(spec.get("phase",0.0))
		part.transform=rest
		if role=="orbit":part.rotate_y(clock_time*.18+phase+energy*.15)
		elif role=="sway":
			var speed:float=float(spec.get("speed",1.45))
			var amplitude:float=float(spec.get("amplitude",.045))
			part.rotation.z+=sin(clock_time*speed+phase)*amplitude+energy*.15*cos(phase)
		else:part.position.y+=sin(clock_time*1.8+phase)*.014+energy*.035
	if is_instance_valid(field_material):field_material.set_shader_parameter("surge",energy)
	if active_count==0:return
	if age>=lifetime:
		active_count=0;rival_active=false;particles.visible=false;particles.multimesh.visible_instance_count=0;return
	_update_particles()

func _update_particles()->void:
	var u:=clampf(age/maxf(.001,lifetime),0,1)
	var fade:=1.0-smoothstep(.55,1.0,u)
	var strength:=1.0 if rival_active else .36
	for i in active_count:
		var angle:=float(i)*TAU/float(active_count)+float(_event_seed)*.11
		var twist:=sin(u*PI)*(.68 if profile in ["petals","arcs","embers"] else .12)
		var distance:=1.17+u*(.80+float(rank)*.06)*strength
		var height:=.12+sin(u*PI)*(.28+float(i%3)*.045)*strength
		if profile=="bubbles":height+=u*.22*strength
		var size:float=(.15+float(rank)*.008+float(i%3)*.02)*strength*fade
		var at:=Vector3(sin(angle+twist)*distance,height,cos(angle+twist)*distance)
		var pose:=Transform3D(Basis.from_euler(Vector3(u*2.8,angle+twist,u*1.5)).scaled(Vector3.ONE*size),at)
		particles.multimesh.set_instance_transform(i,pose)
