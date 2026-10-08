extends SceneTree
func _initialize()->void:run.call_deferred()
func run()->void:
 root.size=Vector2i(540,960)
 var game=load("res://fidelity/game.gd").new();root.add_child(game);game.set_physics_process(false)
 for state in [true,false]:
  game.music_enabled=state;game.sfx_enabled=state;game.ui.refresh()
  for i in 3:await process_frame
  for id in ["audio-music","audio-sfx"]:
   var b=game.ui.get_node(id);var font=b.get_theme_font("font");var fs=b.get_theme_font_size("font_size");var rect=b.get_global_rect()
   print("GEOMETRY ",JSON.stringify({"label":b.text,"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"font_size":fs,"glyph_width":font.get_string_size(b.text,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x,"minsize":str(b.get_combined_minimum_size()),"level_overlap":rect.intersects(Rect2(24,26,130,50)),"wallet_overlap":rect.intersects(Rect2(394,26,122,50))}))
 game.free()
 for i in 2:await process_frame
 quit()
