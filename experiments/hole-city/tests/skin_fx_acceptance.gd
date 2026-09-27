extends SceneTree

const SkinVisual=preload("res://fidelity/skin_visual.gd")
var checks:=0
var failures:Array[String]=[]
var definitions:Array[Dictionary]=[
	{"id":"core_shell","tint":"c85d3b","accent":"e2a956"},
	{"id":"copper_ring","tint":"b86f52","accent":"e2a956"},
	{"id":"moss_bloom","tint":"6c8f7a","accent":"a9d8b5"},
	{"id":"gravitas","tint":"746f68","accent":"e2a956"},
	{"id":"lantern","tint":"d9ad62","accent":"efe4ce"},
	{"id":"shard","tint":"8da6a3","accent":"c85d3b"},
	{"id":"cinder","tint":"b66a4a","accent":"e2a956"},
	{"id":"tide","tint":"4d9aa0","accent":"a9d8b5"},
	{"id":"orbit","tint":"6b6fb6","accent":"d9ad62"},
	{"id":"prism_vale","tint":"d77c9b","accent":"7be4d7"}
]

func _initialize() -> void:
	run.call_deferred()

func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok:failures.append(message);push_error(message)

func run() -> void:
	var shader_profiles:={}
	for definition in definitions:
		var visual:=SkinVisual.new()
		root.add_child(visual)
		visual.build(definition,true)
		await process_frame
		check(visual.skin_shader!=null,"profile shader builds for %s"%definition.id)
		check(visual.motes.size()>=5,"visible motes build for %s"%definition.id)
		check(visual.get_meta("visual_id","")==definition.id,"visual identity is retained for %s"%definition.id)
		if visual.skin_shader!=null:shader_profiles[visual.skin_shader.code]=true
		visual.queue_free()
	await process_frame
	check(shader_profiles.size()>=7,"ten forms resolve to at least seven authored shader profiles")
	var result:={"checks":checks,"failures":failures,"skins":definitions.size(),"shader_profiles":shader_profiles.size()}
	print("SKIN_FX_ACCEPTANCE "+JSON.stringify(result))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var out:=FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE);out.store_string(JSON.stringify(result,"\t")+"\n")
	quit(0 if failures.is_empty() else 1)
