extends SceneTree
const Cache=preload("res://fidelity/prop_collision_cache.gd")
func _initialize()->void:run.call_deferred()
func find_root(parent:PackedInt32Array,index:int)->int:
 while parent[index]!=index:index=parent[index]
 return index
func run()->void:
 var catalog:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/city_kit/manifest.json"))
 DirAccess.make_dir_recursive_absolute("res://assets/prop_collisions")
 var report:Array=[]
 for entry in catalog.assets:
  if entry.group!="prop":continue
  var model:Node3D=load(entry.path).instantiate();root.add_child(model)
  var center:=Vector3(entry.center[0],entry.center[1],entry.center[2])
  var cache:=Cache.new();cache.source_asset=entry.id;cache.source_sha256=entry.file_sha256
  var all_points:=PackedVector3Array()
  for mesh_node in model.find_children("*","MeshInstance3D",true,false):
   var transform:Transform3D=model.global_transform.affine_inverse()*mesh_node.global_transform
   var vertices:=PackedVector3Array()
   var triangles:=PackedInt32Array()
   var lookup:Dictionary={}
   for surface in mesh_node.mesh.get_surface_count():
    var arrays:Array=mesh_node.mesh.surface_get_arrays(surface)
    var source:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
    var remap:=PackedInt32Array()
    for vertex in source:
     var position:Vector3=transform*vertex-center
     var key:=Vector3i(roundi(position.x*100000),roundi(position.y*100000),roundi(position.z*100000))
     if not lookup.has(key):lookup[key]=vertices.size();vertices.append(position)
     remap.append(lookup[key])
    var ids:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
    if ids.is_empty():
     for i in source.size():triangles.append(remap[i])
    else:
     for i in ids:triangles.append(remap[i])
   var parent:=PackedInt32Array()
   for i in vertices.size():parent.append(i)
   for i in range(0,triangles.size(),3):
    var a:=find_root(parent,triangles[i])
    for j in [1,2]:
     var b:=find_root(parent,triangles[i+j]);parent[b]=a
   var islands:Dictionary={}
   for i in vertices.size():
    var key:=find_root(parent,i)
    if not islands.has(key):islands[key]=PackedVector3Array()
    islands[key].append(vertices[i])
   for points in islands.values():
    if points.size()<4:continue
    var shape:=ConvexPolygonShape3D.new()
    shape.points=points
    all_points.append_array(points)
    # The default 4 cm margin dwarfs thin signposts; use a 2 mm skin.
    shape.margin=.002
    cache.shapes.append(shape)
    var midpoint:=Vector3.ZERO
    for point in points:midpoint+=point
    midpoint/=points.size()
    cache.rim_samples.append(midpoint)
    for axis in 3:
     for direction in [-1,1]:
      var tip:Vector3=points[0]
      for point in points:
       if point[axis]*direction>tip[axis]*direction:tip=point
      cache.rim_samples.append(tip)
      var face:=Vector3.ZERO
      var count:=0
      for point in points:
       if absf(point[axis]-tip[axis])<.0001:face+=point;count+=1
      cache.rim_samples.append(face/maxi(1,count))
  var lowest:=INF
  for point in all_points:lowest=minf(lowest,point.y)
  var feet:=0
  for point in all_points:
   if point.y<lowest+.005:cache.support_anchor+=point;feet+=1
  cache.support_anchor/=maxi(1,feet)
  for point in all_points:cache.support_radius=maxf(cache.support_radius,Vector2(point.x-cache.support_anchor.x,point.z-cache.support_anchor.z).length())
  assert(not cache.shapes.is_empty(),entry.id)
  var path:String="res://assets/prop_collisions/"+entry.id+".res"
  assert(ResourceSaver.save(cache,path)==OK,path)
  report.append({"id":entry.id,"hulls":cache.shapes.size(),"source_sha256":entry.file_sha256})
  model.free()
 print("PROP_COLLISION_BAKE "+JSON.stringify(report))
 FileAccess.open("res://assets/prop_collisions/manifest.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
 await process_frame;quit()
