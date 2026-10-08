"""Read-only metadata audit; writes its receipt only beside this script."""
from pathlib import Path
import hashlib
import json
import plistlib
import subprocess
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
BASE = ROOT / "build/ios-preparation-20260930-03"
XCODE, SOURCE = BASE / "xcode", BASE / "source"

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

prep = json.loads((BASE / "preparation.json").read_text())
receipt_path = ROOT / "artifacts/shop-theme-20260930/release/release.json"
frozen = json.loads(receipt_path.read_text())["source_sha256"]
web_changes = [k for k, v in frozen.items() if sha(ROOT / k) != v]
files = {str(p.relative_to(XCODE)): sha(p) for p in XCODE.rglob("*") if p.is_file()}
original_changes = [k for k, v in prep["copied_source_sha256"].items() if sha(ROOT / k) != v]
copy_changes = [k for k, v in prep["copied_source_sha256"].items() if sha(SOURCE / k) != v]
unexpected_copy_changes = [k for k in copy_changes if k != "project.godot" and not k.endswith(".import")]
expected_settings = (ROOT / "project.godot").read_text().replace(
    "[rendering]\n", "[rendering]\ntextures/vram_compression/import_etc2_astc=true\n", 1)
pbx = json.loads((OUT / "pbxproj.json").read_text())
objects = pbx["objects"]
targets = [v for v in objects.values() if v.get("isa") == "PBXNativeTarget"]
configs, resources = [], []
for target in targets:
    for cid in objects[target["buildConfigurationList"]]["buildConfigurations"]:
        config = objects[cid]
        settings = config["buildSettings"]
        configs.append({"name": config["name"], **{k: settings.get(k) for k in (
            "DEVELOPMENT_TEAM", "PRODUCT_BUNDLE_IDENTIFIER", "MARKETING_VERSION",
            "CURRENT_PROJECT_VERSION", "IPHONEOS_DEPLOYMENT_TARGET",
            "TARGETED_DEVICE_FAMILY", "CODE_SIGN_STYLE", "CODE_SIGN_IDENTITY")}})
    for pid in target["buildPhases"]:
        phase = objects[pid]
        if phase["isa"] == "PBXResourcesBuildPhase":
            resources.extend(objects[objects[fid]["fileRef"]].get("path") for fid in phase["files"])

icons = XCODE / "SinkCity/Images.xcassets/AppIcon.appiconset"
icon_info = []
for entry in json.loads((icons / "Contents.json").read_text())["images"]:
    if not entry.get("filename"):
        continue
    image = Image.open(icons / entry["filename"])
    # Universal 1024 px asset entries omit scale; they use the stated pixel size.
    pixels = round(float(entry["size"].split("x")[0]) * float(entry.get("scale", "1x").rstrip("x")))
    alpha = image.convert("RGBA").getextrema()[3]
    icon_info.append({"file": entry["filename"], "pixels": list(image.size),
        "expected_pixels": pixels, "mode": image.mode, "alpha_extrema": list(alpha),
        "valid": image.size == (pixels, pixels) and alpha == (255, 255)})

privacy = plistlib.loads((XCODE / "PrivacyInfo.xcprivacy").read_bytes())
info = plistlib.loads((XCODE / "SinkCity/SinkCity-Info.plist").read_bytes())
entitlements = plistlib.loads((XCODE / "SinkCity/SinkCity.entitlements").read_bytes())
unexpected_errors = []
lines = (OUT / "resource.log").read_text().splitlines()
for i, line in enumerate(lines):
    if line.startswith(("ERROR:", "SCRIPT ERROR:", "SHADER ERROR:", "FATAL")):
        if (line == 'ERROR: Condition "ret != noErr" is true. Returning: ""'
                and i + 1 < len(lines)
                and "get_system_ca_certificates (platform/macos/os_macos.mm:" in lines[i + 1]):
            continue
        unexpected_errors.append(line)

architectures = {}
for key, relative in {
    "godot_device": "SinkCity.xcframework/ios-arm64/libgodot.a",
    "godot_simulator": "SinkCity.xcframework/ios-arm64_x86_64-simulator/libgodot.a",
    "moltenvk_device": "MoltenVK.xcframework/ios-arm64/libMoltenVK.a",
}.items():
    result = subprocess.run(["/usr/bin/lipo", "-archs", str(XCODE / relative)],
        capture_output=True, text=True, timeout=30, check=True)
    architectures[key] = result.stdout.strip().split()

