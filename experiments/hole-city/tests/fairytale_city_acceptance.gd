extends SceneTree
## Authored architecture, actual City-relative density and physical collection.
## Headless material settings are configuration evidence, never rendered gloss.
const Game=preload("res://fidelity/game.gd")
const Growth=preload("res://fidelity/hole.gd")
const KINDS:=["toy_castle","grand_castle","bubble_turret","toy_arch","block_tower"]
const HABITABLE:=["toy_castle","grand_castle","block_tower"]
const TRIANGLE_BUDGETS:={"toy_castle":12000,"grand_castle":12000,"bubble_turret":6000,"toy_arch":2500,"block_tower":6000}
const COMMON_AREA:=Rect2(-96,-96,192,192)
const CELL_SIZE:=24.0
class SizeProbe:
	extends Node3D
	var radius:=.85
var provider:Script
var game:Node3D
var checks:=0
var failures:Array[String]=[]
var metrics:Dictionary={}
var receipts:Dictionary={}
var progress_paths:Array[String]=[]
var manifest:Dictionary={}

func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);print("CHECK_FAILED "+label)
func descendants(owner:Node)->Array[Node]:
	var result:Array[Node]=[]
	for child in owner.get_children():
		result.append(child);result.append_array(descendants(child))
	return result
func frames(count:int)->void:
	for _index in count:await physics_frame
func mesh_points(mesh:Mesh)->PackedVector3Array:
	var result:=PackedVector3Array()
	for surface in mesh.get_surface_count():
		var arrays:Array=mesh.surface_get_arrays(surface)
		result.append_array(arrays[Mesh.ARRAY_VERTEX])
	return result
func geometry_signature(mesh:Mesh)->String:
	var context:=HashingContext.new();context.start(HashingContext.HASH_SHA256)
	for surface in mesh.get_surface_count():
		var arrays:Array=mesh.surface_get_arrays(surface)
		var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		context.update(vertices.to_byte_array());context.update(indices.to_byte_array())
	return context.finish().hex_encode()
func key(point:Vector3)->String:
	return "%d,%d,%d"%[roundi(point.x*100000),roundi(point.y*100000),roundi(point.z*100000)]
func point_bounds(points:PackedVector3Array)->AABB:
	if points.is_empty():return AABB()
	var box:=AABB(points[0],Vector3.ZERO)
	for point in points:box=box.expand(point)
	return box
func support_height(vertices:PackedVector3Array,indices:PackedInt32Array,row:Dictionary,at:Vector2,ceiling:float)->float:
	var highest:float=-INF
	for offset in range(int(row.start),int(row.end),3):
		var a:Vector3=vertices[indices[offset]];var b:Vector3=vertices[indices[offset+1]];var c:Vector3=vertices[indices[offset+2]]
		var determinant:float=(b.z-c.z)*(a.x-c.x)+(c.x-b.x)*(a.z-c.z)
		if absf(determinant)<1.0e-12:continue
		var first:float=((b.z-c.z)*(at.x-c.x)+(c.x-b.x)*(at.y-c.z))/determinant
		var second:float=((c.z-a.z)*(at.x-c.x)+(a.x-c.x)*(at.y-c.z))/determinant
		var third:float=1.0-first-second
		if minf(first,minf(second,third))<-.00001:continue
		var height:float=a.y*first+b.y*second+c.y*third
		if height<=ceiling+.00001:highest=maxf(highest,height)
	return highest

