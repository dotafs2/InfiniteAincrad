# H26 受阻取材：个人失败感知与后台GM诊断（离线）

> GPT-6复核状态：本地候选，尚未接受或发布。长指令ID、取消成功反馈与32条关闭历史＋10个在途任务并存仍需补验收；下文通过记录不代表这些额外情况已通过。2026-09-12 10:26模型流中断，代码和测试已保留，未知费用单列，未重放工具。用户随后授权本次例外继续，收尾修复已恢复。
日期：2026-09-12。范围：现有 Godot 城镇材料取料链的最小真实接通——居民在
取料途中**物理上没有进展**时得到一条个人生活事实，保留未完成的任务，并可被
调度后在“等待/继续”与“自愿放弃这次出行”之间选择；同时由**独立只读投影**
向后台上层暴露一条去重、可处置的问题证据。本轮不接模型、不接 GM 服务、不扩人口。

## 做了什么

- `game/core/town_materials.gd`：新增有界的**物理行进观测** `observe_material_travel(id, position, elapsed)`。
  场景提供碰撞解算后的实际位置与**未暂停**秒数；世界判定“有剩余距离但位移/接近量均低于阈值”为停滞。
  阈值：`MATERIAL_BLOCKED_NO_PROGRESS_SECONDS = 8.0`，位移/接近 epsilon `0.05`，到达半径 `0.45`。
  停滞达标后持久化一条 episode（`materials.blocked`，键与 `episode_id` 均为
  `material_blocked:<resident>:<command>:<n>`，`n` 由持久计数器单调分配），
  并只追加**一条**个人事件（`material_travel_blocked`，文本“我没能到达那个材料点；这次取材任务还没有完成。”，
  仅带不透明的 `episode_id` 归属，无坐标/碰撞/测量字段）。**同一作业可反复受阻**：
  上一次 episode 关闭后再次停滞会新建一条可归属 episode，各 episode 各自只上报一次；
  已关闭的 episode 是历史事实，后续任何观测都不会改写它的结果字段。
- `game/agents/town_turns.gd`：仅当存在**已上报且仍待办**的材料受阻 episode 时，才允许调度该居民；
  普通未受阻待办仍然不可调度。等待会走既有 1800 模拟秒冷却，不产生付费忙循环。
- `game/core/town_materials.gd`：受阻时在选项中加入**只针对这次材料出行**的
  `material:cancel:<原命令>`；放弃会把**原命令**记为终态 `rejected`+`material_cancelled`
  （`quantity = 0`，零资源转移），清除任务，episode 记为 `closed/resident_cancelled`，
  并保留全部历史。未给其他合同增加通用取消。该命令在改动任何资源/任务/历史之前，
  先检查 `godot.commands`、`materials.commands`、`trade.commands` 三本日志：复用他人已接受
  命令 ID（含原材料命令 ID、其他居民的材料命令 ID）一律 `command_conflict`，且不覆盖原日志项；
  同一放弃命令重复提交按 payload 幂等返回 `duplicate`。
- 进展真正恢复时 episode 记为 `closed/progress_resumed`，历史事实不删除。
- 关闭历史与活跃记录**分开设界**：`MATERIAL_BLOCKED_CLOSED_LIMIT = 32` 只裁剪最旧的已关闭
  episode（个人生活事件永远保留），活跃 watch/open 每条居民至多一条，因此 10 名居民 + 32 条
  关闭历史可以同时存在而不会写档失败。
- `blocked_material_diagnostics()`：独立只读后台投影，含 `world_id / resident_id / job_command_id /
  episode_id / source_id / material / opened_elapsed / no_progress_seconds / remaining_distance /
  progress_evidence`，`report_count = 1`。它不进 `life.events` 收件人，也不在
  `resident_view`（因此不会进入 `BudgetGatewayProvider` 的个人白名单）。
- `game/spatial/town_street.gd`：在既有 0.5 秒事务批次内、`advance` 之后，把**实际物理位置**
  与该批次未暂停秒数交给世界观测。暂停时不进入该路径，因此暂停时间不是受阻时间。

