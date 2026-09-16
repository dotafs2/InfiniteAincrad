# 2026-09-17 本机接收与工作交接

本次请求：拉取线上最新代码并开始工作交接。接收目录为 `D:\lucidgloves\InfiniteAincrad`，分支 `main`。本文件记录换机后的实际检查，不能替代上一台电脑的原始测试证据。

## 已接收的版本与成果

- 从 `aa026a3` 快进到 `4b958f345a3fbd3309cdd60936f46ab59184709a`，与本次抓取的 `origin/main` 一致；没有合并冲突。
- 上游提交为 **Assemble first-floor PCG demo and archive September 16 art work**，时间为 2026-09-16 21:41（中国时间），包含 H89—H99 的工作。
- 本次新增 1414 个变更文件；拉取过程中下载约 915 MiB LFS 内容。当前版本共 404 个 LFS 路径，工作区实际文件合计 2,811,437,023 字节，缺失文件和未展开指针均为 0；`git lfs fsck --objects HEAD` 通过。
- 原有 `stash@{0}`（`local-route-review-before-sync-20260915-b08b219`）保留，未应用或删除。
- 收尾再次直接查询远端时，GitHub 分别返回空响应和低速超时；此前 fetch、快进及 LFS 下载已成功完成。版本结论以本次成功抓取的 `4b958f3` 为准，不能用失败的收尾查询证明其后远端没有变化。

| 成果 | 当前状态与入口 |
| --- | --- |
| 最新 Demo 小镇 | 16 栋房屋、10 位居民、39 类 / 145 处道具、116 树、66,000 草、28 组岩石和 8 根倒木；入口为 [StartDemo.cmd](../../StartDemo.cmd) 和 [demo_town.tscn](../../game/scenes/demo_town.tscn)。 |
| 居民生活街区 | 10 处室内住所、可开关门窗、家具和连续坡地；以存档中的 `first-floor-market-quarter-v1` 选择新布局，旧布局仍有兼容入口。 |
| 原生场景插件 | Terrain3D、Road Generator、ProtonScatter、SimpleGrassTextured、EZ-Tree；精确来源及下载哈希见 [plugins.json](../../experiments/pcg-trial/plugins.json)。 |
| 模型比较与原始资料 | Tripo / Meshy 房屋及组件比较、双住宅示例、模型账号池与原始模型已入库；64 个归档源文件见 [清单](../../Art/SourceModels/20260916/manifest.json)。 |
| 美术证据 | 最新是 [demo-v2](../../Art/Generated/PCG20260916/demo-v2/delivery-status.json) 的 13 张实渲和报告。H88 的 44 栋扩建样板、视频及 LOD 仍保留；与本次 16 栋生活街区是不同场景，不应混记。 |

上一台电脑已记录 40/40 路线、30/30 实走、64/64 门窗以及散布空带检查通过。这些是随 Git 接收的历史结果；本次没有重新完成全图实走或图形性能测试。

## 本机接收检查

| 检查 | 本次结果 |
| --- | --- |
| Git 与 LFS | 快进成功，404 个 LFS 文件齐全，对象完整性检查通过。 |
| C# 构建 | `dotnet build game/InfiniteAincrad.csproj --disable-build-servers -v minimal` 通过，0 警告、0 错误。 |
| Meshy 工具测试 | `python -m unittest discover -s tools -p test_meshy_pool.py`：21 项通过，使用离线测试，不调用生成服务。 |
| 原档迁移回归 | 6 项全部跳过：缺少 `private/living-quarter-20260916/original-seq129.json`。不能记为本机通过。 |
| 首次 Godot 资源导入 | 失败：Terrain3D 原生 DLL 没有随仓库交付。错误日志保存在本机 `private/handoff-20260917/import/tool.log`。后续补依赖和复查结果见下节。 |
| 补依赖后的资源导入 | 最终采用系统 .NET 9 并允许 `LatestMajor` 后通过，退出码 0，完整日志无 ERROR / WARNING，自有进程已全部退出。 |
| 公共预览准备与冷恢复 | `StartDemo.cmd --prepare-only` 成功；实际 Godot 状态检查输出 `DEMO_PREVIEW_STATE_OK residents=10 seq=0 cold_restore=true`，退出码 0，完整日志无 ERROR / WARNING。 |
| 正式场景图形退出与全图复测 | 本次未执行，仍保留上游未解决状态。Headless 状态检查不覆盖 GPU 渲染资源释放。 |

