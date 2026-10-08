extends RefCounted
## Deterministic area combat. Cells carry fire energy, never individual bullets.
## A fixed 10-Hz moving coverage front keeps the visual travel rhythm cheap.
const CELL_COUNT := 32
const CELL_WIDTH := 0.35
const LEFT := -5.6
const TICK := 0.1
const MAX_AGE := 3.0
var game: Node3D
var pending: Dictionary = {}
var fields: Array[Dictionary] = []
var clock := 0.0
var resolved_ticks := 0
var peak_fields := 0

func setup(owner_game: Node3D) -> void:
	game=owner_game

func reset() -> void:
	pending.clear();fields.clear();clock=0;resolved_ticks=0;peak_fields=0

func speed(mode: String) -> float:
	return 52.0 if mode=="rail" else 23.0 if mode=="rocket" else 34.0

func enqueue(origin: Vector3, mode: String, tier: int, pellets: int=1) -> void:
	var width:float={"rifle":0.50,"scatter":2.20,"rail":0.35,"rocket":0.75,"arc":0.75}.get(mode,0.50)
	if not pending.has(mode):
		var energy:=PackedFloat64Array();energy.resize(CELL_COUNT)
		pending[mode]={"energy":energy,"z":origin.z,"mode":mode,"tier":tier}
	var bank:Dictionary=pending[mode]
	# The rear muzzle defines the representative front, avoiding early rear-row hits.
	bank.z=maxf(bank.z,origin.z)
	bank.tier=maxi(bank.tier,tier)
	var amount:float=game.Campaign.weapon_power(mode,tier)*pellets
	_deposit(bank.energy,origin.x-width*0.5,origin.x+width*0.5,amount)

func _deposit(energy: PackedFloat64Array, left: float, right: float, amount: float) -> void:
	var width:=maxf(0.000001,right-left)
	for cell in range(maxi(0,floori((left-LEFT)/CELL_WIDTH)),mini(CELL_COUNT,ceili((right-LEFT)/CELL_WIDTH))):
		var overlap:=maxf(0,minf(right,LEFT+(cell+1)*CELL_WIDTH)-maxf(left,LEFT+cell*CELL_WIDTH))
		energy[cell]+=amount*overlap/width

func step(delta: float) -> void:
	clock+=delta
	while clock+0.0000001>=TICK:
		clock=maxf(0,clock-TICK)
		_tick()

func _tick() -> void:
	resolved_ticks+=1
	for mode in game.Campaign.WEAPONS:
		if not pending.has(mode): continue
		var bank:Dictionary=pending[mode]
		var contacts:=PackedInt32Array();contacts.resize(CELL_COUNT)
		fields.append({"energy":bank.energy,"contacts":contacts,"mode":mode,"z":bank.z,"age":0.0,"secondary":false,"tier":bank.tier})
	pending.clear()
	peak_fields=maxi(peak_fields,fields.size())
	var living:Array[Dictionary]=[]
	for field in fields:
		var previous:float=field.z
		field.z-=speed(field.mode)*TICK;field.age+=TICK
		_resolve(field,previous,field.z)
		if field.age<MAX_AGE and field.z> -50.0 and _total(field)>0.0000001: living.append(field)
	fields=living

func _total(field: Dictionary) -> float:
	var total:=0.0
	for value in field.energy: total+=value
	return total

func _fraction(cell: int, left: float, right: float) -> float:
	return clampf((minf(right,LEFT+(cell+1)*CELL_WIDTH)-maxf(left,LEFT+cell*CELL_WIDTH))/CELL_WIDTH,0,1)

func _sample(field: Dictionary, left: float, right: float) -> float:
	var result:=0.0
	for cell in range(maxi(0,floori((left-LEFT)/CELL_WIDTH)),mini(CELL_COUNT,ceili((right-LEFT)/CELL_WIDTH))):
		result+=field.energy[cell]*_fraction(cell,left,right)
	return result

func _debit(field: Dictionary, left: float, right: float, amount: float, available: float) -> void:
	if available<=0: return
	var ratio:=clampf(amount/available,0,1)
	for cell in range(maxi(0,floori((left-LEFT)/CELL_WIDTH)),mini(CELL_COUNT,ceili((right-LEFT)/CELL_WIDTH))):
		field.energy[cell]=maxf(0,field.energy[cell]*(1.0-_fraction(cell,left,right)*ratio))