@warning_ignore("integer_division")
func inspect_assembly(kind:String,mesh:ArrayMesh,payload:Dictionary,entry:Dictionary)->Dictionary:
	var components:Array=payload.get("components",[])
	var arrays:Array=mesh.surface_get_arrays(0);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX];var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR]
	var roles:Dictionary={};var rows:Array[Dictionary]=[];var surfaces:Dictionary={};var segment_groups:Dictionary={};var next_start:=0
	var partition_ok:=not components.is_empty();var bounds_ok:=true;var solids_ok:=true;var material_ok:=true
	var coral:=Color("ed7990");var coral_samples:=0;var max_coral_delta:=0.0
	for component:Dictionary in components:
		var start:int=int(component.get("index_start",-1));var count:int=int(component.get("index_count",0))
		var valid:bool=start==next_start and start>=0 and count>0 and start%3==0 and count%3==0 and start+count<=indices.size() and int(component.get("triangle_count",-1))==count/3
		partition_ok=partition_ok and valid
		if not valid:continue
		next_start=start+count
		var points:=PackedVector3Array();var edge_counts:Dictionary={};var volume:=0.0
		var role:String=component.get("structural_role","generic");var material_role:String=component.get("material_role","")
		for offset in range(start,start+count,3):
			var a:Vector3=vertices[indices[offset]];var b:Vector3=vertices[indices[offset+1]];var c:Vector3=vertices[indices[offset+2]]
			points.append(a);points.append(b);points.append(c);volume+=a.dot(b.cross(c))/6.0
			var keys:=[key(a),key(b),key(c)]
			for edge in [[keys[0],keys[1]],[keys[1],keys[2]],[keys[2],keys[0]]]:
				var edge_key:String=(edge[0]+"|"+edge[1]) if edge[0]<edge[1] else (edge[1]+"|"+edge[0])
				edge_counts[edge_key]=int(edge_counts.get(edge_key,0))+1
			for index in [indices[offset],indices[offset+1],indices[offset+2]]:
				var color_role:String=payload.role_names[int(payload.color_roles[index])]
				material_ok=material_ok and material_role==color_role
				# This historical material-role alias now names the real coral plastic
				# frame color. Verify the decoded color rather than reject its label.
				if color_role=="wood":
					var color:Color=colors[index]
					var delta:float=maxf(absf(color.r-coral.r),maxf(absf(color.g-coral.g),absf(color.b-coral.b)))
					coral_samples+=1;max_coral_delta=maxf(max_coral_delta,delta)
					material_ok=material_ok and delta<=1.0/255.0+.0001 and is_equal_approx(color.a,1.0)
		var box:=point_bounds(points);var declared:Dictionary=component.get("unit_bounds",{})
		var position:Array=declared.get("position",[]);var size:Array=declared.get("size",[])
		if position.size()!=3 or size.size()!=3:bounds_ok=false
		else:
			var declared_box:=AABB(Vector3(position[0],position[1],position[2]),Vector3(size[0],size[1],size[2]))
			bounds_ok=bounds_ok and declared_box.position.distance_to(box.position)<.00001 and declared_box.size.distance_to(box.size)<.00001
		solids_ok=solids_ok and box.size.x>0 and box.size.y>0 and box.size.z>0 and absf(volume)>1.0e-12 and not edge_counts.is_empty() and edge_counts.values().all(func(value):return int(value)>=2 and int(value)%2==0)
		roles[role]=int(roles.get(role,0))+1
		var row:={"name":str(component.get("name","")),"role":role,"surface":str(component.get("assembly_surface","")),"course":int(component.get("course_index",-1)),"start":start,"end":start+count,"box":box,"volume":absf(volume)}
		rows.append(row)
		if role=="block_course":
			if not surfaces.has(row.surface):surfaces[row.surface]={}
			var course_rows:Dictionary=surfaces[row.surface]
			if not course_rows.has(row.course):course_rows[row.course]=[]
			course_rows[row.course].append(row)
		if role=="tower_segment":
			if not segment_groups.has(row.surface):segment_groups[row.surface]=[]
			segment_groups[row.surface].append(row)
	check(partition_ok and next_start==indices.size() and components.size()==int(entry.get("component_objects",-1)),kind+": actual Blender component ranges partition the complete runtime index payload")
	check(bounds_ok,kind+": component bounds are recomputed from actual referenced runtime vertices")
	check(solids_ok,kind+": every component is a closed positive-volume mesh rather than a painted label or plane")
	check(material_ok,kind+": actual component vertex roles match their declared material and coral plastic frames remain opaque")
	var course_bands:=0;var staggered_pairs:=0;var joint_count:=0;var course_details:Array[Dictionary]=[]
	for surface:String in surfaces:
		var groups:Dictionary=surfaces[surface];var courses:Array=groups.keys();courses.sort()
		var previous:Array[float]=[];var previous_y:float=-INF
		var distinct_bands:=0
		for course in courses:
			var bricks:Array=groups[course]
			var dx:=0.0;var dz:=0.0;var mean_y:=0.0
			for brick:Dictionary in bricks:dx+=brick.box.size.x;dz+=brick.box.size.z;mean_y+=brick.box.get_center().y
			mean_y/=maxi(1,bricks.size())
			var axis:=0 if dx>=dz else 2
			bricks.sort_custom(func(a,b):return a.box.position[axis]<b.box.position[axis])
			var joints:Array[float]=[];var widths:Array[float]=[]
			for brick:Dictionary in bricks:widths.append(float(brick.box.size[axis]))
			widths.sort()
			for index in range(bricks.size()-1):
				var left:AABB=bricks[index].box;var right:AABB=bricks[index+1].box
				if right.position[axis]-left.end[axis]>.00001:joints.append((right.position[axis]+left.end[axis])*.5)
			joint_count+=joints.size()
			if is_finite(mean_y) and mean_y>previous_y+.0001:distinct_bands+=1
			if not previous.is_empty() and not joints.is_empty() and not widths.is_empty():
				var displaced:=false;var width:float=widths[widths.size()/2]
				for joint in joints:
					var nearest:float=INF
					for old_joint in previous:nearest=minf(nearest,absf(joint-old_joint))
					if nearest>width*.15:displaced=true
				if displaced:staggered_pairs+=1
			previous=joints;previous_y=mean_y
		course_bands=maxi(course_bands,distinct_bands)
		course_details.append({"surface":surface,"bands":distinct_bands,"courses":courses.size()})
	if kind in ["toy_castle","grand_castle","block_tower"]:
		check(int(roles.get("block_course",0))>=48 and course_bands>=4,kind+": real closed wall bricks occupy at least four distinct vertical courses")
		check(joint_count>=8 and staggered_pairs>=2,kind+": actual separate brick gaps shift horizontally between courses")
	var valid_segment_groups:=0
	for surface:String in segment_groups:
		var segments:Array=segment_groups[surface]
		segments.sort_custom(func(a,b):return a.box.get_center().y<b.box.get_center().y)
		var distinct:=0;var previous_y:float=-INF
		for segment:Dictionary in segments:
			var height:float=segment.box.get_center().y
			if height>previous_y+.0001 and segment.box.size.y>.005:distinct+=1
			previous_y=height
		if distinct>=4:valid_segment_groups+=1
	if kind in ["toy_castle","grand_castle"]:check(valid_segment_groups>=4,kind+": four corner towers each contain four real stacked solid segments")
	elif kind=="bubble_turret":check(valid_segment_groups>=1,kind+": the actual standalone turret consists of four vertically distinct segments")
	var stud_count:=0;var studs_ok:=true;var mounted:=0;var stud_contacts:Array[Dictionary]=[];var natural:Vector3=provider.natural_size_for(kind)
	for stud:Dictionary in rows:
		if stud.role!="stud":continue
		stud_count+=1
		var box:AABB=stud.box;var actual_size:Vector3=box.size*natural
		var diameter:float=minf(actual_size.x,actual_size.z)
		studs_ok=studs_ok and diameter>0 and maxf(actual_size.x,actual_size.z)/diameter<1.15 and actual_size.y/diameter>=.05 and actual_size.y/diameter<=1.5
		var at:=Vector2(box.get_center().x,box.get_center().z);var highest:float=-INF
		for support:Dictionary in rows:
			if support.role=="stud":continue
			var support_box:AABB=support.box
			if not Rect2(Vector2(support_box.position.x,support_box.position.z),Vector2(support_box.size.x,support_box.size.z)).grow(.00001).has_point(at):continue
			highest=maxf(highest,support_height(vertices,indices,support,at,box.position.y))
		if is_finite(highest) and box.position.y-highest>=-.00001 and box.position.y-highest<=.002 and box.end.y>highest+.0005:mounted+=1
		stud_contacts.append({"name":stud.name,"base":box.position.y,"top":box.end.y,"support_height":highest if is_finite(highest) else null,"gap":box.position.y-highest if is_finite(highest) else null})
	var expected_studs:int={"toy_castle":28,"grand_castle":28,"bubble_turret":4,"toy_arch":8,"block_tower":12}[kind]
	check(stud_count>=expected_studs and studs_ok,kind+": raised stud labels correspond to real closed cylindrical proportions")
	check(mounted==stud_count and stud_count>0,kind+": actual studs rise from nearby indexed support surfaces without floating")
	if kind=="block_tower":check(int(roles.get("plastic_frame",0))>=7,kind+": seven real closed plastic frame members replace the wooden braces")
	return {"components":components.size(),"roles":roles,"course_bands":course_bands,"staggered_pairs":staggered_pairs,"real_brick_joints":joint_count,"course_surfaces":course_details,"four_segment_towers":valid_segment_groups,"studs":stud_count,"mounted_studs":mounted,"stud_contacts":stud_contacts,"coral_plastic_vertex_samples":coral_samples,"max_coral_color_delta":max_coral_delta}
