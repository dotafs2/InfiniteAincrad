extends SceneTree
## Independent geometry and real collection presentation review. No saves or renderer capture.
const Catalog=preload("res://fidelity/skin_catalog.gd")
const Visual=preload("res://fidelity/skin_visual.gd")
const IDS=["pizza_party","frosted_cake","fox_den","bunny_burrow","rocket_port","dragon_roost"]
const REWORKED_COMMON=["cookie_bite","citrus_slice","melon_munch","pancake_stack","bacon_curl","cocoa_square"]
## Pinned actual buffers from the retained pre-polish script; no artifact dependency in PCK.
const BEFORE_GEOMETRY:={"bacon_curl":"62cac037f64a552417c6b268797210d5db7fe60ac8d7a9cd89d54f3be86d247d","berry_crown":"4f88c860a746dd65f16f8c95d8356bde7061cba3bb26b01c100023cf5de11e8a","bunny_burrow":"679f71719f0f2743bf4888e719b5b47edcdba61f38328f8e94cf1bcec1973372","carnival_tent":"663758f29094cdf36960e365b32dbb0088d5e9b66785fc0888741f45d7b4005d","cinder":"7631eb72e194e60dba83346dab3ac195be230623e7862a6aaa5e6490c2442af0","citrus_slice":"62cac037f64a552417c6b268797210d5db7fe60ac8d7a9cd89d54f3be86d247d","clockwork_key":"4f88c860a746dd65f16f8c95d8356bde7061cba3bb26b01c100023cf5de11e8a","cocoa_square":"62cac037f64a552417c6b268797210d5db7fe60ac8d7a9cd89d54f3be86d247d","cookie_bite":"62cac037f64a552417c6b268797210d5db7fe60ac8d7a9cd89d54f3be86d247d","copper_ring":"0c2854100d5ee16c85529363257100dd571cde1feb2492d39023cdaaa46c5a91","coral_reef":"4b56e5fd8f3d3b4b25e96d630688ba5e1119b666a77759a78306844e8082e22c","core_shell":"ae6caab32f8dd407ff9158787f138aa1dabf0670e16acf93e8c9b7b8f392bd73","crab_cove":"f7991d74f93e6e867badd495a1a746a0693fc658bb488c6808e3d9d2db8cd8cf","dragon_roost":"efbdbef1d9ba735d83068d8249b14d915631a3e90218133b80a8b99ed82bce2a","fox_den":"96faf7a65626276999fcd0587dc5f3bad73028ebae14f439b5e1389f6d638d8b","frog_pond":"4f88c860a746dd65f16f8c95d8356bde7061cba3bb26b01c100023cf5de11e8a","frosted_cake":"7327ffff0b861864bf23aeba32a298fa4da721b2bd5cff0c957d715437862fb2","gravitas":"9cb9564fd7cc037eff92236664a308d04a6339ce47056b201d1d3dcec1fcb41a","jelly_veil":"a6733b6c2151493090570e56ed0018a59ab1c55934d74fc442419b2893cc638d","lantern":"acf7c4b7449e11f8bb14fa7151dc7c180c572eff610a5a049527ea8e9e049d7a","melon_munch":"62cac037f64a552417c6b268797210d5db7fe60ac8d7a9cd89d54f3be86d247d","moon_dream":"d76727c65a8eb6c8c5635e0d5de3dc71e29d1cabdee9bfd32bfd1e82e8cb94c5","moss_bloom":"cfecfca98b9792041f536055d488bf54a362e7f6ff72ae2dd64c813de496898e","music_stage":"aa044e8ada294207e8cf7f34a244d3df5e87276b939259c95a9d221275d2433a","orbit":"7de890f1b4bf99539516c7a565805355e23dda2adabb7b2d3138fdbd7e641a08","owl_hollow":"6bc13683608c8b359a38f11f0950ce98be2f9740ea4a752b2bb035e344111178","pancake_stack":"62cac037f64a552417c6b268797210d5db7fe60ac8d7a9cd89d54f3be86d247d","pineapple_top":"d61cb9346cab02208770840462f11471a7b6ace0b52cd8583bf4dd24fea15731","pizza_party":"8f343467f988008849e82c72cf101163868e66c7257ab8a7b23502f8d04a64c1","popcorn_pot":"a0e5ceafb97738790f56f82de7a7d3373a702bb7d7a843c52d0f39c3fe32bdb4","pretzel_twist":"4f88c860a746dd65f16f8c95d8356bde7061cba3bb26b01c100023cf5de11e8a","prism_vale":"2c08b6b32626120861324e4c46ef2938698a8d948ee48aff1fa154e29c81e629","rainbow_bridge":"2fe38e1bd412456fbcf60dbea9eeba28a5fb885c6e68029469f3e2a52f707386","rocket_port":"9f1bede4ae6dc489664eb8890cfc280f4a62815174875a67a571c1a42d3d34d1","royal_gate":"dbe252690e086396bb31be7d6520c5d3e129d641bbc75ddb11959f54f68144c3","satellite_dish":"b4ec966a11929d55806c481c9cb22bad54166b49d5c05eed7cf7252dfcec468c","shard":"c3c83f736da078e4601733a1b985d829d241a0d830adf470fb8b92238a3e6ed3","snail_trail":"e2a9a92f317668416cc3b9586117b117eba36728fe39c37a45cbf039bd11303f","storm_cloud":"ae9134f826aca704c0a6d50646d6ed8dfea182c89ab06c8c9fb8ce956f3d7695","sugar_glaze":"4f88c860a746dd65f16f8c95d8356bde7061cba3bb26b01c100023cf5de11e8a","sunny_side":"4f88c860a746dd65f16f8c95d8356bde7061cba3bb26b01c100023cf5de11e8a","tide":"59c0bacf397d3e62dd78515e1ec5b52f0d27a99ff181df3f0d57a1481e64f81e","turtle_shell":"4f88c860a746dd65f16f8c95d8356bde7061cba3bb26b01c100023cf5de11e8a","waffle_stack":"4f88c860a746dd65f16f8c95d8356bde7061cba3bb26b01c100023cf5de11e8a"}
var checks:=0
var failures:Array[String]=[]
var forms:Array=[]
var game:Node3D
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func frames(n:=2)->void:
 for i in n:await process_frame
