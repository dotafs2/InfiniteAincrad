extends RefCounted
## Authored parcels: avenue frontage, a courtyard, civic commons and canal yards.
const DISTRICTS:=[
	{"id":"garden_market","name":"Garden Market","park":Rect2(16.9,18.0,7.6,18.5),"landmark":35,"links":["civic_quarter","north_commons","canal_yards"]},
	{"id":"civic_quarter","name":"Civic Quarter","park":Rect2(-8.0,-23.0,16.0,2.0),"landmark":23,"links":["garden_market","north_commons"]},
	{"id":"north_commons","name":"North Commons","park":Rect2(-10.0,-59.0,20.0,6.0),"landmark":46,"links":["garden_market","civic_quarter","canal_yards"]},
	{"id":"canal_yards","name":"Canal Yards","park":Rect2(-48.0,34.0,10.0,6.0),"landmark":29,"links":["garden_market","north_commons"]}
]
static func parcels()->Array[Dictionary]:
	var result:Array[Dictionary]=[]
	for i in 48:
		var at:=Vector2.ZERO;var yaw:=0.0;var district:="garden_market"
		if i<6:
			# West and south sides of a residential courtyard; no repeated row.
			at=[Vector2(-16.5,47),Vector2(-16.5,55),Vector2(-16.5,63),Vector2(-8,64),Vector2(0,64),Vector2(8,64)][i]
			yaw=PI*.5 if i<3 else PI
		elif i<12:
			at=Vector2(-17.5+(i-6)*7.0,12.0)
		elif i<18:
			at=[Vector2(-8,-64),Vector2(0,-64),Vector2(8,-64),Vector2(16,-64),Vector2(-16,-56),Vector2(16,-56)][i-12]
			yaw=PI if i<16 else PI*.5 if i==16 else -PI*.5;district="north_commons"
		elif i<24:
			at=Vector2(-17.5+(i-18)*7.0,-16.5);district="civic_quarter"
		elif i<30:
			at=Vector2(-43.0,[-59.0,-45.0,-16.0,12.0,27.0,46.0][i-24]);yaw=PI*.5;district="canal_yards"
		elif i<36:
			at=[Vector2(16.5,47),Vector2(16.5,55),Vector2(16.5,63),Vector2(-8,47.7),Vector2(0,47.7),Vector2(8,47.7)][i-30]
			yaw=-PI*.5 if i<33 else 0.0
		elif i<42:
			at=Vector2(43.0+float(i%2),[-47.0,-16.0,12.0,27.0,42.0,57.0][i-36]);yaw=-PI*.5;district="civic_quarter"
		else:
			at=[Vector2(-16,-48),Vector2(-8,-48),Vector2(0,-48),Vector2(8,-48),Vector2(16,-48),Vector2(-16,-64)][i-42]
			district="north_commons"
		result.append({"at":at,"yaw":yaw,"district":district,"landmark":DISTRICTS.any(func(d):return int(d.landmark)==i)})
	return result
