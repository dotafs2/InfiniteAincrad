extends SceneTree
## Package loading only: no main scene instantiation, audio or player save.
func _initialize()->void:
	var args:=OS.get_cmdline_user_args()
	var source:=""
	var output:=""
	for arg in args:
		if arg.begins_with("--wanted="):source=arg.trim_prefix("--wanted=")
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
	if not args.has("--test") or source.is_empty() or output.is_empty():
		quit(2);return
	var wanted:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(source))
	var failures:Array=[]
	var counts:Dictionary={}
	for path in wanted.resources:
		var resource:=ResourceLoader.load(path)
		if resource==null:failures.append("Resource cannot load: "+str(path));continue
		var type:=resource.get_class()
		counts[type]=int(counts.get(type,0))+1
	for entry in wanted.plain:
		if not FileAccess.file_exists(entry.path):failures.append("Missing file: "+str(entry.path));continue
		if FileAccess.get_sha256(entry.path)!=entry.sha256:failures.append("Changed raw file: "+str(entry.path))
	var music:AudioStreamOggVorbis=load("res://assets/audio/shop_theme_loop.ogg")
	var result:={"scope":"Desktop Godot reads the exported iOS PCK; no scene instances, native compilation, signing, audio playback or phone validation.","resources":wanted.resources.size(),"plain_files":wanted.plain.size(),"resource_types":counts,"project_name":ProjectSettings.get_setting("application/config/name"),"version":ProjectSettings.get_setting("application/config/version"),"main_scene":str(ProjectSettings.get_setting("application/run/main_scene")),"mobile_texture_import":ProjectSettings.get_setting("rendering/textures/vram_compression/import_etc2_astc",false),"music_seconds":music.get_length() if music else 0.0,"failures":failures}
	var file:=FileAccess.open(output,FileAccess.WRITE)
	if file==null:quit(2);return
	file.store_string(JSON.stringify(result,"  ")+"\n");file.close()
	print("IOS_RESOURCE_REVIEW "+JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
