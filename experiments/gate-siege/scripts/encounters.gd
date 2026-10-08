extends RefCounted
const Motion = preload("res://scripts/creature_motion.gd")
var game: Node3D
var enemies: Array[Dictionary] = []
var hazards: Array[Dictionary] = []
var next_id := 10000
var warning_mesh:PlaneMesh
var warning_material:ShaderMaterial

func start(owner_game: Node3D) -> void:
	game=owner_game;enemies.clear();hazards.clear()
	var list:Array=game.Campaign.WAVES[game.wave].elites
	for i in range(list.size()):
		var kind:String=list[i]
		var node:=Node3D.new();game.stage_root.add_child(node)
		node.position=Vector3([-3.9,-0.65,-2.3,0.0][i%4],0,-6.0-i*3.4)
		var art:Node3D=game.model("dragon" if kind=="drake" else "golem" if kind=="shield" else "skitter")
		node.add_child(art);art.rotation.y=PI
		art.scale=Vector3.ONE*(0.57 if kind=="drake" else 0.58 if kind=="shield" else 0.65)
		var hp:float=(180.0+game.wave*130.0)*(2 if kind=="shield" else 1.5 if kind=="drake" else 1.0)
		var bar:MeshInstance3D=game.box(node,Vector3(0,2.45 if kind=="drake" else 2.0,0),Vector3(1.35,0.1,0.07),game.material(Color("63e6cf")))
		game._add_blob(node,Vector2(1.8,1.1))
		enemies.append({"id":next_id,"kind":kind,"health":hp,"max_health":hp,"node":node,"art":art,"bar":bar,"clock":i*0.4,"attack_clock":2.0+i*.9,"death":0.0,"alive":true})
		next_id+=1

func alive_count() -> int:
	var count:=0
	for enemy in enemies:
		if enemy.alive: count+=1
	return count

func step(delta: float) -> void:
	for enemy in enemies:
		enemy.clock+=delta
		if not enemy.alive:
			enemy.death+=delta
			Motion.pose(enemy.art,enemy.kind,enemy.clock,0,minf(1,enemy.death/0.6))
			if enemy.death>0.7: enemy.node.hide()
			continue
		var speed:float=1.05 if enemy.kind=="skitter" else 0.60 if enemy.kind=="shield" else 0.8
		enemy.node.position.z=minf(game.PLAYER_Z-1.9,enemy.node.position.z+delta*speed)
		Motion.pose(enemy.art,enemy.kind,enemy.clock)
		enemy.attack_clock-=delta
		if enemy.attack_clock<=0:
			enemy.attack_clock=5.5 if enemy.kind=="drake" else 7.0
			warn(game.player_x,game.squad.hurtbox_position().z,1.2 if enemy.kind=="drake" else 0.88,12 if enemy.kind=="drake" else 8)
	if warning_material: warning_material.set_shader_parameter("clock",game.sim_time)
	for hazard in hazards:
		hazard.life-=delta
		if hazard.life<=0 and not hazard.hit:
			hazard.hit=true
			var center:Vector3=game.squad.hurtbox_position()
			var struck:bool=Vector2(center.x-hazard.x,center.z-hazard.z).length()<hazard.radius+game.squad.hurtbox_radius
			if struck: game.health=maxf(0,game.health-hazard.damage);game.shake=0.22
			game._emit(Vector3(hazard.x,0.4,hazard.z),Color("ff9e41"),22,0.21)
			hazard.node.queue_free()
	hazards=hazards.filter(func(h):return not h.hit)

func warning_visual() -> MeshInstance3D:
	if not warning_mesh:
		warning_mesh=PlaneMesh.new();warning_mesh.size=Vector2(2,2)
		warning_material=ShaderMaterial.new();warning_material.shader=preload("res://assets/shaders/attack_warning.gdshader")
	var mesh:=MeshInstance3D.new();mesh.mesh=warning_mesh;mesh.material_override=warning_material
	mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh

func warn(x: float,z: float,radius: float,damage: float) -> void:
	if hazards.size()>=6: return
	var mesh:=warning_visual();mesh.scale=Vector3(radius,1,radius)
	mesh.position=Vector3(x,0.043,z);game.stage_root.add_child(mesh)
	hazards.append({"node":mesh,"x":x,"z":z,"radius":radius,"damage":damage,"life":1.35,"hit":false})

func damage(enemy: Dictionary, amount: float, mode: String) -> float:
	if not enemy.alive or amount<=0: return 0
	var protection:float=0.45 if enemy.kind=="shield" and mode not in ["rail","rocket","arc"] else 1.0
	var applied:=minf(enemy.health,amount*protection)
	enemy.health-=applied;game.metrics.damage+=applied
	enemy.bar.scale.x=maxf(0.001,enemy.health/enemy.max_health)
	game._emit(enemy.node.position+Vector3(0,1,0),Color("b7ffe9"),3,0.08)
	if enemy.health<=0:
		enemy.alive=false;enemy.bar.hide();game.kills+=1;game.metrics.elites+=1
	return applied/protection

func hit_segment(packet: Dictionary, previous: float) -> bool:
	var candidates:Array=[]
	for enemy in enemies:
		if enemy.alive and absf(packet.pos.x-enemy.node.position.x)<0.82+packet.width*0.5 and previous>=enemy.node.position.z+0.7 and packet.pos.z<=enemy.node.position.z+0.7: candidates.append(enemy)
	candidates.sort_custom(func(a,b):return a.node.position.z>b.node.position.z)
	for enemy in candidates:
		var amount:float=packet.power*packet.count
		damage(enemy,amount,packet.weapon)
		if packet.weapon=="rocket": game.area_damage(enemy.node.position,1.85,amount*0.7,enemy.id)
		if packet.weapon=="arc": game.chain_damage(enemy.node.position,amount,enemy.id)
		if packet.weapon!="rail": return true
	return false

func settled() -> bool:
	for enemy in enemies:
		if enemy.alive or enemy.death<0.7: return false
	return true