func geometry(model:Node3D)->String:
 var rows:Array=[]
 for part in model.find_children("*","MeshInstance3D",true,false):
  var arrays:Array=[]
  for surface in part.mesh.get_surface_count():arrays.append(part.mesh.surface_get_arrays(surface))
  rows.append([model.global_transform.affine_inverse()*part.global_transform,part.visible,arrays])
 return var_to_bytes(rows).hex_encode().sha256_text()
func illuminated(view:SubViewport)->bool:
 var envs:=view.find_children("*","WorldEnvironment",false,false)
 var lamps:=view.find_children("*","DirectionalLight3D",false,false)
 if envs.size()!=1 or lamps.size()!=1:return false
 var env:Environment=envs[0].environment;var lamp:DirectionalLight3D=lamps[0]
 return env!=null and env.ambient_light_source==Environment.AMBIENT_SOURCE_COLOR and env.ambient_light_energy>0 and env.ambient_light_color.get_luminance()>.4 and lamp.visible and lamp.light_energy>0 and lamp.light_color.get_luminance()>.4 and not lamp.shadow_enabled
func model_in(view:SubViewport)->Node3D:
 for child in view.get_children():
  if child is Visual:return child
 return null
func profile(id:String,size_:Vector2i)->void:
 root.size=size_;await frames(3)
 var ui=game.ui;var slot:int=ui.card_skin_ids.find(id)
 check(slot>=0,"Requested sculpt is actually mounted in current collection page: "+id)
 if slot<0:return
 var view:SubViewport=ui.skin_cards[slot];var model:=model_in(view);var camera:Camera3D=view.get_camera_3d()
 check(view.own_world_3d and illuminated(view),"Actual isolated card has a live directional light and ambient environment: "+id)
 check(camera!=null and camera.projection==Camera3D.PROJECTION_ORTHOGONAL and view.msaa_3d==Viewport.MSAA_2X,"Actual mounted card retains orthographic camera and 2x MSAA: "+id)
 check(ui.card_textures[slot].size==Vector2(144,106) and ui.card_textures[slot].mouse_filter==Control.MOUSE_FILTER_IGNORE,"Logical mobile card bounds and touch pass-through remain unchanged: "+id)
 var same_env:=true
 for other in ui.skin_cards:
  var envs:Array=other.find_children("*","WorldEnvironment",false,false)
  same_env=same_env and envs.size()==1 and envs[0].environment==ui.card_environment
 check(same_env,"Every current card reuses one ambient resource: "+id)
 var active:=0
 for other in ui.skin_cards:
  if other.render_target_update_mode==SubViewport.UPDATE_ALWAYS and model_in(other).is_processing():active+=1
 check(active==1 and model.is_processing(),"Only the selected card renders continuously and animates: "+id)
 var clock_before:float=model.clock_time;await frames(4)
 check(model.clock_time>clock_before,"Selected actual card receives natural SceneTree process frames: "+id)
 var vertices:=PackedVector3Array();var lit:=0;var triangles:=0;var good_material:=true;var curved:=0;var palette:={}
 for part in model.find_children("*","MeshInstance3D",true,false):
  if part.get_meta("sculpted",false):
   lit+=1
   var mat:StandardMaterial3D=part.material_override
   good_material=good_material and mat!=null and mat.shading_mode==BaseMaterial3D.SHADING_MODE_PER_PIXEL and mat.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and not mat.emission_enabled and mat.roughness>=.16 and mat.roughness<=.5 and mat.metallic_specular>=.5 and mat.clearcoat_enabled and is_equal_approx(mat.clearcoat,.22)
   palette[mat.albedo_color.to_html()]=true
  for surface in part.mesh.get_surface_count():
   var a:Array=part.mesh.surface_get_arrays(surface);var vs:PackedVector3Array=a[Mesh.ARRAY_VERTEX];var ns:PackedVector3Array=a[Mesh.ARRAY_NORMAL]
   triangles+=(a[Mesh.ARRAY_INDEX].size() if a[Mesh.ARRAY_INDEX]!=null and not a[Mesh.ARRAY_INDEX].is_empty() else vs.size())/3
   if not part.visible:continue
   for i in vs.size():
    vertices.append(model.global_transform.affine_inverse()*part.global_transform*vs[i])
    if part.get_meta("sculpted",false) and absf(ns[i].x)>.12 and absf(ns[i].y)>.12:curved+=1
 check(lit>=8 and good_material and palette.size()>=3,"Mounted model uses contrasting opaque standard lit materials with supported clearcoat: "+id)
 check(curved>80,"Actual sculpture has curved normals for changing light response: "+id)
 check(model.find_children("*","MeshInstance3D",true,false).size()<=18 and triangles<=4500 and model.parts.is_empty() and model.motes.is_empty(),"Real card including mouth and boost stays within original generic mesh/triangle budget: "+id)
 check(model.mouth!=null and model.find_children("*","CollisionObject3D",true,false).is_empty(),"Card owns a visible opening but no physics or gameplay payload: "+id)
 var margin:=INF
 for yaw in 48:
  model.rotation.y=float(yaw)*TAU/48.0;var fits:=true
  for p in vertices:
   var px:Vector2=camera.unproject_position(model.global_transform*p)/Vector2(view.size)*Vector2(144,106)
   margin=minf(margin,minf(minf(px.x,144-px.x),minf(px.y,106-px.y)))
   fits=fits and px.is_finite() and Rect2(4,4,136,98).has_point(px)
  check(fits,"Every visible real card vertex has four logical pixels clearance across full rotation: %s %s yaw%d"%[id,str(size_),yaw])
 model.rotation=Vector3.ZERO
 forms.append({"id":id,"screen":str(size_),"raster":str(view.size),"triangles_including_mouth":triangles,"minimum_logical_margin":margin,"lit_parts":lit,"palette_colors":palette.size()})
