extends Node3D
signal item_collected(item:Node3D,hole:Node3D)
const Art=preload("res://fidelity/catalog_city.gd")
const FoodCity=preload("res://fidelity/food_city.gd")
const Train=preload("res://fidelity/edible_train.gd")
const TrainRoutes=preload("res://fidelity/train_routes.gd")
const TrainTracks=preload("res://fidelity/train_track_surface.gd")
var train_controller:RefCounted
var train_tracks:RefCounted
const Layout=preload("res://fidelity/street_layout.gd")
const MAPS:={"city":"SUNNY CITY","food":"SNACK GARDEN"}
const MapCatalog=preload("res://fidelity/map_catalog.gd")
const Rarity=preload("res://fidelity/skin_rarity.gd")
const SkinDraw=preload("res://fidelity/skin_draw.gd")
var selected_map:="city"
var food_collected:Dictionary={}
const FOOD_CITY_GOALS:={"buildings":12,"landmarks":1,"heaps":1}
var food_guide:Node3D
var food_guide_clock:=0.0
var ping_cache:Dictionary={}
var ui_clock:=0.0
const Hole=preload("res://fidelity/hole.gd")
const UI=preload("res://fidelity/ui.gd")
const Ads=preload("res://fidelity/ads_bridge.gd")
const Commerce=preload("res://fidelity/commerce_bridge.gd")
const Reveal=preload("res://fidelity/hole_reveal.gd")
var reveal:=Reveal.new()
const Asphalt=preload("res://fidelity/asphalt.gdshader")
## A full timed coin run; points and optional food milestones never end it.
const ROUND_SECONDS:=240.0
const SCORE_TARGET:=500
const WorldBounds=preload("res://fidelity/world_bounds.gd")
const WORLD_LIMIT:=WorldBounds.PLAY_LIMIT
const SKIN_DEFS:Array[Dictionary]=preload("res://fidelity/skin_catalog.gd").DEFS
var phase:="title"
var remaining:=ROUND_SECONDS
var elapsed:=0.0
var player:CharacterBody3D
var holes:Array[Node3D]=[]
var city:Node3D
var ground:Node3D
var world:Node3D
var camera:Camera3D
var scene_environment:Environment
var ui:Control
var eaten:=0
var total:=0
var scan:=0.0
var kills:=0
# Combat size is an explicit relation, independent from food admission.
const PLAYER_RIVAL_RATIO:=1.15
const AI_RIVAL_RATIO:=1.20
const AI_PLAYER_RATIO:=1.40
const PLAYER_SPAWN_PROTECTION:=10.0
var rival_previous_positions:Dictionary={}
var rival_previous_elapsed:=0.0
var rival_successors:Dictionary={}
var rival_ai_targets:Dictionary={}
var rival_combat_events:Array[Dictionary]=[]
var notice:=""
var notice_time:=0.0
var swallow_hint:=""
var coins:=50
var gems:=50
var stage:=1
var test_mode:=OS.get_cmdline_user_args().has("--test")
var demo_mode:=OS.get_cmdline_user_args().has("--demo")
var demo_target:Node3D
var sound:AudioStreamPlayer
var audio:Node
var music_enabled:=true
var sfx_enabled:=true
var ads:Node
var commerce:Node
var rewarded_requests:Dictionary={}
var verified_rewards_waiting:Array[String]=[]
var purchase_request:=""
var resonance_count:=0
var resonance_pull_count:=0
var selected_skin_id:=Rarity.NEW_PLAYER_SKIN
var skin_progress:=0
var owned_skin_ids:Array[String]=[Rarity.NEW_PLAYER_SKIN]
var draw_pity:Dictionary={"foundation":SkinDraw.clean_counters({}),"resonance":SkinDraw.clean_counters({})}
var completed_runs:=0
var best_scores:Dictionary={"city":0,"food":0}
var round_serial:=0
var round_receipt:Dictionary={}
var reward_receipts:Dictionary={}
var redeemed_transactions:Dictionary={}
var player_respawn_time:=0.0
var player_protected_until:=PLAYER_SPAWN_PROTECTION
var round_deaths:=0
var round_coins:=0
var round_score_coins:=0
var round_win_coins:=0
var round_start_stage:=1
var shop_gift_claimed_stage:=0
var last_shop_msec:=-1000
var last_unlock_msec:=-1000
# Tests must explicitly select an isolated file; --test alone never writes saves.
var test_progress_path:=""
const PROGRESS_PATH:="user://reference-first-level.cfg"
const COIN_PRICES:=[50,70,90,110,140]
const COIN_PACKS:=[{"coins":320,"gems":40},{"coins":2000,"gems":200},{"coins":9600,"gems":500}]
var progress_dirty:=false
var progress_save_time:=0.0

func _ready() -> void:
	reveal.reset()
	if not test_mode:load_player_progress()
	var envnode:=WorldEnvironment.new()
	var env:=Environment.new()
	scene_environment=env
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("b6e5f0")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color.WHITE
	env.ambient_light_energy=0.78
	envnode.environment=env
	add_child(envnode)
	var sun:=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-52,-38,0)
	sun.light_energy=0.95
	sun.shadow_enabled=true
	add_child(sun)
	camera=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_PERSPECTIVE
	camera.fov=58
	camera.keep_aspect=Camera3D.KEEP_HEIGHT
	camera.far=220
	add_child(camera)
	camera.current=true
	audio=preload("res://fidelity/audio.gd").new()
	audio.current_map=selected_map
	audio.music_enabled=music_enabled
	audio.sfx_enabled=sfx_enabled
	add_child(audio)
	sound=AudioStreamPlayer.new()
	sound.volume_db=-19
	sound.bus="SFX"
	add_child(sound)
	var layer:=CanvasLayer.new()
	add_child(layer)
	ui=UI.new()
	ui.game=self
	layer.add_child(ui)
	ads=Ads.new()
	add_child(ads)
	ads.rewarded_completed.connect(credit_round_double)
	ads.rewarded_closed.connect(reward_video_closed)
	ads.rewarded_failed.connect(reward_video_failed)
	ads.availability_changed.connect(refresh_monetization_ui)
	ads.initialize()
	commerce=Commerce.new()
	add_child(commerce)
	commerce.verified_purchase.connect(credit_verified_purchase)
	commerce.purchase_failed.connect(purchase_failed)
	commerce.purchase_pending.connect(purchase_pending)
	commerce.products_changed.connect(refresh_monetization_ui)
	commerce.initialize()
	if test_mode and OS.get_cmdline_user_args().has("--device-qa"):
		var recorder:=preload("res://fidelity/device_qa.gd").new()
		recorder.game=self
		recorder.process_mode=Node.PROCESS_MODE_ALWAYS
		add_child(recorder)
	if demo_mode:start_level();begin_play()

