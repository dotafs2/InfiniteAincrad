extends RefCounted
## Original toy parcels. Clear lanes are reserved before any edible placement.
const SPAWN:=Vector2(1,23)
const LANE_HALF:=3.6
const OUTER_HALF:=3.2
const WORLD_LIMIT:=96.0
const TIER_POINTS:={1:1,2:2,3:4,4:7,5:12,6:22,7:36,8:64,9:96}

static func road_clearance()->Array[Rect2]:
	var result:Array[Rect2]=[]
	for x in [-44.0,0.0,44.0]:result.append(Rect2(Vector2(x-LANE_HALF,-WORLD_LIMIT),Vector2(LANE_HALF*2,WORLD_LIMIT*2)))
	for z in [-36.0,18.0,60.0]:result.append(Rect2(Vector2(-WORLD_LIMIT,z-LANE_HALF),Vector2(WORLD_LIMIT*2,LANE_HALF*2)))
	for x in [-84.0,84.0]:result.append(Rect2(Vector2(x-OUTER_HALF,-84-OUTER_HALF),Vector2(OUTER_HALF*2,168+OUTER_HALF*2)))
	for z in [-84.0,84.0]:result.append(Rect2(Vector2(-84-OUTER_HALF,z-OUTER_HALF),Vector2(168+OUTER_HALF*2,OUTER_HALF*2)))
	return result

static func districts()->Array[Dictionary]:
	return [
		{"id":"rose_courtyard","name":"Rose Courtyard","center":Vector2(-23,41),"palette":1},
		{"id":"mint_playground","name":"Mint Playground","center":Vector2(23,41),"palette":0},
		{"id":"sky_block_quarter","name":"Sky Block Quarter","center":Vector2(-23,-10),"palette":4},
		{"id":"apricot_garden","name":"Apricot Garden","center":Vector2(23,-10),"palette":3},
		{"id":"crown_heights","name":"Crown Heights","center":Vector2(0,-64),"palette":4},
		{"id":"west_bubble_walk","name":"West Bubble Walk","center":Vector2(-68,20),"palette":0},
		{"id":"east_bubble_walk","name":"East Bubble Walk","center":Vector2(68,20),"palette":2},
		{"id":"sunset_castles","name":"Sunset Castles","center":Vector2(0,73),"palette":3}
	]

static func opening_route()->Array[Vector2]:
	return [SPAWN,Vector2(4.9,23),Vector2(4.9,34),Vector2(11,34),Vector2(18,31),Vector2(23,34),Vector2(23,41),Vector2(34,44),Vector2(39,51)]

static func bounds_for(at:Vector2,size:Vector3,yaw:float)->Rect2:
	var c:=absf(cos(yaw));var s:=absf(sin(yaw))
	var half:=Vector2(size.x*c+size.z*s,size.z*c+size.x*s)*.5
	return Rect2(at-half,half*2)

static func clear_of_roads(bounds:Rect2)->bool:
	if bounds.position.x<-WORLD_LIMIT or bounds.end.x>WORLD_LIMIT or bounds.position.y<-WORLD_LIMIT or bounds.end.y>WORLD_LIMIT:return false
	for lane in road_clearance():
		if bounds.intersects(lane,true):return false
	return true

static func _append(plan:Array[Dictionary],occupied:Array[Rect2],kind:String,at:Vector2,size:Vector3,tier:int,palette:int,neighborhood:String,yaw:=0.0,tower_id:="",tower_level:=0,bottom:=0.04,landmark:=false,neighbor_gap:=.22)->bool:
	var bounds:=bounds_for(at,size,yaw)
	if not clear_of_roads(bounds.grow(.08)):return false
	if tower_level==0:
		for existing in occupied:
			if bounds.grow(neighbor_gap).intersects(existing,true):return false
		occupied.append(bounds)
	plan.append({"kind":kind,"at":at,"size":size,"tier":tier,"points":int(TIER_POINTS[tier]),"palette":palette,"neighborhood":neighborhood,"yaw":yaw,"tower_id":tower_id,"tower_level":tower_level,"bottom":bottom,"landmark":landmark})
	return true

