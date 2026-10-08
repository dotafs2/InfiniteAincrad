extends SceneTree
const OldUI=preload("res://artifacts/skin-polish-20260930/review/ui-before-review.gd")
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize()->void:run.call_deferred()
func run()->void:
 if not OS.get_cmdline_user_args().has("--test"):quit(2);return
 var game=load("res://fidelity/main.tscn").instantiate();root.add_child(game);game.set_physics_process(false)
 var old=OldUI.new();old.game=game;root.add_child(old);old.open_holes();game.ui.open_holes()
 await process_frame
 var rows:Array=[]
 for ui in [old,game.ui]:
  ui.choose_holes_tab("classic");var index:int=ui.tab_skin_ids().find("pizza_party");ui.change_skin_page(index/6-ui.skin_page);ui.select_hole_slot("pizza_party")
  var views:=0;var lamps:=0;var environments:=0;var litparts:=0
  for view in ui.skin_cards:
   views+=1;lamps+=view.find_children("*","DirectionalLight3D",false,false).size();environments+=view.find_children("*","WorldEnvironment",false,false).size()
   for part in view.find_children("*","MeshInstance3D",true,false):
    if part.get_meta("sculpted",false) and part.material_override.shading_mode==BaseMaterial3D.SHADING_MODE_PER_PIXEL:litparts+=1
  rows.append({"views":views,"lamps":lamps,"environments":environments,"lit_parts":litparts})
 check(rows[0].views==6 and rows[0].lit_parts>0,"Original actual UI mounts six cards including per-pixel sculpture")
 check(rows[0].lamps==0 and rows[0].environments==0,"Original actual UI has no card-world lighting; final lighting oracle rejects it")
 check(rows[1].views==6 and rows[1].lit_parts==rows[0].lit_parts,"Current actual UI mounts the same geometry payload")
 check(rows[1].lamps==6 and rows[1].environments==6,"Current actual UI adds one lamp and one ambient environment per isolated card")
 old.free();game.audio.music.stop();await create_timer(.12).timeout;game.free();await process_frame
 var result:={"checks":checks,"failures":failures,"before":rows[0],"after":rows[1],"scope":"Actual old/new UI instances. No pixel capture; establishes absence and addition of illumination in isolated worlds."}
 print("SKIN_LIGHTING_BASELINE "+JSON.stringify(result))
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--report="):FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
 quit(0 if failures.is_empty() else 1)
