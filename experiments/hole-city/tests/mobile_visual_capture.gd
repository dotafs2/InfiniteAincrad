extends SceneTree
var game:Node3D
func _initialize()->void:run.call_deferred()
func settle()->void:
 for i in 5:await process_frame
 await RenderingServer.frame_post_draw
func snap(label:String)->void:
 await settle()
 root.get_texture().get_image().save_png("res://artifacts/mobile/"+label+".png")
func run()->void:
 DirAccess.make_dir_recursive_absolute("res://artifacts/mobile")
 game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
 await snap("city-menu")
 game.select_map("food")
 await snap("food-menu")
 for map in ["city","food"]:
  game.selected_map=map;game.start_level()
  await snap(map+"-play")
  game.set_process(false)
  game.camera.position=Vector3(67,85,85);game.camera.look_at(Vector3(0,0,0))
  await snap(map+"-overview")
  game.set_process(true)
 game.free()
 var characters:=load("res://tests/character_showcase.gd").new();root.add_child(characters)
 await snap("characters")
 characters.free()
 await process_frame
 quit()
