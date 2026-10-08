extends SceneTree
## Transaction-only case checks. No scene, ads, purchases or real player saves.
const Game=preload("res://fidelity/game.gd")
const Rarity=preload("res://fidelity/skin_rarity.gd")
const Draw=preload("res://fidelity/skin_draw.gd")
class FaultySaveGame:
	extends "res://fidelity/game.gd"
	var fail_saves:=false
	func save_player_progress()->bool:
		return false if fail_saves else super.save_player_progress()

var checks:=0
var failures:Array[String]=[]
var files:Array[String]=[]
var completed_sections:Array[String]=[]
var base:="/tmp/hole-feast-case-%d"%OS.get_process_id()

func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)

func path(label:String)->String:
	var result:=base+"-"+label+".cfg"
	for suffix in ["",".tmp",".pre-coins.cfg"]:files.append(result+suffix)
	return result

func state(owner:Node3D)->Dictionary:
	return {"coins":owner.coins,"gems":owner.gems,"owned":owner.owned_skin_ids.duplicate(),
		"selected":owner.selected_skin_id,"pity":owner.draw_pity.duplicate(true),
		"case":owner.pending_skin_case(),"serial":owner.skin_case_serial}

func cold(saved_path:String)->Node3D:
	var owner:=Game.new();owner.test_progress_path=saved_path
	check(owner.load_player_progress(),"Isolated profile cold-loads: "+saved_path.get_file())
	return owner

