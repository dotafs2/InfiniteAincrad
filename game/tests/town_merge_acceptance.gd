extends "res://tests/town_trade_acceptance.gd"
## Integrated-scene acceptance for the Mac/Windows town merge.
##
## Loads the ACTUAL scene res://scenes/town_street.tscn (not source-string matching),
## keeps it PAUSED throughout, and only toggles scene.repair_fixture /
## gateway_mode / restore_only / scripted_trade AFTER ready while paused. No live
## provider is configured or stepped; _process must not invoke model_turns.
##
## Reproduction (run from the repo root; fixture created by the existing tool):
##   python3 tools/create_trade_fixture.py --output /tmp/town-merge-fixture.json
##   python3 tools/run_godot.py --godot /absolute/path/to/godot \
##       --name town-merge-headless --timeout 300 \
##       --out /tmp/town-merge-headless.log \
##       -- --headless --script res://tests/town_merge_acceptance.gd -- \
##       --town-save=/tmp/town-merge-fixture.json \
##       --merge-output=/tmp/town-merge-result.json
## Optional graphical capture (non-headless engine):
##   python3 tools/run_godot.py --godot /absolute/path/to/godot \
##       --name town-merge-capture --timeout 300 \
##       --out /tmp/town-merge-capture.log \
##       -- --rendering-method gl_compatibility \
##       --script res://tests/town_merge_acceptance.gd -- \
##       --town-save=/tmp/town-merge-fixture.json \
##       --merge-capture=/tmp/town-merge-capture \
##       --merge-output=/tmp/town-merge-result.json
##
## This script has NOT been executed here; the commands above are the intended
## reproduction path only.

const TownStreetScene := preload("res://scenes/town_street.tscn")
const TownToolsScript := preload("res://spatial/town_tools.gd")

const DRESSING_IDS := [
	"F1_herb_planter",
	"F1_wildflower_patch",
	"F1_fern_patch",
	"F1_meadow_grass",
	"F1_flowering_shrub",
	"F1_berry_bush",
	"F1_roadside_milestone",
	"F1_ivy_wall_panel",
]
const DRESSING_SUFFIX := "_Dressing"

var _scene: Node = null
var _fixture_path := ""
var _capture_dir := ""
var _merge_output := ""
var _fixture_bytes_before := PackedByteArray()
var _fixture_bytes_after := PackedByteArray()
var _errors: Array[String] = []
var _dressing_ids: Array[String] = []
var _image_paths: Array[String] = []
var _image_sizes: Array[String] = []
var _nameplate_image_paths: Array[String] = []
var _nameplate_checks_start := 0
var _nameplate_failures_start := 0
var _nameplate_views: Array = []
var _nameplate_checks := 0
var _nameplate_failures := 0

