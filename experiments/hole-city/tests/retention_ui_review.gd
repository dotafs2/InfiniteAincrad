extends SceneTree
## Independent reviewer. Real pointer/touch input plus observation of the
## shipped CanvasItem draw calls; no screenshots or device-GPU claims.
const Rarity=preload("res://fidelity/skin_rarity.gd")
const MapCatalog=preload("res://fidelity/map_catalog.gd")
const Ads=preload("res://fidelity/ads_bridge.gd")

class Video extends RefCounted:
	signal rewarded_earned(request_id:String)
	signal rewarded_closed(request_id:String)
	signal rewarded_failed(request_id:String,message:String)
	signal availability_changed
	var requests:Array[String]=[]
	func sink_city_rewarded_protocol_version()->int:return 1
	func initialize()->void:pass
	func rewarded_available()->bool:return true
	func show_rewarded(id:String)->bool:requests.append(id);return true

class CapturedCarousel extends "res://fidelity/map_carousel.gd":
	var captions:Array[Dictionary]=[]
	func _draw()->void:
		captions.clear()
		super._draw()
	func label_at(message:String,at:Vector2,font_size:int,color:Color)->void:
		captions.append({"text":message,"at":at,"size":font_size})
		super.label_at(message,at,font_size,color)

class CapturedUI extends "res://fidelity/ui.gd":
	var captions:Array[Dictionary]=[]
	var panels:Array[Dictionary]=[]
	var badges:Array[Dictionary]=[]
	var stars:Array[Dictionary]=[]
	var home_symbols:Array[Dictionary]=[]
	var wrapped_lines:Array[Dictionary]=[]
	var wrapped_paragraphs:Array[Dictionary]=[]
	func make_map_carousel()->void:
		# Observe real screenshot-card draw callbacks while forwarding the
		# unchanged production layout, interaction and painting behavior.
		map_carousel=CapturedCarousel.new();map_carousel.game=game;map_carousel.font=font
		var rect:Rect2=responsive_rect(MAP_CAROUSEL_RECT)
		map_carousel.position=rect.position;map_carousel.size=rect.size
		add_child(map_carousel)
		map_carousel.focused.connect(map_focus_changed)
	func _draw()->void:
		captions.clear();panels.clear();badges.clear();stars.clear();home_symbols.clear();wrapped_lines.clear();wrapped_paragraphs.clear()
		super._draw()
		if menu_screen=="holes":skin_list.queue_redraw()
	func text_center(message:String,at:Vector2,font_size:int,tint:=Color.WHITE,outline:=true,target:CanvasItem=null)->void:
		captions.append({"text":message,"at":at+skin_list.position if target==skin_list else responsive_point(at),"size":font_size,"color":tint,"card":target==skin_list})
		super.text_center(message,at,font_size,tint,outline,target)
	func box(rect:Rect2,color:Color,radius:=24,border:=Color("ffffff"),stroke:=2,target:CanvasItem=null)->void:
		var observed:=rect
		if target==skin_list:observed.position+=skin_list.position
		else:observed=responsive_rect(observed)
		panels.append({"rect":observed,"color":color,"border":border})
		super.box(rect,color,radius,border,stroke,target)
	func draw_rarity_badge(id:String,rect:Rect2,target:CanvasItem=null)->void:
		badges.append({"id":id,"rect":rect})
		super.draw_rarity_badge(id,rect,target)
	func star(at:Vector2,radius:float,tint:Color)->void:
		stars.append({"center":at,"radius":radius})
		super.star(at,radius,tint)
	func draw_home_symbol(at:Vector2,size_:float,tint:Color,background:Color)->void:
		home_symbols.append({"center":at,"size":size_})
		super.draw_home_symbol(at,size_,tint,background)
	func text_wrapped(message:String,at:Vector2,width:float,font_size:int,tint:Color)->float:
		var first:int=wrapped_lines.size()
		var last:float=super.text_wrapped(message,at,width,font_size,tint)
		wrapped_paragraphs.append({"text":message,"first":first,"count":wrapped_lines.size()-first,"last":last})
		return last
	func draw_wrapped_line(message:String,at:Vector2,width:float,font_size:int,tint:Color)->void:
		wrapped_lines.append({"text":message,"at":at,"width":width,"size":font_size})
		super.draw_wrapped_line(message,at,width,font_size,tint)

