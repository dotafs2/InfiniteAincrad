extends SceneTree
## Non-author rarity and probability review, independent of the game/save/UI.
const Catalog=preload("res://fidelity/skin_catalog.gd")
const Rarity=preload("res://fidelity/skin_rarity.gd")
const Visual=preload("res://fidelity/skin_visual.gd")
const CommonSurface=preload("res://fidelity/common_surface.gdshader")
const Draw=preload("res://fidelity/skin_draw.gd")
const TIERS=["common","uncommon","rare","epic","legendary","prismatic"]
const WEIGHTS=[4500,2800,1600,800,250,50]
const APPENDED_IDS:=["tempest","rainfall","paper_boat","toy_tire","leaf_cup","wooden_tub","rope_coil","clay_pot","shell_cup","woven_nest","paint_tin","denim_pocket","catchers_mitt","enamel_basin","acorn_cup","knit_cap","plain_loop","button_wheel","pocket_arcade","sakura_pavilion","clockwork_orbit","phoenix_nest","crystal_crown","aurora_rift","core_shell__solar_core","copper_ring__verdigris","moss_bloom__autumn_bloom","gravitas__marble_gold","lantern__festival_rose","shard__amethyst_shards","cinder__azure_flame","tide__rosewater","orbit__golden_nebula","prism_vale__dawn_veil","sunny_side__moonlight","sunny_side__mint_cream","sunny_side__peach_glow","sugar_glaze__blueberry","sugar_glaze__pistachio","sugar_glaze__cocoa_icing","berry_crown__blackcurrant","berry_crown__strawberry_cream","berry_crown__golden_berry","citrus_slice__ruby_orange","citrus_slice__lime_slice","melon_munch__golden_melon","melon_munch__honeydew","pretzel_twist__dark_rye","pretzel_twist__sea_salt","pretzel_twist__cinnamon","popcorn_pot__caramel_cinema","popcorn_pot__blue_matinee","popcorn_pot__plum_premiere","pizza_party__pesto_party","pizza_party__spicy_fiesta","pizza_party__truffle_night","cookie_bite__double_cocoa","cookie_bite__red_velvet","waffle_stack__cocoa_waffle","waffle_stack__berry_syrup","waffle_stack__matcha_waffle","pancake_stack__blueberry_stack","pancake_stack__cocoa_stack","bacon_curl__maple_crisp","bacon_curl__pepper_crisp","cocoa_square__basalt","cocoa_square__sandstone","cocoa_square__rose_quartz","frosted_cake__blueberry_cake","frosted_cake__lemon_cake","frosted_cake__matcha_cake","pineapple_top__sunset_pineapple","pineapple_top__silver_pineapple","pineapple_top__ruby_pineapple","crab_cove__blue_crab","crab_cove__golden_crab","crab_cove__rose_crab","fox_den__arctic_fox","fox_den__dusky_fox","fox_den__fennec_fox","bunny_burrow__honey_bunny","bunny_burrow__blue_bunny","bunny_burrow__cocoa_bunny","frog_pond__blue_pond","frog_pond__golden_reed","frog_pond__lilac_pond","owl_hollow__snow_owl","owl_hollow__copper_owl","owl_hollow__moss_owl","turtle_shell__lagoon","turtle_shell__amber_shell","turtle_shell__midnight_shell","snail_trail__coral_snail","snail_trail__lavender_snail","snail_trail__lemon_snail","clockwork_key__rose_brass","clockwork_key__steel_blue","clockwork_key__black_nickel","royal_gate__rose_palace","satellite_dish__copper_signal","carnival_tent__midnight_circus","rocket_port__solar_rocket","rainbow_bridge__opal_bridge","storm_cloud__sunset_storm","dragon_roost__jade_dragon","jelly_veil__golden_jelly","moon_dream__rose_moon","moon_dream__golden_moon","moon_dream__ice_moon","coral_reef__lavender_reef","coral_reef__lagoon_reef","coral_reef__sunrise_reef","music_stage__jazz_night","music_stage__pop_neon","music_stage__blue_session","tempest__cobalt_storm","rainfall__rose_rain","paper_boat__blue_print","paper_boat__rose_letter","toy_tire__rally_red","toy_tire__ice_track","leaf_cup__autumn_leaf","leaf_cup__frost_leaf","wooden_tub__cedar","wooden_tub__white_oak","rope_coil__blue_mariner","rope_coil__terracotta_cord","clay_pot__olive_glaze","clay_pot__azure_glaze","shell_cup__rose_shell","shell_cup__pearl_tide","woven_nest__willow_nest","woven_nest__rose_willow","paint_tin__sunflower_paint","paint_tin__berry_paint","denim_pocket__indigo_denim","denim_pocket__washed_rose","catchers_mitt__chocolate_leather","catchers_mitt__navy_leather","enamel_basin__mint_enamel","enamel_basin__apricot_enamel","acorn_cup__chestnut","acorn_cup__forest_acorn","knit_cap__seaside_knit","knit_cap__mustard_knit","plain_loop__coral","plain_loop__sea_glass","plain_loop__night_ink","button_wheel__teal_button","button_wheel__lilac_button","pocket_arcade__berry_arcade","sakura_pavilion__moon_pavilion","clockwork_orbit__silver_mechanism","phoenix_nest__frost_phoenix","crystal_crown__emerald_crown","aurora_rift__solar_rift"]
const APPENDED_RESONANCE:=["tempest","rainfall","copper_ring__verdigris","moss_bloom__autumn_bloom","gravitas__marble_gold","lantern__festival_rose","shard__amethyst_shards","clockwork_key__rose_brass","clockwork_key__steel_blue","clockwork_key__black_nickel","royal_gate__rose_palace","satellite_dish__copper_signal","carnival_tent__midnight_circus","rocket_port__solar_rocket","rainbow_bridge__opal_bridge","storm_cloud__sunset_storm","dragon_roost__jade_dragon","jelly_veil__golden_jelly","moon_dream__rose_moon","moon_dream__golden_moon","moon_dream__ice_moon","coral_reef__lavender_reef","coral_reef__lagoon_reef","coral_reef__sunrise_reef","music_stage__jazz_night","music_stage__pop_neon","music_stage__blue_session","tempest__cobalt_storm","rainfall__rose_rain"]
const BASELINE:={"core_shell":{"id":"core_shell","group":"foundation","legacy_score":0,"kind":"cosmetic","cooldown":0.0},"copper_ring":{"id":"copper_ring","group":"resonance","legacy_score":25,"kind":"draw","cooldown":8.0},"moss_bloom":{"id":"moss_bloom","group":"resonance","legacy_score":70,"kind":"bloom","cooldown":12.0},"gravitas":{"id":"gravitas","group":"resonance","legacy_score":120,"kind":"thrum","cooldown":12.0},"lantern":{"id":"lantern","group":"resonance","legacy_score":180,"kind":"speed","cooldown":9.0},"shard":{"id":"shard","group":"resonance","legacy_score":240,"kind":"sweep","cooldown":11.0},"cinder":{"id":"cinder","group":"foundation","legacy_score":300,"kind":"cosmetic","cooldown":0.0},"tide":{"id":"tide","group":"foundation","legacy_score":340,"kind":"cosmetic","cooldown":0.0},"orbit":{"id":"orbit","group":"foundation","legacy_score":380,"kind":"cosmetic","cooldown":0.0},"prism_vale":{"id":"prism_vale","group":"foundation","legacy_score":420,"kind":"cosmetic","cooldown":0.0},"sunny_side":{"id":"sunny_side","group":"foundation","legacy_score":2147483647,"kind":"cosmetic","cooldown":0.0},"sugar_glaze":{"id":"sugar_glaze","group":"foundation","legacy_score":2147483647,"kind":"cosmetic","cooldown":0.0},"berry_crown":{"id":"berry_crown","group":"foundation","legacy_score":2147483647,"kind":"cosmetic","cooldown":0.0},"citrus_slice":{"id":"citrus_slice","group":"foundation","legacy_score":2147483647,"kind":"cosmetic","cooldown":0.0},"melon_munch":{"id":"melon_munch","group":"foundation","legacy_score":2147483647,"kind":"cosmetic","cooldown":0.0},"pretzel_twist":{"id":"pretzel_twist","group":"foundation","legacy_score":2147483647,"kind":"cosmetic","cooldown":0.0},"popcorn_pot":{"id":"popcorn_pot","group":"foundation","legacy_score":2147483647,"kind":"cosmetic","cooldown":0.0},"pizza_party":{"id":"pizza_party","group":"foundation","legacy_score":2147483647,"kind":"cosmetic","cooldown":0.0},"cookie_bite":{"id":"cookie_bite","group":"foundation","legacy_score":2147483647,"kind":"cosmetic","cooldown":0.0},"waffle_stack":{"id":"waffle_stack","group":"foundation","legacy_score":2147483647,"kind":"cosmetic","cooldown":0.0},"pancake_stack":{"id":"pancake_stack","group":"foundation","legacy_score":2147483647,"kind":"cosmetic","cooldown":0.0},"bacon_curl":{"id":"bacon_curl","group":"foundation","legacy_score":2147483647,"kind":"cosmetic","cooldown":0.0},"cocoa_square":{"id":"cocoa_square","group":"foundation","legacy_score":2147483647,"kind":"cosmetic","cooldown":0.0},"frosted_cake":{"id":"frosted_cake","group":"foundation","legacy_score":2147483647,"kind":"cosmetic","cooldown":0.0},"pineapple_top":{"id":"pineapple_top","group":"foundation","legacy_score":2147483647,"kind":"cosmetic","cooldown":0.0},"crab_cove":{"id":"crab_cove","group":"foundation","legacy_score":2147483647,"kind":"cosmetic","cooldown":0.0},"fox_den":{"id":"fox_den","group":"foundation","legacy_score":2147483647,"kind":"cosmetic","cooldown":0.0},"bunny_burrow":{"id":"bunny_burrow","group":"foundation","legacy_score":2147483647,"kind":"cosmetic","cooldown":0.0},"frog_pond":{"id":"frog_pond","group":"foundation","legacy_score":2147483647,"kind":"cosmetic","cooldown":0.0},"owl_hollow":{"id":"owl_hollow","group":"foundation","legacy_score":2147483647,"kind":"cosmetic","cooldown":0.0},"turtle_shell":{"id":"turtle_shell","group":"foundation","legacy_score":2147483647,"kind":"cosmetic","cooldown":0.0},"snail_trail":{"id":"snail_trail","group":"foundation","legacy_score":2147483647,"kind":"cosmetic","cooldown":0.0},"clockwork_key":{"id":"clockwork_key","group":"resonance","legacy_score":2147483647,"kind":"cosmetic","cooldown":0.0},"royal_gate":{"id":"royal_gate","group":"resonance","legacy_score":2147483647,"kind":"cosmetic","cooldown":0.0},"satellite_dish":{"id":"satellite_dish","group":"resonance","legacy_score":2147483647,"kind":"cosmetic","cooldown":0.0},"carnival_tent":{"id":"carnival_tent","group":"resonance","legacy_score":2147483647,"kind":"cosmetic","cooldown":0.0},"rocket_port":{"id":"rocket_port","group":"resonance","legacy_score":2147483647,"kind":"cosmetic","cooldown":0.0},"rainbow_bridge":{"id":"rainbow_bridge","group":"resonance","legacy_score":2147483647,"kind":"cosmetic","cooldown":0.0},"storm_cloud":{"id":"storm_cloud","group":"resonance","legacy_score":2147483647,"kind":"cosmetic","cooldown":0.0},"dragon_roost":{"id":"dragon_roost","group":"resonance","legacy_score":2147483647,"kind":"cosmetic","cooldown":0.0},"jelly_veil":{"id":"jelly_veil","group":"resonance","legacy_score":2147483647,"kind":"cosmetic","cooldown":0.0},"moon_dream":{"id":"moon_dream","group":"resonance","legacy_score":2147483647,"kind":"cosmetic","cooldown":0.0},"coral_reef":{"id":"coral_reef","group":"resonance","legacy_score":2147483647,"kind":"cosmetic","cooldown":0.0},"music_stage":{"id":"music_stage","group":"resonance","legacy_score":2147483647,"kind":"cosmetic","cooldown":0.0}}
const ACTIVE_SKILLS:={"copper_ring":{"id":"copper_ring","name":"Copper Ring","group":"resonance","legacy_score":25,"tint":"e58a37","accent":"ffe9a6","skill_name":"COPPER DRAW","skill_short":"DRAW","skill_desc":"Pull up to five nearby objects in one copper pulse.","play_desc":"Use the copper band beside a tight cluster, then let gravity finish.","cooldown":8.0,"kind":"draw"},"moss_bloom":{"id":"moss_bloom","name":"Moss Bloom","group":"resonance","legacy_score":70,"tint":"25c96a","accent":"b2ff60","skill_name":"BLOOM CATCH","skill_short":"BLOOM","skill_desc":"Living leaves catch up to three nearby objects every 12 seconds.","play_desc":"Keep moving near props; the green catch happens by itself.","cooldown":12.0,"kind":"bloom"},"gravitas":{"id":"gravitas","name":"Gravitas","group":"resonance","legacy_score":120,"tint":"5d5478","accent":"ffbe39","skill_name":"GROUND THRUM","skill_short":"THRUM","skill_desc":"Gravity thrum vibrates every nearby building and shifts it slightly.","play_desc":"Trigger the weighted ring beside a cluster before swallowing the heap.","cooldown":12.0,"kind":"thrum"},"lantern":{"id":"lantern","name":"Lantern","group":"resonance","legacy_score":180,"tint":"ffb32b","accent":"fff3a1","skill_name":"BEACON STEP","skill_short":"STEP","skill_desc":"Beacon glow gives a short speed surge for repositioning.","play_desc":"Tap SKILL, then steer the warm signal across open ground.","cooldown":9.0,"kind":"speed"},"shard":{"id":"shard","name":"Shard","group":"resonance","legacy_score":240,"tint":"24baff","accent":"e0ffff","skill_name":"SHARD SWEEP","skill_short":"SWEEP","skill_desc":"Ice-blue crystals sweep up to eight objects from a wider area.","play_desc":"Use the shard ring at the edge of a pile and let objects fall.","cooldown":11.0,"kind":"sweep"}}
const OLD_VISUAL:={"bacon_curl":{"meshes":10,"motes":0,"parts":0,"triangles":1824,"visible":9},"berry_crown":{"meshes":12,"motes":0,"parts":0,"triangles":2296,"visible":11},"bunny_burrow":{"meshes":11,"motes":0,"parts":0,"triangles":3276,"visible":10},"carnival_tent":{"meshes":12,"motes":0,"parts":0,"triangles":1620,"visible":11},"cinder":{"meshes":14,"motes":10,"parts":0,"triangles":1844,"visible":13},"citrus_slice":{"meshes":11,"motes":0,"parts":0,"triangles":2208,"visible":10},"clockwork_key":{"meshes":11,"motes":0,"parts":0,"triangles":2544,"visible":10},"cocoa_square":{"meshes":10,"motes":0,"parts":0,"triangles":1632,"visible":9},"cookie_bite":{"meshes":13,"motes":0,"parts":0,"triangles":2592,"visible":12},"copper_ring":{"meshes":9,"motes":0,"parts":6,"triangles":2376,"visible":8},"coral_reef":{"meshes":6,"motes":0,"parts":0,"triangles":1776,"visible":5},"core_shell":{"meshes":4,"motes":0,"parts":0,"triangles":2976,"visible":3},"crab_cove":{"meshes":14,"motes":0,"parts":0,"triangles":2232,"visible":13},"dragon_roost":{"meshes":8,"motes":0,"parts":0,"triangles":2136,"visible":7},"fox_den":{"meshes":11,"motes":0,"parts":0,"triangles":2276,"visible":10},"frog_pond":{"meshes":8,"motes":0,"parts":0,"triangles":2160,"visible":7},"frosted_cake":{"meshes":10,"motes":0,"parts":0,"triangles":3132,"visible":9},"gravitas":{"meshes":8,"motes":0,"parts":6,"triangles":1608,"visible":7},"jelly_veil":{"meshes":9,"motes":0,"parts":6,"triangles":2088,"visible":8},"lantern":{"meshes":15,"motes":5,"parts":8,"triangles":1626,"visible":14},"melon_munch":{"meshes":11,"motes":0,"parts":0,"triangles":2640,"visible":10},"moon_dream":{"meshes":6,"motes":0,"parts":0,"triangles":1684,"visible":5},"moss_bloom":{"meshes":14,"motes":0,"parts":12,"triangles":1600,"visible":13},"music_stage":{"meshes":13,"motes":0,"parts":0,"triangles":2460,"visible":12},"orbit":{"meshes":4,"motes":0,"parts":0,"triangles":2976,"visible":3},"owl_hollow":{"meshes":9,"motes":0,"parts":0,"triangles":2136,"visible":8},"pancake_stack":{"meshes":6,"motes":0,"parts":0,"triangles":2700,"visible":5},"pineapple_top":{"meshes":13,"motes":0,"parts":0,"triangles":1648,"visible":12},"pizza_party":{"meshes":15,"motes":0,"parts":0,"triangles":3000,"visible":14},"popcorn_pot":{"meshes":13,"motes":0,"parts":0,"triangles":3048,"visible":12},"pretzel_twist":{"meshes":8,"motes":0,"parts":0,"triangles":2724,"visible":7},"prism_vale":{"meshes":10,"motes":0,"parts":6,"triangles":1872,"visible":9},"rainbow_bridge":{"meshes":7,"motes":0,"parts":0,"triangles":2508,"visible":6},"rocket_port":{"meshes":8,"motes":0,"parts":0,"triangles":2116,"visible":7},"royal_gate":{"meshes":13,"motes":0,"parts":0,"triangles":3300,"visible":12},"satellite_dish":{"meshes":11,"motes":0,"parts":0,"triangles":1776,"visible":10},"shard":{"meshes":11,"motes":0,"parts":9,"triangles":1608,"visible":10},"snail_trail":{"meshes":10,"motes":0,"parts":0,"triangles":2904,"visible":9},"storm_cloud":{"meshes":8,"motes":0,"parts":0,"triangles":3000,"visible":7},"sugar_glaze":{"meshes":9,"motes":0,"parts":0,"triangles":1992,"visible":8},"sunny_side":{"meshes":8,"motes":0,"parts":0,"triangles":3120,"visible":7},"tide":{"meshes":5,"motes":0,"parts":0,"triangles":1632,"visible":4},"turtle_shell":{"meshes":13,"motes":0,"parts":0,"triangles":3840,"visible":12},"waffle_stack":{"meshes":14,"motes":0,"parts":0,"triangles":1680,"visible":13}}
## Six explicitly rebuilt cosmetic forms; the other 38 retain the old oracle.
const POLISHED_VISUAL:={"bunny_burrow":{"meshes":12,"motes":0,"parts":0,"triangles":2768,"visible":11},"dragon_roost":{"meshes":13,"motes":0,"parts":0,"triangles":2880,"visible":12},"fox_den":{"meshes":12,"motes":0,"parts":0,"triangles":2668,"visible":11},"frosted_cake":{"meshes":11,"motes":0,"parts":0,"triangles":3132,"visible":10},"pizza_party":{"meshes":12,"motes":0,"parts":0,"triangles":3044,"visible":11},"rocket_port":{"meshes":12,"motes":0,"parts":0,"triangles":2928,"visible":11}}
var checks:=0
var failures:Array[String]=[]
var visual_rows:Array=[]
var probability_rows:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func counts(model:Node3D)->Dictionary:
	var result:={"visible":0,"meshes":0,"triangles":0,"motes":model.motes.size(),"parts":model.parts.size()}
	for node in model.find_children("*","MeshInstance3D",true,false):
		result.meshes+=1
		if node.visible:result.visible+=1
		if node.mesh==null:
			check(not node.visible,"Empty pooled view remains hidden");continue
		for index in node.mesh.get_surface_count():
			var a:Array=node.mesh.surface_get_arrays(index)
			result.triangles+=(a[Mesh.ARRAY_INDEX].size() if a[Mesh.ARRAY_INDEX]!=null and not a[Mesh.ARRAY_INDEX].is_empty() else a[Mesh.ARRAY_VERTEX].size())/3
	return result
