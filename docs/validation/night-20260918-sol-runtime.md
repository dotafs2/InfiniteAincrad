# 2026-09-18 Sol Runtime 阶段交付

## 已交付

真实配置位于 `D:/Dev/vibeGamingDemo1/ThreeHearthsVillage/Saved/ThreeHearths/api-config.json`。只读检查确认文件存在，端点、模型、thinking 模式和非空密钥字段符合当前 Kimi 网关要求；本文不包含密钥。

首个真实续跑没有发出 Kimi 请求。根因不是网络延迟或三请求排队，而是所带账本的授权截止时间仍为 2026-09-17 09:00。编译适配器先把一次尝试持久化为 `Unknown=true`，随后账本才拒绝过期授权，导致世界留下误导性的 `brain_run_failed`。

提交 `6f5286b` 在 `CarriedLedgerGate` 构造时检查 `ledger.deadline_reached()`。因此过期账本会在创建 provider、loopback 服务器、输出目录和 Godot 进程之前停止。离线回归证明过期拒绝不改变 guard 或请求行，并且模型调用数为零；`test_town_model_validation_budget` 共 25 项通过。

主协调任务随后核对五个失败回执的 provider operation 在旧、新账本均不存在，并使用仓内既有 `recover_town_controller_cli.gd` 显式恢复，未产生模型调用。第二个真实回合使用新独立夜间账本：10 次请求全部 settled，`Unknown=false`，无模型错误，停机 drain 完整；世界在约 81 秒内从 seq167 推进到 seq173。

## 长跑中的材料通路复核

第三个真实回合继续使用同一独立夜间账本，并保持单并发。它在 03:38 正常退出：32 次新请求全部 settled，`Unknown=false`，模型错误为空，engine exit 0，网关 drain 完整；世界在 899.52 模拟秒内从 seq173 推进到 seq201。夜间账本累计 42 次 settled、零 pending，覆盖九位不同居民；牧人尚未得到本夜新回合。累计已结算费用为 1.0711735 CNY。

面包师的旧取料命令一度只在 81 秒内增加约 4 秒工时。只读采样显示其在材料点附近 0.7–1.4 米往返，而阻塞检测因持续位移没有把它判为静止。对 seq192 存档副本的真实场景探针进一步确认：

- 材料目标位于导航网格上，路径终点距目标约 `0.000005 m`，不是静态几何不可达；
- 先前完成取材的木匠停在目标约 `0.44 m` 内，目标点的真实胶囊探测命中木匠；
- 工作圈内仍有多处同时无碰撞且在导航网格上的站位；24.02 秒隔离物理运行中，面包师最小距目标 `0.058 m`，工时增加 `12.4 s`；
- 正式世界最终在 `elapsed_seconds=6907.32` 自然完成原命令 `turn:shared:baker:2:28`，回执为 `material_recovered`，没有传送、强制行为或导航补丁。

因此实际瓶颈是共享单工位被前一位居民占据时，RVO 围绕精确目标产生的低效绕行，而不是永久死锁。截止前不修改通用导航；若以后优化，应给材料工位增加排队或多个可用接近点语义，并保持原有碰撞和 0.45 米工作门槛。

## 完整冷恢复

life03 的进程树以 exit 0、活动进程 0、全部成员退出结束，网关同时记录 `drained_complete=true`。随后复用既有 `private/gm-npc-research-20260917/verify_cold_restore.py`，只对验证器自己的不可变副本执行十次 `observe` 和一次 `stop`，模型调用数为零。

冻结文件 `gm-source-seq201.json`、正式 world、验证器的 `immutable-source.json` 和冷进程退出后的 world 均为 2,182,660 bytes，SHA-256 同为 `ac592d2007244e0b38197919d904b53d1b1264f78ffc012b345ee04124115f4f`。验证结果：

- `full_state_equal=true`、`selected_core_equal=true`、`resident_turn_projection_equal=true`；
- 十个 stable identity 的顺序和值完全一致；
- 1 件物品和 1 份 `collected` 合同完全一致；
- 铁匠未完成的 `turn:shared:smith:1:19` / `eat_ration` 任务仍为 `elapsed=3.6166666666666663`；
- 十份 resident-turn 记录仍为 settled，逐人历史计数 `23,28,18,21,19,7,20,26,26,17`，总计 205；
- turn shape errors 和 observation errors 均为空，源文件与不可变副本均未改变。

## 公开对白微修

seq201 的真实回复曾把内部技能 ID `wood_repair` 直接说进居民公开对白。提交 `5d3c7a8` 只补充 Kimi 网关的现有居民提示：结构化 action/tool/skill/capability 字段继续使用原始 ID；公开对白改用自然简体中文技能名称或描述，不谈程序、API、system prompt、GM 或后台操作。它不替换模型输出、不改写既有历史对白，也不扩大为世界观提示。`dotnet build` 为 0 warning / 0 error，离线 `gateway_acceptance.gd` 通过且 paid calls 为 0。

## 尚未完成

第二回合的 10 次请求只覆盖七位不同居民：水槽看守三次、园丁两次，铁匠、旅店主、渔夫、治疗师、织工各一次。第三回合已把夜间覆盖扩大到九位，且面包师旧取料作业已经完成；牧人仍没有本夜新模型回合。当前证据仍不能表述为“十位居民都完成了新模型回合”。

现存 1800 秒空闲冷却尚无证据需要改写。后续仍应通过自然运行观察牧人到期与场景移动；不应通过强制动作或伪造时间来凑齐覆盖率。