static func _tower(plan:Array[Dictionary],occupied:Array[Rect2],at:Vector2,palette:int,neighborhood:String,index:int,giant:=false)->void:
	var id:="toy_tower_%02d"%index
	var sizes:Array[Vector3]=[Vector3(5.4,4.0,5.0),Vector3(4.2,4.0,3.9),Vector3(3.0,4.6,2.8)]
	var tiers:Array[int]=[6,5,4]
	var kinds:Array[String]=["block_tower","toy_block","bubble_turret"]
	if giant:
		# A coherent royal landmark replaces the former palace-on-a-toy-block.
		# Small courtyard stacks still provide independent gravity handoffs.
		_append(plan,occupied,"grand_castle",at,Vector3(18,38,17),9,palette,neighborhood,0.0,"",0,.04,true)
		return
	var bottom:=.04
	for level in sizes.size():
		if not _append(plan,occupied,kinds[level],at,sizes[level],tiers[level],(palette+level)%5,neighborhood,0.0,id,level,bottom,giant):return
		bottom+=sizes[level].y+.025

static func _small_tower(plan:Array[Dictionary],occupied:Array[Rect2],at:Vector2,palette:int,neighborhood:String,index:int)->void:
	var bottom:=.04
	var sizes:Array[Vector3]=[Vector3(2.05,1.2,1.95),Vector3(1.45,.9,1.12),Vector3(.72,.65,.68)]
	var kinds:Array[String]=["toy_block","toy_car","toy_duck"]
	for level in 3:
		if not _append(plan,occupied,kinds[level],at,sizes[level],3-level,(palette+level)%5,neighborhood,0.0,"toy_tower_%02d"%index,level,bottom):return
		bottom+=sizes[level].y+.025

static func _starter_cluster(plan:Array[Dictionary],occupied:Array[Rect2],at:Vector2,palette:int,neighborhood:String)->void:
	# A mouth can collect several separate low-value miniatures in one sweep.
	# No tiny body grants a castle-sized score and none visually overlaps.
	for row in 3:
		for column in 2:
			var offset:=Vector2((column-.5)*.48,(row-1)*.48)
			_append(plan,occupied,["toy_ball","toy_block","toy_duck"][(row+column)%3],at+offset,Vector3(.40,.38,.38),1,palette,neighborhood,0.0,"",0,.04,false,.025)

