# InfiniteAincrad

A persistent AI world inspired by Sword Art Online. Residents retain their identities, experiences and commitments as the models behind them change.

Maintained by [dotafs2](https://github.com/dotafs2). Project name: **InfiniteAincrad**.

**Status: migration preparation.** This repository has an independent Godot startup scene and a bounded implementation plan. It does not yet contain a playable town, autonomous residents or a migrated live world. The previous experiment's results are reference evidence, not capabilities already delivered here.

## 第一个可玩的作品

一条起始之城风格街道，三个有连续经历的居民，一件真实生活事件。玩家提供一次材料帮助或不帮助，居民自主回应；行动产生可见后果，保存重启后继续。

唯一长期目标：建立能进入、能影响、能长期延续的AI世界。模型升级增强同一批居民的生活，已经发生的事情不会随模型更换消失。

## Current repository

| Path | Purpose |
| --- | --- |
| [game/](game/project.godot) | Godot 4 startup scaffold; no model calls or world loading |
| [ROADMAP.md](ROADMAP.md) | One MVP, sequential acceptance gates and stop limits |
| [docs/MIGRATION.md](docs/MIGRATION.md) | What may move from the experiment, and how continuity is verified |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Single-engine direction and boundaries for world rules and model adapters |
| [docs/STATUS.md](docs/STATUS.md) | Implemented, missing and blocked work |

## Run the scaffold

Open `game/project.godot` in Godot 4 and run the main scene, or use:

```powershell
godot --path game
```

The screen states that migration is pending. It does not generate NPC decisions, spend API credit, initialize a replacement world or load private saves. An editor-free downloadable game is a later acceptance gate, not the current deliverable.

## Contributing

Start with [CONTRIBUTING.md](CONTRIBUTING.md). The first implementation task is a bounded test of whether the existing world semantics can continue inside a single Godot runtime. Avoid parallel rewrites, new populations, full-city art production or unattended model loops.

This is an independent fan-inspired project, not an official SAO product. The initial repository contains newly written scaffolding and planning documents; no third-party character models, animation screenshots or private save data. Reuse and asset licensing status is recorded in [ASSET_POLICY.md](ASSET_POLICY.md). A public repository does not by itself grant a general reuse license; the project-wide license has not yet been selected.

Previous experiment: [dotafs2/vibeGamingDemo1](https://github.com/dotafs2/vibeGamingDemo1). Its history remains there; this project starts with its own Git history.
