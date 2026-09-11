# InfiniteAincrad

合并来源可用性：[跨机器合并验证报告](docs/validation/cross_machine_2026-09-12.md)

A persistent AI world inspired by Sword Art Online. Residents retain their identities, experiences and commitments as the models behind them change.

2026-09-11生活验证：同一个三人测试档已完成真实Kimi修理、付款、取回、工具使用及冷启动续接；一次居民顾虑已推动新结算能力的开发和实际使用。过程有明确标记的玩家澄清，原镇主档和正式人物美术仍未恢复。[结果与限制](docs/validation/town_continuous_life_2026-09-11.md) · [唯一全景进度图](ROADMAP.md)。

Maintained by [dotafs2](https://github.com/dotafs2). Project name: **InfiniteAincrad**.

**2026-09-10 transfer:** [New-computer setup, art sources and same-world continuation](docs/CONTINUE_ON_ANOTHER_PC.md). Current real-model evidence now includes two separate resident knowledge states; see [current progress](docs/STATUS.md). Normal launches remain offline unless explicitly configured otherwise.

**Status: a runnable Godot 3D street trial.** Walk through the reused market, approach a resident at the well and help with rope and a bucket. The resident physically draws and drinks water; facts continue after reopening. This is an explicitly offline fixture with temporary character/prop art, not a live-model or migrated-world release. [Verified result](docs/validation/street_rebuild_2026-09-10.md).

## 第一个可玩的作品

当前井边包只算内部技术预览。第一版目标已提高为完整首镇：保留原世界的 13 个身份，先在 Godot 恢复三名活跃居民的生活能力，再达到 5–10 人的食物、劳动与交换循环，完善人物、美术、玩家介入和模型更换后的连续生活。

已经加入原存档的独立迁移验证入口：`./Run-Street.ps1 -Town -SavePath <迁移输出/world.json>`。三人可进食、休息、到公共浆果地采集；新选择明确使用离线规则。先按 [迁移说明](docs/MIGRATION.md) 生成私有副本。启动暂停，空格继续；这仍不是完整迁移或第一版。

城镇端也已加入修刃委托的 Godot 规则和可见流程：靠近斧子主人按 R，可经过接单预留、当面交付、60 秒修理、耗铁、取回和付款；H 仍用于近距离询问。该流程已在三人离线 fixture 中验证并冷恢复，尚未在这台电脑缺失的 13 人私有存档上重放，详见 [修理验收](docs/validation/repair_work_2026-09-11.md)。

第一层美术新增一套原创 Blender 英雄街角：双塔城门、木石商屋、锻造铺、契约告示板、灯具、货车和 12 米可行走街道。Godot 已实际导入并验证碰撞与门洞；这是一块可编辑的质量/风格样板，不是“无限城市”完成声明，也不含复制的动画场景或旧工程受限人物。详见 [美术验收](docs/validation/floor1_art_2026-09-11.md)。

第一批 20 件环境组件已按新的近景要求全部重制为 V2：独立分枝和弯曲叶片、六类植物、顶点权重风动、三档 LOD、可直接拖入 Godot 的组件场景。默认井边 demo 与城镇模式的 8 个装饰实例已替换，其中 7 个具有局部植物风动；新隔离存档的原有井边流程检查通过。提供 Blender 源、6 秒实录和近景，详见 [V2 美术与接入验收](docs/validation/floor1_environment_v2_2026-09-11.md)。

第一层另新增 5 种原创住宅外观：庭院宅、窄三层宅、L 形花院宅、长廊宅和转角宅。包含高精度 Blender 源、四套 2K PBR 材质、双 UV、三档 LOD 与独立 Godot 组件；在 `game/scenes/floor1_residences_review.tscn` 查看。该批是外观资产，不含可进入的精装室内或居民住房逻辑，详见 [住宅图集与验收](docs/validation/floor1_residences_2026-09-11.md)。

唯一长期目标：建立能进入、能影响、能长期延续的AI世界。模型升级增强同一批居民的生活，已经发生的事情不会随模型更换消失。

2026-09-11：新增 Godot 修理、交付、结算与工具使用。真实 Kimi 在明确的三人测试世界完成一笔 2 Col 修斧柄交易并冷启动保持；完整双部件修理/使用仅脚本验收通过，尚未证明原镇自主闭环。原镇最新私有存档未随 Git 同步到本机。[本轮报告与实机画面](docs/validation/town_trade_2026-09-11.md)。

## Current repository

| Path | Purpose |
| --- | --- |
| [game/](game/project.godot) | Godot 4 walkable 3D street trial; isolated fixture |
| [ROADMAP.md](ROADMAP.md) | One MVP, sequential acceptance gates and stop limits |
| [docs/MIGRATION.md](docs/MIGRATION.md) | What may move from the experiment, and how continuity is verified |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Single-engine direction and boundaries for world rules and model adapters |
| [docs/STATUS.md](docs/STATUS.md) | Implemented, missing and blocked work |

## Run the 3D street

A local Windows technical preview can now be built with `./Build-WindowsPreview.ps1 -Godot C:/path/to/Godot.exe`.
The complete ZIP runs without an editor, SDK or API key. See [build and verification instructions](docs/release/WINDOWS_PREVIEW.md).
The local package has passed offline event and cold-restore checks; external first-time testers and the [license scope](docs/release/RIGHTS_REVIEW.md) are still pending.

Open `game/project.godot` in Godot 4.7.2 .NET and build/run the default scene, or run `./Run-Street.ps1 -Godot C:/path/to/Godot.exe`. The launcher builds the C# adapter and imports the market before launching; it requires .NET SDK 8 or newer. It also accepts `GODOT_EXE` or an installed `godot` command. Fetch Git LFS assets when cloning. `-SkipBuild` assumes compilation and imports are already current.

WASD moves; click to capture the mouse, Escape releases it. Walk close to the well and press E after the resident asks for help. F8 toggles diagnostic text. The normal scene keeps its separate `user://street-trial/world.json` fixture save; reopen to continue. Damaged saves display an error rather than resetting.

The market is the existing authored V5 environment. The one resident uses primitive temporary geometry and a labeled offline observation provider running through the MIT OpenGameAgent runtime; no Kimi request is made. Player help passes through the existing need/GM approval/install checks. The old 2D panel remains available as `game/scenes/bootstrap.tscn` for internal tests. See [reused MIT foundations and module boundaries](docs/MIT_PLUGIN_BASE.md).

## Contributing

Start with [CONTRIBUTING.md](CONTRIBUTING.md) and the [current delivery gate](ROADMAP.md). The immediate contribution is independently reproducing or testing the Windows preview. Nearby source-attributed inquiry is now present in the town fixture; the next bounded gameplay work is the remaining source-defined handle repair, repaired-tool use and material exchange, followed by the accounted 5–10-resident food/labor loop.

This is an independent fan-inspired project, not an official SAO product. The initial repository contains newly written scaffolding and planning documents; no third-party character models, animation screenshots or private save data. Reuse and asset licensing status is recorded in [ASSET_POLICY.md](ASSET_POLICY.md). A public repository does not by itself grant a general reuse license; the project-wide license has not yet been selected.

Previous experiment: [dotafs2/vibeGamingDemo1](https://github.com/dotafs2/vibeGamingDemo1). Its history remains there; this project starts with its own Git history.