func _exit_tree()->void:
	reveal.reset()

func start_level() -> void:
	reveal.reset(true)
	get_tree().paused=false
	audio.set_map(selected_map)
	scene_environment.ambient_light_energy=.48 if selected_map=="food" else .78
	if is_instance_valid(ui):ui.menu_screen="home"
	if is_instance_valid(world):world.free()
	train_controller=null
	train_tracks=null
	holes.clear()
	phase="intro"
	remaining=ROUND_SECONDS
	elapsed=0
	eaten=0
	round_coins=0
	round_score_coins=0
	round_win_coins=0
	round_start_stage=stage
	food_collected.clear()
	food_guide=null
	food_guide_clock=0.0
	kills=0
	scan=0
	resonance_count=0
	resonance_pull_count=0
	player_respawn_time=0.0
	player_protected_until=PLAYER_SPAWN_PROTECTION
	round_deaths=0
	round_receipt={}
	world=Node3D.new()
	add_child(world)
	ground=preload("res://fidelity/cut_ground.gd").new()
	world.add_child(ground)
	var mat:=ShaderMaterial.new()
	mat.shader=Asphalt
	mat.set_shader_parameter("road_x",Layout.ROAD_X)
	mat.set_shader_parameter("road_z",Layout.ROAD_Z)
	mat.set_shader_parameter("road_half_width",Layout.HALF_WIDTH)
	mat.set_shader_parameter("food_theme",selected_map=="food")
	if selected_map=="food":mat.set_shader_parameter("food_city_atlas",load(FoodCity.Neighborhoods.ATLAS_PATH))
	for i in Layout.SIDEWALKS.size():
		var area:Rect2=Layout.SIDEWALKS[i]
		mat.set_shader_parameter("sidewalk_%d"%i,Vector4(area.position.x,area.position.y,area.size.x,area.size.y))
	ground.build(self,mat)
	city=FoodCity.new() if selected_map=="food" else Art.new()
	world.add_child(city)
	city.build(self)
	var train_route:Array[Vector2]=TrainRoutes.food_route() if selected_map=="food" else TrainRoutes.city_route()
	train_controller=Train.new()
	if train_controller.build(self,city,train_route,TrainRoutes.specs(selected_map),6.4 if selected_map=="food" else 7.2):
		train_controller.bypass_offset=1.35 if selected_map=="food" else 1.6
		train_tracks=TrainTracks.new()
		train_tracks.build(mat,train_route,selected_map=="food")
		train_controller.route_changed.connect(train_tracks.refresh)
	else:
		push_error("Unable to build the edible train for "+selected_map)
		train_controller=null
	reveal.bind_city(city)
	total=city.foods.size()
	player=spawn_hole("Mica",Vector3(1,0,23),Color("c85d3b"),true)
	var names:=["Rowan","Lumen","Brine","Aster","Ember","Kite","Moss"]
	var colors:=[Color("a9d8b5"),Color("d9ad62"),Color("6c8f7a"),Color("c98068"),Color("e8c27d"),Color("8da6a3"),Color("b66a4a")]
	var starts:=[Vector3(-4,0,23),Vector3(-2,0,27),Vector3(9,0,24),Vector3(-8,0,32),Vector3(19,0,37),Vector3(-12,0,14),Vector3(22,0,14)]
	if selected_map=="food":starts=[Vector3(-4,0,23),Vector3(-3,0,27),Vector3(12,0,23),Vector3(-12,0,29),Vector3(20,0,37),Vector3(-12,0,17),Vector3(20,0,14)]
	for i in 7:spawn_hole(names[i],starts[i],colors[i],false)
	reset_rival_state()
	update_camera(1.0,true)
	update_reveal(0.0)
	ui.refresh()

func spawn_hole(title:String, at:Vector3, tint:Color, human:bool) -> CharacterBody3D:
	var h:=Hole.new()
	h.game=self
	h.display_name=title
	h.skin_id=selected_skin_id if human else ""
	h.color=Color(skin_definition(selected_skin_id).tint) if human else tint
	h.is_player=human
	ground.add_child(h)
	ground.add_child(h.hole)
	h.hole.visible=false
	h.position=at
	holes.append(h)
	return h

func begin_play() -> void:
	if phase!="intro":return
	phase="playing"
	for h in holes:h.enabled=true
	if is_instance_valid(player) and player.skin_id=="moss_bloom":player.skin_cooldown=4.0
	ui.refresh()

func screen_direction(d:Vector2) -> Vector2:
	var right:=Vector2(camera.global_basis.x.x,camera.global_basis.x.z).normalized()
	var back:=Vector2(camera.global_basis.z.x,camera.global_basis.z.z).normalized()
	return right*d.x+back*d.y

func _physics_process(delta:float) -> void:
	if progress_dirty and not test_mode:
		progress_save_time-=delta
		if progress_save_time<=0.0:
			if save_player_progress():retry_verified_rewards()
			else:progress_save_time=5.0
	if phase!="playing":return
	elapsed+=delta
	remaining=maxf(0,remaining-delta)
	if remaining<=0:
		finish("complete")
		return
	if train_controller!=null:train_controller.step(delta)
	if player_respawn_time>0:
		player_respawn_time=maxf(0,player_respawn_time-delta)
		if player_respawn_time<=0:respawn_player()
		return
	notice_time=maxf(0,notice_time-delta)
	scan-=delta
	if scan<=0:
		scan=0.09
		scan_food()
	scan_rivals(delta)
	if phase!="playing":return
	if is_instance_valid(player) and player.skin_id=="moss_bloom" and player.skin_cooldown<=0.0:activate_skin_skill(player,true)
	if demo_mode and phase=="playing":
		player.test_direction=auto_direction(player,delta)

