"""Install local redistribution notices in an unpublished Godot Web candidate.

The only game-page entry lives inside Godot's temporary loading overlay. Its
removal by the engine also removes the link; no permanent gameplay hit target
or game-canvas UI is introduced. The standalone credits page remains available.
"""
from __future__ import annotations

import hashlib
import html
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE_NOTICES = (
    ("LICENSE", "LICENSE.txt", "Hole Feast license"),
    ("THIRD_PARTY.md", "THIRD_PARTY.md", "Third-party acknowledgements"),
    ("assets/fonts/OFL.txt", "FREDOKA_OFL.txt", "Fredoka font — SIL Open Font License"),
    ("third_party/mbmayer/LICENSE", "MBMAYER_LICENSE.txt", "mbMayer template — MIT license"),
    ("assets/audio/MUSIC_CREDITS.txt", "MUSIC_CREDITS.txt", "Music credits"),
)
HEAD_START = "<!-- sink-city-notices:head -->"
HEAD_END = "<!-- /sink-city-notices:head -->"
LOAD_START = "<!-- sink-city-notices:loading -->"
LOAD_END = "<!-- /sink-city-notices:loading -->"


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _remove_owned(text: str, start: str, end: str) -> str:
    if text.count(start) != text.count(end) or text.count(start) > 1:
        raise ValueError("Ambiguous or incomplete existing notices hook")
    if start in text:
        first, last = text.index(start), text.index(end)
        if last < first:
            raise ValueError("Malformed notices hook")
        text = text[:first] + text[last + len(end):]
    return text


def inject_entry(text: str) -> str:
    text = _remove_owned(text, HEAD_START, HEAD_END)
    text = _remove_owned(text, LOAD_START, LOAD_END)
    notice = '<div id="status-notice"></div>'
    overlay = '<div id="status">'
    # Refuse unknown templates instead of placing an unreviewed overlay over
    # the game. The hook must be after the canvas and inside the known loader.
    if text.count("</head>") != 1 or text.count(notice) != 1 or text.count(overlay) != 1 or text.count("</canvas>") != 1:
        raise ValueError("Expected one head, canvas and Godot loading-status hook")
    head, canvas, status, anchor = (text.index(x) for x in ("</head>", "</canvas>", overlay, notice))
    if not head < canvas < status < anchor or "</div>" in text[status + len(overlay):anchor]:
        raise ValueError("Credits hook is not inside the temporary loading overlay")
    metadata = HEAD_START + '<link rel="license" href="credits.html">' + HEAD_END
    footer = (LOAD_START + '<p id="sink-city-credits" style="position:absolute;bottom:1rem;margin:0;z-index:2;'
              'font:14px/1.4 system-ui,sans-serif;text-align:center">'
              '<a href="credits.html" target="_blank" rel="noopener" '
              'style="display:inline-block;min-height:44px;line-height:44px;padding:0 .75rem;color:#e3e8ef" '
              'aria-label="Credits and licenses (opens a new tab)">Credits &amp; licenses</a></p>' + LOAD_END)
    return text.replace("</head>", metadata + "</head>", 1).replace(notice, notice + footer, 1)


def _credits_page() -> bytes:
    links = [(filename, title) for _, filename, title in SOURCE_NOTICES]
    links.append(("GODOT_LICENSES.txt", "Godot Engine and bundled dependency licenses"))
    items = "\n".join('<li><a href="notices/' + html.escape(filename, quote=True) + '">' + html.escape(title) + '</a></li>' for filename, title in links)
    return ('''<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Hole Feast — Credits and licenses</title>
<style>body{margin:0;background:#f4f6fb;color:#25304b;font:1rem/1.65 system-ui,sans-serif}
main{max-width:48rem;margin:auto;padding:2rem 1.25rem}a{color:#184faa;text-underline-offset:.2em}
a:focus-visible{outline:3px solid #8b4600;outline-offset:4px}li{margin:.6rem 0}li a{display:inline-block;padding:.4rem 0;min-height:1.5rem}
code{overflow-wrap:anywhere}h1{line-height:1.2}nav{margin-bottom:1.5rem}</style></head>
<body><main><nav aria-label="Game navigation"><a href="index.html">Return to Hole Feast</a></nav>
<h1>Credits and licenses</h1>
<p>Redistribution notices for this Hole Feast build. Each document is included locally with the game.</p>
<ul>''' + items + '''</ul>
<p>The engine notice is generated from the exact Godot build used by this package step and contains its dependency notices and license texts.</p>
<p><a href="notices/manifest.json">Notice bundle provenance and SHA-256 hashes</a></p>
</main></body></html>
''').encode("utf-8")


