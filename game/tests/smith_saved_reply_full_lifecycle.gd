extends SceneTree
## Offline replay of committed raw evidence; later lifecycle commands are scripted host continuation.
const Town = preload("res://core/town_runtime.gd")
const Turns = preload("res://agents/town_turns.gd")
const Reviewed = preload("res://agents/reviewed_dialogue_fixture_adapter.gd")
const Runner = preload("res://demo/axe_day_demo_runner.gd")
const OWNER := "shared:carpenter"
const SMITH := "shared:smith"
const AXE := "seed:axe"
const C := "res://../docs/validation/local-smith-format-live-20260923/contexts.json"
const R := "res://../docs/validation/local-smith-format-live-20260923/response.json"
const P := "res://../docs/validation/local-smith-format-live-20260923/report.json"
var checks := 0
var failures: Array[String] = []
var report := {"suite":"smith_saved_reply_full_lifecycle","fixture_only":true,"paid_calls":0,"saved_model_reply_replayed":true,"new_model_calls":0,"model_replay_acceptance":{},"scripted_continuation":{},"failures":[]}
var raw := ""
var saved_case := {}
var saved_report := {}
var turns

class ReplayBrain extends Node:
	var test
	func propose(view: Dictionary, _seq: int) -> Dictionary:
		var offered: Dictionary = test.turns._record(SMITH).get("offered_actions", {})
		var prepared: Dictionary = Reviewed.prepare(test.raw, view, offered, [OWNER, SMITH], [])
		if not prepared.get("ok",false): return {"ok":false,"code":prepared.get("code", "prepare_failed")}
		var fresh := {}
		for alias in offered:
			for option in test.town.trade_options(SMITH):
				if option.get("id","") == offered[alias]: fresh[alias] = offered[alias]
		if fresh.get("a16", "") != "contract:accept:trade_contract_fixture:offer": return {"ok":false,"code":"saved_alias_not_current"}
		var now_view := view.duplicate(true); now_view.available_actions = fresh.keys()
		var authorized: Dictionary = Reviewed.authorize(prepared, now_view, fresh, true, "Explicit offline replay authorization; Turns remains final gate.", [OWNER,SMITH], [])
		if not authorized.get("ok",false): return {"ok":false,"code":authorized.get("code","authorize_failed")}
		return {"ok":true,"decision":authorized.decision,"command_id":"fixture:saved-smith-replay","provenance":"opengameagent_fixture","provider_id":"local:ollama","model_returned":false}

