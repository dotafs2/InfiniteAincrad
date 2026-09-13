extends SceneTree
## tools/render_probe.gd — 一次性渲染/一致性探针（真实 Forward+ 渲染，跑完即退）
## 用法:
##   <godot.exe> --path C:/GodotAnimeLab --max-fps 30 --resolution 960x540 --script res://tools/render_probe.gd
## 它会: 打开生成好的场景 -> 截图 -> 在内存/磁盘上改一个共享常量再截图 -> 还原再截图
## -> 写出 _work/validation.json 后退出。不写回场景或材质文件，不驻留。

const SCENE := "res://scenes/material_lab.tscn"
const SURFACE_SHADER := "res://shaders/anime_surface.gdshader"
const POST_SHADER := "res://shaders/anime_post.gdshader"
const STYLE_INC := "res://shaders/anime_style.gdshaderinc"
const SHOT_DIR := "res://_work/captures"
const MAX_FRAMES := 1500
const MUTATIONS := {
    "const float STYLE_THRESHOLD = 0.42;": "const float STYLE_THRESHOLD = 0.78;",
    "const vec3 STYLE_SHADOW_TINT = vec3(0.86, 0.90, 1.00);": "const vec3 STYLE_SHADOW_TINT = vec3(0.62, 0.28, 0.30);",
    "const float STYLE_HIGHLIGHT_GAIN = 1.28;": "const float STYLE_HIGHLIGHT_GAIN = 1.55;",
}

var scene_root: Node
var quad: MeshInstance3D
var surface_materials := []
var sharing := []
var models_seen := {}
var shots := []
var failures := []
var notes := []
var orig_inc_text := ""
var mutated_inc_text := ""
var baseline_samples := PackedFloat32Array()
var queue := []
var waiting := 0
var frames := 0
var scene_instance_id := 0
var live_include_used := false


func _initialize() -> void:
    DirAccess.make_dir_recursive_absolute(SHOT_DIR)
    var t0 := Time.get_ticks_msec()
    var packed := load(SCENE) as PackedScene
    if packed == null:
        failures.append("无法加载场景 " + SCENE)
        _write_report(t0)
        quit(1)
        return
    scene_root = packed.instantiate()
    get_root().add_child(scene_root)
    scene_instance_id = scene_root.get_instance_id()
    quad = scene_root.find_child("PostOutlineQuad", true, false) as MeshInstance3D
    if quad == null:
        notes.append("场景里没有 PostOutlineQuad（后处理关闭）")
    orig_inc_text = FileAccess.get_file_as_string(STYLE_INC)
    mutated_inc_text = orig_inc_text
    for key in MUTATIONS.keys():
        if not mutated_inc_text.contains(key):
            failures.append("共享常量未找到，无法做改动测试: " + key)
        mutated_inc_text = mutated_inc_text.replace(key, MUTATIONS[key])
    _collect_surfaces(scene_root, "")
    _freeze_wind()
    notes.append("为了截图可比，探针把材质的 material_wind 临时设为 0（只在内存中，不写回 .tres）")
    queue = [
        {"do": _act_noop, "wait": 25},
        {"do": _act_capture.bind("01_baseline_post_on"), "wait": 4},
        {"do": _act_post_off, "wait": 4},
        {"do": _act_capture.bind("01b_baseline_post_off"), "wait": 4},
        {"do": _act_post_on, "wait": 4},
        {"do": _act_live_edit, "wait": 6},
        {"do": _act_capture.bind("02_live_include_edit"), "wait": 4},
        {"do": _act_live_restore, "wait": 6},
        {"do": _act_disk_edit, "wait": 10},
        {"do": _act_capture.bind("03_shared_disk_reload_edit"), "wait": 4},
        {"do": _act_disk_restore, "wait": 10},
        {"do": _act_capture.bind("04_restored_default"), "wait": 4},
        {"do": _act_finish, "wait": 0},
    ]


func _process(_delta: float) -> bool:
    frames += 1
    if frames > MAX_FRAMES:
        failures.append("超过最大帧数保护 %d，强制结束" % MAX_FRAMES)
        _act_finish()
        return true
    if waiting > 0:
        waiting -= 1
        return false
    if queue.is_empty():
        return true
    var item: Dictionary = queue.pop_front()
    var fn: Callable = item["do"]
    fn.call()
    waiting = int(item["wait"])
    return false