def _generate_engine_notice(godot: Path, destination: Path, log: Path) -> bytes:
    # Reuse the release gate's deliberately narrow diagnostic policy. In
    # particular, an ERROR with exit status zero must still reject the build.
    from release_web import unexpected_engine_errors
    command = [str(godot), "--headless", "--path", str(ROOT), "--script", str(ROOT / "tools/runtime_licenses.gd"),
               "--log-file", str(log), "--", "--test", "--license-out=" + str(destination)]
    try:
        completed = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                   text=True, timeout=45, check=False)
    except subprocess.TimeoutExpired as error:
        raise RuntimeError("Godot license generation timed out; candidate was not changed") from error
    output = completed.stdout + (log.read_text(encoding="utf-8") if log.exists() else "")
    if completed.returncode != 0 or unexpected_engine_errors(output) or "Parse Error" in output:
        raise RuntimeError("Godot license generation failed; candidate was not changed:\n" + output[-8000:])
    if not destination.is_file():
        raise RuntimeError("Godot did not write its license notice")
    data = destination.read_bytes()
    text = data.decode("utf-8")
    markers = ["THIRD-PARTY COPYRIGHT NOTICES", "THIRD-PARTY LICENSE TEXTS"]
    if not re.match(r"Godot Engine [^\n]+\n", text) or "Permission is hereby granted, free of charge" not in text:
        raise RuntimeError("Engine notice lacks its version or MIT license")
    if any(text.count(marker) != 1 for marker in markers) or text.index(markers[0]) > text.index(markers[1]):
        raise RuntimeError("Engine notice lacks complete ordered dependency sections")
    copyright_part, license_part = text.split(markers[0], 1)[1].split(markers[1], 1)
    if len(copyright_part.strip()) < 50 or len(license_part.strip()) < 50:
        raise RuntimeError("Engine dependency notices are empty or truncated")
    return data


def _commit(candidate: Path, payload: Path, backup: Path) -> None:
    """Rename three owned outputs with rollback, keeping index replacement last."""
    names = ["notices", "credits.html", "index.html"]
    installed: list[str] = []
    displaced: list[str] = []
    try:
        for name in names:
            target = candidate / name
            if target.exists():
                os.replace(target, backup / name)
                displaced.append(name)
            os.replace(payload / name, target)
            installed.append(name)
    except OSError:
        for name in reversed(installed):
            target = candidate / name
            if target.is_dir():
                shutil.rmtree(target)
            elif target.exists():
                target.unlink()
        for name in reversed(displaced):
            os.replace(backup / name, candidate / name)
        raise


def install_notices(candidate: Path | str, godot: Path | str) -> dict[str, str]:
    """Return relative artifact paths and SHA-256 hashes after a successful install.

    Only an unpublished exported candidate is an appropriate caller target.
    Required source notices and the engine are hashed before/after generation.
    No network, browser, runtime UI, player save or publication is involved.
    """
    raw_candidate = Path(candidate)
    if raw_candidate.is_symlink():
        raise ValueError("Candidate must be a real directory")
    candidate = raw_candidate.resolve(strict=True)
    godot = Path(godot).resolve(strict=True)
    if not candidate.is_dir() or candidate == ROOT.resolve() or not godot.is_file():
        raise ValueError("Expected an exported candidate directory and Godot executable")
    for name in ("index.html", "credits.html", "notices"):
        target = candidate / name
        if target.is_symlink():
            raise ValueError("Notice outputs may not be symlinks")
        if target.exists() and target.is_dir() != (name == "notices"):
            raise ValueError("Notice output has an unexpected file type")
    index = (candidate / "index.html").read_bytes()
    updated = inject_entry(index.decode("utf-8")).encode("utf-8")
    inputs = {relative: (ROOT / relative).read_bytes() for relative, _, _ in SOURCE_NOTICES}
    if any(not value.strip() for value in inputs.values()):
        raise ValueError("Required redistribution notice is empty")
    script = ROOT / "tools/runtime_licenses.gd"
    script_hash, engine_hash = digest(script.read_bytes()), digest(godot.read_bytes())
    with tempfile.TemporaryDirectory(prefix="web-notices-", dir=candidate.parent) as temporary:
        work = Path(temporary);payload = work / "payload";backup = work / "backup"
        (payload / "notices").mkdir(parents=True);backup.mkdir()
        for relative, filename, _ in SOURCE_NOTICES:
            (payload / "notices" / filename).write_bytes(inputs[relative])
        engine_data = _generate_engine_notice(godot, payload / "notices/GODOT_LICENSES.txt", work / "engine.log")
        # An injected test runner must obey the same output contract too.
        if (payload / "notices/GODOT_LICENSES.txt").read_bytes() != engine_data:
            raise RuntimeError("Engine notice output changed during generation")
        if inputs != {name: (ROOT / name).read_bytes() for name in inputs} or script_hash != digest(script.read_bytes()) or engine_hash != digest(godot.read_bytes()):
            raise RuntimeError("License inputs or engine changed during generation")
        (payload / "credits.html").write_bytes(_credits_page())
        (payload / "index.html").write_bytes(updated)
        bundle = {str(p.relative_to(payload)): digest(p.read_bytes()) for p in sorted(payload.rglob("*")) if p.is_file() and p.name != "index.html"}
        provenance = {"schema": 1, "engine_version": engine_data.decode("utf-8").splitlines()[0], "engine_sha256": engine_hash,
                      "runtime_licenses_sha256": script_hash, "source_sha256": {key: digest(value) for key, value in inputs.items()},
                      "files": bundle, "entry": {"head_license_link": True, "loading_overlay_link": True, "always_visible_gameplay_link": False}}
        (payload / "notices/manifest.json").write_text(json.dumps(provenance, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        if (candidate / "index.html").read_bytes() != index:
            raise RuntimeError("Candidate index changed during notice generation")
        result = {str(p.relative_to(payload)): digest(p.read_bytes()) for p in sorted(payload.rglob("*")) if p.is_file()}
        _commit(candidate, payload, backup)
    return result
