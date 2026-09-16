extends "res://experiments/pcg/quarter.gd"
## Small first pass: upstream assets, native scatter modifiers, existing terrain.

func _start_scatter() -> void:
	asset_root = "res://assets/floor1/pcg_native/"
	pcg_report.plugins.append_array(["EZ-Tree 0.2.0", "SimpleGrassTextured 2.1.0"])
	pcg_report["scope"] = "first grass and PBR tree placement; copied paused world; no paid calls"
	for frame in 3: await get_tree().physics_frame
	if OS.get_cmdline_user_args().has("--pcg-structure-only"):
		pcg_ready = true
		return
	_scatter("ez-oak",22,Vector3(-54,0,6),Vector3(46,1,115),3.5,true,31)
	_scatter("ez-small-oak",16,Vector3(53,0,34),Vector3(36,1,110),3.5,true,32)
	_scatter("ez-oak",12,Vector3(0,0,117),Vector3(126,1,26),3.5,true,33)
	_scatter("simple-grass",12000,Vector3(-47,0,12),Vector3(62,1,130),.70,false,34)
	_scatter("simple-grass",8500,Vector3(44,0,28),Vector3(55,1,126),.70,false,35)
	_scatter("simple-grass",3600,Vector3(0,0,-34),Vector3(58,1,34),.70,false,36)
	for scatter in scatter_nodes:
		scatter.full_rebuild()
		await scatter.build_completed
	pcg_report["grass_rendering"] = "upstream crossed mesh + CC0 texture + wind shader, ProtonScatter chunked MultiMesh"
	pcg_report["trees"] = "EZ-Tree native PBR bark and lit textured leaves; trunk colliders"
	pcg_report["paid_calls"] = 0
	pcg_ready = scatter_complete == scatter_expected
	print("PCG_NATIVE_READY counts=", scatter_complete, "/", scatter_expected)
