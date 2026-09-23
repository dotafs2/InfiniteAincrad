extends SceneTree

const Bridge = preload("res://core/adventure_live_bridge.gd")

var checks := 0
var failures := 0
var town_save := ""
var adventure_save := ""
var manifest_save := ""

func _initialize() -> void:
	for raw in OS.get_cmdline_user_args():
		if raw.begins_with("--town-save="): town_save = raw.trim_prefix("--town-save=")
		elif raw.begins_with("--adventure-save="): adventure_save = raw.trim_prefix("--adventure-save=")
		elif raw.begins_with("--manifest-save="): manifest_save = raw.trim_prefix("--manifest-save=")
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func run() -> void:
	check(not town_save.is_empty() and not adventure_save.is_empty() and not manifest_save.is_empty(),
		"disposable install paths supplied")
	var town_before := FileAccess.get_file_as_bytes(town_save)
	var adventure_before := FileAccess.get_file_as_bytes(adventure_save)
	var bridge := Bridge.new()
	var installed: Dictionary = bridge.install(town_save, adventure_save)
	check(installed.ok and installed.code == "disposable_adventure_installed", "sidecar installs beside disposable town copy")
	check(bridge.manifest.canonical_mutation_allowed == false, "install manifest forbids canonical mutation")
	check(bridge.manifest.host_capabilities == 36 and bridge.manifest.adventure_capabilities == 10,
		"live bridge combines host and adventure registries")
	check(bridge.registry.all().size() == 46, "combined registry has no collision")
	var id := "shared:baker"
	var entered: Dictionary = bridge.enter_wilderness(id, "live-entry")
	check(entered.ok and bridge.adventure.snapshot().residents[id].zone == "wilderness",
		"disposable live bridge executes a physical-entry receipt")
	var unknown: Dictionary = bridge.attack(id, "missing:encounter", "live-unknown-attack")
	check(not unknown.ok and unknown.code == "encounter_missing", "live bridge closes unknown combat data")
	var fled: Dictionary = bridge.flee(id, "live-flee")
	check(fled.ok and bridge.adventure.snapshot().residents[id].zone == "town",
		"disposable live bridge executes a physical flee receipt")
	check(bridge.save_manifest(manifest_save).ok, "disposable install manifest saves")
	check(FileAccess.get_file_as_bytes(town_save) == town_before, "town copy bytes remain unchanged")
	check(FileAccess.get_file_as_bytes(adventure_save) == adventure_before, "source adventure sidecar bytes remain unchanged")
	var restored := Bridge.new()
	check(restored.load_manifest(manifest_save).ok, "install manifest cold-loads")
	check(restored.adventure.snapshot() == bridge.adventure.snapshot(), "live receipts survive manifest cold restore")
	check(restored.manifest.registered_capabilities.size() == 46, "cold manifest preserves all registered definitions")
	print(JSON.stringify({"suite":"adventure_disposable_live_install","checks":checks,"failures":failures,
		"host_capabilities":bridge.manifest.host_capabilities,"adventure_capabilities":bridge.manifest.adventure_capabilities,
		"combined_capabilities":bridge.registry.all().size(),"canonical_mutation_allowed":false,
		"town_copy_unchanged":FileAccess.get_file_as_bytes(town_save) == town_before,
		"adventure_source_unchanged":FileAccess.get_file_as_bytes(adventure_save) == adventure_before,
		"status":"disposable_live_install_passed_pending_gm_effect_feedback"}))
	quit(0 if failures == 0 else 1)
