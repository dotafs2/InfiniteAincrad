extends "res://experiments/model_interface_probe.gd"
## A separately reviewed GM runtime can be admitted for an explicit experiment.
## Normal launches and H85 keep the original runtime.

func _runtime_override():
	if not OS.get_cmdline_user_args().has("--r5-gm-runtime"):
		return null
	var extension = load("res://experiments/r5_gm_runtime.gd")
	if extension == null:
		push_error("Reviewed R5 GM runtime is unavailable")
		quit(4)
		return null
	return extension.new()
