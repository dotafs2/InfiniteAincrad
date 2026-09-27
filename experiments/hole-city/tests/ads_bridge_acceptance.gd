extends SceneTree
const Ads=preload("res://fidelity/ads_bridge.gd")

var checks:=0
var failures:Array[String]=[]
var game:Node3D

func _initialize() -> void:
	run.call_deferred()

func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok:
		failures.append(message)
		push_error(message)

func frames(count:int) -> void:
	for i in count:await process_frame

func run() -> void:
	game=load("res://fidelity/main.tscn").instantiate()
	root.add_child(game)
	await frames(4)
	check(is_instance_valid(game.ads),"the game owns an explicit ad bridge")
	check(game.ads.initialized,"the ad bridge initializes once at startup")
	check(not game.ads.native_available,"desktop fallback has no native ad singleton")
	check(not game.ads.show_rewarded(),"desktop fallback never claims a rewarded ad")
	check(Ads.IOS_TEST_REWARDED_UNIT.begins_with("ca-app-pub-"),"the development bridge documents Google's iOS test unit")
	var result:={"checks":checks,"failures":failures,"native_available":game.ads.native_available}
	print("ADS_BRIDGE_ACCEPTANCE "+JSON.stringify(result))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
