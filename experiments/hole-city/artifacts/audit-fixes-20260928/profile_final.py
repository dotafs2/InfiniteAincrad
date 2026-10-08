"""Freeze complete inputs and record final isolated CPU evidence provenance."""
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import verify_delivery as verify

ROOT = verify.ROOT
OUT = ROOT / "artifacts/audit-fixes-20260928/cpu-final"
GODOT = ROOT / ".build/godot-standard/Godot.app/Contents/MacOS/Godot"


def main():
    spec = importlib.util.spec_from_file_location("gate", ROOT / "tools/release_web.py")
    gate = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(gate)
    before = verify.profile_inputs(gate)
    godot_sha = verify.sha(GODOT)
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "provenance-before.json").write_text(json.dumps(before, indent=2) + "\n")
    subprocess.run([sys.executable, str(ROOT / "tools/profile_maps.py"), "--godot", str(GODOT),
                    "--output", str(OUT), "--repeats", "3"], check=True, cwd=ROOT)
    command = [str(GODOT), "--headless", "--path", str(ROOT), "--fixed-fps", "60",
               "--script", str(ROOT / "tests/mobile_profile.gd"), "--", "--test", "--map=food",
               "--scenario=rain_soak", "--report=" + str(OUT / "food-rain-soak.json")]
    gate.run(command, OUT / "food-rain-soak.log")
    after = verify.profile_inputs(gate)
    assert before == after and godot_sha == verify.sha(GODOT), "Profile inputs changed"
    paths = [p for p in OUT.iterdir() if p.is_file() and p.suffix in [".json", ".log"] and not p.name.startswith("provenance")]
    record = {"before": before, "after": after, "godot_path": str(GODOT), "godot_sha256": godot_sha,
              "raw_sha256": {p.name: verify.sha(p) for p in paths}}
    (OUT / "provenance.json").write_text(json.dumps(record, indent=2) + "\n")
    print("Final CPU trace complete; all %d input hashes remain unchanged." % len(before), flush=True)


if __name__ == "__main__":
    main()
