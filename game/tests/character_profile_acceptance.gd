extends "res://tests/town_turns_acceptance.gd"
## Offline: actual turn composition, ownership boundary, save/load, latent extension preservation.

const Profile = preload("res://core/character_profile.gd")
const BrainBudget = preload("res://agents/resident_brain.gd")

func run() -> void:
	var codec = preload("res://core/TownJsonCodec.cs").new()
	var catalog: Dictionary = codec.Decode(FileAccess.get_file_as_string("res://data/character_dossiers.json"))
	check(catalog.profiles.size() == 10, "all ten resident dossiers exist")
	for id in catalog.profiles:
		check(Profile.validate(catalog.profiles[id], id), "complete profile validates: " + id)
	var profile: Dictionary = catalog.profiles["shared:well-keeper"].duplicate(true)
	profile.resident_id = "fixture:a"
	profile.extensions["future_module"] = {"precise": 0.12345678901234567, "unknown": null,
		"large_unused_detail": "DORMANT_DETAIL_SENTINEL".repeat(2000)}
	profile.sections.author_notes["secret"] = "AUTHOR_ONLY_SENTINEL"
	profile.sections.private_self["secret"] = "UNSELECTED_SELF_SENTINEL"
	check(Profile.validate(profile, "fixture:a"), "large latent extension accepted without truncation")
	check(not Profile.validate(profile, "fixture:b"), "profile cannot be attached to another identity")
	for version in [true, 1.5, 2, "1"]:
		var invalid: Dictionary = profile.duplicate(true)
		invalid.schema_version = version
		check(not Profile.validate(invalid, "fixture:a"), "invalid profile schema fails closed: " + str(version))
	var malformed: Dictionary = profile.duplicate(true)
	malformed.facets.social = []
	check(not Profile.validate(malformed, "fixture:a"), "malformed decision-facing facet rejected")
	malformed = profile.duplicate(true)
	malformed.core.flaw = "x".repeat(181)
	check(not Profile.validate(malformed, "fixture:a"), "oversized core rejected")
	malformed = profile.duplicate(true)
	malformed.sections.erase("relationships")
	check(not Profile.validate(malformed, "fixture:a"), "missing complete section rejected")
	malformed = profile.duplicate(true)
	malformed.extensions.large = "x".repeat(1048576)
	check(not Profile.validate(malformed, "fixture:a"), "file growth guard rejects an oversized profile")
	var person := {"stable_id": "fixture:a", "character_profile": profile}
	var normal := {"needs": {"satiety": 60, "energy": 60}, "nearby_residents": [{"id": "fixture:b"}]}
	var projection: Dictionary = Profile.project(person, normal, [])
	check(projection.facets.has("social"), "actual proximity selects own social manner")
	check(JSON.stringify(projection).to_utf8_buffer().size() <= 2600, "self projection fits fixed byte budget")
	check(not JSON.stringify(projection).contains("SENTINEL"), "detailed private/author/latent sections stay off the wire")
	check(Profile.project({"stable_id": "fixture:legacy"}, normal, []).is_empty(), "legacy resident gets no fabricated profile")
	for example in [[{"satiety": 0, "energy": 0}, "survival"], [{"satiety": 80, "energy": 0}, "rest"]]:
		var view: Dictionary = normal.duplicate(true)
		view.needs = example[0]
		check(Profile.project(person, view, []).facets.has(example[1]), "immediate need selects relevant own facet: " + str(example[1]))
	check(Profile.project(person, normal, [{"id": "repair_edge", "action": "repair_edge"}]).facets.has("work"), "real work option selects own work facet")
	check(Profile.project(person, normal, [{"id": "share-skill:other:wood_repair", "action": "share_skill"}]).facets.has("learning"),
		"sharing knowledge about repair is learning, not an active repair job")
	check(Profile.project(person, normal, [{"id": "approach:someone-named-repair", "action": "approach"}]).facets.has("social"),
		"identity substrings cannot change the selected context")
	var multibyte: Dictionary = profile.duplicate(true)
	for key in Profile.contract.core_fields:
		multibyte.core[key] = "🌱".repeat(180)
	check(Profile.validate(multibyte, "fixture:a"), "valid multi-byte profile remains storable")
	check(JSON.stringify(Profile.project({"stable_id": "fixture:a", "character_profile": multibyte}, normal, [])).to_utf8_buffer().size() <= 2600,
		"multi-byte core cannot bypass projection cap")
	var initial := fixture()
	initial.residents[0].character_profile = profile
	initial.residents[1].character_profile = catalog.profiles["shared:baker"].duplicate(true)
	initial.residents[1].character_profile.resident_id = "fixture:b"
	initial.residents[1].character_profile.core.flaw = "OTHER_PERSON_PRIVATE_SENTINEL"
	var path := "user://character-profile-%d.json" % Time.get_ticks_usec()
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(codec.Encode(initial))
	file.close()
	codec.Release()
	var original_bytes := FileAccess.get_file_as_bytes(path)
	var town := WaitTown.new()
	check(town.load_from(path).ok, "extended world loads through production validator")
	check(FileAccess.get_file_as_bytes(path) == original_bytes, "load never rewrites profile or historical bytes")
	var snapshot: Dictionary = town.snapshot()
	var turns := Turns.new()
	root.add_child(turns)
	turns.town = town
	turns.save_path = path
	var brain := TestBrain.new()
	turns.add_child(brain)
	turns.brains["fixture:a"] = brain
	check((await turns.step("fixture:a")).ok, "real turn accepts an ordinary fixture choice")
	check(brain.received.identity.character.core == profile.core, "real turn receives its own distinct decision core")
	check(not JSON.stringify(brain.received).contains("SENTINEL"), "real turn excludes other residents and all latent/private details")
	var budget := BrainBudget.new()
	var request := {"sessionId": "profile-test", "actorId": "fixture:a", "inputId": "profile-test",
		"type": "personal_observation", "timelineId": initial.world_id, "tick": 0,
		"payload": {"resident_view": brain.received}}
	var bounded: String = budget._bounded_input(request, brain.received)
	check(not bounded.is_empty(), "profile-bearing real turn fits existing brain context guards")
	budget.free()
	check(town.snapshot().life == snapshot.life and town.snapshot().survival == snapshot.survival,
		"characterization grants no resource, skill, friendship or event")
	brain.received.identity.character.core.flaw = "Changed model-side copy"
	check(town.resident("fixture:a").character_profile == profile, "model projection cannot mutate canonical profile")
	town.release_writer(path)
	var restored := WaitTown.new()
	check(restored.load_from(path).ok, "profile world cold-restores")
	check(restored.resident("fixture:a").character_profile == profile, "all detailed and unknown future data survive production save/load exactly")
	restored.release_writer(path)
	turns.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print(JSON.stringify({"suite": "character_profile", "checks": checks, "failures": failures, "paid_calls": 0}))
	quit(0 if failures == 0 else 1)
