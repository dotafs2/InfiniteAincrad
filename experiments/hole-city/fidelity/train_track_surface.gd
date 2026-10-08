extends RefCounted
## Marks live on the existing cut ground: there is no rail mesh or floor
## spanning a hole. The small mipmapped mask updates only when a bypass changes.
const SIZE:=1024
const HALF:=100.0
const PIXELS_PER_METER:=float(SIZE)/(HALF*2.0)
var base:PackedByteArray
var pixels:PackedByteArray
var texture:ImageTexture
var material:ShaderMaterial
var updates:=0
var last_branches:Array=[]

func build(target:ShaderMaterial,points:Array[Vector2],food:bool)->void:
	material=target
	pixels.resize(SIZE*SIZE);pixels.fill(0)
	var loop:=PackedVector2Array(points);loop.append(loop[0])
	paint_track(loop)
	base=pixels.duplicate()
	upload()
	material.set_shader_parameter("train_marks",texture)
	material.set_shader_parameter("train_tracks_enabled",true)
	material.set_shader_parameter("train_rail_color",Color("fff0b7") if food else Color("c7d9df"))
	material.set_shader_parameter("train_tie_color",Color("a95637") if food else Color("273b4d"))

func refresh(branches:Array)->void:
	if branches==last_branches:return
	last_branches=branches.duplicate(true)
	pixels=base.duplicate()
	for branch in branches:paint_track(branch)
	upload()

func upload()->void:
	var image:=Image.create_from_data(SIZE,SIZE,false,Image.FORMAT_R8,pixels)
	image.generate_mipmaps()
	if texture==null:texture=ImageTexture.create_from_image(image)
	else:texture.update(image)
	updates+=1

func stroke(from:Vector2,to:Vector2,width:float,value:int)->void:
	var a:Vector2=(from+Vector2.ONE*HALF)*PIXELS_PER_METER
	var b:Vector2=(to+Vector2.ONE*HALF)*PIXELS_PER_METER
	var radius:=width*.5*PIXELS_PER_METER
	var low:Vector2i=Vector2i((a.min(b)-Vector2.ONE*(radius+1)).floor()).clamp(Vector2i.ZERO,Vector2i(SIZE-1,SIZE-1))
	var high:Vector2i=Vector2i((a.max(b)+Vector2.ONE*(radius+1)).ceil()).clamp(Vector2i.ZERO,Vector2i(SIZE-1,SIZE-1))
	var along:=b-a;var length2:=maxf(.00001,along.length_squared())
	for y in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			var p:=Vector2(x+.5,y+.5)
			var nearest:=a+along*clampf((p-a).dot(along)/length2,0,1)
			var coverage:=clampf(radius+.5-p.distance_to(nearest),0,1)
			var index:=y*SIZE+x
			pixels[index]=maxi(pixels[index],int(round(float(value)*coverage)))

func paint_track(points:PackedVector2Array)->void:
	if points.size()<2:return
	# Draw the complete bed first so it cannot cover the bright rails at joins.
	for i in points.size()-1:stroke(points[i],points[i+1],1.45,44)
	var distance:=0.0;var next_tie:=0.0
	for i in points.size()-1:
		var a:=points[i];var b:=points[i+1];var segment:=a.distance_to(b)
		if segment<.001:continue
		var forward:Vector2=(b-a)/segment;var normal:=Vector2(-forward.y,forward.x)
		while next_tie<=distance+segment:
			var center:Vector2=a+forward*(next_tie-distance)
			stroke(center-normal*.61,center+normal*.61,.16,142)
			next_tie+=2.4
		distance+=segment
	# Offset polyline vertices share a bisected normal, keeping curved rails joined.
	var closed:=points[0].distance_to(points[-1])<.001
	var normals:=PackedVector2Array()
	for i in points.size():
		var before:Vector2=points[i]-points[i-1] if i>0 else points[0]-points[-2] if closed else points[1]-points[0]
		var after:Vector2=points[i+1]-points[i] if i<points.size()-1 else points[1]-points[0] if closed else before
		var tangent:Vector2=(before.normalized()+after.normalized()).normalized()
		normals.append(Vector2(-tangent.y,tangent.x))
	for i in points.size()-1:
		for side in [-1.0,1.0]:stroke(points[i]+normals[i]*.42*side,points[i+1]+normals[i+1]*.42*side,.19,255)
