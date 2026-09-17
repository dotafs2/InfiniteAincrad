# 2026-09-18 十人生活现场首轮交付

## 已接入的真实入口

`StartLiving.cmd` 现在明确把用户带入 `res://scenes/town_street.tscn`，不再需要记住 `Run-Street.ps1 -Town`，也不会误入项目默认的单居民 `street_trial.tscn` 或 `StartDemo.cmd` 的暂停美术预览。

无付费本地观察必须使用原档的**副本**，并显式给 `-ObserveOnly`。此模式以 `--town-restore` 打开十个身体，模型暂停、不会接纳新决定。它是字节保持的只读回看：`Space`、`H`、`E`、`F` 不会恢复生活、写入询问／本地回复或改变门窗；`V` 总览／返回、`N` 跟随、`M` 生活窗和 `WASD` 游览仍可用。不应把研究原档直接传给它：

```powershell
.\StartLiving.cmd `
  -ObserveOnly `
  -Godot D:\lucidgloves\InfiniteAincrad\tmp\toolchain\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64.exe `
  -SkipBuild `
  -SavePath D:\path\to\disposable-world-copy.json
```

该命令是暂停模型的身体观察，不应被描述为 AI 自主生活。真实模型共同世界由同一个入口接受账本、授权配置、存档和输出目录，再调用已有的有界启动器建立 loopback gateway、预算授权和退出排空。它不带 `--headless`，现场窗口可见：

```powershell
.\StartLiving.cmd `
  -Godot D:\lucidgloves\InfiniteAincrad\tmp\toolchain\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64.exe `
  -SkipBuild `
  -SavePath D:\lucidgloves\InfiniteAincrad\tmp\overnight-20260918\delivery\private\night-delivery\delivery-live\world.json `
  -Ledger D:\path\to\existing-ledger.json `
  -Config D:\path\to\authorized-config.json `
  -Out D:\lucidgloves\InfiniteAincrad\tmp\overnight-20260918\delivery\private\night-delivery\live-run-01 `
  -Seconds 300 -MaxRequests 12 -Concurrency 1 `
  -GmExport D:\lucidgloves\InfiniteAincrad\tmp\overnight-20260918\delivery\private\night-delivery\live-run-01\gm\world.json
```

这条真实路径的关键场景参数仍是 `res://scenes/town_street.tscn -- --town-save=<same-world> --town-gateway`。`Ledger / Config / Out` 缺任意一项都会报错且什么也不启动；也不会暗中退回脚本生活。既没有完整 live 三件套、也没有显式 `-ObserveOnly` 时同样拒绝启动。本次首轮验证产生 0 个模型调用。

普通用户可把 [StartLiving.local.example.json](../../StartLiving.local.example.json) 复制为被 Git 忽略的 `private/night-delivery/start-living.local.json`，只填写现有存档、Godot、授权配置和账本的**路径**，之后直接双击 `StartLiving.cmd`。`mode=live` 会调用同一个有界真实 AI runner，并在 `out_root` 下逐次建立带时间戳的新目录；`mode=observe_only` 明确打开无新决定回看。可配置带时区的 `expires_at` 和 `on_expiry=observe_only`：到期时启动器会显示警告并只读回看，不创建、补充、重置或延长账本。该本机 JSON 不应写 token，也不会进入 Git。

09:00 后若用户明确希望继续真实 AI 生活，使用独立的 `StartLivingAI.cmd`。把 `StartLivingAI.local.example.json` 复制为被 Git 忽略的 `private/night-delivery/start-living-ai.local.json` 并填写路径；启动器会先清楚显示 900 秒、最多 32 个新决定、并发 1、本次授权 3.00 元／可用 2.85 元，且只接受交互式窗口中准确输入 `START AI`。900 秒后不再接新决定，最多再用 65 秒让已开始的回复完成并保存；加上现有运行器固定的 55 秒进程／排空边界，整个授权窗口恰为 1020 秒。3.00／2.85 元按 2026-09-18 独立核对的 K2.6 中国区公开单价控制；界面结束时显示的是按实际回复用量计算的本地费用估算，最终费用以供应商账单为准。确认前零写入；确认后也会先核对所有已列出的旧付费会话、历次用户会话和世界写锁。任何进行中、结果未知、停止、损坏、缺少配对文件或已有世界写入者都会在创建新会话前失败关闭。通过后才以唯一时间戳创建一次性记录和累计摘要；该入口没有无人值守确认参数，也不属于夜间自动流程。

若一整段中居民都处于既有冷却，运行器仍如实保持 `validation_status=not_exercised`、`validation_passed=false` 和原验收退出码；只有在引擎正常、排空完整、没有模型错误／预算停止／未结请求、且同一世界的模拟时间确实前进时，才另记 `idle_completed=true` 并不导出 startup fault。手动入口会显示“本段没有新的 AI 决定，世界已保存”，manifest 保留原 `runner_exit_code`，绝不把健康空闲冒充 AI 测试通过。启动即退、没有时间推进或任何错误仍按失败处理。

## 玩家实际能看到什么

右侧新增一个只读生活窗口：

