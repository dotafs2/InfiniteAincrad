extends Control
## Original, short-lived canvas celebration. No emitter nodes, lights or textures.
const Rarity=preload("res://fidelity/skin_rarity.gd")
const DURATION:=1.60
const MAX_PARTICLES:=36
const ORIGIN:=Vector2(270,400)
var ui:Control
var active:=false
var age:=0.0
var burst_count:=0
var particles:Array[Dictionary]=[]
var tint:=Color.WHITE
var focused:=true
var app_suspended:=false

func _ready()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	process_mode=Node.PROCESS_MODE_ALWAYS
	set_process(false)
	hide()

func layout()->void:
	if is_instance_valid(ui):size=ui.size
	if active:queue_redraw()

func start(rarity:String,presentation_seed:int)->void:
	clear()
	var tier:int=maxi(0,Rarity.ORDER.find(rarity))
	tint=Rarity.COLORS[tier]
	var rng:=RandomNumberGenerator.new()
	rng.seed=presentation_seed ^ 0x53A17
	var count:int=mini(MAX_PARTICLES,26+tier*2)
	var turn:float=rng.randf_range(0,TAU)
	for index in count:
		var color:Color=Rarity.RAINBOW_COLORS[index%Rarity.RAINBOW_COLORS.size()] if rarity=="prismatic" else tint
		particles.append({"angle":turn+TAU*float(index)/count+rng.randf_range(-.06,.06),
			"distance":rng.randf_range(132,168),"bend":rng.randf_range(-27,27),
			"delay":rng.randf_range(0,.10),"life":rng.randf_range(1.10,1.48),
			"width":rng.randf_range(2.2,3.4),"color":color,"star":index%5==0})
	age=0;active=true;burst_count+=1
	layout();show();set_process(true);queue_redraw()

func clear()->void:
	active=false;age=0;particles.clear()
	set_process(false);hide();queue_redraw()

func _notification(what:int)->void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:focused=false
	elif what==NOTIFICATION_APPLICATION_FOCUS_IN:focused=true
	elif what==NOTIFICATION_APPLICATION_PAUSED:app_suspended=true
	elif what==NOTIFICATION_APPLICATION_RESUMED:app_suspended=false

func _process(delta:float)->void:
	if not active:return
	if not is_visible_in_tree():clear();return
	if not focused or app_suspended or get_tree().paused:return
	age+=delta
	if age>=DURATION:clear()
	else:queue_redraw()

func position_at(p:Dictionary,u:float)->Vector2:
	var direction:=Vector2.from_angle(float(p.angle))
	var eased:float=1.0-pow(1.0-clampf(u,0,1),4.0)
	var at:Vector2=direction*(80.0+float(p.distance)*eased)
	at+=direction.orthogonal()*sin(u*PI)*float(p.bend)
	at.y=at.y*.66-14.0*sin(u*PI)+14.0*u*u
	return ORIGIN+at

func point(at:Vector2)->Vector2:
	return ui.responsive_point(at)

func _draw()->void:
	if not active or ui==null:return
	# Two faint elliptical waves expand around, rather than wash over, the prize.
	for ring in 2:
		var t:float=(age-float(ring)*.07)/.40
		if t<0 or t>=1:continue
		var outline:=PackedVector2Array()
		var radius:float=78+158*(1-pow(1-t,2))
		for segment in 49:
			var at:=Vector2.from_angle(TAU*float(segment)/48)*radius
			at.y*=.66;outline.append(point(ORIGIN+at))
		draw_polyline(outline,Color(tint,.19*pow(1-t,2)),2.5*(1-t)+.5,true)
	for p in particles:
		var u:float=(age-float(p.delay))/float(p.life)
		if u<=0 or u>=1:continue
		var fade:float=minf(u/.04,1.0)*pow(1-u,.95)
		var head:Vector2=point(position_at(p,u))
		var middle:Vector2=point(position_at(p,maxf(0,u-.055)))
		var tail:Vector2=point(position_at(p,maxf(0,u-.23)))
		var across:Vector2=(head-tail).normalized().orthogonal()*float(p.width)
		var color:Color=p.color
		# A tapered colored ribbon and pearl core stay behind the live 3D model.
		# Explicit triangles remain valid when a slow curved tail folds near expiry.
		# A single concave polygon can self-intersect at that point.
		var mid_color:=Color(color,.55*fade)
		var head_color:=Color(color.lightened(.65),fade)
		draw_primitive(PackedVector2Array([tail,middle+across,middle-across]),
			PackedColorArray([Color(color,0),mid_color,mid_color]),PackedVector2Array())
		draw_primitive(PackedVector2Array([middle+across,head+across*.38,head-across*.38]),
			PackedColorArray([mid_color,head_color,head_color]),PackedVector2Array())
		draw_primitive(PackedVector2Array([middle+across,head-across*.38,middle-across]),
			PackedColorArray([mid_color,head_color,mid_color]),PackedVector2Array())
		draw_circle(head,7.0,Color(color,.09*fade))
		draw_circle(head,3.8,Color(color,.26*fade))
		if bool(p.star):
			var radius:float=(5.2+2.2*sin(u*PI))*(.7+.3*absf(sin(u*17)))
			var star:=PackedVector2Array()
			for axis in 8:
				star.append(head+Vector2.from_angle(float(axis)*PI/4)*(radius if axis%2==0 else radius*.20))
			draw_colored_polygon(star,Color(Color.WHITE,.94*fade))
		else:draw_circle(head,1.7,Color(color.lightened(.9),fade))
