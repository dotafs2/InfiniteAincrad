extends SceneTree
## Offline world-level acceptance for the public-place capability.
##
## Everything here uses a disposable fixture world and the real world module; there is no
## scene, no model call, no gateway and no maintained world. The scene-side perception
## (physics line of sight, real bodies, real journeys) is validated separately in
## town_places_scene_acceptance.gd.
##
## Covered: notice/direct-sight learning with attribution and idempotency, distance and
## occlusion exclusion, unknown-id rejection, illegal destination rejection without mutation,
## a known-only option list with no other resident's data, trip persistence across a byte
## cold reopen with exactly one arrival receipt, honest blocked-trip closure with no arrival,
## the existing rest rule at a place, and tampered-state rejection.
const Town := preload("res://core/town_places.gd")
const Catalog := preload("res://spatial/town_places.gd")

const A := "fixture:innkeeper"
const B := "fixture:smith"
const FAR := "fixture:far"

var checks := 0
var failures: Array = []
var _work := ""
var _town: Town = null
var _path := ""

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func _work_dir() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--places-work="):
			return arg.trim_prefix("--places-work=").strip_edges()
	var game_dir := ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/")
	var repo_root: String = game_dir.substr(0, game_dir.length() - 5) if game_dir.ends_with("/game") else game_dir
	return repo_root.path_join("tmp").path_join("town-places-20260912").path_join("rules")

func fixture() -> Dictionary:
	var roster := [
		[A, "Innkeeper (offline fixture)", "innkeeper", [2.5, 0.22, 7.5]],
		[B, "Smith (offline fixture)", "smith", [0.5, 0.22, 9.5]],
		[FAR, "Far resident (offline fixture)", "herder", [0.0, 0.22, -30.0]],
	]
	var world := {"schema_version": 2, "world_id": "fixture:town-places-rules", "fixture": true,
		"elapsed_seconds": 0, "residents": [],
		"survival": {"accounts": [], "tick_remainder_seconds": 0},
		"foraging": {"stock": 6, "capacity": 6, "initial_stock": 6, "produced_total": 0,
			"harvested_total": 0, "growth_remainder_seconds": 0},
		"life": {"seq": 0, "events": [], "contracts": [], "applied": [], "relations": [],
			"inboxes": [], "items": [], "skills": [], "accounts": []},
		"godot": {"schema_version": 1, "mode": "migration_validation", "source_life_seq": 0,
			"source_sha256": "fixture-town-places-rules", "positions": {}, "homes": {},
			"pending": {}, "commands": {}, "new_events": [], "elapsed_seconds": 0,
			"observations": {}, "berry_position": [4, 0.22, 1]}}
	for entry in roster:
		var stable_id: String = entry[0]
		world.residents.append({"stable_id": stable_id, "name": entry[1], "role": entry[2],
			"story": "explicit offline fixture identity", "personality": "explicit offline fixture",
			"coins_col": 5, "needs": {"hunger": 60.0}, "runtime": {"fixture_only": true}})
		world.survival.accounts.append({"resident_id": stable_id, "food": 1, "energy": 60.0})
		world.life.accounts.append({"resident_id": stable_id, "wood": 1, "iron": 0, "kindling": 0, "reserved_col": 0})
		world.godot.positions[stable_id] = entry[3].duplicate()
		world.godot.homes[stable_id] = entry[3].duplicate()
		world.godot.observations[stable_id] = []
	return world

func write_world(relative: String, world: Dictionary) -> String:
	var path := _work.path_join(relative)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(JSON.stringify(world, "", true, true))
	file.close()
	return path

func load_town(path: String) -> Town:
	var town := Town.new()
	var loaded := town.load_from(path)
	check(loaded.ok, "fixture loads: " + path.get_file() + " " + str(loaded.get("code", "")))
	return town if loaded.ok else null

func events_of(event_type: String) -> Array:
	var result: Array = []
	for event in _town._state.life.events:
		if event is Dictionary and event.get("type", "") == event_type:
			result.append(event)
	return result

