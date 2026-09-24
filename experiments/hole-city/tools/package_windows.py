"""Build a portable Windows game entirely headless. Does not launch its GUI."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import zipfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, type=Path)
    parser.add_argument("--templates", required=True, type=Path, help="Matching Godot export templates .tpz")
    parser.add_argument("--out", type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    destination = (args.out or root / "build/reference-windows").resolve()
    destination.mkdir(parents=True, exist_ok=True)
    cache = root / ".build"
    cache.mkdir(exist_ok=True)
    (cache / ".gdignore").write_text("", encoding="utf-8")
    engine = args.godot.resolve()
    environment = os.environ.copy()
    environment.setdefault("DOTNET_ROLL_FORWARD", "LatestMajor")

    def run(arguments, log_name, timeout=180):
        result = subprocess.run(
            [str(engine), "--headless", *arguments], cwd=root, env=environment,
            capture_output=True, text=True, encoding="utf-8", errors="replace",
            timeout=timeout,
            creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
        )
        output = result.stdout + result.stderr
        (cache / log_name).write_text(output, encoding="utf-8")
        if result.returncode or "SCRIPT ERROR:" in output or "ERROR:" in output:
            raise RuntimeError(f"Godot failed; see {cache / log_name}\n{output[-5000:]}")
        return output.strip()

    version = run(["--version"], "version.log")
    with zipfile.ZipFile(args.templates) as archive:
        template_version = archive.read("templates/version.txt").decode().strip()
        if not version.startswith(template_version + "."):
            raise RuntimeError(f"Editor {version} does not match templates {template_version}")
        # Extract only the known executable; no archive-controlled output paths.
        data = archive.read("templates/windows_release_x86_64.exe")
        (cache / "windows_release_x86_64.exe").write_bytes(data)
    run(["--editor", "--path", str(root), "--quit"], "import.log")
    run(["--path", str(root), "--script", "res://tools/runtime_licenses.gd", "--",
         "--license-out=" + str(destination / "GODOT_LICENSES.txt")], "licenses.log")
    executable = destination / "SinkCity.exe"
    run(["--path", str(root), "--export-release", "Windows Desktop", str(executable)], "export.log")
    for name in ("README.md", "LICENSE", "THIRD_PARTY.md", "LEGACY_PROTOTYPE.md"):
        shutil.copyfile(root / name, destination / name)
    # Exercise the actual embedded pack with a dummy renderer and no game window.
    original_engine = engine
    engine = executable
    try:
        run(["--quit-after", "120", "--", "--test", "--demo"], "export-smoke.log")
    finally:
        engine = original_engine
    manifest = {
        "game": "Sink City", "version": "0.3.0-portrait-city-kit", "engine": version,
        "template_version": template_version,
        "template_sha256": hashlib.sha256(data).hexdigest(),
        "headless_export_smoke": "passed",
        "files": {p.name: {"bytes": p.stat().st_size, "sha256": hashlib.sha256(p.read_bytes()).hexdigest()}
                  for p in sorted(destination.iterdir()) if p.is_file() and p.name != "manifest.json"},
    }
    (destination / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    bundle = destination.parent / "SinkCity-Windows-x64.zip"
    with zipfile.ZipFile(bundle, "w", zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(destination.iterdir()):
            if path.is_file(): archive.write(path, "SinkCity/" + path.name)
    print(json.dumps({"executable": str(executable), "zip": str(bundle), "bytes": bundle.stat().st_size,
                      "sha256": hashlib.sha256(bundle.read_bytes()).hexdigest(), "smoke": "passed"}, indent=2))


if __name__ == "__main__":
    main()