func visuals()->void:
	var found:Dictionary={};var low_count:=0;var low_triangles:=0;var high_triangles:=0
	var model:=Visual.new();root.add_child(model);model.set_process(false)
	for definition in Catalog.DEFS:
		var id:String=definition.id;found[id]=true
		check(BASELINE.has(id) or APPENDED_IDS.has(id),"Current skin retains a known saved ID: "+id)
		if not BASELINE.has(id):continue
		var same:=true
		for field in BASELINE[id]:same=same and definition.get(field)==BASELINE[id][field]
		check(same,"Exact pre-rarity identity/group/legacy threshold/skill/cooldown retained: "+id)
		if ACTIVE_SKILLS.has(id):
			var skill_same:=true
			for field in ACTIVE_SKILLS[id]:skill_same=skill_same and definition.get(field)==ACTIVE_SKILLS[id][field]
			check(skill_same,"Every original active-skill field and instruction remains intact: "+id)
		check(TIERS.has(definition.rarity),"Skin belongs to one of the six explicit tiers: "+id)
		model.build(definition,false);var measured:=counts(model)
		check(model.mouth==null and model.find_children("*","CollisionObject3D",true,false).is_empty(),"Gameplay form preserves an actual open mouth and owns no collision: "+id)
		if definition.model_id in Visual.Common.IDS:
			check(is_instance_valid(model.common) and model.fx_family==id and model.model_id==id,"Authorized Common rework builds an authored model: "+id)
			var main_material:Material=model.main_ring.material_override
			if main_material==null and model.main_ring.mesh.get_surface_count()>0:main_material=model.main_ring.mesh.surface_get_material(0)
			check(main_material is ShaderMaterial and main_material.shader==CommonSurface and measured.meshes<=18 and measured.triangles<=4500,"Authored Common stays within the existing bounded lit-geometry budget: "+id)
		elif definition.model_id in Visual.SIMPLE_MODELS:
			low_count+=1;low_triangles+=int(measured.triangles)
			check(measured.triangles<int(OLD_VISUAL[id].triangles) and measured.visible<int(OLD_VISUAL[id].visible),"Low tier truly reduces geometry and visible pieces versus delivered v0.8.6: "+id)
			check(model.ornaments.get_child_count()==0 and measured.parts==0 and measured.motes==0,"Low tier has no old ornamental or animated payload hidden behind its label: "+id)
			var target:int=2
			check(measured.visible==target and measured.meshes==target+1 and not model.wave.visible,"Low tier has only its basic ring/trim and one reusable hidden feedback mesh: "+id)
			check(model.main_ring.mesh is TorusMesh and model.main_ring.mesh.rings==32,"Low tier actually uses the reduced ring tessellation: "+id)
			check(model.materials.size()==1 and model.main_ring.material_override.get_shader_parameter("style")==target-1,"Low tier selects static recolor or basic sheen on the actual material: "+id)
		else:
			high_triangles+=int(measured.triangles)
			if POLISHED_VISUAL.has(id):
				check(measured==POLISHED_VISUAL[id] and measured.meshes<=18 and measured.triangles<=4500,"Exactly six specified sculpted cosmetics use their new bounded geometry: "+id)
			else:
				check(measured==OLD_VISUAL[id],"Higher-tier geometry, parts and effect counts retain their prior authored form: "+id)
		if id in ["core_shell","tide","cinder"]:check(definition.rarity=="legendary","Signature black hole/water/fire are all Legendary: "+id)
		if id=="orbit":check(definition.rarity=="prismatic","Orbit retains the highest tier: "+id)
		if id in ["prism_vale","rainbow_bridge"]:check(definition.rarity=="legendary","Authorized grading places the two curtain/bridge models in Legendary: "+id)
		if id=="orbit":check(model.main_ring.material_override.get_shader_parameter("spectral")==1.0,"Orbit keeps its actual spectral accretion material")
		if id=="rainbow_bridge":check(model.main_ring.material_override.get_shader_parameter("style")==7,"Rainbow Bridge material uses the actual animated rainbow branch")
		var old_nodes:int=measured.meshes;model.flash();model._process(.4)
		check(model.wave.visible and counts(model).meshes==old_nodes,"Feedback animates existing geometry without allocating more: "+id)
		model.build(definition,false)
		check(counts(model)==measured and model.effect_time==0.0 and not model.wave.visible,"Rebuild preserves geometry budget and clears feedback: "+id)
		visual_rows.append({"id":id,"tier":definition.rarity,"before":OLD_VISUAL[id],"after":measured})
	check(Catalog.DEFS.size()==200 and found.size()==200 and BASELINE.keys().all(func(id):return found.has(id)),"All 44 existing saved skin IDs remain present exactly once")
	var first_sixty:=PackedStringArray()
	for d in Catalog.DEFS.slice(0,60):first_sixty.append("%s|%s|%s|%d|%s|%d"%[d.id,d.name,d.group,int(d.legacy_score),d.kind,int(d.cooldown)])
	check("\n".join(first_sixty).sha256_text()=="e13d9be6506a654aa4b2703eaca1c9dd083ee03e011b44e7c74c136e97dfb357","All first sixty identity/order/name/migration/gameplay fields match the preserved baseline; only rarity is regraded")
	check(low_count==8,"Eight original trim forms retain their original simplified construction")
	check(Rarity.ORDER==TIERS and Rarity.BASE_WEIGHTS==WEIGHTS,"Public tier order and integer weights match the six-tier product contract")
	model.free()
