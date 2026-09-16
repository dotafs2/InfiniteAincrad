"""Bounded Tripo text-to-model trial for five fantasy town houses (2026-09-16).

Commands (run from the repository root):

  python -X utf8 tools/tripo_houses_trial.py dry-run
  python -X utf8 tools/tripo_houses_trial.py status
  python -X utf8 tools/tripo_houses_trial.py balance [--key-file PATH]
  python -X utf8 tools/tripo_houses_trial.py submit [--house ID]... [--key-file PATH]
  python -X utf8 tools/tripo_houses_trial.py poll [--deadline 1200] [--house ID]... [--key-file PATH]
  python -X utf8 tools/tripo_houses_trial.py download [--house ID]... [--key-file PATH]
  python -X utf8 tools/tripo_houses_trial.py resume [--deadline 1200] [--key-file PATH]

Safety contract:
  * The key file (default secrets/tripo-key.txt) is read only by live commands (balance/submit/
    poll/download/resume). Key text, request headers and raw exception text never reach stdout,
    the public summary or the tracked tree; raw provider receipts stay in gitignored tmp/.
  * At most one POST per house and at most five creations in total. A POST is marked "attempted"
    before it is sent, so a network error, timeout, 5xx or ambiguous reply is never retried and no
    model is silently regenerated. A known task id is always polled/downloaded instead.
  * A house whose stored request fingerprint differs from the current manifest is refused instead
    of creating an implicit new task.
  * Credits: one balance read before submitting, stop if the balance is below the planned cost of
    the houses still missing a task. Measured credits_consumed is reported as null when unknown.
"""
import argparse
import hashlib
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "Art" / "Generated" / "TripoHouses20260916" / "trial.json"
DEFAULT_KEY_FILE = ROOT / "secrets" / "tripo-key.txt"
TMP_DIR = ROOT / "tmp" / "tripo-houses-20260916"
EXPORT_DIR = ROOT / "exports" / "tripo-houses-20260916"
STATE_PATH = TMP_DIR / "tasks.json"
RAW_DIR = TMP_DIR / "raw"
MODEL_DIR = EXPORT_DIR / "models"
GLB_MAX_BYTES = 300 * 1024 * 1024
HTTP_TIMEOUT = 30.0
DOWNLOAD_TIMEOUT = 90.0
BACKOFFS = (5.0, 10.0, 15.0)
TERMINAL = ("success", "failed", "cancelled", "banned")
_ACTIVE_SECRETS = []


def now_utc():
    return datetime.now(timezone.utc).isoformat()


def atomic_write(path: Path, text: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".part")
    temporary.write_text(text, encoding="utf-8")
    os.replace(temporary, path)


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def sanitize(text: str, secrets=()) -> str:
    cleaned = re.sub(r"(?i)authorization\s*:\s*\S+", "authorization: [redacted]", text or "")
    for secret in secrets:
        if secret:
            cleaned = cleaned.replace(secret, "[redacted]")
    return cleaned


class TripoError(RuntimeError):
    def __init__(self, kind, message="", status=None, code=None):
        super().__init__(message)
        self.kind = kind
        self.status = status
        self.code = code

    def public(self, secrets=()):
        return {"error_class": self.kind, "http_status": self.status, "provider_code": self.code,
                "message": sanitize(str(self), secrets)[:200]}


def load_manifest():
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    houses = manifest.get("houses") or []
    if len(houses) != 5:
        raise SystemExit("manifest must describe exactly five houses, found %d" % len(houses))
    settings = manifest["settings"]
    forbidden = {"quad", "smart_low_poly", "generate_parts", "compress", "auto_size"}
    if forbidden & set(settings):
        raise SystemExit("manifest settings contain unsupported switches: %s" % sorted(forbidden & set(settings)))
    for house in houses:
        if len(house["prompt"]) > 1024:
            raise SystemExit("%s: prompt exceeds 1024 characters" % house["id"])
    if len(manifest.get("negative_prompt", "")) > 255:
        raise SystemExit("negative_prompt exceeds 255 characters")
    if manifest["maximum_creations"] != 5:
        raise SystemExit("maximum_creations must stay at 5")
    return manifest