func visual_points(body:Node3D)->PackedVector3Array:
	var result:=PackedVector3Array();var view:MeshInstance3D=body.get_node_or_null("ToyVisual")
	if view==null or view.mesh==null:return result
	for point in mesh_points(view.mesh):result.append(view.transform*point)
	return result
func collision_points(body:Node3D)->PackedVector3Array:
	var result:=PackedVector3Array()
	for node in body.get_children():
		if node is CollisionShape3D and node.shape is ConvexPolygonShape3D:
			for point in node.shape.points:result.append(node.transform*point)
	return result
func footprint(body:Node3D,points:PackedVector3Array)->Rect2:
	var first:=true;var area:=Rect2()
	for point in points:
		var world:Vector3=body.global_transform*point;var at:=Vector2(world.x,world.z)
		if first:area=Rect2(at,Vector2.ZERO);first=false
		else:area=area.expand(at)
	return area
func quiet_world()->void:
	game.set_process(false);game.set_physics_process(false)
	game.city.set_process(false);game.city.set_physics_process(false)
	if is_instance_valid(game.city.get("court")):game.city.court.set_process(false)
	for hole in game.holes:
		hole.enabled=false;hole.set_process(false);hole.set_physics_process(false)
		if hole!=game.player:hole.active=false
func isolated_game(map_id:String)->void:
	game=Game.new();game.selected_map=map_id
	var path:="/tmp/hole-fairytale-%d-%s.cfg"%[OS.get_process_id(),map_id]
	game.test_progress_path=path
	for suffix in ["",".tmp",".pre-coins.cfg"]:progress_paths.append(path+suffix)
	root.add_child(game);game.start_level();game.begin_play();quiet_world()
	await frames(3)
