extends SceneTree
## tools/build_lab.gd — 一次性构建脚本（只在需要重建时运行，不是运行时脚本）
## 用法:
##   <godot.exe> --headless --path C:/GodotAnimeLab --script res://tools/build_lab.gd
## 作用: 从已复制的 GLB 生成 scenes/material_lab.tscn 与 materials/*.tres。
## 只读取 res://assets 下的副本；不改动 shader 源码，也不接触任何外部工程。

const OUT_SCENE := "res://scenes/material_lab.tscn"
const MAT_DIR := "res://materials"
const SURFACE_SHADER_PATH := "res://shaders/anime_surface.gdshader"
const POST_SHADER_PATH := "res://shaders/anime_post.gdshader"
const RES_TEX := "res://assets/residences/textures/"
const RES_KINDS := ["limestone", "plaster", "oak", "clay"]

var models := [
    {"node": "AncientOak", "glb": "res://assets/v2_trees/F1_ancient_oak_LOD1.glb", "lod": "1", "pos": Vector3(-15, 0, -3), "yaw": 18.0},
    {"node": "StonePine", "glb": "res://assets/v2_trees/F1_stone_pine_LOD1.glb", "lod": "1", "pos": Vector3(0, 0, -14), "yaw": -12.0},
    {"node": "YoungMaple", "glb": "res://assets/v2_trees/F1_young_maple_LOD1.glb", "lod": "1", "pos": Vector3(15, 0, 1), "yaw": 40.0},
    {"node": "Residence01_LindenCourt", "glb": "res://assets/residences/F1_Residence_01.glb", "lod": "1", "pos": Vector3(-8.5, 0, -2), "yaw": 0.0},
    {"node": "Residence03_RoseCourtyard", "glb": "res://assets/residences/F1_Residence_03.glb", "lod": "1", "pos": Vector3(8.5, 0, -2), "yaw": 0.0},
    {"node": "Milestone", "glb": "res://assets/props/F1_roadside_milestone_LOD1.glb", "lod": "1", "pos": Vector3(1.5, 0, 6.5), "yaw": 0.0},
    {"node": "BoulderCluster", "glb": "res://assets/props/F1_mossy_boulder_cluster_LOD1.glb", "lod": "1", "pos": Vector3(-5, 0, 6), "yaw": 25.0},
    {"node": "HerbPlanter", "glb": "res://assets/props/F1_herb_planter_LOD1.glb", "lod": "1", "pos": Vector3(-2.4, 0, 6.4), "yaw": -8.0},
    {"node": "MeadowGrass", "glb": "res://assets/props/F1_meadow_grass_LOD1.glb", "lod": "1", "pos": Vector3(4.6, 0, 6), "yaw": 0.0},
]

var surface_shader: Shader
var materials := {}
var placed := []
var mat_records := []