def job_request(manifest, house):
    request = {"model": manifest["model"], "prompt": house["prompt"],
               "negative_prompt": manifest["negative_prompt"]}
    request.update(manifest["settings"])
    return request


def fingerprint(manifest, house) -> str:
    return sha256_text(json.dumps(job_request(manifest, house), sort_keys=True, ensure_ascii=False))


def empty_state(manifest) -> dict:
    return {"trial_id": manifest["trial_id"], "manifest_sha256": sha256_file(MANIFEST_PATH),
            "base_url": manifest["base_url"], "model": manifest["model"],
            "settings": manifest["settings"], "created_at_utc": now_utc(), "houses": {}}


def load_state(manifest):
    if STATE_PATH.exists():
        state = json.loads(STATE_PATH.read_text(encoding="utf-8"))
    else:
        state = empty_state(manifest)
    for house in manifest["houses"]:
        state["houses"].setdefault(house["id"], {
            "id": house["id"], "name_zh": house.get("name_zh", ""),
            "prompt_sha256": sha256_text(house["prompt"]), "fingerprint": fingerprint(manifest, house),
            "state": "pending", "task_id": None, "post_attempts": 0, "post_attempted_at_utc": None,
            "status": None, "progress": None, "credits_consumed": None, "model_url": None,
            "rendered_image_url": None, "glb_path": None, "glb_sha256": None, "glb_bytes": None,
            "last_polled_at_utc": None, "error": None})
    return state


def save_state(state):
    atomic_write(STATE_PATH, json.dumps(state, indent=2, sort_keys=True))


def house_by_id(manifest, house_id):
    for house in manifest["houses"]:
        if house["id"] == house_id:
            return house
    raise SystemExit("unknown house id: %s" % house_id)


def check_fingerprints(manifest, state):
    """Refuse an implicit new task when the stored request no longer matches the manifest."""
    for house in manifest["houses"]:
        entry = state["houses"][house["id"]]
        current = fingerprint(manifest, house)
        if entry.get("fingerprint") != current:
            if entry.get("task_id") or entry.get("post_attempts"):
                raise SystemExit("refusing implicit new task for %s: stored fingerprint differs from the "
                                 "manifest (prompt/model/settings changed). Keep the original task or ask the "
                                 "supervisor to open a new trial id." % house["id"])
            entry["fingerprint"] = current
            entry["prompt_sha256"] = sha256_text(house["prompt"])


def read_key(key_file: Path) -> str:
    if not key_file.exists():
        raise SystemExit("key file not found: %s (pass --key-file or set TRIPO_API_KEY)" % key_file)
    key = key_file.read_text(encoding="utf-8").strip()
    if not key:
        raise SystemExit("key file is empty: %s" % key_file)
    return key


def resolve_key(args):
    if args.key_file:
        key = read_key(Path(args.key_file))
    else:
        environment = os.environ.get("TRIPO_API_KEY")
        key = environment.strip() if environment else read_key(DEFAULT_KEY_FILE)
    if key not in _ACTIVE_SECRETS:
        _ACTIVE_SECRETS.append(key)
    return key


