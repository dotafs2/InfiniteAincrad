extends RefCounted
## Cosmetic copy-on-variant resources. Base geometry/materials remain immutable.
## Live particle colors are owned by their controller; only model meshes are remapped.
const GENERATED_SHADER_PATHS=["accretion.gdshader","tide.gdshader","aurora.gdshader","cinder_flame.gdshader"]
static var mesh_cache:Dictionary={}
static var shader_cache:Dictionary={}

static func mapped(color:Color,definition:Dictionary)->Color:
	if int(definition.get("variant_index",0))==0:return color
	var palette:Dictionary=definition.get("palette",{})
	var primary:=Color(str(palette.get("primary",definition.tint)))
	var secondary:=Color(str(palette.get("secondary",definition.accent)))
	var source_a:=Color(str(palette.get("base_primary",definition.tint)))
	var source_b:=Color(str(palette.get("base_secondary",definition.accent)))
	# Build-time tint/accent may already be the desired variant. Never remap twice.
	if color.is_equal_approx(primary) or color.is_equal_approx(secondary):return color
	if color.is_equal_approx(source_a):return Color(primary,color.a)
	if color.is_equal_approx(source_b):return Color(secondary,color.a)
	# Preserve the black opening, dark seams and neutral paper/icing highlights.
	if color.v<.16 or color.s<.09:return color
	var distance_a:=Vector3(color.r-source_a.r,color.g-source_a.g,color.b-source_a.b).length_squared()
	var distance_b:=Vector3(color.r-source_b.r,color.g-source_b.g,color.b-source_b.b).length_squared()
	var target:Color=primary if distance_a<=distance_b else secondary
	var source:Color=source_a if distance_a<=distance_b else source_b
	var value:=clampf(target.v*(color.v/maxf(source.v,.15)),.08,1.0)
	return Color.from_hsv(target.h,clampf(target.s*(color.s/maxf(source.s,.15)),.05,.92),value,color.a)

static func fragment_end(code:String)->int:
	# Scan the one known shader processor, ignoring braces inside both comment forms.
	var start:=code.find("void fragment")
	if start<0:return -1
	var brace:=code.find("{",start)
	if brace<0:return -1
	var depth:=0;var line_comment:=false;var block_comment:=false
	var i:=brace
	while i<code.length():
		var ch:=code.substr(i,1);var pair:=code.substr(i,2)
		if line_comment:
			if ch=="\n":line_comment=false
		elif block_comment:
			if pair=="*/":block_comment=false;i+=1
		elif pair=="//":line_comment=true;i+=1
		elif pair=="/*":block_comment=true;i+=1
		elif ch=="{":depth+=1
		elif ch=="}":
			depth-=1
			if depth==0:return i
		i+=1
	return -1

static func palette_shader(source:Shader)->Shader:
	var key:=source.get_instance_id()
	if shader_cache.has(key):return shader_cache[key]
	var code:=source.code
	var end:=fragment_end(code)
	if end<0:
		push_error("Skin palette cannot locate a complete fragment processor: "+source.resource_path)
		return source
	var processor:=code.find("void fragment")
	var helper:="""
uniform vec4 hf_variant_primary : source_color = vec4(1.0);
uniform vec4 hf_variant_secondary : source_color = vec4(1.0);
vec3 hf_variant_color(vec3 color) {
    float luminance = dot(color, vec3(0.2126, 0.7152, 0.0722));
    float span = max(max(color.r, color.g), color.b) - min(min(color.r, color.g), color.b);
    vec3 palette = mix(hf_variant_primary.rgb, hf_variant_secondary.rgb, smoothstep(0.25, 0.85, luminance));
    vec3 tinted = palette * (0.30 + luminance * 1.05);
    return mix(color, tinted, clamp(span * 2.0 + 0.25, 0.0, 0.94));
}
"""
	var finish:="\n    ALBEDO = hf_variant_color(ALBEDO);\n"
	# Preserve the original emission energy; only shaders that write it are transformed.
	if code.contains("EMISSION"):finish+="    EMISSION = hf_variant_color(EMISSION);\n"
	var shader:=Shader.new()
	shader.code=code.substr(0,processor)+helper+code.substr(processor,end-processor)+finish+code.substr(end)
	shader.set_meta("palette_source",source.resource_path)
	shader_cache[key]=shader
	return shader