func fixture_catalog()->Array[Dictionary]:
	var result:Array[Dictionary]=[]
	for tier in TIERS:
		for index in 3:result.append({"id":tier+str(index),"rarity":tier,"group":"fixture"})
	return result
func expected(catalog:Array[Dictionary],owned:Array[String],group:String,counters:Dictionary)->Dictionary:
	var pools:Array=[[],[],[],[],[],[]]
	for definition in catalog:
		if definition.group==group and not owned.has(definition.id) and TIERS.has(definition.rarity):pools[TIERS.find(definition.rarity)].append(definition.id)
	var minimum:=0
	# Highest currently eligible guarantee wins. Thresholds count previous
	# misses; the fifth/tenth/twentieth draw itself is already guaranteed.
	for rank in [3,4,5]:
		var threshold:int={3:5,4:10,5:20}[rank]
		var possible:=false
		for index in range(rank,6):possible=possible or not pools[index].is_empty()
		if int(counters.get(TIERS[rank],0))>=threshold-1 and possible:minimum=rank
	var weights:Array=[];var total:=0
	for index in 6:
		var value:int=WEIGHTS[index] if index>=minimum and not pools[index].is_empty() else 0
		weights.append(value);total+=value
	return {"pools":pools,"weights":weights,"total":total,"floor":minimum}
