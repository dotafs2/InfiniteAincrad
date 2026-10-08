extends SceneTree
## Independent exported-resource inventory; invoke externally with an isolated --main-pack.
var records:Dictionary={}
func scan(path:String)->void:
	for file in DirAccess.get_files_at(path):
		var resource:String=path.path_join(file)
		records[resource]=FileAccess.get_sha256(resource)
	for child in DirAccess.get_directories_at(path):scan(path.path_join(child))
func _initialize()->void:
	scan("res://")
	var output:String=OS.get_cmdline_user_args()[0]
	var file:=FileAccess.open(output,FileAccess.WRITE)
	if not file:push_error("Cannot save package manifest");quit(2);return
	file.store_string(JSON.stringify(records,"  "))
	print("PACKAGED_RESOURCE_MANIFEST ",records.size()," resources")
	quit()