var game:Node3D
var checks:=0
var failures:Array[String]=[]
var seen_badges:Dictionary={}
var touched:Array[String]=[]
var detail_measurements:Array[Dictionary]=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frames(count:=2)->void:
	for i in count:await process_frame
func target(id:String)->Button:
	for b in game.ui.buttons:
		if b.name==id or b.text==id:return b
	return null
func touch_at(at:Vector2)->void:
	for pressed in [true,false]:
		var event:=InputEventScreenTouch.new()
		event.index=0;event.position=at;event.pressed=pressed
		root.push_input(event,true);await frames()
func tap(id:String)->void:
	var b:=target(id)
	check(b!=null,"Actual viewport target exists: "+id)
	if b==null:return
	touched.append(id)
	await touch_at(b.get_global_rect().get_center())
func settle_maps()->void:
	# Advance only the real cosmetic interpolation for deterministic headless
	# measurement; navigation itself still enters through actual touch events.
	for index in 40:
		if not game.ui.map_carousel.busy():break
		game.ui.map_carousel._process(.1)
		await frames(1)
	await frames(2)
func has_map_text(message:String)->bool:
	for item in game.ui.map_carousel.captions:
		if item.text==message:return true
	return false
func has_text(message:String)->bool:
	for item in game.ui.captions:
		if item.text==message:return true
	return false
func caption_at(y:float,message:String)->bool:
	for item in game.ui.captions:
		if is_equal_approx(item.at.y,game.ui.responsive_y(y)) and item.text==message:return true
	return false
func navigation_layout(active:String,label:String,primary_page:=true)->void:
	# Observe actual targets and draw callbacks independently of the UI's order arrays.
	var ids:Array[String]=["holes-home","store-nav","holes-nav"]
	var labels:Array[String]=["HOME","STORE","HOLES"]
	var destinations:Array[String]=["home","store","holes"]
	var selected_size:=0
	var other_sizes:Array[int]=[]
	for index in 3:
		var b:Button=target(ids[index])
		check(b!=null,label+": shared dock exposes "+labels[index])
		if b==null:return
		var rect:Rect2=b.get_rect()
		check(rect.is_equal_approx(Rect2(20+index*172,game.ui.size.y-106,156,74)),label+": HOME / STORE / HOLES retain equal left-to-right bottom targets: "+labels[index])
		check(b.disabled==(primary_page and active==destinations[index]),label+": only the current primary destination is disabled: "+labels[index])
		var painted:Dictionary={}
		for panel in game.ui.panels:
			if panel.rect.is_equal_approx(rect):painted=panel
		check(not painted.is_empty(),label+": painted dock panel matches its actual tap rectangle: "+labels[index])
		if not painted.is_empty():
			var color:Color=painted.color
			check(color.get_luminance()>.85 if active==destinations[index] else color.get_luminance()<.45,label+": only the active destination has a bright foreground pill: "+labels[index])
		var caption:Dictionary={}
		for item in game.ui.captions:
			if item.text==labels[index] and rect.has_point(item.at):caption=item
		check(not caption.is_empty(),label+": destination label is drawn inside its own tap target: "+labels[index])
		if not caption.is_empty():
			if active==destinations[index]:selected_size=int(caption.size)
			else:other_sizes.append(int(caption.size))
	check(selected_size>0 and other_sizes.all(func(value:int)->bool:return value<selected_size),label+": active destination label is more prominent")
	var home:Button=target("holes-home")
	check(game.ui.home_symbols.size()==1,label+": HOME draws exactly one authored house icon")
	for symbol in game.ui.home_symbols:
		var half:float=float(symbol.size)*.5
		check(home.get_rect().encloses(Rect2(symbol.center-Vector2.ONE*half,Vector2.ONE*half*2)),label+": mapped house icon remains inside the actual left HOME target")