class HttpTransport:
    """Real HTTPS transport. Never logs headers, the key or a raw exception body."""

    def __init__(self, base_url, key):
        self.base_url = base_url.rstrip("/")
        self.key = key

    def _open(self, request, timeout):
        return urllib.request.urlopen(request, timeout=timeout)

    def get_json(self, path):
        request = urllib.request.Request(self.base_url + path,
                                        headers={"Authorization": "Bearer " + self.key,
                                                 "Accept": "application/json"})
        return self._read_json(request, HTTP_TIMEOUT)

    def post_json(self, path, payload):
        body = json.dumps(payload).encode("utf-8")
        request = urllib.request.Request(self.base_url + path, data=body, method="POST",
                                        headers={"Authorization": "Bearer " + self.key,
                                                 "Content-Type": "application/json",
                                                 "Accept": "application/json"})
        return self._read_json(request, HTTP_TIMEOUT)

    def _read_json(self, request, timeout):
        try:
            with self._open(request, timeout) as response:
                raw = response.read()
                status = response.status
        except urllib.error.HTTPError as error:
            try:
                error.read(4096)
            except Exception:
                pass
            raise TripoError("http_error", "HTTP %d from provider" % error.code, status=error.code)
        except Exception as error:
            raise TripoError("network_error", "transport failed: %s" % type(error).__name__)
        try:
            payload = json.loads(raw.decode("utf-8"))
        except Exception:
            raise TripoError("invalid_json", "provider response was not JSON", status=status)
        if status >= 500:
            raise TripoError("server_error", "HTTP %d from provider" % status, status=status)
        if payload.get("code") not in (0, None):
            raise TripoError("provider_code", "provider returned a non-zero code", status=status,
                             code=payload.get("code"))
        return payload

    def download(self, url, destination: Path, max_bytes=GLB_MAX_BYTES):
        """Download a signed CDN URL with a separate request and no Authorization header."""
        request = urllib.request.Request(url, headers={"Accept": "model/gltf-binary,*/*"})
        destination.parent.mkdir(parents=True, exist_ok=True)
        temporary = destination.with_suffix(destination.suffix + ".part")
        written = 0
        try:
            with self._open(request, DOWNLOAD_TIMEOUT) as response, temporary.open("wb") as handle:
                while True:
                    block = response.read(1024 * 1024)
                    if not block:
                        break
                    written += len(block)
                    if written > max_bytes:
                        raise TripoError("download_too_large", "download exceeded %d bytes" % max_bytes)
                    handle.write(block)
        except TripoError:
            temporary.unlink(missing_ok=True)
            raise
        except Exception as error:
            temporary.unlink(missing_ok=True)
            raise TripoError("download_failed", "download failed: %s" % type(error).__name__)
        validation = validate_glb(temporary)
        if not validation["ok"]:
            temporary.unlink(missing_ok=True)
            raise TripoError("invalid_glb", "rejected downloaded model: %s" % validation["reason"])
        os.replace(temporary, destination)
        return validation


def validate_glb(path: Path) -> dict:
    """Validate GLB magic, version 2 and declared length before a file is accepted."""
    size = path.stat().st_size
    if size < 20:
        return {"ok": False, "reason": "file smaller than a GLB header", "bytes": size}
    with path.open("rb") as handle:
        header = handle.read(12)
    if header[0:4] != b"glTF":
        return {"ok": False, "reason": "missing glTF magic", "bytes": size}
    version = int.from_bytes(header[4:8], "little")
    declared = int.from_bytes(header[8:12], "little")
    if version != 2:
        return {"ok": False, "reason": "glTF version %d is not 2" % version, "bytes": size}
    if declared != size:
        return {"ok": False, "reason": "declared length %d differs from file size %d" % (declared, size),
                "bytes": size}
    return {"ok": True, "reason": "", "bytes": size, "version": version, "declared_length": declared}


def house_public(entry) -> dict:
    result = {"id": entry["id"], "name_zh": entry.get("name_zh", ""),
              "prompt_sha256": entry.get("prompt_sha256"), "request_fingerprint": entry.get("fingerprint"),
              "state": entry.get("state"), "task_id": entry.get("task_id"),
              "post_attempts": entry.get("post_attempts", 0), "status": entry.get("status"),
              "progress": entry.get("progress"), "credits_consumed": entry.get("credits_consumed"),
              "error": entry.get("error")}
    if entry.get("glb_path"):
        result["glb"] = {"path": entry["glb_path"], "bytes": entry.get("glb_bytes"),
                         "sha256": entry.get("glb_sha256")}
    return result