func _act_noop() -> void:
    pass


func _act_capture(tag: String) -> void:
    var img := get_root().get_texture().get_image()
    if img == null:
        failures.append("截图失败: " + tag)
        return
    var path := "%s/%s.png" % [SHOT_DIR, tag]
    var err := img.save_png(path)
    var buf := img.save_png_to_buffer()
    var samples := _sample(img)
    var rec := {
        "tag": tag,
        "path": path,
        "save_error": err,
        "width": img.get_width(),
        "height": img.get_height(),
        "sha256": _sha256(buf),
        "mean_rgb": _mean(samples),
    }
    if baseline_samples.is_empty():
        baseline_samples = samples
        rec["is_baseline"] = true
    else:
        rec["mean_abs_diff_vs_baseline"] = _mean_abs_diff(samples, baseline_samples)
        rec["changed_sample_ratio"] = _changed_ratio(samples, baseline_samples, 0.02)
    shots.append(rec)
    print("SHOT %s %dx%d sha256=%s diff_vs_baseline=%s" % [tag, img.get_width(), img.get_height(), rec["sha256"].substr(0, 16), str(rec.get("mean_abs_diff_vs_baseline", 0.0))])


func _act_post_off() -> void:
    if quad != null:
        quad.visible = false


func _act_post_on() -> void:
    if quad != null:
        quad.visible = true


func _act_live_edit() -> void:
    var inc := load(STYLE_INC) as ShaderInclude
    if inc == null:
        failures.append("无法加载 ShaderInclude")
        return
    var before := inc.code
    inc.code = mutated_inc_text
    live_include_used = inc.code != before
    notes.append("live edit: 直接改内存里的 ShaderInclude.code（模拟编辑器里改 include 文件）")


func _act_live_restore() -> void:
    var inc := load(STYLE_INC) as ShaderInclude
    if inc != null:
        inc.code = orig_inc_text


func _act_disk_edit() -> void:
    var f := FileAccess.open(STYLE_INC, FileAccess.WRITE)
    if f == null:
        failures.append("无法写入 " + STYLE_INC)
        return
    f.store_string(mutated_inc_text)
    f.close()
    _reload_shader_into_materials()


func _act_disk_restore() -> void:
    var f := FileAccess.open(STYLE_INC, FileAccess.WRITE)
    if f != null:
        f.store_string(orig_inc_text)
        f.close()
    _reload_shader_into_materials()


func _reload_shader_into_materials() -> void:
    # 磁盘上的 include 已经改写；把内容喂回缓存里的 ShaderInclude，shader 依赖会
    # 重编译 —— 这就是编辑器监听文件变化后做的事（不重建场景、不重载场景节点）。
    # 注意：不要用 CACHE_MODE_REPLACE 直接重载 .gdshader，那条路径不跑 include 预处理。
    var text := FileAccess.get_file_as_string(STYLE_INC)
    var inc := load(STYLE_INC) as ShaderInclude
    if inc == null:
        failures.append("无法加载 ShaderInclude")
        return
    inc.code = text


func _act_finish() -> void:
    _write_report(0)
    quit()


func _collect_surfaces(node: Node, model: String) -> void:
    var next_model := model
    if node != scene_root and node.get_parent() == scene_root:
        next_model = String(node.name)
        models_seen[next_model] = true
    if node is MeshInstance3D:
        var mi := node as MeshInstance3D
        var mesh := mi.mesh
        if mesh != null:
            for s in range(mesh.get_surface_count()):
                var mat := mi.get_surface_override_material(s)
                if mat == null:
                    mat = mi.material_override
                if mat == null:
                    mat = mesh.surface_get_material(s)
                var mat_path := ""
                var shader_path := ""
                if mat != null:
                    mat_path = mat.resource_path
                    if mat is ShaderMaterial and mat.shader != null:
                        shader_path = mat.shader.resource_path
                        # 只统计表面材质；后处理四边形用的是另一个 shader，不能混进来。
                        if shader_path == SURFACE_SHADER and not surface_materials.has(mat):
                            surface_materials.append(mat)
                sharing.append({"model": next_model, "mesh": String(mi.name), "surface": s, "material": mat_path, "shader": shader_path})
    for child in node.get_children():
        _collect_surfaces(child, next_model)


func _freeze_wind() -> void:
    for mat in surface_materials:
        if mat.get_shader_parameter("material_wind") != null:
            mat.set_shader_parameter("material_wind", 0.0)


