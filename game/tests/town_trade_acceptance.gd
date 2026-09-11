extends "res://tests/town_life_acceptance.gd"

const TownTrade = preload("res://core/town_trade.gd")

func _initialize() -> void:
	run.call_deferred()

func trade_fixture() -> Dictionary:
	var world := fixture()
	var ember := "fictional:ember"
	var birch := "fictional:birch"
	var forge := "fictional:forge"
	for person in world.residents:
		var old_id: String = person.get("stable_id")
		var new_id := ember if old_id == "fixture:a" else birch if old_id == "fixture:b" else forge
		person.stable_id = new_id
		person.role = "axe owner" if new_id == ember else "wood carpenter" if new_id == birch else "metal smith"
		person.coins_col = 12 if new_id == ember else 3
	for account in world.survival.accounts:
		account.resident_id = ember if account.resident_id == "fixture:a" else birch if account.resident_id == "fixture:b" else forge
	var old_positions: Dictionary = world.godot.positions.duplicate(true)
	var old_homes: Dictionary = world.godot.homes.duplicate(true)
	var old_observations: Dictionary = world.godot.observations.duplicate(true)
	world.godot.positions.clear()
	world.godot.homes.clear()
	world.godot.observations.clear()
	for old_id in ["fixture:a", "fixture:b", "fixture:c"]:
		var new_id := ember if old_id == "fixture:a" else birch if old_id == "fixture:b" else forge
		world.godot.positions[new_id] = [0, 0, 0] if new_id == ember else [1, 0, 0] if new_id == birch else [2, 0, 0]
		world.godot.homes[new_id] = old_homes[old_id]
		world.godot.observations[new_id] = old_observations[old_id]
	world.life.items = [
		{"id": "fictional:axe-edge", "kind": "axe", "owner_id": ember, "custodian_id": ember, "edge": 20, "handle": 20, "source": "fictional_fixture"},
		{"id": "fictional:opaque", "kind": "unmodeled", "owner_id": forge, "custodian_id": forge, "opaque": {"keep": true}}
	]
	world.life.accounts = [
		{"resident_id": ember, "wood": 2, "iron": 0, "kindling": 0, "reserved_col": 0},
		{"resident_id": birch, "wood": 1, "iron": 0, "kindling": 0, "reserved_col": 0},
		{"resident_id": forge, "wood": 0, "iron": 1, "kindling": 0, "reserved_col": 0}
	]
	world.life.skills = [{"resident_id": birch, "skill_id": "wood_repair"}, {"resident_id": forge, "skill_id": "metal_repair"}]
	world.life.contracts = [{"id": "fictional:historical", "part": "legacy", "item_id": "fictional:missing", "owner_id": forge, "worker_id": birch, "status": "closed_old", "price_col": 99, "reserved_col": 0, "opaque": "preserve"}]
	world.legacy_marker = {"unchanged": true}
	return world

func _write_fixture(path: String, world: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(world, "", true, true))
	file.close()

func _load_trade(path: String) -> TownTrade:
	var town := TownTrade.new()
	check(town.load_from(path).ok, "fictional trade fixture loads")
	return town

func _option(town: TownTrade, resident_id: String, action: String, part: String = "", worker_id: String = "", price: int = -1) -> String:
	for value in town.trade_options(resident_id):
		if value.get("action") == action and (part.is_empty() or value.get("_part") == part) and (worker_id.is_empty() or value.get("_worker_id") == worker_id) and (price < 0 or value.get("_price") == price):
			return str(value.get("id"))
	return ""

func _contract(town: TownTrade, item_id: String, status: String) -> Dictionary:
	for value in town.snapshot().life.get("contracts", []):
		if value.get("item_id") == item_id and value.get("status") == status:
			return value
	return {}

func execute(town: TownTrade, path: String, id: String, option: String, command: String) -> Dictionary:
	var result := town.transaction(path, func(): return town.submit_trade(id, option, command, "opengameagent_fixture"))
	check(result.ok, command + ": " + str(result.get("code", "")))
	return result

