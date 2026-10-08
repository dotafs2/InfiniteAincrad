"""Create a local, unsigned Xcode project from an isolated game snapshot.

Requires the verified standard Godot 4.7.2 binary and iOS template, also installed
in that editor's export_templates/4.7.2.stable directory. Never runs
xcodebuild archive, provisioning updates, App Store registration or upload.
The destination must be new; failed output is retained for diagnosis.
"""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import re
import shutil
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[1]
TEMPLATE_SHA = "fd3280d10dc75356dded006f6f8813f40a5aebd32d128592b781256d8ffbdff4"
RUNTIME_DIRS = ("assets", "fidelity", "scripts", "Scenes", "shaders")


def normalize_native_project(exported):
    """Correct exporter defaults for this game's automatic-signing candidate."""
    project = exported / "SinkCity.xcodeproj" / "project.pbxproj"
    settings = project.read_text()
    distribution = 'CODE_SIGN_IDENTITY = "Apple Distribution";'
    development = 'CODE_SIGN_IDENTITY = "Apple Development";'
    if settings.count(distribution) not in (0, 2):
        raise RuntimeError("Unexpected Release signing settings; review before normalizing")
    # Automatic signing archives with a development identity. Organizer/export
    # later applies distribution signing for App Store Connect.
    project.write_text(settings.replace(distribution, development))
    info_path = exported / "SinkCity" / "SinkCity-Info.plist"
    info = plistlib.loads(info_path.read_bytes())
    removed = []
    for key in ("NSCameraUsageDescription", "NSMicrophoneUsageDescription",
                "NSPhotoLibraryUsageDescription"):
        if key in info:
            if info[key] != "":
                raise RuntimeError("Review nonempty permission description before removing " + key)
            del info[key]
            removed.append(key)
    info_path.write_bytes(plistlib.dumps(info, sort_keys=False))
    return {"archive_signing_identity": "Apple Development",
            "removed_unused_empty_permission_keys": removed}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate_app_icon_png(data):
    if (data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR"
            or len(data) < 33 or struct.unpack(">II", data[16:24]) != (1024, 1024)
            or data[24:26] != bytes((8, 2))):
        raise RuntimeError("The native app icon must be an opaque 1024-square RGB8 PNG")
    # RGB PNGs can still carry transparency through an optional tRNS chunk.
    offset = 8
    while offset + 12 <= len(data):
        length = struct.unpack(">I", data[offset:offset + 4])[0]
        tag = data[offset + 4:offset + 8]
        offset += length + 12
        if offset > len(data) or tag == b"tRNS":
            raise RuntimeError("The native app icon has invalid chunks or transparency")
        if tag == b"IEND":
            if offset != len(data):
                raise RuntimeError("Unexpected trailing native app icon data")
            return
    raise RuntimeError("The native app icon is incomplete")


