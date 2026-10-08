"""Gate the local Web Review build on actual source AND packaged scene QA.

python3 tools/release_web.py --godot .build/godot-standard/Godot.app/Contents/MacOS/Godot
The previous preview stays intact if export or either physics run fails.
Only the separate game build/artifact directories are written.
"""
import argparse
import hashlib
import json
import re
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
# Keep sibling helpers available when the gate is loaded by an evidence verifier.
if str(ROOT / "tools") not in sys.path:
    sys.path.insert(0, str(ROOT / "tools"))
from package_web_notices import install_notices

SUITES = [("release_info", [], 32), ("fairytale_city", [], 169), ("toy_geometry", [], 131), ("toy_guard_geometry", [], 191), ("frostlight_city", [], 9), ("frost_legacy_physics", [], 47), ("glacier_frozen_review", [], 2400),
          ("toy_city", [], 2844), ("toy_map_integration", [], 76), ("toy_court", [], 639),
          ("native_polish", [], 45), ("viewport_layout", [], 41), ("application_lifecycle", [], 70), ("scene_qa", [], 400), ("street_prop_qa", ["--all-props"], 700),
          ("claim_recovery", [], 8), ("full_city_qa", [], 600), ("skin_collection", [], 350),
          ("skin_fx", [], 100), ("title_navigation", [], 25), ("ui_redesign", [], 150),
          ("map_carousel", [], 450), ("map_unlock", [], 90), ("food_preview", [], 483),
          ("coin_skins", [], 80), ("skin_case_transaction", [], 130), ("skin_case_ui", [], 540), ("skin_case_audio", [], 70), ("skin_skill", [], 20),
          ("snack_city", [], 80), ("food_city_density", [], 1000), ("food_round", [], 2),
          ("food_finish", [], 136), ("food_neighborhoods", [], 150), ("mobile_maps", [], 25),
          ("performance", ["--reference-ground="+str(ROOT/"tests/fixtures/ground_before_performance.gd")], 260),
          ("portrait", [], 30), ("progression", [], 15), ("store", [], 17),
          ("city_motion", [], 22), ("city_districts", [], 1200), ("skin_catalog", [], 842),
          ("food_rain_continuity", [], 38), ("food_city_revision", [], 85), ("food_impact", [], 256),
          ("ui_collection_review", [], 150), ("food_goals_review", [], 37),
          ("progression_review", [], 10), ("rain_review", [], 9),
          ("crowd_review", [], 17), ("district_review", [], 4),
          ("food_revision_review", [], 11), ("skin_catalog_review", [], 202),
          ("mobile_thumbnail", [], 695), ("procedural_filtering", [], 27),
          ("selective_reveal", [], 75), ("selective_reveal_review", [], 491),
          ("building_only_reveal_review", [], 213), ("building_surface_artifacts", [], 1438),
          ("growth_extension", [], 1978), ("rival_combat", [], 58),
          ("large_growth_world", [], 258), ("pedestrian_swallow_review", [], 120),
          ("growth_rivals_review", [], 291), ("growth_integration_review", [], 1606),
          ("food_collision", [], 156), ("food_collision_review", [], 18276),
          ("music", [], 125), ("world_music", [], 150), ("music_review", [], 118), ("shop_theme_review", [], 55),
          ("food_color", [], 55), ("food_color_review", [], 1109),
          ("skin_rarity", [], 556), ("skin_rarity_review", [], 1555),
          ("world_expansion", [], 57), ("world_expansion_review", [], 284),
          ("monetization_bridges", [], 116), ("economy_continuation", [], 120), ("diamond_boundary_review", [], 25), ("retention", [], 67),
          ("retention_review", [], 590), ("retention_ui_review", [], 2443),
          ("perimeter_frontage", [], 631), ("food_extension_collision_review", [], 189),
          ("train", [], 220), ("train_surface", [], 161), ("train_review", [], 388),
          ("train_surface_review", [], 1121), ("boost", [], 55), ("boost_review", [], 98),
          ("skin_polish", [], 486), ("skin_polish_review", [], 760),
          ("food_growth", [], 2202), ("food_growth_review", [], 1476),
          ("rain_admission", [], 71), ("rain_admission_review", [], 101),
          ("rain_support", [], 102)]
