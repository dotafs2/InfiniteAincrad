extends Control
## One bounded row of baked screenshots; browsing locked worlds never selects them.
signal focused(id:String)
const Catalog=preload("res://fidelity/map_catalog.gd")
const PHOTO_SHADER=preload("res://fidelity/map_photo.gdshader")
const CARD_WIDTH:=436.0
const STEP:=454.0
const ACCENTS:={"city":Color("268c84"),"food":Color("c45473"),"toys":Color("8461bf"),"frost":Color("3e8ec2")}
var game:Node
var font:Font
var definitions:Array[Dictionary]=[]
var photos:Array[TextureRect]=[]
var focus_index:=0
var scroll:=0.0
var target_scroll:=0.0
var pointer:=-2
var pointer_start:=Vector2.ZERO
var pointer_last:=Vector2.ZERO
var pointer_dragged:=false
var pointer_start_scroll:=0.0
var styles:Dictionary={}

func _ready()->void:
	clip_contents=true;mouse_filter=Control.MOUSE_FILTER_IGNORE
	for definition in Catalog.DEFS:
		if not bool(definition.available):continue
		definitions.append(definition)
		var photo:=TextureRect.new()
		photo.texture=load("res://assets/map_thumbnails/"+str(definition.id)+".png")
		photo.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		photo.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
		photo.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var material:=ShaderMaterial.new();material.shader=PHOTO_SHADER
		photo.material=material;add_child(photo);photos.append(photo)
	resized.connect(layout_photos)
	focus_map(game.selected_map,false)
	layout_photos()

func current_id()->String:
	return str(definitions[focus_index].id) if not definitions.is_empty() else "city"

func busy()->bool:return pointer!=-2 or absf(scroll-target_scroll)>2.0

func card_rect(index:int)->Rect2:
	return Rect2((size.x-CARD_WIDTH)*.5+index*STEP-scroll,10,CARD_WIDTH,maxf(340,size.y-20))

func photo_rect(index:int)->Rect2:
	var rect:=card_rect(index)
	return Rect2(rect.position+Vector2(10,10),Vector2(rect.size.x-20,rect.size.y-158))

func layout_photos()->void:
	for index in photos.size():
		var rect:=photo_rect(index)
		photos[index].position=rect.position;photos[index].size=rect.size
		photos[index].material.set_shader_parameter("extent",rect.size)
		photos[index].modulate=Color.WHITE if game.map_unlocked(str(definitions[index].id)) else Color(.76,.80,.87,1)
	queue_redraw()

func cancel_pointer(snap:=false)->void:
	pointer=-2;pointer_dragged=false;target_scroll=focus_index*STEP
	if snap:scroll=target_scroll;layout_photos()

func focus_map(id:String,animate:=true,notify:=false)->void:
	for index in definitions.size():
		if str(definitions[index].id)==id:
			focus_index=index;target_scroll=index*STEP
			if not animate:scroll=target_scroll
			layout_photos()
			if notify:focused.emit(id)
			return

func step(direction:int)->void:
	if definitions.is_empty():return
	cancel_pointer()
	focus_map(str(definitions[clampi(focus_index+direction,0,definitions.size()-1)].id),true,true)

func pointer_event(index:int,at:Vector2,pressed:bool,canceled:=false)->bool:
	if pressed:
		if pointer!=-2 or not Rect2(Vector2.ZERO,size).has_point(at):return pointer!=-2
		pointer=index;pointer_start=at;pointer_last=at;pointer_start_scroll=scroll;pointer_dragged=false
		return true
	if index!=pointer:return pointer!=-2
	var moved:=pointer_dragged or absf(at.x-pointer_start.x)>10
	pointer=-2
	if canceled:
		target_scroll=focus_index*STEP;return true
	var next:=focus_index
	if moved:
		next=clampi(roundi(scroll/STEP),0,definitions.size()-1)
		if next==focus_index and absf(at.x-pointer_start.x)>55:
			next=clampi(focus_index+(1 if at.x<pointer_start.x else -1),0,definitions.size()-1)
	elif Rect2(Vector2.ZERO,size).has_point(at):
		for i in definitions.size():
			if card_rect(i).has_point(at):next=i;break
	focus_map(str(definitions[next].id),true,true)
	return true

func drag_pointer(at:Vector2)->void:
	if pointer==-2:return
	pointer_last=at
	if absf(at.x-pointer_start.x)>10:pointer_dragged=true
	if pointer_dragged:
		scroll=clampf(pointer_start_scroll+pointer_start.x-at.x,0,maxf(0,(definitions.size()-1)*STEP))
		layout_photos()

func _process(delta:float)->void:
	if not visible:return
	if pointer==-2 and absf(scroll-target_scroll)>.05:
		scroll=lerpf(scroll,target_scroll,1-exp(-16*delta))
		if absf(scroll-target_scroll)<.2:scroll=target_scroll
		layout_photos()

func panel(rect:Rect2,color:Color,border:Color,width:=2)->void:
	var key:=color.to_html()+border.to_html()+str(width)
	if not styles.has(key):
		var style:=StyleBoxFlat.new();style.bg_color=color
		style.set_corner_radius_all(28);style.set_border_width_all(width);style.border_color=border
		styles[key]=style
	draw_style_box(styles[key],rect)

func label_at(message:String,at:Vector2,font_size:int,color:Color)->void:
	var width:=font.get_string_size(message,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	draw_string(font,at-Vector2(width*.5,0),message,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func _draw()->void:
	if font==null:return
	for index in definitions.size():
		var rect:=card_rect(index)
		if not rect.intersects(Rect2(Vector2.ZERO,size)):continue
		var id:String=definitions[index].id
		var status:Dictionary=game.map_unlock_status(id)
		var accent:Color=ACCENTS[id]
		var active:bool=index==focus_index
		panel(rect,Color("fffdf7"),Color("fff2ac") if active else Color("bccbeb"),4 if active else 2)
		var photo:=photo_rect(index)
		var center:=rect.get_center().x
		label_at("WORLD %02d  ·  %d SEC"%[index+1,int(game.map_round_seconds(id))],Vector2(center,photo.end.y+24),14,accent)
		label_at(str(definitions[index].name).to_upper(),Vector2(center,photo.end.y+56),26,Color("263467"))
		if bool(status.unlocked):
			label_at("READY TO PLAY",Vector2(center,photo.end.y+88),18,Color("26896b"))
			label_at("BEST  %d POINTS"%int(game.best_scores.get(id,0)),Vector2(center,photo.end.y+116),15,Color("65749c"))
		else:
			label_at(str(status.condition),Vector2(center,photo.end.y+85),18,Color("52658e"))
			var bar:=Rect2(rect.position.x+32,photo.end.y+96,rect.size.x-64,6)
			draw_style_box(progress_style(Color("dfe5f3")),bar)
			var fraction:=float(status.current)/maxf(1,float(status.target))
			if fraction>0:draw_style_box(progress_style(accent),Rect2(bar.position,Vector2(bar.size.x*fraction,6)))
			label_at(str(status.progress),Vector2(center,photo.end.y+124),13,accent)

func progress_style(color:Color)->StyleBoxFlat:
	var key:="bar-"+color.to_html()
	if not styles.has(key):
		var style:=StyleBoxFlat.new();style.bg_color=color;style.set_corner_radius_all(3);styles[key]=style
	return styles[key]