func auto_direction(h:Node3D,delta:float)->Vector2:
	if phase!="playing" or get_tree().paused or not is_instance_valid(h) or not h.active:return Vector2.ZERO
	# A released object still gets its normal gravity settlement before an AI
	# chooses another meal. Rival targets are separate from the food-only target.
	var destination:Vector3=h.position
	h.set_meta("rival_pursuit",0)
	if h.settle_time>0.0:
		h.settle_time=maxf(0.0,h.settle_time-delta)
		destination=h.settle_at
	else:
		if not is_instance_valid(h.target) or h.target.consumed or (is_instance_valid(h.target.claimed_by) and h.target.claimed_by!=h):
			h.target=nearest_food(h)
		if is_instance_valid(h.target) and h.target.claimed_by==h:
			destination=h.target.interaction_position()
			h.settle_time=1.25;h.settle_at=destination;h.target=null
		else:
			var prey:Node3D=choose_rival_prey(h) if h!=player else null
			var food_distance:=INF
			if is_instance_valid(h.target):food_distance=h.position.distance_to(h.target.interaction_position())
			if is_instance_valid(prey) and h.position.distance_to(prey.position)<=maxf(3.5,food_distance*1.35):
				destination=prey.position
				h.set_meta("rival_pursuit",prey.get_instance_id())
			elif is_instance_valid(h.target):destination=h.target.interaction_position()
	var gap:=Vector2(destination.x-h.position.x,destination.z-h.position.z)
	return gap.normalized()*clampf(gap.length()/.4,0,1)

func choose_rival_prey(hunter:Node3D)->Node3D:
	var reach:float=clampf(hunter.radius*1.6+3.0,7.0,24.0)
	var selected:Node3D=null;var nearest:=reach*reach
	for other in holes:
		if not rival_size_allows(hunter,other):continue
		var distance:float=hunter.position.distance_squared_to(other.position)
		# A modest preference for the previous choice avoids rapid target flips.
		var prior:WeakRef=rival_ai_targets.get(hunter.get_instance_id())
		if prior!=null and prior.get_ref()==other:distance*=.8
		if distance<nearest:nearest=distance;selected=other
	if is_instance_valid(selected):rival_ai_targets[hunter.get_instance_id()]=weakref(selected)
	else:rival_ai_targets.erase(hunter.get_instance_id())
	return selected

func _process(delta:float) -> void:
	if is_instance_valid(player) and phase in ["intro","playing"]:update_camera(delta)
	update_reveal(delta)
	if is_instance_valid(player) and phase in ["intro","playing"]:update_hole_labels()
	if selected_map=="food" and phase=="playing" and is_instance_valid(city):
		food_guide_clock-=delta
		if food_guide_clock<=0.0:
			food_guide_clock=1.0
			food_guide=city.objective_target(player) if not food_city_goal_complete() else null
	ui_clock+=delta
	if is_instance_valid(ui) and ui_clock>=1.0/30.0:
		ui_clock=0.0
		ui.queue_redraw()

func prepare_occluder(node:Node)->void:
	# Dynamic loose objects deliberately retain their opaque source materials.
	pass

func update_reveal(delta:float)->void:
	# Paused gameplay freezes the aperture along with its camera and actors.
	if get_tree().paused:return
	var active:bool=phase in ["intro","playing"] and is_instance_valid(player) and player.active
	# Returning home frees the player with the old world. Do not pass that
	# stale Object into a typed Node3D argument, even for a disabled tick.
	if not active:
		reveal.reset()
		return
	reveal.tick(camera,player,delta,true)

func update_hole_labels() -> void:
	if not is_instance_valid(camera):return
	# Keep the player's three-line badge readable, then admit nearby rival
	# badges only when their screen-space blocks do not collide. This affects
	# presentation only; all holes remain active and simulated.
	var ordered:Array[Node3D]=[]
	if is_instance_valid(player) and player.active:ordered.append(player)
	var rivals:Array[Node3D]=[]
	for h in holes:
		if not is_instance_valid(h) or not h.active or h==player:continue
		rivals.append(h)
	rivals.sort_custom(func(a:Node3D,b:Node3D)->bool:
		return a.global_position.distance_squared_to(player.global_position)<b.global_position.distance_squared_to(player.global_position))
	ordered.append_array(rivals)
	var accepted:Array[Dictionary]=[]
	for h in holes:
		if not is_instance_valid(h):continue
		h.label.visible=false
		h.name_tag.visible=false
		h.meter.visible=false
	for h in ordered:
		var screen:=camera.unproject_position(h.global_position+Vector3.UP*1.7)
		# Label3D has a wide outline and three lines. Reserve space for the
		# actual name length instead of forcing off-screen player tags visible.
		# The sector line is wider than the short display name, so reserve a
		# conservative block for all three billboard lines and their outline.
		var span:=clampf(72.0+float(h.display_name.length())*6.0,132.0,180.0)
		var on_screen:=screen.x>span+10.0 and screen.x<540.0-span-10.0 and screen.y>92.0 and screen.y<660.0
		var clear:=on_screen
		if clear:
			for other in accepted:
				if absf(screen.x-float(other.at.x))<span+float(other.span) and absf(screen.y-float(other.at.y))<58.0:
					clear=false
					break
		if clear:
			accepted.append({"at":screen,"span":span})
			h.label.visible=true
			h.name_tag.visible=true
			h.meter.visible=true

func update_camera(delta:float, instant:=false) -> void:
	var distance:float=1.0+(player.radius-0.85)*0.12
	var target:Vector3=player.position
	var offset:=Vector3(10,18,14)*distance
	var viewport_size:Vector2=camera.get_viewport().get_visible_rect().size
	var aspect:=maxf(viewport_size.x,1.0)/maxf(viewport_size.y,1.0)
	var half_fov:=deg_to_rad(camera.fov)*.5
	var limiting_half_fov:=minf(half_fov,atan(tan(half_fov)*aspect))
	var required_distance:float=player.radius*1.08/maxf(.001,sin(limiting_half_fov))
	offset=offset.normalized()*maxf(offset.length(),required_distance)
	camera.position=target+offset if instant else camera.position.lerp(target+offset,1-exp(-delta*6))
	# Growth may cross several tiers at once. Preserve the same margin during
	# camera easing instead of clipping the mouth until the camera catches up.
	var actual_offset:Vector3=camera.position-target
	if actual_offset.length()<required_distance:
		camera.position=target+(actual_offset.normalized() if actual_offset.length()>.001 else offset.normalized())*required_distance
	camera.far=maxf(220.0,maxf(offset.length(),camera.position.distance_to(target))+player.radius+20.0)
	camera.look_at(target)

func nearest_food(h:Node3D) -> Node3D:
	var found:Node3D
	var best:=INF
	if city.has_method("query_foods"):
		for reach in [12.0,24.0,48.0,256.0]:
			for item in city.query_foods(h.position,reach):
				if not item.can_fit(h):continue
				var dist:float=item.interaction_position().distance_squared_to(h.global_position)
				if dist<best:best=dist;found=item
			if best<=reach*reach:return found
		return found
	for item in city.foods:
		if not is_instance_valid(item) or not item.can_fit(h):continue
		var dist:float=item.interaction_position().distance_squared_to(h.global_position)
		if dist<best:best=dist;found=item
	return found

