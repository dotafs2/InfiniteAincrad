# 来源复核与排除记录

核验日期：2026-09-10。此文件记录研究中发现的证据问题，不是执行路线。

## 已纠正的引用

- `StanfordHCI/genagents` 与原始 Smallville 代码不是同一个仓库。原始论文实验应引用 [joonspk-research/generative_agents](https://github.com/joonspk-research/generative_agents) 与 [论文](https://arxiv.org/abs/2304.03442)。原仓库 LICENSE 为 [Apache-2.0](https://github.com/joonspk-research/generative_agents/blob/main/LICENSE)；项目使用的第三方美术仍需分别核对，不能从代码许可证直接推导素材权限。
- 初稿出现的 `github.com/VelorenProject/veloren` 不作为官方项目证据。该同名页面的内容和源码布局不足以建立官方来源链。采用 [Veloren 官网](https://veloren.net/)、[官方贡献者手册](https://book.veloren.net/contributors/index.html) 和明确标注 GitLab 镜像的 [veloren/veloren](https://github.com/veloren/veloren)。未下载或运行同名页面的安装工具。
- [Project Sid 官方仓库](https://github.com/altera-al/project-sid) 的可见文件为技术报告 PDF、README 和示意图，README 也明确仓库内容是技术报告。因此把它归为研究影响力对照，不能列为可直接复用的开源模拟器。
- [AI Town README](https://github.com/a16z-infra/ai-town) 提供本地 Docker 与 Ollama 路径，不能概括为只能用云；但仍引入 Convex/PixiJS 等运行栈。其更换模型/embedding 时清空数据的说明与本项目保持世界事实的目标不相同。借鉴概念，不照搬数据重置方式。

## 持续贡献的可见证据

[Veloren 开发周报 250](https://veloren.net/blog/devblog-250/) 标注发表于 2025-11-21，覆盖页面说明的 5 月工作周期，列出贡献者、翻译者、已合并功能和 GitLab MR。它支持“有跨角色贡献和公开合并反馈”的历史事实，不证明 2026-09 的最新贡献率。官方手册另为开发、美术、音频、翻译、设计和文案提供入口。

[Endless Sky 发布页](https://github.com/endless-sky/endless-sky/releases) 与 [Luanti 发布页](https://github.com/luanti-org/luanti/releases) 可用于核对存在可获取版本和变更历史。它们与贡献指南共同支持可运行交付和协作流程的观察；本报告没有将星数、fork 数、未关闭 Issue 数推算为活跃贡献者数量。

## 不成立的推论

- 离线规则或回放通过，不等于真实模型会自主拒绝或形成生活。
- 真实模型说“等一等”，不自动等于提出了结构化能力需求。
- 提供者超时是系统错误状态，不是居民自愿作出的等待决定。
- 两种提供者续接同一份状态，只证明该测试范围中的技术连续性；需要两种实际模型的新决策，才可报告模型替换实验。
- 一次失败、三个样本的比例或自设阈值不能证明应该放弃整个 Godot 世界目标。先分类定位、缩小任务并复测；方向变化必须基于充分证据和维护者决定。
- 有许可证、有发行包、有贡献说明是参与条件，不是外部贡献者必然出现的因果保证。真实协作仍要用独立体验、贡献和再次参与来验证。

## 访问与实际验证限制

主持复核时，OpenGameAgent 固定提交的网页访问出现缓存获取失败；本地已随仓库保存该提交对应的来源锁文件、MIT 文本和接入记录。因此“保留已有固定依赖”有本地依据，但不能据此推断上游最新维护速度或新版本兼容性。Blender 手册的另一条 latest/import_export 路径也未成功取得内容，最终采用美术评审已记录的官方手册来源，不把失败页面当作新增证据。

版本网页、许可声明和 API 文档只支持资料层判断。本轮没有下载候选资产包逐文件审计，也没有安装新插件、运行本地模型或完成 Windows 导出；这些都仍是路线中的实际验收工作。