func _initialize() -> void:
    var t0 := Time.get_ticks_msec()
    DirAccess.make_dir_recursive_absolute("res://scenes")
    DirAccess.make_dir_recursive_absolute(MAT_DIR)
    DirAccess.make_dir_recursive_absolute("res://meshes")
    DirAccess.make_dir_recursive_absolute("res://_work")
    surface_shader = load(SURFACE_SHADER_PATH)
    if surface_shader == null:
        push_error("缺少 surface shader: " + SURFACE_SHADER_PATH)
        quit(1)
        return

    var root := Node3D.new()
    root.name = "MaterialLab"
    root.add_child(_make_environment())
    root.add_child(_make_light())
    _make_camera(root)
    _make_ground_sphere(root)
    for spec in models:
        var node := _build_model(spec)
        if node != null:
            root.add_child(node)
    for key in materials.keys():
        var path := "%s/%s.tres" % [MAT_DIR, _slug(key)]
        var err := ResourceSaver.save(materials[key], path)
        if err == OK:
            # ResourceSaver 不会自动把路径写到资源上；不设的话 pack() 会把材质
            # 内嵌进 tscn，而不是引用 materials/*.tres。
            materials[key].take_over_path(path)
        mat_records.append({"key": key, "path": path, "save_error": err, "params": _params_of(materials[key])})

    # 运行时 new 出来的节点默认没有 owner，pack() 会把它们全部丢掉；必须显式指定。
    _assign_owners(root, root)
    var packed := PackedScene.new()
    var perr := packed.pack(root)
    var serr := ResourceSaver.save(packed, OUT_SCENE)
    var report := {
        "built_at_utc": Time.get_datetime_string_from_system(true),
        "build_ms": Time.get_ticks_msec() - t0,
        "scene": OUT_SCENE,
        "scene_save_error": serr,
        "pack_error": perr,
        "models": placed,
        "materials": mat_records,
        "surface_shader": SURFACE_SHADER_PATH,
    }
    var f := FileAccess.open("res://_work/build_report.json", FileAccess.WRITE)
    f.store_string(JSON.stringify(report, "  "))
    f.close()
    print("BUILD scene=%s pack_err=%d save_err=%d models=%d materials=%d build_ms=%d" % [OUT_SCENE, perr, serr, placed.size(), mat_records.size(), report["build_ms"]])
    for m in mat_records:
        print("  material %s -> %s" % [m["key"], m["path"]])
    root.free()
    quit()


func _make_environment() -> WorldEnvironment:
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.60, 0.68, 0.76)
    env.background_energy_multiplier = 1.0
    env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
    env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
    env.ssao_enabled = false
    env.ssr_enabled = false
    env.glow_enabled = false
    env.fog_enabled = false
    env.volumetric_fog_enabled = false
    env.sdfgi_enabled = false
    var we := WorldEnvironment.new()
    we.name = "WorldEnvironment"
    we.environment = env
    return we


func _make_light() -> DirectionalLight3D:
    var light := DirectionalLight3D.new()
    light.name = "KeyLight"
    light.rotation_degrees = Vector3(-42.0, -35.0, 0.0)
    light.light_color = Color(1.0, 0.97, 0.92)
    light.light_energy = 0.95
    light.shadow_enabled = true
    light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
    light.directional_shadow_max_distance = 90.0
    return light


func _make_camera(root: Node3D) -> void:
    var cam := Camera3D.new()
    cam.name = "PreviewCamera"
    cam.fov = 46.0
    cam.near = 0.1
    cam.far = 400.0
    root.add_child(cam)
    cam.look_at_from_position(Vector3(0, 7.5, 34), Vector3(0, 3.2, -3.0), Vector3.UP)

    var post := ShaderMaterial.new()
    post.resource_name = "anime_post"
    post.shader = load(POST_SHADER_PATH)
    post.render_priority = -8
    var quad := MeshInstance3D.new()
    quad.name = "PostOutlineQuad"
    var qm := QuadMesh.new()
    qm.size = Vector2(2, 2)
    quad.mesh = qm
    quad.material_override = post
    quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    quad.extra_cull_margin = 16384.0
    quad.visible = true
    quad.set_meta("note", "可选后处理：在检查器里取消 Visible 就关闭描边/饱和度")
    cam.add_child(quad)
    ResourceSaver.save(post, MAT_DIR + "/anime_post.tres")


func _make_ground_sphere(root: Node3D) -> void:
    var ground_mat := _new_material("lab_ground")
    ground_mat.set_shader_parameter("material_tint", Color(0.40, 0.45, 0.34))
    ground_mat.set_shader_parameter("material_use_vertex_color", 0.0)
    var ground := MeshInstance3D.new()
    ground.name = "Ground"
    var pm := PlaneMesh.new()
    pm.size = Vector2(140, 140)
    ground.mesh = pm
    ground.material_override = ground_mat
    root.add_child(ground)

    var sphere_mat := _new_material("lab_sphere")
    sphere_mat.set_shader_parameter("material_tint", Color(0.88, 0.86, 0.82))
    sphere_mat.set_shader_parameter("material_use_vertex_color", 0.0)
    var sphere := MeshInstance3D.new()
    sphere.name = "TestSphere"
    var sm := SphereMesh.new()
    sm.radius = 0.9
    sm.height = 1.8
    sm.radial_segments = 48
    sm.rings = 24
    sphere.mesh = sm
    sphere.material_override = sphere_mat
    sphere.position = Vector3(0, 0.9, 3.0)
    root.add_child(sphere)


