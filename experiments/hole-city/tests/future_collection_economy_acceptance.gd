extends SceneTree
## Synthetic future catalog validates the user's 200-skin planning assumption.
## It does not add or advertise unbuilt skins in the playable catalog.
const Draw=preload("res://fidelity/skin_draw.gd")
const Rarity=preload("res://fidelity/skin_rarity.gd")
const Game=preload("res://fidelity/game.gd")
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	var catalog:Array[Dictionary]=[]
	for index in 200:
		catalog.append({"id":"future_fixture_%03d"%index,"group":"foundation","rarity":Rarity.ORDER[index%6]})
	for seed_value in 64:
		var rng:=RandomNumberGenerator.new();rng.seed=seed_value
		var owned:Array[String]=["future_fixture_000"]
		var counters:=Draw.clean_counters({})
		var valid:=true
		for index in 199:
			var offer:=Draw.offer(catalog,owned,"collection",counters)
			var id:=Draw.choose(offer,rng.randf(),rng.randf())
			if id.is_empty() or owned.has(id):valid=false;break
			owned.append(id)
			var definition:Dictionary=catalog.filter(func(entry):return entry.id==id)[0]
			counters=Draw.advance(counters,definition.rarity)
		check(valid and owned.size()==200 and Draw.offer(catalog,owned,"collection",counters).total_weight==0,"Synthetic 200-skin catalog finishes after exactly199 unique draws, seed%d"%seed_value)
	check(Game.POINTS_PER_COIN==10 and Game.COIN_DRAW_PRICE==100,"1000 earned points buy exactly one draw")
	check(Game.COIN_PACKS[0].gems==100 and Game.COIN_PACKS[0].coins==2000,"Unchanged 100-diamond entry product funds20 actual draw prices")
	for offer in Game.COIN_PACKS:
		check(offer.coins==offer.gems*20,"Each exchange consistently delivers20coins per diamond")
	check(Game.COIN_BOOST_GEM_COST==2 and Game.EXTENSION_GEM_COST==2,"Optional score boost and continuation each cost2diamonds")
	check(Game.SKIN_DEFS.size()==200,"The authorized production catalog contains exactly two hundred separate entitlements")
	print("FUTURE_COLLECTION_ECONOMY_ACCEPTANCE "+JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