static func variant_material(source:Material,definition:Dictionary,replacements:Dictionary)->Material:
	if source==null:return null
	var key:=source.get_instance_id()
	if replacements.has(key):return replacements[key]
	var result:Material=source.duplicate()
	replacements[key]=result
	if result is StandardMaterial3D:
		result.albedo_color=mapped(source.albedo_color,definition)
		result.emission=mapped(source.emission,definition)
	elif result is ShaderMaterial:
		for uniform:Dictionary in source.shader.get_shader_uniform_list():
			var value=source.get_shader_parameter(str(uniform.name))
			if value is Color:result.set_shader_parameter(str(uniform.name),mapped(value,definition))
		var generated:bool=source.shader.resource_path.get_file() in GENERATED_SHADER_PATHS
		if source.shader.resource_path.get_file()=="solid_skin.gdshader":generated=source.get_shader_parameter("style")==7
		if generated:
			result.shader=palette_shader(source.shader)
			result.set_shader_parameter("hf_variant_primary",Color(str(definition.tint)))
			result.set_shader_parameter("hf_variant_secondary",Color(str(definition.accent)))
	return result

static func variant_mesh(source:Mesh,definition:Dictionary,replacements:Dictionary)->Mesh:
	var key:=str(source.get_instance_id())+":"+str(definition.id)
	if mesh_cache.has(key):return mesh_cache[key]
	var result:Mesh
	if source is ArrayMesh:
		var array_mesh:=ArrayMesh.new()
		for surface in source.get_surface_count():
			var arrays:=source.surface_get_arrays(surface)
			var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR]!=null else PackedColorArray()
			for i in colors.size():colors[i]=mapped(colors[i],definition)
			if not colors.is_empty():arrays[Mesh.ARRAY_COLOR]=colors
			array_mesh.add_surface_from_arrays(source.surface_get_primitive_type(surface),arrays)
			array_mesh.surface_set_material(surface,variant_material(source.surface_get_material(surface),definition,replacements))
		result=array_mesh
	else:
		result=source.duplicate()
		for surface in result.get_surface_count():result.surface_set_material(surface,variant_material(source.surface_get_material(surface),definition,replacements))
	result.set_meta("palette_skin_id",definition.id)
	mesh_cache[key]=result
	return result

static func apply(visual:Node3D,definition:Dictionary)->void:
	if int(definition.get("variant_index",0))==0:return
	var family:=str(definition.get("model_id",definition.id))
	# These modules author their model shader/particle palettes explicitly at build.
	if family in ["tempest","rainfall","plain_loop","button_wheel","pocket_arcade","sakura_pavilion","clockwork_orbit","phoenix_nest","crystal_crown","aurora_rift"]:return
	var replacements:Dictionary={}
	var pending:Array[Node]=[visual]
	while not pending.is_empty():
		var node:Node=pending.pop_back()
		pending.append_array(node.get_children())
		if not node is MeshInstance3D or node==visual.mouth or node==visual.wave:continue
		if node.mesh==null:continue
		if node.material_override!=null:node.material_override=variant_material(node.material_override,definition,replacements)
		else:node.mesh=variant_mesh(node.mesh,definition,replacements)
		for surface in node.mesh.get_surface_count():
			var override:Material=node.get_surface_override_material(surface)
			if override!=null:node.set_surface_override_material(surface,variant_material(override,definition,replacements))
	# SkinVisual owns these time-updated materials; keep its references on the clones.
	for i in visual.materials.size():
		var old:Material=visual.materials[i]
		if replacements.has(old.get_instance_id()):visual.materials[i]=replacements[old.get_instance_id()]
	visual.set_meta("palette_applied",str(definition.id))