func _new_material(key: String) -> ShaderMaterial:
    var mat := ShaderMaterial.new()
    mat.shader = surface_shader
    mat.resource_name = key
    materials[key] = mat
    return mat


func _build_model(spec: Dictionary) -> Node3D:
    var packed := load(spec["glb"]) as PackedScene
    if packed == null:
        push_error("无法加载 " + str(spec["glb"]))
        return null
    var inst := packed.instantiate() as Node3D
    if inst == null:
        push_error("不是 Node3D 场景: " + str(spec["glb"]))
        return null
    # 不用 GLB 场景实例：实例里的 LOD0/LOD2 节点无法真正删除（重新加载会回来），
    # 会把三个 LOD 一起画出来。这里只抽出目标 LOD 的网格，存成独立 .res，
    # 生成纯静态的 MeshInstance3D 节点。
    var model := Node3D.new()
    model.name = spec["node"]
    var dropped := []
    var surfaces := []
    for mi in _mesh_instances(inst):
        var node_name := String(mi.name)
        if not _is_target_lod(node_name, spec["lod"]):
            dropped.append(node_name)
            continue
        var mesh_copy := (mi.mesh as Mesh).duplicate(true) as Mesh
        var overrides := []
        for s in range(mesh_copy.get_surface_count()):
            var has_color: bool = (mesh_copy.surface_get_format(s) & Mesh.ARRAY_FORMAT_COLOR) != 0
            var src := mesh_copy.surface_get_material(s) as StandardMaterial3D
            var key := _material_key(src, s, String(model.name))
            var mat := _material_for(key, src, has_color)
            # 去掉网格自带的原材质：它带着源工程里的贴图路径引用，留着会产生
            # 外部 res:// 依赖。表面外观改由我们的 ShaderMaterial 覆盖。
            mesh_copy.surface_set_material(s, null)
            overrides.append(mat)
            surfaces.append({"mesh": node_name, "surface": s, "material": key, "vertex_color": has_color, "textured": src != null and src.albedo_texture != null})
        var mesh_path := "res://meshes/%s.res" % _slug(node_name)
        var merr := ResourceSaver.save(mesh_copy, mesh_path)
        if merr != OK:
            push_error("保存网格失败 %s -> %d" % [mesh_path, merr])
        var node := MeshInstance3D.new()
        node.name = node_name
        node.mesh = ResourceLoader.load(mesh_path) as Mesh
        node.transform = _relative_transform(inst, mi)
        node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
        for s in range(overrides.size()):
            node.set_surface_override_material(s, overrides[s])
        model.add_child(node)
        surfaces[surfaces.size() - 1]["mesh_res"] = mesh_path
    model.position = spec["pos"]
    model.rotation_degrees = Vector3(0, spec["yaw"], 0)
    placed.append({"node": String(model.name), "glb": spec["glb"], "kept_lod": spec["lod"], "dropped_lod_nodes": dropped, "position": str(spec["pos"]), "surface_count": surfaces.size(), "surfaces": surfaces})
    inst.free()
    return model


func _material_key(src: StandardMaterial3D, surface: int, node_name: String) -> String:
    if src != null and src.resource_name != "":
        return src.resource_name
    return "%s_surface%d" % [node_name, surface]


