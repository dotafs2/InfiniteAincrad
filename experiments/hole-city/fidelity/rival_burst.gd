extends Node3D
## One short cosmetic burst per real player victory. One draw, no physics.
const COUNT:=28
const LIFETIME:=.85
var age:=0.0
var profile:=""
var skin_id:=""
var palette:Array[Color]=[]
var particles:MultiMeshInstance3D
var starts:Array[Vector3]=[]
var velocities:Array[Vector3]=[]
var rotations:Array[Vector3]=[]
var sizes:Array[float]=[]
var poses:Array[Transform3D]=[]

static func profile_for(id:String)->String:
	if id in ["cinder","rocket_port","lantern","storm_cloud"]:return "sparks"
	if id in ["tide","jelly_veil","frog_pond","turtle_shell"]:return "droplets"
	if id in ["moss_bloom","pineapple_top","berry_crown"]:return "leaves"
	if id in ["shard","prism_vale","mirror_gate","orbit","core_shell","satellite_dish"]:return "shards"
	return "confetti"

func build(definition:Dictionary,radius:float)->void:
	skin_id=str(definition.id);profile=profile_for(skin_id)
	palette=[Color(definition.tint),Color(definition.accent),Color(definition.accent).lightened(.30)]
	particles=MultiMeshInstance3D.new();add_child(particles)
	particles.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh:Mesh
	match profile:
		"droplets":
			var drop:=SphereMesh.new();drop.radius=.42;drop.height=1.2;drop.radial_segments=8;drop.rings=4;mesh=drop
		"shards","leaves":
			var shard:=PrismMesh.new();shard.size=Vector3(.70,1.30,.16 if profile=="leaves" else .50);mesh=shard
		_:
			var chip:=BoxMesh.new();chip.size=Vector3(.24,.95,.14) if profile=="sparks" else Vector3(.60,.30,.13);mesh=chip
	var mat:=StandardMaterial3D.new()
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo=true
	particles.material_override=mat
	var instances:=MultiMesh.new();instances.transform_format=MultiMesh.TRANSFORM_3D
	instances.use_colors=true;instances.mesh=mesh;instances.instance_count=COUNT
	particles.multimesh=instances
	poses.resize(COUNT)
	var size:=clampf(radius*.09,.18,1.8)
	var reach:=clampf(radius*2.4,3.2,96.0)
	for i in COUNT:
		var angle:=float(i)*2.399963
		var outward:=Vector3(sin(angle),0,cos(angle))
		starts.append(outward*radius*.45+Vector3.UP*.22)
		velocities.append(outward*reach*(.70+float(i%5)*.10)+Vector3.UP*reach*(.55+float(i%4)*.08))
		rotations.append(Vector3(.4+float(i%3),angle,float(i)*.7))
		sizes.append(size*(.75+float(i%4)*.13))
		instances.set_instance_color(i,palette[i%palette.size()])
	update_particles()

func update_particles()->void:
	var fade:=1.0-smoothstep(.48,LIFETIME,age)
	for i in COUNT:
		var at:=starts[i]+velocities[i]*age+Vector3.DOWN*age*age*4.0
		var basis:=Basis.from_euler(rotations[i]+Vector3(1.2,.8,.6)*age).scaled(Vector3.ONE*sizes[i]*fade)
		poses[i]=Transform3D(basis,at)
		particles.multimesh.set_instance_transform(i,poses[i])

func _process(delta:float)->void:
	age+=delta
	if age>=LIFETIME:queue_free();return
	if is_instance_valid(particles):update_particles()
