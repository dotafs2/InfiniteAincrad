extends "res://spatial/living_quarter.gd"
## Adapter only: existing map -> Terrain3D, Road Generator and ProtonScatter.
## All distribution, projection, road meshing and terrain rendering belong to the plugins.
const RandomFill = preload("res://addons/proton_scatter/src/modifiers/create_inside_random.gd")
const Jitter = preload("res://addons/proton_scatter/src/modifiers/randomize_transforms.gd")
const ProjectGround = preload("res://addons/proton_scatter/src/modifiers/project_on_geometry.gd")
const NEW_ASSETS := "res://assets/floor1/pcg_20260916/"
var asset_root := NEW_ASSETS
var terrain: Terrain3D
var road_manager: RoadManager
var scatter_nodes: Array[ProtonScatter] = []
var scatter_complete := 0
var scatter_expected := 0
var pcg_ready := false
var pcg_report := {"seed":91627,"plugins":["Terrain3D 1.0.2","Road Generator 0.9.3","ProtonScatter"],"scatter":[],"road_segments":0}

func build() -> void:
	super.build()
	_build_plugin_roads()
	_start_scatter.call_deferred()

func _build_surface() -> void:
	# Reuse the established map collider/navigation source. Terrain3D renders the
	# same heights; this experiment does not migrate the saved world's physics.
	super._build_surface()
	var original: MeshInstance3D = get_node("ContinuousValleyTerrain")
	original.visible = false
	(original.get_child(0) as StaticBody3D).collision_layer = 3
	terrain = Terrain3D.new()
	terrain.name = "PCG_Terrain3D"
	terrain.collision_mode = 0
	terrain.mesh_size = 48
	terrain.vertex_spacing = 1.0
	add_child(terrain)
	terrain.material.world_background = 0
	terrain.material.auto_shader = false
	var grain := FastNoiseLite.new()
	grain.seed = 91627
	grain.frequency = 0.17
	var albedo := Image.create(256,256,false,Image.FORMAT_RGBA8)
	var normal := Image.create(256,256,false,Image.FORMAT_RGBA8)
	normal.fill(Color(.5,.5,1,.96))
	for z in 256:
		for x in 256:
			var tone := .88 + grain.get_noise_2d(x,z)*.10
			albedo.set_pixel(x,z,Color(tone,tone,tone,.5))
	albedo.generate_mipmaps()
	normal.generate_mipmaps()
	var asset := Terrain3DTextureAsset.new()
	asset.name = "PCG meadow ground"
	asset.albedo_texture = ImageTexture.create_from_image(albedo)
	asset.normal_texture = ImageTexture.create_from_image(normal)
	asset.uv_scale = .65
	terrain.assets.set_texture(0,asset)
	var heights := Image.create(512,512,false,Image.FORMAT_RF)
	var colors := Image.create(512,512,false,Image.FORMAT_RGBA8)
	for z in 512:
		for x in 512:
			var wx := x-256
			var wz := z-256
			heights.set_pixel(x,z,Color(_map_height(wx,wz),0,0))
			var tint := Color("6b8841").lerp(Color("859452"),grain.get_noise_2d(wx*.12,wz*.12)*.5+.5)
			if absf(wx)<145 and wz>-135 and wz<185 and _paved(wx,wz): tint=Color("91836a")
			colors.set_pixel(x,z,tint)
	var maps: Array[Image] = [heights,null,colors]
	terrain.data.import_images(maps,Vector3(-256,0,-256))
	pcg_report["terrain_height_source"] = LAYOUT_PATH
	pcg_report["terrain_physics"] = "existing map collider retained; Terrain3D collision migration not evaluated"

func _map_height(x: float, z: float) -> float:
	# Sample the existing triangle grid exactly at the new heightmap's vertices.
	var x0 := floorf(x/2.0)*2.0
	var z0 := floorf(z/2.0)*2.0
	var u := (x-x0)*.5
	var v := (z-z0)*.5
	if u+v<=1.0:
		return height_at(x0,z0)*(1-u-v)+height_at(x0+2,z0)*u+height_at(x0,z0+2)*v
	return height_at(x0+2,z0)*(1-v)+height_at(x0,z0+2)*(1-u)+height_at(x0+2,z0+2)*(u+v-1)

func _landscape() -> void:
	# The old trees and shrubs are intentionally absent in this comparison.
	pass

func _asset(path: String, at: Vector3, height: float, yaw: float = 0) -> Node3D:
	if path.ends_with("F1_herb_planter.glb"): return null
	return super._asset(path,at,height,yaw)

