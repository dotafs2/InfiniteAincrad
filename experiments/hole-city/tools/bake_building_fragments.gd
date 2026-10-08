extends SceneTree
const Cache=preload("res://fidelity/fracture_cache.gd")
const City=preload("res://fidelity/catalog_city.gd")
func _initialize()->void:run.call_deferred()
func clip(poly:Array,axis:int,bound:float,above:bool)->Array:
 var result:=[]
 if poly.is_empty():return result
 var a:Array=poly.back()
 var da:float=(a[0][axis]-bound)*(1.0 if above else -1.0)
 for b in poly:
  var db:float=(b[0][axis]-bound)*(1.0 if above else -1.0)
  if (da>=0)!=(db>=0):
   var t:float=da/(da-db)
   result.append([a[0].lerp(b[0],t),a[1].lerp(b[1],t).normalized(),a[2].lerp(b[2],t),a[3].lerp(b[3],t)])
  if db>=0:result.append(b)
  a=b;da=db
 return result
func emit(poly:Array,offset:Vector3,v:PackedVector3Array,n:PackedVector3Array,c:PackedColorArray,uv:PackedVector2Array)->void:
 for j in range(1,poly.size()-1):
  for data in [poly[0],poly[j],poly[j+1]]:
   v.append(data[0]-offset);n.append(data[1]);c.append(data[2]);uv.append(data[3])
func bake(body:Node3D)->Resource:
 var source:Array=[]
 var bounds:=AABB()
 var first:=true
 for node in body.find_children("*","MeshInstance3D",true,false):
  if node.mesh==null:continue
  var transform:Transform3D=body.global_transform.affine_inverse()*node.global_transform
  var aabb:AABB=transform*node.mesh.get_aabb()
  bounds=aabb if first else bounds.merge(aabb);first=false
  for surface in node.mesh.get_surface_count():
   var a:Array=node.mesh.surface_get_arrays(surface)
   var vertices:PackedVector3Array=a[Mesh.ARRAY_VERTEX]
   var normals:PackedVector3Array=a[Mesh.ARRAY_NORMAL]
   var colors:PackedColorArray=a[Mesh.ARRAY_COLOR] if a[Mesh.ARRAY_COLOR]!=null else PackedColorArray()
   var uvs:PackedVector2Array=a[Mesh.ARRAY_TEX_UV] if a[Mesh.ARRAY_TEX_UV]!=null else PackedVector2Array()
   var ids:PackedInt32Array=a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
   if ids.is_empty():
    for k in vertices.size():ids.append(k)
   for k in range(0,ids.size(),3):
    var triangle:=[]
    for j in 3:
     var i:int=ids[k+j]
     triangle.append([transform*vertices[i],(transform.basis.inverse().transposed()*normals[i]).normalized(),colors[i] if i<colors.size() else Color.WHITE,uvs[i] if i<uvs.size() else Vector2.ZERO])
    source.append(triangle)
 var cache:=Cache.new()
 for floor_index in 4:
  for corner in 4:
   var cell_size:=bounds.size/Vector3(2,4,2)
   var cell:=AABB(bounds.position+cell_size*Vector3(corner%2,floor_index,corner/2),cell_size)
   var offset:=cell.get_center()
   var v:=PackedVector3Array();var n:=PackedVector3Array();var c:=PackedColorArray();var uv:=PackedVector2Array()
   for triangle in source:
    var polygon:Array=triangle
    for axis in 3:
     polygon=clip(polygon,axis,cell.position[axis],true)
     polygon=clip(polygon,axis,cell.end[axis],false)
     if polygon.size()<3:break
    if polygon.size()>=3:emit(polygon,offset,v,n,c,uv)
   cache.exterior_vertex_counts.append(v.size())
   # Preserve the actual shell. Rectangular cell caps would fill empty rooms
   # and roof gaps with new panels when the pieces separate.
   var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
   arrays[Mesh.ARRAY_VERTEX]=v;arrays[Mesh.ARRAY_NORMAL]=n;arrays[Mesh.ARRAY_COLOR]=c;arrays[Mesh.ARRAY_TEX_UV]=uv
   var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
   cache.meshes.append(mesh);cache.cells.append(cell)
 return cache
func run()->void:
 var world:=Node3D.new();root.add_child(world)
 var city:=City.new();world.add_child(city);city.read_catalog()
 DirAccess.make_dir_recursive_absolute("res://assets/fractures")
 var count:=0
 for entry in city.catalog:
  if entry.group!="building":continue
  var body:=city.place(entry,Vector2.ZERO)
  var cache:=bake(body)
  var path:String="res://assets/fractures/"+entry.id+".res"
  if ResourceSaver.save(cache,path,ResourceSaver.FLAG_COMPRESS)!=OK:quit(1);return
  body.queue_free();await process_frame;count+=1
 print("FRACTURE_BAKE "+str(count)+" buildings / "+str(count*16)+" original-surface pieces")
 world.free();await process_frame;quit()
