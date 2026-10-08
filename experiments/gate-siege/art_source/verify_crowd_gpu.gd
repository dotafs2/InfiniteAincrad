extends SceneTree
var frame:=0
func _initialize() -> void:
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
 root.size=Vector2i(900,900)
 root.content_scale_size=Vector2i(900,900)
 DisplayServer.window_set_size(Vector2i(900,900))
 var world=Node3D.new();root.add_child(world)
 var env=WorldEnvironment.new();var e=Environment.new();e.background_mode=Environment.BG_COLOR;e.background_color=Color("293442");e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color("e1e8f2");e.ambient_light_energy=.35;env.environment=e;world.add_child(env)
 var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-55,-30,0);light.light_energy=.55;light.shadow_enabled=true;world.add_child(light)
 var cam=Camera3D.new();cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.size=11.5;world.add_child(cam);cam.look_at_from_position(Vector3(0,12,13),Vector3(0,0,-3.2))
 var floor=MeshInstance3D.new();floor.mesh=BoxMesh.new();floor.mesh.size=Vector3(7,.08,17);var fm=StandardMaterial3D.new();fm.albedo_color=Color("6e737b");floor.material_override=fm;world.add_child(floor);floor.position=Vector3(0,-.06,-4)
 var proto=(load("res://assets/models/zombie.glb") as PackedScene).instantiate();var mesh_node=find_mesh(proto);var mat=mesh_node.get_active_material(0)
 assert(mat.vertex_color_use_as_albedo);assert(not mat.vertex_color_is_srgb)
 print("CROWD_GPU vertex=",mat.vertex_color_use_as_albedo," srgb=",mat.vertex_color_is_srgb," surfaces=",mesh_node.mesh.get_surface_count()," aabb=",mesh_node.mesh.get_aabb())
 var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true;mm.mesh=mesh_node.mesh;mm.instance_count=288
 var batch=MultiMeshInstance3D.new();batch.multimesh=mm;world.add_child(batch)
 for i in range(288):
  mm.set_instance_transform(i,Transform3D(Basis(Vector3.UP,PI).scaled(Vector3.ONE*1.1),Vector3(-2.7+float(i%16)*.36,0,-float(i/16)*.44)))
  mm.set_instance_color(i,Color.WHITE)
 proto.free()
func find_mesh(n:Node) -> MeshInstance3D:
 if n is MeshInstance3D:return n
 for c in n.get_children():
  var v=find_mesh(c)
  if v:return v
 return null
func _process(_dt:float) -> bool:
 frame+=1
 if frame==24:
  var img=root.get_texture().get_image();img.save_png("res://art_source/crowd-gpu-verification.png");print("CROWD_GPU_CAPTURE_COMPLETE ",img.get_size());quit()
 return false
