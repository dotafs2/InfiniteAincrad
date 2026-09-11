# H22 城镇技能转介（第三方转介）离线验证报告

日期：2026-09-12
范围：离线 fixture 验收，仅涉及 `game/core/town_trade.gd` 与 `game/tests/town_skill_referral_acceptance.gd`。

## 结论（诚实边界）

- 保留：选择 / 拒绝 / 等待三种结果均被保留，不被伪造为成功。
- 规范说明：A 在**原始告知**处确实是技能持有者；后续历史声明**不**代表当前能力。
- A 仅在**原始告知**处拥有技能归属；B 必须**直接收到**告知；C 只能获得**带归属的历史知识**。
- A/B 之后变为不活跃、距离过远或技能丢失，**不会抹除历史**。
- 以上**不构成**对当前技能或当前可用性的证明。
- A→B 的来源被保留；间接的 C **不能**再向他人转介。
- 运行时报价仍受**当前接近度 / 活跃状态**门控；工作接受仍检查**实际能力与资源**。
- 来源结构一致性**不等于**对完整存档被恶意编辑的防护。
- 任何**生成的发言都不授予技能**；矛盾的可选发言与规范文本分离。

## 强反对意见与最小验证

强反对：无差别转介会把一句陈述变成全局/当前的“全知”。

最小验证（证明这是有限边界，而非自主生命）：

1. B→C 发生时 A 实际距离很远；
2. 无效的、未被看见的来源被拒绝；
3. C 不能再转介；
4. 当前技能丢失后仍保留历史声明。

结果标签：**有限边界成立**（非自主生命，非当前能力证明）。

## 验收证据

- 专测：`town_skill_referral_acceptance`，121 项检查，0 失败。
- NPC 付费调用：0。DeepSeek 开发用量单独记录于 `usage.json`（与 NPC 付费调用无关）。
- 日志：`tests/town_skill_referral_acceptance.stdout.log`（stderr 为空日志并存）。
- 套件：27 套件全部通过；3 个校验器全部通过。

### 覆盖的行为

- 收据幂等；来源变更产生冲突；
- 过期/远距离目标在**宿主移动之后**被拒绝且字节不变；
- 忙碌发言者被阻断；忙碌听者仍可听见；
- 畸形来源与原始主体被实时拒绝；
- 持久化与属性不变量。

## 范围限制

- 仅离线 fixture；**未**改动 NPC provider，**未**新增 NPC 付费运行。
- **未**重建旧私有世界。
- **未验证真实模型自主转介**；仅离线 fixture 中被选中的动作。

## 复现命令

```
python -X utf8 tools/run_godot.py --godot <Godot.NET.exe> --name skill-referral --timeout 60 --out <logsdir> -- --headless --script res://tests/town_skill_referral_acceptance.gd
```

## 证据链接

- [测试汇总](town_skill_referral_2026-09-12/tests.json)
- [来源哈希](town_skill_referral_2026-09-12/source_sha256.json)
- [用量](town_skill_referral_2026-09-12/usage.json)
- [专测 stdout](town_skill_referral_2026-09-12/tests/town_skill_referral_acceptance.stdout.log)
- [专测 stderr](town_skill_referral_2026-09-12/tests/town_skill_referral_acceptance.stderr.log)