func scan_food() -> void:
	swallow_hint=""
	var hint_distance:=INF
	var player_swallowing:=false
	var candidates:Array=city.scan_candidates(holes) if city.has_method("scan_candidates") else city.foods
	for item in candidates:
		if not is_instance_valid(item) or item.consumed:continue
		if item.claimed_by==player:player_swallowing=true
		if is_instance_valid(item.claimed_by):continue
		var at:Vector3=item.interaction_position()
		var player_distance:=Vector2(at.x-player.position.x,at.z-player.position.z).length()
		if player_distance<player.radius*.9 and player_distance<hint_distance and not is_instance_valid(item.support_parent) and item.footprint*1.08>player.radius:
			hint_distance=player_distance
			var needed_level:int=player.level_for_radius(item.footprint*1.08)
			swallow_hint="GROW TO LVL %d"%needed_level if needed_level>0 else "TOO LARGE"
		for h in holes:
			if not h.active or not item.can_fit(h):continue
			var d:=Vector2(at.x-h.position.x,at.z-h.position.z).length()
			# Wake while part of the base is still supported by the rim, so
			# asymmetric contact and gravity can tip the rigid body into the cut.
			if d<h.radius*0.90:
				item.begin_swallow(h)
				if h==player:player_swallowing=true
				break
	if player_swallowing:swallow_hint=""

func activate_resonance(hole:Node3D) -> bool:
	if phase!="playing" or hole!=player:return false
	var influenced:=0
	var reach:=maxf(4.0,hole.radius*2.8)
	for item in city.foods:
		if influenced>=10:break
		if not is_instance_valid(item) or item.consumed or is_instance_valid(item.claimed_by):continue
		if not item.can_fit(hole):continue
		if item.global_position.distance_to(hole.global_position)>reach:continue
		if item.begin_pull(hole):influenced+=1
	resonance_count+=1
	resonance_pull_count+=influenced
	notice="RESONANCE %02d"%influenced
	notice_time=1.2
	return true

func skin_definition(id:String)->Dictionary:
	for definition in SKIN_DEFS:
		if definition.id==id:return definition
	return SKIN_DEFS[0]

func skin_exists(id:String)->bool:
	for definition in SKIN_DEFS:
		if definition.id==id:return true
	return false

func skin_ids(group:String)->Array[String]:
	var ids:Array[String]=[]
	for definition in SKIN_DEFS:
		if definition.group==group:ids.append(definition.id)
	return ids

func skin_unlocked(id:String)->bool:
	return skin_exists(id) and owned_skin_ids.has(id)

func locked_skin_ids(group:String)->Array[String]:
	var ids:Array[String]=[]
	for id in skin_ids(group):
		if not skin_unlocked(id):ids.append(id)
	return ids

func skin_unlock_price(group:String)->int:
	if locked_skin_ids(group).is_empty():return 0
	var purchased:=unlocked_skin_count(group)-(1 if group=="foundation" else 0)
	return COIN_PRICES[clampi(purchased,0,COIN_PRICES.size()-1)]

func skin_draw_offer(group:String)->Dictionary:
	return SkinDraw.offer(SKIN_DEFS,owned_skin_ids,group,draw_pity.get(group,{}))

func unlock_random_skin(group:String)->Dictionary:
	if phase!="title":return {"ok":false,"message":"Return home to unlock skins"}
	var pool:=locked_skin_ids(group)
	if pool.is_empty():return {"ok":false,"message":"COLLECTION COMPLETE"}
	var price:=skin_unlock_price(group)
	if coins<price:
		var missing:=price-coins
		return {"ok":false,"message":"Need %d more coins"%missing,"price":price,"missing_coins":missing}
	# Reject rapid taps even when input was queued before the UI refreshed.
	if Time.get_ticks_msec()-last_unlock_msec<800:return {"ok":false,"message":"Enjoy your new skin!"}
	var offer:=skin_draw_offer(group)
	var id:=SkinDraw.choose(offer,randf(),randf())
	if id.is_empty():return {"ok":false,"message":"COLLECTION COMPLETE"}
	var previous_skin:=selected_skin_id
	var previous_pity:Dictionary=draw_pity.duplicate(true)
	coins-=price;owned_skin_ids.append(id);selected_skin_id=id
	draw_pity[group]=SkinDraw.advance(offer.counters,str(skin_definition(id).rarity))
	if not save_player_progress():
		coins+=price;owned_skin_ids.erase(id);selected_skin_id=previous_skin
		draw_pity=previous_pity
		return {"ok":false,"message":"Could not save. No coins spent."}
	last_unlock_msec=Time.get_ticks_msec()
	return {"ok":true,"id":id,"price":price,"rarity":skin_definition(id).rarity}

func unlocked_skin_count(group:String)->int:
	var count:=0
	for id in skin_ids(group):
		if skin_unlocked(id):count+=1
	return count

func buy_coin_pack(index:int)->Dictionary:
	if phase!="title" or index<0 or index>=COIN_PACKS.size():return {"ok":false,"message":"Offer unavailable"}
	var offer:Dictionary=COIN_PACKS[index]
	if gems<int(offer.gems):return {"ok":false,"message":"Need %d more gems"%(int(offer.gems)-gems)}
	if Time.get_ticks_msec()-last_shop_msec<600:return {"ok":false,"message":"Coins added!"}
	gems-=int(offer.gems);coins+=int(offer.coins)
	if not save_player_progress():
		gems+=int(offer.gems);coins-=int(offer.coins)
		return {"ok":false,"message":"Could not save. No gems spent."}
	last_shop_msec=Time.get_ticks_msec()
	return {"ok":true,"message":"+%d COINS"%int(offer.coins)}

func claim_shop_gift()->Dictionary:
	if phase!="title" or shop_gift_claimed_stage>=stage:return {"ok":false,"message":"Finish a timed run for the next gift"}
	var previous:=shop_gift_claimed_stage
	shop_gift_claimed_stage=stage;gems+=5
	if not save_player_progress():
		shop_gift_claimed_stage=previous;gems-=5
		return {"ok":false,"message":"Could not save. Try again."}
	return {"ok":true,"message":"+5 GEMS"}

func note_skin_progress(value:int) -> void:
	var previous:=skin_progress
	skin_progress=mini(SCORE_TARGET,maxi(skin_progress,value))
	if skin_progress!=previous:
		progress_dirty=true
		progress_save_time=maxf(progress_save_time,1.0)
	if skin_progress!=previous and is_instance_valid(ui):ui.queue_redraw()

