extends "res://tests/town_trade_acceptance.gd"
## Real legacy load, English presentation and unchanged canonical evidence.

func _has_han(value: Variant) -> bool:
	var pattern := RegEx.new()
	pattern.compile("[\\x{3400}-\\x{9fff}]")
	return pattern.search(JSON.stringify(value)) != null

func run() -> void:
	var path := "user://town-english-%d.json" % Time.get_ticks_usec()
	var legacy := trade_fixture()
	legacy.residents[0].personality = "谨慎、独立"
	_write_fixture(path, legacy)
	var bytes_before := FileAccess.get_file_as_bytes(path)
	var town := _load_trade(path)
	var before: Dictionary = town.snapshot()
	var id := "fictional:ember"
	check(town.resident_name(id) == "Eileen", "known old name has an English presentation alias")
	check(town.resident(id).name == "艾琳", "canonical identity retains its original name")
	check(town.resident_name("missing") == "missing", "unknown identity retains its identifier fallback")
	check(town.resident_background(id, "personality") == "Cautious and independent", "known legacy personality is English")
	check(town.resident_view(id).identity.name == "Eileen", "personal model identity uses English")
	check(not _has_han(town.trade_options(id)), "actual available action labels are English")
	check(not _has_han(town.resident_view(id).known_rules), "actual personal world rules are English")
	var original := {"id": "历史-id", "name": "阿岚", "history": [{"text": "我说过一句从未收录的话。"}],
		"nested": {"name": "白枝"}, "seq": 450, "cost": null}
	var projected: Dictionary = town.English.project(original)
	check(projected.name == "Ari" and projected.nested.name == "Wren", "nested known names translate")
	check(projected.id == original.id and projected.seq == 450 and projected.cost == null,
		"projection preserves machine identifiers, sequence and unknown cost")
	check(projected.history == original.history, "unknown historical speech stays verbatim")
	check(original.name == "阿岚" and original.nested.name == "白枝", "projection never mutates its input")
	check(town.snapshot() == before, "English UI/model reads never mutate the loaded world")
	check(FileAccess.get_file_as_bytes(path) == bytes_before, "English UI/model reads preserve exact save bytes")
	var genesis := {"origin": {"kind": "new_world_seed", "genesis": true, "migrated_from": null},
		"godot": {"new_world_seed": true, "source_life_seq": 0}}
	for hash_value in [Town.PREVIEW_LAYOUT_SHA256, Town.LEGACY_PREVIEW_LAYOUT_SHA256]:
		check(town._declared_preview_genesis(genesis, {"preview_genesis": true, "layout_sha256": hash_value}),
			"reviewed layout language revision keeps valid preview provenance")
	check(not town._declared_preview_genesis(genesis, {"preview_genesis": true, "layout_sha256": "unreviewed"}),
		"English revision does not admit an unreviewed layout hash")
	check(town.start_action(id, "eat_ration", "english-eat").ok, "legacy resident can start an ordinary action")
	town.advance(30)
	check(not _has_han(town.snapshot().life.events), "new authored action evidence is English")
	check(town.resident(id).name == "艾琳", "English new events do not rename canonical resident")
	town.release_writer(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print(JSON.stringify({"suite": "town_english", "checks": checks, "failures": failures, "paid_calls": 0}))
	quit(0 if failures == 0 else 1)
