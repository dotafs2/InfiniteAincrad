extends SceneTree
const Game=preload("res://fidelity/game.gd")
const ReleaseInfo=preload("res://fidelity/release_info.gd")
var checks:=0
var failures:Array[String]=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frames()->void:
	await process_frame;await process_frame
func run()->void:
	check(ReleaseInfo.IOS_PRIVACY_TEXT.contains("Coins, diamonds") and ReleaseInfo.PRIVACY_TEXT.contains("Coins, diamonds"),"Both platform policies disclose the local diamond wallet")
	check(ReleaseInfo.IOS_PRIVACY_TEXT.contains("Apple handles optional diamond purchases") and ReleaseInfo.IOS_PRIVACY_TEXT.contains("earlier coin packs remain valid"),"Native policy explains new diamond purchases and preserved legacy coin receipts")
	check(ReleaseInfo.IOS_PRIVACY_TEXT.contains("ad confirms your reward") and ReleaseInfo.IOS_PRIVACY_TEXT.contains("you close the video") and ReleaseInfo.IOS_PRIVACY_TEXT.contains("provider determines video length"),"Rewarded disclosure requires earning and closing without promising a fixed video duration")
	var settings_name:=str(ProjectSettings.get_setting("application/config/name"))
	var settings_custom:=bool(ProjectSettings.get_setting("application/config/use_custom_user_dir"))
	var current_dir:=OS.get_user_data_dir()
	ProjectSettings.set_setting("application/config/name","SinkCity")
	ProjectSettings.set_setting("application/config/use_custom_user_dir",false)
	var legacy_dir:=OS.get_user_data_dir()
	ProjectSettings.set_setting("application/config/name",settings_name)
	ProjectSettings.set_setting("application/config/use_custom_user_dir",settings_custom)
	check(current_dir==legacy_dir,"Renamed game retains the engine's original save directory on this platform")
	check(ProjectSettings.get_setting("application/config/custom_user_dir_name")=="godot/app_userdata/SinkCity","Web and Unix storage retain the exact legacy identity")
	check(ProjectSettings.get_setting("application/config/custom_user_dir_name.macos")=="Godot/app_userdata/SinkCity","macOS storage preserves case")
	check(ProjectSettings.get_setting("application/config/custom_user_dir_name.windows")=="Godot/app_userdata/SinkCity","Windows storage preserves case")
	var game:=Game.new();root.add_child(game);await frames()
	check(ProjectSettings.get_setting("application/config/name")=="Hole Feast","Selected display name ships")
	var settings_button:Button=game.ui.get_node_or_null("home-settings")
	check(is_instance_valid(settings_button) and game.ui.get_node_or_null("release-info")==null,"Home keeps privacy and audio inside its settings entry")
	if is_instance_valid(settings_button):
		settings_button.pressed.emit();await frames()
	var button:Button=game.ui.get_node_or_null("release-info")
	check(game.ui.menu_screen=="settings" and is_instance_valid(button),"Settings exposes the privacy and support entry")
	if is_instance_valid(button):
		check(minf(button.size.x,button.size.y)*375.0/540.0>=44,"Information entry has a phone touch target")
		button.pressed.emit();await frames()
	var panel:Control=game.ui.release_info
	check(is_instance_valid(panel),"Information panel opens")
	if is_instance_valid(panel):
		check(panel.mouse_filter==Control.MOUSE_FILTER_STOP,"Modal consumes input over settings")
		check(panel.body.text.contains("chenxi.qu.work@gmail.com"),"Privacy contact is present")
		check(panel.body.text.contains("Local progress"),"Privacy explains local saves")
		check(panel.body.text.contains("not automatically uploaded"),"Optional reports are accurately disclosed")
		check(not panel.body.bbcode_enabled,"License and policy text is not interpreted as markup")
		for tab in panel.tabs:
			check(tab.size.y*375.0/540.0>=44,"Information tab has a phone touch target")
		panel.show_page("Support")
		check(panel.body.text.contains("Developer: Chenxi"),"Support names the operator")
		check(panel.body.text.contains("Three maps are playable"),"Support describes released scope")
		panel.show_page("Credits")
		for filename in panel.NOTICE_FILES:
			var content:=FileAccess.get_file_as_string("res://assets/legal/"+filename)
			check(content.length()>100,"Full notice is delivered: "+filename)
			check(panel.body.text.contains(content),"Full notice is reachable: "+filename)
		check(panel.body.text.contains("THIRD-PARTY LICENSE TEXTS"),"Engine dependency license texts are included")
		check(panel.get_child(1).get_rect().end.y<=game.ui.size.y,"Information panel fits the actual safe portrait canvas")
		panel.queue_free();await frames()
	check(game.phase=="title" and game.ui.menu_screen=="settings","Closing information returns to settings without starting a run")
	var back:Button=game.ui.get_node_or_null("settings-back")
	if is_instance_valid(back):back.pressed.emit();await frames()
	check(game.ui.menu_screen=="home" and is_instance_valid(game.ui.get_node_or_null("home-settings")),"Settings BACK returns to the stable home entry")
	game.ui.open_settings();await frames()
	check(is_instance_valid(game.ui.get_node_or_null("release-info")),"Information entry survives reopening settings")
	game.queue_free();await frames()
	print("RELEASE_INFO_ACCEPTANCE "+JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
