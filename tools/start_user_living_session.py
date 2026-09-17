"""Interactive, fail-closed bootstrap for one new paid resident-life session.

This entry point is intentionally manual. It has no confirmation flag and is not used
by the overnight runner. A new payment record is created only after the user types the
exact confirmation in an interactive terminal and all earlier records plus the world
writer boundary have been checked.
"""

from datetime import datetime, timedelta, timezone
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools/kimi"))
from kimi_budget import BudgetError, CityValidationPolicy, Ledger, NANO, Policy
from kimi_gateway import KimiProvider


SESSION_SECONDS = 900
MAX_NEW_DECISIONS = 32
CONCURRENCY = 1
AUTHORIZED_NANO = 3 * NANO
ALLOCATABLE_NANO = 2_850_000_000
WINDOW_SECONDS = 1020
# The existing runner adds a fixed 55-second process/drain margin to its own runtime
# authorization. 900 + 65 + 55 = the approved 1020-second window exactly. The 65
# seconds admit no new decisions; they only let an already-started reply settle and save.
SHUTDOWN_WAIT_SECONDS = 65
CONFIRMATION = "START AI"
REQUIRED_PROFILE_KEYS = {
    "save_path", "godot", "config", "sessions_root", "prior_paid_session_records"
}
OPTIONAL_PROFILE_KEYS = {"gm_status"}


class LaunchBlocked(RuntimeError):
    pass


def _read_json(path):
    try:
        return json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise LaunchBlocked(f"配置无法读取：{path}") from exc


def _resolve(value):
    path = Path(value)
    return path.resolve() if path.is_absolute() else (ROOT / path).resolve()


def load_profile(path):
    data = _read_json(path)
    keys = set(data) if isinstance(data, dict) else set()
    if (not isinstance(data, dict) or not REQUIRED_PROFILE_KEYS.issubset(keys)
            or keys - REQUIRED_PROFILE_KEYS - OPTIONAL_PROFILE_KEYS):
        raise LaunchBlocked("本机配置字段不完整或包含未知字段；请重新从示例复制。")
    records = data["prior_paid_session_records"]
    if not isinstance(records, list) or not records or any(not isinstance(item, str) or not item.strip() for item in records):
        raise LaunchBlocked("必须列出需要核对的既有付费会话记录。")
    for key in ("save_path", "godot", "config", "sessions_root"):
        if not isinstance(data[key], str) or not data[key].strip():
            raise LaunchBlocked(f"本机配置 {key} 必须是非空路径。")
    result = {key: _resolve(data[key]) for key in ("save_path", "godot", "config", "sessions_root")}
    result["prior_paid_session_records"] = [_resolve(item) for item in records]
    if "gm_status" in data:
        if not isinstance(data["gm_status"], str) or not data["gm_status"].strip():
            raise LaunchBlocked("本机配置 gm_status 必须是非空路径。")
        result["gm_status"] = _resolve(data["gm_status"])
    return result


def _policy_from_guard(record):
    guard_path = record.with_suffix(".guard.json")
    if not record.is_file() or not guard_path.is_file():
        raise LaunchBlocked("既有付费会话记录缺少配对文件；为避免重复计费，已拒绝启动。")
    guard = _read_json(guard_path)
    try:
        values = guard["policy"]
        policy_type = CityValidationPolicy if "request_limit" in values else Policy
        return policy_type(**values)
    except (KeyError, TypeError) as exc:
        raise LaunchBlocked("既有付费会话记录格式未知；为避免重复计费，已拒绝启动。") from exc


def audit_paid_record(record):
    try:
        session = Ledger(record, _policy_from_guard(record))
        status = session.status()
    except (BudgetError, OSError, ValueError, KeyError, TypeError) as exc:
        raise LaunchBlocked("既有付费会话记录无法完整核对；为避免重复计费，已拒绝启动。") from exc
    counts = status.get("counts", {})
    if status.get("halted"):
        raise LaunchBlocked("既有付费会话处于停止状态；请先人工核对，未创建新会话。")
    if counts.get("reserved", 0) or counts.get("uncertain", 0):
        raise LaunchBlocked("既有付费会话仍有进行中或结果未知的请求；未创建新会话。")
    return {
        "record": str(record),
        "id": status["ledger_id"],
        "settled_cny": status["settled_cny"],
        "requests": sum(counts.values()),
    }


def _record_for_guard(guard):
    stem = guard.name[:-len(".guard.json")]
    return guard.with_name(stem + ".sqlite3")


