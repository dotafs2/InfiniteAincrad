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
	_fixture_bytes_after = _read_bytes(_fixture_path)
	check(_fixture_bytes_after == _fixture_bytes_before, "saved fixture bytes preserved end-to-end")

	if not _capture_dir.is_empty():
		await _capture()

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
