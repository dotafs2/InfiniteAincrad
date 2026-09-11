extends CanvasLayer
## Screen-space resident nameplates with deterministic rectangle collision avoidance.
##
## Read-only projection overlay: it never mutates the world, never moves residents or
## the camera, and never writes data. It replaces the per-resident Label3D cards with
## screen-space Label/Panel cards so overlapping 3D labels cannot stack on top of each
## other. Labels ignore mouse input and cannot intercept HUD/dialogue interaction.
##
## Practical limits (documented, not promised):
## - Occlusion uses a single physics ray from the camera to the head anchor. It is a
##   static collision test, not pixel-perfect mesh occlusion; thin geometry may leak.
## - Candidate placement is a finite bounded search. In an overcrowded viewport some
##   distant labels are hidden (reason "no_space") rather than overlapped.
## - Label order never implies custody: held-item text is descriptive only.

const FONT_SIZE := 17
const PANEL_PAD := Vector2(6, 4)
const CARD_GAP := 4.0
const MAX_CANDIDATES := 48
const SAFE_MARGIN := 8.0
const MAX_DISTANCE := 26.0

var town
var actors: Dictionary = {}
var cards: Dictionary = {}
var camera: Camera3D = null
var player: Node3D = null
var hud_controls: Array[Control] = []

var _root: Control = null
var _entries: Dictionary = {}
var _layout: Dictionary = {}

func configure(world, resident_actors: Dictionary, card_nodes: Dictionary, cam: Camera3D, player_node: Node3D, exclusions: Array[Control]) -> void:
	town = world
	actors = resident_actors
	cards = card_nodes
	camera = cam
	player = player_node
	hud_controls = exclusions.duplicate()
	layer = 5
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	for id in town.active_ids():
		_ensure_entry(id)

## Hides the legacy Label3D backing card for an id once the overlay owns the title.
func set_card_hidden(id: String, hidden: bool) -> void:
	var card: Label3D = cards.get(id)
	if card != null:
		card.visible = not hidden

func _ensure_entry(id: String) -> void:
	if _entries.has(id):
		return
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.09, 0.82)
	style.content_margin_left = PANEL_PAD.x
	style.content_margin_right = PANEL_PAD.x
	style.content_margin_top = PANEL_PAD.y
	style.content_margin_bottom = PANEL_PAD.y
	style.set_corner_radius_all(5)
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", Color("f2e8d5"))
	panel.add_child(label)
	var line := Line2D.new()
	line.width = 1.0
	line.default_color = Color(0.85, 0.78, 0.62, 0.55)
	line.z_index = -1
	_root.add_child(line)
	_root.add_child(panel)
	_entries[id] = {"panel": panel, "label": label, "line": line}

func _head_anchor(id: String) -> Vector3:
	var actor_variant: Variant = actors.get(id)
	if not is_instance_valid(actor_variant):
		return Vector3.INF
	if not (actor_variant is Node3D):
		return Vector3.INF
	var actor: Node3D = actor_variant
	return actor.global_position + Vector3(0, 1.85, 0)

func _collision_ancestor(node: Node) -> CollisionObject3D:
	var current: Node = node
	while current != null:
		if current is CollisionObject3D:
			return current as CollisionObject3D
		current = current.get_parent()
	return null

func _is_occluded(anchor: Vector3, id: String) -> bool:
	if camera == null:
		return false
	var space := camera.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, anchor)
	var exclude: Array[RID] = []
	var player_body := _collision_ancestor(player)
	if player_body != null:
		exclude.append(player_body.get_rid())
	var actor: Node = actors.get(id)
	var actor_body := _collision_ancestor(actor)
	if actor_body != null:
		exclude.append(actor_body.get_rid())
	query.exclude = exclude
	var hit := space.intersect_ray(query)
	return not hit.is_empty()