func free_game()->void:
	if game.audio!=null:
		game.audio.music.stop()
		# Drain only this fixture's mixer before its resource owner is freed.
		await create_timer(.15).timeout
	game.free();game=null;await process_frame

@warning_ignore("integer_division")
func inspect_geometry()->void:
	check(Array(provider.KINDS)==KINDS,"The authored provider exposes the five agreed architectural kinds")
	manifest=provider.asset_manifest()
	check(int(manifest.get("schema",0))==1 and manifest.get("authoring_tool","")=="Blender" and not str(manifest.get("blender_version","")).is_empty(),"The shipped manifest names the actual Blender authoring tool and version")
	var provenance_ok:=true
	for field in ["generator_sha256","blender_binary_sha256","source_blend_sha256"]:
		var value:String=str(manifest.get(field,""));provenance_ok=provenance_ok and value.length()==64 and value.is_valid_hex_number(false)
	check(provenance_ok,"The compact runtime provenance binds the generator, Blender binary and saved source scene")
	check(manifest.get("assets",{}).keys().size()==KINDS.size() and KINDS.all(func(kind):return manifest.get("assets",{}).has(kind)),"The shipped manifest describes every authored architectural payload")
	var signatures:Dictionary={};var sources:Dictionary={};var rows:Dictionary={}
	for kind:String in KINDS:
		var mesh:ArrayMesh=provider.mesh_for(kind,0)
		check(mesh!=null and mesh.get_surface_count()>0,kind+": actual authored mesh exists")
		if mesh==null:continue
		check(mesh==provider.mesh_for(kind,0),kind+": repeated requests share the cached geometry")
		var box:AABB=mesh.get_aabb();var natural:Vector3=provider.natural_size_for(kind)
		check(box.size.is_equal_approx(Vector3.ONE) and box.get_center().is_equal_approx(Vector3(0,.5,0)),kind+": actual vertices retain the normalized grounded envelope")
		check(natural.is_finite() and natural.x>0 and natural.y>0 and natural.z>0,kind+": authored natural proportions are finite and positive")
		var source:String=mesh.get_meta("source_geometry_sha256","")
		check(mesh.get_meta("fairytale_authored",false) and mesh.get_meta("authoring_tool","")=="Blender" and mesh.get_meta("toy_kind","")==kind and int(mesh.get_meta("toy_palette",-1))==0 and source.length()==64 and source.is_valid_hex_number(false),kind+": runtime provenance names the actual authored kind and source digest")
		var payload_path:="res://assets/fairytale_castles/"+kind+".json"
		var entry:Dictionary=manifest.get("assets",{}).get(kind,{})
		var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(payload_path))
		check(parsed is Dictionary and FileAccess.get_sha256(payload_path)==str(entry.get("sha256","")) and str(entry.get("source_geometry_sha256",""))==source,kind+": actual packaged JSON bytes match the shipped source digest")
		var payload:Dictionary=parsed if parsed is Dictionary else {}
		var vertices_ok:=true;var normals_ok:=true;var colors_ok:=true;var indices_ok:=true;var faces_ok:=true;var triangles:=0;var vertices_count:=0;var edges:Dictionary={}
		for surface in mesh.get_surface_count():
			check(mesh.surface_get_primitive_type(surface)==Mesh.PRIMITIVE_TRIANGLES,kind+": authored surfaces use triangles")
			var arrays:Array=mesh.surface_get_arrays(surface)
			var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
			var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR]
			var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			vertices_count+=vertices.size();normals_ok=normals_ok and normals.size()==vertices.size();colors_ok=colors_ok and colors.size()==vertices.size()
			for point in vertices:vertices_ok=vertices_ok and point.is_finite() and box.grow(.00001).has_point(point)
			for normal in normals:normals_ok=normals_ok and normal.is_finite() and absf(normal.length()-1.0)<.002
			for color in colors:colors_ok=colors_ok and is_equal_approx(color.a,1.0) and is_finite(color.r) and is_finite(color.g) and is_finite(color.b)
			indices_ok=indices_ok and not indices.is_empty() and indices.size()%3==0
			for index in indices:indices_ok=indices_ok and index>=0 and index<vertices.size()
			if not indices_ok:continue
			triangles+=indices.size()/3
			for offset in range(0,indices.size(),3):
				var a:int=indices[offset];var b:int=indices[offset+1];var c:int=indices[offset+2]
				var cross:Vector3=(vertices[b]-vertices[a]).cross(vertices[c]-vertices[a])
				if cross.length_squared()<1.0e-15:faces_ok=false;continue
				if normals.size()==vertices.size():
					var average:Vector3=normals[a]+normals[b]+normals[c]
					faces_ok=faces_ok and not average.is_zero_approx() and absf(cross.normalized().dot(average.normalized()))>.05
				var keys:=[key(vertices[a]),key(vertices[b]),key(vertices[c])]
				for edge in [[keys[0],keys[1]],[keys[1],keys[2]],[keys[2],keys[0]]]:
					var edge_key:String=(edge[0]+"|"+edge[1]) if edge[0]<edge[1] else (edge[1]+"|"+edge[0])
					edges[edge_key]=int(edges.get(edge_key,0))+1
		check(vertices_count>0 and vertices_ok,kind+": finite actual vertices lie inside the real envelope")
		check(normals_ok and faces_ok,kind+": finite unit normals agree with nondegenerate actual triangles")
		check(colors_ok,kind+": every actual vertex has an opaque finite color")
		check(indices_ok and faces_ok,kind+": indexed faces are valid and nondegenerate")
		var raw_vertices:=PackedVector3Array();var raw_normals:=PackedVector3Array();var raw_indices:=PackedInt32Array();var raw_ok:=true
		for point in payload.get("vertices",[]):raw_vertices.append(Vector3(point[0],point[1],point[2]))
		for normal in payload.get("normals",[]):
			var vector:=Vector3(normal[0],normal[1],normal[2]);raw_normals.append(vector)
			raw_ok=raw_ok and vector.is_finite() and absf(vector.length()-1.0)<.002
		for index in payload.get("indices",[]):raw_indices.append(int(index))
		for color in payload.get("colors",[]):raw_ok=raw_ok and color.size()==4 and is_equal_approx(float(color[3]),1.0)
		var actual:Array=mesh.surface_get_arrays(0)
		var matching_normals:bool=raw_normals.size()==raw_vertices.size() and raw_normals.size()==actual[Mesh.ARRAY_NORMAL].size()
		var max_vertex_delta:=0.0;var max_normal_delta:=0.0;var min_normal_alignment:=1.0
		if raw_vertices.size()==actual[Mesh.ARRAY_VERTEX].size():
			for index in raw_vertices.size():max_vertex_delta=maxf(max_vertex_delta,raw_vertices[index].distance_to(actual[Mesh.ARRAY_VERTEX][index]))
		if matching_normals:
			for index in raw_normals.size():
				var normal:Vector3=raw_normals[index].normalized();var decoded:Vector3=actual[Mesh.ARRAY_NORMAL][index]
				# ArrayMesh's encoded-normal round-trip measured 0.000116674
				# vector error with unchanged vertices and indices. Retain a strict
				# 0.0002 bound plus independent orientation/unit-normal checks.
				matching_normals=matching_normals and normal.distance_to(decoded)<=.0002 and normal.dot(decoded.normalized())>=.999999
				max_normal_delta=maxf(max_normal_delta,normal.distance_to(decoded));min_normal_alignment=minf(min_normal_alignment,normal.dot(decoded))
		print("FAIRYTALE_PAYLOAD_DIAGNOSTIC "+JSON.stringify({"kind":kind,"surface_count":mesh.get_surface_count(),"raw_valid":raw_ok,"vertices_exact":raw_vertices==actual[Mesh.ARRAY_VERTEX],"indices_exact":raw_indices==actual[Mesh.ARRAY_INDEX],"normal_count":raw_normals.size(),"actual_normal_count":actual[Mesh.ARRAY_NORMAL].size(),"matching_normals":matching_normals,"max_vertex_delta":max_vertex_delta,"max_normal_delta":max_normal_delta,"min_normal_alignment":min_normal_alignment}))
		check(mesh.get_surface_count()==1 and raw_ok and raw_vertices==actual[Mesh.ARRAY_VERTEX] and raw_indices==actual[Mesh.ARRAY_INDEX] and matching_normals,kind+": real runtime vertices/indices equal the authored payload and normals remain within the measured encoding bound")
		check(not edges.is_empty() and edges.values().all(func(count):return int(count)>=2 and int(count)%2==0),kind+": welded boundaries remain closed")
		check(triangles>0 and triangles<=int(TRIANGLE_BUDGETS[kind]),kind+": authored detail stays inside its agreed triangle budget")
		var signature:=geometry_signature(mesh);signatures[signature]=true;sources[source]=true
		var alternative:ArrayMesh=provider.mesh_for(kind,1)
		check(alternative!=null and alternative!=mesh and geometry_signature(alternative)==signature,kind+": palette changes do not replace the collision geometry")
		var parts:Array=provider.collision_parts_for(kind);var copies:Array=provider.collision_parts_for(kind)
		var finite_parts:=not parts.is_empty() and parts.size()==copies.size()
		for index in parts.size():
			var part:PackedVector3Array=parts[index]
			finite_parts=finite_parts and part.size()>=4 and part==copies[index]
			for point in part:finite_parts=finite_parts and point.is_finite() and box.grow(.0001).has_point(point)
		check(finite_parts,kind+": actual normalized convex parts are finite, bounded and reproducible")
		if not parts.is_empty() and not parts[0].is_empty():
			var original:Vector3=parts[0][0];parts[0][0]+=Vector3.ONE
			var third:Array=provider.collision_parts_for(kind)
			check(third[0][0]==original and copies[0][0]==original,kind+": callers cannot poison the cached collider points")
		check(kind!="toy_arch" or copies.size()>=3,kind+": standalone arch retains separate structural collision parts")
		if kind in ["toy_castle","grand_castle"]:check(copies.size()>=5,kind+": authored castles retain compound bodies and their real towers")
		check(int(entry.get("triangles",-1))==triangles and int(entry.get("vertices",-1))==vertices_count and int(entry.get("collision_parts",-1))==copies.size(),kind+": actual triangle, vertex and collider counts match the exported manifest")
		rows[kind]={"triangles":triangles,"vertices":vertices_count,"collision_parts":copies.size(),"natural_size":natural,"mesh_signature":signature,"source_geometry_sha256":source,"max_source_vertex_delta":max_vertex_delta,"max_source_normal_delta":max_normal_delta,"min_source_normal_alignment":min_normal_alignment}
		rows[kind].assembly=inspect_assembly(kind,mesh,payload,entry)
	check(signatures.size()==KINDS.size() and sources.size()==KINDS.size(),"Five architectural recipes have distinct geometry and distinct source payloads")
	metrics.geometry=rows;metrics.provenance=manifest