var town
var path := ""
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var hashes := _hashes()
	var contexts: Variant = _json(C); var response: Variant = _json(R); saved_report = _json(P)
	_check(contexts is Dictionary and response is Dictionary and saved_report is Dictionary, "saved_documents_parse")
	if not failures.is_empty(): return _finish(hashes)
	_check(contexts.fixture_only == true and response.fixture_only == true and saved_report.fixture_only == true and contexts.cases.size()==1 and response.cases.size()==1, "saved_fixture_metadata")
	saved_case = contexts.cases[0]
	_check(saved_case.get("case_id")=="smith_reply" and saved_case.get("resident_id")==SMITH and response.cases[0].get("case_id")=="smith_reply", "single_formal_smith_case")
	raw = response.cases[0].get("raw_content","")
	var saved_accept := false
	for option in saved_case.get("options",[]):
		if option.get("alias","")=="a16" and option.get("action_id","")=="contract:accept:trade_contract_fixture:offer" and option.get("expected_intents",[])==["agree"]: saved_accept=true
	_check(raw is String and raw.sha256_text()==saved_report.get("raw_sha256","") and saved_case.context.action_ids.has("a16") and saved_accept, "raw_sha_and_alias_evidence")
	if not failures.is_empty(): return _finish(hashes)
	path = "user://saved-smith-lifecycle-%d-%d.world.json" % [OS.get_process_id(),Time.get_ticks_usec()]
	var runner := Runner.new(); _check(not FileAccess.file_exists(path) and runner._write_fixture(path), "unique_fixture")
	town=Town.new(); _check(town.load_from(path).get("ok",false), "fixture_load")
	if not failures.is_empty(): return _finish(hashes)
	var notice: Dictionary = town.transaction(path,func(): return town.submit_trade(SMITH,"share-skill:"+OWNER+":metal_repair","fixture:notice","opengameagent_fixture"))
	var offer := _option(OWNER,"offer_repair","edge",SMITH,2)
	var proposed: Dictionary = town.transaction(path,func(): return town.submit_trade(OWNER,offer,"fixture:offer","opengameagent_fixture"))
	_check(notice.get("ok",false) and not offer.is_empty() and proposed.get("code","")=="contract_proposed", "scripted_setup_offer")
	if not failures.is_empty(): return _finish(hashes)
	turns=Turns.new(); root.add_child(turns); turns.town=town; turns.save_path=path
	var brain:=ReplayBrain.new(); brain.test=self; turns.add_child(brain); turns.brains[SMITH]=brain
	var accepted:Dictionary=await turns.step(SMITH)
	var receipt:Dictionary=accepted.get("record",{}).get("result",{})
	var accept_event: bool = town.snapshot().life.events.any(func(event): return event.get("type","")=="axe_contract_accepted" and event.get("actor_id","")==SMITH)
	report.model_replay_acceptance={"raw_sha256":raw.sha256_text(),"saved_alias":"a16","actual_code":receipt.get("code",accepted.get("code","")),"actual_event":"axe_contract_accepted" if accept_event else "","new_model_returned":false}
	_check(accepted.get("ok",false) and receipt.get("code","")=="contract_accepted" and accept_event and town.resident(OWNER).coins_col==8 and town._trade_account(OWNER).reserved_col==2, "model_replay_actual_acceptance")
	if not failures.is_empty(): return _finish(hashes)
	var cid:=str(_contract("accepted").get("id",""))
	var accepted_bytes:=FileAccess.get_file_as_bytes(path); turns.free(); turns=null; town.release_writer(path); town=Town.new(); _check(town.load_from(path).get("ok",false) and FileAccess.get_file_as_bytes(path)==accepted_bytes,"cold_after_replay_acceptance")
	var acceptance_turns:=Turns.new(); root.add_child(acceptance_turns); acceptance_turns.town=town; acceptance_turns.save_path=path
	var acceptance_feedback:Array=acceptance_turns._feedback_history(SMITH,acceptance_turns._record(SMITH)); acceptance_turns.free()
	report["after_acceptance_cold"]={"owner_wallet":town.resident(OWNER).coins_col,"owner_reserved":town._trade_account(OWNER).reserved_col,"smith_iron":town._trade_account(SMITH).iron,"feedback_code":"axe_contract_accepted","feedback_present":acceptance_feedback.any(func(x): return x.get("result",{}).get("code","")=="axe_contract_accepted")}
	var delivery: Dictionary=town.transaction(path,func(): return town.submit_trade(OWNER,"contract:deliver:"+cid,"fixture:deliver","opengameagent_fixture")); _advance(OWNER,1.0)
	report["after_delivery"]={"event":_event("fixture:deliver"),"duration_seconds":1,"custodian_id":town._item(AXE).custodian_id,"host_move":"scripted_host_move_surrogate"}
	var work: Dictionary=town.transaction(path,func(): return town.submit_trade(SMITH,"contract:work:"+cid+":edge","fixture:work","opengameagent_fixture")); _advance(SMITH,60.0)
	report["after_work"]={"event":_event("fixture:work"),"duration_seconds":60,"edge":town._item(AXE).edge,"smith_iron":town._trade_account(SMITH).iron,"host_move":"scripted_host_move_surrogate"}
	var collect: Dictionary=town.transaction(path,func(): return town.submit_trade(OWNER,"contract:collect:"+cid,"fixture:collect","opengameagent_fixture")); _advance(OWNER,1.0)
	var duplicate: Dictionary=town.submit_trade(OWNER,"contract:collect:"+cid,"fixture:collect","opengameagent_fixture")
	report.scripted_continuation={"label":"scripted_host_continuation","delivery":_event("fixture:deliver"),"work":_event("fixture:work"),"collection":_event("fixture:collect"),"duplicate_collection":duplicate.get("duplicate",false)}
	report["after_collection"]={"event":_event("fixture:collect"),"duration_seconds":1,"custodian_id":town._item(AXE).custodian_id,"edge":town._item(AXE).edge,"owner_wallet":town.resident(OWNER).coins_col,"smith_wallet":town.resident(SMITH).coins_col,"owner_reserved":town._trade_account(OWNER).reserved_col,"host_move":"scripted_host_move_surrogate"}
	_check(delivery.get("ok",false) and work.get("ok",false) and collect.get("ok",false) and _event("fixture:deliver")=="axe_delivered" and _event("fixture:work")=="axe_repaired" and _event("fixture:collect")=="axe_repair_paid" and town._item(AXE).custodian_id==OWNER and town._item(AXE).edge==100 and town._trade_account(SMITH).iron==0 and town.resident(OWNER).coins_col==8 and town.resident(SMITH).coins_col==12 and town._trade_account(OWNER).reserved_col==0 and duplicate.get("duplicate",false), "scripted_lifecycle_conservation")
	var bytes:=FileAccess.get_file_as_bytes(path); town.release_writer(path); town=Town.new(); var cold: Dictionary=town.load_from(path)
	var cold_turns:=Turns.new(); root.add_child(cold_turns); cold_turns.town=town; cold_turns.save_path=path
	var feedback:Array=cold_turns._feedback_history(SMITH,cold_turns._record(SMITH)); cold_turns.free()
	_check(cold.get("ok",false) and FileAccess.get_file_as_bytes(path)==bytes and feedback.any(func(x): return x.get("result",{}).get("code","")=="axe_contract_accepted"), "cold_restart_feedback")
	report["final_cold_feedback"]={"feedback_code":"axe_contract_accepted","feedback_present":feedback.any(func(x): return x.get("result",{}).get("code","")=="axe_contract_accepted")}
	_finish(hashes)