def command_dry_run(args):
    manifest = load_manifest()
    state = load_state(manifest)
    check_fingerprints(manifest, state)
    save_state(state)
    jobs = []
    for house in manifest["houses"]:
        jobs.append({"house_id": house["id"], "name_zh": house.get("name_zh", ""),
                     "prompt_sha256": sha256_text(house["prompt"]), "prompt_chars": len(house["prompt"]),
                     "fingerprint": fingerprint(manifest, house), "request": job_request(manifest, house)})
    plan = {"trial_id": manifest["trial_id"], "generated_at_utc": now_utc(), "jobs": jobs,
            "planned_credits": manifest["expected_credits_per_house"] * len(jobs),
            "maximum_creations": manifest["maximum_creations"], "provider_calls": 0,
            "note": "offline plan only; no key was read and no network request was made"}
    atomic_write(TMP_DIR / "jobs-plan.json", json.dumps(plan, indent=2, ensure_ascii=False))
    print(json.dumps({"command": "dry-run", "jobs": len(jobs), "planned_credits": plan["planned_credits"],
                      "maximum_creations": plan["maximum_creations"], "model": manifest["model"],
                      "settings": manifest["settings"],
                      "houses": [{"id": job["house_id"], "name_zh": job["name_zh"],
                                  "prompt_chars": job["prompt_chars"], "prompt_sha256": job["prompt_sha256"],
                                  "fingerprint": job["fingerprint"]} for job in jobs],
                      "plan_path": "tmp/tripo-houses-20260916/jobs-plan.json",
                      "key_read": False, "network_calls": 0}, indent=2, ensure_ascii=False))
    return 0


def command_status(args):
    manifest = load_manifest()
    state = load_state(manifest)
    houses = [house_public(state["houses"][house["id"]]) for house in manifest["houses"]]
    print(json.dumps({"command": "status", "trial_id": manifest["trial_id"],
                      "post_attempts_total": sum(house.get("post_attempts", 0) for house in houses),
                      "houses": houses, "key_read": False, "network_calls": 0}, indent=2, ensure_ascii=False))
    return 0


def planned_remaining(manifest, state):
    missing = [house["id"] for house in manifest["houses"] if not state["houses"][house["id"]].get("task_id")]
    return len(missing), missing, len(missing) * manifest["expected_credits_per_house"]


def command_balance(args):
    manifest = load_manifest()
    key = resolve_key(args)
    transport = args.transport_factory(manifest["base_url"], key)
    payload = transport.get_json("/account/balance")
    data = payload.get("data") or {}
    missing, missing_ids, planned = planned_remaining(manifest, load_state(manifest))
    affordable = data.get("balance") is not None and float(data["balance"]) >= planned
    print(json.dumps({"command": "balance", "balance": data.get("balance"), "frozen": data.get("frozen"),
                      "planned_remaining_credits": planned, "houses_without_task": missing_ids,
                      "affordable": affordable, "network_calls": 1, "key_read": True},
                     indent=2, ensure_ascii=False))
    return 0