func elapse(town: TownTrade, path: String, seconds: float) -> void:
	var result := town.transaction(path, func(): return town.advance(seconds))
	check(result.ok, "advance and durable save: " + str(result.get("code", "")))

func arrive(town: TownTrade, id: String) -> void:
	var job := town.pending_job(id)
	town.host_move(id, town.destination(id, job.action))

func run() -> void:
	var path := "user://fictional-town-trade-%d.json" % Time.get_ticks_usec()
	var initial := trade_fixture()
	_write_fixture(path, initial)
	var town := TownTrade.new()
	var loaded := town.load_from(path)
	check(loaded.ok, "load legacy life schema: " + str(loaded.get("code", "")))
	if not loaded.ok:
		quit(1)
		return
	var owner := "fictional:ember"
	var wood := "fictional:birch"
	var metal := "fictional:forge"
	check(_option(town, owner, "use_tool").is_empty(), "damaged tool cannot be used")
	check(town.resident_view(owner).unavailable_actions[0].required_each == 100, "owner receives the actual reason tool use is unavailable")
	execute(town, path, owner, "ask:" + metal, "ask-metal")
	var request: String = town.snapshot().life.events[-1].request_id
	execute(town, path, metal, "reply:" + request + ":willing", "reply-metal")
	check(town.resident_view(wood).experiences.is_empty(), "third person does not receive private request/reply")
	var offers := town.trade_options(owner).filter(func(o): return o.action == "offer_repair" and o._part == "edge")
	check(offers.size() == 3, "same repair offers all three optional prices")
	execute(town, path, owner, _option(town, owner, "offer_repair", "edge", metal, 5), "offer-edge")
	var edge := _contract(town, "fictional:axe-edge", "proposed")
	var edge_id: String = edge.id
	check(_option(town, owner, "offer_repair").is_empty(), "one active contract per physical item")
	execute(town, path, metal, "contract:accept:" + edge_id, "accept-edge")
	check(town.resident(owner).coins_col == 7 and town._trade_account(owner).reserved_col == 5, "acceptance reserves money once")
	execute(town, path, owner, "contract:deliver:" + edge_id, "deliver-edge")
	elapse(town, path, 10)
	check(town._item("fictional:axe-edge").custodian_id == owner, "time without arrival never delivers")
	arrive(town, owner)
	elapse(town, path, 1)
	check(town._item("fictional:axe-edge").custodian_id == metal, "physical arrival transfers custody only")
	execute(town, path, metal, "contract:work:" + edge_id + ":edge", "work-edge")
	elapse(town, path, 60)
	check(town._item("fictional:axe-edge").edge == 20, "work away from workplace has no effect")
	arrive(town, metal)
	elapse(town, path, 30)
	var bytes := FileAccess.get_file_as_bytes(path)
	town.release_writer(path)
	var restored := TownTrade.new()
	check(restored.load_from(path).ok, "mid-repair independent instance restores")
	check(FileAccess.get_file_as_bytes(path) == bytes, "cold read does not rewrite bytes")
	town = restored
	elapse(town, path, 29)
	check(town._item("fictional:axe-edge").edge == 20, "59 seconds is not a finished repair")
	elapse(town, path, 1)
	check(town._item("fictional:axe-edge").edge == 100 and town._trade_account(metal).iron == 0, "60 seconds consumes exactly one iron")
	execute(town, path, owner, "contract:collect:" + edge_id, "collect-edge")
	arrive(town, owner)
	elapse(town, path, 1)
	check(town.resident(metal).coins_col == 8 and town._trade_account(owner).reserved_col == 0, "collect settles once")
	var after := town.snapshot()
	check(town.submit_trade(owner, "contract:collect:" + edge_id, "collect-edge", "opengameagent_fixture").duplicate and town.snapshot() == after, "duplicate collection cannot repay")
	check(_option(town, owner, "use_tool").is_empty(), "unrepaired handle still blocks use")
	execute(town, path, owner, _option(town, owner, "offer_repair", "handle", wood, 2), "offer-handle-refused")
	var h := _contract(town, "fictional:axe-edge", "proposed")
	execute(town, path, wood, "contract:reject:" + str(h.id), "reject-handle")
	check(town.resident(owner).coins_col == 7, "refusal moves neither resources nor money")
	execute(town, path, owner, _option(town, owner, "offer_repair", "handle", wood, 2), "offer-handle-cancelled")
	h = _contract(town, "fictional:axe-edge", "proposed")
	execute(town, path, wood, "contract:accept:" + str(h.id), "accept-then-cancel")
	execute(town, path, owner, "contract:cancel:" + str(h.id), "cancel-handle")
	check(town.resident(owner).coins_col == 7 and town._trade_account(owner).reserved_col == 0, "cancellation returns escrow")
	execute(town, path, owner, _option(town, owner, "offer_repair", "handle", wood, 2), "offer-handle")
	h = _contract(town, "fictional:axe-edge", "proposed")
	execute(town, path, wood, "contract:accept:" + str(h.id), "accept-handle")
	execute(town, path, owner, "contract:deliver:" + str(h.id), "deliver-handle")
	arrive(town, owner)
	elapse(town, path, 1)
	execute(town, path, wood, "contract:work:" + str(h.id) + ":handle", "work-handle")
	arrive(town, wood)
	elapse(town, path, 60)
	execute(town, path, owner, "contract:collect:" + str(h.id), "collect-handle")
	arrive(town, owner)
	elapse(town, path, 1)
	execute(town, path, owner, "tool:use", "use-axe")
	arrive(town, owner)
	elapse(town, path, 59)
	check(town._trade_account(owner).wood == 2, "premature use retains wood")
	elapse(town, path, 1)
	check(town._trade_account(owner).wood == 1 and town._trade_account(owner).kindling == 1, "one wood becomes one kindling")
	check(town.resident(owner).coins_col + town.resident(wood).coins_col + town.resident(metal).coins_col == 18, "total coins conserved")
	check(town._trade_account(wood).wood == 0 and town._trade_account(metal).iron == 0, "both repair materials consumed once")
	check(town.snapshot().life.contracts[0] == initial.life.contracts[0] and town.snapshot().legacy_marker == initial.legacy_marker, "opaque old fields retained")
	check(town.snapshot().life.events.all(func(e): return e.source == "opengameagent_fixture"), "all decisions honestly fixture attributed")
	town.host_move(metal, Vector3(20, 0, 0))
	check(not town.trade_options(owner).any(func(o): return o.action == "ask_help" and o.counterparty == metal), "cannot speak across town")
	var view: Dictionary = town.resident_view(owner)
	check(not JSON.stringify(view.life_account).contains(metal) and view.life_account.wood == 1, "personal account only")
	town.host_visitor_position(town.position_of(owner))
	var asked := town.transaction(path, func(): return town.visitor_inquiry(owner, "需要帮助吗？", "visitor-ask", "scripted_player_fixture"))
	check(asked.ok, "nearby player inquiry persists before model response")
	var wallet_before: float = town.resident(owner).coins_col
	execute(town, path, owner, "visitor-reply:" + str(asked.request_id) + ":unavailable", "visitor-decline")
	check(not town.trade_options(owner).any(func(o): return o.action == "visitor_reply") and town.resident(owner).coins_col == wallet_before,
		"resident can decline player once without resource effects")
	check(not town.resident_view(wood).experiences.any(func(e): return e.get("request_id") == asked.request_id), "player conversation stays private")
	var damaged := town.snapshot()
	damaged.life.accounts[0].wood = -1
	check(not town._validate_state(damaged).ok, "negative resources rejected on cold-load path")
	var before_failed := town.snapshot()
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(path + ".tmp"))
	var failed := town.transaction(path, func(): return town.submit_trade(owner, "approach:" + wood, "failed-save", "opengameagent_fixture"))
	check(not failed.ok and town.snapshot() == before_failed, "actual failed save rolls back action")
	town.release_writer(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".tmp"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print(JSON.stringify({"suite": "town_trade", "checks": checks, "failures": failures, "paid_calls": 0}))
	quit(0 if failures == 0 else 1)
