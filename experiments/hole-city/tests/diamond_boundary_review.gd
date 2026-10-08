extends SceneTree
## Independent fault-injection checks at the durable game-wallet boundary.
## All providers are explicit local --test fixtures; no SDK request is made.
const Game=preload("res://fidelity/game.gd")
const Ads=preload("res://fidelity/ads_bridge.gd")
var checks:=0
var failures:Array[String]=[]
var temporary_paths:Array[String]=[]
var base:="/tmp/hole-diamond-boundary-%d"%OS.get_process_id()

class FaultySaveGame:
	extends "res://fidelity/game.gd"
	var save_calls:=0
	var fail_on_save:=0
	func save_player_progress()->bool:
		save_calls+=1
		if save_calls==fail_on_save:return false
		return super.save_player_progress()

class Video extends RefCounted:
	signal rewarded_earned(request_id:String)
	signal rewarded_closed(request_id:String)
	signal rewarded_failed(request_id:String,message:String)
	signal availability_changed
	var requests:Array[String]=[]
	func sink_city_rewarded_protocol_version()->int:return 1
	func initialize()->void:pass
	func rewarded_available()->bool:return true
	func show_rewarded(request_id:String)->bool:
		requests.append(request_id);return true

class Acknowledgements extends Node:
	var finished:Array[String]=[]
	func active_request_id()->String:return ""
	func acknowledge(transaction_id:String)->bool:
		finished.append(transaction_id);return true

func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func isolated_path(label:String)->String:
	var path:=base+"-"+label+".cfg"
	for suffix in ["",".tmp",".pre-coins.cfg"]:temporary_paths.append(path+suffix)
	return path
func read_save(path:String)->ConfigFile:
	var cfg:=ConfigFile.new()
	check(cfg.load(path)==OK,"A durable isolated wallet file can be read")
	return cfg

func second_reward_commit_failure()->void:
	var owner:=FaultySaveGame.new();owner.test_progress_path=isolated_path("second-reward-save")
	owner.rewarded_requests["accepted-diamond-video"]={"purpose":"diamonds","round":"","status":"loading","closed":false,"authenticated":false}
	owner.fail_on_save=2
	var initial_gems:int=owner.gems
	owner.credit_round_double("accepted-diamond-video")
	check(owner.save_calls==2 and owner.gems==initial_gems and owner.diamond_video_ready_at==0,"Second reward commit failure rolls back diamonds and cooldown after the earned marker saved")
	check(owner.rewarded_requests["accepted-diamond-video"].status=="reward_due" and owner.verified_rewards_waiting.has("accepted-diamond-video"),"Failed reward commit retains authenticated work for retry")
	var cfg:=read_save(owner.test_progress_path)
	check(cfg.get_value("progress","gems")==initial_gems and cfg.get_value("rewards","video_requests")["accepted-diamond-video"].status=="reward_due","Crash evidence contains no uncommitted diamond grant but keeps the verified reward marker")
	var path:String=owner.test_progress_path;owner.free()
	var restarted:=Game.new();restarted.test_progress_path=path
	check(restarted.load_player_progress(),"Authenticated unfinished diamond reward restores after process replacement")
	restarted.retry_verified_rewards();restarted.retry_verified_rewards()
	check(restarted.gems==initial_gems+3 and restarted.rewarded_requests["accepted-diamond-video"].status=="earned","Restart settles the second-commit failure once, even when retry repeats")
	check(restarted.diamond_video_cooldown_remaining()>119,"Recovered diamond grant commits its cooldown with its balance")
	restarted.free()

func extension_commit_failure()->void:
	var owner:=FaultySaveGame.new();owner.test_progress_path=isolated_path("extension-save")
	owner.world=Node3D.new();owner.player=CharacterBody3D.new();owner.phase="complete";owner.remaining=0
	owner.round_receipt={"id":"finished-world","map":"city","base_coins":13,"settled":true,"doubled":false,"extension_used":false}
	owner.reward_receipts["finished-world"]=owner.round_receipt.duplicate(true)
	owner.rewarded_requests["earned-extension"]={"purpose":"extension","round":"finished-world","status":"loading","closed":true,"authenticated":false,"world":owner.world.get_instance_id()}
	owner.fail_on_save=2
	var initial_gems:int=owner.gems;var initial_coins:int=owner.coins
	owner.credit_round_double("earned-extension")
	check(owner.save_calls==2 and owner.phase=="complete" and owner.remaining==0 and not owner.extension_used,"Uncommitted extension never starts its timer")
	check(not owner.round_receipt.extension_used and not owner.reward_receipts["finished-world"].extension_used and owner.gems==initial_gems and owner.coins==initial_coins,"Extension commit failure rolls back receipt state without spending or granting currency")
	var cfg:=read_save(owner.test_progress_path)
	check(cfg.get_value("rewards","video_requests")["earned-extension"].status=="reward_due" and not cfg.get_value("rewards","rounds")["finished-world"].extension_used,"Saved earned marker survives while uncommitted continuation use does not")
	var path:String=owner.test_progress_path;owner.world.free();owner.player.free();owner.free()
	var restarted:=Game.new();restarted.test_progress_path=path
	check(restarted.load_player_progress(),"Earned extension restores without reviving the old physical world")
	restarted.retry_verified_rewards();restarted.retry_verified_rewards()
	check(restarted.phase=="title" and restarted.gems==initial_gems+5 and restarted.coins==initial_coins,"Lost-world extension compensates once after a commit failure and restart")
	restarted.free()

