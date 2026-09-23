# 居民观察（seq266→seq323，2026-09-23）

本轮从 seq266 的真实提案继续运行多个有界 live 窗口，修复 Well-keeper 适配器后又结算 1 次，完成三次 300 秒多居民连续窗口，处理一次 Baker 的长度恢复，又完成一次 600 秒长窗口和一次冷启动物理 job 恢复，累计 59 次新增 Kimi NPC 调用。账本从 6.2679476 元增至 7.6118814 元，新增 1.3439338 元；没有未知费用、预留费用或未排空的上游请求。最新公开 checkpoint 是 `seq000323-2d80c92778c34dc7.world.json`。

## Flint 与 Rowan 的真实修理链

这条链在正式续存世界中完整发生：

1. Rowan 在 seq266 真实提出 2 Col、收取时付款的刃口修理合同。
2. Flint 在 seq267 真实接受；2 Col 进入 Rowan 的预留资金。
3. Rowan 在 seq268 真实交付斧头。
4. Flint 在 seq275 完成实体 60 秒工作，消耗 1 铁，斧刃恢复到 100。
5. 新增的收货唤醒逻辑让 Rowan 在走到 Flint 身边、看到 `contract:collect` 首次出现后重新获得一次模型回合；他在 seq285 真实选择收货。
6. 权威状态记录 `axe_repair_paid`：合同为 `collected`，预留 Col 为 0，斧头 custodian 回到 Rowan，刃口与斧柄均为 100。

收货后双方又自然进行了简短确认对话。没有重复付款，也没有把聊天或旧合同误判为完成。

## 本轮修复的运行时缺口

原先居民在距离不足时看不到收货动作；之后即使走入 3 米交接范围，30 分钟冷却也不会重新观察。`game/agents/town_turns.gd` 现在只在 `contract:collect` 从本人的旧菜单中首次出现时唤醒一次；居民若选择别的动作，仍回到普通冷却，不会重复付费催促。

现有 `town_repair` 离线验收为 30 checks、0 failures；live 窗口实际验证了新唤醒路径。

## Provider 错误已清除

Well-keeper 的持久 `brain_run_failed` 已经完成一次新的真实回合并结算为 `settled`。根因是运行程序集未刷新，且失败分类层把底层网关固定错误统一压成了通用错误；重新构建程序集后，副本世界中的真实 Kimi 调用正常通过，世界推进到 seq290。没有重放旧请求，也没有修改旧回执；账本仍为零未知、零预留、零未决。

## 多居民连续窗口

窗口 07 从 seq290 连续运行 300 秒，12 次上游请求全部结算，Godot 正常退出并排空 24 个网关工作线程。12 次新决定覆盖 baker、carpenter、gardener、healer、smith、weaver 六名居民，新增 10 个生活事件；六名未重新决策的居民保持 settled，十名居民最终均无 provider error。窗口 08 从 seq300 又结算 12 次并推进到 seq316；Baker 的一次 516 字符 reason 被如实记录为 `reason_too_long`，没有丢失或重放。下一次冷启动完成了唯一允许的 length recovery，Baker 在 seq317 正常观察，原始失败进入 reviews，当前十名居民再次全部 settled、无 provider error。窗口 10 从 seq317 再运行 300 秒，Smith 和 Carpenter 产生 3 次新决定并推进到 seq320，Godot 排空 6 个网关 worker。窗口 11 从 seq320 运行 600 秒，2 次请求结算并推进到 seq321，4 个 worker 全部排空；边界只留下一个可恢复的 Fisher rest job。窗口 12 从 seq321 冷启动 120 秒，先完成该物理 job，再结算 1 次模型决定并推进到 seq323，2 个 worker 全部排空。最终十名居民无 provider error、无 pending 物理 job，历史 rejected 仅为资源不足的权威结果。

## 证据

- Provider 清除后的居民决定与事件报告：`seq266-to-290-provider-cleared.json`
- 多居民连续窗口报告：`seq290-to-300-multi-resident-window-07.json`
- 第二窗口及 Baker length recovery：`seq300-to-317-window-08-recovery.json`
- 第三窗口连续性报告：`seq317-to-320-window-10.json`
- 600 秒长窗口报告：`seq320-to-321-window-11.json`
- 冷启动物理恢复报告：`seq321-to-323-window-12.json`
- 最新世界 checkpoint：`../../checkpoints/seq000323-2d80c92778c34dc7.world.json`
- 开发者用量快照：`../../usage/seq000323-198a9494f7e2811d.usage.json`
