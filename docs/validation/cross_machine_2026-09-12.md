# 跨机器合并验证报告（2026-09-12）

本报告记录 Windows 玩法分支与 Mac 美术分支合并进 main 的验证事实。

## 合并来源

- 待合并 HEAD：`d3ba1e99868f14d06f4285708ed1477bf8db8390`（Mac 美术 + 已验收 house06）
- MERGE_HEAD：`e123706e2b14bda4f646f654d61ee98736ae292c`（Windows 规范玩法分支）
- 远端 main 上次提交：`336f0335f168a16351b535363012c0c5e9124743`
- 合并后路径并集 922 条，资产路径 457 条，LFS 指针 97 条经最终审计确认保全。
- 本报告仅记录合并后 main 的最终审计事实；美术资产保留不等于居民住房/室内玩法已接入。

## 已修复问题

- Windows JSON 桥退出崩溃已修复：新增显式释放方法，两次独立专测均正常退出（exit 0）。
- 92 项专测两次独立运行均通过 92 项断言后正常退出；此前两次复现仅在 92 项检查通过后崩溃。
- 完整 24 项功能套件与 3 项资产校验器在修复后全部通过。
- 网关 15 项回环用例全部通过。

## 场景验收

- 合并场景 52 项检查、0 失败；8 项环境装饰齐全；模型调用 0 次。
- 存档字节前后一致（world_save_byte_equal=true）。
- 真实 GPU 截图 2 张，尺寸均为 1400x900。
- 场景照片经 GPT-6 复核：截图中可见市场 3 名居民；8 项 Mac 装饰经装饰树逐项核验，并非全部在截图中单独可见。

## 未解决问题（视觉）

- 日照过曝导致浅色路面与墙面发白。
- 3D 标签相互重叠。
- 以上为真实遗留视觉问题，不构成完整首街验收。

## 限制

- 原始存档缺失，未恢复原镇。
- N3 未通过真实第二模型验证。
- N5 未完成。
- 模型路由为 GPT-6 复核 / DeepSeek 执行；费用为上限估算，非账单。

## 证据与图片

- [tests.json](cross_machine_2026-09-12/tests.json)
- [build.json](cross_machine_2026-09-12/build.json)
- [merge_scene.json](cross_machine_2026-09-12/merge_scene.json)
- [gateway.json](cross_machine_2026-09-12/gateway.json)
- [gateway-run.json](cross_machine_2026-09-12/gateway-run.json)
- [audit.json](cross_machine_2026-09-12/audit.json)
- [codec-lifetime-1.process.json](cross_machine_2026-09-12/codec-lifetime-1.process.json)
- [codec-lifetime-1.stdout.txt](cross_machine_2026-09-12/codec-lifetime-1.stdout.txt)
- [codec-lifetime-1.stderr.txt](cross_machine_2026-09-12/codec-lifetime-1.stderr.txt)
- [codec-lifetime-2.process.json](cross_machine_2026-09-12/codec-lifetime-2.process.json)
- [codec-lifetime-2.stdout.txt](cross_machine_2026-09-12/codec-lifetime-2.stdout.txt)
- [codec-lifetime-2.stderr.txt](cross_machine_2026-09-12/codec-lifetime-2.stderr.txt)
- [merge_overview.png](cross_machine_2026-09-12/merge_overview.png)
- [merge_residents.png](cross_machine_2026-09-12/merge_residents.png)

## 复现

复用现有工具 `tools/create_trade_fixture.py` 与 `tools/run_godot.py`；
先生成新的 fixture，再用本机 Godot 路径运行合并验收：

```
python tools/create_trade_fixture.py --output <newfixture.json>
python tools/run_godot.py --godot <Godot.NET.exe> --name merge --timeout 120 --out <logsdir> -- --headless --script res://tests/town_merge_acceptance.gd -- --town-save=<sameabsfixture> --merge-output=<outputjson>
```

`--timeout` 与 `120` 为两个独立 CLI 参数；`--town-save` 需与 fixture 使用同一绝对路径。

## 开发用量（聚合，已脱敏）

- 调用次数：18（含响应格式/完整性失败 5 次；所有调用含修订均计入总数）
- 输入 token：408564
- 输出 token：98196
- 费用上限估算（美元）：0.201192（非账单）