def command_submit(args):
    manifest = load_manifest()
    state = load_state(manifest)
    check_fingerprints(manifest, state)
    save_state(state)
    selected = args.house or [house["id"] for house in manifest["houses"]]
    key = resolve_key(args)
    transport = args.transport_factory(manifest["base_url"], key)
    payload = transport.get_json("/account/balance")
    balance = payload.get("data") or {}
    missing, missing_ids, planned = planned_remaining(manifest, state)
    if balance.get("balance") is not None and float(balance["balance"]) < planned:
        save_state(state)
        print(json.dumps({"command": "submit", "result": "stopped_insufficient_balance",
                          "balance": balance.get("balance"), "planned_remaining_credits": planned,
                          "houses_without_task": missing_ids, "post_attempts_this_run": 0,
                          "key_read": True, "network_calls": 1}, indent=2, ensure_ascii=False))
        return 4
    results = []
    for house_id in selected:
        entry = state["houses"][house_id]
        if entry.get("task_id"):
            results.append({"id": house_id, "action": "kept_existing_task", "task_id": entry["task_id"]})
            continue
        if int(entry.get("post_attempts", 0)) >= 1:
            results.append({"id": house_id, "action": "refused_repeat_post",
                            "reason": "a POST was already attempted for this house; never retried"})
            continue
        entry["post_attempts"] = int(entry.get("post_attempts", 0)) + 1
        entry["post_attempted_at_utc"] = now_utc()
        entry["state"] = "post_attempted"
        save_state(state)  # durable before the request leaves the process
        try:
            response = transport.post_json("/generation/text-to-model", job_request(manifest, house_by_id(manifest, house_id)))
        except TripoError as error:
            entry["state"] = "uncertain"
            entry["error"] = error.public([key])
            save_state(state)
            results.append({"id": house_id, "action": "post_failed_no_retry", "error": entry["error"]})
            continue
        task_id = str((response.get("data") or {}).get("task_id") or "")
        atomic_write(RAW_DIR / house_id / "post-response.json", json.dumps(response, indent=2, ensure_ascii=False))
        if not task_id:
            entry["state"] = "uncertain"
            entry["error"] = {"error_class": "missing_task_id", "message": "provider code 0 without task_id"}
            save_state(state)
            results.append({"id": house_id, "action": "post_ambiguous_no_retry", "error": entry["error"]})
            continue
        entry["task_id"] = task_id
        entry["state"] = "submitted"
        entry["status"] = "queued"
        entry["error"] = None
        save_state(state)  # never lose a successful creation
        results.append({"id": house_id, "action": "submitted", "task_id": task_id})
    posted = sum(1 for item in results if item["action"] in ("submitted", "post_failed_no_retry", "post_ambiguous_no_retry"))
    print(json.dumps({"command": "submit", "balance": balance.get("balance"),
                      "planned_remaining_credits": planned, "results": results,
                      "post_attempts_this_run": posted, "key_read": True},
                     indent=2, ensure_ascii=False))
    return 0