func run()->void:
 if not OS.get_cmdline_user_args().has("--test"):quit(2);return
 var model:=Visual.new();root.add_child(model);model.set_process(false)
 var changed:Array[String]=[];var common_changed:Array[String]=[]
 for d in Catalog.DEFS:
  if not BEFORE_GEOMETRY.has(d.id):continue # Later additions have separate catalog and geometry acceptance.
  model.build(d,false);var actual:=geometry(model)
  if d.id in IDS:
   changed.append(d.id)
   check(actual!=BEFORE_GEOMETRY[d.id],"Requested skin uses newly sculpted real buffers: "+d.id)
  elif d.id in REWORKED_COMMON:
   common_changed.append(d.id)
   check(actual!=BEFORE_GEOMETRY[d.id] and is_instance_valid(model.common),"Six authorized Common reworks replace the old shared-ring buffers: "+d.id)
  else:check(actual==BEFORE_GEOMETRY[d.id],"Untouched skin retains every mesh buffer, transform and visibility: "+d.id)
 check(changed.size()==6 and common_changed.size()==6 and BEFORE_GEOMETRY.size()==44,"Pinned baseline retains six earlier sculpts and exactly six later authorized Common reworks")
 model.free()
 root.content_scale_size=Vector2i(540,960);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_KEEP;root.size=Vector2i(375,812)
 game=load("res://fidelity/main.tscn").instantiate();root.add_child(game);await frames(3)
 game.set_physics_process(false)
 check(game.progress_file().is_empty(),"Test uses no player progress file")
 var coins:int=game.coins;var gems:int=game.gems;var owned:Array=game.owned_skin_ids.duplicate();var equipped:String=game.selected_skin_id
 game.ui.open_holes();await frames()
 check(game.ui.case_opening.result_view.render_target_update_mode==SubViewport.UPDATE_DISABLED and not game.ui.case_opening.result_model.is_processing(),"Collection review does not render or animate the reusable case result")
 for id in IDS:
  var d:Dictionary=game.skin_definition(id)
  game.ui.scroll_to_skin(id);game.ui.select_hole_slot(id);await frames()
  await profile(id,Vector2i(375,812));await profile(id,Vector2i(1170,2532))
 # The former camera+model-only isolated world must fail the illumination oracle.
 var dark:=SubViewport.new();dark.own_world_3d=true;root.add_child(dark)
 var dark_model:=Visual.new();dark.add_child(dark_model);dark_model.build(game.skin_definition(IDS[0]),true);dark.add_child(Camera3D.new())
 check(not illuminated(dark),"Negative oracle rejects a model/camera-only isolated card with no lighting")
 dark.free()
 var retired:Array=game.ui.skin_cards.duplicate();var lamps:Array=[];var models:Array=[]
 for view in retired:lamps.append_array(view.find_children("*","DirectionalLight3D",false,false));models.append(model_in(view))
 game.ui.close_menu()
 check(retired.all(func(v):return v.render_target_update_mode==SubViewport.UPDATE_DISABLED) and models.all(func(m):return not m.is_processing()),"Leaving collection immediately stops cached rendering and animation")
 await frames(3)
 check(retired.all(func(v):return not is_instance_valid(v)) and lamps.all(func(v):return not is_instance_valid(v)),"Retired cards and their new lights are freed together")
 check(game.ui.find_children("*","SubViewport",true,false).size()==3,"Repeated page changes retain only two legacy previews and one permanent case result viewport")
 check(game.ui.case_opening.result_view.render_target_update_mode==SubViewport.UPDATE_DISABLED and not game.ui.case_opening.result_model.is_processing() and not game.ui.case_opening.visible,"The case result stays hidden and dormant after returning Home")
 check(game.coins==coins and game.gems==gems and game.owned_skin_ids==owned and game.selected_skin_id==equipped,"Reviewing locked or owned cosmetics does not change currency, equipment or entitlements")
 check(not game.audio.unlocked and not game.audio.music.playing,"Programmatic review does not authorize or start background audio")
 game.audio.music.stop();await create_timer(.12).timeout;game.free();await frames(2)
 var report:={"checks":checks,"failures":failures,"forms":forms,"scope":"Non-author actual buffers, real UI camera/light/lifecycle and bounded geometry. Headless: no image equivalence or phone performance claim."}
 print("SKIN_POLISH_REVIEW "+JSON.stringify(report))
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--report="):
   var path:=arg.trim_prefix("--report=")
   if not path.is_absolute_path() or "://" in path:quit(2);return
   var f:=FileAccess.open(path,FileAccess.WRITE)
   if f==null:quit(2);return
   f.store_string(JSON.stringify(report,"\t")+"\n");f.close()
 quit(0 if failures.is_empty() else 1)
