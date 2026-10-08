extends SceneTree
## Source and isolated-PCK resource acceptance, not a pixel/GPU/device claim.
const ATLAS := "res://assets/food_city/streets.png"
const EXPECTED_BASE_RGB_SHA256 := "eb8e2ad7928dc0d98ed4a26d23ca1f3416f32e04f5aae5851281afc9760212ae"
var checks := 0
var failures: Array[String] = []
var metrics: Dictionary = {}

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func bytes_hash(data: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(data)
	return hashing.finish().hex_encode()

func run() -> void:
	var atlas: Texture2D = load(ATLAS)
	check(atlas != null, "Authored food atlas loads as a runtime texture")
	if atlas:
		var image := atlas.get_image()
		check(image != null, "Runtime texture provides its imported image")
		if image:
			if image.is_compressed():
				check(image.decompress() == OK, "Imported image can be inspected")
			check(image.get_width() == 2048 and image.get_height() == 2048, "Original atlas resolution is retained")
			check(image.has_mipmaps(), "Actual imported resource contains mipmaps")
			check(image.get_mipmap_count() == 11, "Full 2048 to 1 pixel mip chain is present")
			# Convert only the inspection copy; the runtime resource is unchanged.
			image.convert(Image.FORMAT_RGB8)
			var data := image.get_data()
			var base_bytes := 2048 * 2048 * 3
			check(bytes_hash(data.slice(0, base_bytes)) == EXPECTED_BASE_RGB_SHA256, "Every base-level atlas pixel matches the reviewed enlarged-city plan")
			check(data.size() == 16777215, "RGB mip storage is bounded to 4/3 of the base image")
			var previous_offset := 0
			for level in range(1, 12):
				var offset := image.get_mipmap_offset(level)
				check(offset > previous_offset and offset < data.size(), "Mip %d has a distinct stored level" % level)
				previous_offset = offset
			metrics = {"width":image.get_width(), "height":image.get_height(), "mip_levels_after_base":image.get_mipmap_count(), "rgb_bytes":data.size(), "base_rgb_sha256":bytes_hash(data.slice(0,base_bytes))}
	var asphalt: Shader = load("res://fidelity/asphalt.gdshader")
	var facade: Shader = load("res://fidelity/facade.gdshader")
	check(asphalt != null and facade != null, "Both authored shaders load from the active resource pack")
	if asphalt and facade:
		check("filter_linear_mipmap" in asphalt.code and "repeat_disable" in asphalt.code, "Atlas shader requests trilinear clamped sampling")
		check("fwidth(p)" in asphalt.code and "fwidth(dash_coord)" in asphalt.code and "fwidth(park_coord)" in asphalt.code, "Ground derivatives use continuous world-space coordinates")
		check("fwidth(grid)" in facade.code, "Facade derivative uses continuous window-grid coordinates")
		for shader in [asphalt, facade]:
			check(not "fwidth(fract" in shader.code and not "fwidth(floor" in shader.code, "No discontinuous periodic coordinate derivative: " + shader.resource_path)
			check(not "discard" in shader.code, "Filtering does not add a geometry or mouth discard: " + shader.resource_path)
		check("ALPHA=visibility" in facade.code, "Existing facade visibility contract is retained")
	print("PROCEDURAL_FILTERING_ACCEPTANCE " + JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics}))
	quit(0 if failures.is_empty() else 1)
