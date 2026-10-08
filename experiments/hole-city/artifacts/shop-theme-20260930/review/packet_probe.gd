extends SceneTree
func _initialize()->void:
 if not OS.get_cmdline_user_args().has("--test"):quit(2);return
 var stream:AudioStreamOggVorbis=load("res://assets/audio/shop_theme_loop.ogg")
 var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(var_to_bytes(stream.packet_sequence.get("packet_data")))
 print("SHOP_PACKET "+JSON.stringify({"packet_sha256":hash.finish().hex_encode(),"seconds":stream.get_length(),"path":stream.resource_path}))
 quit(0)