- 十位居民全部具名列出，逐人显示当前世界工作；身体有水平速度时显示“行走中”。
- gateway／恢复模式显示每个人自己的 durable resident-turn 状态，并用启动时的 request id 区分“历史决定”和“本次决定”，不把一个公共模型状态冒充十个人。
- 最近五条公开交流或生活结果来自 `life.events`；只有 `source=opengameagent_live` 才标为 AI，并按启动时的 life seq 明示“历史 AI”或“本次 AI”。界面不生成文本、不选择动作、不展示私有理由。
- `G` 在相同的右侧面积切换“十位 GM · 已完成工作快照”，再次按 `G` 返回。数据只来自可选 `--town-gm-status=<external json>` 的脱敏外部摘要；必须匹配当前 `world_id`、固定 schema 和十个唯一 GM，且状态只能是“观察完成”或“方案评审完成”。文件未配置、损坏或世界不符时只显示“未载入”，绝不推断正在运行或十人成功。路径和内容不会写入世界，也不会进入居民上下文。
- 原有近身姓名牌、真实身体动画、公开对话框、玩家 `H` 询问、门窗和俯瞰仍在同一个世界中。无对话时底部仅保留一行提示，按 `H` 输入或出现真实对话文本时恢复完整面板。`N` 依次跟随十位真实身体，`M` 收起／展开生活窗；观察相机只读身体坐标，不移动居民、玩家或工作目标。
- HUD 将场景如实标为“艾恩葛朗特第一层 · 原创生活街区”，不把这组原创 16 栋布局冒充原著“起始之城”或托尔巴纳的精确地图。

![生活现场 HUD：十人活动与公开交流](night-20260918-sol-life/living-world-hud.png)

![跟随相机中的真实居民身体](night-20260918-sol-life/resident-follow.png)

## 烘焙视觉接入

公共烤炉、有限面粉袋和居民手中面包已换成可复用 prefab；烤炉仍使用原有同尺寸实体碰撞，面粉袋数量只投影 `flour_remaining`，黑褐圆面包只在守恒账本 `held > 0` 时显示。视觉节点不能生成面粉、食物、技能、钱币或行为。

下面近景来自原研究存档的**可丢弃副本**：只为构图验证，由 `development_gm:overnight-baking-visual-only` 引用原存档公开求助 seq155 安装 5 份有限面粉；源档 SHA-256 在前后保持 `5d4d848dc4048ec588c872b72a3511bfe23c796b31c3eca22aa315bc1cb719b6`。这张图不代表烤炉已被正式采纳进共同世界。

![16 栋街区中的公共烤炉与有限面粉投影](night-20260918-sol-life/baking-point-integrated.png)

## 实机验证

验证只读取原研究世界后复制到隔离路径；源档及冷读副本 SHA-256 都是 `5d4d848dc4048ec588c872b72a3511bfe23c796b31c3eca22aa315bc1cb719b6`，世界仍为 seq166。

- 冷读十身体物理检查：58 项通过、0 失败；10 个 `CharacterBody3D`、10 个不同 RID、10 个启用胶囊、0 个超过 1 cm 的穿模，存档字节不变。原始结果见 [ten-body-cold-evidence.json](night-20260918-sol-life/ten-body-cold-evidence.json)。
- 未暂停物理检查：10 人全部落地、0 穿模；旅店老板保留的真实 pending `eat_ration` 在 45 个物理帧内移动 0.848 米。旧探针仍要求每人距存档起点小于 0.75 米，因此该轮 67 项中 66 项通过，唯一失败正是这次真实移动，不把它伪称全绿。原始结果见 [ten-body-motion-evidence.json](night-20260918-sol-life/ten-body-motion-evidence.json)。
- 16 栋生活街区检查：10 个居民、16 组门窗实体、40/40 条住所到公共地点路线可达、10/10 个采集工作点有空间、导航状态 `ready`。原始结果见 [living-quarter-report.json](night-20260918-sol-life/living-quarter-report.json)。
- `town_dialogue_ui_acceptance.gd`：14 项通过，确认玩家输入仍走权威事件路径且界面不发明回复。
- `town_gm_status_ui_acceptance.gd`：13 项通过，确认 G 键十行面板、结果截短、坏 JSON／世界不符／伪造 running 失败关闭，且世界内存与存档字节不变；0 个模型调用。
- 空闲段分类回归：真实 life06 样本（模拟时间 9167→9767、engine 0、0 API、排空完整）被严格识别为健康空闲，同时仍是 `not_exercised`／非通过；无时间推进、未结请求或引擎错误均不满足。手动入口 10 项测试通过，健康空闲保留 runner 退出码并显示保存完成语义。
- `town_merge_acceptance.gd`：200 项通过、0 失败，其中姓名牌／HUD 布局 145 项通过；1000×700 逻辑视口压力检查仍有可见姓名牌且不挡原 HUD。
- `town_baking_route_acceptance.gd`：53 项通过、0 失败，确认安装归因、有限面粉、账本守恒、独立知识和冷启动连续性。
- `town_baking_physics_acceptance.gd`：66 项通过、0 失败；居民胶囊不能穿过实体烤炉，工作围裙最近距目标 0.075 米、最小碰撞余量 0.525 米，真实遮挡会阻断观察；0 个模型调用。
- C# 构建：0 警告、0 错误。

![16 栋生活街区中的十位具名居民](night-20260918-sol-life/living-quarter-ten-residents.png)

引擎仍报告既有的 NavigationServer3D deprecated、agent radius voxel rounding 和 4 个 edge merge warning；它们没有阻止本轮 40/40 路线与碰撞检查，但不能写成“日志无警告”。

## 场景关系与限制

`demo_town.gd` 与真实生活不是两套模拟：它继承 `pcg/town.gd → living_town.gd → town_street.gd`，只是把正式 `living_quarter` 换成较重的 PCG `DemoQuarter`。本轮入口选择正式 `town_street.tscn`，因为 seq166 存档已经声明 `first-floor-market-quarter-v1`，可直接得到 16 栋住所、室内碰撞、门窗和十个真实身体；无需把静止美术预览冒充生活交付。

本轮没有执行新的付费居民决定，也没有证明治疗师已经回应 seq166 的求助、面包师已正式采用烤炉或十位 GM 已持续接力。公开生活窗口只是把这些真实缺口与已有成果放进可观察世界；后续 live run 和 GM 维护必须由协调任务在共同存档上继续。
