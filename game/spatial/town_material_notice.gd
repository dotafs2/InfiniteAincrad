extends "res://spatial/town_place_notice.gd"
## A physical public route notice. Reading it is not sight of source stock.
var lettering: Label3D
var published_entries: Array = []

func notice_spec() -> Dictionary:
	var base: Vector3 = town.material_notice_position()
	return {"id": town.MATERIAL_NOTICE_ID, "label": "Public Material Routes",
		"asset": Catalog.NOTICE.asset, "position": [base.x, base.y, base.z], "yaw": 200.0,
		"point": [base.x, base.y + 1.55, base.z], "read_range_m": town.MATERIAL_NOTICE_RANGE}

func build() -> void:
	if town.material_notice_entries().is_empty(): return
	super.build()
	if not placed: return
	name = "PublicMaterialNotice"
	lettering = Label3D.new()
	lettering.font_size = 28
	lettering.outline_size = 4
	lettering.pixel_size = 0.0032
	lettering.width = 550
	lettering.modulate = Color(1.0, 0.92, 0.72)
	lettering.outline_modulate = Color(0.08, 0.06, 0.03, 1.0)
	lettering.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lettering.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lettering.position = notice_point()
	add_child(lettering)
	_sync_text()

func _sync_text() -> void:
	var entries: Array = town.material_notice_entries()
	if entries == published_entries: return
	published_entries = entries
	lettering.text = "PUBLIC MATERIAL ROUTES"
	for entry in published_entries: lettering.text += "\n" + str(entry.text)

func observe() -> Dictionary:
	if town != null and not placed: build()
	if town == null or not placed or not is_inside_tree() or not is_visible_in_tree() or not visual.is_visible_in_tree() or not lettering.is_visible_in_tree():
		return {"ok": false, "code": "material_notice_unavailable"}
	_sync_text()
	var learned := {}
	for id in town.active_ids():
		if town.position_of(id).distance_to(town.material_notice_position()) > town.MATERIAL_NOTICE_RANGE: continue
		var needs_notice := false
		for source in published_entries:
			if not town._known_materials(id).has(source.id): needs_notice = true
		if not needs_notice: continue
		var result: Dictionary = town.observe_material_notice(id, visible_from(id))
		if not result.get("ok", false): return result
		if not result.learned.is_empty(): learned[id] = result.learned
	return {"ok": true, "learned": learned}

func evidence() -> Dictionary:
	return {"notice": notice_spec(), "placed": placed, "collision": is_instance_valid(solid),
		"published_entries": published_entries.duplicate(true), "stock_disclosed": false}
