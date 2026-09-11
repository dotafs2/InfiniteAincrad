extends Node3D
## Visual projection only: never creates inventory, repairs or transfers custody.
var town
var actors: Dictionary
var axes: Dictionary = {}
var materials: Dictionary = {}
var facts: Label3D

func configure(world, resident_actors: Dictionary) -> void:
	town = world
	actors = resident_actors
	for item in town.snapshot().life.get("items", []):
		if item.get("kind") != "axe":
			continue
		var axe := Node3D.new()
		add_child(axe)
		box(axe, Vector3.ZERO, Vector3(0.035, 0.48, 0.035), Color("82582f"))
		box(axe, Vector3(0.07, 0.17, 0), Vector3(0.20, 0.12, 0.06), Color("a7b4b5"))
		axes[item.id] = axe
	facts = Label3D.new()
	facts.font_size = 30
	facts.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	facts.outline_size = 8
	add_child(facts)
	for id in town.active_ids():
		var pile := Node3D.new()
		pile.position = town.destination(id, "rest") + Vector3(0.8, 0.12, -0.4)
		add_child(pile)
		for index in 6:
			box(pile, Vector3((index % 3) * 0.10, (index / 3) * 0.07, 0), Vector3(0.08, 0.055, 0.35), Color("ba9160"))
		materials[id] = pile

func _process(_delta: float) -> void:
	if town == null or facts == null:
		return
	var state: Dictionary = town.snapshot()
	var lines: Array[String] = []
	for item in state.life.get("items", []):
		if not axes.has(item.id) or not actors.has(item.custodian_id):
			continue
		var actor: Node3D = actors[item.custodian_id]
		axes[item.id].global_transform = actor.global_transform
		axes[item.id].global_position = actor.to_global(Vector3(0.32, 0.75, -0.12))
		lines.append("斧刃 %d · 斧柄 %d\n持有人：%s" % [item.edge, item.handle, town.resident(item.custodian_id).name])
		facts.global_position = actor.global_position + Vector3(0, 2.7, 0)
	for account in state.life.get("accounts", []):
		if materials.has(account.resident_id):
			var pile: Node3D = materials[account.resident_id]
			for index in pile.get_child_count():
				pile.get_child(index).visible = index < int(account.get("kindling", 0))
	facts.text = "\n".join(lines)

func box(parent: Node3D, position_value: Vector3, size: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.position = position_value
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	mesh.material_override = material
	parent.add_child(mesh)