REVIEW_SCRIPTS = {
    "glacier_frozen_review": ("glacier_frozen_review_acceptance.gd", "GLACIER_FROZEN_REVIEW"),
    "diamond_boundary_review": ("diamond_boundary_review.gd", "DIAMOND_BOUNDARY_REVIEW"),
    "shop_theme_review": ("shop_theme_review.gd", "SHOP_THEME_REVIEW"),
    "rain_admission_review": ("rain_admission_review.gd", "RAIN_ADMISSION_REVIEW"),
    "skin_polish_review": ("skin_polish_review.gd", "SKIN_POLISH_REVIEW"),
    "food_growth_review": ("food_growth_review.gd", "FOOD_GROWTH_REVIEW"),
    "boost_review": ("boost_review.gd", "BOOST_REVIEW"),
    "train_surface_review": ("train_surface_review.gd", "TRAIN_SURFACE_REVIEW"),
    "train_review": ("train_review.gd", "TRAIN_REVIEW"),
    "food_extension_collision_review": ("food_extension_collision_review.gd", "FOOD_EXTENSION_COLLISION_REVIEW"),
    "retention_ui_review": ("retention_ui_review.gd", "RETENTION_UI_REVIEW"),
    "retention_review": ("retention_review.gd", "RETENTION_REVIEW"),
    "food_color_review": ("food_color_review.gd", "FOOD_COLOR_REVIEW"),
    "skin_rarity_review": ("skin_rarity_review.gd", "SKIN_RARITY_REVIEW"),
    "world_expansion_review": ("world_expansion_review.gd", "WORLD_EXPANSION_REVIEW"),
    "music_review": ("music_review.gd", "MUSIC_REVIEW"),
    "building_only_reveal_review": ("building_only_reveal_review.gd", "BUILDING_ONLY_REVEAL_REVIEW"),
    "map_preview_review": ("map_preview_review.gd", "MAP_PREVIEW_REVIEW"),
    "food_collision_review": ("food_collision_review.gd", "FOOD_COLLISION_REVIEW"),
    "growth_integration_review": ("growth_integration_review.gd", "GROWTH_INTEGRATION_REVIEW"),
    "growth_rivals_review": ("growth_rivals_review.gd", "GROWTH_RIVALS_REVIEW"),
    "pedestrian_swallow_review": ("pedestrian_swallow_review.gd", "PEDESTRIAN_SWALLOW_REVIEW"),
    "selective_reveal_review": ("selective_reveal_review.gd", "SELECTIVE_REVEAL_REVIEW"),
    "food_revision_review": ("city_review_food_revision.gd", "CITY_REVIEW_FOOD_REVISION"),
    "skin_catalog_review": ("city_review_skin_catalog.gd", "CITY_REVIEW_SKIN_CATALOG"),
    "ui_collection_review": ("review_ui_collection.gd", "UI_COLLECTION_REVIEW"),
    "food_goals_review": ("review_food_goals.gd", "FOOD_GOALS_REVIEW"),
    "progression_review": ("city_review_progression.gd", "CITY_REVIEW_PROGRESSION"),
    "rain_review": ("city_review_food_rain.gd", "CITY_REVIEW_FOOD_RAIN"),
    "crowd_review": ("food_crowd_review.gd", "FOOD_CROWD_REVIEW"),
    "district_review": ("food_review_city_districts.gd", "FOOD_REVIEW_CITY_DISTRICTS"),
}