## 换机依赖与启动

发现一个可复现的交付遗漏：`.gitignore` 中的通用 `bin/` 规则排除了 `game/addons/terrain_3d/bin/`；Git 中有 `terrain.gdextension`，但没有它引用的原生动态库。`git lfs pull` 不能恢复未被跟踪的文件。

本次按 `plugins.json` 的固定版本恢复 Terrain3D 1.0.2 Windows x64 debug/release DLL。下载包 SHA-256 必须为 `a071850250ec5e596aa54da61c01d75768774eb379ee997584d426a45f4884a2`；恢复回执放在本机 `private/handoff-20260917/terrain-dependency.json`。这属于本机依赖准备，仓库的自动安装缺口仍需后续工程修改。

项目的 `RuntimeFrameworkVersion` 固定为 8.0.31，本机系统没有该补丁版。本次将对应 Windows x64 Runtime 下载至 `tmp/toolchain/dotnet-8.0.31`，按已有官方发行清单校验 SHA-512，未更改系统安装。回执在 `private/handoff-20260917/dotnet-dependency.json`。该独立运行时已准备，但不是下方最终通过的编辑器启动配置。

实测只把 `DOTNET_ROOT` 指向上述 .NET 8 目录时，Godot 编辑器报 `System.Runtime, Version=9.0.0.0` 缺失；虽然该轮导入最后退出 0，也不能记为无错误通过。随后改用本机系统 .NET 9.0.2，并仅在命令环境设置 `DOTNET_ROLL_FORWARD=LatestMajor`：资源导入和公共预览状态检查均无错误通过。系统 SDK 9.0.200 已实际构建成功。这是本机验证配置，不等于已验证其他机器或发布包兼容性。

本机 Godot 为 `tmp/toolchain/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64.exe`。PowerShell 中从仓库根运行：

```powershell
$handoffGodot = Join-Path $PWD 'tmp/toolchain/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64.exe'
$env:DOTNET_ROOT = 'C:\Program Files\dotnet'
$env:DOTNET_ROOT_X64 = $env:DOTNET_ROOT
$env:DOTNET_ROLL_FORWARD = 'LatestMajor'
python -X utf8 tools/import_pcg_project.py --godot $handoffGodot --out private/handoff-next/import
.\StartDemo.cmd --godot $handoffGodot --prepare-only
# 需要打开交互窗口时：
.\StartDemo.cmd --godot $handoffGodot
```

V 切换总览，WASD 移动，E 门、F 窗。启动器默认只操作独立预览副本，居民暂停，不发 NPC / GM 模型请求。缺少私有档时会创建 `shared:demo-preview-20260916`、seq0 的公共初始预览。

注意：当前 `prepare_runtime()` 只凭 DLL / 导入目录存在来决定是否跳过准备。老 checkout 更新代码后，这两个目录可能存在但已经过期，因此本次显式构建和导入。`StartDemo.cmd` 使用 `--godot` 或 `GODOT`，不能假定与旧 `Run-Street.ps1` 的 `GODOT_EXE` 自动互通。

最终通过的本机日志为 `private/handoff-20260917/import-system-runtime/tool.log` 和 `private/handoff-20260917/preview-system-runtime/tool.log`。公共种子为 `private/pcg-trial-20260916/preview-genesis.json`，冷恢复产物为 `private/handoff-20260917/preview-system-cold-world.json`；均在 Git 忽略目录。

## 正式世界与公共预览的交接边界

上游记录的正式世界为 `shared:mvp-test-20260914`，seq129，十人历史和身份保留、生活暂停。最新迁移档 SHA-256 为：

```text
3ed26a1024e59cad84960022c09bbb0f0bc18062bdc15f79903a9268014e526a
```

本机没有上游所指的 `tmp/mvp-autonomy-20260914/prepared/real/canonical-world.json`，也没有 `private/pcg-trial-20260916/world.json` 或迁移原档。对本机 `tmp`、`private` 及存在的存档目录按 world/canonical 文件名进行的限定检查覆盖 359 个候选 JSON，没有找到上述世界 ID；不能据此把本地旧测试世界当作同一正式世界。