func _material_for(key: String, src: StandardMaterial3D, has_color: bool) -> ShaderMaterial:
    if materials.has(key):
        return materials[key]
    var mat := _new_material(key)
    var lower := key.to_lower()
    var is_residence := lower.begins_with("residence_")
    var is_foliage := lower.contains("foliage") or lower.contains("leaf") or lower.contains("grass") or lower.contains("plant") or lower.contains("fern")
    var is_water := lower.contains("water")
    mat.set_shader_parameter("material_use_vertex_color", 1.0 if has_color else 0.0)
    mat.set_shader_parameter("material_wind", 0.0)
    mat.set_shader_parameter("material_two_sided_normal", 0.0)
    mat.set_shader_parameter("material_alpha_scissor", 0.0)
    mat.set_shader_parameter("material_normal_strength", 0.0)
    mat.set_shader_parameter("material_texture_strength", 1.0)
    if is_residence:
        var kind := lower.substr("residence_".length())
        if RES_KINDS.has(kind) and ResourceLoader.exists(RES_TEX + kind + "_albedo.png"):
            mat.set_shader_parameter("material_albedo", load(RES_TEX + kind + "_albedo.png"))
            mat.set_shader_parameter("material_use_texture", 1.0)
        elif src != null and src.albedo_texture != null:
            mat.set_shader_parameter("material_albedo", src.albedo_texture)
            mat.set_shader_parameter("material_use_texture", 1.0)
        else:
            mat.set_shader_parameter("material_use_texture", 0.0)
        mat.set_shader_parameter("material_roughness", 0.85)
        mat.set_shader_parameter("material_specular", 0.3)
    else:
        var textured := src != null and src.albedo_texture != null
        mat.set_shader_parameter("material_use_texture", 1.0 if textured else 0.0)
        if textured:
            mat.set_shader_parameter("material_albedo", src.albedo_texture)
        if is_foliage:
            mat.set_shader_parameter("material_wind", 1.0)
            mat.set_shader_parameter("material_two_sided_normal", 1.0)
            mat.set_shader_parameter("material_alpha_scissor", 1.0 if textured else 0.0)
            mat.set_shader_parameter("material_roughness", 0.9)
            mat.set_shader_parameter("material_specular", 0.2)
        elif is_water:
            mat.set_shader_parameter("material_roughness", 0.25)
            mat.set_shader_parameter("material_specular", 0.5)
        else:
            mat.set_shader_parameter("material_roughness", 0.8)
            mat.set_shader_parameter("material_specular", 0.25)
    return mat


func _is_target_lod(node_name: String, keep: String) -> bool:
    var idx := node_name.rfind("LOD")
    if idx < 0 or idx + 3 >= node_name.length():
        return true
    return node_name.substr(idx + 3, 1) == keep


func _relative_transform(root_node: Node3D, node: Node3D) -> Transform3D:
    var t := Transform3D()
    var cur: Node = node
    while cur != null and cur != root_node:
        if cur is Node3D:
            t = (cur as Node3D).transform * t
        cur = cur.get_parent()
    if cur == null:
        return node.transform
    return t


func _mesh_instances(node: Node) -> Array:
    var out := []
    if node is MeshInstance3D:
        out.append(node)
    for child in node.get_children():
        out.append_array(_mesh_instances(child))
    return out


func _slug(key: String) -> String:
    var out := ""
    for i in range(key.length()):
        var c := key[i]
        if (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or (c >= "0" and c <= "9"):
            out += c.to_lower()
        else:
            out += "_"
    return out


func _assign_owners(node: Node, root: Node) -> void:
    for child in node.get_children():
        child.owner = root
        _assign_owners(child, root)


func _unused_slug(key: String) -> String:
    var out := ""
    for i in range(key.length()):
        var c := key[i]
        if (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or (c >= "0" and c <= "9"):
            out += c.to_lower()
        else:
            out += "_"
    return out


func _params_of(mat: ShaderMaterial) -> Dictionary:
    var out := {}
    if mat.shader == null:
        return out
    for uniform in mat.shader.get_shader_uniform_list():
        var name: String = uniform["name"]
        var v = mat.get_shader_parameter(name)
        if v is Texture2D:
            out[name] = str(v.resource_path)
        elif v is Color:
            out[name] = [v.r, v.g, v.b, v.a]
        elif v is Vector4:
            out[name] = [v.x, v.y, v.z, v.w]
        else:
            out[name] = str(v)
    return out