def suite_script(suite):
    return REVIEW_SCRIPTS.get(suite, (suite + "_acceptance.gd", suite.upper() + "_ACCEPTANCE"))[0]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def unexpected_engine_errors(text, allow_fixture_parse=False):
    plain = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", text)
    lines = [line.strip() for line in plain.splitlines()]
    failures = []
    for i, line in enumerate(lines):
        if not re.match(r"^(?:ERROR:|SCRIPT ERROR:|SHADER ERROR:|FATAL(?: ERROR)?:)", line): continue
        if line == 'ERROR: Condition "ret != noErr" is true. Returning: ""' and i+1 < len(lines) and 'at: get_system_ca_certificates (platform/macos/os_macos.mm:' in lines[i+1]: continue
        if allow_fixture_parse and re.fullmatch(r"ERROR: ConfigFile parse error at /tmp/hole-city-coin-qa-\d+-broken\.cfg:0: Unexpected EOF while parsing simple tag\.", line): continue
        failures.append(line)
    return failures


def run(command, log, return_failure=False, allow_fixture_parse=False, cwd=None):
    split = command.index("--") if "--" in command else len(command)
    command = command[:split] + ["--log-file", str(log.with_suffix(".engine.log"))] + command[split:]
    failed = False
    markers = ("SCRIPT ERROR", "Parse Error", "Export failed", "No clear recipe placement", "No clear street furniture placement")
    with log.open("w") as out, log.open("r") as monitor:
        process = subprocess.Popen(command, stdout=out, stderr=subprocess.STDOUT, cwd=cwd)
        deadline = time.monotonic() + 600
        carry = ""
        try:
            while process.poll() is None:
                chunk = carry + monitor.read()
                carry = chunk[-256:]
                if any(marker in chunk for marker in markers) or time.monotonic() >= deadline:
                    failed = True
                    break
                time.sleep(.10)
        finally:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
        failed = failed or process.returncode != 0
    text = log.read_text()
    failed = failed or any(marker in text for marker in ("SCRIPT ERROR", "Parse Error", "Export failed", "No clear recipe placement", "No clear street furniture placement"))
    failed = failed or bool(unexpected_engine_errors(text, allow_fixture_parse))
    if failed and not return_failure:
        raise RuntimeError(f"Step failed; previous preview preserved. See {log}")
    return text, failed


def acceptance(command, log, report, suite, minimum, cwd=None):
    text, process_failed = run(command, log, return_failure=True, allow_fixture_parse=suite == "coin_skins", cwd=cwd)
    prefix = REVIEW_SCRIPTS.get(suite, (None, suite.upper() + "_ACCEPTANCE"))[1] + " "
    lines = [line[len(prefix):] for line in text.splitlines() if line.startswith(prefix)]
    if not lines:
        report.write_text(json.dumps({"checks": 0, "failures": ["Missing completion marker; inspect the engine log"], "log": str(log)}, indent=2) + "\n")
        raise RuntimeError(f"Missing scene QA completion marker: {log}")
    data = json.loads(lines[-1])
    if process_failed:
        data.setdefault("failures", []).append("Engine process failed; inspect the engine log")
    report.write_text(json.dumps(data, indent=2) + "\n")
    if data.get("failures") or data.get("checks", 0) < minimum:
        raise RuntimeError(f"Scene QA failed; previous preview preserved. See {report}")
    return data


