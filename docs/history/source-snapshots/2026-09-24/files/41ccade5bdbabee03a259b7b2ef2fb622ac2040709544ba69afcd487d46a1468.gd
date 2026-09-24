extends SceneTree
const Town := preload("res://core/town_runtime.gd")
const Turns := preload("res://agents/town_turns.gd")
const BAKER := "shared:baker"

func _initialize() -> void:
    run.call_deferred()

func run() -> void:
    var save := ""
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--town-save="):
            save = argument.trim_prefix("--town-save=")
    if save.is_empty():
        print(JSON.stringify({"ok": false, "code": "town_save_required"}))
        quit(2)
        return
    var town := Town.new()
    var loaded: Dictionary = town.load_from(save)
    if not loaded.ok:
        print(JSON.stringify({"ok": false, "code": loaded.get("code", "load_failed")}))
        quit(3)
        return
    var turns := Turns.new()
    get_root().add_child(turns)
    turns.configure(town, save)
    var before: Dictionary = turns._record(BAKER).duplicate(true)
    var outcome: Dictionary = await turns.step(BAKER)
    var after: Dictionary = turns._record(BAKER).duplicate(true)
    var safe := {"ok": outcome.get("ok", false), "code": outcome.get("code", ""),
        "status": after.get("status", ""), "error": after.get("error", ""),
        "request_before": before.get("request_id", ""), "request_after": after.get("request_id", ""),
        "epoch": after.get("controller_epoch", -1), "next_due_present": after.has("next_due")}
    town.release_writer(save)
    turns.free()
    print(JSON.stringify(safe))
    quit(0)