def discover_session_records(sessions_root):
    if not sessions_root.exists():
        return []
    if not sessions_root.is_dir():
        raise LaunchBlocked("新会话目录不是文件夹；已拒绝启动。")
    for session_dir in sessions_root.glob("session-*"):
        if (not session_dir.is_dir()
                or not (session_dir / "kimi-user-session.sqlite3").is_file()
                or not (session_dir / "kimi-user-session.guard.json").is_file()):
            raise LaunchBlocked("历史会话目录存在未完成或未配对记录；已拒绝启动。")
    records = set(sessions_root.rglob("*.sqlite3"))
    guards = set(sessions_root.rglob("*.guard.json"))
    for record in records:
        if not record.with_suffix(".guard.json").is_file():
            raise LaunchBlocked("历史会话目录存在未配对记录；已拒绝启动。")
    for guard in guards:
        if not _record_for_guard(guard).is_file():
            raise LaunchBlocked("历史会话目录存在未配对记录；已拒绝启动。")
    return sorted(records)


def audit_all(profile):
    records = set(profile["prior_paid_session_records"])
    records.update(discover_session_records(profile["sessions_root"]))
    return [audit_paid_record(record) for record in sorted(records)]


def _require_file(path, label):
    if not path.is_file():
        raise LaunchBlocked(f"{label}不存在：{path}")


def validate_local_inputs(profile):
    _require_file(profile["save_path"], "世界存档")
    _require_file(profile["godot"], "Godot")
    _require_file(profile["config"], "AI 配置")
    game = (ROOT / "game").resolve()
    for path in (profile["save_path"], profile["sessions_root"]):
        if path == game or game in path.parents:
            raise LaunchBlocked("私有世界与会话记录不能放在可导出的游戏目录中。")
    config = _read_json(profile["config"])
    if not isinstance(config, dict):
        raise LaunchBlocked("AI 配置格式无效。")
    try:
        KimiProvider(config)
    except BudgetError as exc:
        raise LaunchBlocked("AI 配置未通过现有服务与模型边界核对。") from exc


def _writer_lock(save):
    return Path(str(save) + ".writer-lock")


def ensure_world_idle(save):
    if _writer_lock(save).exists():
        raise LaunchBlocked("世界正在由另一个进程写入；未创建新付费会话。请先正常结束当前生活运行。")


def new_policy(deadline_utc):
    # Prices and per-request ceilings match the reviewed overnight Kimi authorization.
    return CityValidationPolicy(
        authorized_nano=AUTHORIZED_NANO,
        allocatable_nano=ALLOCATABLE_NANO,
        prior_unverified_nano=0,
        input_nano_per_token=6500,
        cached_nano_per_token=1100,
        output_nano_per_token=27000,
        input_ceiling=32768,
        max_output=512,
        max_request_bytes=32768,
        max_context_utf8_bytes=24576,
        concurrency=CONCURRENCY,
        deadline_utc=deadline_utc,
        price_verified="2026-09-18 https://platform.kimi.com/ K2.6 China",
        request_limit=MAX_NEW_DECISIONS,
    )


def _write_json(path, value):
    temporary = path.with_name(path.name + ".tmp")
    with temporary.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, ensure_ascii=False, indent=2, sort_keys=True)
        handle.write("\n")
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(temporary, path)


def _session_directory(sessions_root, now):
    base = now.strftime("session-%Y%m%d-%H%M%S-%fZ")
    path = sessions_root / base
    path.mkdir(exist_ok=False)
    return path


def _runner_command(profile, record, output):
    command = [
        sys.executable, "-X", "utf8", str(ROOT / "tools/run_town_model_validation.py"),
        "--godot", str(profile["godot"]),
        "--ledger", str(record),
        "--config", str(profile["config"]),
        "--save", str(profile["save_path"]),
        "--out", str(output),
        "--seconds", str(SESSION_SECONDS),
        "--max-requests", str(MAX_NEW_DECISIONS),
        "--concurrency", str(CONCURRENCY),
        "--shutdown-wait", str(SHUTDOWN_WAIT_SECONDS),
    ]
    if "gm_status" in profile:
        command += ["--gm-status", str(profile["gm_status"])]
    return command


def _say(stream, message=""):
    print(message, file=stream, flush=True)