def input_hashes():
    inputs = [ROOT / "project.godot", ROOT / "export_presets.cfg", ROOT / "artifacts/.gdignore", ROOT / "build/.gdignore", ROOT / "tools/device_qa.js",
              ROOT / "tests/device_qa_test.cjs", ROOT / "tests/fixtures/ground_before_performance.gd",
              ROOT / "tools/release_web.py", ROOT / "tools/bake_prop_collisions.gd", ROOT / "tools/bake_building_fragments.gd",
              ROOT / "tools/prepare_shop_theme.py", ROOT / "tools/package_web_notices.py",
              ROOT / "tools/runtime_licenses.gd", ROOT / "tests/test_web_notices.py",
              ROOT / "LICENSE", ROOT / "THIRD_PARTY.md", ROOT / "third_party/mbmayer/LICENSE",
              ROOT / "tools/build_actor_recipes.py", ROOT / "tools/build_food_neighborhoods.py", ROOT / "tools/build_ui_icons.py", ROOT / "tools/build_music.py",
              ROOT / "tools/build_case_audio.py", ROOT / "tools/prepare_world_music.py", ROOT / "tools/bake_skin_case_thumbnails.gd", ROOT / "tests/map_thumbnail_capture.gd", ROOT / "tools/build_frost_blender_assets.py", ROOT / "art_source/frostlight/frostlight_assets.blend",
              ROOT / "art_source/frostlight/asset-manifest.json", ROOT / "tools/build_train_assets.py", ROOT / "tools/build_fairytale_castles.py", ROOT / "tools/extract_frost_legacy_castle_physics.gd", ROOT / "tests/royal_castle_capture.gd", ROOT / "tools/capture_royal_castle.gd", ROOT / "tests/toy_visual_capture.gd", ROOT / "art_source/.gdignore",
              ROOT / "art_source/trains/train_assets.blend", ROOT / "art_source/trains/validate_assets.py",
              *[ROOT / "tests" / suite_script(suite) for suite, _, _ in SUITES]]
    for directory in ["fidelity", "scripts", "assets", "Scenes", "shaders"]:
        inputs.extend(p for p in sorted((ROOT / directory).rglob("*"))
                      # Import recipes affect rendered pixels (including road
                      # mipmaps), so they are part of the tested build inputs.
                      if p.is_file() and p.suffix != ".uid" and p.name != ".DS_Store")
    return {str(p.relative_to(ROOT)): digest(p) for p in inputs}


def verify_inputs(expected):
    if input_hashes() != expected:
        raise RuntimeError("Source changed during acceptance; previous preview preserved. Run the gate again.")


def install_device_qa(candidate):
    # Optional, local-only hardware evidence. Ordinary visits never mount QA.
    qa = candidate / "device-qa.js"
    shutil.copy2(ROOT / "tools/device_qa.js", qa)
    page = candidate / "index.html"
    html = page.read_text()
    metadata = {"pck_sha256": digest(candidate / "index.pck"), "wasm_sha256": digest(candidate / "index.wasm"),
                "recorder_sha256": digest(qa), "version": next(line.split('=')[1].strip().strip('"') for line in (ROOT / "project.godot").read_text().splitlines() if line.startswith('config/version='))}
    if html.count('<script src="index.js"></script>') != 1: raise RuntimeError("Missing engine script; preview preserved")
    html = html.replace('<script src="index.js"></script>', '<script>window.SINK_QA_BUILD = '+json.dumps(metadata)+';</script>\n<script src="device-qa.js"></script>\n<script src="index.js"></script>')
    hook = 'if (window.SinkDeviceQA && window.SinkDeviceQA.enabled) GODOT_CONFIG.args = ["--", "--test", "--device-qa"];\n'
    if html.count('const engine = new Engine(GODOT_CONFIG);') != 1: raise RuntimeError("Missing engine boot hook; preview preserved")
    html = html.replace('const engine = new Engine(GODOT_CONFIG);', hook+'const engine = new Engine(GODOT_CONFIG);')
    if html.count('<script src="device-qa.js"></script>') != 1 or html.count(hook) != 1: raise RuntimeError("Incomplete QA boot installation; preview preserved")
    page.write_text(html)


