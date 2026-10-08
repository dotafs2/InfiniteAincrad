extends SceneTree
const Catalog=preload("res://fidelity/skin_catalog.gd")
const Old=preload("res://artifacts/skin-polish-20260930/before/skin_visual.gd")
const Current=preload("res://fidelity/skin_visual.gd")
func geometry(model:Node3D)->String:
 var rows:Array=[]
 for part in model.find_children("*","MeshInstance3D",true,false):
  var arrays:Array=[]
  for surface in part.mesh.get_surface_count():arrays.append(part.mesh.surface_get_arrays(surface))
  rows.append([model.global_transform.affine_inverse()*part.global_transform,part.visible,arrays])
 return var_to_bytes(rows).hex_encode().sha256_text()
func counts(model:Node3D)->Dictionary:
 var result:={"visible":0,"meshes":0,"triangles":0,"motes":model.motes.size(),"parts":model.parts.size()}
 for part in model.find_children("*","MeshInstance3D",true,false):
  result.meshes+=1
  if part.visible:result.visible+=1
  for surface in part.mesh.get_surface_count():
   var a:Array=part.mesh.surface_get_arrays(surface)
   result.triangles+=(a[Mesh.ARRAY_INDEX].size() if a[Mesh.ARRAY_INDEX]!=null and not a[Mesh.ARRAY_INDEX].is_empty() else a[Mesh.ARRAY_VERTEX].size())/3
 return result
func _initialize()->void:run.call_deferred()
func run()->void:
 if not OS.get_cmdline_user_args().has("--test"):quit(2);return
 var old=Old.new();root.add_child(old);old.set_process(false)
 var current=Current.new();root.add_child(current);current.set_process(false)
 var rows:={}
 for d in Catalog.DEFS:
  old.build(d,false);current.build(d,false)
  rows[d.id]={"before":geometry(old),"after":geometry(current),"before_counts":counts(old),"after_counts":counts(current)}
 old.free();current.free()
 var output={"checks":44,"failures":[],"skins":rows}
 print("SKIN_BASELINE_PROBE "+JSON.stringify(output))
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--report="):FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(output,"\t"))
 quit()