func skin_card_caption_layout(label:String)->void:
	for index in game.ui.card_skin_ids.size():
		var id:String=game.ui.card_skin_ids[index]
		var definition:Dictionary=game.skin_definition(id)
		var rect:Rect2=game.ui.slot_rect(index)
		var expected:Array[String]=[str(definition.name)]
		if int(definition.variant_index)>0:
			expected=[str(game.skin_definition(definition.model_id).name),str(definition.palette.name)]
		var measured:Array[Rect2]=[]
		for text in expected:
			var found:Dictionary={}
			for caption in game.ui.captions:
				if caption.get("card",false) and caption.text==text and rect.has_point(caption.at):found=caption;break
			check(not found.is_empty(),label+": full base/palette caption appears in its own card: "+id+" / "+text)
			if found.is_empty():continue
			var font_size:int=int(found.size)
			var width:float=game.ui.font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
			var ascent:float=game.ui.font.get_ascent(font_size)
			var descent:float=game.ui.font.get_descent(font_size)
			var glyph:=Rect2(found.at-Vector2(width*.5,ascent),Vector2(width,ascent+descent))
			check(width<=140 and glyph.position.x>=rect.position.x+8 and glyph.end.x<=rect.end.x-8,label+": complete caption fits its actual card without ellipsis: "+id)
			check(glyph.position.y>=rect.position.y+100 and glyph.end.y<=rect.position.y+137,label+": caption stays above the actual rarity badge: "+id)
			check(font_size>=10,label+": caption retains its minimum readable authored font: "+id)
			measured.append(glyph)
		if measured.size()==2:check(measured[0].end.y<=measured[1].position.y,label+": base and palette captions have separate nonoverlapping lines: "+id)