func select_skin(id:String)->bool:
	if not skin_exists(id) or not skin_unlocked(id):return false
	var previous:=selected_skin_id
	selected_skin_id=id
	if not save_player_progress():selected_skin_id=previous;return false
	if is_instance_valid(ui):ui.refresh()
	return true

func progress_file()->String:
	return test_progress_path if test_mode else PROGRESS_PATH

func load_player_progress()->bool:
	var path:=progress_file()
	if path.is_empty():return true
	var cfg:=ConfigFile.new()
	var error:=cfg.load(path)
	if error==ERR_FILE_NOT_FOUND:return true
	if error!=OK:return false
	music_enabled=bool(cfg.get_value("audio","music_enabled",true))
	sfx_enabled=bool(cfg.get_value("audio","sfx_enabled",true))
	if is_instance_valid(audio):
		audio.set_music_enabled(music_enabled)
		audio.set_sfx_enabled(sfx_enabled)
	selected_map=str(cfg.get_value("progress","map","city"))
	if not MAPS.has(selected_map):selected_map="city"
	if is_instance_valid(audio):audio.set_map(selected_map)
	coins=maxi(0,int(cfg.get_value("progress","coins",50)))
	gems=maxi(0,int(cfg.get_value("progress","gems",50)))
	stage=maxi(1,int(cfg.get_value("progress","stage",1)))
	shop_gift_claimed_stage=maxi(0,int(cfg.get_value("progress","shop_gift_claimed_stage",0)))
	skin_progress=clampi(int(cfg.get_value("progress","skin_progress",0)),0,SCORE_TARGET)
	owned_skin_ids=[Rarity.NEW_PLAYER_SKIN]
	# Existing pre-rarity saves always owned their original starter. Preserve
	# that entitlement, even if an older save omitted the explicit list.
	if int(cfg.get_value("progress","skin_schema",0))<3:owned_skin_ids.append("core_shell")
	var legacy:=int(cfg.get_value("progress","skin_schema",0))<2
	if legacy:
		for definition in SKIN_DEFS:
			if skin_progress>=int(definition.legacy_score) and not owned_skin_ids.has(definition.id):owned_skin_ids.append(definition.id)
	# An explicit entitlement list is always additive, including transitional
	# saves that wrote ownership before updating their schema marker.
	var saved_ids=cfg.get_value("progress","owned_skin_ids",[])
	if saved_ids is Array or saved_ids is PackedStringArray:
		for id in saved_ids:
			if skin_exists(str(id)) and not owned_skin_ids.has(str(id)):owned_skin_ids.append(str(id))
	var saved_skin:=str(cfg.get_value("progress","selected_skin_id",Rarity.NEW_PLAYER_SKIN))
	selected_skin_id=saved_skin if skin_unlocked(saved_skin) else Rarity.NEW_PLAYER_SKIN
	var saved_pity=cfg.get_value("collection","pity",{})
	draw_pity={"foundation":SkinDraw.clean_counters({}),"resonance":SkinDraw.clean_counters({})}
	if saved_pity is Dictionary:
		for group in draw_pity:
			if saved_pity.get(group) is Dictionary:draw_pity[group]=SkinDraw.clean_counters(saved_pity[group])
	completed_runs=maxi(0,int(cfg.get_value("progress","completed_runs",0)))
	round_serial=maxi(0,int(cfg.get_value("progress","round_serial",0)))
	var saved_best=cfg.get_value("progress","best_scores",{})
	for map_id in MAPS:
		best_scores[map_id]=maxi(0,int(saved_best.get(map_id,0))) if saved_best is Dictionary else 0
	var saved_receipts=cfg.get_value("rewards","rounds",{})
	reward_receipts={}
	if saved_receipts is Dictionary:
		for key in saved_receipts:
			var receipt=saved_receipts[key]
			if key is String and receipt is Dictionary and receipt.get("id","")==key and MAPS.has(receipt.get("map","")) and int(receipt.get("base_coins",-1))>=0:
				reward_receipts[key]=receipt.duplicate(true)
	var saved_transactions=cfg.get_value("rewards","purchases",{})
	redeemed_transactions={}
	if saved_transactions is Dictionary:
		for transaction in saved_transactions:
			if transaction is String and not transaction.is_empty() and Commerce.PRODUCTS.has(saved_transactions[transaction]):redeemed_transactions[transaction]=saved_transactions[transaction]
	var saved_requests=cfg.get_value("rewards","video_requests",{})
	rewarded_requests={}
	verified_rewards_waiting.clear()
	if saved_requests is Dictionary:
		for key in saved_requests:
			var request=saved_requests[key]
			if key is String and request is Dictionary and reward_receipts.has(request.get("round","")):
				rewarded_requests[key]=request.duplicate(true)
				# Loading cannot survive a process restart; an authenticated late
				# callback may still settle its original receipt exactly once.
				if rewarded_requests[key].get("status","")=="loading":rewarded_requests[key].status="closed"
				if rewarded_requests[key].get("status","")=="reward_due":verified_rewards_waiting.append(key)
	if not verified_rewards_waiting.is_empty():progress_dirty=true;progress_save_time=1.0
	if legacy:
		# Keep the original pre-coin save once, then persist ownership separately
		# from the best score so later high scores cannot re-grant every skin.
		if not FileAccess.file_exists(path+".pre-coins.cfg"):
			if DirAccess.copy_absolute(path,path+".pre-coins.cfg")!=OK:return false
		return save_player_progress()
	return true

func save_player_progress() -> bool:
	var path:=progress_file()
	if path.is_empty():return true
	var cfg:=ConfigFile.new()
	var error:=cfg.load(path)
	if error!=OK and error!=ERR_FILE_NOT_FOUND:return false
	cfg.set_value("progress","skin_progress",skin_progress)
	cfg.set_value("progress","skin_schema",3)
	cfg.set_value("progress","owned_skin_ids",owned_skin_ids)
	cfg.set_value("progress","selected_skin_id",selected_skin_id)
	cfg.set_value("progress","map",selected_map)
	cfg.set_value("progress","coins",coins)
	cfg.set_value("progress","gems",gems)
	cfg.set_value("progress","stage",stage)
	cfg.set_value("progress","shop_gift_claimed_stage",shop_gift_claimed_stage)
	cfg.set_value("progress","completed_runs",completed_runs)
	cfg.set_value("progress","round_serial",round_serial)
	cfg.set_value("progress","best_scores",best_scores)
	cfg.set_value("collection","pity",draw_pity)
	cfg.set_value("rewards","rounds",reward_receipts)
	cfg.set_value("rewards","purchases",redeemed_transactions)
	cfg.set_value("rewards","video_requests",rewarded_requests)
	cfg.set_value("audio","music_enabled",music_enabled)
	cfg.set_value("audio","sfx_enabled",sfx_enabled)
	if cfg.save(path+".tmp")!=OK:return false
	if DirAccess.rename_absolute(path+".tmp",path)!=OK:
		DirAccess.remove_absolute(path+".tmp")
		return false
	progress_dirty=false
	progress_save_time=0.0
	return true