static func plan()->Array[Dictionary]:
	var result:Array[Dictionary]=[]
	var occupied:Array[Rect2]=[]
	# Ten distant silhouettes keep useful late targets after the first courtyards.
	var late:Array[Vector2]=[Vector2(-68,-64),Vector2(-22,-64),Vector2(22,-64),Vector2(68,-64),Vector2(-68,0),Vector2(68,0),Vector2(-68,40),Vector2(68,40),Vector2(-23,73),Vector2(23,73)]
	for i in late.size():
		var at:Vector2=late[i]
		var district:="crown_heights" if i<4 else "west_bubble_walk" if at.x<0 else "east_bubble_walk"
		if i>=8:district="sunset_castles"
		if i in [1,2]:
			_tower(result,occupied,at,i%5,district,i,true)
		else:
			var size:=Vector3(18,24+float(i%4)*3,17) if i<8 else Vector3(14,22+float(i%2)*5,13)
			_append(result,occupied,"grand_castle",at,size,9 if i<8 else 8,i%5,district,0.0,"",0,.04,true)
	# Actual intermediate footprints bridge the mid city and radius-14 crowns.
	# These standalone bodies remain directly accessible without clearing a base.
	for side in [-1,1]:
		_append(result,occupied,"toy_castle",Vector2(side*23,-46.5),Vector3(12,18,10.4),8,4,"crown_heights")
		_append(result,occupied,"toy_castle",Vector2(side*55.5,-47),Vector3(10.4,16,9.2),8,2,"west_bubble_walk" if side<0 else "east_bubble_walk")
		_append(result,occupied,"toy_castle",Vector2(side*56,28),Vector3(12,21,10.4),8,0,"west_bubble_walk" if side<0 else "east_bubble_walk")
		_append(result,occupied,"toy_castle",Vector2(side*61,73),Vector3(10.4,15,9.2),8,3,"sunset_castles")
		_append(result,occupied,"toy_castle",Vector2(side*72,-20),Vector3(14,21,12),8,2,"west_bubble_walk" if side<0 else "east_bubble_walk")
	# Each neighborhood has its own castle, gates, and independently owned towers.
	var inner:Array[Dictionary]=districts().slice(0,4)
	for district in inner:
		var center:Vector2=district.center
		var palette:int=district.palette
		_append(result,occupied,"toy_castle",center,Vector3(8.8,10.0+float(palette)*1.4,7.6),7,palette,district.id)
		_append(result,occupied,"toy_castle",center+Vector2(-10,-9),Vector3(4.8,7.0+float(palette%2)*2,4.0),6,palette,district.id)
		_append(result,occupied,"toy_castle",center+Vector2(10,8),Vector3(4.8,9.0+float(palette%3),4.0),6,(palette+1)%5,district.id)
		_tower(result,occupied,center+Vector2(-10,8),(palette+2)%5,district.id,10+palette)
		_append(result,occupied,"toy_arch",center+Vector2(7,-10),Vector3(2.8,3.5,2.6),4,palette,district.id)
		_append(result,occupied,"bubble_turret",center+Vector2(10,-3),Vector3(4.2,6.0+palette,4.0),5,palette,district.id)
		_append(result,occupied,"bubble_turret",center+Vector2(-2,11),Vector3(4.2,5.5,4.0),5,(palette+3)%5,district.id)
	# Street-facing rows form real city blocks around palace courtyards. Their
	# alternating eaves/dormers/rooflines bridge the small props and royal skyline.
	for district in inner:
		var center:Vector2=district.center
		var palette:int=district.palette
		for index in 5:
			var along:float=-13.0+float(index)*6.1
			for edge in [-1,1]:
				var at:Vector2=center+Vector2(along,edge*14.2)
				var height:float=[5.0,8.0,5.6,10.5,7.0][posmod(index+palette,5)]
				_append(result,occupied,"block_tower",at,Vector3(4.2,height,3.5),5 if height<8 else 6,(palette+index)%5,district.id,0.0 if edge<0 else PI)
	# Outer avenue frontage uses the same district/road relationship as Sunny
	# City's extended quarters, with distinct short cottages and tall gables.
	for side in 4:
		for index in 6:
			var along:float=[-66.0,-48.0,-15.0,14.0,48.0,66.0][index]
			var at:=Vector2(along,-92.5 if side==0 else 92.5) if side<2 else Vector2(-92.5 if side==2 else 92.5,along)
			var yaw:float=[0.0,PI,PI*.5,-PI*.5][side]
			var height:float=[5.5,9.0,5.8,12.0,6.5,10.0][(index+side)%6]
			_append(result,occupied,"block_tower",at,Vector3(4.8,height,4.2),6,(index+side)%5,["crown_heights","sunset_castles","west_bubble_walk","east_bubble_walk"][side],yaw)
	_small_tower(result,occupied,Vector2(13,31),0,"mint_playground",20)
	_small_tower(result,occupied,Vector2(-13,31),1,"rose_courtyard",21)
	for side in [-1,1]:
		var palette:=0 if side>0 else 1
		var district:="mint_playground" if side>0 else "rose_courtyard"
		for at in [Vector2(5.4,24.4),Vector2(5.4,28),Vector2(5.4,32),Vector2(5.4,36),Vector2(8.7,36.8),Vector2(19,27),Vector2(28,30),Vector2(37,49)]:
			_starter_cluster(result,occupied,Vector2(at.x*side,at.y),palette,district)
		for at in [Vector2(5.4,-25),Vector2(5.4,-21),Vector2(19,-24),Vector2(37,-4)]:
			_starter_cluster(result,occupied,Vector2(at.x*side,at.y),3 if side>0 else 4,"apricot_garden" if side>0 else "sky_block_quarter")
	# A visible small-to-mid route starts a short move from the actual spawn.
	for side in [-1,1]:
		for i in 7:
			_append(result,occupied,["toy_ball","toy_duck","toy_block"][i%3],Vector2(side*4.9,23+i*1.55),Vector3(.72,.65,.68),1,0 if side>0 else 1,"mint_playground" if side>0 else "rose_courtyard")
	for i in 6:
		_append(result,occupied,"toy_car" if i%2==0 else "toy_train",Vector2(8+i*1.9,24),Vector3(1.45,.82,1.12),2,0,"mint_playground",0.0)
	# Dense little toy gardens sit inside parcels, never across the open lanes.
	var small_kinds:Array[String]=["toy_ball","toy_duck","toy_car","toy_block","toy_train"]
	for district in inner:
		var center:Vector2=district.center
		for row in 9:
			for column in 10:
				var at:=center+Vector2(-14.7+column*3.25,-13.2+row*3.25)
				var index:=row*10+column+int(district.palette)*13
				var tier:=1 if index%5<2 else 2 if index%5<4 else 3
				var kind:String=small_kinds[index%small_kinds.size()]
				var size:=Vector3(.72,.65,.68) if tier==1 else Vector3(1.45,.9,1.12) if tier==2 else Vector3(2.05,1.7,1.95)
				if tier==3:kind="toy_block" if index%2==0 else "toy_duck"
				_append(result,occupied,kind,at,size,tier,int(district.palette),district.id,float(index%4)*PI*.5)
	# Intermediate targets make the road to the distant crowns economically viable.
	for side in [-1,1]:
		for i in 8:
			var at:=Vector2(side*(55.5+float(i%2)*18),-47.0+i*13.0)
			var tier:=4+i%4
			var size:=Vector3(2.8,3.2,2.6) if tier==4 else Vector3(4.2,5.5,4) if tier==5 else Vector3(6,8,5) if tier==6 else Vector3(8.8,12,7.6)
			var kind:="bubble_turret" if tier<6 else "toy_castle"
			_append(result,occupied,kind,at,size,tier,(i+2)%5,"west_bubble_walk" if side<0 else "east_bubble_walk")
		for row in 10:
			for column in 4:
				var at:=Vector2(side*(51.5+column*7.8),-73.0+row*15.0)
				var tier:=1+(row+column)%4
				var size:=Vector3(.72,.65,.68) if tier==1 else Vector3(1.45,.9,1.12) if tier==2 else Vector3(2.05,1.7,1.95) if tier==3 else Vector3(2.8,3.2,2.6)
				_append(result,occupied,"toy_car" if tier<3 else "toy_arch" if tier==4 else "toy_block",at,size,tier,(row+column)%5,"west_bubble_walk" if side<0 else "east_bubble_walk")
	return result

static func metadata()->Dictionary:
	return {"spawn":SPAWN,"districts":districts(),"road_clearance":road_clearance(),"opening_route":opening_route(),"main_vertical_lanes":[-44.0,0.0,44.0],"main_horizontal_lanes":[-36.0,18.0,60.0],"lane_half_width":LANE_HALF,"outer_ring":84.0,"outer_half_width":OUTER_HALF,"world_limit":WORLD_LIMIT,"tier_points":TIER_POINTS.duplicate()}