func still_visible_video()->void:
	var owner:=Game.new();owner.test_progress_path=isolated_path("visible-video")
	var bridge:=Ads.new();root.add_child(bridge);owner.ads=bridge
	var video:=Video.new()
	check(bridge.bind_test_native(video),"Visible-video fixture binds the real AdsBridge protocol")
	bridge.rewarded_completed.connect(owner.credit_round_double)
	bridge.rewarded_closed.connect(owner.reward_video_closed)
	bridge.rewarded_failed.connect(owner.reward_video_failed)
	bridge.initialize()
	check(owner.request_diamond_video().ok and video.requests.size()==1,"Diamond offer opens one actual accepted provider invocation")
	var id:String=video.requests[0];var initial_gems:int=owner.gems
	video.rewarded_earned.emit(id)
	check(owner.gems==initial_gems+3 and owner.reward_video_pending() and bridge.reward_in_flight,"Earned diamond grant keeps both the game and shared bridge pending until actual dismissal")
	check(not owner._request_reward_video("diamonds").ok and video.requests.size()==1,"Even a provider claiming readiness cannot open another video while the first is visible")
	video.rewarded_closed.emit(id)
	check(not owner.reward_video_pending() and not bridge.reward_in_flight and bridge.validated_reward_available(),"Only actual close releases both game and shared presentation locks")
	video.rewarded_earned.emit(id);video.rewarded_closed.emit(id)
	check(owner.gems==initial_gems+3,"Duplicated late callbacks from that visible video cannot grant twice")
	bridge.free();owner.free()

func legacy_request_and_receipt_binding()->void:
	var path:=isolated_path("legacy-purpose");var cfg:=ConfigFile.new()
	cfg.set_value("progress","skin_schema",3);cfg.set_value("progress","coins",50);cfg.set_value("progress","gems",10)
	cfg.set_value("rewards","rounds",{"old-round":{"id":"old-round","map":"city","base_coins":15,"settled":true,"doubled":false}})
	# Older saved requests did not have a purpose field.
	cfg.set_value("rewards","video_requests",{"old-earned":{"round":"old-round","status":"reward_due"},"old-loading":{"round":"old-round","status":"loading"}})
	check(cfg.save(path)==OK,"Legacy request fixture writes without a modern purpose field")
	var owner:=Game.new();owner.test_progress_path=path
	check(owner.load_player_progress(),"Old video request schema still restores")
	owner.retry_verified_rewards();owner.retry_verified_rewards()
	check(owner.coins==65 and owner.gems==10 and owner.reward_receipts["old-round"].doubled,"Legacy earned request remains an exactly-once coin bonus, never a diamond grant")
	check(owner.rewarded_requests["old-loading"].status=="closed" and not owner.verified_rewards_waiting.has("old-loading"),"Restart never promotes an old loading video into earned work")
	owner.commerce=Acknowledgements.new()
	owner.redeemed_transactions["persisted-coin-transaction"]="sink_city.coins_320"
	owner.credit_verified_purchase("persisted-coin-transaction","sink_city.diamonds_60")
	check(owner.coins==65 and owner.gems==10 and owner.commerce.finished.is_empty(),"Persisted cross-currency transaction conflict neither grants nor acknowledges a different product")
	owner.credit_verified_purchase("persisted-coin-transaction","sink_city.coins_320")
	check(owner.commerce.finished==["persisted-coin-transaction"] and owner.coins==65,"Matching durable legacy coin transaction can finish without a second grant")
	owner.commerce.free();owner.free()

func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	second_reward_commit_failure();extension_commit_failure();still_visible_video();legacy_request_and_receipt_binding()
	await process_frame
	for path in temporary_paths:
		if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
	var result:={"checks":checks,"failures":failures,"scope":"Independent durable-wallet faults and accepted provider callbacks in isolated --test fixtures; no real SDK purchase or ad."}
	print("DIAMOND_BOUNDARY_REVIEW "+JSON.stringify(result))
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):FileAccess.open(argument.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	quit(0 if failures.is_empty() else 1)