func _advance(id:String,seconds:float)->void:
	var job:Dictionary=town.pending_job(id)
	if not job.is_empty(): town.host_move(id,town.destination(id,str(job.action)))
	var r:Dictionary=town.transaction(path,func(): return town.advance(seconds)); _check(r.get("ok",false),"advance_"+id)
func _option(id:String,action:String,part:String="",worker:String="",price:int=-1)->String:
	for o in town.trade_options(id):
		if o.get("action")==action and (part.is_empty() or o.get("_part")==part) and (worker.is_empty() or o.get("_worker_id")==worker) and (price<0 or o.get("_price")==price): return str(o.get("id", ""))
	return ""
func _contract(status:String)->Dictionary:
	for c in town.snapshot().life.contracts:
		if c.get("item_id")==AXE and c.get("status")==status:return c
	return {}
func _event(command:String)->String:
	for e in town.snapshot().life.events:
		if e.get("operation_id")==command:return str(e.get("type",""))
	return ""
func _json(p:String)->Variant: return JSON.parse_string(FileAccess.get_file_as_string(p))
func _hashes()->Dictionary:
	var d={}; for p in [C,R,P,Runner.SOURCE,"res://agents/town_turns.gd","res://agents/reviewed_dialogue_fixture_adapter.gd"]: d[p]=FileAccess.get_sha256(p)
	return d
func _check(ok:bool,label:String)->void: checks+=1; if not ok and not failures.has(label): failures.append(label)
func _finish(hashes:Dictionary)->void:
	if turns!=null: turns.free()
	if town!=null: town.release_writer(path)
	if not path.is_empty() and FileAccess.file_exists(path):DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var unchanged:=_hashes()==hashes; _check(unchanged,"verified_input_hashes_changed")
	report.checks=checks; report.failures=failures; report.verified_input_hashes_unchanged=unchanged; report.ok=failures.is_empty()
	var out:=ProjectSettings.globalize_path("res://../private/iteration-20260923/smith-saved-reply-full-lifecycle-%d.json"%Time.get_ticks_usec()); var f:=FileAccess.open(out,FileAccess.WRITE)
	if f==null:
		_check(false,"report_write_failed")
		report.checks=checks; report.failures=failures; report.ok=false
	else:
		f.store_string(JSON.stringify(report,"  ",true,true)); f.close()
	print(JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
