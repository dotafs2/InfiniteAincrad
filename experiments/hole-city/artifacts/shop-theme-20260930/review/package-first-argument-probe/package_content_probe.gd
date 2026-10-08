extends SceneTree
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize()->void:
 if not OS.get_cmdline_user_args().has("--test"):quit(2);return
 check(OS.get_cmdline_args().has("--main-pack"),"Probe explicitly loads an exported package")
 var expected={"res://assets/audio/music_manifest.json":"21cd9b52c6835674db60c2304744b314cd14e8556e31e5e2cda86d04317ac087","res://assets/audio/MUSIC_CREDITS.txt":"eabdbe1a5c7039c71617452183dd3ffe721ed472dc80d77aec7698ad7f39e012","res://assets/audio/README.md":"354dc09d2405623758e3a696f7e3f5c86847884c625c9684fab0d52856ea2680"}
 for path in expected:
  check(FileAccess.file_exists(path),"Actual package includes "+path)
  check(FileAccess.get_sha256(path)==expected[path],"Packaged metadata bytes match the independently reviewed source: "+path)
 var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/music_manifest.json"))
 check(manifest is Dictionary and manifest.author=="Cleyton Kauffman" and manifest.license=="CC0-1.0" and manifest.source_member=="shop_theme/Buy Something!.ogg" and manifest.sha256=="0e5af2a8c1ea6969bfcadbd727e33a4c7f87379aa211b465322f98f026538b02","Packaged provenance identifies the selected normal recording and delivered asset")
 check(not ResourceLoader.exists("res://assets/audio/sunny_city_loop.ogg") and not ResourceLoader.exists("res://assets/audio/snack_garden_loop.ogg"),"Former synthesized tracks are not exported as hidden audio payloads")
 check(not DirAccess.dir_exists_absolute("res://art_source/music/legacy-v0.11.0"),"Archived original score and legacy music remain outside the package")
 var stream:AudioStreamOggVorbis=load("res://assets/audio/shop_theme_loop.ogg")
 check(stream!=null and absf(stream.get_length()-88.0)<.001,"Actual exported Shop Theme resource loads the complete recording")
 var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(var_to_bytes(stream.packet_sequence.get("packet_data")))
 var fingerprint:=hash.finish().hex_encode()
 check(fingerprint=="5d0053ae1d9ee3c8627fe9f6cfecd9f0126fc6c9eaae65ad47b01c7049f71fe0","Actual exported Vorbis packets match the independently decoded source recording")
 print("SHOP_PACKAGE_CONTENT "+JSON.stringify({"checks":checks,"failures":failures,"packet_sha256":fingerprint,"metadata_hashes":expected,"scope":"Isolated actual exported-package resources; no browser, audible output or screenshot."}))
 quit(0 if failures.is_empty() else 1)
