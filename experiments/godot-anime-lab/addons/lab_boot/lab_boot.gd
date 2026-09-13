@tool
extends EditorPlugin
## One-shot bootstrap for the material lab.
##
## On a graphical editor start (never headless) this waits for the editor's main
## scene, opens res://scenes/material_lab.tscn if it is not already the edited
## scene, switches to the 3D screen, selects PreviewCamera, and opens the shared
## style include in the built-in shader editor. It then saves a single capture of
## the editor 3D viewport as proof.
##
## It writes no resource to disk except that one PNG. It runs once per editor
## session (guarded by an Engine meta flag), so it does not fight the user's own
## edits on later reloads.

const SCENE_PATH := "res://scenes/material_lab.tscn"
const SHADER_PATH := "res://shaders/anime_style.gdshaderinc"
const CAPTURE_PATH := "res://_work/captures/editor_view.png"
const SESSION_FLAG := "lab_boot_done"
const MAX_WAIT_FRAMES := 300
const SETTLE_FRAMES := 75

func _enter_tree() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if Engine.has_meta(SESSION_FLAG):
		return
	Engine.set_meta(SESSION_FLAG, true)
	_boot.call_deferred()

func _boot() -> void:
	await _await_scene()
	if EditorInterface.get_edited_scene_root() == null:
		EditorInterface.open_scene_from_path(SCENE_PATH)
		await _await_scene()
	EditorInterface.set_main_screen_editor("3D")
	_select_preview_camera()
	_open_style_include()
	await _settle(SETTLE_FRAMES)
	_capture_viewport()

func _await_scene() -> void:
	var frames := 0
	while EditorInterface.get_edited_scene_root() == null and frames < MAX_WAIT_FRAMES:
		await get_tree().process_frame
		frames += 1

func _settle(frames: int) -> void:
	for _i in frames:
		await get_tree().process_frame

func _select_preview_camera() -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		print("[lab_boot] no edited scene root; camera selection skipped")
		return
	var camera := root.get_node_or_null("PreviewCamera")
	if camera == null:
		print("[lab_boot] PreviewCamera not found; camera selection skipped")
		return
	var selection := EditorInterface.get_selection()
	selection.clear()
	selection.add_node(camera)
	print("[lab_boot] PreviewCamera selected - press F in the 3D view to frame all nine models")

func _open_style_include() -> void:
	var include: Resource = load(SHADER_PATH)
	if include == null:
		print("[lab_boot] failed to load %s" % SHADER_PATH)
		return
	EditorInterface.edit_resource(include)
	print("[lab_boot] shader editor opened on %s" % SHADER_PATH)

func _capture_viewport() -> void:
	var viewport := EditorInterface.get_editor_viewport_3d(0)
	if viewport == null:
		print("[lab_boot] 3D viewport unavailable; capture skipped")
		return
	var image := viewport.get_texture().get_image()
	if image == null:
		print("[lab_boot] 3D viewport texture not ready; capture skipped")
		return
	var absolute := ProjectSettings.globalize_path(CAPTURE_PATH)
	var error := image.save_png(absolute)
	print("[lab_boot] editor 3D viewport capture written to %s (error=%d)" % [absolute, error])
