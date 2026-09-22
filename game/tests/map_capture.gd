extends SceneTree
## Generic viewport capture for scenes that ship no capture switch of their own.
##
##   godot --path game --resolution 1280x720 --script res://tests/map_capture.gd -- \
##     --scene=res://scenes/demo_town.tscn --out=C:\abs\dir --seconds=12 --fps=12 --warmup=8
##
## The scene is instantiated unchanged and keeps running on its own: the wrapper
## only reads the viewport, so nothing about the map, the save or the world is
## touched. When the scene provides no camera, a simple overview camera is added
## so the map is still visible.

var scene_path := ""
var out_dir := ""
var seconds := 10.0
var fps := 12.0
var warmup := 6.0
var camera_pos := Vector3.ZERO
var camera_look := Vector3.ZERO
var camera_override := false
var frames := 0
var physics_frames := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			scene_path = arg.trim_prefix("--scene=")
		elif arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--seconds="):
			seconds = float(arg.trim_prefix("--seconds="))
		elif arg.begins_with("--fps="):
			fps = float(arg.trim_prefix("--fps="))
		elif arg.begins_with("--warmup="):
			warmup = float(arg.trim_prefix("--warmup="))
		elif arg.begins_with("--camera-pos="):
			camera_pos = _vec(arg.trim_prefix("--camera-pos="))
			camera_override = true
		elif arg.begins_with("--camera-look="):
			camera_look = _vec(arg.trim_prefix("--camera-look="))
	call_deferred("run")


func _vec(text: String) -> Vector3:
	var parts := text.split(",")
	if parts.size() != 3:
		return Vector3.ZERO
	return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))


func run() -> void:
	if scene_path.is_empty() or out_dir.is_empty():
		print("MAPCAPTURE error missing --scene or --out")
		quit(2)
		return
	var packed := load(scene_path) as PackedScene
	if packed == null:
		print("MAPCAPTURE error cannot load " + scene_path)
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	var instance := packed.instantiate()
	root.add_child(instance)
	# Town-family scenes expect to be the current scene, not an anonymous child.
	current_scene = instance
	var warm_frames := int(warmup * 60.0)
	for index in range(warm_frames):
		await physics_frame
	var camera_note := "scene camera"
	if camera_override:
		# A read-only viewing camera for scenes whose own camera is parked away
		# from what should be recorded (for example the walking residents).
		var viewer := Camera3D.new()
		viewer.name = "MapCaptureViewer"
		viewer.position = camera_pos
		viewer.fov = 62.0
		root.add_child(viewer)
		viewer.look_at(camera_look, Vector3.UP)
		viewer.current = true
		camera_note = "wrapper viewer camera"
	elif root.get_camera_3d() == null:
		var camera := Camera3D.new()
		camera.name = "MapCaptureOverview"
		camera.position = Vector3(0.0, 26.0, 34.0)
		camera.fov = 62.0
		root.add_child(camera)
		camera.look_at(Vector3.ZERO, Vector3.UP)
		camera.current = true
		camera_note = "wrapper overview camera"
	var step := maxf(1.0, 60.0 / fps)
	var accumulator := step
	var limit := int((seconds + 60.0) * 60.0)
	while frames < int(seconds * fps) and physics_frames < limit:
		await physics_frame
		physics_frames += 1
		accumulator += 1.0
		if accumulator < step:
			continue
		accumulator = 0.0
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		if image == null:
			continue
		image.save_png(out_dir + "/frame_%05d.png" % frames)
		frames += 1
	print("MAPCAPTURE done scene=%s frames=%d camera=%s" % [scene_path, frames, camera_note])
	quit(0)
