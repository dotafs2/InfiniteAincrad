# 发布前授权范围草案

2026-09-10。供 dotafs2 确认；本文件自身不授予许可证，也不更改第三方条款。
当前可继续本地构建与测试。公开协作发布需要下列权利范围的明确决定。

| 文件范围 | 当前证据与来源 | 拟采用的授权 / 剩余确认 |
|---|---|---|
| `game/core/`、`game/spatial/`、`game/ui/`、`game/agents/`、`game/tests/`、`game/scenes/`、`game/capabilities/`、根启动/构建脚本、`tools/` 中自编写部分 | 正式仓库自行编写；不含下面单列的上游目录 | 原创代码采用 MIT，署名 `2026 dotafs2 and InfiniteAincrad contributors`；需权利人确认原创部分可以这样授权 |
| 根 Markdown、`docs/` 中独立原创文档 | 项目文档；研究引用仍指向各自原始来源 | 原创文字采用 CC BY 4.0；第三方引用、商标及外部链接内容不随文档重新授权 |
| `game/assets/market/StartingTown_Market_CraftV5.glb` | [现有来源说明](../../game/assets/market/PROVENANCE.md)；来自 dotafs2/vibeGamingDemo1 的自制 V5 市场；SHA256 `2e680ec8814a6aa7f4d09c74ad20fb859b5ccae5e3ef161f51d70e9c40f1b67d` | 拟 CC BY 4.0；确认市场模型及嵌入纹理确为可授权的原创内容 |
| `Art/ReferenceScenes/MarketCraftV5/` 的 Blender 源及纹理、制作脚本 | [迁机清单](../CONTINUE_ON_ANOTHER_PC.md)、该目录内制作说明；Blend SHA256 `ccd3261b89500d1b1878b29d8aebf0282291bf5e1c21b6bf69b7bc9ae9b2b` | 原创美术拟 CC BY 4.0、原创构建脚本拟 MIT；逐文件清单及外部依赖需核对后适用，不能只给整个旧项目换许可证 |
| `game/spatial/trial_resident.gd` 生成的临时人物与道具 | 项目代码生成的基础几何体 | 代码 MIT；独立导出的原创美术拟 CC BY 4.0 |
| `third_party/OpenGameAgent/` 与 `game/addons/open_game_agent/` | [上游锁定清单](../../third_party/opengameagent.lock.json)，EricSun0218/OpenGameAgent `b1a9f149`；两个目录保留 MIT 文本 | 沿用现有 MIT 与原作者署名；生成的 Godot UID 元数据不改变上游源码 |
| NuGet 标准库、Godot/.NET 运行时 | 锁文件、官方 Godot 4.7.2 .NET、.NET 8.0.31；运行时包内附许可证 | 各自原始条款，见 [随包告知](../../distribution/THIRD_PARTY_NOTICES.md)；不受项目新许可证覆盖 |
| `distribution/licenses/` | Godot 源 `ed1daf0bf001b61586d9930840f2f1394092c079` 的 LICENSE/COPYRIGHT；dotnet/runtime `v8.0.31` 的 LICENSE.TXT/THIRD-PARTY-NOTICES.TXT | 原文照录，保留各自版权，不能改为项目原创文档许可证 |
| `docs/validation/` 的截图与记录 | 明确标为 fixture、replay 或真实决策的公开证据；其中的第三方渲染内容仍按底层资产条款 | 原创说明拟 CC BY 4.0；不能凭截图授予第三方角色/字体权利 |

MIT 许可正文将在范围确认后作为根 `LICENSE` 落地；CC BY 4.0 使用
[Creative Commons 官方条款](https://creativecommons.org/licenses/by/4.0/legalcode.en)。
拟署名格式：`InfiniteAincrad / dotafs2 — https://github.com/dotafs2/InfiniteAincrad`，
注明所用许可证及修改。第三方组件仍单独署名。

明确排除：源项目受限 Kirito 角色及其派生素材、私人存档/身份历史、密钥与费用数据库、
SAO 品牌/角色权利、外部引用内容。既有排除规则继续有效，不需要再次询问是否排除。

最终需要确认的是一个具体范围：**对以上确属你有权授权的原创代码采用 MIT，对原创美术与独立文档采用 CC BY 4.0，并确认市场 V5 及其嵌入纹理的授权链**。
若有例外，记录具体路径并从公开包排除；不以新建仓库或投票替代权利证据。