func _arg_value(prefix: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.trim_prefix(prefix)
	return ""

func _read_bytes(path: String) -> PackedByteArray:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return PackedByteArray()
	var data := file.get_buffer(file.get_length())
	file.close()
	return data

func _count_visible_axes() -> int:
	var visible_count := 0
	var tools: Node = _scene.get("town_tools")
	if tools != null:
		var axes: Dictionary = tools.get("axes")
		for key in axes.keys():
			var node: Node3D = axes[key]
			if is_instance_valid(node) and node.is_visible_in_tree():
				visible_count += 1
	for id in _scene.town.active_ids():
		var actor: Node3D = _scene.actors[id]
		if actor == null:
			continue
		var hand: Node3D = actor.get("_axe") as Node3D
		if hand != null and hand.is_visible_in_tree():
			visible_count += 1
	return visible_count

func _world_axe_count() -> int:
	var count := 0
	for item in _scene.town.snapshot().life.get("items", []):
		if item.get("kind") == "axe":
			count += 1
	return count

func _snapshot() -> Dictionary:
	return _scene.town.snapshot()

func _assert_one_axe(label: String) -> void:
	var world_axes := _world_axe_count()
	var visible := _count_visible_axes()
	check(world_axes == 1, "%s: exactly one real world axe item" % label)
	check(visible == world_axes, "%s: exactly one visible axe projection for the one real item (got %d)" % [label, visible])

func _assert_no_world_change(label: String, before: Dictionary) -> void:
	check(_snapshot() == before, "%s: in-memory world snapshot unchanged" % label)
	check(_read_bytes(_fixture_path) == _fixture_bytes_before, "%s: saved fixture bytes unchanged" % label)

func _apply_mode(repair: bool, gateway: bool, restore: bool, scripted: bool) -> void:
	_scene.repair_fixture = repair
	_scene.gateway_mode = gateway
	_scene.restore_only = restore
	_scene.scripted_trade = scripted
	_scene._refresh()

func run() -> void:
	_fixture_path = _arg_value("--town-save=")
	_capture_dir = _arg_value("--merge-capture=")
	_merge_output = _arg_value("--merge-output=")
	if _fixture_path.is_empty():
		_errors.append("missing --town-save=<fixture>")
		await _finish()
		return
	if OS.get_cmdline_user_args().has("--town-gateway"):
		_errors.append("test must not be launched with --town-gateway")
		await _finish()
		return

	# Validate the exact explicit fixture BEFORE adding the scene or acquiring a writer.
	var probe := TownTrade.new()
	var probe_load := probe.load_from(_fixture_path)
	check(probe_load.ok, "fixture loads for preflight")
	var probe_snap: Dictionary = probe.snapshot()
	check(probe_snap.world_id == "fixture:town-trade-validation", "fixture world_id is exactly fixture:town-trade-validation")
	check(probe_snap.get("fixture", false) == true, "fixture flag is true")
	if not probe_load.ok or probe_snap.world_id != "fixture:town-trade-validation" or probe_snap.get("fixture", false) != true:
		_errors.append("fixture preflight failed; refusing to add scene")
		await _finish()
		return
	_fixture_bytes_before = _read_bytes(_fixture_path)
	check(not _fixture_bytes_before.is_empty(), "fixture file is readable")

	_scene = TownStreetScene.instantiate()
	root.add_child(_scene)
	await process_frame
	await process_frame

	check(_scene._market_loaded, "market asset loaded")
	check(_scene.paused, "scene starts paused")
	check(_scene.model_turns == null, "no model_turns attached (no live provider)")
	check(_scene.get("town_tools") != null, "scene stores a reference to the configured TownTools node")
	check(_scene.get("town_tools") is TownToolsScript, "stored TownTools reference is the configured projector")

	var dressing: Node = _scene.get_node_or_null("Floor1EnvironmentDressing")
	check(dressing != null, "scene has Floor1EnvironmentDressing")
	if dressing != null:
		check(dressing.get_child_count() == 8, "Floor1EnvironmentDressing has all 8 children")
		for child in dressing.get_children():
			var raw := str(child.name)
			var canonical := raw.trim_suffix(DRESSING_SUFFIX) if raw.ends_with(DRESSING_SUFFIX) else raw
			_dressing_ids.append(canonical)
		for expected in DRESSING_IDS:
			check(_dressing_ids.has(expected), "dressing id present: %s" % expected)

	check(_scene.town.active_ids().size() == 3, "all 3 fixture actors present")
	for id in _scene.town.active_ids():
		check(_scene.actors.has(id), "actor node exists for %s" % id)

	# Ordinary offline view (no gateway, no restore, no legacy fixture, no scripted trade).
	_apply_mode(false, false, false, false)
	await process_frame
	await process_frame
	_assert_one_axe("ordinary offline")
	var ordinary_snapshot := _snapshot()

	# Legacy labelled fixture view: Mac hand-axe projection is allowed here.
	_apply_mode(true, false, false, false)
	await process_frame
	await process_frame
	_assert_one_axe("legacy repair fixture")
	_apply_mode(false, false, false, false)
	await process_frame
	await process_frame
	_assert_one_axe("return from legacy fixture")

	# Scripted trade view: TownTools only, never hand axe.
	_apply_mode(false, false, false, true)
	await process_frame
	await process_frame
	_assert_one_axe("scripted trade")
	_apply_mode(false, false, false, false)
	await process_frame
	await process_frame
	_assert_one_axe("return from scripted trade")

	# Gateway-labelled paused view: must not hide the actual item.
	_apply_mode(false, true, false, false)
	await process_frame
	await process_frame
	_assert_one_axe("gateway-labelled paused")
	check(_scene.model_turns == null, "gateway flag alone does not attach a provider")
	var gateway_before := _snapshot()
	_scene._request_edge_repair()
	await process_frame
	_assert_no_world_change("gateway R/_request_edge_repair", gateway_before)
	_apply_mode(false, false, false, false)
	await process_frame
	await process_frame
	_assert_one_axe("return from gateway")

	# Restore view: R must change nothing.
	_apply_mode(false, false, true, false)
	await process_frame
	await process_frame
	_assert_one_axe("restore view")
	var restore_before := _snapshot()
	_scene._request_edge_repair()
	await process_frame
	_assert_no_world_change("restore R/_request_edge_repair", restore_before)
	_apply_mode(false, false, false, false)
	await process_frame
	await process_frame
	_assert_one_axe("return from restore")

	# Custody/condition preserved and no invented world item.
	var axe: Dictionary = {}
	for item in _snapshot().life.get("items", []):
		if item.get("kind") == "axe":
			axe = item
			break
	check(not axe.is_empty(), "real fixture axe item present")
	check(axe.get("custodian_id") == "fixture:innkeeper", "axe custody preserved")
	check(int(axe.get("edge", -1)) == 20 and int(axe.get("handle", -1)) == 20, "axe condition preserved")
	check(_snapshot() == ordinary_snapshot, "world snapshot identical to ordinary offline baseline")
	check(_scene.paused, "scene remains paused throughout")

	if not _capture_dir.is_empty():
		await _capture()

	# Actual-geometry/state nameplate acceptance. Runs both graphical and headless.
	await _verify_nameplates()

	_fixture_bytes_after = _read_bytes(_fixture_path)
	check(_fixture_bytes_after == _fixture_bytes_before, "saved fixture bytes preserved end-to-end")

	await _finish()

func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		_errors.append("capture requested but engine is headless")
		return
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	root.size = Vector2i(1400, 900)
	_scene.paused = true
	_scene._refresh()
	var hud: Label = _scene.status
	if hud != null:
		hud.text = "整合验收 · 测试世界 · 无模型调用\n" + hud.text
	_scene._camera.global_position = Vector3(0, 5, 14)
	_scene._camera.look_at(Vector3(0, 1, 4))
	for i in 24:
		await process_frame
	await RenderingServer.frame_post_draw
	var overview := _scene.get_viewport().get_texture().get_image()
	var overview_path := _capture_dir.path_join("merge_overview.png")
	var overview_err := overview.save_png(overview_path)
	if overview_err != OK:
		_errors.append("overview screenshot failed: %d" % overview_err)
	else:
		_image_paths.append(overview_path)
		_image_sizes.append("%dx%d" % [overview.get_width(), overview.get_height()])
	_scene._camera.global_position = Vector3(4, 3, 11)
	_scene._camera.look_at(Vector3(-1, 1, 6))
	for i in 24:
		await process_frame
	await RenderingServer.frame_post_draw
	var residents := _scene.get_viewport().get_texture().get_image()
	var residents_path := _capture_dir.path_join("merge_residents.png")
	var residents_err := residents.save_png(residents_path)
	if residents_err != OK:
		_errors.append("residents screenshot failed: %d" % residents_err)
	else:
		_image_paths.append(residents_path)
		_image_sizes.append("%dx%d" % [residents.get_width(), residents.get_height()])

func _rect_array(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]

func _vec_array(value: Vector2) -> Array:
	return [value.x, value.y]

func _nameplate_entries() -> Dictionary:
	var overlay: Node = _scene.get("nameplates")
	if overlay == null:
		return {}
	return overlay.get("_entries")

func _nameplate_layout() -> Dictionary:
	var overlay: Node = _scene.get("nameplates")
	if overlay == null:
		return {}
	return overlay.layout_snapshot()

func _visible_panel_rects() -> Array:
	var out: Array = []
	var entries := _nameplate_entries()
	for id in entries.keys():
		var entry: Dictionary = entries[id]
		var panel: Control = entry.get("panel")
		if is_instance_valid(panel) and panel.is_visible_in_tree():
			out.append({"id": id, "rect": panel.get_global_rect()})
	return out

func _rects_overlap_with_gap(a: Rect2, b: Rect2, gap: float) -> bool:
	return a.grow(gap).intersects(b)

func _verify_nameplates() -> void:
	_nameplate_checks_start = checks
	_nameplate_failures_start = failures
	var overlay: Node = _scene.get("nameplates")
	check(overlay != null, "nameplate overlay node exists")
	if overlay == null:
		_nameplate_checks = checks - _nameplate_checks_start
		_nameplate_failures = failures - _nameplate_failures_start
		return
	var snapshot_before := _snapshot()
	var bytes_before := _read_bytes(_fixture_path)
	var initial_cam_pos: Vector3 = _scene._camera.global_position
	var initial_cam_basis: Basis = _scene._camera.global_transform.basis
	var initial_viewport_size: Vector2i = root.size
	var initial_content_scale_size: Vector2i = root.content_scale_size
	root.size = Vector2i(1400, 900)
	root.content_scale_size = Vector2i(1400, 900)
	_scene.paused = true
	_scene._refresh()
	await process_frame
	await process_frame

	# --- 3 fixture entries/identities -------------------------------------
	var entries := _nameplate_entries()
	check(entries.size() == 3, "nameplate overlay has 3 entries for 3 fixture identities")
	var innkeeper := "fixture:innkeeper"
	var innkeeper_entry: Dictionary = entries.get(innkeeper, {})
	check(not innkeeper_entry.is_empty(), "innkeeper has a nameplate entry")
	if not innkeeper_entry.is_empty():
		var innkeeper_label: Label = innkeeper_entry.get("label")
		check(is_instance_valid(innkeeper_label), "innkeeper nameplate label is a real Control")
		if is_instance_valid(innkeeper_label):
			var innkeeper_name: String = str(_scene.town.resident(innkeeper).name)
			check(innkeeper_label.text.begins_with(innkeeper_name), "innkeeper label begins with actual resident name")
			check(innkeeper_label.text.contains("持有斧头"), "innkeeper label contains 持有斧头 (real custodian)")
			var actual_axe: Dictionary = {}
			for item in _snapshot().life.get("items", []):
				if item.get("kind") == "axe":
					actual_axe = item
					break
			check(not actual_axe.is_empty(), "authoritative axe item present for condition check")
			var actual_edge: int = int(actual_axe.get("edge", -1))
			var actual_handle: int = int(actual_axe.get("handle", -1))
			check(innkeeper_label.text.contains("刃 %d" % actual_edge), "innkeeper label contains actual 刃 %d" % actual_edge)
			check(innkeeper_label.text.contains("柄 %d" % actual_handle), "innkeeper label contains actual 柄 %d" % actual_handle)
	for id in _scene.town.active_ids():
		if id == innkeeper:
			continue
		var other_entry: Dictionary = entries.get(id, {})
		if other_entry.is_empty():
			continue
		var other_label: Label = other_entry.get("label")
		if is_instance_valid(other_label):
			check(not other_label.text.contains("持有斧头"), "non-custodian %s label does not claim 持有斧头" % id)
	# Legacy 3D cards and fallback facts must not be visible.
	for id in _scene.town.active_ids():
		var card: Label3D = _scene.cards.get(id)
		if card != null:
			check(not card.is_visible_in_tree(), "legacy 3D card hidden for %s" % id)
	var tools: Node = _scene.get("town_tools")
	if tools != null:
		var facts: Label3D = tools.get("facts")
		if facts != null:
			check(not facts.is_visible_in_tree(), "fallback facts label not visible")
	# Mouse filters ignore.
	for id in entries.keys():
		var entry: Dictionary = entries[id]
		var panel: Control = entry.get("panel")
		var label: Label = entry.get("label")
		if is_instance_valid(panel):
			check(panel.mouse_filter == Control.MOUSE_FILTER_IGNORE, "panel %s ignores mouse" % id)
		if is_instance_valid(label):
			check(label.mouse_filter == Control.MOUSE_FILTER_IGNORE, "label %s ignores mouse" % id)

	# --- Overview view -----------------------------------------------------
	await _nameplate_view("overview", Vector3(0, 5, 14), Vector3(0, 1, 4), true)
	# --- Close view --------------------------------------------------------
	await _nameplate_view("close", Vector3(4, 3, 11), Vector3(-1, 1, 6), true)

	# --- Physical window resize 1200x800 (above minimum 1100x720) ---------
	# project.godot uses canvas_items stretch with logical viewport 1400x900;
	# a physical window resize is NOT a logical viewport resize. Assert both.
	root.size = Vector2i(1200, 800)
	for i in 12:
		await process_frame
	check(root.size == Vector2i(1200, 800), "physical window reports requested 1200x800 (got %dx%d)" % [root.size.x, root.size.y])
	var physical_view: Vector2 = _scene.get_viewport().get_visible_rect().size
	check(int(physical_view.x) == 1400 and int(physical_view.y) == 900, "logical viewport stays 1400x900 under content_scale_size after physical resize (got %dx%d)" % [int(physical_view.x), int(physical_view.y)])
	_nameplate_views.append({"view": "physical_window_1200x800", "physical_window": _vec_array(Vector2(root.size)), "logical_viewport": _vec_array(physical_view)})

	# --- Logical viewport stress 1000x700 (test-only content_scale_size) ---
	var resized_dialogue_panel: Control = null
	if is_instance_valid(_scene.dialogue):
		var dp: Node = _scene.dialogue.get_parent()
		while dp != null and not (dp is PanelContainer):
			dp = dp.get_parent()
		if dp is Control:
			resized_dialogue_panel = dp as Control
	var resized_dialogue_original_bottom: float = -1.0
	if resized_dialogue_panel != null and resized_dialogue_panel.is_visible_in_tree():
		resized_dialogue_original_bottom = resized_dialogue_panel.get_global_rect().end.y
	root.content_scale_size = Vector2i(1000, 700)
	_scene._camera.global_position = Vector3(0, 5, 14)
	_scene._camera.look_at(Vector3(0, 1, 4))
	for i in 12:
		await process_frame
	var resized_view: Vector2 = _scene.get_viewport().get_visible_rect().size
	check(int(resized_view.x) == 1000 and int(resized_view.y) == 700, "logical viewport actually 1000x700 under test-only content_scale_size")
	var resized_rects := _visible_panel_rects()
	var resized_hud: Array[Control] = []
	if is_instance_valid(_scene.status):
		var sp: Control = _scene.status.get_parent() as Control
		if sp != null:
			resized_hud.append(sp)
	if resized_dialogue_panel != null:
		resized_hud.append(resized_dialogue_panel)
	for item in resized_rects:
		var r: Rect2 = item.rect
		check(r.position.x >= 0 and r.position.y >= 0 and r.end.x <= resized_view.x and r.end.y <= resized_view.y, "resized panel %s inside actual viewport" % item.id)
		for hud in resized_hud:
			if is_instance_valid(hud) and hud.is_visible_in_tree():
				check(not r.intersects(hud.get_global_rect()), "resized panel %s avoids actual HUD/dialogue" % item.id)
	for i in resized_rects.size():
		for j in range(i + 1, resized_rects.size()):
			check(not _rects_overlap_with_gap(resized_rects[i].rect, resized_rects[j].rect, 0.0), "resized panels %s/%s do not overlap" % [resized_rects[i].id, resized_rects[j].id])
	var resized_status_visible: bool = is_instance_valid(_scene.status) and _scene.status.is_visible_in_tree()
	var resized_dialogue_visible: bool = resized_dialogue_panel != null and resized_dialogue_panel.is_visible_in_tree()
	check(resized_rects.size() > 0, "resized 1000x700: at least one actual nameplate panel visible")
	check(resized_status_visible or resized_dialogue_visible, "resized 1000x700: at least one of status/dialogue panel visible")
	if resized_dialogue_visible and resized_dialogue_original_bottom >= 0.0:
		var resized_dialogue_new_bottom: float = resized_dialogue_panel.get_global_rect().end.y
		check(abs(resized_dialogue_new_bottom - 680.0) < 2.0, "resized 1000x700: dialogue panel new bottom approx 680 (got %.1f)" % resized_dialogue_new_bottom)
		check(abs(resized_dialogue_original_bottom - 880.0) < 2.0, "resized 1000x700: dialogue panel original bottom approx 880 (got %.1f)" % resized_dialogue_original_bottom)
		check(abs(resized_dialogue_new_bottom - resized_dialogue_original_bottom) > 0.5, "resized 1000x700: dialogue panel repositioned from original bottom edge")
	_nameplate_views.append({"view": "logical_1000x700", "viewport": _vec_array(resized_view), "visible": resized_rects.size(), "status_visible": resized_status_visible, "dialogue_visible": resized_dialogue_visible})
	if not _capture_dir.is_empty() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var resized_img := _scene.get_viewport().get_texture().get_image()
		var resized_path := _capture_dir.path_join("merge_nameplates_logical_1000x700.png")
		if resized_img.save_png(resized_path) == OK:
			_nameplate_image_paths.append(resized_path)
	root.content_scale_size = Vector2i(1400, 900)
	for i in 12:
		await process_frame
	check(int(_scene.get_viewport().get_visible_rect().size.x) == 1400 and int(_scene.get_viewport().get_visible_rect().size.y) == 900, "logical viewport restored to 1400x900")

	# --- Face away ---------------------------------------------------------
	_scene._camera.global_position = Vector3(0, 5, -14)
	_scene._camera.look_at(Vector3(0, 1, -24))
	for i in 12:
		await process_frame
	var away_layout := _nameplate_layout()
	var away_visible := _visible_panel_rects()
	check(away_visible.is_empty(), "face-away: no actual panels visible")
	var away_entries := _nameplate_entries()
	for id in away_entries.keys():
		var entry: Dictionary = away_entries[id]
		var panel: Control = entry.get("panel")
		var line: Line2D = entry.get("line")
		if is_instance_valid(panel):
			check(not panel.is_visible_in_tree(), "face-away: actual panel %s hidden" % id)
		if is_instance_valid(line):
			check(not line.is_visible_in_tree(), "face-away: actual line %s hidden" % id)
	var away_hidden_rows := 0
	for id in away_layout.keys():
		var row: Dictionary = away_layout[id]
		if row.get("visible", false) == false:
			away_hidden_rows += 1
			check(str(row.get("reason", "")) == "screen", "face-away row %s reason is screen" % id)
	check(away_hidden_rows == 3, "face-away: 3 rows reported hidden (got %d)" % away_hidden_rows)
	_nameplate_views.append({"view": "face_away", "visible": away_visible.size(), "hidden_rows": away_hidden_rows})

	# --- Occlusion ---------------------------------------------------------
	_scene._camera.global_position = Vector3(0, 5, 14)
	_scene._camera.look_at(Vector3(0, 1, 4))
	for i in 12:
		await process_frame
	var innkeeper_head: Vector3 = _scene.actors[innkeeper].global_position + Vector3(0, 1.85, 0)
	var cam_pos: Vector3 = _scene._camera.global_position
	var midpoint: Vector3 = (cam_pos + innkeeper_head) * 0.5
	var blocker := StaticBody3D.new()
	var blocker_shape := CollisionShape3D.new()
	var blocker_box := BoxShape3D.new()
	blocker_box.size = Vector3(0.4, 0.4, 0.4)
	blocker_shape.shape = blocker_box
	blocker.add_child(blocker_shape)
	blocker.position = midpoint
	_scene.add_child(blocker)
	for i in 6:
		await physics_frame
	for i in 6:
		await process_frame
	var occluded_layout := _nameplate_layout()
	var innkeeper_row: Dictionary = occluded_layout.get(innkeeper, {})
	check(innkeeper_row.get("visible", true) == false, "occluded innkeeper panel hidden")
	check(str(innkeeper_row.get("reason", "")) == "occluded", "occluded innkeeper reason is occluded")
	var occluded_entries := _nameplate_entries()
	var occluded_entry: Dictionary = occluded_entries.get(innkeeper, {})
	var occluded_panel: Control = occluded_entry.get("panel")
	var occluded_line: Line2D = occluded_entry.get("line")
	if is_instance_valid(occluded_panel):
		check(not occluded_panel.is_visible_in_tree(), "occluded innkeeper actual panel hidden")
	if is_instance_valid(occluded_line):
		check(not occluded_line.is_visible_in_tree(), "occluded innkeeper actual line hidden")
	blocker.queue_free()
	for i in 6:
		await physics_frame
	for i in 12:
		await process_frame
	var restored_layout := _nameplate_layout()
	var restored_row: Dictionary = restored_layout.get(innkeeper, {})
	check(restored_row.get("visible", false) == true, "innkeeper panel restored after blocker freed")
	var restored_entries := _nameplate_entries()
	var restored_entry: Dictionary = restored_entries.get(innkeeper, {})
	var restored_panel: Control = restored_entry.get("panel")
	if is_instance_valid(restored_panel):
		check(restored_panel.is_visible_in_tree(), "innkeeper actual panel visible after blocker freed")

	# --- Temporary actor mapping removal (missing_actor bug) ---------------
	var saved_actor: Node3D = _scene.actors.get(innkeeper)
	_scene.actors.erase(innkeeper)
	for i in 12:
		await process_frame
	var missing_layout := _nameplate_layout()
	var missing_row: Dictionary = missing_layout.get(innkeeper, {})
	check(missing_row.get("visible", true) == false, "missing actor: no stale visible panel")
	check(str(missing_row.get("reason", "")) == "missing_actor", "missing actor reason is missing_actor")
	var missing_entries := _nameplate_entries()
	var missing_entry: Dictionary = missing_entries.get(innkeeper, {})
	var missing_panel: Control = missing_entry.get("panel")
	var missing_line: Line2D = missing_entry.get("line")
	if is_instance_valid(missing_panel):
		check(not missing_panel.is_visible_in_tree(), "missing actor: actual innkeeper panel hidden")
	if is_instance_valid(missing_line):
		check(not missing_line.is_visible_in_tree(), "missing actor: actual innkeeper line hidden")
	var missing_visible := _visible_panel_rects()
	for item in missing_visible:
		check(item.id != innkeeper, "missing actor has no visible panel")
	_scene.actors[innkeeper] = saved_actor
	for i in 12:
		await process_frame
	var returned_layout := _nameplate_layout()
	var returned_row: Dictionary = returned_layout.get(innkeeper, {})
	check(returned_row.get("visible", false) == true, "identity/visibility returns after mapping restored")
	var returned_entries := _nameplate_entries()
	var returned_entry: Dictionary = returned_entries.get(innkeeper, {})
	var returned_panel: Control = returned_entry.get("panel")
	if is_instance_valid(returned_panel):
		check(returned_panel.is_visible_in_tree(), "missing actor: actual innkeeper panel visible after restore")

	# --- Restore camera/viewport/content scale before final comparison ----
	_scene._camera.global_position = initial_cam_pos
	_scene._camera.global_transform.basis = initial_cam_basis
	root.size = initial_viewport_size
	root.content_scale_size = initial_content_scale_size
	for i in 12:
		await process_frame

	# --- End-state comparison ---------------------------------------------
	check(_snapshot() == snapshot_before, "nameplate tests did not mutate town world")
	check(_read_bytes(_fixture_path) == bytes_before, "nameplate tests did not change saved fixture bytes")
	check(_scene.model_turns == null, "no model attached during nameplate tests")
	check(_scene.paused, "scene still paused after nameplate tests")
	_nameplate_checks = checks - _nameplate_checks_start
	_nameplate_failures = failures - _nameplate_failures_start

func _nameplate_view(view_name: String, cam_pos: Vector3, look_at: Vector3, require_all: bool) -> void:
	_scene._camera.global_position = cam_pos
	_scene._camera.look_at(look_at)
	for i in 24:
		await process_frame
	var view: Vector2 = _scene.get_viewport().get_visible_rect().size
	var layout: Dictionary = _nameplate_layout()
	var entries: Dictionary = _nameplate_entries()
	var visible_rects: Array = _visible_panel_rects()
	if require_all:
		check(visible_rects.size() == 3, "%s: all 3 actual panels visible" % view_name)
	var measured: Array = []
	for item in visible_rects:
		var r: Rect2 = item.rect
		check(r.size.x > 0 and r.size.y > 0, "%s: panel %s has positive size" % [view_name, item.id])
		check(r.position.x >= 0 and r.position.y >= 0 and r.end.x <= view.x and r.end.y <= view.y, "%s: panel %s inside viewport safe edges" % [view_name, item.id])
		var row: Dictionary = layout.get(item.id, {})
		var reported: Rect2 = row.get("rect", Rect2())
		check(abs(reported.position.x - r.position.x) < 1.0 and abs(reported.position.y - r.position.y) < 1.0, "%s: panel %s actual rect matches reported rect" % [view_name, item.id])
		check(abs(reported.size.x - r.size.x) < 1.0 and abs(reported.size.y - r.size.y) < 1.0, "%s: panel %s actual size matches reported size" % [view_name, item.id])
		var entry: Dictionary = entries.get(item.id, {})
		var label: Label = entry.get("label")
		var text: String = ""
		if is_instance_valid(label):
			text = label.text
		var anchor_vec: Vector3 = row.get("anchor", Vector3.ZERO)
		var projected_anchor: Vector2 = _scene._camera.unproject_position(anchor_vec)
		measured.append({"id": item.id, "rect": _rect_array(r), "text": text, "anchor": _vec_array(projected_anchor)})
	for i in visible_rects.size():
		for j in range(i + 1, visible_rects.size()):
			check(not _rects_overlap_with_gap(visible_rects[i].rect, visible_rects[j].rect, 2.0), "%s: panels %s/%s non-overlap with gap" % [view_name, visible_rects[i].id, visible_rects[j].id])
	# Avoid actual visible status/dialogue Control rects.
	var hud_rects: Array[Control] = []
	if is_instance_valid(_scene.status):
		var sp := _scene.status.get_parent() as Control
		if sp != null:
			hud_rects.append(sp)
	if is_instance_valid(_scene.dialogue):
		var dp: Node = _scene.dialogue.get_parent()
		while dp != null and not (dp is PanelContainer):
			dp = dp.get_parent()
		if dp is Control:
			hud_rects.append(dp as Control)
	for item in visible_rects:
		for hud in hud_rects:
			if is_instance_valid(hud) and hud.is_visible_in_tree():
				check(not item.rect.intersects(hud.get_global_rect()), "%s: panel %s avoids actual HUD/dialogue" % [view_name, item.id])
	# Leader line ends at camera projection of the correct actor head; assert actual Line2D points.
	for id in layout.keys():
		var row: Dictionary = layout[id]
		if row.get("visible", false) != true:
			continue
		var anchor: Vector3 = row.get("anchor", Vector3.ZERO)
		var projected: Vector2 = _scene._camera.unproject_position(anchor)
		var expected: Vector2 = _scene._camera.unproject_position(_scene.actors[id].global_position + Vector3(0, 1.85, 0))
		check(projected.distance_to(expected) < 2.0, "%s: leader line anchor matches actor %s head projection" % [view_name, id])
		var entry: Dictionary = entries.get(id, {})
		var line: Line2D = entry.get("line")
		if is_instance_valid(line):
			check(line.is_visible_in_tree(), "%s: leader line %s actually visible" % [view_name, id])
			check(line.points.size() == 2, "%s: leader line %s has exactly 2 points" % [view_name, id])
			if line.points.size() == 2:
				var last_pt: Vector2 = line.to_global(line.points[1])
				check(last_pt.distance_to(expected) < 2.0, "%s: leader line %s last point within 2px of actual head projection" % [view_name, id])
				var first_pt: Vector2 = line.to_global(line.points[0])
				var card_rect: Rect2 = entry.get("panel").get_global_rect()
				var on_boundary: bool = card_rect.grow(2.0).has_point(first_pt)
				check(on_boundary, "%s: leader line %s first point within actual card boundary" % [view_name, id])
	_nameplate_views.append({"view": view_name, "viewport": _vec_array(view), "visible": visible_rects.size(), "measured": measured})

func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_errors.append("could not open output for writing: %s" % path)
		return
	file.store_string(JSON.stringify(payload, "  "))
	file.close()

func _finish() -> void:
	var evidence := {
		"suite": "town_merge_acceptance",
		"checks": checks,
		"failures": failures,
		"model_calls": 0,
		"model_turns_attached": _scene != null and _scene.model_turns != null,
		"dressing_ids": _dressing_ids,
		"world_save_byte_equal": _fixture_bytes_after == _fixture_bytes_before,
		"image_paths": _image_paths,
		"image_sizes": _image_sizes,
		"nameplate_image_paths": _nameplate_image_paths,
		"nameplate_checks": _nameplate_checks,
		"nameplate_failures": _nameplate_failures,
		"nameplate_views": _nameplate_views,
		"errors": _errors,
	}
	if not _capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(_capture_dir)
		_write_json(_capture_dir.path_join("evidence.json"), evidence)
	if not _merge_output.is_empty():
		_write_json(_merge_output, evidence)
	print(JSON.stringify(evidence))
	if _scene != null:
		_scene.town.release_writer(_fixture_path)
		_scene.queue_free()
		_scene = null
	await process_frame
	await process_frame
	quit(0 if failures == 0 and _errors.is_empty() else 1)