func pull_skin_objects(hole:Node3D, reach:float, limit:int)->int:
	var influenced:=0
	for item in city.foods:
		if influenced>=limit:break
		if not is_instance_valid(item) or item.consumed or is_instance_valid(item.claimed_by):continue
		if not item.can_fit(hole) or item.global_position.distance_to(hole.global_position)>reach:continue
		if item.begin_pull(hole):influenced+=1
	return influenced

func activate_skin_skill(hole:Node3D, passive:=false)->bool:
	if phase!="playing" or hole!=player or not is_instance_valid(hole):return false
	var definition:=skin_definition(hole.skin_id)
	var kind:String=definition.kind
	if kind in ["cosmetic","none"]:return false
	if not passive and kind=="bloom":return false
	if hole.skin_cooldown>0.0:return false
	var used:=true
	var affected:=0
	match kind:
		"draw":affected=pull_skin_objects(hole,5.0,5)
		"bloom":affected=pull_skin_objects(hole,4.2,3)
		"sweep":affected=pull_skin_objects(hole,6.5,8)
		"thrum":
			for entry in city.building_visuals:
				var body:RigidBody3D=entry.body
				if not is_instance_valid(body) or is_instance_valid(body.claimed_by):continue
				var offset:Vector3=body.global_position-hole.global_position
				if Vector2(offset.x,offset.z).length()>20.0:continue
				var away:=Vector3(offset.x,0,offset.z).normalized()
				# Buildings begin frozen for the ordinary swallow model. A thrum is
				# deliberately a tiny authored presentation nudge, not a free-flight
				# impulse that could destabilize the city before a collapse.
				body.notify_moving()
				body.global_position+=away*.14
				body.rotation.y+=.018 if affected%2==0 else -.018
				affected+=1
		"speed":hole.speed_boost_time=.85
		_:used=false
	if not used:return false
	hole.skin_cooldown=float(definition.cooldown)
	if is_instance_valid(hole.skin_visual):hole.skin_visual.flash()
	notice=definition.skill_name+(" %02d"%affected if affected>0 else "")
	notice_time=1.2
	return true

func collect(item:Node3D, h:Node3D) -> void:
	if phase!="playing":return
	h=active_rival_owner(h)
	if not is_instance_valid(h):return
	h.award(item.points)
	item_collected.emit(item,h)
	if h==player:note_skin_progress(h.score)
	eaten+=1
	if h==player:
		if selected_map=="food":city.record_collection(item,h)
		var kind:String=str(item.get_meta("food_kind",item.category))
		food_collected[kind]=int(food_collected.get(kind,0))+1
		ping(item.points)

func reset_rival_state()->void:
	rival_previous_positions.clear();rival_previous_elapsed=elapsed
	rival_successors.clear();rival_ai_targets.clear();rival_combat_events.clear()
	for hole in holes:
		if is_instance_valid(hole):rival_previous_positions[hole.get_instance_id()]=Vector2(hole.position.x,hole.position.z)

func rival_size_allows(predator:Node3D,prey:Node3D,predator_radius:=-1.0,prey_radius:=-1.0)->bool:
	if not is_instance_valid(predator) or not is_instance_valid(prey) or predator==prey or not predator.active or not prey.active:return false
	if prey==player and elapsed<player_protected_until:return false
	var ratio:float=PLAYER_RIVAL_RATIO if predator==player else AI_PLAYER_RATIO if prey==player else AI_RIVAL_RATIO
	var big:float=predator.radius if predator_radius<0 else predator_radius
	var small:float=prey.radius if prey_radius<0 else prey_radius
	return small>0 and big>=small*ratio

func rival_contact(predator:Dictionary,prey:Dictionary,delta:float)->bool:
	var allowance:float=predator.radius-prey.radius
	if allowance<=0:return false
	var relative:Vector2=prey.at-predator.at
	if relative.length_squared()<=allowance*allowance:return true
	if delta<=0.0 or (prey.body==player and rival_previous_elapsed<player_protected_until):return false
	var previous_predator:Vector2=rival_previous_positions.get(predator.id,predator.at)
	var previous_prey:Vector2=rival_previous_positions.get(prey.id,prey.at)
	# Explicit teleports/setup are not travel paths. reset_rival_state() is the
	# public fixture/restart boundary; this bound also rejects remote warp sweeps.
	var maximum_step:=maxf(.5,delta*20.0)
	if previous_predator.distance_to(predator.at)>maximum_step or previous_prey.distance_to(prey.at)>maximum_step:return false
	var previous_relative:Vector2=previous_prey-previous_predator
	var closest:=Geometry2D.get_closest_point_to_segment(Vector2.ZERO,previous_relative,relative)
	return closest.length_squared()<=allowance*allowance

func active_rival_owner(owner:Node3D)->Node3D:
	var current:Node3D=owner
	for _step in holes.size()+1:
		if not is_instance_valid(current):return null
		if current.active:return current
		var next:WeakRef=rival_successors.get(current.get_instance_id())
		if next==null:return null
		current=next.get_ref()
	return null

func transfer_rival_claims(from:Node3D,to:Node3D)->void:
	for item in city.foods:
		if not is_instance_valid(item) or item.consumed:continue
		for field in ["claimed_by","pull_owner","fall_credit","release_hole"]:
			if item.get(field)==from:item.set(field,to)

