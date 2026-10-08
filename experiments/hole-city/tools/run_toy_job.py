"""Record one owned, bounded toy-map QA job without changing player data."""
import argparse
import hashlib
import json
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path
from release_web import unexpected_engine_errors, input_hashes


def now():
    return datetime.now(timezone.utc).isoformat()


def runtime_inputs(command):
    hashes = {name: sha for name, sha in input_hashes().items()
              if name.startswith(("fidelity/", "scripts/", "assets/", "Scenes/", "shaders/"))
              or name in ("project.godot", "export_presets.cfg")}
    if "--script" in command:
        script = command[command.index("--script") + 1]
        path = Path(script.removeprefix("res://")).resolve()
        hashes[str(path)] = hashlib.sha256(path.read_bytes()).hexdigest()
    return hashes


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence", required=True, type=Path)
    parser.add_argument("--timeout", type=float, default=180)
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command
    if command and command[0] == "--":
        command = command[1:]
    if not command:
        parser.error("Provide the exact owned command after --")
    evidence = args.evidence.resolve()
    evidence.mkdir(parents=True, exist_ok=False)
    receipt_path = evidence / "process.json"
    log_path = evidence / "engine.log"
    receipt = dict(command=command, cwd=str(Path.cwd()), started_at=now(),
                   timeout_seconds=args.timeout, status="starting")
    before = runtime_inputs(command)
    before_path = evidence / "runtime-inputs-before.json"
    before_path.write_text(json.dumps(before, indent=2, sort_keys=True) + "\n")
    receipt.update(runtime_input_count=len(before),
                   runtime_inputs_before_sha256=hashlib.sha256(before_path.read_bytes()).hexdigest())
    try:
        with log_path.open("w") as stream:
            process = subprocess.Popen(command, stdin=subprocess.DEVNULL,
                                       stdout=stream, stderr=subprocess.STDOUT)
            receipt.update(pid=process.pid, status="running")
            receipt_path.write_text(json.dumps(receipt, indent=2) + "\n")
            print("Owned QA PID:", process.pid, flush=True)
            deadline = time.monotonic() + args.timeout
            stopped_for_errors = False
            while process.poll() is None and time.monotonic() < deadline:
                if unexpected_engine_errors(log_path.read_text()):
                    stopped_for_errors = True
                    break
                time.sleep(.1)
            if process.poll() is not None:
                return_code = process.returncode
                receipt.update(status="completed", exit_code=return_code)
            else:
                # Terminate only this exact child, retaining partial evidence.
                process.terminate()
                try:
                    return_code = process.wait(timeout=8)
                except subprocess.TimeoutExpired:
                    process.kill()
                    return_code = process.wait()
                receipt.update(status="engine-errors" if stopped_for_errors else "timed-out", exit_code=return_code)
    finally:
        receipt["finished_at"] = now()
        if log_path.exists():
            receipt["log_sha256"] = hashlib.sha256(log_path.read_bytes()).hexdigest()
            receipt["engine_errors"] = unexpected_engine_errors(log_path.read_text())
        after = runtime_inputs(command)
        after_path = evidence / "runtime-inputs-after.json"
        after_path.write_text(json.dumps(after, indent=2, sort_keys=True) + "\n")
        receipt["runtime_inputs_unchanged"] = before == after
        receipt["runtime_inputs_after_sha256"] = hashlib.sha256(after_path.read_bytes()).hexdigest()
        if before != after:
            receipt["status"] = "runtime-inputs-changed"
        receipt_path.write_text(json.dumps(receipt, indent=2) + "\n")
    print(json.dumps(receipt), flush=True)
    if receipt.get("engine_errors") or not receipt.get("runtime_inputs_unchanged"):
        raise SystemExit(return_code if return_code else 1)
    raise SystemExit(return_code if receipt["status"] == "completed" else 124)


if __name__ == "__main__":
    main()
