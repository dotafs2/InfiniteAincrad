# 自愿技能介绍与有来源的个人记忆（H21）

日期：2026-09-12 · 状态：离线夹具验证通过（H5 仍为部分完成）

## 实际收益

- 居民可以主动介绍自己**真实拥有**的技能，而不是被注入全镇知识。
- 一次介绍只送达一个实际接收者；说话者本人也收到该条有来源的记忆。
- 历史通知在说话者之后不再活跃时仍然保留，可被已知说话者引用。
- 无来源的自由发言不会被当作新的结构化技能声明。
- 没有任务强制、没有强制成功；未使用不会被冒称为已兑现。

## 验证结果

- 专项：95 项检查 / 0 失败 / NPC 模型调用 0；DeepSeek 开发调用另记。
- 全套件：26 套（原 24 + 合并场景 + 技能通知），全部通过；3 个校验器通过。
- 冷读字节一致；无自动知识注入；无关金钱/合同/资产未改变。

## 限制

- 这是**离线夹具验证**，不是自主模型发现。
- 历史通知是接收者读取历史来源，不是第三方转介（第三方转介尚未实现）。
- 父节点 H5 仍为部分完成：真实自主发现与第三方转介尚未验证。

## 下一步

- 基于直接来源的第三方转介。
- H20 实机视觉（日照过曝、居民标签重叠）。
- 不更换 NPC 提供者。

## 来源与复现

- 源码：`game/core/town_trade.gd`、`game/tests/town_skill_notice_acceptance.gd`
- 证据：[tests.json](town_skill_notice_2026-09-12/tests.json)、[stdout](town_skill_notice_2026-09-12/town_skill_notice_acceptance.stdout.txt)
- 复现命令：`python tools/run_godot.py --godot <Godot.NET.exe> --name skill-notice --timeout 60 --out <logsdir> -- --headless --script res://tests/town_skill_notice_acceptance.gd`