func _candidate_positions(base: Vector2, size: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	out.append(base)
	var step_x := size.x + CARD_GAP
	var step_y := size.y + CARD_GAP
	var rings := [1, 2, 3]
	for ring in rings:
		var dx := step_x * float(ring)
		var dy := step_y * float(ring)
		var ring_offsets: Array[Vector2] = [
			Vector2(0, -dy), Vector2(0, dy), Vector2(dx, 0), Vector2(-dx, 0),
			Vector2(dx, -dy), Vector2(-dx, -dy), Vector2(dx, dy), Vector2(-dx, dy),
			Vector2(dx * 0.5, -dy), Vector2(-dx * 0.5, -dy), Vector2(dx * 0.5, dy), Vector2(-dx * 0.5, dy),
			Vector2(dx, -dy * 0.5), Vector2(-dx, -dy * 0.5), Vector2(dx, dy * 0.5), Vector2(-dx, dy * 0.5)]
		for offset in ring_offsets:
			if out.size() >= MAX_CANDIDATES:
				return out
			out.append(base + offset)
	return out

func _fits(rect: Rect2, placed: Array[Rect2], view: Vector2) -> bool:
	if rect.position.x < SAFE_MARGIN or rect.position.y < SAFE_MARGIN:
		return false
	if rect.end.x > view.x - SAFE_MARGIN or rect.end.y > view.y - SAFE_MARGIN:
		return false
	for other in placed:
		if rect.grow(CARD_GAP).intersects(other):
			return false
	for control in hud_controls:
		if not is_instance_valid(control) or not control.is_visible_in_tree():
			continue
		if rect.intersects(control.get_global_rect()):
			return false
	return true

func _process(_delta: float) -> void:
	if town == null or camera == null or _root == null:
		return
	var view := get_viewport().get_visible_rect().size
	_root.size = view
	var active: Array[String] = []
	for id in town.active_ids():
		active.append(id)
	for id in active:
		_ensure_entry(id)
	for id in _entries.keys():
		if id in active:
			continue
		var stale: Dictionary = _entries[id]
		var stale_panel: PanelContainer = stale.panel
		var stale_line: Line2D = stale.line
		if is_instance_valid(stale_panel):
			stale_panel.visible = false
			stale_panel.queue_free()
		if is_instance_valid(stale_line):
			stale_line.visible = false
			stale_line.queue_free()
		_entries.erase(id)
	# Hide every entry before laying out the active valid rows. This guarantees an
	# active id whose actor is missing/freed cannot leave a stale panel visible.
	for id in _entries.keys():
		var hide_entry: Dictionary = _entries[id]
		var hide_panel: PanelContainer = hide_entry.panel
		var hide_line: Line2D = hide_entry.line
		if is_instance_valid(hide_panel):
			hide_panel.visible = false
		if is_instance_valid(hide_line):
			hide_line.visible = false
			hide_line.points = PackedVector2Array()
	var placed: Array[Rect2] = []
	var cam_pos := camera.global_position
	var ordered: Array[String] = []
	_layout = {}
	for id in active:
		var anchor := _head_anchor(id)
		if not anchor.is_finite():
			# Active id with a missing/freed actor: report it explicitly instead of
			# silently skipping while an old panel stays on screen.
			_layout[id] = {"id": id, "rect": Rect2(), "anchor": Vector3.INF, "visible": false, "reason": "missing_actor"}
			continue
		ordered.append(id)
	ordered.sort_custom(func(a: String, b: String) -> bool:
		var da := cam_pos.distance_to(_head_anchor(a))
		var db := cam_pos.distance_to(_head_anchor(b))
		if da == db:
			return a < b
		return da < db)
	for id in ordered:
		var entry: Dictionary = _entries.get(id, {})
		if entry.is_empty():
			continue
		var panel: PanelContainer = entry.panel
		var label: Label = entry.label
		var line: Line2D = entry.line
		var anchor := _head_anchor(id)
		var card: Label3D = cards.get(id)
		if card != null:
			label.text = card.text
			card.visible = false
		var distance := cam_pos.distance_to(anchor)
		var screen := camera.unproject_position(anchor)
		var behind := camera.is_position_behind(anchor)
		var reason := ""
		if behind:
			reason = "screen"
		elif distance > MAX_DISTANCE:
			reason = "screen"
		elif screen.x < 0.0 or screen.y < 0.0 or screen.x > view.x or screen.y > view.y:
			reason = "screen"
		elif _is_occluded(anchor, id):
			reason = "occluded"
		if not reason.is_empty():
			panel.visible = false
			line.visible = false
			line.points = PackedVector2Array()
			_layout[id] = {"id": id, "rect": Rect2(), "anchor": anchor, "visible": false, "reason": reason}
			continue
		panel.visible = true
		var size := panel.get_combined_minimum_size()
		var base := screen - Vector2(size.x * 0.5, size.y + 14.0)
		var chosen := Rect2()
		var found := false
		for candidate in _candidate_positions(base, size):
			var rect := Rect2(candidate, size)
			if _fits(rect, placed, view):
				chosen = rect
				found = true
				break
		if not found:
			panel.visible = false
			line.visible = false
			line.points = PackedVector2Array()
			_layout[id] = {"id": id, "rect": Rect2(), "anchor": anchor, "visible": false, "reason": "no_space"}
			continue
		panel.position = chosen.position
		panel.size = size
		placed.append(chosen)
		line.visible = true
		var attach := Vector2(clampf(screen.x, chosen.position.x, chosen.end.x), clampf(screen.y, chosen.position.y, chosen.end.y))
		line.points = PackedVector2Array([attach, screen])
		_layout[id] = {"id": id, "rect": chosen, "anchor": anchor, "visible": true, "reason": ""}

## Read-only layout snapshot for later acceptance checks. Never fabricates success:
## hidden entries report their reason (screen / occluded / no_space).
func layout_snapshot() -> Dictionary:
	return _layout.duplicate(true)