def run(command, log, cwd):
    with log.open("w") as output:
        result = subprocess.run(command, cwd=cwd, stdout=output,
                                stderr=subprocess.STDOUT, timeout=600)
    text = log.read_text()
    lines = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", text).splitlines()
    errors = []
    for i, line in enumerate(lines):
        if re.match(r"^(?:ERROR:|SCRIPT ERROR:|SHADER ERROR:|FATAL|Export failed)", line):
            # Known macOS certificate-store read warning, unrelated to export.
            if (line == 'ERROR: Condition "ret != noErr" is true. Returning: ""'
                    and i + 1 < len(lines)
                    and "get_system_ca_certificates (platform/macos/os_macos.mm:" in lines[i + 1]):
                continue
            errors.append(line)
    if result.returncode or errors:
        raise RuntimeError(f"Native preparation failed; retained log: {log}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, type=Path)
    parser.add_argument("--template", required=True, type=Path)
    parser.add_argument("--team-id", required=True)
    parser.add_argument("--bundle-id", required=True)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--web-receipt", required=True, type=Path)
    parser.add_argument("--build-number", default="1")
    args = parser.parse_args()
    if not re.fullmatch(r"[1-9][0-9]*", args.build_number):
        parser.error("Build number must be a positive integer")
    if not re.fullmatch(r"[A-Z0-9]{10}", args.team_id):
        parser.error("Use the actual ten-character Apple Developer Team ID")
    if not re.fullmatch(r"[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+){2,}", args.bundle_id):
        parser.error("Use an explicit reverse-domain Bundle ID")
    godot, template = args.godot.resolve(), args.template.resolve()
    output = args.output.resolve()
    if not output.is_relative_to(ROOT / "build") or output.exists():
        parser.error("Output must be a new directory below this game's build directory")
    if sha(template) != TEMPLATE_SHA:
        raise RuntimeError("Unexpected iOS template; the standard 4.7.2 member is required")
    version = subprocess.check_output([str(godot), "--version"], text=True).strip()
    if version != "4.7.2.stable.official.ed1daf0bf":
        raise RuntimeError(f"Unexpected Godot version: {version}")
    receipt = args.web_receipt.resolve()
    frozen = json.loads(receipt.read_text())["source_sha256"]
    if not frozen:
        raise RuntimeError("Empty Web input receipt")
    # Launcher artwork is a native packaging input, independent of gameplay.
    # Bind it explicitly: historical Web gates did not include root icon.svg.
    app_icon = ROOT / "branding" / "app-icon.png"
    icon_manifest = ROOT / "branding" / "manifest.json"
    icon_inputs = [ROOT / "icon.svg"]
    if app_icon.exists():
        data = app_icon.read_bytes()
        validate_app_icon_png(data)
        declared = json.loads(icon_manifest.read_text())
        if declared.get("path") != "branding/app-icon.png" or declared.get("sha256") != sha(app_icon):
            raise RuntimeError("Native icon manifest does not bind the selected artwork")
        icon_inputs.extend([app_icon, icon_manifest])
    else:
        app_icon = ROOT / "icon.svg"
    frozen_icons = {str(p.relative_to(ROOT)): sha(p) for p in icon_inputs}

    def verify_original():
        changed = [name for name, expected in frozen.items()
                   if not (ROOT / name).is_file() or sha(ROOT / name) != expected]
        if changed:
            raise RuntimeError("Web inputs differ from the verified release: " + ", ".join(changed))
        changed_icons = [name for name, expected in frozen_icons.items()
                         if not (ROOT / name).is_file() or sha(ROOT / name) != expected]
        if changed_icons:
            raise RuntimeError("Native icon inputs changed during preparation: " + ", ".join(changed_icons))

    verify_original()
    source, exported, logs = output / "source", output / "xcode", output / "logs"
    source.mkdir(parents=True)
    exported.mkdir()
    logs.mkdir()
    copied = {}
    paths = [ROOT / "project.godot", ROOT / "icon.svg"]
    for name in RUNTIME_DIRS:
        paths.extend(sorted((ROOT / name).rglob("*")))
    for path in paths:
        if path.is_symlink():
            raise RuntimeError(f"Unexpected runtime symlink: {path}")
        if path.is_file():
            relative = path.relative_to(ROOT)
            target = source / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, target)
            copied[str(relative)] = sha(target)
    # iOS requires mobile texture imports even with the Compatibility renderer.
    # Only the native snapshot changes; the verified Web project stays identical.
    project_settings = source / "project.godot"
    settings = project_settings.read_text()
    game_version = re.search(r'^config/version="([0-9]+\.[0-9]+\.[0-9]+)"$', settings, re.M)
    if not game_version:
        raise RuntimeError("A semantic game version is required before native export")
    game_version = game_version.group(1)
    if settings.count("[rendering]\n") != 1 or "textures/vram_compression/import_etc2_astc" in settings:
        raise RuntimeError("Review native mobile texture override for changed project settings")
    project_settings.write_text(settings.replace("[rendering]\n", "[rendering]\ntextures/vram_compression/import_etc2_astc=true\n", 1))
    # The food-swallowing master is already opaque and has no rounded corners.
    # Keep the old SVG path only for historical snapshots without branding.
    native = source / "native"
    native.mkdir()
    base = [str(godot), "--headless", "--path", str(source)]
    if app_icon.suffix == ".png":
        shutil.copy2(app_icon, native / "icon.png")
        if sha(native / "icon.png") != frozen_icons["branding/app-icon.png"]:
            raise RuntimeError("Native icon copy differs from the bound master")
        (logs / "icon.log").write_text("Copied the verified opaque 1024-square food-swallowing icon.\n")
    else:
        (native / "icon.svg").write_text(app_icon.read_text().replace('rx="28"', 'rx="0"'))
        icon_script = output / "render_icon.gd"
        icon_script.write_text('''extends SceneTree
func _init() -> void:
    var image := Image.new()
    assert(image.load_svg_from_string(FileAccess.get_file_as_string("res://native/icon.svg"), 8.0) == OK)
    assert(image.get_size() == Vector2i(1024, 1024))
    image.convert(Image.FORMAT_RGB8)
    assert(image.save_png("res://native/icon.png") == OK)
    quit()
''')
        run(base + ["--script", str(icon_script), "--log-file", str(logs / "icon.engine.log")], logs / "icon.log", source)
    # Account identifiers stay in the ignored local snapshot, not source presets.
    preset = f'''[preset.0]
name="iOS Project"
platform="iOS"
runnable=false
advanced_options=true
export_filter="all_resources"
include_filter="assets/city_kit/*.json,assets/world_actors/*.json,assets/trains/*.json,assets/fairytale_castles/*.json,assets/fonts/OFL.txt,assets/audio/*.json,assets/audio/*.txt,assets/audio/README.md,assets/legal/*.txt"
exclude_filter="native/icon.svg,art_source/*,assets/fairytale_castles/source/*,*.blend"
export_path="{exported.as_posix()}/SinkCity.ipa"
script_export_mode=2

[preset.0.options]
custom_template/debug="{template.as_posix()}"
custom_template/release="{template.as_posix()}"
architectures/arm64=true
application/app_store_team_id="{args.team_id}"
application/bundle_identifier="{args.bundle_id}"
application/short_version="{game_version}"
application/version="{args.build_number}"
application/export_project_only=true
application/delete_old_export_files_unconditionally=false
application/export_method_debug=1
application/export_method_release=0
application/targeted_device_family=0
application/min_ios_version="15.0"
icons/icon_1024x1024="res://native/icon.png"
application/icon_interpolation=4
modules/camera=false
entitlements/game_center=false
entitlements/push_notifications="Disabled"
privacy/tracking_enabled=false
privacy/tracking_domains=PackedStringArray()
privacy/file_timestamp_access_reasons=2
privacy/system_boot_time_access_reasons=1
privacy/disk_space_access_reasons=1
privacy/active_keyboard_access_reasons=0
privacy/user_defaults_access_reasons=0
user_data/accessible_from_files_app=false
user_data/accessible_from_itunes_sharing=false
'''
    (source / "export_presets.cfg").write_text(preset)
    run(base + ["--editor", "--import", "--log-file", str(logs / "import.engine.log")], logs / "import.log", source)
    run(base + ["--export-release", "iOS Project", str(exported / "SinkCity.ipa"),
                "--log-file", str(logs / "export.engine.log")], logs / "export.log", source)
    project = exported / "SinkCity.xcodeproj" / "project.pbxproj"
    if not project.is_file() or (exported / "SinkCity.ipa").exists() or (exported / "SinkCity.xcarchive").exists():
        raise RuntimeError("Expected Xcode project-only output, without archive or IPA")
    native_export_fixes = normalize_native_project(exported)
    verify_original()
    report = {
        "status": "project_exported_unsigned_not_built_or_uploaded",
        "godot": version, "template_sha256": sha(template),
        "godot_binary_sha256": sha(godot),
        "web_receipt_sha256": sha(receipt), "unchanged_web_inputs": len(frozen),
        "copied_source_sha256": copied,
        "native_icon": {"source": str(app_icon.relative_to(ROOT)),
                        "source_sha256": sha(app_icon),
                        "input_sha256": frozen_icons,
                        "prepared_png_sha256": sha(native / "icon.png"),
                        "gameplay_receipt_separate": True},
        "native_overrides": {"textures/vram_compression/import_etc2_astc": True},
        "native_export_fixes": native_export_fixes,
        "native_project_settings_sha256": sha(project_settings),
        "native_export_preset_sha256": sha(source / "export_presets.cfg"),
        "project": str(project.parent.relative_to(output)),
        "exported_files": {str(p.relative_to(exported)): sha(p)
                           for p in sorted(exported.rglob("*")) if p.is_file()},
        "limitations": ["No native compilation, signing, installation or device test",
                        "This helper does not verify Apple Bundle ID registration",
                        "Requires eligible Xcode, SDK and distribution signing before TestFlight upload",
                        "Native device acceptance and App Store metadata remain separate release work"]
    }
    (output / "preparation.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({k: report[k] for k in ("status", "unchanged_web_inputs", "project")}))


if __name__ == "__main__":
    main()