func skin_detail_layout(label:String)->void:
	var detail_card:=Rect2()
	for panel in game.ui.panels:
		if is_equal_approx(panel.rect.position.x,20) and is_equal_approx(panel.rect.size.x,500) and panel.color==game.ui.PAPER:
			detail_card=panel.rect
	check(detail_card.has_area(),label+": actual draw emits the white skin detail card")
	var paragraph:Dictionary={}
	for item in game.ui.wrapped_paragraphs:
		if item.text==game.ui.skin_detail_text():paragraph=item
	check(not paragraph.is_empty(),label+": actual skin description emits wrapped draw lines")
	if paragraph.is_empty() or not detail_card.has_area():return
	var first:int=int(paragraph.first)
	var count:int=int(paragraph.count)
	check(count>=1 and count<=2,label+": original skin description stays within two lines")
	var trigger_baseline:=-1.0
	for item in game.ui.captions:
		if item.text==game.ui.skin_trigger_text() and detail_card.has_point(item.at):trigger_baseline=float(item.at.y)
	var final_baseline:=-1.0
	var first_baseline:=-1.0
	var lowest_edge:=-1.0
	for index in range(first,first+count):
		var line:Dictionary=game.ui.wrapped_lines[index]
		var at:Vector2=line.at
		var font_size:int=int(line.size)
		var width:float=game.ui.font.get_string_size(line.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		var ascent:float=game.ui.font.get_ascent(font_size)
		var descent:float=game.ui.font.get_descent(font_size)
		var glyph_rect:=Rect2(at-Vector2(0,ascent),Vector2(width,ascent+descent))
		check(detail_card.encloses(glyph_rect),label+": measured description glyph bounds stay inside the actual white card")
		check(width<=float(line.width) and font_size==16 and is_equal_approx(float(line.width),468),label+": description preserves authored font size and wrapping width")
		if index==first:first_baseline=at.y
		else:check(is_equal_approx(at.y-final_baseline,21),label+": paragraph retains ordinary 21-unit line spacing")
		final_baseline=at.y;lowest_edge=at.y+descent
	check(trigger_baseline>=0 and first_baseline>trigger_baseline+12,label+": skin description appears below its actual trigger caption")
	check(is_equal_approx(float(paragraph.last),final_baseline) and final_baseline<detail_card.end.y,label+": returned final baseline is the actual last line inside the card")
	check(lowest_edge<target("unlock-random").get_rect().position.y,label+": wrapped description clears the actual unlock target")
	detail_measurements.append({"skin":game.ui.preview_skin_id,"layout":label,"canvas_height":game.ui.size.y,"card_top":detail_card.position.y,"card_bottom":detail_card.end.y,"lines":count,"first_baseline":first_baseline,"last_baseline":final_baseline,"lowest_glyph_edge":lowest_edge})
func layout(label:String)->void:
	check(not game.ui.captions.is_empty(),label+": actual draw callback produced text")
	var buttons:Array=game.ui.buttons
	for i in buttons.size():
		var b:Button=buttons[i]
		if b.has_meta("skin_id") and b.disabled:continue
		var rect:=b.get_rect()
		if b.get_parent()==game.ui.skin_list:rect.position+=game.ui.skin_list.position
		check(b.visible and Rect2(16,16,508,game.ui.size.y-32).encloses(rect),label+": visible control inside phone margins "+b.name)
		check(minf(b.size.x,b.size.y)*375.0/540.0>=44.0,label+": minimum 44-point touch target at 375-point width "+b.name)
		for j in range(i+1,buttons.size()):
			if buttons[j].has_meta("skin_id") and buttons[j].disabled:continue
			var other:Rect2=buttons[j].get_rect()
			if buttons[j].get_parent()==game.ui.skin_list:other.position+=game.ui.skin_list.position
			check(not rect.intersects(other),label+": nonoverlapping controls "+b.name+" / "+buttons[j].name)
		if b.text.is_empty():
			var painted:=false
			for panel in game.ui.panels:
				if panel.rect.is_equal_approx(rect):painted=true
				# Circular gameplay buttons intentionally have larger finger targets.
				if b.name in ["pulse-action","skin-action"] and rect.encloses(panel.rect) and panel.rect.get_area()>=rect.get_area()*.6:painted=true
			check(painted,label+": transparent hotspot has a matching visible panel "+b.name)
	for item in game.ui.captions:
		var width:float=game.ui.font.get_string_size(item.text,HORIZONTAL_ALIGNMENT_LEFT,-1,item.size).x
		check(item.at.x-width*.5>=8.0 and item.at.x+width*.5<=532.0,label+": caption fits phone horizontally: "+item.text)
	for badge in game.ui.badges:
		seen_badges[badge.id]=true
		var index:int=Rarity.ORDER.find(badge.id)
		check(index>=0 and has_text(Rarity.NAMES[index].to_upper()),label+": actual badge paints the declared rarity "+badge.id)

func rate_oracle(label:String)->void:
	# Independently reconstruct the eligible pools from ownership, not offer().
	var counts:Array[int]=[0,0,0,0,0,0]
	var group:String=game.ui.active_skin_group()
	for definition in game.SKIN_DEFS:
		if (definition.group==group or group=="collection") and not game.owned_skin_ids.has(definition.id):
			counts[Rarity.ORDER.find(definition.rarity)]+=1
	var counters:Dictionary=game.draw_pity[group]
	var floor_rank:=0
	for gate in [[3,"epic",5],[4,"legendary",10],[5,"prismatic",20]]:
		var eligible:=0
		for i in range(gate[0],6):eligible+=counts[i]
		if eligible>0 and int(counters[gate[1]])>=gate[2]-1:floor_rank=gate[0]
	var weights:Array[int]=[]
	var total:=0
	for i in 6:
		var weight:int=[4500,2800,1600,800,250,50][i] if counts[i]>0 and i>=floor_rank else 0
		weights.append(weight);total+=weight
	for i in 6:
		var y:=182.0+i*76
		var chance:float=100.0*weights[i]/total if total>0 else 0.0
		check(caption_at(y+30,"%.2f%%"%chance),label+": drawn tier chance matches current eligible pool "+Rarity.ORDER[i])
		check(caption_at(y+54,"Each skin: %.2f%%"%(chance/maxi(1,counts[i]))),label+": drawn per-skin chance matches current pool "+Rarity.ORDER[i])
		check(caption_at(y+55,"%d left"%counts[i]),label+": current remaining count "+Rarity.ORDER[i])
	check(has_text("No repeats. Owned tiers leave the pool."),label+": no-duplicate disclosure is drawn")
	check(has_text("Epic+ %d  ·  Legendary+ %d  ·  Prismatic %d"%[5-int(counters.epic),10-int(counters.legendary),20-int(counters.prismatic)]),label+": countdown uses this tab's actual counters")
	layout(label)

func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	Input.emulate_mouse_from_touch=true
	root.size=Vector2i(375,667)
	root.content_scale_size=Vector2i(540,960)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game);await frames(4)
	game.set_process(false);game.set_physics_process(false)
	var old:Control=game.ui
	var layer:Node=old.get_parent();layer.remove_child(old);old.free()
	game.ui=CapturedUI.new();game.ui.game=game;layer.add_child(game.ui);await frames(3)
	check(game.selected_skin_id==Rarity.NEW_PLAYER_SKIN and game.owned_skin_ids==[Rarity.NEW_PLAYER_SKIN],"Fresh profile has exactly its Common starter")
	layout("home")
	navigation_layout("home","initial home")
	check(target("home-settings")!=null and target("audio-music")==null and target("home-play-dock")==null,"Home keeps settings secondary and has one primary PLAY")
	check(target("PLAY").get_rect().get_area()>target("holes-home").get_rect().get_area()*2 and target("PLAY").get_rect().end.y<target("holes-home").position.y,"Home's single PLAY remains the primary action above the dock")
	await tap("store-nav")
	check(game.ui.menu_screen=="store","Actual center dock touch opens Store")
	navigation_layout("store","store after center touch")
	await tap("holes-nav")
	check(game.ui.menu_screen=="holes","Actual right dock touch opens Holes")
	navigation_layout("holes","holes after right touch")
	skin_detail_layout("short starter")
	await tap("holes-home")
	check(game.ui.menu_screen=="home" and game.ui.map_carousel.visible and not game.ui.hero.visible,"Actual left dock touch restores Home and its screenshot row")
	navigation_layout("home","home after left touch")
	await tap("home-settings");layout("settings")
	navigation_layout("home","settings parent destination",false)
	check(target("audio-music")!=null and target("audio-sfx")!=null and target("feedback-haptics")!=null and target("release-info")!=null,"Secondary settings keeps audio, haptics, privacy and support discoverable")
	await tap("release-info")
	var info:Control=game.ui.release_info
	check(is_instance_valid(info) and info.tabs[0].disabled,"Real settings touch opens the Privacy reader")
	var info_text:String=info.body.text
	for index in 4:
		var wheel:=InputEventMouseButton.new();wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN;wheel.pressed=true;wheel.position=info.body.get_global_rect().get_center()
		root.push_input(wheel,true);await frames()
	var reading_position:float=info.body.get_v_scroll_bar().value
	check(reading_position>0,"Actual wheel input advances the Privacy reader before layout changes")
	root.size=Vector2i(430,932);await frames(4);game.ui.update_viewport_layout();await frames()
	check(is_instance_valid(info) and game.ui.release_info==info,"Changed portrait layout retains the existing Privacy overlay instance")
	if is_instance_valid(info):
		check(info.body.text==info_text and is_equal_approx(info.body.get_v_scroll_bar().value,reading_position),"Layout-only refresh preserves the actual privacy page and reading position")
		var close:Button=null
		for candidate in info.find_children("*","Button",true,false):
			if candidate.text=="BACK TO GAME":close=candidate
		check(close!=null,"Preserved reader retains its actual close button")
		if close!=null:await touch_at(close.get_global_rect().get_center())
	await frames()
	await tap("settings-back")
	for portrait in [Vector2i(430,932),Vector2i(440,956)]:
		root.size=portrait;await frames(4);game.ui.update_viewport_layout();await frames()
		layout("tall portrait "+str(portrait))
		navigation_layout("home","tall portrait "+str(portrait))
		check(game.ui.size.y>960,"Tall portrait uses the extra safe canvas height")
		check(is_equal_approx(target("holes-home").get_rect().end.y,game.ui.size.y-32),"Navigation anchors to the actual safe bottom")
		check(is_equal_approx(target("home-settings").position.y,20),"Top settings stays near the safe top instead of recentering")
		check(game.ui.map_carousel.size.y>game.ui.MAP_CAROUSEL_RECT.size.y,"Screenshot row uses the extra safe portrait height")
		var active_photo:TextureRect=game.ui.map_carousel.photos[game.ui.map_carousel.focus_index]
		var active_card:Rect2=game.ui.map_carousel.card_rect(game.ui.map_carousel.focus_index)
		check(active_card.encloses(active_photo.get_rect()),"Actual screenshot remains inside its responsive rounded card")
		check(game.ui.map_carousel.position.y+game.ui.map_carousel.size.y<target("home-play").position.y,"The larger screenshot row clears the actual PLAY target")
		check(not game.ui.hero.visible and game.ui.hero_view.render_target_update_mode==SubViewport.UPDATE_DISABLED,"Tall Home does not restart the hidden live map viewport")
	root.size=Vector2i(375,667);await frames(4);game.ui.update_viewport_layout();await frames()
	game.ui.open_maps();await frames()
	check(game.ui.menu_screen=="home" and game.ui.map_carousel.visible and not game.ui.hero.visible,"Legacy map entry opens the same Home row without a split chooser")
	check(game.ui.map_carousel.definitions.size()==4 and game.ui.map_carousel.photos.size()==4 and game.MAPS.size()==4,"Exactly the four playable worlds have actual screenshot cards")
	check(has_text("CHOOSE YOUR WORLD") and has_text("SWIPE TO EXPLORE"),"Home paints one concise world-selection heading and swipe affordance")
	layout("world screenshot row")
	navigation_layout("home","world row Home destination")
	game.ui.map_carousel.focus_map("city",false,true);await settle_maps()
	for index in game.ui.map_carousel.definitions.size():
		var definition:Dictionary=game.ui.map_carousel.definitions[index]
		if index>0:await tap("map-next");await settle_maps()
		var id:String=definition.id
		var photo:TextureRect=game.ui.map_carousel.photos[index]
		check(game.ui.map_carousel.current_id()==id and game.selected_map==id and game.ui.menu_screen=="home","Actual arrow touch focuses and selects the earned world "+id)
		check(photo.texture!=null and photo.texture.get_width()>0 and photo.texture.get_height()>0 and photo.texture.resource_path.ends_with("/"+id+".png"),"Screenshot card owns its real packaged image: "+id)
		check(has_map_text(str(definition.name).to_upper()) and has_map_text("WORLD %02d  ·  %d SEC"%[index+1,int(game.map_round_seconds(id))]),"Actual card draw paints the world name and real timer: "+id)
		check(has_map_text("READY TO PLAY") and target("home-play").text=="PLAY" and not target("home-play").disabled,"Earned focused world exposes one ready PLAY action: "+id)
	check(target("map-next").disabled and not target("map-previous").disabled,"Final world disables the forward boundary instead of wrapping")
	for id in ["animals","stars"]:
		check(not game.ui.map_carousel.definitions.any(func(definition):return str(definition.id)==id) and target("map-"+id)==null,"Unbuilt future world has no misleading screenshot or separate card button: "+id)
		var old_map:String=game.selected_map
		game.select_map(id)
		check(game.selected_map==old_map and not game.map_unlocked(id),"Omitted future world remains unavailable to the runtime: "+id)
	game.ui.pick_map("city");await settle_maps()
	check(game.selected_map=="city" and game.ui.menu_screen=="home" and game.ui.map_carousel.current_id()=="city","Compatibility pick_map focuses the existing Home row")
	await tap("map-next");await settle_maps()
	check(game.selected_map=="food" and game.ui.map_carousel.visible,"Actual next-arrow touch selects Food without another screen")
	await tap("map-previous");await settle_maps()
	check(game.selected_map=="city" and target("map-previous").disabled,"Actual previous-arrow touch returns to the first world")
	game.best_scores={"city":1357,"food":2468}
	game.ui.map_carousel.queue_redraw();await frames()
	check(has_map_text("BEST  1357 POINTS"),"City screenshot card draws its actual personal record")
	await tap("map-next");await settle_maps()
	check(has_map_text("BEST  2468 POINTS"),"Food screenshot card draws its separate actual personal record")
	await tap("map-previous");await settle_maps()

	await tap("holes-nav")
	check(game.ui.preview_skin_id==Rarity.NEW_PLAYER_SKIN,"Collection initially focuses actual starter")
	for id in game.ui.skin_order:
		game.ui.scroll_to_skin(id);game.ui.select_hole_slot(id);game.ui.toast_time=0;game.ui.queue_redraw();await frames()
		layout("collection "+id)
		skin_card_caption_layout("short collection "+id)
		skin_detail_layout("short collection "+id)
		check(game.ui.badges.size()==game.ui.card_skin_ids.size(),"Every visible skin has one actual rarity badge")
		for i in game.ui.card_skin_ids.size():
			check(game.ui.badges[i].id==game.skin_definition(game.ui.card_skin_ids[i]).rarity,"Badge belongs to its actual card")
	check(seen_badges.size()==6,"All six rarities were drawn during continuous scrolling")
	root.size=Vector2i(440,956);await frames(4);game.ui.update_viewport_layout();await frames()
	check(game.ui.size.y>960,"Tall all-skin description review uses the expanded safe canvas")
	for id in game.ui.skin_order:
		game.ui.scroll_to_skin(id);game.ui.select_hole_slot(id);game.ui.toast_time=0;game.ui.queue_redraw();await frames()
		skin_detail_layout("tall collection "+id)
		skin_card_caption_layout("tall collection "+id)
	root.size=Vector2i(375,667);await frames(4);game.ui.update_viewport_layout();await frames()
	game.ui.select_hole_slot(Rarity.NEW_PLAYER_SKIN);game.ui.toast_time=0;game.ui.queue_redraw();await frames()
	game.draw_pity.collection={"epic":0,"legendary":0,"prismatic":0}
	await tap("skin-rates")
	rate_oracle("Unified current rates")
	var scroll_before:float=game.ui.skin_scroll
	await tap("rates-back")
	check(game.ui.skin_scroll==scroll_before,"Rates BACK preserves continuous scroll position")
	await tap("skin-rates")
	for fixture in [{"epic":4,"legendary":3,"prismatic":7},{"epic":4,"legendary":9,"prismatic":19}]:
		game.draw_pity.collection=fixture;game.ui.queue_redraw();await frames()
		rate_oracle("Unified guarantee "+str(fixture.prismatic))
	var original_owned:Array=game.owned_skin_ids.duplicate()
	for definition in game.SKIN_DEFS:
		if not game.owned_skin_ids.has(definition.id):game.owned_skin_ids.append(definition.id)
	game.ui.queue_redraw();await frames();rate_oracle("Unified complete")
	await tap("rates-back")
	check(target("unlock-random").disabled and has_text("COLLECTION COMPLETE"),"Completed collection cannot spend coins on an invisible or empty offer")
	game.owned_skin_ids.assign(original_owned)
	await tap("store-nav");layout("store")
	check(has_text("DIAMONDS") and has_text("+3 DIAMONDS") and not has_text("FREE 5 GEMS"),"Store presents a concise actual rewarded diamond offer")
	check(target("store-diamond-video").disabled,"Missing rewarded SDK disables the diamond video")
	await tap("diamond-shop");layout("purchase fallback")
	check(has_text("DIAMOND SHOP") and has_text("100 DIAMONDS") and has_text("360 DIAMONDS") and has_text("1800 DIAMONDS") and has_text("UNAVAILABLE"),"Diamond packs display amounts and honest unavailable prices")
	for i in 3:
		check(target("purchase-%d"%i).disabled,"Unsupported native purchase is visibly disabled")
		var coins_before:int=game.coins;var diamonds_before:int=game.gems
		await tap("purchase-%d"%i)
		check(game.coins==coins_before and game.gems==diamonds_before and game.purchase_request.is_empty(),"Disabled purchase cannot grant imaginary currency")
	await tap("purchase-back")
	check(game.ui.menu_screen=="store","Native purchase BACK returns to store")
	await tap("holes-home");await tap("PLAY")
	for node in game.world.find_children("*","Node",true,false):node.set_physics_process(false)
	# Keep player input enabled; only suspend unrelated physics for this UI probe.
	check(game.phase=="intro" and has_text("01:30") and has_text("SWIPE TO EAT"),"Sunny City entry paints its actual 90-second timer and concise tutorial")
	await touch_at(Vector2(120,420))
	check(game.phase=="playing" and game.player.touch_index==-1,"Released intro touch starts play without stuck input")
	game.player.score=1234;game.remaining=61.1;game.ui.queue_redraw();await frames()
	check(has_text("01:02") and has_text("1234 POINTS") and has_text("+123 COINS"),"HUD paints ceiling time and the live score-derived reward")
	layout("playing")
	await tap("pause-action");layout("paused")
	check(paused,"Actual pause target pauses tree")
	await tap("KEEP PLAYING")
	check(not paused and game.phase=="playing","Pause resume preserves active round")
	game.remaining=.01;game._physics_process(.02);await frames()
	check(game.phase=="complete" and has_text("TIME'S UP!") and has_text("1234 POINTS"),"Actual timer expiry produces honest timed result")
	check(game.round_score_coins==123 and game.round_win_coins==0 and has_text("+123 COINS"),"Timed result draws 123 coins for 1234 points")
	layout("timed result")
	check(target("double-round-coins")==null and target("extend-video").disabled and not target("extend-diamonds").disabled and target("coin-boost-video").disabled and not target("coin-boost-diamonds").disabled,"Result offers one independent boost and continuation with unavailable videos disabled")
	check(target("extend-video").text=="NOT READY" and has_text("1.5× COINS") and has_text("+30 SECONDS") and not has_text("100 pts = 1 coin · Max 30 · Finish with points: +5"),"Result shows two concise offers without the old rule paragraphs")
	game.gems=20;game.ui.refresh();await frames()
	var before_boost_coins:int=game.coins
	await tap("coin-boost-diamonds")
	check(game.phase=="complete" and game.coins==before_boost_coins+61 and game.gems==18 and game.round_coins==184,"Actual two-diamond touch boosts 123 coins to 184 exactly once")
	check(target("coin-boost-video")==null and target("coin-boost-diamonds")==null and target("extend-diamonds")!=null,"Claimed boost disappears while the independent continuation remains")
	layout("boosted result")
	var original_world:int=game.world.get_instance_id()
	var original_coins:int=game.coins
	var original_diamonds:int=game.gems
	await tap("extend-diamonds")
	check(game.phase=="playing" and is_equal_approx(game.remaining,30.0) and game.world.get_instance_id()==original_world,"Actual diamond touch continues the existing world for 30 seconds")
	check(game.gems==original_diamonds-2 and game.coins==original_coins,"Continuation spends diamonds without replaying settled coins")
	game.player.score=2200;game.remaining=.01;game._physics_process(.02);await frames()
	check(target("extend-video")==null and target("extend-diamonds")==null and target("coin-boost-video")==null and game.round_coins==330 and game.coins==original_coins+146,"Second timeout credits new score and its boost without offering duplicate choices")
	layout("extended result")
	# A controlled provider checks actual touch routing and earned/closed order.
	# It is explicitly a test boundary, not native ad playback evidence.
	game.start_level();game.begin_play()
	for node in game.world.find_children("*","Node",true,false):node.set_physics_process(false)
	game.player.score=500;game.remaining=.01;game._physics_process(.02);await frames()
	game.ads.free();game.ads=Ads.new();game.add_child(game.ads)
	var video:=Video.new()
	check(game.ads.bind_test_native(video),"Controlled provider binds the actual versioned reward boundary")
	game.ads.rewarded_completed.connect(game.credit_round_double)
	game.ads.rewarded_closed.connect(game.reward_video_closed)
	game.ads.rewarded_failed.connect(game.reward_video_failed)
	game.ads.availability_changed.connect(game.refresh_monetization_ui)
	game.ads.initialize()
	game.ui.refresh();await frames()
	await tap("extend-video")
	check(video.requests.size()==1 and game.reward_video_pending(),"Actual result touch requests exactly one authenticated-provider video")
	check(target("extend-video").disabled and target("extend-diamonds").disabled and target("coin-boost-video").disabled and target("coin-boost-diamonds").disabled and target("result-home").disabled and target("result-play-again").disabled,"Pending reward visibly disables both offer groups and exit controls")
	check(has_text("Finish & close the video") and target("extend-video").tooltip_text.contains("close the ad"),"Short pending state and secondary tooltip retain the earned-and-closed condition")
	layout("pending extension video")
	video.rewarded_earned.emit(video.requests[0]);await frames()
	check(game.phase=="complete" and game.remaining==0.0,"Earned callback does not run the timer under an open ad")
	video.rewarded_closed.emit(video.requests[0]);await frames()
	check(game.phase=="playing" and is_equal_approx(game.remaining,30.0) and not game.reward_video_pending(),"Actual provider dismissal resumes the same round with 30 seconds")
	game.remaining=.01;game._physics_process(.02);await frames()
	check(target("extend-video")==null and target("extend-diamonds")==null,"A rewarded continuation also disappears after its single use")
	var before_video_boost:int=game.coins
	await tap("coin-boost-video")
	check(video.requests.size()==2 and game.reward_video_pending(),"The unused independent coin boost requests one actual controlled-provider video")
	video.rewarded_earned.emit(video.requests[1]);await frames()
	check(game.coins==before_video_boost and game.phase=="complete","Earned boost waits for dismissal before crediting coins")
	video.rewarded_closed.emit(video.requests[1]);await frames()
	check(game.coins==before_video_boost+25 and game.round_coins==75 and target("coin-boost-video")==null,"Dismissed video boosts the50-coin receipt once and removes the consumed choice")
	await tap("HOME")
	check(game.phase=="title" and game.ui.menu_screen=="home","Result HOME returns to true home")
	await touch_at(Vector2(180,195))
	check(game.phase=="title" and game.ui.menu_screen=="home","Empty home space is not a hidden launch hotspot")
	game.audio.set_process(false) # Freeze pending route changes before decoder teardown.
	game.audio.music.stop();OS.delay_msec(120);await process_frame
	game.free();await frames()
	var result:={"checks":checks,"failures":failures,"input":"Screen touch press/release through portrait viewports","captured":"Shipped CanvasItem text, wrapped-line baselines, panels and rarity badges via subclass forwarding to super","rarities_drawn":seen_badges.keys(),"touch_events":touched,"skin_detail_measurements":detail_measurements,"scope":"Headless layout/input and runtime text evidence. No browser pixels, native purchase provider or phone GPU claim."}
	print("RETENTION_UI_REVIEW "+JSON.stringify(result))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	quit(0 if failures.is_empty() else 1)