func inspect_offer(catalog:Array[Dictionary],owned:Array[String],group:String,counters:Dictionary,label:String)->Dictionary:
	var truth:=expected(catalog,owned,group,counters);var offer:Dictionary=Draw.offer(catalog,owned,group,counters)
	check(offer.total_weight==truth.total and offer.entries.size()==6,label+": total ticket count and six disclosed rows match eligible independent pools")
	var correct:=true;var sum:=0.0
	for index in 6:
		var entry:Dictionary=offer.entries[index]
		var chance:float=float(truth.weights[index])/truth.total if truth.total>0 else 0.0
		correct=correct and entry.rarity==TIERS[index] and entry.ids==truth.pools[index] and entry.weight==truth.weights[index] and absf(float(entry.chance)-chance)<1e-12
		sum+=float(entry.chance)
	check(correct and is_equal_approx(sum,1.0 if truth.total>0 else 0.0),label+": disclosed normalized odds and every eligible ID are mathematically exact")
	if truth.total==0:check(Draw.choose(offer,.5,.5).is_empty(),label+": empty pool yields no invented or duplicate reward")
	else:
		var low:=Draw.choose(offer,0.0,0.0);var high:=Draw.choose(offer,1.0,1.0)
		check(not owned.has(low) and not owned.has(high) and catalog.any(func(d):return d.id==low and d.group==group) and catalog.any(func(d):return d.id==high and d.group==group),label+": endpoint rolls stay inside the disclosed unowned group")
	return offer