## 排除项（针对最强反驳）

“静止即缺陷”会误判**暂停**与**已在工作点**的居民，也会误伤**正在绕行**的居民。本轮用物理证据排除：

1. 暂停：`paused` 时物理帧提前返回，观测与时钟都不推进（场景 1）。
2. 已在目标：到达半径内视为在施工，累计清零（场景 2：12 秒内任务计时正常增长，仍无任何上报）。
3. 正常行进/绕行：只要位移或接近量达标就清零停滞计数（场景 3：H24 短距离绕障仍成功到达并取回 1 份材料）。
4. 只有“待办取料任务 + 有剩余距离 + 位移与接近量都低于阈值 + 未暂停”才可能上报。

## 实际执行

Godot .NET 4.7.2（console），`game/tests/town_material_blocked_probe.gd` 为离线 SceneTree 探针，
fixture 控制器是**确定性本地控制器**（无网络、无 Kimi 调用，`paid_kimi_calls = 0`）。
证据目录：`tmp/chain-20260912/task01-tests/repair-final/`（评审修复后的最终代码；
不触碰任何私有存档）与 `tmp/chain-20260912/task01-tests/repair7/suites/`
（同代码的受影响回归）；`final*` 是修复前的等价重复批次。

| 场景 | 检查 | 失败 | 关键实测 |
| --- | --- | --- | --- |
| paused-enclosed | 21 | 0 | 10 秒暂停 + 封闭目标：无 episode、无事件、任务计时 0、钱物料不变 |
| at-target | 23 | 0 | 站在料点 12 秒：无 episode、无事件、任务计时 > 5、未离开工作点 |
| detour-crate（H24 短绕障几何） | 22 | 0 | 横向绕行 max\|x\| = 2.047（H24 记录 2.02）、到达并 `material_recovered` 1 份、库存 3→2、无任何受阻上报 |
| recurring-block（同一待办作业） | 32 | 0 | 受阻→真实位移恢复→再次受阻：episode 1 `progress_resumed`、episode 2 `resident_cancelled`（两个 episode ID、两条个人事实）、放弃后原命令零转移、冷读通过 |
| blocked-enclosed（全封闭目标） | 125 | 0 | 见下 |

状态级验收 `game/tests/town_material_blocked_state_acceptance.gd`（离线世界 API，无场景无模型）：
206 项检查 0 失败，含命令日志冲突（复用 `wait`/原材料/他人材料命令 ID 全部 `command_conflict`
且原日志未改写、任务未取消、历史未增长）、异居民取消、未知目标、未列 provenance、带 speech、
幂等重复放弃、closed 不再二次取消、同一作业 block→progress→block、重复停滞不重发事件、
后续 tick 不改写已关闭结果、10 名居民 × 4 轮共 40 次受阻+放弃后：关闭历史 = 32（设界生效）、
活跃记录 0、个人受阻事实 46 条全部保留、`blocked_seq` 单调、冷读逐字节一致且校验通过、
设界后仍可新建 episode。

blocked-enclosed 实测：

- 封闭目标 + 实际物理帧：**8.085 秒**后上报一次；`no_progress_seconds = 8.27 ≥ 8.0`；
  6 秒时仍无上报；停滞期间位移 `0.0`；任务保持待办且施工计时 `0.0`。
- 个人事件恰好 1 条，收件人为本人；字段集恰为 `type/actor_id/recipient_ids/operation_id/source/
  source_id/material/episode_id/text/seq/event_id`，文本无数字/坐标/碰撞字段；`resident_view` 不含
  `no_progress_seconds`/`observed_position`/`target_position`/`remaining_distance`/`progress_evidence`。
- 后台诊断恰好 1 条：`episode_id = material_blocked:fixture:smith:fixture:blocked-open:1`，
  `job_command_id = fixture:blocked-open`，`remaining_distance = 2.0`，`report_count = 1`。