func inspect_transaction_and_reentry()->void:
	var owner:Node3D=FaultySaveGame.new();owner.test_progress_path=path("durable")
	owner.coins=300;owner.gems=43;owner.stage=8
	owner.owned_skin_ids.append("tide");owner.selected_skin_id="tide"
	owner.selected_map="food";owner.unlocked_map_ids.assign(["city","food"])
	owner.best_scores={"city":400,"food":240,"toys":0,"frost":0}
	owner.map_completed_best_scores={"city":400,"food":125,"toys":0,"frost":0}
	owner.music_enabled=false;owner.sfx_enabled=false;owner.haptics_enabled=false
	owner.draw_pity={"foundation":{"epic":4,"legendary":9,"prismatic":19},"resonance":{"epic":1,"legendary":2,"prismatic":3}}
	owner.redeemed_transactions={"case-fixture-product":"sink_city.diamonds_100"}
	owner.reward_receipts={"case-fixture-round":{"id":"case-fixture-round","map":"food","base_coins":20,"settled":true,"score":200}}
	check(owner.save_player_progress(),"Existing funded profile and previous receipts save")
	var cfg:=ConfigFile.new();check(cfg.load(owner.test_progress_path)==OK,"Existing fixture is readable")
	cfg.set_value("unrelated","keep","case-sentinel")
	check(cfg.save(owner.test_progress_path)==OK,"Unrelated existing section is present")
	var before:Dictionary=state(owner)
	var offered:Dictionary=owner.skin_draw_offer("collection")
	var opened:Dictionary=owner.open_skin_case()
	check(bool(opened.get("ok",false)) and not bool(opened.get("resumed",true)),"One new opening succeeds")
	if not bool(opened.get("ok",false)):owner.free();return
	var winner:String=opened.id
	var case_id:String=opened.case_id
	check(owner.coins==200 and owner.owned_skin_ids.size()==3 and owner.skin_unlocked(winner),"One opening debits exactly 100 and grants one previously unowned skin")
	check(not before.owned.has(winner) and owner.selected_skin_id=="tide","The new case grants a unique skin without changing existing equipment")
	check(opened.price==100 and opened.rarity=="prismatic","Inherited highest-tier guarantee applies to the actual committed award")
	check(owner.draw_pity.collection==Draw.advance(offered.counters,opened.rarity),"The same economic transaction advances the disclosed pity state once")
	check(owner.draw_pity.foundation==before.pity.foundation and owner.draw_pity.resonance==before.pity.resonance,"Unified case preserves both historical pool counters")
	check(opened.presentation_seed>0 and opened.serial==1 and case_id=="skin-case-1","Presentation has one persistent seed and identity")
	check(opened.odds.total_weight==offered.total_weight and opened.odds.guarantee==offered.guarantee and opened.odds.counters==offered.counters,"Receipt captures the pre-draw adjusted odds and due guarantee")
	for index in Rarity.ORDER.size():
		var row:Dictionary=opened.odds.entries[index]
		check(row.rarity==Rarity.ORDER[index] and row.weight==offered.entries[index].weight and row.count==offered.entries[index].ids.size(),"Compact snapshot preserves exact eligible count and weight: "+row.rarity)
		check(is_equal_approx(row.chance,offered.entries[index].chance) and not row.has("ids"),"Compact snapshot preserves chance without saving a full catalog: "+row.rarity)
	var committed:Dictionary=state(owner)
	var committed_bytes:=FileAccess.get_file_as_bytes(owner.test_progress_path)
	for attempt in 4:
		if attempt>0:owner.last_unlock_msec=-1000 # Delayed callbacks must also be harmless.
		var resumed:Dictionary=owner.open_skin_case()
		check(resumed.ok and resumed.resumed and resumed.case_id==case_id and resumed.id==winner,"Repeated opening returns the same result, attempt %d"%attempt)
		check(state(owner)==committed,"Repeated opening cannot change debit, award, equipment, pity or serial, attempt %d"%attempt)
		for group in ["collection","foundation","resonance"]:
			check(not owner.unlock_random_skin(group).ok and state(owner)==committed,"Legacy "+group+" cannot bypass a pending case, attempt %d"%attempt)
	check(FileAccess.get_file_as_bytes(owner.test_progress_path)==committed_bytes,"Resume and blocked alternate draws do not rewrite the save")
	var pending:Dictionary=owner.pending_skin_case()
	pending.id="missing";pending.odds.entries[0].count=999;pending.odds.counters.epic=99
	opened.odds.entries[1].weight=9999;opened.price=1
	check(state(owner)==committed,"Mutating returned receipts and nested odds cannot alter stored state")
	check(not owner.acknowledge_skin_case("wrong-case") and state(owner)==committed,"Wrong acknowledgement cannot clear or charge the current case")
	for interruption in ["after commit","mid reel","result"]:
		var restored:=cold(owner.test_progress_path)
		check(state(restored)==committed,"Cold restart preserves one debit and one award at "+interruption)
		var resumed:Dictionary=restored.open_skin_case()
		check(resumed.ok and resumed.resumed and resumed.case_id==case_id and resumed.id==winner,"Cold reentry resumes the identical winner at "+interruption)
		check(restored.selected_map=="food" and restored.unlocked_map_ids==["city","food"] and restored.map_completed_best_scores.food==125,"Case cold restore preserves earned map access and progress at "+interruption)
		check(restored.gems==43 and restored.stage==8 and not restored.music_enabled and not restored.sfx_enabled and not restored.haptics_enabled,"Case cold restore preserves currency, stage and preferences at "+interruption)
		check(restored.redeemed_transactions==owner.redeemed_transactions and restored.reward_receipts==owner.reward_receipts,"Case cold restore preserves previous purchase and gameplay receipts at "+interruption)
		restored.free()
	owner.fail_saves=true
	check(not owner.acknowledge_skin_case(case_id) and state(owner)==committed,"Acknowledgement write failure retains the earned award and pending result")
	check(FileAccess.get_file_as_bytes(owner.test_progress_path)==committed_bytes,"Failed acknowledgement leaves the durable transaction unchanged")
	owner.fail_saves=false
	check(owner.select_skin(winner) and owner.selected_skin_id==winner,"Explicit result EQUIP selects the already-earned skin")
	check(owner.coins==200 and owner.pending_skin_case().case_id==case_id,"Equipping a result neither spends coins nor loses its pending receipt")
	check(owner.acknowledge_skin_case(case_id) and owner.pending_skin_case().is_empty(),"Acknowledgement durably clears presentation only")
	check(not owner.acknowledge_skin_case(case_id) and owner.coins==200 and owner.owned_skin_ids.size()==3,"Repeated acknowledgement is harmless and never grants or charges")
	var acknowledged:=cold(owner.test_progress_path)
	check(acknowledged.pending_skin_case().is_empty() and acknowledged.selected_skin_id==winner and acknowledged.coins==200,"Acknowledged result and explicit equipment survive restart")
	acknowledged.free()
	owner.last_unlock_msec=-1000
	var second:Dictionary=owner.open_skin_case()
	check(second.ok and not second.resumed and second.case_id!=case_id and second.serial==2 and second.id!=winner,"Next deliberate case commits a new unique identity and award")
	var second_state:Dictionary=state(owner)
	check(not owner.acknowledge_skin_case(case_id) and state(owner)==second_state,"An old completion callback cannot clear the new case")
	check(owner.coins==100 and owner.selected_skin_id==winner,"Second opening retains prior explicit equipment and charges only once")
	cfg.load(owner.test_progress_path)
	check(cfg.get_value("unrelated","keep","")=="case-sentinel","Opening, equipment and acknowledgement preserve unrelated config fields")
	owner.free()
	completed_sections.append("transaction")

