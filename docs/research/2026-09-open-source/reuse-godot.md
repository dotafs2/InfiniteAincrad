# Godot 工程复用评审（E）

核验日：2026-09-10。范围是把现有 Godot 4.7.2 .NET 街道推到可导出的 Windows 试验包，并让“近距离消息→接收者决策→可见后果”可验证。仓库已有 OpenGameAgent、两个隔离 fixture 居民、保存/知识/决策测试；`street_trial.gd` 仍是两点直线移动，未使用导航网格、AnimationTree 或第三方测试框架。没有 `export_presets.cfg`、`.github/` 或可分发包。以下兼容性均是资料判断，尚未在本仓库安装或实测。

## 基线与候选

**1. 原生导航与动画：保留现有，作为当前唯一推荐。** Godot 官方 [NavigationAgent3D 文档](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationagents.html)说明它提供寻路、路径跟随和避让；[NavigationRegion3D/导航网格文档](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationmeshes.html)也明确网格必须按角色尺寸收缩，碰撞体不会自动变成可行走信息。官方 [AnimationTree 文档](https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html)说明它复用 AnimationPlayer 动画并处理混合过渡。它们是引擎内置、MIT 引擎许可范围内的节点，不增加第三方归属。先用 NavigationRegion3D + NavigationAgent3D 替代直线移动，再把现有 `set_walking/set_gesture` 映射到 AnimationTree；这能让“到达井边/收到消息时确实在半径内、绕开障碍、产生可观察动作”成为测试后果。不能替世界规则、消息权限或模型决策，也不能保证导入 GLB 的碰撞和网格正确。4.7.2 官方下载页同时列出 Windows .NET 编辑器及 [.NET export templates](https://godotengine.org/download/archive/4.7.2-stable/)；本机 `4.7.2.stable.custom_build` 仍不证明官方 .NET 构建可得，首次交付必须固定官方版本、模板和 Windows headless/export 验收。

**2. Beehave：以后触发再加。** [官方仓库](https://github.com/bitbrain/beehave)为 GDScript 行为树，MIT；[v2.9.3 release](https://github.com/bitbrain/beehave/releases/tag/v2.9.3)写明兼容 Godot 4.7，并修复加载/卸载生命周期。它可替代未来“走路、等待、搬运”分散在场景脚本中的自研流程编排，接入成本是复制 addon、启用插件、把每个受世界规则约束的动作封成叶节点。当前一个居民只有有限阶段，行为树会增加状态来源而不解决消息真实性、存档或 GM 审核；因此触发条件是第三个以上可复用行动且现有阶段测试开始重复。维护信号良好（4.7 升级 PR 和近期 release），但本项目 C# 主体与 GDScript addon 的边界尚未验证。

**3. LimboAI：延后，不与 Beehave 同时引入。** [官方仓库](https://github.com/limbonaut/limboai)是 MIT 风格许可的 C++/GDExtension 行为树与状态机，demo 美术另为 CC BY 4.0；[v1.8.0 release](https://github.com/limbonaut/limboai/releases/tag/v1.8.0)提供 Godot 4.7、.NET editor 和 .NET export-templates 构建，并注明 4.7 支持。它比 Beehave 多编辑器、调试器和状态机，可替代部分自研编排；代价是原生扩展、平台二进制、导出矩阵和状态树迁移。它仍不能验证邻居是否真正听见消息，不能管理居民私有知识或持久世界事实。即使版本信号强，也未在本项目的 Windows .NET 与现有场景实测；只有当 Beehave 试验暴露出需要层级状态机且可接受 GDExtension 打包时再比较，禁止一口气引入两套。

**4. 测试框架：保留现有 SceneTree，暂不替换。** [GUT](https://github.com/bitwes/Gut) 是 MIT、GDScript 单元测试；官方 README 列出 9.7.1 对 Godot 4.7.x，并提供 doubles、CLI、JUnit XML，[release](https://github.com/bitwes/Gut/releases/tag/9.7.1)记录 4.7 类型检查修复。[GdUnit4](https://github.com/godot-gdunit-labs/gdUnit4) 及其 [C# 实现](https://github.com/godot-gdunit-labs/gdUnit4Net)均 MIT，支持场景、mock 和 C#；README 的 master/v6.2 兼容表覆盖 4.7/4.7.1，但没有本仓库 4.7.2 .NET 实测。两者都能替代自写断言/runner，GUT 更轻且 4.7 版本明确，GdUnit4 更适合 C# 场景测试；代价是引入 addon、发现顺序和 headless 失败差异。现有测试已覆盖保存、知识隔离、决策边界，且直接 `SceneTree` 可执行；现在换框架只增基础设施，不会证明消息后果。触发条件是外部贡献者需要标准 JUnit/scene fixture，届时先以一个复制测试做比较，不迁移全部套件。

**5. CI 与 Windows 导出：现在有限试验，推荐 setup-godot。** [chickensoft-games/setup-godot](https://github.com/chickensoft-games/setup-godot) 为 MIT GitHub Action，README 明确支持 Windows/macOS/Linux、Godot 4.x、`.NET`、可选 export templates，并可按精确版本安装缓存；这正好替代当前没有 `.github`、模板和版本门控的自研脚本。可选的 [barichello/godot-ci](https://hub.docker.com/r/barichello/godot-ci/) 是 Docker 导出镜像，文档明确用 `mono-VERSION` 支持旧 Mono/C#，但没有证据表明其镜像标签覆盖本项目 Godot 4.7.2 .NET；不能把旧 `mono-*` 经验当成兼容。先用 setup-godot 固定 4.7.2、`use-dotnet: true`、模板和 `dotnet build`，再运行现有 headless tests 与 Windows export smoke test；若 runner 无法取得官方 .NET 模板则停止发布。CI 只能复现构建，不能替代近距离消息、存档和模型拒绝/等待的行为验收。

## 结论与边界

唯一推荐顺序是：保留 OpenGameAgent、现有 SceneTree 测试和 Godot 原生节点；现在有限试验 setup-godot 的官方 4.7.2 Windows .NET 构建；下一项产品工作只做原生导航加一条“消息被接收后拒绝或等待”的可验证路径；以后触发再加 Beehave；LimboAI、GUT、GdUnit4 都延后。禁止同时引入行为树、状态机和新测试框架。任何候选都不能解决 C# Web 导出限制，不能把项目转到网页；[官方 Web 导出文档](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html)明确 Godot 4 C# 目前不能直接导出 Web。Windows 分发仍需在官方 4.7.2 .NET editor/template 上冷验证，不能以本机 custom build、仓库有源码或 CI 绿色作为完成声明。

对当前代码的替代关系应保持窄：导航只替换 `_move_resident_to()` 的路线选择，不接管 `_kernel` 的事实提交；AnimationTree 只替换临时角色的姿态播放，不写入 `memory` 或 `actions`；CI 只负责构建、导出和收集现有验收输出，不把模型请求塞进流水线。消息功能应在世界内新增带发送者、接收者、距离、来源和回执的事件，模型只从接收者个人视图提出 `accept`、`refuse` 或 `wait`，由 kernel 校验后再让场景表现移动或停留。这样才能把三类结果分开断言：没有到达就没有接收；接收但拒绝不改变资源；等待可以保存并在冷启动后保持一次决策，不重复发送。导航网格的障碍、代理半径和到达阈值应成为测试输入，避免用时间或屏幕位置猜测“近距离”。

版本风险也必须单独留痕。项目 SDK 是 `Godot.NET.Sdk/4.7.2`、目标 `net8.0`；候选 addon 多数按 Godot 小版本或 GDScript/GDExtension 构建，README 的“支持 4.7”不等同于支持这个自定义 .NET 编辑器、当前 Windows 驱动或本项目 GLB。每个有限试验都应锁 release/tag 和哈希，记录编辑器版本、模板版本、操作系统、导出命令及 headless 结果；失败时回退到现有脚本，不改变存档格式。这个退出条件比追求插件数量更能保护连续世界。

评审投票前的反证标准是可重复的 Windows 包和冷启动行为证据，而不是截图、星数或“能打开编辑器”。若官方模板下载、C# 编译、导航烘焙、消息回执或旧存档读取任一项失败，候选只能保持延后状态；修复应先缩小到一个 fixture 和一个可追踪事件，再决定是否扩大到三名居民。

最强质询（给美术组）：请在不改世界规则的前提下交付可复现的导航输入——市场 GLB 的行走面、22 个碰撞代理、井边和两名居民的胶囊尺寸，能否在固定 Godot 4.7.2 .NET 上烘焙出不穿墙、可到达且可截图/断言的网格？如果不能，任何行为树或动画插件都只是把不可验证的直线移动包装起来。

最强质询（给 AI 组）：消息接收者的视图能否只包含其实际距离、可见/可听来源和收到的原文，并让拒绝或等待留下带来源的持久事件？请给出跨冷启动仍不共享 Luna 私有经历的断言；没有这条证据，增加 LimboAI、Beehave 或测试框架都不能证明居民真正互相影响。

## 交叉辩论回应（第二轮）

我接受根代理和 B 对门槛的修正：原生导航应是“原生优先、需求触发”，不再把整街重烘或完整 NavigationRegion3D 设为消息开发前置条件。当前固定井边位置已有实测近距离条件，第一条消息可直接复用该路径；只有出现绕障、多个目的地或位置误差导致接收判定不稳定时，才做一个最小井边网格试件。这样保留引擎节点的真实成本优势（路径查询、避让和调试由 Godot 提供），又避免为一条已验证直线事件支付全市场烘焙、障碍清理和 GLB 碰撞重审成本。自研直线移动的退出成本几乎为零；自研导航则会承担代理尺寸、网格版本和路径回放维护，因此不能凭“以后可能需要”提前扩张。

F 提出的语义区分是硬证据：模型明确选择 `wait`/`refuse`，才是居民决定；provider timeout、取消、断网或规则拒绝只能记录系统/世界拒绝并进入显式失败分支，不能伪装成 wait。每条消息测试应保存发送者、接收者、原文来源、感知距离、turn、决定来源和回执；冷启动后断言收件人的私有视图、事件和资源一致，且不会重发。证明“续接身份”的事实应是同一 `world_id`、同一 resident identity、旧经历/动作计数与新事件按 turn 连续，并由接收者基于自己收到的观察作出新决定；一段相似对白或单次模型回复都不够。

B 的分发优先成立：setup-godot 只能安装指定 Godot/.NET/模板，不能替代 `export_presets.cfg`、Windows 导出命令、C# build、物理碰撞、消息回执或保存恢复验收。保持现有 SceneTree 测试；只有需要标准 JUnit/场景 runner 且一个复制试件证明收益时才试 GUT 或 GdUnit4。Beehave 仅在第三个以上居民共享行动编排、现有阶段逻辑重复时试用；LimboAI 还需先证明行为树不足并接受 GDExtension 打包。当前不改变原推荐顺序，只把“现在做导航”改为“现在保留原生选项，消息证据先行”。

## 一手来源（均于 2026-09-10 核验）

Godot 4.7.2 [archive](https://godotengine.org/download/archive/4.7.2-stable/)、[4.7.2 release](https://godotengine.org/article/maintenance-release-godot-4-7-2/)、[NavigationAgent3D](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationagents.html)、[navigation meshes](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationmeshes.html)、[AnimationTree](https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html)、[Web export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html)；Beehave [repo/license](https://github.com/bitbrain/beehave/blob/godot-4.x/LICENSE) 与 [release](https://github.com/bitbrain/beehave/releases/tag/v2.9.3)；LimboAI [repo/license](https://github.com/limbonaut/limboai) 与 [release](https://github.com/limbonaut/limboai/releases/tag/v1.8.0)；GUT [README](https://github.com/bitwes/Gut/blob/main/README.md)；GdUnit4 [repo](https://github.com/godot-gdunit-labs/gdUnit4)；setup-godot [README/license](https://github.com/chickensoft-games/setup-godot)；barichello [Docker image](https://hub.docker.com/r/barichello/godot-ci/)。