func _resolve(field: Dictionary, previous: float, current: float) -> void:
	# Only crossed depth layers are considered; sort at most 43 scene layers,
	# rather than building and sorting an event list for every displayed streak.
	var events:Array[Dictionary]=[]
	for i in range(3):
		if previous>=game.GATE_Z[i] and current<game.GATE_Z[i]: events.append({"kind":"gate","z":game.GATE_Z[i],"index":i})
	if game.tier<3 and not game.recruiting and previous>=-10.4 and current< -10.4: events.append({"kind":"recruit","z":-10.4})
	for row in range(34):
		var z:float=game.crowd_front-row*0.43
		if previous>=z and current<z: events.append({"kind":"row","z":z,"row":row})
	for enemy in game.encounters.enemies:
		var z:float=enemy.node.position.z+0.7
		if enemy.alive and previous>=z and current<z: events.append({"kind":"elite","z":z,"target":enemy})
	if not game.boss_dead and previous>=game.boss_z+1.1 and current<game.boss_z+1.1: events.append({"kind":"boss","z":game.boss_z+1.1})
	events.sort_custom(func(a,b):return a.z>b.z)
	for event in events:
		if _total(field)<=0.0000001: break
		match event.kind:
			"gate": _gate(field,event.index)
			"recruit":
				var amount:=_sample(field,0.65,5.6)
				_debit(field,0.65,5.6,amount,amount);game._damage_recruit(amount)
			"row":
				for col in range(16):
					var target:Dictionary=game.crowd[event.row*16+col]
					if target.alive: _hit(field,"troop",target,target.x,0.18,event.z,target.id)
			"elite":
				if event.target.alive: _hit(field,"elite",event.target,event.target.node.position.x,0.82,event.z,event.target.id)
			"boss":
				if not game.boss_dead: _hit(field,"boss",{},game.boss.position.x,2.0,event.z,-2)

func _gate(field: Dictionary, index: int) -> void:
	var center:float=game.gates[index].position.x
	var left:float=center-game.GATE_WIDTH[index]*0.5
	var right:float=center+game.GATE_WIDTH[index]*0.5
	var covered:=_sample(field,left,right)
	if covered<=0: return
	if index==1 and game.gold_hp>0:
		_debit(field,left,right,covered,covered)
		game.gold_hp=maxf(0,game.gold_hp-covered)
		game._emit(Vector3(center,0.7,game.GATE_Z[index]),Color("ffcc32"),4,0.12)
		if game.gold_hp==0:
			game.message="×999 GATE OPEN";game.message_time=1.4;game._sound(game.upgrade_audio,-17)
		return
	var before:PackedFloat64Array=field.energy.duplicate()
	var visual_x:=0.0
	var prior_contacts:=0
	for cell in range(CELL_COUNT):
		visual_x+=before[cell]*_fraction(cell,left,right)*(LEFT+(cell+0.5)*CELL_WIDTH)
		if before[cell]>0: prior_contacts=maxi(prior_contacts,field.contacts[cell])
	var spread:float=[1.65,4.5,3.3][index]
	var multiplier:float=[5.0,999.0,2.0][index]
	for cell in range(CELL_COUNT):
		var part:float=before[cell]*_fraction(cell,left,right)
		if part<=0: continue
		field.energy[cell]-=part
		var x:float=LEFT+(cell+0.5)*CELL_WIDTH
		# Keep energy on the playable strip when the multiplied spray fans out.
		var lo:=maxf(LEFT,x-spread*0.5);var hi:=minf(-LEFT,x+spread*0.5)
		_deposit(field.energy,lo,hi,part*multiplier)
	if field.mode=="rail":
		# Fan-out must never give carried rail energy a fresh penetration allowance.
		for cell in range(CELL_COUNT): field.contacts[cell]=maxi(field.contacts[cell],prior_contacts)
	game.spray.emit_gate(Vector3(visual_x/covered,0.85,game.GATE_Z[index]),spread,field.mode,field.get("tier",game.tier))
	game.metrics[["gate5","gate999","gate2"][index]]+=1

func _hit(field: Dictionary, kind: String, target: Dictionary, x: float, radius: float, z: float, id: int) -> void:
	var left:=x-radius;var right:=x+radius
	var amount:=_sample(field,left,right)
	if amount<=0.0000001: return
	var spent:=0.0
	if kind=="troop":
		spent=minf(target.hp,amount);target.hp-=spent;game.metrics.damage+=spent
		if target.hp<=0:
			target.alive=false;game.kills+=1;game.crowd_dirty=true
			if game.kill_flashes.size()<game.death_cap: game.kill_flashes.append({"x":x,"z":z,"life":0.26})
	elif kind=="elite": spent=game.encounters.damage(target,amount,field.mode)
	else: spent=minf(game.boss_hp,amount);game._damage_boss(amount)
	if field.mode=="rail":
		for cell in range(maxi(0,floori((left-LEFT)/CELL_WIDTH)),mini(CELL_COUNT,ceili((right-LEFT)/CELL_WIDTH))):
			if field.energy[cell]>0 and _fraction(cell,left,right)>0:
				field.contacts[cell]+=1
				if field.contacts[cell]>=6: field.energy[cell]=0
	elif field.mode in ["rocket","arc"]:
		_debit(field,left,right,amount,amount)
		# One grouped discharge per coverage salvo; never one explosion per streak.
		if not field.secondary:
			field.secondary=true
			var impact:=Vector3(x,2.0 if kind=="boss" else 0.65,z)
			if field.mode=="rocket": game.area_damage(impact,1.85,amount*0.70,id)
			else: game.chain_damage(impact,amount,id)
	else: _debit(field,left,right,spent,amount)

func fingerprint() -> Dictionary:
	var data:Array=[]
	for field in fields:
		data.append([field.mode,snappedf(field.z,0.000001),field.energy.duplicate(),field.contacts.duplicate(),field.secondary])
	var banks:Dictionary={}
	for mode in game.Campaign.WEAPONS:
		if pending.has(mode):banks[mode]=[pending[mode].z,pending[mode].energy.duplicate()]
	return {"clock":snappedf(clock,0.000001),"pending":banks,"fields":data,"ticks":resolved_ticks}