func travel_option(id: String, place_id: String) -> Dictionary:
	for option in _town.trade_options(id):
		if option.get("id") == "place:travel:" + place_id:
			return option
	return {}

func rest_option(id: String, place_id: String) -> Dictionary:
	for option in _town.trade_options(id):
		if option.get("id") == "place:rest:" + place_id:
			return option
	return {}

func run() -> void:
	_work = _work_dir()
	DirAccess.make_dir_recursive_absolute(_work)
	_path = write_world("rules.json", fixture())
	check(not _path.is_empty(), "fixture path is writable: " + _path)
	if _path.is_empty():
		_finish()
		return
	_town = load_town(_path)
	if _town == null:
		_finish()
		return
	check(_town.active_ids().size() == 3, "three explicit offline fixture identities")

	# 1. No knowledge, no place options: nothing is injected into a brain.
	check(_town.known_place_ids(A).is_empty(), "a resident starts with no place knowledge")
	check(travel_option(A, "planted_commons").is_empty(), "no travel option before any perception")
	# 1b. Authored capacity: exactly ten distinct points per place, one owner per index, and no
	# modulo alias for a resident beyond the authored set.
	var slots_ok := true
	var slot_points: Array = []
	for place_id in Catalog.place_ids():
		check(Catalog.offset_count(str(place_id)) == Catalog.PLACE_CAPACITY,
			"authored capacity is ten points for " + str(place_id))
		for slot in Catalog.offset_count(str(place_id)):
			var point := Catalog.slot_point(str(place_id), slot)
			for other in slot_points:
				if Vector2(point.x - other.x, point.z - other.z).length() < 1.19:
					slots_ok = false
			slot_points.append(point)
		check(not Catalog.slot_point(str(place_id), Catalog.PLACE_CAPACITY).is_finite(),
			"a resident beyond the authored set gets no aliased point for " + str(place_id))
	check(slots_ok, "all forty authored points are distinct within their place")

	# 2. Distance exclusion: a resident 20+ m away cannot read the notice even if a caller
	# claims it can. Occlusion: a near resident with no line of sight learns nothing.
	var far := _town.transaction(_path, func(): return _town.observe_public_places(FAR, true, []))
	check(far.ok and int(far.get("learned", []).size()) == 0, "distance exclusion blocks the notice read: " + str(far.get("code", "")))
	var occluded := _town.transaction(_path, func(): return _town.observe_public_places(A, false, []))
	check(occluded.ok and int(occluded.get("learned", []).size()) == 0, "no line of sight means no notice knowledge")
	check(_town.known_place_ids(FAR).is_empty(), "the far resident learned nothing")

	# 3. Unknown ids are ignored, never learned or trusted from the caller.
	var smuggle: Array = ["planted_commons", "not_a_place", "caravan_rest"]
	var smuggled := _town.transaction(_path, func(): return _town.observe_public_places(A, false, smuggle))
	check(smuggled.ok and int(smuggled.get("learned", []).size()) == 0, "an unknown place id is never learned")
	check(not _town.known_place_ids(A).has("not_a_place"), "unknown place id absent from knowledge")

	# 4. Real notice read: attributed, idempotent, one event per place.
	var seq_before := int(_town._state.life.seq)
	var read := _town.transaction(_path, func(): return _town.observe_public_places(A, true, []))
	check(read.ok and int(read.get("learned", []).size()) == Catalog.place_ids().size(),
		"the notice reader learns every public place on the sign: " + str(read.get("learned", [])))
	check(int(_town._state.life.seq) == seq_before + Catalog.place_ids().size(),
		"one attributed event per learned place, no extra history rewrite")
	var knowledge := _town.place_knowledge(A)
	var sources_ok := true
	for place_id in Catalog.place_ids():
		var record: Dictionary = knowledge.get(place_id, {})
		if record.get("source", "") != "public_notice" or record.get("source_id", "") != str(Catalog.NOTICE["id"]) or str(record.get("event_id", "")).is_empty():
			sources_ok = false
	check(sources_ok, "every learned place keeps its notice source and event id")
	var repeat := _town.transaction(_path, func(): return _town.observe_public_places(A, true, []))
	check(repeat.ok and events_of("place_learned").size() == Catalog.place_ids().size(),
		"a repeated perception adds no second learned event (idempotent)")

	# 5. Direct sight learns only the place actually seen and keeps source attribution.
	var sighted := _town.transaction(_path, func():
		_town.host_move(B, Vector3(0.0, 0.10, 45.0))
		return _town.observe_public_places(B, false, ["planted_commons"]))
	check(sighted.ok and sighted.get("learned", []) == ["planted_commons"], "direct sight learns exactly the seen place")
	check(_town.place_knowledge(B).get("planted_commons", {}).get("source", "") == "direct_sight",
		"direct-sight knowledge keeps its own source")
	check(_town.known_place_ids(B).size() == 1, "direct sight grants nothing else")
	check(travel_option(B, "caravan_rest").is_empty(), "resident B cannot travel to what it has not learned")
	# B later reads the notice: the already-known place keeps its original direct-sight source.
	var b_read := _town.transaction(_path, func():
		_town.host_move(B, Vector3(0.5, 0.22, 9.5))
		return _town.observe_public_places(B, true, []))
	check(b_read.ok and int(b_read.get("learned", []).size()) == Catalog.place_ids().size() - 1,
		"the notice teaches the remaining places and not the one already seen")
	check(_town.place_knowledge(B).get("planted_commons", {}).get("source", "") == "direct_sight",
		"a repeated source never overwrites the original attribution")
	check(not travel_option(B, "caravan_rest").is_empty(), "after reading the notice the same resident does get the option")

	# 6. Options now appear only for the learner's own knowledge, with no other resident's data.
	var option := travel_option(A, "caravan_rest")
	check(not option.is_empty(), "a known place becomes a travel option")
	check(str(option.get("label", "")).contains("商队休息区") and str(option.get("label", "")).contains("步行"),
		"the option label states the public place and that it is a walk")
	var view := _town.resident_view(A)
	check(view.get("known_places", []).size() == Catalog.place_ids().size(), "the resident view lists its own known places")
	var has_source_attribution := false
	for entry in view.get("known_places", []):
		if str(entry.get("place_id", "")) == "planted_commons" and not str(entry.get("learned_event_id", "")).is_empty():
			has_source_attribution = true
	check(has_source_attribution, "the view carries each place's own learned event id")
	check(not JSON.stringify(view.get("known_places", [])).contains("fixture:smith"),
		"the known-place list carries no other resident's data")
	# 7. Illegal/unknown destinations are rejected without any mutation.
	var before := JSON.stringify(_town._state)
	var illegal := _town.transaction(_path, func(): return _town.submit_trade(FAR, "place:travel:caravan_rest", "fixture-places:illegal:1", "opengameagent_fixture"))
	check(not illegal.ok and illegal.get("code") == "option_unavailable", "an unknown destination is rejected: " + str(illegal.get("code", "")))
	var bogus := _town.transaction(_path, func(): return _town.submit_trade(A, "place:travel:not_a_place", "fixture-places:illegal:2", "opengameagent_fixture"))
	check(not bogus.ok, "a place outside the catalog is rejected")
	check(JSON.stringify(_town._state) == before, "a rejected destination mutates nothing")

	# 8. A real trip: pending, persisted, exactly one arrival receipt, no duplicate on repeat.
	var target := _town.place_point("planted_commons", A)
	var started := _town.transaction(_path, func(): return _town.submit_trade(A, "place:travel:planted_commons", "fixture-places:travel:1", "opengameagent_fixture"))
	check(started.ok and started.get("pending", false), "the trip starts and is pending: " + str(started.get("code", "")))
	check(_town.pending_job(A).get("place_id", "") == "planted_commons", "the pending job keeps its place")
	# The cold copy is taken from the bytes the world actually saved, not from memory.
	var mid := _work.path_join("mid-walk.json")
	DirAccess.copy_absolute(_path, mid)
	var cold := load_town(mid)
	check(cold != null and cold.pending_job(A).get("place_id", "") == "planted_commons", "a cold copy resumes the same trip")
	check(cold != null and events_of("place_visited").is_empty(), "no arrival receipt before the body arrives")
	_mid_check(cold)
	_town.host_move(A, target)
	var advanced := _town.transaction(_path, func(): return _town.advance(0.5))
	check(advanced.ok and events_of("place_visited").size() == 1, "exactly one arrival receipt after real arrival")
	var arrival: Dictionary = events_of("place_visited")[0]
	check(str(arrival.get("place_id", "")) == "planted_commons" and arrival.get("target_position", []) == [target.x, target.y, target.z],
		"the arrival keeps the place and the exact target")
	check(_town.pending_job(A).is_empty(), "the trip is closed after arrival")
	_town.transaction(_path, func(): return _town.advance(0.5))
	check(events_of("place_visited").size() == 1, "repeating the step adds no second receipt")

	# 9. A blocked trip closes honestly: no arrival, no resource, resident keeps its identity.
	var blocked_target := _town.place_point("caravan_rest", B)
	var blocked_start := _town.transaction(_path, func(): return _town.submit_trade(B, "place:travel:caravan_rest", "fixture-places:travel:blocked", "opengameagent_fixture"))
	check(blocked_start.ok, "the second resident starts a trip")
	for step in 2:
		_town.transaction(_path, func():
			_town.observe_place_travel(B, _town.position_of(B), 30.0)
			return {"ok": true})
	check(not _town.place_travel_blocked(B).is_empty(), "the world reports the trip as making no progress")
	var closed := _town.transaction(_path, func(): return _town.advance(0.5))
	check(closed.ok and events_of("travel_blocked").size() == 1, "the blocked trip closes with one honest failure event")
	check(events_of("place_visited").size() == 1, "a blocked trip adds no arrival receipt")
	var blocked_command: Dictionary = _town._state.godot.get("places", {}).get("commands", {}).get("fixture-places:travel:blocked", {})
	check(blocked_command.get("status", "") == "rejected" and str(blocked_command.get("result", {}).get("code", "")) == "travel_blocked",
		"a blocked trip is closed as an honest rejection, never a successful arrival: " + str(blocked_command.get("result", {})))
	check(_town.pending_job(B).is_empty() and _town.place_travel_blocked(B).is_empty(), "the blocked trip leaves no dangling pending job")
	check(_town.position_of(B).distance_to(blocked_target) > 1.0, "the resident never gained the target position")

	# 10. Rest at a place uses the existing rest rule, only at the allowed point.
	_town.transaction(_path, func():
		_town.host_move(B, _town.place_point("planted_commons", B))
		_town.account(B).energy = 40.0
		return {"ok": true})
	var rest := rest_option(B, "planted_commons")
	check(not rest.is_empty(), "a known place offers rest under the existing rule")
	var elsewhere := _town.transaction(_path, func():
		_town.host_move(B, Vector3(2.5, 0.22, 7.5))
		return _town.submit_trade(B, "place:rest:planted_commons", "fixture-places:rest:far", "opengameagent_fixture"))
	check(not elsewhere.ok, "resting at a place you are not standing at is rejected: " + str(elsewhere.get("code", "")))
	var rest_start := _town.transaction(_path, func():
		_town.host_move(B, _town.place_point("planted_commons", B))
		return _town.submit_trade(B, "place:rest:planted_commons", "fixture-places:rest:1", "opengameagent_fixture"))
	check(rest_start.ok and rest_start.get("pending", false), "rest at the place starts: " + str(rest_start.get("code", "")))
	var rest_point := _town.place_point("planted_commons", B)
	var pending: Dictionary = _town._state.godot.pending.get(B, {})
	check(pending.get("place_id", "") == "planted_commons" and pending.get("target_position", []) == [rest_point.x, rest_point.y, rest_point.z],
		"the pending rest keeps the place and its exact point")
	var energy_before := float(_town.account(B).energy)
	for step in 120:
		_town.transaction(_path, func(): return _town.advance(0.5))
	check(absf(float(_town.account(B).energy) - minf(100.0, energy_before + 35.0)) < 0.01,
		"rest at the place grants the existing +35 energy rule")
	check(events_of("rest").size() == 1, "exactly one rest receipt")
	_town.transaction(_path, func(): return _town.advance(0.5))
	check(events_of("rest").size() == 1, "no duplicate rest receipt on a further step")

	# 11. Tampered state is refused: a forged learned event and a forged job target.
	var forged := fixture()
	forged.godot.places = {"schema_version": 1,
		"commands": {"fixture-places:forged:1": {"payload": {"actor_id": A, "action": "place_option",
			"option_id": "place:travel:planted_commons", "provenance": "opengameagent_fixture"}, "status": "pending"}},
		"jobs": {A: {"action": "travel", "command_id": "fixture-places:forged:1", "place_id": "planted_commons",
			"provenance": "opengameagent_fixture", "elapsed": 0.0, "duration_seconds": 0.0,
			"target_position": [99.0, 0.1, 99.0], "last_position": [0.0, 0.0, 0.0], "no_progress_seconds": 0.0}}}
	var forged_path := write_world("forged.json", forged)
	var refused := Town.new().load_from(forged_path)
	check(not refused.ok, "a forged place job target is refused: " + str(refused.get("code", "")))
	var forged_event := fixture()
	forged_event.godot.places = {"schema_version": 1, "commands": {}, "jobs": {}}
	forged_event.life.events = [{"seq": 1, "event_id": "life_event_1", "type": "place_learned", "actor_id": A,
		"subject_id": A, "recipient_ids": [A], "operation_id": "places:public_notice:%s:planted_commons" % A,
		"source": "public_notice_or_sight", "source_kind": "public_notice", "source_id": str(Catalog.NOTICE["id"]),
		"place_id": "planted_commons", "source_position": [0.0, 0.0, 0.0], "text": "forged"}]
	forged_event.life.seq = 1
	var event_path := write_world("forged-event.json", forged_event)
	var refused_event := Town.new().load_from(event_path)
	check(refused_event.ok, "an honestly derived learned event loads: " + str(refused_event.get("code", "")))
	forged_event.life.events[0].operation_id = "places:public_notice:" + A + ":west_forecourt"
	var mismatch_path := write_world("forged-event-2.json", forged_event)
	var refused_mismatch := Town.new().load_from(mismatch_path)
	check(not refused_mismatch.ok, "a learned event with a mismatched operation id is refused")

	# 12. A world with no place feature at all still loads (old save compatibility).
	var legacy := fixture()
	var legacy_path := write_world("legacy.json", legacy)
	var legacy_town := Town.new()
	var legacy_loaded := legacy_town.load_from(legacy_path)
	check(legacy_loaded.ok, "a world without the place feature still loads")
	var legacy_place_options := 0
	for item in legacy_town.trade_options(A):
		if str(item.get("id", "")).begins_with("place:"):
			legacy_place_options += 1
	check(legacy_place_options == 0, "a legacy world offers no place action")
	_finish()

func _mid_check(cold: Town) -> void:
	## The cold copy is a real second world object; its command must still be pending.
	var command: Dictionary = cold._state.godot.get("places", {}).get("commands", {}).get("fixture-places:travel:1", {})
	check(command.get("status", "") == "pending", "the cold copy keeps the trip command pending")

func _finish() -> void:
	var evidence := {"suite": "town_places_rules", "checks": checks, "failures": failures,
		"failure_count": failures.size(), "work_dir": _work, "model_calls": 0, "paid_calls": 0,
		"places": Catalog.place_ids(), "notice_id": str(Catalog.NOTICE["id"])}
	var out := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	if not out.is_empty():
		DirAccess.make_dir_recursive_absolute(out.get_base_dir())
		var file := FileAccess.open(out, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(evidence, "", true, true))
			file.close()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func _initialize() -> void:
	run.call_deferred()