func inspect_arch_opening()->void:
	var owner:=StaticBody3D.new();owner.position=Vector3(0,-20,0);owner.collision_layer=1;owner.collision_mask=1
	for points in provider.collision_parts_for("toy_arch"):
		var shape:=ConvexPolygonShape3D.new();shape.points=points
		var collision:=CollisionShape3D.new();collision.shape=shape;owner.add_child(collision)
	root.add_child(owner);await frames(2)
	var clear_from:=Vector3(0,.25,-.8);var clear_to:=Vector3(0,.25,.8)
	var clear_query:=PhysicsRayQueryParameters3D.create(owner.global_transform*clear_from,owner.global_transform*clear_to,1)
	var hit:Dictionary=owner.get_world_3d().direct_space_state.intersect_ray(clear_query)
	check(hit.is_empty(),"The actual normalized compound arch collider preserves its declared through-opening")
	# The roof ray must hit the same real compound shape, proving the first ray
	# did not pass merely because a fixture lacked registered physics.
	var roof_query:=PhysicsRayQueryParameters3D.create(owner.global_transform*Vector3(0,1.2,0),owner.global_transform*Vector3(0,.6,0),1)
	var roof:Dictionary=owner.get_world_3d().direct_space_state.intersect_ray(roof_query)
	check(roof.get("collider")==owner,"The real arch roof collider is registered above the open passage")
	metrics.arch_opening={"from":clear_from,"to":clear_to,"passage_hit":not hit.is_empty(),"roof_hit":roof.get("collider")==owner}
	owner.free();await physics_frame