继续原世界 10+10 之前，需要从上一台电脑私下接续以下资料，并核对实际路径、世界 ID、序号及哈希：

1. 正式世界档及迁移前备份；避免用 seq0 预览覆盖原档。
2. 十位 GM 的状态、会话、候选交付与发布记录；只搬世界 JSON 不会搬走 GM 的记忆。
3. 对应 Kimi / DeepSeek 用量账本、运行配置和本地凭据。仅记录路径及配置是否可用，不把密钥或私有数据加入 Git。

这些资料不阻碍离线场景诊断。当前没有重新启动付费居民、GM、生成队列或夜间自动化。

## 接下来如何继续

### 1. 先完成可重复的换机启动

让工程执行方补齐 Terrain3D 固定版本依赖的获取 / 完整性检查，并改进启动器对已有但过期构建与导入缓存的处理。验收是在干净 checkout 或独立隔离目录中启动公共预览，而不是借用本机现有缓存后宣布交付完成。

### 2. 定位已交接的 Godot 退出问题

原日志见 [engine-exit.log.txt](../../Art/Generated/PCG20260916/demo-v2/engine-exit.log.txt)。错误涉及 `PagedAllocator` 中的 `GeometryInstanceSurfaceDataCache` / `GeometryInstanceForwardClustered`，以及未释放的 `SceneForwardClusteredShaderRD` 和实例依赖。上游尝试释放子节点后等四帧，仍失败，不能重复当作已修复方案。

优先入口是 [town.gd 的关闭流程](../../game/experiments/pcg/town.gd)、[demo_quarter.gd](../../game/experiments/pcg/demo_quarter.gd)、[native_quarter.gd](../../game/experiments/pcg/native_quarter.gd)、[quarter.gd](../../game/experiments/pcg/quarter.gd)。按可疑资源生命周期做 Terrain3D、Scatter / MultiMesh、素材实例的最小隔离，保留错误出现条件与退出码。监管脚本在看到 ERROR 后会终止自有进程，因此原日志末尾不代表引擎自然退出。

上游市场视角 90 帧采样均值 15.94ms、P95 19.78ms；另一轮均值 181.85ms，且有非任务 UE4 后台负载。没有稳定整图 60FPS 的证据。记录本机负载后再比较，不能沿用旧 PID，也不能关闭他人的编辑器。

### 3. 再衔接生活与维护闭环

长期目标仍是十位居民在城市移动、生活并产生需要，十位 AI GM 观察问题、开发改进、发布后复查实际采用。当前新摆放的市场 / 工坊道具只是美术和碰撞，没有自动增加烹饪、加工、职业或居民工具。十个 GM 身份也不意味着十个持续并行开发进程。

恢复原档后先做一个短而完整的生活 → 问题 → 原 GM 修复 → 原居民采用 → 保存重启复查闭环，再扩大运行时长；不要把原 H86 单居民隔离实验能力直接当成正式世界已上线。核心架构与接口见 [ROADMAP 当前架构](../../ROADMAP.md#current-architecture)。

本轮已采用的美术方向是第一层市场街 / 托尔巴纳参考、适度 PBR 的树草；此前平面化树木是保留的对比候选。GPT-6 负责方向、建模和评审；需要写功能代码时按用户既有选择交给 GPT-5.6 或 DeepSeek。本次仅完成同步、依赖准备、检查与交接，没有继续生成资产。新增交接及三份主文档的索引更新保留在本地，尚未提交或推送。

## 给下一位接手者的短提示

> 从 D:\lucidgloves\InfiniteAincrad 的 main / 4b958f3 接手，先读本文件、HISTORY 的 H99 和原始 `Art/Generated/PCG20260916/handoff/continue-prompt.txt`。旧提示里的 C:/InfiniteAincrad 是上一台电脑路径。最新是 16 栋生活街区 Demo，H88 的 44 栋样板另存。先查本机依赖与已知退出资源错误，不重新生成已完成的模型。正式 seq129 私有世界及 GM 状态没有随 Git 交接，公共 seq0 预览只能用于离线场景开发。已有 stash 保留，README 刻意为空，不重建 AGENTS.md。
