extends SceneTree
var frame:=0
var world:Node3D
func _initialize() -> void:
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
 root.size=Vector2i(1100,760)
 DisplayServer.window_set_size(Vector2i(1100,760))
 root.content_scale_size=Vector2i(1100,760)
 world=Node3D.new();root.add_child(world)
 var env=WorldEnvironment.new();var e=Environment.new();e.background_mode=Environment.BG_COLOR;e.background_color=Color("293442");e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color("e1e8f2");e.ambient_light_energy=.35;e.tonemap_mode=Environment.TONE_MAPPER_FILMIC;env.environment=e;world.add_child(env)
 var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-55,-30,0);light.light_energy=.55;light.shadow_enabled=true;world.add_child(light)
 var cam=Camera3D.new();cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.size=9.5;world.add_child(cam);cam.look_at_from_position(Vector3(0,6,11),Vector3(0,1.7,0))
 var floor=MeshInstance3D.new();floor.mesh=BoxMesh.new();floor.mesh.size=Vector3(30,.08,30);var fm=StandardMaterial3D.new();fm.albedo_color=Color("6e737b");floor.material_override=fm;world.add_child(floor);floor.position.y=-.07
 for item in [["infantry",-3.7,2.3],["zombie",-1.55,3.5],["brute_vest",.9,1.0],["gunner_silver",3.7,1.5]]:
  var n=(load("res://assets/models/"+item[0]+".glb") as PackedScene).instantiate();world.add_child(n);n.position=Vector3(item[1],0,0);n.rotation.y=PI;n.scale*=item[2];check_colors(n,item[0])
 # Test the same one-surface zombie mesh as a MultiMesh, with white per-instance tint.
 var proto=(load("res://assets/models/zombie.glb") as PackedScene).instantiate();var mesh_node=find_mesh(proto)
 var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true;mm.mesh=mesh_node.mesh;mm.instance_count=12
 var batch=MultiMeshInstance3D.new();batch.multimesh=mm;world.add_child(batch)
 for i in range(12):
  mm.set_instance_transform(i,Transform3D(Basis(Vector3.UP,PI),Vector3(-2.2+float(i%6)*.8,0,2.6+float(i/6)*.9)))
  mm.set_instance_color(i,Color.WHITE)
 proto.free()
func find_mesh(n:Node) -> MeshInstance3D:
 if n is MeshInstance3D:return n
 for c in n.get_children():
  var v=find_mesh(c)
  if v:return v
 return null
func check_colors(n:Node,kind:String) -> void:
 if n is MeshInstance3D and kind in ["infantry","zombie"]:
  var mat=n.get_active_material(0)
  print("GPU_PALETTE ",kind," vertex=",mat.vertex_color_use_as_albedo," srgb=",mat.vertex_color_is_srgb)
  assert(mat.vertex_color_use_as_albedo)
 for c in n.get_children():check_colors(c,kind)
func _process(_dt:float) -> bool:
 frame+=1
 if frame==24:
  var img=root.get_texture().get_image();img.save_png("res://art_source/godot-color-verification.png");print("GPU_COLOR_CAPTURE_COMPLETE ",img.get_size());quit()
 return false