def refresh_task(state, entry, transport):
    task_id = entry["task_id"]
    payload = transport.get_json("/tasks/" + urllib.parse.quote(task_id, safe=""))
    atomic_write(RAW_DIR / entry["id"] / ("task-%s.json" % datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")),
                 json.dumps(payload, indent=2, ensure_ascii=False))
    data = payload.get("data") or {}
    entry["status"] = data.get("status") or entry.get("status")
    entry["progress"] = data.get("progress")
    entry["credits_consumed"] = data.get("credits_consumed")
    entry["last_polled_at_utc"] = now_utc()
    output = data.get("output") or {}
    entry["model_url"] = output.get("model_url")
    entry["rendered_image_url"] = output.get("rendered_image_url")
    if entry["status"] == "success":
        entry["state"] = "success"
    elif entry["status"] in TERMINAL:
        entry["state"] = entry["status"]
    else:
        entry["state"] = "submitted"
    return entry


def download_house(entry, transport, key):
    if entry.get("state") != "success" or not entry.get("model_url"):
        return {"id": entry["id"], "action": "skipped", "reason": "no successful model_url"}
    destination = MODEL_DIR / (entry["id"] + ".glb")
    if destination.exists():
        existing = validate_glb(destination)
        if existing["ok"]:
            entry["glb_path"] = str(destination.relative_to(ROOT)).replace("\\", "/")
            entry["glb_bytes"] = existing["bytes"]
            entry["glb_sha256"] = sha256_file(destination)
            return {"id": entry["id"], "action": "kept_existing_file", "bytes": existing["bytes"],
                    "sha256": entry["glb_sha256"]}
    try:
        validation = transport.download(entry["model_url"], destination)
    except TripoError as error:
        entry["error"] = error.public([key])
        return {"id": entry["id"], "action": "download_failed", "error": entry["error"]}
    entry["glb_path"] = str(destination.relative_to(ROOT)).replace("\\", "/")
    entry["glb_bytes"] = validation["bytes"]
    entry["glb_sha256"] = sha256_file(destination)
    entry["error"] = None
    return {"id": entry["id"], "action": "downloaded", "bytes": validation["bytes"],
            "sha256": entry["glb_sha256"], "glb_header_ok": True}


def _poll_loop(args, download):
    manifest = load_manifest()
    state = load_state(manifest)
    check_fingerprints(manifest, state)
    save_state(state)
    selected = args.house or [house["id"] for house in manifest["houses"]]
    pending = [state["houses"][house_id] for house_id in selected
               if state["houses"][house_id].get("task_id")
               and state["houses"][house_id].get("state") not in TERMINAL]
    if not pending:
        print(json.dumps({"command": args.command,
                          "results": [{"id": house_id, "action": "no_known_open_task"} for house_id in selected],
                          "network_calls": 0, "key_read": False,
                          "note": "nothing to poll; no POST was made and no new task was created"},
                         indent=2, ensure_ascii=False))
        return 0
    key = resolve_key(args)
    transport = args.transport_factory(manifest["base_url"], key)
    deadline = time.monotonic() + float(args.deadline)
    results = []
    network_calls = 0
    attempt = 0
    while pending and time.monotonic() < deadline:
        for entry in list(pending):
            try:
                refresh_task(state, entry, transport)
                network_calls += 1
            except TripoError as error:
                entry["error"] = error.public([key])
                save_state(state)
                results.append({"id": entry["id"], "action": "poll_failed_kept_task", "error": entry["error"]})
                continue
            if entry["state"] in TERMINAL:
                pending.remove(entry)
                results.append({"id": entry["id"], "action": "terminal", "status": entry["status"],
                                "credits_consumed": entry.get("credits_consumed")})
                if download and entry["state"] == "success":
                    results.append(download_house(entry, transport, key))
            save_state(state)
        if pending and time.monotonic() < deadline:
            time.sleep(BACKOFFS[min(attempt, len(BACKOFFS) - 1)])
            attempt += 1
    save_state(state)
    print(json.dumps({"command": args.command, "results": results, "network_calls": network_calls,
                      "still_open": [{"id": entry["id"], "task_id": entry["task_id"], "status": entry["status"]}
                                     for entry in pending],
                      "deadline_seconds": args.deadline, "key_read": True,
                      "houses": [house_public(state["houses"][house["id"]]) for house in manifest["houses"]]},
                     indent=2, ensure_ascii=False))
    return 0 if not pending else 3


def command_download(args):
    manifest = load_manifest()
    state = load_state(manifest)
    check_fingerprints(manifest, state)
    selected = args.house or [house["id"] for house in manifest["houses"]]
    transport = None
    key = ""
    results = []
    for house_id in selected:
        entry = state["houses"][house_id]
        if entry.get("state") != "success":
            results.append({"id": house_id, "action": "skipped", "reason": "task is not successful"})
            continue
        if transport is None:
            key = resolve_key(args)
            transport = args.transport_factory(manifest["base_url"], key)
        results.append(download_house(entry, transport, key))
    save_state(state)
    print(json.dumps({"command": "download", "results": results, "key_read": bool(transport is not None),
                      "houses": [house_public(state["houses"][house["id"]]) for house in manifest["houses"]]},
                     indent=2, ensure_ascii=False))
    return 0


def build_parser():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("command", choices=["dry-run", "status", "balance", "submit", "poll", "download", "resume"])
    parser.add_argument("--house", action="append", default=None, help="restrict to a house id (repeatable)")
    parser.add_argument("--key-file", default=None, help="default: secrets/tripo-key.txt or TRIPO_API_KEY")
    parser.add_argument("--deadline", type=float, default=1200.0, help="whole polling deadline in seconds")
    parser.set_defaults(transport_factory=HttpTransport)
    return parser


def main(argv=None, transport_factory=None):
    args = build_parser().parse_args(argv)
    if transport_factory is not None:
        args.transport_factory = transport_factory
    commands = {"dry-run": command_dry_run, "status": command_status, "balance": command_balance,
                "submit": command_submit, "poll": _poll_loop_wrapper, "download": command_download,
                "resume": _poll_loop_wrapper}
    try:
        return commands[args.command](args)
    except TripoError as error:
        print(json.dumps({"command": args.command, "error": error.public(_ACTIVE_SECRETS)},
                         indent=2, ensure_ascii=False))
        return 5


def _poll_loop_wrapper(args):
    return _poll_loop(args, download=True)


if __name__ == "__main__":
    sys.exit(main())