result = {
    "status": "PASS_FOR_DEVICE_XCODE_PROJECT_PREPARATION_WITH_SIMULATOR_LIMITATION",
    "scope": "Read-only helper, template, Xcode metadata and desktop-headless PCK resource loading. No native compilation, signing, installation, upload, credentials or device execution.",
    "preparation_report_sha256": sha(BASE / "preparation.json"),
    "helper_sha256": sha(ROOT / "tools/prepare_ios_project.py"),
    "native_readme_sha256_at_review": sha(ROOT / "docs/ios-20260930/README.md"),
    "template_provenance_sha256": sha(ROOT / "artifacts/ios-20260930/template-provenance.json"),
    "web_receipt_sha256_matches": sha(receipt_path) == prep["web_receipt_sha256"],
    "web_inputs": len(frozen), "changed_web_inputs": web_changes,
    "copied_source_files": len(prep["copied_source_sha256"]),
    "original_copied_inputs_changed": original_changes,
    "prepared_copy_differences": copy_changes,
    "unexpected_copy_differences": unexpected_copy_changes,
    "snapshot_settings_exact_expected_override": expected_settings == (SOURCE / "project.godot").read_text(),
    "exported_files": len(files), "exported_files_match_author_hashes": files == prep["exported_files"],
    "pck_sha256": sha(XCODE / "SinkCity.pck"), "pck_bytes": (XCODE / "SinkCity.pck").stat().st_size,
    "target_configs": configs, "resource_build_phase": resources,
    "shell_script_phase_present": any(v.get("isa") == "PBXShellScriptBuildPhase" for v in objects.values()),
    "icons": icon_info, "privacy": privacy, "entitlements": entitlements,
    "unused_permission_descriptions": {k: v for k, v in info.items() if k.endswith("UsageDescription")},
    "orientation": info["UISupportedInterfaceOrientations"],
    "no_ipa_or_archive": not list(XCODE.rglob("*.ipa")) and not list(XCODE.rglob("*.xcarchive")),
    "dylibs_files": [str(p.relative_to(XCODE)) for p in (XCODE / "SinkCity/dylibs").rglob("*") if p.is_file()],
    "resource_probe": json.loads((OUT / "resources.json").read_text()),
    "unexpected_resource_probe_errors": unexpected_errors,
    "actual_library_architectures": architectures,
    "declared_simulator_architectures": ["arm64", "x86_64"],
    "limitations": [
        "The official simulator slice declares arm64+x86_64 but actually contains only x86_64; native Apple Silicon simulator support is not established.",
        "Real-device arm64 libraries are present; native linking and execution were not tested.",
        "Privacy reason codes are populated, not independently certified for a future final archive or future SDKs.",
        "Unused empty camera/photo/microphone purpose strings remain from the template; review them before final submission.",
        "Permanent native credits/privacy/support entries remain release work.",
        "The standard template member is verified by official HTTPS ranges and ZIP CRC; the complete 1.28 GB archive hash was not verified.",
    ],
}
assert not web_changes and not original_changes and not unexpected_copy_changes
assert result["web_receipt_sha256_matches"] and result["exported_files_match_author_hashes"]
assert result["snapshot_settings_exact_expected_override"] and all(x["valid"] for x in icon_info)
assert len(targets) == 1 and len(configs) == 2
assert all(c["DEVELOPMENT_TEAM"] == "KAMZHRWY33" and c["PRODUCT_BUNDLE_IDENTIFIER"] == "io.github.dotafs2.sinkcity" for c in configs)
assert {"SinkCity.pck", "PrivacyInfo.xcprivacy"} <= set(resources)
assert not entitlements and not privacy["NSPrivacyTracking"] and result["no_ipa_or_archive"]
assert not unexpected_errors and not result["resource_probe"]["failures"]
assert architectures["godot_device"] == ["arm64"] and architectures["moltenvk_device"] == ["arm64"]
(OUT / "review.json").write_text(json.dumps(result, indent=2) + "\n")
print(json.dumps({k: result[k] for k in ["status", "web_inputs", "copied_source_files", "exported_files", "pck_bytes", "actual_library_architectures"]}, indent=2))
