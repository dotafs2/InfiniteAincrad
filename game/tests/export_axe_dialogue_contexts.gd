extends SceneTree
## Offline projection only. Captured views are existing Turns inputs; no proposal is executed.
const Town = preload("res://core/town_runtime.gd")
const Turns = preload("res://agents/town_turns.gd")
const SOURCE := "res://../worlds/restart-20260918-01/checkpoints/seq000000-22fe742384341a2b.world.json"
const OWNER := "shared:carpenter"
const SMITH := "shared:smith"
var out := ""
class CaptureBrain extends Node:
	var view := {}
	func propose(input: Dictionary, _seq: int) -> Dictionary:
		view = input.duplicate(true)
		return {"ok":false,"code":"fixture_capture_stops_before_decision"}
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out=arg.trim_prefix("--out=")
	if out.is_empty() or FileAccess.file_exists(out): quit(2); return
	run.call_deferred()
func run() -> void:
	var tmp := "user://axe-context-%d-%d.json" % [OS.get_process_id(),Time.get_ticks_usec()]
	var source_hash := FileAccess.get_sha256(SOURCE)
	if source_hash.is_empty(): quit(1); return
	var state: Variant=JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	if not state is Dictionary: quit(1); return
	state.fixture=true; state.fixture_note="Disposable dialogue-context export."
	state.godot.positions[OWNER]=[0,0,0]; state.godot.positions[SMITH]=[0,0,0]
	for p in state.residents:
		if p.get("stable_id") in [OWNER,SMITH]: p.coins_col=10
	for a in state.life.accounts:
		if a.get("resident_id")==SMITH: a.iron=1
	for item in state.life.items:
		if item.get("id") == "seed:axe": item.edge=20; item.handle=100; item.owner_id=OWNER; item.custodian_id=OWNER
	var f:=FileAccess.open(tmp,FileAccess.WRITE)
	if f==null: quit(1); return
	f.store_string(JSON.stringify(state)); f.close()
	var town:=Town.new(); if not town.load_from(tmp).ok: _cleanup(town,tmp); quit(1); return
	# Existing public-skill event exposes the legal repair offer without a model call.
	var notice := town.transaction(tmp,func(): return town.submit_trade(SMITH,"share-skill:"+OWNER+":metal_repair","fixture:notice","opengameagent_fixture"))
	if not notice.get("ok",false): _cleanup(town,tmp); quit(1); return
	var cases:Array=[]
	cases.append(await capture(town,tmp,"owner_repair_offer"))
	var offer:=""
	for option in town.trade_options(OWNER):
		if option.get("action")=="offer_repair" and option.get("_part")=="edge" and option.get("_worker_id")==SMITH and option.get("_price")==2: offer=str(option.id)
	if offer.is_empty() or not _has_action(cases[0],offer): _cleanup(town,tmp); quit(1); return
	var proposed := town.transaction(tmp,func(): return town.submit_trade(OWNER,offer,"fixture:offer","opengameagent_fixture"))
	if not proposed.get("ok",false) or proposed.get("code","")!="contract_proposed": _cleanup(town,tmp); quit(1); return
	cases.append(await capture(town,tmp,"smith_accept_or_wait"))
	if not _has_prefix(cases[1],"contract:accept:"): _cleanup(town,tmp); quit(1); return
	town._trade_account(SMITH).iron=0
	cases.append(await capture(town,tmp,"smith_missing_iron"))
	if _has_prefix(cases[2],"contract:accept:") or not _has_prefix(cases[2],"contract:reject:"): _cleanup(town,tmp); quit(1); return
	var payload={"fixture_only":true,"source_sha256":source_hash,"source_unchanged":FileAccess.get_sha256(SOURCE)==source_hash,"cases":cases}
	if not payload.source_unchanged: _cleanup(town,tmp); quit(1); return
	var file:=FileAccess.open(out,FileAccess.WRITE)
	if file==null:
		_cleanup(town,tmp)
		quit(2)
		return
	file.store_string(JSON.stringify(payload,"  ",true,true)); file.close()
	_cleanup(town,tmp)
	print(JSON.stringify({"suite":"export_axe_dialogue_contexts","cases":cases.size(),"paid_calls":0,"source_unchanged":payload.source_unchanged,"out":out}))
	quit(0)
func capture(town:RefCounted,path:String,case_id:String) -> Dictionary:
	var turns:=Turns.new(); root.add_child(turns); turns.town=town; turns.save_path=path
	var brain:=CaptureBrain.new(); turns.add_child(brain); turns.brains[case_id]=brain
	# actor IDs are passed separately; use an actual key so Turns builds native aliases.
	turns.brains.erase(case_id)
	var actor:=OWNER if case_id=="owner_repair_offer" else SMITH
	turns.brains[actor]=brain
	var captured_step: Dictionary = await turns.step(actor)
	var record:Dictionary=turns._record(actor)
	var options:Array=[]
	for alias in record.get("offered_actions",{}):
		options.append({"alias":alias,"description":_description(town,actor,str(record.offered_actions[alias])),"action_id":record.offered_actions[alias]})
	var view:Dictionary=brain.view
	if view.is_empty() or captured_step.get("code","") != "provider_error": turns.free(); return {"case_id":case_id,"resident_id":actor,"context":{},"options":[],"observation":{}}
	var rules: Dictionary = view.get("known_rules", {}).duplicate(true)
	# This is a dialogue-envelope lab, so omit the resident decision-format contract
	# that asks for the older action/reason response shape.
	rules.erase("decision_format")
	var observation={"identity":view.get("identity",{}),"needs":view.get("needs",{}),"inventory":view.get("inventory",{}),"life_account":view.get("life_account",{}),"wallet":view.get("wallet",{}),"contracts":view.get("contracts",[]),"skills":view.get("skills",[]),"items":view.get("items",[]),"unavailable_actions":view.get("unavailable_actions",[]),"memory":view.get("memory",{}),"experiences":view.get("experiences",[]),"known_rules":rules}
	turns.free()
	# CaptureBrain intentionally returns before a decision. Remove that disposable
	# provider-error record so the next fixture case receives its own fresh view.
	town._state.godot.resident_turns.erase(actor)
	return {"case_id":case_id,"resident_id":actor,"context":{"target_ids":[OWNER,SMITH],"claim_ids":[],"action_ids":view.get("available_actions",[])},"options":options,"observation":observation}
func _description(town:RefCounted,id:String,action:String)->String:
	for option in town.trade_options(id): if option.get("id")==action: return str(option.get("label",""))
	return ""
func _has_action(case_data:Dictionary,action:String)->bool:
	for option in case_data.get("options",[]): if option.get("action_id","")==action: return true
	return false
func _has_prefix(case_data:Dictionary,prefix:String)->bool:
	for option in case_data.get("options",[]): if str(option.get("action_id","")).begins_with(prefix): return true
	return false
func _cleanup(town:Variant,path:String)->void:
	if town!=null: town.release_writer(path)
	if not path.is_empty(): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
