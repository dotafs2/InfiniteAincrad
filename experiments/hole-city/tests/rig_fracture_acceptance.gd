extends SceneTree
const City=preload("res://fidelity/catalog_city.gd")
var checks:=0
var failures:Array[String]=[]
var rig_results:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func run()->void:
 var world:=Node3D.new();root.add_child(world)
 var city:=City.new();world.add_child(city);city.read_catalog()
 for entry in city.catalog:
  if entry.group=="building":
   var body:=city.place(entry,Vector2.ZERO)
   var cache:Resource=body.fracture_cache
   check(cache!=null and cache.meshes.size()==16,entry.id+": sixteen cached original-surface fragments")
   var source_area:=0.0
   for source in body.find_children("*","MeshInstance3D",true,false):
    if source.mesh==null:continue
    for surface in source.mesh.get_surface_count():
     var source_arrays:Array=source.mesh.surface_get_arrays(surface)
     var vs:PackedVector3Array=source_arrays[Mesh.ARRAY_VERTEX]
     var ids:PackedInt32Array=source_arrays[Mesh.ARRAY_INDEX] if source_arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
     if ids.is_empty():
      for i in vs.size():ids.append(i)
     for i in range(0,ids.size(),3):source_area+=(vs[ids[i+1]]-vs[ids[i]]).cross(vs[ids[i+2]]-vs[ids[i]]).length()*.5
   var colors:={};var exterior:=0;var cut_area:=0.0
   for i in cache.meshes.size():
    var a:Array=cache.meshes[i].surface_get_arrays(0)
    check(cache.exterior_vertex_counts[i]>0,entry.id+": fragment retains real exterior triangles")
    exterior+=cache.exterior_vertex_counts[i]
    var vs:PackedVector3Array=a[Mesh.ARRAY_VERTEX]
    for j in range(0,cache.exterior_vertex_counts[i],3):cut_area+=(vs[j+1]-vs[j]).cross(vs[j+2]-vs[j]).length()*.5
    for j in cache.exterior_vertex_counts[i]:colors[a[Mesh.ARRAY_COLOR][j].to_html()]=true
   check(colors.size()>=4 and exterior>100,entry.id+": roof, wall, window and trim colors survive fracture")
   check(absf(source_area-cut_area)<source_area*.003,entry.id+": exterior triangle area is conserved through cutting")
   body.free()
  if entry.group!="person":continue
  var model:Node3D=load(entry.path).instantiate();world.add_child(model)
  var skeleton:Skeleton3D=model.find_child("Skeleton3D",true,false)
  var player:AnimationPlayer=model.find_child("AnimationPlayer",true,false)
  var mesh:MeshInstance3D=model.find_child("*",true,false) as MeshInstance3D
  for child in model.find_children("*","MeshInstance3D",true,false):mesh=child;break
  check(skeleton!=null and skeleton.get_bone_count()>=10,entry.id+": original articulated hierarchy and accessory binds retained")
  var a:Array=mesh.mesh.surface_get_arrays(0)
  var vertices:PackedVector3Array=a[Mesh.ARRAY_VERTEX]
  var joints:PackedInt32Array=a[Mesh.ARRAY_BONES]
  var weights:PackedFloat32Array=a[Mesh.ARRAY_WEIGHTS]
  var bindings:Array[Transform3D]=[]
  var names:Array[int]=[]
  for i in mesh.skin.get_bind_count():
   var name:=mesh.skin.get_bind_name(i)
   names.append(skeleton.find_bone(name) if name!=&"" else mesh.skin.get_bind_bone(i))
   bindings.append(mesh.skin.get_bind_pose(i))
  var min_y:=INF;var max_y:=-INF;var max_span:=0.0
  var upright:=true;var seam:=true
  for clip in entry.animations:
   var animation:Animation=player.get_animation(clip)
   var first_poses:Array[Quaternion]=[]
   for sample in 9:
    player.play(clip);player.seek(animation.length*float(sample)/8.0,true)
    var transforms:Array[Transform3D]=[]
    for i in bindings.size():transforms.append(skeleton.get_bone_global_pose(names[i])*bindings[i])
    var root_index:=skeleton.find_bone("root")
    if skeleton.get_bone_global_pose(root_index).basis.y.normalized().dot(Vector3.UP)<.999:upright=false
    for i in skeleton.get_bone_count():
     var rotation:=skeleton.get_bone_pose_rotation(i)
     if sample==0:first_poses.append(rotation)
     if sample==8 and rotation.angle_to(first_poses[i])>.001:seam=false
    var low:=Vector3(INF,INF,INF);var high:=-low
    for i in vertices.size():
     var vertex:=Vector3.ZERO
     for k in 4:
      if weights[i*4+k]>.0:vertex+=(transforms[joints[i*4+k]]*vertices[i])*weights[i*4+k]
     low=low.min(vertex);high=high.max(vertex)
    min_y=minf(min_y,low.y);max_y=maxf(max_y,high.y);max_span=maxf(max_span,(high-low).length())
  check(upright,entry.id+": no whole-body pitching during locomotion or gestures")
  check(seam,entry.id+": rotations loop without a seam")
  check(min_y>-.18 and max_y<2.5 and max_span<3.0,entry.id+": skinned vertices remain bounded near the ground")
  player.play("Walk");player.seek(.3125,true)
  var li:=skeleton.find_bone("thighL");var ri:=skeleton.find_bone("thighR")
  var left:=skeleton.get_bone_rest(li).basis.get_rotation_quaternion().inverse()*skeleton.get_bone_pose_rotation(li)
  var right:=skeleton.get_bone_rest(ri).basis.get_rotation_quaternion().inverse()*skeleton.get_bone_pose_rotation(ri)
  check(left.x*right.x<0 and left.angle_to(right)>.4,entry.id+": left and right legs alternate")
  rig_results.append({"role":entry.kind,"min_y":min_y,"max_y":max_y,"max_diagonal":max_span})
  model.free()
 var report:={"checks":checks,"failures":failures,"rigs":rig_results}
 print("RIG_FRACTURE_ACCEPTANCE "+JSON.stringify(report))
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--report="):FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 world.free();await process_frame;quit(0 if failures.is_empty() else 1)