@warning_ignore("integer_division")
func density(owner:Node3D,toy:bool)->Dictionary:
	var positions:Array[Vector2]=[];var cells:Dictionary={};var heights:Array[float]=[];var ids:Dictionary={}
	for body in owner.foods:
		if not is_instance_valid(body) or body.get_meta("court_actor",false):continue
		var kind:String=body.get_meta("toy_kind","")
		if body.category!="building" or (toy and not HABITABLE.has(kind)):continue
		var at:=Vector2(body.position.x,body.position.z)
		if not COMMON_AREA.has_point(at):continue
		positions.append(at);heights.append(float(body.height));ids[body.get_instance_id()]=true
		var cell:=Vector2i(floori((at.x-COMMON_AREA.position.x)/CELL_SIZE),floori((at.y-COMMON_AREA.position.y)/CELL_SIZE))
		cells[str(cell)]=int(cells.get(str(cell),0))+1
	var nearest:Array[float]=[]
	for index in positions.size():
		var distance:=INF
		for other in positions.size():
			if other!=index:distance=minf(distance,positions[index].distance_to(positions[other]))
		if is_finite(distance):nearest.append(distance)
	nearest.sort();heights.sort()
	return {"count":positions.size(),"occupied_cells":cells.size(),"cells":cells,"median_nearest_distance":nearest[nearest.size()/2] if not nearest.is_empty() else 0.0,"minimum_height":heights.front() if not heights.is_empty() else 0.0,"maximum_height":heights.back() if not heights.is_empty() else 0.0,"heights":heights,"scope":"Actual habitable bodies in the common 192-metre square; 24-metre cells; NPCs, arches and turrets excluded"}