func scan_rivals(delta:=0.0)->void:
	if phase!="playing" or get_tree().paused:return
	# Freeze this step's sizes/reward bases and resolve largest first. Eating
	# cannot grow a hole into a second size gate during the same physics step.
	var snapshot:Array[Dictionary]=[]
	for hole in holes:
		if is_instance_valid(hole) and hole.active:
			snapshot.append({"body":hole,"id":hole.get_instance_id(),"radius":hole.radius,"score":hole.score,"at":Vector2(hole.position.x,hole.position.z)})
	snapshot.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.radius>b.radius if not is_equal_approx(a.radius,b.radius) else a.id<b.id)
	for predator in snapshot:
		var large:Node3D=predator.body
		if not large.active:continue
		for prey in snapshot:
			var small:Node3D=prey.body
			if not rival_size_allows(large,small,predator.radius,prey.radius):continue
			if not rival_contact(predator,prey,delta):continue
			# Retire before awarding; every victim can contribute exactly once.
			small.retire();rival_successors[prey.id]=weakref(large)
			rival_ai_targets.erase(prey.id)
			transfer_rival_claims(small,large)
			var reward:=maxi(5,int(prey.score*.3))
			large.award(reward)
			if rival_combat_events.size()>=128:rival_combat_events.pop_front()
			rival_combat_events.append({"hunter":large.display_name,"victim":small.display_name,"reward_base":reward,"victim_score":prey.score,"elapsed":elapsed})
			if large==player:kills+=1
			if small==player:
				round_deaths+=1
				player_respawn_time=2.0
				notice="BACK IN 2 SECONDS"
				notice_time=2.0
				break
		if phase!="playing":break
	rival_previous_elapsed=elapsed
	# Also advance protected pairs' history: protection expiry must never replay
	# a contact that happened while the player was protected.
	rival_previous_positions.clear()
	for entry in snapshot:
		if is_instance_valid(entry.body) and entry.body.active:rival_previous_positions[entry.id]=entry.at

func level_up() -> void:
	notice="LEVEL UP!"
	notice_time=1.2

func respawn_player()->void:
	var old:=player
	var saved_score:int=old.score
	var spawn:=Vector3(1,0,23)
	var best_clearance:=-INF
	for at in [Vector3(1,0,23),Vector3(-45,0,48),Vector3(46,0,-48),Vector3(-45,0,-48),Vector3(46,0,48)]:
		var clearance:=INF
		for rival in holes:
			if rival!=old and is_instance_valid(rival) and rival.active:clearance=minf(clearance,at.distance_to(rival.position)-rival.radius)
		if clearance>best_clearance:best_clearance=clearance;spawn=at
	player=spawn_hole("Mica",spawn,Color(skin_definition(selected_skin_id).tint),true)
	player.award(saved_score)
	player.enabled=true
	player_protected_until=elapsed+8.0
	holes.erase(old)
	if is_instance_valid(old.hole):old.hole.queue_free()
	old.queue_free()
	update_camera(0.0,true)
	notice="BACK IN! COINS KEPT"
	notice_time=1.5
	ui.refresh()

func finish(reason:String) -> void:
	if phase!="playing":return
	if reason not in ["complete","timeout","eaten"]:return
	phase=reason
	reveal.reset()
	# Reward actual points once at settlement, on either map. Quitting a
	# paused round does not manufacture a completion or award free coins.
	round_score_coins=maxi(0,player.score)/10
	round_win_coins=20 if reason in ["complete","timeout"] and player.score>0 else 0
	round_coins=round_score_coins+round_win_coins
	coins+=round_coins
	if reason in ["complete","timeout"] and player.score>0:
		stage+=1
		completed_runs+=1
	best_scores[selected_map]=maxi(int(best_scores.get(selected_map,0)),player.score)
	round_serial+=1
	var receipt_id:="%d-%d-%d"%[round_serial,int(Time.get_unix_time_from_system()*1000),randi()]
	round_receipt={"id":receipt_id,"base_coins":round_coins,"score":player.score,"map":selected_map,"doubled":false,"settled":true}
	reward_receipts[receipt_id]=round_receipt.duplicate(true)
	while reward_receipts.size()>32:
		var expired:String=str(reward_receipts.keys()[0])
		reward_receipts.erase(expired)
		for request_id in rewarded_requests.keys():
			if rewarded_requests[request_id].get("round","")==expired:rewarded_requests.erase(request_id)
	if not save_player_progress():progress_dirty=true;progress_save_time=1.0
	for h in holes:h.enabled=false
	# Stop admission and steering, but let released props, rain and collapsing
	# tiers finish their physical fall behind the results. collect() rejects
	# late receipts, so this presentation cannot change the settled reward.
	ui.refresh()

func back_home() -> void:
	reveal.reset()
	get_tree().paused=false
	phase="title"
	if is_instance_valid(ui):ui.menu_screen="home"
	if is_instance_valid(world):world.queue_free()
	train_controller=null
	train_tracks=null
	holes.clear()
	ui.refresh()

func refresh_monetization_ui()->void:
	if is_instance_valid(commerce):purchase_request=commerce.active_request_id()
	if is_instance_valid(ui):ui.refresh()

func reward_video_pending()->bool:
	for request in rewarded_requests.values():
		if request is Dictionary and request.get("round","")==round_receipt.get("id","") and request.get("status","")=="loading":return true
	return false

func request_round_double()->Dictionary:
	if phase not in ["complete","timeout","eaten"] or round_receipt.is_empty():return {"ok":false,"message":"Finish a run first"}
	if round_receipt.get("doubled",false):return {"ok":false,"message":"Double coins already claimed"}
	if int(round_receipt.get("base_coins",0))<=0:return {"ok":false,"message":"Earn coins in your next run"}
	if reward_video_pending():return {"ok":false,"message":"Your video is loading"}
	if not is_instance_valid(ads) or not ads.validated_reward_available():return {"ok":false,"message":"Videos are not available right now"}
	var request_id:="reward-%s-%d"%[round_receipt.id,randi()]
	rewarded_requests[request_id]={"round":round_receipt.id,"status":"loading"}
	# The round and request are durable before any external callback can arrive.
	if not save_player_progress():
		rewarded_requests.erase(request_id)
		return {"ok":false,"message":"Could not save. Try again."}
	if not ads.show_rewarded(request_id):
		reward_video_failed(request_id,"Video unavailable")
		return {"ok":false,"message":"Videos are not available right now"}
	return {"ok":true,"message":"Loading your video..."}

func credit_round_double(request_id:String)->void:
	var request=rewarded_requests.get(request_id)
	if not request is Dictionary:return
	var receipt_id:=str(request.get("round",""))
	var receipt=reward_receipts.get(receipt_id)
	if not receipt is Dictionary or not receipt.get("settled",false):return
	if receipt.get("doubled",false):verified_rewards_waiting.erase(request_id);return
	var bonus:=maxi(0,int(receipt.get("base_coins",0)))
	if bonus<=0:return
	var before_receipt:Dictionary=receipt.duplicate(true)
	var before_request:Dictionary=request.duplicate(true)
	coins+=bonus;receipt.doubled=true;request.status="earned"
	if not save_player_progress():
		coins-=bonus;reward_receipts[receipt_id]=before_receipt;rewarded_requests[request_id]=before_request
		rewarded_requests[request_id].status="reward_due"
		if not verified_rewards_waiting.has(request_id):verified_rewards_waiting.append(request_id)
		progress_dirty=true;progress_save_time=1.0
		monetization_notice("Saving your reward. We will retry.")
		return
	verified_rewards_waiting.erase(request_id)
	if round_receipt.get("id","")==receipt_id:round_receipt=receipt.duplicate(true)
	monetization_notice("+%d BONUS COINS"%bonus)