func probability()->void:
	var fixture:=fixture_catalog();var empty:Array[String]=[]
	var offer:=inspect_offer(fixture,empty,"fixture",{},"Complete six-tier fixture")
	var tallies:=[0,0,0,0,0,0]
	for ticket in 10000:
		var id:=Draw.choose(offer,(float(ticket)+.5)/10000.0,.5)
		for rank in 6:
			if id==TIERS[rank]+"1":tallies[rank]+=1
	check(tallies==WEIGHTS,"Exhaustive ten-thousand-ticket draw reproduces exact 45/28/16/8/2.5/0.5 percent distribution")
	var prior:=0
	for rank in 6:
		var tier_mid:float=(float(prior)+float(WEIGHTS[rank])*.5)/10000.0;var counts_per_id:=[0,0,0]
		for ticket in 1200:
			var id:=Draw.choose(offer,tier_mid,(float(ticket)+.5)/1200.0)
			for slot in 3:
				if id==TIERS[rank]+str(slot):counts_per_id[slot]+=1
		check(counts_per_id==[400,400,400],"Conditional item draw is uniform within tier, independent of tier weights: "+TIERS[rank]);prior+=WEIGHTS[rank]
	for mask in 64:
		var owned:Array[String]=[]
		for rank in 6:
			if not (mask&(1<<rank)):
				for index in 3:owned.append(TIERS[rank]+str(index))
		for counters in [{},{"epic":4},{"legendary":9},{"prismatic":19},{"epic":4,"legendary":9,"prismatic":19}]:
			inspect_offer(fixture,owned,"fixture",counters,"Availability mask %d counters %s"%[mask,counters])
	for group in ["foundation","resonance"]:
		var owned:Array[String]=[];var counters:Dictionary={};var count:=0
		while true:
			var actual:=inspect_offer(Catalog.DEFS,owned,group,counters,"Actual %s unlock %d"%[group,count+1])
			if actual.total_weight==0:break
			var chosen:=Draw.choose(actual,0.0,1.0)
			check(not owned.has(chosen),"Every actual unlock is new until collection exhaustion: "+chosen)
			var rank:=-1
			for definition in Catalog.DEFS:
				if definition.id==chosen:rank=TIERS.find(definition.rarity)
			for floor_rank in [3,4,5]:
				var threshold:int={3:5,4:10,5:20}[floor_rank]
				if int(counters.get(TIERS[floor_rank],0))==threshold-1:
					var possible:bool=Catalog.DEFS.any(func(d):return d.group==group and not owned.has(d.id) and TIERS.find(d.rarity)>=floor_rank)
					check(not possible or rank>=floor_rank,"Actual consecutive worst-case draws honor eligible %d-draw guarantee"%threshold)
			owned.append(chosen);count+=1;counters=Draw.advance(counters,TIERS[rank])
		var expected_ids:Array[String]=[]
		for id in BASELINE:
			if BASELINE[id].group==group:expected_ids.append(id)
		for id in APPENDED_IDS:
			var expected_group:="resonance" if id in APPENDED_RESONANCE else "foundation"
			if expected_group==group:expected_ids.append(id)
		check(count==(154 if group=="foundation" else 46) and owned.size()==expected_ids.size() and expected_ids.all(func(id):return owned.has(id)),"All actual skins in the group can be drawn exactly once with the exact approved identity set: "+group)
		probability_rows.append({"group":group,"unlocks":count,"final_counters":counters})
	for rarity in TIERS:
		var starting:={"epic":3,"legendary":8,"prismatic":18};var unchanged:=starting.duplicate();var next:=Draw.advance(starting,rarity);var rank:=TIERS.find(rarity)
		check(next=={"epic":0 if rank>=3 else 4,"legendary":0 if rank>=4 else 9,"prismatic":0 if rank>=5 else 19},"Success resets every satisfied pity and increments only higher unsatisfied guarantees: "+rarity)
		check(starting==unchanged,"Counter helper never mutates the caller's saved dictionary: "+rarity)
	check(Draw.clean_counters({"epic":-10,"legendary":9223372036854775807,"prismatic":99})=={"epic":0,"legendary":9,"prismatic":19},"Counter import bounds negative and overlarge stored values without losing the next-draw guarantee")
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	visuals();probability()
	var report:={"checks":checks,"failures":failures,"visuals":visual_rows,"actual_collection_draws":probability_rows,"scope":"Independent actual skin resources and pure probability/pity mathematics. No save/UI/economy transaction or browser/GPU claim."}
	print("SKIN_RARITY_REVIEW "+JSON.stringify(report))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	quit(0 if failures.is_empty() else 1)