func inspect_world(baseline:Dictionary)->void:
	var current:=density(game.city,true)
	check(int(baseline.count)>=72,"The actual Sunny City baseline retains its 48 main and 24 outer buildings")
	check(int(current.count)>=int(baseline.count),"Actual fairytale habitable density is at least the same-area Sunny City count")
	check(int(current.occupied_cells)>=int(baseline.occupied_cells),"Real fairytale frontage covers at least as many shared grid cells as Sunny City")
	var low:=0;var middle:=0;var high:=0
	for height:float in current.heights:
		if height<=6.0:low+=1
		elif height<=16.0:middle+=1
		else:high+=1
	var height_histogram:Dictionary={}
	for height:float in current.heights:
		var bucket:=str(snappedf(height,.5));height_histogram[bucket]=int(height_histogram.get(bucket,0))+1
	print("FAIRYTALE_DENSITY_DIAGNOSTIC "+JSON.stringify({"sunny_city":baseline,"fairytale":current,"low":low,"middle":middle,"high":high,"height_histogram":height_histogram}))
	check(low>=12 and middle>=12 and high>=4,"The actual habitable skyline contains street houses, middle buildings and taller landmarks")
	check(float(current.maximum_height)>=float(current.minimum_height)*3.0,"Real height hierarchy spans at least three times the shortest habitation")
	var nodes:=descendants(game.city);var meshes:=0;var colliders:=0;var fragments:=0
	for node in nodes:
		if node is MeshInstance3D or node is MultiMeshInstance3D:meshes+=1
		if node is CollisionShape3D:colliders+=1
		if node.get_meta("building_fragment",false):fragments+=1
	check(game.city.foods.size()<=900 and meshes<=1200 and colliders<=2000,"The actual dense city remains within the shared body, mesh and collider budgets")
	check(fragments==0,"The real scene contains no facade shell fragments")
	var kinds:Dictionary={};var invalid_geometry:Array[String]=[];var invalid_bounds:Array[String]=[];var invalid_collision:Array[String]=[];var invalid_material:Array[String]=[];var opening:=0;var middle_palaces:=0;var late:=0;var levels:Dictionary={}
	var layout:Dictionary=game.city.layout_metadata();var lanes:Array=layout.road_clearance
	var probe:=SizeProbe.new();root.add_child(probe)
	for body in game.city.static_foods():
		var kind:String=body.get_meta("toy_kind","");var minimum:int=int(body.get_meta("minimum_level",0))
		levels[minimum]=int(levels.get(minimum,0))+1
		if not is_instance_valid(body.support_parent) and minimum<=2 and Vector2(body.position.x,body.position.z).distance_to(layout.spawn)<16:opening+=1
		if kind in ["toy_castle","grand_castle"] and not is_instance_valid(body.support_parent):
			if minimum<=5:middle_palaces+=1
			if minimum>=9:late+=1
		if not KINDS.has(kind):continue
		kinds[kind]=int(kinds.get(kind,0))+1
		var view:MeshInstance3D=body.get_node_or_null("ToyVisual")
		if view==null or view.mesh==null or not view.mesh.get_meta("fairytale_authored",false) or geometry_signature(view.mesh)!=geometry_signature(provider.mesh_for(kind,int(body.get_meta("toy_palette",0)))):invalid_geometry.append(str(body.name));continue
		var points:=visual_points(body);var box:=point_bounds(points);var maximum_radius:=0.0
		for point in points:maximum_radius=maxf(maximum_radius,Vector2(point.x,point.z).length())
		var area:=footprint(body,points)
		if not box.size.is_equal_approx(body.half_size*2) or not is_equal_approx(box.size.y,body.height) or absf(maximum_radius-body.footprint)>.0001 or minimum!=Growth.level_for_radius(maximum_radius*1.08) or not COMMON_AREA.encloses(area) or not lanes.all(func(lane):return not area.intersects(lane,true)):invalid_bounds.append(str(body.name))
		var parts:=collision_points(body);var contained:=not parts.is_empty()
		for point in parts:contained=contained and point.is_finite() and box.grow(.001).has_point(point)
		probe.radius=maximum_radius*1.08-.0001
		if not contained or body.can_fit(probe):invalid_collision.append(str(body.name))
		var material:Material=view.material_override
		if material==null:invalid_material.append(str(body.name))
		elif body.category=="building" and (not material is ShaderMaterial or not body.get_meta("dither_building",false) or not is_zero_approx(float(material.get_shader_parameter("reveal_occluder")))):invalid_material.append(str(body.name))
	check(kinds.size()==KINDS.size(),"All five authored architecture kinds appear as real playable bodies")
	check(invalid_geometry.is_empty(),"Every architectural physics owner uses its real corresponding Blender geometry: "+str(invalid_geometry))
	check(invalid_bounds.is_empty(),"Actual architecture bounds, admission levels and rotated street clearance agree: "+str(invalid_bounds))
	check(invalid_collision.is_empty(),"Actual architecture collider envelopes and undersized-mouth rejection agree: "+str(invalid_collision))
	check(invalid_material.is_empty(),"Whole habitable buildings start with their inspectable opaque reveal material: "+str(invalid_material))
	check(opening>=12 and levels.size()>=9,"The real opening inventory and size-level variety remain sustained")
	check(middle_palaces>=8 and late>=8,"Real level-five bridge palaces and larger late castles coexist")
	check(game.round_duration()==90.0 and game.remaining==90.0,"The selected third map retains its real 90-second starting round")
	metrics.density={"sunny_city":baseline,"fairytale":current,"low":low,"middle":middle,"high":high}
	metrics.scene={"bodies":game.city.foods.size(),"nodes":nodes.size(),"meshes":meshes,"colliders":colliders,"authored_kinds":kinds,"opening_targets":opening,"bridge_palaces":middle_palaces,"late_castles":late,"admission_levels":levels}
	metrics.environment={"sky_assigned":game.scene_environment.sky!=null,"reflected_light_source":game.scene_environment.reflected_light_source,"ambient_energy":game.scene_environment.ambient_light_energy,"sun_energy":game.scene_sun.light_energy,"shadows":game.scene_sun.shadow_enabled,"scope":"Configuration only; no rendered highlight verdict"}
	check(game.scene_environment.sky!=null and game.scene_environment.reflected_light_source==Environment.REFLECTION_SOURCE_SKY and game.scene_sun.shadow_enabled,"Toy lighting assigns an actual sky reflection source while retaining directional shadows")
	probe.free()

