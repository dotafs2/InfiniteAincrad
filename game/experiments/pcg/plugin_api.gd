extends SceneTree

func _initialize() -> void:
	var report := {}
	for kind in ["Terrain3D", "Terrain3DData", "Terrain3DAssets", "Terrain3DMaterial", "Terrain3DTextureAsset"]:
		report[kind] = {"properties":ClassDB.class_get_property_list(kind, true), "methods":ClassDB.class_get_method_list(kind, true)}
	var file := FileAccess.open("res://../private/pcg-trial-20260916/plugin-api.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report))
	file.close()
	quit()