def publish_candidate(candidate, preview, artifacts):
    # Fully verify a sibling directory before switching the served path. The
    # server resolves this absolute path per request; it does not chdir into it.
    with tempfile.TemporaryDirectory(prefix="preview-swap-", dir=preview.parent) as scratch:
        stage = Path(scratch) / "ready"
        backup = preview.with_name(preview.name + ".previous-" + uuid.uuid4().hex)
        shutil.copytree(candidate, stage)
        if any(digest(stage / name) != sha for name, sha in artifacts.items()):
            raise RuntimeError("Staged preview checksum mismatch; previous preview preserved")
        had_previous = preview.exists()
        if had_previous: preview.rename(backup)
        try:
            stage.rename(preview)
            if any(digest(preview / name) != sha for name, sha in artifacts.items()):
                raise RuntimeError("Local preview checksum mismatch")
        except BaseException:
            if preview.exists(): shutil.rmtree(preview)
            if had_previous:
                try: backup.rename(preview)
                except OSError as rollback_error:
                    raise RuntimeError(f"Preview rollback needs recovery; previous build retained at {backup}") from rollback_error
            raise
        if had_previous: shutil.rmtree(backup)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, type=Path)
    parser.add_argument("--evidence", type=Path, default=ROOT / "artifacts" / "release")
    parser.add_argument("--preview", type=Path, default=ROOT / "build" / "web", help="Verified preview destination; defaults to the existing local preview")
    args = parser.parse_args()
    godot = str(args.godot.resolve())
    evidence = args.evidence.resolve()
    evidence.mkdir(parents=True, exist_ok=True)
    base = [godot, "--headless", "--path", str(ROOT)]
    def check_suites(engine_args, prefix, working_directory=None):
        results = {}
        for suite, extra, minimum in SUITES:
            print(f"Checking {prefix} {suite}...", flush=True)
            test = ["--script", str(ROOT / "tests" / suite_script(suite)), "--fixed-fps", "60",
                    "--quit-after", "140000", "--", "--test", *([] if suite in {"map_unlock", "map_carousel", "world_music"} else ["--qa-unlocked-worlds"]), *extra]
            results[suite] = acceptance(engine_args + test, evidence / f"{prefix}-{suite}.log",
                                        evidence / f"{prefix}-{suite}.json", suite, minimum, cwd=working_directory)
        return results
    tested_inputs = input_hashes()
    notices_test = subprocess.run([sys.executable, str(ROOT / "tests/test_web_notices.py")], capture_output=True, text=True, timeout=45)
    (evidence / "web-notices-test.log").write_text(notices_test.stdout + notices_test.stderr)
    if notices_test.returncode: raise RuntimeError("Web notice packaging checks failed; preview preserved")
    train_assets = subprocess.run([sys.executable, str(ROOT / "art_source/trains/validate_assets.py")], capture_output=True, text=True, timeout=30)
    (evidence / "train-assets.log").write_text(train_assets.stdout + train_assets.stderr)
    if train_assets.returncode: raise RuntimeError("Train asset buffers/source hashes failed; preview preserved")
    train_asset_result = json.loads(train_assets.stdout)
    if train_asset_result.get("failures") or train_asset_result.get("checks", 0) < 246: raise RuntimeError("Incomplete train asset validation; preview preserved")
    recorder = subprocess.run(["node", str(ROOT / "tests/device_qa_test.cjs")], capture_output=True, text=True, timeout=30)
    (evidence / "device-qa-test.log").write_text(recorder.stdout + recorder.stderr)
    if recorder.returncode or "DEVICE_QA_TEST " not in recorder.stdout: raise RuntimeError("Device recorder self-test failed; preview preserved")
    source = check_suites(base, "source")
    verify_inputs(tested_inputs)
    build = ROOT / "build"
    build.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="qa-candidate-", dir=build) as scratch:
        candidate = Path(scratch)
        print("Exporting candidate Web Review package...", flush=True)
        run(base + ["--export-release", "Web Review", str(candidate / "index.html")], evidence / "export.log")
        install_device_qa(candidate)
        install_notices(candidate, godot)
        packaged = check_suites([godot, "--headless", "--main-pack", str(candidate / "index.pck")], "package", candidate)
        verify_inputs(tested_inputs)
        artifacts = {str(p.relative_to(candidate)): digest(p) for p in sorted(candidate.rglob("*")) if p.is_file()}
        publish_candidate(candidate, args.preview.resolve(), artifacts)

    manifest = dict(source_checks=sum(r["checks"] for r in source.values()), packaged_checks=sum(r["checks"] for r in packaged.values()), failures=[],
                    artifacts=artifacts, source_sha256=tested_inputs, device_recorder_checks=json.loads(recorder.stdout.split("DEVICE_QA_TEST ")[-1])["checks"],
                    train_asset_checks=train_asset_result["checks"],
                    limitation="Headless physics and asset checks; browser rendering and iPhone GPU performance are not covered.")
    (evidence / "release.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"Local preview updated: {manifest['source_checks']} source checks and {manifest['packaged_checks']} packaged checks passed.", flush=True)


if __name__ == "__main__":
    main()
