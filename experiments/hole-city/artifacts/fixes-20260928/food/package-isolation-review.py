"""Independent bounded PCK resource-isolation probe; no scene instantiation."""
import hashlib
import importlib.util
import json
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
PACK = ROOT / "build/package-isolation-review/index.pck"
GODOT = ROOT / ".build/godot-standard/Godot.app/Contents/MacOS/Godot"
spec = importlib.util.spec_from_file_location("release_isolation_review", ROOT / "tools/release_web.py")
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)
gate_hash = gate.digest(ROOT / "tools/release_web.py")
pack_hash = gate.digest(PACK)
script_text = '''extends SceneTree
func _initialize() -> void:
    var sentinel := ""
    var isolated := false
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--sentinel="):
            sentinel = arg.trim_prefix("--sentinel=")
        if arg == "--isolated":
            isolated = true
    var tool_visible := FileAccess.file_exists("res://tools/release_web.py")
    var sentinel_visible := FileAccess.file_exists("res://" + sentinel)
    var scene_visible := ResourceLoader.exists("res://fidelity/main.tscn", "PackedScene")
    var failures: Array[String] = []
    if tool_visible == isolated:
        failures.append("Excluded release tool visibility differs from expected working-directory behavior")
    if sentinel_visible == isolated:
        failures.append("Source-only sentinel visibility differs from expected working-directory behavior")
    if not scene_visible:
        failures.append("Packaged main scene is missing")
    print("SCENE_QA_ACCEPTANCE " + JSON.stringify({"checks": 3, "failures": failures,
        "isolated": isolated, "excluded_tool_visible": tool_visible,
        "source_only_sentinel_visible": sentinel_visible,
        "packaged_main_scene_visible": scene_visible,
        "globalized_res": ProjectSettings.globalize_path("res://")}))
    quit(0 if failures.is_empty() else 1)
'''

with tempfile.TemporaryDirectory(prefix="hole-package-isolation-") as scratch:
    script = Path(scratch) / "probe.gd"
    script.write_text(script_text)
    # Created after export: this cannot exist in the package under review.
    with tempfile.NamedTemporaryFile(mode="w", prefix=".package-isolation-sentinel-", suffix=".txt", dir=ROOT) as sentinel:
        sentinel.write("Independent source-only package isolation sentinel\n")
        sentinel.flush()
        command = [str(GODOT), "--headless", "--main-pack", str(PACK), "--script", str(script),
                   "--quit-after", "30", "--", "--test", "--sentinel=" + Path(sentinel.name).name]
        control = gate.acceptance(command, OUT / "package-isolation-root-control.log",
                                 OUT / "package-isolation-root-control.json", "scene_qa", 3, cwd=ROOT)
        isolated = gate.acceptance(command + ["--isolated"], OUT / "package-isolation-candidate.log",
                                  OUT / "package-isolation-candidate.json", "scene_qa", 3, cwd=PACK.parent)

checks = [
    {"label": "root-cwd-reproduces-source-tool-fallback", "passed": control["excluded_tool_visible"]},
    {"label": "root-cwd-reproduces-new-sentinel-fallback", "passed": control["source_only_sentinel_visible"]},
    {"label": "candidate-cwd-excludes-source-tool", "passed": not isolated["excluded_tool_visible"]},
    {"label": "candidate-cwd-excludes-new-source-sentinel", "passed": not isolated["source_only_sentinel_visible"]},
    {"label": "candidate-cwd-keeps-packaged-main-scene", "passed": isolated["packaged_main_scene_visible"]},
    {"label": "reviewed-pack-unchanged", "passed": gate.digest(PACK) == pack_hash},
    {"label": "reviewed-gate-unchanged", "passed": gate.digest(ROOT / "tools/release_web.py") == gate_hash},
]
result = {"checks": checks, "count": len(checks), "passed": all(c["passed"] for c in checks),
          "gate_sha256": gate_hash, "pack_sha256": pack_hash, "pack": str(PACK),
          "control": control, "isolated": isolated,
          "scope": "Real headless packaged-resource existence checks through actual gate.acceptance/run cwd propagation; no scene instantiation, preview publication, save writes, or CPU timing"}
(OUT / "package-isolation-review.json").write_text(json.dumps(result, indent=2) + "\n")
print("PACKAGE_ISOLATION_REVIEW " + json.dumps(result))
sys.exit(0 if result["passed"] else 1)