func inspect_failure_and_boundaries()->void:
	var owner:Node3D=FaultySaveGame.new();owner.test_progress_path=path("rollback");owner.coins=100
	owner.draw_pity.foundation={"epic":4,"legendary":9,"prismatic":19}
	check(owner.save_player_progress(),"Rollback baseline saves")
	var before:Dictionary=state(owner)
	var bytes:=FileAccess.get_file_as_bytes(owner.test_progress_path)
	owner.fail_saves=true
	var result:Dictionary=owner.open_skin_case()
	check(not result.ok and result.message=="Could not save. No coins spent.","Commit write failure reports no spend")
	check(state(owner)==before and owner.last_unlock_msec==-1000,"Failed commit rolls back debit, new ownership, receipt, serial, pity and throttle")
	check(FileAccess.get_file_as_bytes(owner.test_progress_path)==bytes,"Failed commit cannot alter the original save")
	owner.fail_saves=false
	result=owner.open_skin_case()
	check(result.ok and owner.coins==0 and owner.skin_unlocked(result.id),"The exact 100-coin balance opens one case after a failed write")
	var frozen:Dictionary=state(owner)
	owner.phase="playing"
	check(not owner.open_skin_case().ok and state(owner)==frozen,"Gameplay cannot start or reroll a case")
	owner.phase="title"
	check(owner.open_skin_case().resumed and state(owner)==frozen,"A zero balance can still resume its paid pending result")
	check(owner.acknowledge_skin_case(result.case_id),"Boundary case acknowledgement saves")
	owner.last_unlock_msec=-1000
	var deficit:Dictionary=owner.open_skin_case()
	check(not deficit.ok and deficit.price==100 and deficit.missing_coins==100 and owner.coins==0,"A later unaffordable case has the exact existing shortage")
	owner.free()
	owner=Game.new();owner.coins=100;owner.test_progress_path=path("no-directory")+"/save.cfg"
	before=state(owner)
	check(not owner.open_skin_case().ok and state(owner)==before,"A real missing destination rejects a case without economic changes")
	owner.free()
	owner=Game.new();owner.test_progress_path=path("last");owner.coins=100
	owner.owned_skin_ids=owner.skin_ids("collection");owner.owned_skin_ids.erase("rainfall")
	result=owner.open_skin_case()
	check(result.ok and result.id=="rainfall" and owner.coins==0 and owner.owned_skin_ids.size()==200,"The last remaining skin costs 100 once and is the actual winner")
	check(owner.skin_unlock_price("collection")==0 and owner.locked_skin_ids("collection").is_empty(),"The ownership pool is complete while its last result is still pending")
	var last:=cold(owner.test_progress_path)
	var replay:Dictionary=last.open_skin_case()
	check(replay.ok and replay.resumed and replay.case_id==result.case_id and replay.id=="rainfall","Sold-out detection cannot hide the final paid result after restart")
	check(last.acknowledge_skin_case(replay.case_id),"Final result can be acknowledged")
	var complete:Dictionary=state(last)
	var sold_out:Dictionary=last.open_skin_case()
	check(not sold_out.ok and sold_out.message=="COLLECTION COMPLETE" and state(last)==complete,"Complete collection cannot spend, reroll or manufacture another receipt")
	last.free();owner.free()
	owner=Game.new();owner.test_progress_path=path("legacy");owner.coins=200
	result=owner.unlock_random_skin("collection")
	check(result.ok and owner.selected_skin_id==result.id and owner.coins==100 and owner.pending_skin_case().is_empty(),"Legacy random draw keeps auto-equipment and does not invent a case presentation")
	owner.free()
	completed_sections.append("boundaries")