func _sample(img: Image) -> PackedFloat32Array:
    var out := PackedFloat32Array()
    var w := img.get_width()
    var h := img.get_height()
    var y := 0
    while y < h:
        var x := 0
        while x < w:
            var c := img.get_pixel(x, y)
            out.append(c.r)
            out.append(c.g)
            out.append(c.b)
            x += 4
        y += 4
    return out


func _mean(samples: PackedFloat32Array) -> float:
    if samples.is_empty():
        return 0.0
    var total := 0.0
    for v in samples:
        total += v
    return total / float(samples.size())


func _mean_abs_diff(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
    if a.size() != b.size() or a.is_empty():
        return -1.0
    var total := 0.0
    for i in range(a.size()):
        total += absf(a[i] - b[i])
    return total / float(a.size())


func _changed_ratio(a: PackedFloat32Array, b: PackedFloat32Array, threshold: float) -> float:
    if a.size() != b.size() or a.is_empty():
        return -1.0
    var changed := 0
    for i in range(a.size()):
        if absf(a[i] - b[i]) > threshold:
            changed += 1
    return float(changed) / float(a.size())


func _sha256(buf: PackedByteArray) -> String:
    var ctx := HashingContext.new()
    ctx.start(HashingContext.HASH_SHA256)
    ctx.update(buf)
    return ctx.finish().hex_encode()


func _write_report(t0: int) -> void:
    var shader_paths := {}
    var material_paths := {}
    for rec in sharing:
        if rec["shader"] != POST_SHADER:
            shader_paths[rec["shader"]] = true
        material_paths[rec["material"]] = true
    var disk_text := FileAccess.get_file_as_string(STYLE_INC)
    var diff := {}
    for rec in shots:
        diff[rec["tag"]] = rec.get("mean_abs_diff_vs_baseline", -1.0)
    var edit_diff: float = diff.get("03_shared_disk_reload_edit", -1.0)
    var restored_diff: float = diff.get("04_restored_default", -1.0)
    var live_diff: float = diff.get("02_live_include_edit", -1.0)
    var checks := {
        "single_shared_shader_on_all_surfaces": shader_paths.size() == 1 and shader_paths.has(SURFACE_SHADER),
        "distinct_material_resources": material_paths.size(),
        "distinct_models_in_preview": models_seen.size(),
        "surface_count": sharing.size(),
        "shared_const_edit_changed_image": edit_diff > 0.002,
        "live_include_code_edit_changed_image": live_diff > 0.002,
        "restored_matches_baseline_again": restored_diff >= 0.0 and (edit_diff <= 0.0 or restored_diff < edit_diff * 0.25),
        "include_file_on_disk_restored": disk_text == orig_inc_text,
        "scene_object_still_same_instance": scene_instance_id == scene_root.get_instance_id(),
        "real_gpu_rendering": RenderingServer.get_video_adapter_name() != "",
    }
    var report := {
        "probe": "tools/render_probe.gd",
        "finished_at_utc": Time.get_datetime_string_from_system(true),
        "probe_ms": Time.get_ticks_msec() - t0,
        "engine": Engine.get_version_info(),
        "video_adapter": RenderingServer.get_video_adapter_name(),
        "rendering_method": ProjectSettings.get_setting("rendering/renderer/rendering_method"),
        "window_size": [get_root().size.x, get_root().size.y],
        "scene": SCENE,
        "mutations": MUTATIONS,
        "checks": checks,
        "captures": shots,
        "surface_sharing": sharing,
        "failures": failures,
        "notes": notes,
        "limits": [
            "屏幕纹理在“不透明之后、透明之前”采样，因此后处理看不到之后绘制的半透明物，不是最终合成器。",
            "探针只验证“场景存活 + 改一个共享常量 -> 所有材质一起变 + 截图不同”；它不等于在原生编辑器里手动编辑 shader 的交互验证。",
            "为了截图可比，探针把 material_wind 在内存里置 0；场景文件里植被风仍是开启的。",
        ],
    }
    var f := FileAccess.open("res://_work/validation.json", FileAccess.WRITE)
    if f != null:
        f.store_string(JSON.stringify(report, "  "))
        f.close()
    print("PROBE checks=%s failures=%d" % [JSON.stringify(checks), failures.size()])
    for fl in failures:
        print("  FAILURE: " + fl)
