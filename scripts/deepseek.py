"""Run one GPT-6-scoped implementation task with DeepSeek through Codex CLI."""

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tomllib
from urllib.error import HTTPError, URLError
from urllib.request import HTTPRedirectHandler, Request, build_opener

ROOT = Path(__file__).resolve().parents[1]
PROFILE = "infiniteaincrad-deepseek"
MODEL = "deepseek-flash"


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument("--check", action="store_true", help="check key and model access; no inference")
    modes.add_argument("--task-file", type=Path, help="UTF-8 file containing one authorized task")
    parser.add_argument("--timeout-seconds", type=int, default=600)
    parser.add_argument("--workdir", type=Path, default=None,
                        help="existing directory the worker runs in; defaults to the repository root")
    parser.add_argument("--reasoning-effort", choices=("low", "medium", "high"), default=None,
                        help="optional codex exec model_reasoning_effort override; omitted keeps the profile value")
    args = parser.parse_args()
    if not 1 <= args.timeout_seconds <= 3600:
        parser.error("timeout must be between 1 and 3600 seconds")
    workdir = ROOT if args.workdir is None else args.workdir.resolve()
    if not workdir.is_dir():
        parser.error(f"--workdir is not an existing directory: {workdir}")

    codex = shutil.which("codex")
    if not codex:
        raise ValueError("Codex CLI is not on PATH.")
    config_dir = Path(os.environ.get("CODEX_HOME") or Path.home() / ".codex")
    profile = tomllib.loads((config_dir / f"{PROFILE}.config.toml").read_text(encoding="utf-8-sig"))
    provider = profile["model_providers"][profile["model_provider"]]
    if (profile["model"] != MODEL or provider["base_url"] != "https://api.deepseek.com"
            or provider["env_key"] != "DEEPSEEK_API_KEY"):
        raise ValueError("Profile differs from the configured DeepSeek V4.1 Flash connection.")
    key = (ROOT / "private/deepseek-api-key.txt").read_text(encoding="utf-8-sig").strip()
    if not re.fullmatch(r"sk-[A-Za-z0-9_-]{16,200}", key):
        raise ValueError("The private TXT must contain only the DeepSeek API key.")

    if args.check:
        request = Request("https://api.deepseek.com/models", headers={"Authorization": f"Bearer {key}"})
        try:
            with build_opener(NoRedirect()).open(request, timeout=25) as response:
                models = [item["id"] for item in json.load(response)["data"]]
        except HTTPError as error:
            raise ValueError(f"DeepSeek authentication check failed: HTTP {error.code}.") from None
        except (URLError, TimeoutError):
            raise ValueError("DeepSeek authentication check failed: connection or timeout error.") from None
        if MODEL not in models:
            raise ValueError("Key accepted, but deepseek-flash is not in the account model list.")
        print(json.dumps({"authentication": "passed", "model": MODEL, "inference_requests": 0}))
        return 0

    task_path = args.task_file.resolve()
    if task_path.stat().st_size > 65536:
        raise ValueError("Task exceeds 64 KiB; supply a bounded task, not full conversation history.")
    task = task_path.read_text(encoding="utf-8-sig").strip()
    if not task or key in task:
        raise ValueError("Task must be nonempty and must not contain the API key.")
    run_dir = ROOT / "private/deepseek-runs" / datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    run_dir.mkdir(parents=True)
    environment = os.environ.copy()
    environment["DEEPSEEK_API_KEY"] = key
    command = [codex, "exec", "--profile", PROFILE, "--cd", str(workdir), "--json",
               "--color", "never", "--output-last-message", str(run_dir / "result.md")]
    if args.reasoning_effort:
        command += ["-c", f"model_reasoning_effort={args.reasoning_effort}"]
    command.append("-")
    with (run_dir / "events.jsonl").open("wb") as events, (run_dir / "stderr.log").open("wb") as errors:
        process = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=events, stderr=errors,
                                   cwd=workdir, env=environment, creationflags=subprocess.CREATE_NO_WINDOW)
        (run_dir / "process.json").write_text(json.dumps({"pid": process.pid, "model": MODEL}), encoding="utf-8")
        print(f"DeepSeek PID {process.pid}; result and usage events: {run_dir}", flush=True)
        try:
            process.communicate(task.encode("utf-8"), timeout=args.timeout_seconds)
        except (subprocess.TimeoutExpired, KeyboardInterrupt):
            subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
            process.wait(timeout=15)
            print("Worker stopped. Inspect private logs and reconcile usage before another dispatch.")
            return 1
    print(f"Worker exited {process.returncode}. GPT-6 must review the diff, checks and usage before continuing.")
    return process.returncode


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError):
        # Do not echo server bodies, local file contents, or credential-bearing exceptions.
        print("DeepSeek setup/run failed. Check key format, local profile, task path and connectivity.", file=sys.stderr)
        sys.exit(1)