func inspect_receipt_sanitization()->void:
	var owner:=Game.new();owner.test_progress_path=path("sanitize");owner.coins=200
	var result:Dictionary=owner.open_skin_case()
	check(result.ok,"Sanitization fixture has one real atomic result")
	if not result.ok:owner.free();return
	var cfg:=ConfigFile.new();cfg.load(owner.test_progress_path)
	var valid:Dictionary=cfg.get_value("collection","pending_case")
	var dirty:Dictionary=valid.duplicate(true)
	dirty.extra="untrusted metadata";dirty.odds.entries[0].chance=12345.0
	cfg.set_value("collection","pending_case",dirty);cfg.set_value("collection","case_serial",0)
	check(cfg.save(owner.test_progress_path)==OK,"Receipt normalization fixture writes")
	var restored:=cold(owner.test_progress_path)
	var cleaned:Dictionary=restored.pending_skin_case()
	check(not cleaned.has("extra") and cleaned==valid and restored.skin_case_serial==1,"Restore drops unknown fields, derives chance from tickets and retains monotonic receipt identity")
	restored.free()
	var malformed:Array=[]
	for kind in ["unknown skin","unowned skin","wrong identity","missing odds","negative count","string counter","wrong price"]:
		dirty=valid.duplicate(true)
		match kind:
			"unknown skin":dirty.id="not-a-skin"
			"unowned skin":dirty.id=owner.locked_skin_ids("collection")[0]
			"wrong identity":dirty.case_id="skin-case-other"
			"missing odds":dirty.erase("odds")
			"negative count":dirty.odds.entries[0].count=-1
			"string counter":dirty.odds.counters.epic="corrupt"
			"wrong price":dirty.price=-100
		malformed.append({"kind":kind,"value":dirty})
	for fixture:Dictionary in malformed:
		cfg.set_value("collection","pending_case",fixture.value)
		check(cfg.save(owner.test_progress_path)==OK,"Malformed presentation fixture writes: "+fixture.kind)
		var original:=FileAccess.get_file_as_bytes(owner.test_progress_path)
		restored=cold(owner.test_progress_path)
		check(restored.pending_skin_case().is_empty(),"Malformed presentation is rejected: "+fixture.kind)
		check(restored.coins==owner.coins and restored.owned_skin_ids==owner.owned_skin_ids and restored.selected_skin_id==owner.selected_skin_id and restored.draw_pity==owner.draw_pity,"Invalid presentation neither grants nor removes economic state: "+fixture.kind)
		check(FileAccess.get_file_as_bytes(owner.test_progress_path)==original,"Reading malformed presentation preserves recoverable original bytes: "+fixture.kind)
		restored.free()
	owner.free()
	completed_sections.append("sanitization")

func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	inspect_transaction_and_reentry()
	inspect_failure_and_boundaries()
	inspect_receipt_sanitization()
	check(completed_sections==["transaction","boundaries","sanitization"],"All transaction sections complete without an early script-error return")
	for file in files:
		if FileAccess.file_exists(file):DirAccess.remove_absolute(file)
	var report:={"checks":checks,"failures":failures,"scope":"Isolated atomic case transaction, pending reentry, cold saves, rollback, odds receipts and compatibility; no reel or real-device performance claim"}
	print("SKIN_CASE_TRANSACTION_ACCEPTANCE "+JSON.stringify(report))
	var report_ok:=true
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var target:=argument.trim_prefix("--report=")
			var output:=FileAccess.open(target,FileAccess.WRITE) if target.is_absolute_path() else null
			if output==null:report_ok=false
			else:output.store_string(JSON.stringify(report,"\t")+"\n");output.close()
	quit(0 if failures.is_empty() and report_ok else 1)
