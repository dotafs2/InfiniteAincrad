from pathlib import Path
import hashlib
import importlib.util
import json

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "artifacts/trains-20260929/cpu"
OUT.mkdir(parents=True, exist_ok=True)
spec = importlib.util.spec_from_file_location("release_gate", ROOT / "tools/release_web.py")
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)
gate.REVIEW_SCRIPTS["train_step_profile"] = ("train_step_profile.gd", "TRAIN_STEP_PROFILE")
engine = ROOT / ".build/godot-standard/Godot.app/Contents/MacOS/Godot"
helper = ROOT / "artifacts/trains-20260929/train_step_profile.gd"
digest = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
before = gate.input_hashes()
helper_hashes = {str(p.relative_to(ROOT)): digest(p) for p in [helper, Path(__file__).resolve()]}
result = gate.acceptance(
    [str(engine), "--headless", "--path", str(ROOT), "--script", str(helper),
     "--fixed-fps", "60", "--quit-after", "3200", "--", "--test"],
    OUT / "source.log", OUT / "source.json", "train_step_profile", 16)
after = gate.input_hashes()
provenance = {"before": before, "after": after, "stable": before == after,
              "helpers": helper_hashes, "engine_sha256": digest(engine),
              "raw_report_sha256": digest(OUT / "source.json"),
              "owned_helpers_running": False,
              "scope": "Isolated native Mac headless elapsed time around controller.step; no browser, rendering, whole-frame or iPhone FPS claim."}
(OUT / "provenance.json").write_text(json.dumps(provenance, indent=2) + "\n")
if before != after:
    raise RuntimeError("Source changed during train CPU sample")
for run in result["runs"]:
    assert len(run["times_ms"]) == run["samples"] == 600
summary = {"checks": result["checks"], "failures": result["failures"],
           "runs": [{k: v for k, v in run.items() if k != "times_ms"} for run in result["runs"]],
           "scope": result["scope"], "stable_source": before == after}
(OUT / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
print(json.dumps(summary, indent=2))
