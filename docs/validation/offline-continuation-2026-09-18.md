# 2026-09-18 本机离线续接

接收基线：`codex/overnight-20260918-delivery` / `9fcd05c`，仓库 `C:\InfiniteAincrad`。用户确认 seq450 私有世界、GM 状态和费用账本仍在另一台机器，要求先继续离线修复。本轮未创建付费会话、未调用 NPC/GM 模型，未更改食物参数或居民选择。

## 修复

`tools/play_pcg_trial.py` 原先只检查 `InfiniteAincrad.dll` 与 `.godot/imported` 是否存在。已有旧缓存时，即使拉取了新源码或新增资产也不会准备运行环境；缺少 SDK、构建失败、导入失败都可能因未执行准备而被绕过。

现每次先运行 MSBuild 增量构建，再运行 Godot 增量导入，由各自工具判断是否需要更新。构建加 `--disable-build-servers`；失败时在复制存档和打开窗口前停止。保留已有缓存，不清空整个工程。继续使用现有 Windows Job 管理自有进程，工具日志保留在私有启动目录。

`tools/test_play_pcg_trial.py` 四项回归覆盖已有旧缓存、构建失败、导入失败、缺少 SDK。对 Git 基线执行得到4失败/0错误，对修复执行得到4通过；失败分支均不得打开窗口或复制世界，源存档字节不变。

## 本机验证

| 检查 | 结果 |
| --- | --- |
| `test_play_pcg_trial.py` | 4通过 |
| `test_start_user_living_session.py` | 18通过 |
| `test_town_model_validation_budget.py` | 28通过 |
| `town_food_handoff_acceptance.gd` | 12通过 |
| `town_basic_needs_rule_acceptance.gd` | 3通过 |
| `town_shutdown_acceptance.gd` | 44通过 |
| `town_settled_reply_acceptance.gd` | 110通过 |
| `town_baking_route_acceptance.gd` | 63通过 |
| `town_life_acceptance.gd` | 43通过 |
| `town_restore_read_only_acceptance.gd` | 11通过，存档字节不变 |
| `town_controller_recovery_acceptance.gd` | 20通过，未复现H102记录的旧失败 |
| C#构建 | 0警告、0错误 |
| 实际 `StartDemo.cmd --prepare-only` | 构建和导入成功，已导入本次烘焙资产；未打开图形窗口 |
| 独立预览保存/冷恢复 | `DEMO_PREVIEW_STATE_OK residents=10 seq=0 cold_restore=true` |

合计50项Python和306项Godot检查；预览冷恢复单独列示，不计入306项。全部模型调用为0。Godot为本机缓存的4.7.2 .NET，Godot专项检查使用进程环境 `DOTNET_ROLL_FORWARD=LatestMajor`。实际 `StartDemo.cmd --prepare-only` 未另加该环境变量，本机也通过；不能据此保证其他运行时组合。

实际启动使用已有本机源档的暂停副本，输出位于 `private/pcg-trial-20260916/visit-20260918-124947-792756/`；没有把这份旧资料当作最新seq450。冷恢复另用 `private/offline-20260918/preview-genesis.json`，世界ID为 `shared:offline-preview-20260918`，以独立身份创建，避免与正式历史混记。

本机详细日志：`C:\InfiniteAincrad\private\offline-20260918\`，每个Godot套件有 `tool.log` 与记录PID/退出状态的 `process.json`；启动构建/导入日志在上面的实际启动目录。所有自有引擎和构建进程已结束。

## 尚未覆盖

- 没有接续seq450，未验证居民自然口粮赠予、长时资源分配或GM长期无人维护。
- 没有执行图形长跑，旧导航/粒子与退出渲染错误仍保留。
- 本机已有Terrain3D动态库，本次未补齐干净电脑自动下载固定依赖的能力。
- 本次为定向回归，不代表全仓历史套件全部通过。

下一次接续原世界前需私下带回世界快照、GM持久状态、费用账本及配套配置，核对上游seq450和哈希；本机离线预览不能替代这些资料。