func _build_plugin_roads() -> void:
	road_manager = RoadManager.new()
	road_manager.name = "PCG_RoadGenerator"
	road_manager.auto_refresh = false
	road_manager.density = 1.0
	# Keep the map's continuous walk surface, avoiding duplicate navigation layers.
	road_manager.collision_layer = 0
	road_manager.collision_mask = 0
	var shader := Shader.new()
	shader.code = """shader_type spatial;
varying vec3 road_world;
void vertex(){ road_world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment(){
 vec2 p=road_world.xz*vec2(2.0,2.8);
 p.x+=mod(floor(p.y),2.0)*0.5;
 vec2 grid=fract(p); vec2 tile=floor(p);
 float value=fract(sin(dot(tile,vec2(127.1,311.7)))*43758.5453);
 float gap=smoothstep(0.035,0.085,min(min(grid.x,1.0-grid.x),min(grid.y,1.0-grid.y)));
 ALBEDO=mix(vec3(.09,.085,.065),mix(vec3(.18,.15,.11),vec3(.31,.27,.20),value),gap);
 ROUGHNESS=.96;
}"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	road_manager.material_resource = mat
	add_child(road_manager)
	for index in layout.roads.size():
		var description: Dictionary = layout.roads[index]
		var container := RoadContainer.new()
		container.name = "ExistingRoute_%02d" % index
		container.generate_ai_lanes = false
		container.underside_thickness = 0.0
		road_manager.add_child(container)
		# Apply the manager's public batch-edit setting to the newly added container.
		road_manager.auto_refresh = false
		var samples: Array[Vector3] = []
		for i in range(description.points.size()-1):
			var a := Vector2(description.points[i][0],description.points[i][1])
			var b := Vector2(description.points[i+1][0],description.points[i+1][1])
			var count := maxi(1,ceili(a.distance_to(b)/4.0))
			for n in count:
				var p := a.lerp(b,float(n)/count)
				samples.append(Vector3(p.x,_map_height(p.x,p.y)+.025+index*.003,p.y))
		var last: Array = description.points[-1]
		samples.append(Vector3(last[0],_map_height(last[0],last[1])+.025+index*.003,last[1]))
		var points: Array[RoadPoint] = []
		for n in samples.size():
			var point := RoadPoint.new()
			point.name = "P%03d" % n
			point.auto_lanes = false
			point.traffic_dir = [RoadPoint.LaneDir.NONE]
			point.lanes = [RoadPoint.LaneType.NO_MARKING]
			point.lane_width = description.width
			point.shoulder_width_l = 0
			point.shoulder_width_r = 0
			point.gutter_profile = Vector2.ZERO
			point.position = samples[n]
			var tangent: Vector3 = samples[mini(n+1,samples.size()-1)]-samples[maxi(n-1,0)]
			point.basis = Basis.looking_at(tangent.normalized(),Vector3.UP,true)
			point.prior_mag = samples[n].distance_to(samples[maxi(n-1,0)])*.22
			point.next_mag = samples[n].distance_to(samples[mini(n+1,samples.size()-1)])*.22
			container.add_child(point)
			points.append(point)
		for n in range(points.size()-1):
			points[n].connect_roadpoint(RoadPoint.PointInit.NEXT,points[n+1],RoadPoint.PointInit.PRIOR)
		container.rebuild_segments(true)
		pcg_report.road_segments += points.size()-1
	pcg_report["road_containers"] = []
	for container: RoadContainer in road_manager.get_containers():
		pcg_report.road_containers.append({"name":container.name,"generated_segments":container.get_segments().size()})

func _shape(scatter: ProtonScatter, center: Vector3, size: Vector3, negative: bool, yaw := 0.0) -> void:
	var node := ProtonScatterShape.new()
	var box := ProtonScatterBoxShape.new()
	box.size = size
	node.shape = box
	node.negative = negative
	node.position = center
	node.rotation.y = yaw
	scatter.add_child(node)

func _exclusions(scatter: ProtonScatter, margin: float) -> void:
	for house in layout.houses+layout.infill:
		_shape(scatter,Vector3(house.at[0],0,house.at[2]),Vector3(15+margin*2,100,15+margin*2),true)
	for road in layout.roads:
		for i in range(road.points.size()-1):
			var a := Vector3(road.points[i][0],0,road.points[i][1])
			var b := Vector3(road.points[i+1][0],0,road.points[i+1][1])
			var d := b-a
			_shape(scatter,(a+b)*.5,Vector3(road.width+margin*2,100,d.length()+margin*2),true,atan2(d.x,d.z))
	for at in [Vector3(2.5,0,14.5),Vector3(-20.8,0,40),Vector3(0,0,53),Vector3(25.9,0,72.9)]:
		_shape(scatter,at,Vector3(16+margin*2,100,16+margin*2),true)
	# Saved gathering ring and waiting seats remain clear.
	_shape(scatter,Vector3(7,0,53),Vector3(12,100,12),true)
	_shape(scatter,Vector3(34,0,70),Vector3(9,100,9),true)

func _scatter(asset_id: String, count: int, center: Vector3, size: Vector3, margin: float, solid: bool, seed_offset: int) -> ProtonScatter:
	if OS.get_cmdline_user_args().has("--pcg-available-assets") and not ResourceLoader.exists(asset_root+asset_id+".tscn"):
		pcg_report["partial_asset_preview"] = true
		return null
	var scatter := ProtonScatter.new()
	scatter.name = "PCG_"+asset_id.replace("-","_")+str(seed_offset)
	scatter.global_seed = 91627+seed_offset
	scatter.render_mode = 1 if solid else 0
	scatter.use_chunks = true
	scatter.chunk_dimensions = Vector3(24,48,24)
	scatter.force_rebuild_on_load = false
	scatter.dbg_disable_thread = true
	var stack := ProtonScatterModifierStack.new()
	var fill := RandomFill.new()
	fill.amount = count
	fill.restrict_height = true
	stack.add(fill)
	var jitter := Jitter.new()
	jitter.rotation = Vector3(0,180,0)
	jitter.scale = Vector3.ONE*.24
	stack.add(jitter)
	var projection := ProjectGround.new()
	projection.collision_mask = 2
	projection.ray_offset = 80
	projection.ray_length = 160
	projection.max_slope = 32 if solid else 42
	projection.align_with_collision_normal = not solid
	stack.add(projection)
	scatter.modifier_stack = stack
	var item := ProtonScatterItem.new()
	item.path = asset_root+asset_id+".tscn"
	item.source_ignore_scale = false
	item.source_ignore_position = false
	if asset_id in ["meadow-grass", "simple-grass"]: item.override_cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scatter.add_child(item)
	_shape(scatter,center,size,false)
	_exclusions(scatter,margin)
	scatter.build_completed.connect(_scatter_done.bind(scatter,asset_id,count),CONNECT_ONE_SHOT)
	scatter_expected += 1
	scatter_nodes.append(scatter)
	add_child(scatter)
	return scatter

func _start_scatter() -> void:
	for frame in 3: await get_tree().physics_frame
	if OS.get_cmdline_user_args().has("--pcg-structure-only"):
		pcg_ready = true
		return
	var forest_left := Vector3(-76,0,25)
	var forest_right := Vector3(76,0,25)
	var forest_size := Vector3(65,1,210)
	_scatter("elm-tree",65,forest_left,forest_size,3.5,true,1)
	_scatter("elm-tree",65,forest_right,forest_size,3.5,true,2)
	_scatter("birch-tree",45,Vector3(0,0,118),Vector3(175,1,52),3,true,3)
	_scatter("leafy-shrub",170,Vector3(0,0,28),Vector3(185,1,218),1.5,true,4)
	_scatter("meadow-grass",13500,Vector3(0,0,28),Vector3(190,1,218),.65,false,5)
	_scatter("wildflowers",950,Vector3(0,0,28),Vector3(175,1,210),.8,false,6)
	_scatter("fern",500,Vector3(0,0,28),Vector3(190,1,220),1.0,false,7)
	# Narrow verge strips beside the established street: separate props, clear road.
	_scatter("market-barrel",13,Vector3(-8,0,-12),Vector3(5,1,77),.15,true,8)
	_scatter("produce-crate",13,Vector3(8,0,-12),Vector3(5,1,77),.15,true,9)
	for scatter in scatter_nodes:
		scatter.full_rebuild()
		await scatter.build_completed
	pcg_ready = scatter_complete == scatter_expected
	print("PCG_READY ",JSON.stringify(pcg_report))

func _scatter_done(scatter: ProtonScatter, asset_id: String, requested: int) -> void:
	scatter_complete += 1
	var transforms: Array = []
	if scatter.transforms != null:
		for t: Transform3D in scatter.transforms.list:
			transforms.append([snappedf(t.origin.x,.001),snappedf(t.origin.y,.001),snappedf(t.origin.z,.001)])
	pcg_report.scatter.append({"asset":asset_id,"requested":requested,"placed":transforms.size(),"seed":scatter.global_seed,
		"render":"independent_nodes" if scatter.render_mode==1 else "chunked_multimesh","positions":transforms})
