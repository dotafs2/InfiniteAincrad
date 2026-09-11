extends Node3D
## Lightweight category-driven wind for ground-centred environment components.
## This first pass moves the visual root only; collision remains authoritative and static.

const PROFILES := {
	"tree_gentle": {"amplitude_deg": 0.34, "speed_hz": 0.34, "gust": 0.22},
	"shrub_soft": {"amplitude_deg": 0.82, "speed_hz": 0.58, "gust": 0.30},
	"ground_breeze": {"amplitude_deg": 1.85, "speed_hz": 0.82, "gust": 0.42},
	"climber_subtle": {"amplitude_deg": 0.22, "speed_hz": 0.46, "gust": 0.18},
	"reed_sway": {"amplitude_deg": 1.45, "speed_hz": 0.66, "gust": 0.36},
	"static": {"amplitude_deg": 0.0, "speed_hz": 0.0, "gust": 0.0},
	"static_container": {"amplitude_deg": 0.0, "speed_hz": 0.0, "gust": 0.0},
}

var _profile_id := "static"
var _phase := 0.0
var _strength := 1.0
var _elapsed := 0.0
var _base_rotation := Vector3.ZERO


func configure(profile_id: String, phase_seed: float = 0.0, strength: float = 1.0) -> void:
	_profile_id = profile_id if PROFILES.has(profile_id) else "static"
	_phase = fmod(absf(phase_seed) * 1.61803398875, TAU)
	_strength = clampf(strength, 0.0, 2.0)
	set_meta("wind_profile", _profile_id)
	set_meta("wind_strength", _strength)


func _ready() -> void:
	_base_rotation = rotation
	add_to_group("floor1_plant_wind")
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	_elapsed += delta
	var offset := rotation_offset_at(_elapsed)
	rotation = _base_rotation + offset


func rotation_offset_at(seconds: float) -> Vector3:
	var profile: Dictionary = PROFILES[_profile_id]
	var amplitude := deg_to_rad(float(profile.amplitude_deg) * _strength)
	if amplitude <= 0.0:
		return Vector3.ZERO
	var omega := TAU * float(profile.speed_hz)
	var primary := sin(seconds * omega + _phase)
	var gust := sin(seconds * omega * 0.37 + _phase * 1.91) * float(profile.gust)
	return Vector3(amplitude * (primary + gust) * 0.58, 0.0, amplitude * (primary - gust * 0.45))


func profile_snapshot() -> Dictionary:
	var result: Dictionary = PROFILES[_profile_id].duplicate(true)
	result["id"] = _profile_id
	result["strength"] = _strength
	return result