func on_collected(body:Node3D,hole:Node3D)->void:
	var id:=body.get_instance_id()
	var top:float=body.global_position.y+body.vertical_extent()
	if not receipts.has(id):receipts[id]=[]
	receipts[id].append({"points":body.points,"top":top,"player":hole==game.player,"mesh_authored":body.get_node("ToyVisual").mesh.get_meta("fairytale_authored",false)})
func inspect_physical()->void:
	var target:Node3D
	for body in game.city.static_foods():
		if body.category=="building" and body.get_meta("toy_kind","")=="toy_castle" and not is_instance_valid(body.support_parent) and int(body.get_meta("minimum_level"))<=5:target=body;break
	check(target!=null,"An actual approachable authored palace provides the whole-body physics fixture")
	if target==null:return
	var id:=target.get_instance_id();var expected:int=target.points;var view:MeshInstance3D=target.get_node("ToyVisual");var mesh:Mesh=view.mesh;var pose:Transform3D=view.transform
	var level:int=int(target.get_meta("minimum_level"));game.player.level=level;game.player.score=Growth.level_start_for(level);game.player.radius=Growth.radius_for_level(level)
	game.player.position=Vector3(target.position.x,0,target.position.z);game.player.velocity=Vector3.ZERO;game.player._sync_shape();game.ground.sync()
	var before:int=game.player.score;game.item_collected.connect(on_collected)
	target.vinyl_material.set_shader_parameter("reveal_occluder",1.0)
	check(target.begin_swallow(game.player),"Real size admission starts the authored whole palace falling")
	check(target.points==expected and view.mesh==mesh and view.transform==pose and is_zero_approx(float(target.vinyl_material.get_shader_parameter("reveal_occluder"))),"Admission clears reveal and preserves the original authored model, transform and reward")
	check(game.player.score==before and not receipts.has(id),"Physical admission awards no premature building points")
	for _frame in 360:
		if not is_instance_valid(target):break
		game.scan_food();await physics_frame
	var rows:Array=receipts.get(id,[])
	check(not is_instance_valid(target) and rows.size()==1,"The actual complete palace fall emits exactly one collection receipt")
	check(rows.size()==1 and int(rows[0].points)==expected and rows[0].top<-3.5 and rows[0].player and rows[0].mesh_authored,"Only the whole authored body below the collection plane grants its original points")
	var total:=0
	for recorded in receipts.values():
		for row in recorded:
			if row.player:total+=int(row.points)
	check(game.player.score==before+total,"Actual player growth equals completed physics receipts, including incidental real collections")
	metrics.physical={"scope":"Explicitly positioned level-five fixture; not ordinary 90-second pacing","palace_id":id,"expected_points":expected,"receipts":rows,"all_player_points":total}

func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	AudioServer.set_bus_mute(0,true)
	provider=load("res://fidelity/fairytale_meshes.gd")
	check(provider!=null,"The runtime package contains the authored FairytaleMeshes provider")
	if provider!=null:
		inspect_geometry()
		await inspect_arch_opening()
		await isolated_game("city");var baseline:=density(game.city,false)
		check(game.scene_environment.sky==null and game.scene_environment.ambient_light_source==Environment.AMBIENT_SOURCE_COLOR,"Ordinary City retains its prior ambient-color environment after the toy-only lighting upgrade")
		await free_game()
		await isolated_game("toys");inspect_world(baseline);await inspect_physical();await free_game()
	for path in progress_paths:
		if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
	var result:={"checks":checks,"failures":failures,"metrics":metrics,"scope":"Actual authored mesh arrays, colliders, same-area density and explicit whole-body physics; no user save, production SDK, rendered gloss, ordinary-round pacing or phone performance claim"}
	print("FAIRYTALE_CITY_ACCEPTANCE "+JSON.stringify(result))
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file:=FileAccess.open(argument.trim_prefix("--report="),FileAccess.WRITE)
			if file!=null:file.store_string(JSON.stringify(result,"\t")+"\n")
	quit(0 if failures.is_empty() else 1)