def launch(profile_path, input_stream=sys.stdin, output_stream=sys.stdout,
           run_process=subprocess.run, now_fn=None):
    profile = load_profile(profile_path)
    _say(output_stream, "启动真实 AI 生活（一次新会话）")
    _say(output_stream, "生活运行：900 秒；最多 32 个新决定；同时处理 1 个请求。")
    _say(output_stream, "900 秒后停止接收新决定，并给已开始的回复最多 65 秒收尾和保存。")
    _say(output_stream, "按当前公布单价控制的本次预算上限：3.00 元；可用于请求：2.85 元。时间或费用先到即停止。")
    _say(output_stream, "运行后显示的是按回复用量计算的本地费用估算；最终费用以供应商账单为准。")
    _say(output_stream, "这不会补充、重置或延长任何既有会话。")
    _say(output_stream, f"若确认，请在交互式窗口准确输入：{CONFIRMATION}")
    if not input_stream.isatty():
        raise LaunchBlocked("必须在交互式终端中手动确认；管道或自动任务不能启动真实 AI。")
    answer = input_stream.readline().rstrip("\r\n")
    if answer != CONFIRMATION:
        _say(output_stream, "已取消；没有创建新付费会话，也没有启动真实 AI。")
        return 0

    validate_local_inputs(profile)
    prior = audit_all(profile)
    ensure_world_idle(profile["save_path"])

    sessions_root = profile["sessions_root"]
    sessions_root.mkdir(parents=True, exist_ok=True)
    bootstrap_lock = sessions_root / ".start-living-ai.lock"
    try:
        bootstrap_lock.mkdir()
    except FileExistsError as exc:
        raise LaunchBlocked("另一个真实 AI 启动流程仍在进行；未创建新会话。") from exc

    try:
        # Re-check after owning the bootstrap boundary. Another manual bootstrap cannot
        # pass this point, and an already-running world is still rejected before first use.
        prior = audit_all(profile)
        ensure_world_idle(profile["save_path"])
        now = now_fn() if now_fn else datetime.now(timezone.utc)
        if now.tzinfo is None:
            now = now.replace(tzinfo=timezone.utc)
        now = now.astimezone(timezone.utc)
        deadline = now + timedelta(seconds=WINDOW_SECONDS)
        session_dir = _session_directory(sessions_root, now)
        record = session_dir / "kimi-user-session.sqlite3"
        session = Ledger(record, new_policy(int(deadline.timestamp())))
        status = session.initialize()
        manifest_path = session_dir / "session.json"
        manifest = {
            "schema_version": 1,
            "status": "starting",
            "created_at_utc": now.isoformat(),
            "deadline_utc": deadline.isoformat(),
            "limits": {
                "seconds": SESSION_SECONDS,
                "max_new_decisions": MAX_NEW_DECISIONS,
                "concurrency": CONCURRENCY,
                "authorized_cny": AUTHORIZED_NANO / NANO,
                "allocatable_cny": ALLOCATABLE_NANO / NANO,
            },
            "prior_paid_sessions": prior,
            "cumulative_settled_before_cny": round(sum(item["settled_cny"] for item in prior), 9),
            "current": {"id": status["ledger_id"], "settled_cny": 0.0, "requests": 0},
        }
        _write_json(manifest_path, manifest)
        _say(output_stream, "核对通过。正在打开十位居民的真实 AI 生活……")
        try:
            result = run_process(_runner_command(profile, record, session_dir / "run"), cwd=ROOT)
            return_code = int(result.returncode)
            final = session.status()
            manifest["status"] = "complete" if return_code == 0 else "runner_failed"
            manifest["runner_exit_code"] = return_code
            manifest["current"] = {
                "id": final["ledger_id"],
                "settled_cny": final["settled_cny"],
                "requests": sum(final.get("counts", {}).values()),
                "in_progress": final.get("counts", {}).get("reserved", 0),
                "unknown": final.get("counts", {}).get("uncertain", 0),
                "stopped": bool(final.get("halted")),
            }
            manifest["cumulative_settled_after_cny"] = round(
                manifest["cumulative_settled_before_cny"] + final["settled_cny"], 9)
            _write_json(manifest_path, manifest)
        except Exception:
            manifest["status"] = "bootstrap_error"
            _write_json(manifest_path, manifest)
            raise
        _say(output_stream, "本次新请求：%d；本地费用估算：%.6f 元（以供应商账单为准）。" % (
            manifest["current"]["requests"], manifest["current"]["settled_cny"]))
        if return_code == 0:
            _say(output_stream, "本次真实 AI 生活已正常结束，记录已保存。")
        else:
            _say(output_stream, "本次运行未正常结束；记录保留且不会自动重试。请先人工核对。")
        return return_code
    finally:
        bootstrap_lock.rmdir()


def main(argv=None):
    parser = argparse.ArgumentParser(description="手动启动一次有明确时间与费用上限的真实 AI 生活。")
    parser.add_argument(
        "--profile", type=Path,
        default=ROOT / "private/night-delivery/start-living-ai.local.json",
        help="本机路径配置（默认使用 private/night-delivery/start-living-ai.local.json）",
    )
    args = parser.parse_args(argv)
    try:
        return launch(args.profile.resolve())
    except LaunchBlocked as exc:
        print(f"无法启动：{exc}", file=sys.stderr)
        return 2
    except (BudgetError, OSError, ValueError) as exc:
        print("无法启动：付费会话初始化或运行失败；不会自动重试。请人工核对私有记录。", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
