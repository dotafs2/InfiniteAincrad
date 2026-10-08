extends Node3D
## One continuous visual handoff at water entry; collection never respawns a model.
const DURATION:=.42
const GHOST_LIMIT:=3
const VIEW_LIMIT:=6
const SURFACE_LIMIT:=6
const SCAN_LIMIT:=48
const WATCH_LIMIT:=12
var slots:Array[Dictionary]=[]
var views:Array[MeshInstance3D]=[]
var watched:Array[WeakRef]=[]
var started_events:=0
var skipped_events:=0

func _ready()->void:
 for i in GHOST_LIMIT:
  var holder:=Node3D.new();add_child(holder)
  slots.append({"node":holder,"age":DURATION,"views":[],"surfaces":0,"source":null,"was_visible":true,"origin":Vector3.ZERO,"basis":Basis.IDENTITY,"distance":0.0,"fresh":false})
 for i in VIEW_LIMIT:
  var view:=MeshInstance3D.new();add_child(view);view.hide()
  view.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;views.append(view)

func watch(body:Node3D)->void:
 if body.get_meta("rainfall_entry_watched",false):return
 body.set_meta("rainfall_entry_watched",true)
 if watched.size()>=WATCH_LIMIT:skipped_events+=1;return
 watched.append(weakref(body))

func active_count()->int:
 var count:=0
 for slot in slots:
  if slot.age<DURATION:count+=1
 return count

func surface_count()->int:
 var count:=0
 for slot in slots:count+=slot.surfaces
 return count

func clear_views(slot:Dictionary)->void:
 for view in slot.views:
  if not is_instance_valid(view):continue
  view.hide()
  for s in view.mesh.get_surface_count():view.set_surface_override_material(s,null)
  view.mesh=null;view.material_override=null
 slot.views.clear();slot.surfaces=0;slot.age=DURATION

func retire(slot:Dictionary,restore:=false)->void:
 if restore and slot.source!=null:
  var body:Node3D=slot.source.get_ref()
  if is_instance_valid(body) and not body.consumed:body.visible=slot.was_visible
 clear_views(slot);slot.source=null

func _exit_tree()->void:
 for slot in slots:retire(slot,true)

func start(body:Node3D)->bool:
 if body.get_meta("rainfall_entry_started",false) or not body.visible:return false
 var free:Array=slots.filter(func(s):return s.source==null)
 if free.is_empty():skipped_events+=1;return false
 var pending:Array[Node]=[body];var sources:Array[MeshInstance3D]=[]
 var surfaces:=0;var scanned:=0
 while not pending.is_empty():
  var node:Node=pending.pop_back();scanned+=1
  if scanned>SCAN_LIMIT:skipped_events+=1;return false
  if node is MeshInstance3D and node.mesh!=null and node.visible:
   if node.skin!=null:skipped_events+=1;return false
   sources.append(node);surfaces+=node.mesh.get_surface_count()
   if sources.size()>VIEW_LIMIT or surfaces>SURFACE_LIMIT:skipped_events+=1;return false
  for child in node.get_children():
   pending.append(child)
   if scanned+pending.size()>SCAN_LIMIT:skipped_events+=1;return false
 if sources.is_empty() or surface_count()+surfaces>SURFACE_LIMIT or views.filter(func(v):return v.mesh==null).size()<sources.size():
  skipped_events+=1;return false
 var slot:Dictionary=free[0]
 var relative:Transform3D=body.global_transform.affine_inverse()
 for source in sources:
  var view:MeshInstance3D=views.filter(func(v):return v.mesh==null)[0]
  view.reparent(slot.node);view.mesh=source.mesh;view.material_override=source.material_override
  for s in source.mesh.get_surface_count():view.set_surface_override_material(s,source.get_surface_override_material(s))
  view.transform=relative*source.global_transform;view.show();slot.views.append(view)
 # Exact pose and original material: no fade-in, scale reset, lift or colour pop.
 slot.basis=global_basis.inverse()*body.global_basis
 slot.origin=to_local(body.global_position)
 var extent:float=body.vertical_extent()/maxf(.01,global_basis.y.length())
 slot.distance=maxf(.20,slot.origin.y+extent-.075+.20)
 slot.source=weakref(body);slot.was_visible=body.visible
 slot.age=0.0;slot.surfaces=surfaces;slot.fresh=true
 pose(slot)
 body.hide();body.set_meta("rainfall_entry_started",true);started_events+=1
 return true

func pose(slot:Dictionary)->void:
 var t:float=clampf(slot.age/DURATION,0,1)
 var lean:=sin(t*TAU)*deg_to_rad(8.0)*(1.0-t)
 var at:Vector3=slot.origin
 at.y-=smoothstep(0,1,t)*slot.distance
 slot.node.transform=Transform3D(Basis(Vector3.FORWARD,lean)*slot.basis,at)

func advance(delta:float)->void:
 var owner:Node=get_parent().get_parent().get_parent()
 var water_y:float=global_position.y+.075*global_basis.y.length()
 for i in range(watched.size()-1,-1,-1):
  var body:Node3D=watched[i].get_ref()
  if not is_instance_valid(body) or body.consumed or not is_instance_valid(body.claimed_by) or body.claimed_by!=owner:
   watched.remove_at(i);continue
  var extent:float=body.vertical_extent()
  # A fully submerged object must NEVER be brought back to the surface.
  if body.global_position.y+extent<=water_y+.02:
   watched.remove_at(i);continue
  var gap:=Vector2(body.global_position.x-owner.global_position.x,body.global_position.z-owner.global_position.z)
  if body.global_position.y-extent<=-.03 and body.linear_velocity.y<=0 and gap.length()+body.footprint<owner.radius*.98:
   start(body);watched.remove_at(i)
 for slot in slots:
  if slot.source==null:continue
  var body:Node3D=slot.source.get_ref()
  # An invalidated admission restores the original, never invents collection.
  if is_instance_valid(body) and not body.consumed and body.sleeping and not is_instance_valid(body.claimed_by):
   retire(slot,true);continue
  if slot.age<DURATION:
   if slot.fresh:slot.fresh=false;continue
   slot.age+=delta
   if slot.age>=DURATION:clear_views(slot)
   else:pose(slot)
  # Keep the original hidden until real settlement; it cannot reappear after
  # the cosmetic handoff ends. Slots cannot be evicted into a second draw.
  if slot.age>=DURATION and (not is_instance_valid(body) or body.consumed):retire(slot)
