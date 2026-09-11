# 开源协作方案评审规则

这是研究证据与评审记录，不是第二份执行路线。最终执行顺序统一写入仓库根目录的 `ROADMAP.md`。核验基线为 2026-09-10、本地提交 `59bd52e`。

## 评审范围

目的：确定从现有 Godot AI 街道原型走到可供外部体验、修改和持续贡献的首个公开版本，需要完成什么，以及哪些复用方案值得加入。

本轮只研究、编写建议和核查来源，不运行付费 NPC，不恢复旧自动任务，不宣布项目许可证，不安装候选依赖，不向外部发送信息。

六个独立任务分为两组：A 产品体验、B 社区贡献、C 差异化与反证；D 美术复用、E Godot 工程、F AI 复用。任务具有不同立场，但不是六名人类专家或六种独立模型。投票表达这些评审任务在给定证据下的判断，不能证明客观唯一正确。

## 证据要求

1. 以官方仓库、许可证、发布记录、实际 PR、官方文档和作者论文为来源。标明核验日期。
2. 区分知名度、可复现、持续发布和外部贡献。星数、下载量或论文关注不能单独证明持续协作；没有可验证数据就写未知。
3. 每项复用提议说明解决哪个现有问题、替代什么自研工作、许可证及范围、固定版本或待验证版本、接入成本、退出方案。仅列出库名不算通过。
4. 兼容性未实际验证时，只能推荐有限试验，不能报告已经兼容或已经节约了工时。
5. 不把测试居民、回放和离线规则标成实时 AI；不把公开快照标成旧主世界迁移。

## 辩论与投票

- 第一轮：独立提出方案、最强反论和可推翻自身判断的条件。
- 第二轮：跨立场质询；至少处理一个真实反对理由并说明保留或改变的判断。
- 第三轮：对统一版本的提案逐项投票。提交票前不阅读其他评审的票。主代理汇总证据并主持，不另加一票。
- 每位一票。一般方案得到至少 4/6 支持才采用；不能完成实际检查的依赖只获得“有限试验”资格。
- 许可证不明、破坏已有世界连续性、需要未授权付费或无法复现的关键前提，不能被多数票覆盖。
- 平票或证据不足的依赖延后；路线若平票则先进行双方同意的最小判别试验，不强造共识。
- 记录逐票结果、少数意见、是否改变立场和重新评审的触发条件。投票支持不等于效果已得到外部用户验证。

## 当前可直接核实的缺口

本地没有根目录 `LICENSE`、`.github/` 或 `game/export_presets.cfg`。已有 `CONTRIBUTING.md`，但主要是内部工作规则；已有保存和知识隔离测试，不能描述为完全没有测试。`game/InfiniteAincrad.csproj` 指向 Godot.NET.Sdk 4.7.2 与 net8.0。当前本机普通 Godot 二进制不构成 .NET 分发环境验收。主美术两个 LFS 文件已通过哈希与 LFS 完整性核验。

私有迁移包与旧运行费用账本不在仓库内，本轮未取得；不据此重置费用，也不冒称旧主世界已恢复。公开试验可以继续使用明确隔离的演示身份，但对原世界的恢复声明仍须核验源档。

## 一手依据

- Open Source Initiative, [The Open Source Definition](https://opensource.org/osd)，页面标注修改于 2024-02-16，2026-09-10 核验：公开源码与授予开放复用权是不同条件。
- GitHub Docs, [Adding a license to a repository](https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/adding-a-license-to-a-repository)，2026-09-10 核验：许可证明确他人使用、修改、分发项目的权限。
- GitHub Docs, [Setting guidelines for repository contributors](https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/setting-guidelines-for-repository-contributors)，2026-09-10 核验：贡献说明与 Issue/PR 入口应使首次参与可操作。
- Godot Docs, [Exporting for the Web](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html)，2026-09-10 核验：当前官方文档明确 Godot 4 C# 项目不能直接导出 Web；不能把现有项目网页首发视为无成本部署。
- Godot Docs, [Exporting for Windows](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_windows.html)，2026-09-10 核验：编辑器运行与导出可分发游戏是不同验收对象。

## 用量说明

本次六项有限研究由新请求明确授权；不沿用或重启旧夜间实现批次。没有新增付费 NPC/API 试验。本接口未提供可可靠合计六任务原始 token 增量的计量结果，因此不填写估算为实际值，也不声称受某个未落实的硬 token 限额控制。