func retry_verified_rewards()->void:
	for request_id in verified_rewards_waiting.duplicate():credit_round_double(request_id)

func reward_video_closed(request_id:String)->void:
	var request=rewarded_requests.get(request_id)
	if not request is Dictionary:return
	# SDKs may report earned after closed. Keep the authenticated request
	# binding; a closed video alone never earns or cancels a reward.
	if request.get("status","") not in ["earned","reward_due"]:request.status="closed"
	if not save_player_progress():progress_dirty=true;progress_save_time=1.0
	refresh_monetization_ui()

func reward_video_failed(request_id:String,_message:String)->void:
	var request=rewarded_requests.get(request_id)
	if not request is Dictionary:return
	if request.get("status","") not in ["earned","reward_due"]:request.status="failed"
	if not save_player_progress():progress_dirty=true;progress_save_time=1.0
	monetization_notice("Videos are not available right now")

func request_coin_purchase(product_id:String)->Dictionary:
	if phase!="title" or not purchase_request.is_empty():return {"ok":false,"message":"Please wait for your purchase"}
	if not is_instance_valid(commerce) or not commerce.purchase_available(product_id):return {"ok":false,"message":"Purchases are coming soon"}
	purchase_request="purchase-%d-%d"%[int(Time.get_unix_time_from_system()*1000),randi()]
	if not commerce.purchase(product_id,purchase_request):
		purchase_request=""
		return {"ok":false,"message":"Purchase unavailable. No coins added."}
	return {"ok":true,"message":"Opening the store..."}

func credit_verified_purchase(transaction_id:String,product_id:String)->void:
	if transaction_id.is_empty() or not Commerce.PRODUCTS.has(product_id):return
	if redeemed_transactions.has(transaction_id):
		if is_instance_valid(commerce):commerce.acknowledge(transaction_id)
		return
	var amount:int=int(Commerce.PRODUCTS[product_id])
	coins+=amount;redeemed_transactions[transaction_id]=product_id
	if not save_player_progress():
		coins-=amount;redeemed_transactions.erase(transaction_id)
		purchase_request=commerce.active_request_id() if is_instance_valid(commerce) else ""
		monetization_notice("Purchase saved by the store. Coins will retry.")
		return
	# Finish the native transaction only after wallet + dedup key commit.
	if is_instance_valid(commerce):commerce.acknowledge(transaction_id)
	purchase_request=commerce.active_request_id() if is_instance_valid(commerce) else ""
	monetization_notice("+%d COINS"%amount)

func purchase_failed(request_id:String,_message:String)->void:
	if request_id!=purchase_request:return
	purchase_request=""
	monetization_notice("Purchase not completed. No coins added.")

func purchase_pending(request_id:String)->void:
	if request_id!=purchase_request:return
	purchase_request=""
	monetization_notice("Waiting for store approval")

func monetization_notice(message:String)->void:
	if not is_instance_valid(ui):return
	ui.toast=message;ui.toast_time=3.0;ui.refresh()

func toggle_pause() -> void:
	if phase!="playing":return
	get_tree().paused=not get_tree().paused
	player.dragged=false
	player.touch_index=-1
	player.joystick=Vector2.ZERO
	ui.refresh()

func select_map(id:String)->void:
	if phase!="title" or not MAPS.has(id):return
	selected_map=id
	audio.set_map(id)
	save_player_progress()
	ui.update_map_preview()
	ui.refresh()

func food_goal_complete()->bool:
	return selected_map!="food" or (food_order_complete() and food_city_goal_complete())

func toggle_music()->void:
	music_enabled=not music_enabled
	if not save_player_progress():
		music_enabled=not music_enabled
		ui.toast="Could not save audio settings. Try again."
		ui.toast_time=2.0
	audio.set_music_enabled(music_enabled)
	ui.refresh()

func toggle_sfx()->void:
	sfx_enabled=not sfx_enabled
	if not save_player_progress():
		sfx_enabled=not sfx_enabled
		ui.toast="Could not save audio settings. Try again."
		ui.toast_time=2.0
	audio.set_sfx_enabled(sfx_enabled)
	ui.refresh()

func food_order_complete()->bool:
	return small_food_collected()>=10 and int(food_collected.get("donut",0))>=4 and int(food_collected.get("cake",0))>=1

func food_city_progress()->Dictionary:
	return city.collection_progress if selected_map=="food" and is_instance_valid(city) and "collection_progress" in city else {"buildings":0,"landmarks":0,"heaps":0}

func food_city_goal_complete()->bool:
	var progress:=food_city_progress()
	for key in FOOD_CITY_GOALS:
		if int(progress.get(key,0))<FOOD_CITY_GOALS[key]:return false
	return true

func small_food_collected()->int:
	var count:=0
	for kind in ["bacon","egg","burger","cookie","berry","sushi","pancake","pizza"]:count+=int(food_collected.get(kind,0))
	return count

func ping(points:=1) -> void:
	if DisplayServer.get_name()=="headless":return
	var tier:=0 if points<4 else 1 if points<20 else 2
	if not ping_cache.has(tier):
		var wav:=AudioStreamWAV.new()
		wav.format=AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate=22050
		var bytes:=PackedByteArray()
		var count:int=[1764,2646,4410][tier]
		var frequency:float=[740.0,510.0,240.0][tier]
		bytes.resize(count*2)
		for i in count:bytes.encode_s16(i*2,int(sin(float(i)/22050*TAU*frequency)*pow(1-float(i)/count,2)*6000))
		wav.data=bytes
		ping_cache[tier]=wav
	sound.stream=ping_cache[tier]
	sound.play()

func _unhandled_input(event:InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ENTER and phase=="title":start_level()
		elif event.keycode==KEY_SPACE and phase=="playing" and is_instance_valid(player) and player.trigger_pulse():get_viewport().set_input_as_handled()
		elif event.keycode==KEY_Q and phase=="playing" and is_instance_valid(player) and player.trigger_skin_skill():get_viewport().set_input_as_handled()