- 再跑 6 秒重复观测：个人事件仍 1 条、诊断仍 1 条、任务仍待办、钱物料不变。
- 逐字节副本冷恢复：episode/事件/诊断各 1，任务待办，`elapsed = 0.0`，库存 3、钱物合同不变；
  重启后重新加载场景并再跑 8 秒**不会重新上报**。
- 调度：未上报且待办时 `ready_resident()` 不返回该居民；上报后返回；`wait` 之后不再立即调度
  （无付费忙循环），再次显式调度选择放弃。
- 放弃：原命令 `rejected` + `material_cancelled`（`quantity = 0`、`ok = false`），任务清空，
  episode `closed/resident_cancelled`，个人历史与钱物料不变；同一命令重复放弃返回 `duplicate` 且状态不变；
  之后正常选项（含再次取料）重新出现，且不会给出陈旧取消。
- 替换任务：放弃后新开一条取料命令，旧 episode 不提供取消、不产生诊断（陈旧任务不继承问题）。
- **替换任务在真实物理下继续运行 16 秒**（不再以暂停提交收尾）：旧 episode 的
  `closed_reason = resident_cancelled` 与 `cancel_command_id` 保持不变（不被改写为 `job_replaced`），
  新任务得到自己的 episode（`...blocked-open-2:2`，`opened_elapsed = 31.0`）与自己的个人事实，
  保存未失败（场景未因写档失败暂停），随后冷读校验通过。
- 新字段校验：去掉/复制个人事件、open 带关闭原因、open 未上报、命令/居民/episode/key 不匹配、
  删任务、`blocked_seq` 非法、复制 episode ID、事件归属到别的 episode 等 12 种篡改全部被
  `_validate_state` 拒绝。
- 旧档兼容：同时验证两种旧形状——删除 `blocked`+`blocked_seq`（最老）、仅删除 `blocked_seq`
  （前一版）——两者都能加载；无 blocked 键时无 episode、无诊断。

复核命令（可复现单项）：

```
<Godot console> --path game --headless --script res://tests/town_material_blocked_probe.gd -- \
  --fixture=<...>/fixture-base.json --town-save=<...>/saves/blocked-enclosed.json \
  --blocked-probe-restart=<...>/saves/blocked-enclosed-restart.json \
  --blocked-probe-output=<...>/out/blocked-enclosed.json --blocked-probe-scenario=blocked-enclosed
```

既有回归（`tmp/chain-20260912/task01-tests/final3/suites/`，27 个入口全部退出码 0、0 失败）：
town_materials 58、town_material_visibility 95、town_replan 66、town_feedback 27、town_turns 29、
town_trade 63、town_life 31、town_social_trigger 19、town_completion_escrow 57、town_skill_notice 95、
town_skill_referral 121、town_specific_help 33、town_handover_context 17、town_contract_speech 20、
town_public_speech 17、town_social 24、town_visitor 17、town_repair 30、town_dialogue_ui 14、
town_controller_recovery 17、town_online 63、town_model_continuity 92、town_validation_limit 5，
以及 core/decision_boundary/oga/gateway 校验器 0 失败。

## 限制与假设（未宣称）

- 8 秒阈值是按 60Hz 物理帧的实测定值，**未**与真实 Kimi 居民或长时间运行调优；
  帧率只会通过 `delta` 影响累计，暂停不计时。
- 一个长期把身体压在障碍上、位移始终为 0 的居民会被上报（这是物理事实，不是模型猜测）；
  若随后恢复移动，episode 关闭为 `progress_resumed`，但个人事件保留。H24 也证明该转向
  在“已贴住障碍”的姿态下可绕行，而“先直线走进障碍”的姿态可能长时间零位移。
- 探针是离线确定性 fixture 控制器，不证明模型会选择放弃或等待，也不证明 10+10 或自主 GM 修复。
- 本轮只提供只读投影与单人流程；没有 GM 认领/实现/发布，没有真实 provider 调用。
- `materials.blocked` 只保留最近 32 条 episode（个人事件仍是长期事实）。
- H24 四个未提交文件未改动、未发布；其原探针（固定写入 H24 沙箱目录）本轮未重跑，
  改在新探针内复现同一 crate 几何与绕行量级。
