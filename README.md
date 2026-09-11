# InfiniteAincrad

A persistent AI world inspired by Sword Art Online. Residents retain their identities, experiences and commitments as the models behind them change.

Maintained by [dotafs2](https://github.com/dotafs2). Project name: **InfiniteAincrad**.

**2026-09-10 transfer:** [New-computer setup, art sources and same-world continuation](docs/CONTINUE_ON_ANOTHER_PC.md). Current real-model evidence now includes two separate resident knowledge states; see [current progress](docs/STATUS.md). Normal launches remain offline unless explicitly configured otherwise.

**Status: a runnable Godot 3D street trial.** Walk through the reused market, approach a resident at the well and help with rope and a bucket. The resident physically draws and drinks water; facts continue after reopening. This is an explicitly offline fixture with temporary character/prop art, not a live-model or migrated-world release. [Verified result](docs/validation/street_rebuild_2026-09-10.md).

## 第一个可玩的作品

当前井边包只算内部技术预览。第一版目标已提高为完整首镇：保留原世界的 13 个身份，先在 Godot 恢复三名活跃居民的生活能力，再达到 5–10 人的食物、劳动与交换循环，完善人物、美术、玩家介入和模型更换后的连续生活。

已经加入原存档的独立迁移验证入口：`./Run-Street.ps1 -Town -SavePath <迁移输出/world.json>`。三人可进食、休息、到公共浆果地采集；新选择明确使用离线规则。先按 [迁移说明](docs/MIGRATION.md) 生成私有副本。启动暂停，空格继续；这仍不是完整迁移或第一版。

唯一长期目标：建立能进入、能影响、能长期延续的AI世界。模型升级增强同一批居民的生活，已经发生的事情不会随模型更换消失。

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

Start with [CONTRIBUTING.md](CONTRIBUTING.md) and the [current delivery gate](ROADMAP.md). The immediate contribution is independently reproducing or testing the Windows preview. The next new world behavior is nearby, source-attributed resident inquiry with a choice to respond, refuse or defer.

This is an independent fan-inspired project, not an official SAO product. The initial repository contains newly written scaffolding and planning documents; no third-party character models, animation screenshots or private save data. Reuse and asset licensing status is recorded in [ASSET_POLICY.md](ASSET_POLICY.md). A public repository does not by itself grant a general reuse license; the project-wide license has not yet been selected.

Previous experiment: [dotafs2/vibeGamingDemo1](https://github.com/dotafs2/vibeGamingDemo1). Its history remains there; this project starts with its own Git history.
