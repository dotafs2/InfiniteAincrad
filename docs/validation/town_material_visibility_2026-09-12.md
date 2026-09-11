# 城镇材料可见性验证报告（2026-09-12）

## 结论摘要

本次验证针对城镇材料可见性修复，在 Godot .NET 4.7.2 headless 3D 物理环境下执行。基线提交 `2713c667234210cf78c35ec25925c246a9f9d5c2` 实际运行 25 项检查、0 失败：真实墙体射线命中为 true，测试居民原先不知道材料，墙体存在时旧逻辑仍写入库存 3 并给出取料选项。生产补丁后实际运行 95 项检查、0 失败：有限消耗由 3 变为 2，另一名工人整理材料 60 秒实际取得 1 份铁；墙体阻挡的居民历史 3 持续存在，移除墙体后看到 2，且新来源事件保留旧 3 记录不变。来源与居民铁资源守恒；金币、物品、契约、技能均未变化。以上仅为个人观察，远处第三名居民未得到材料知识。

## 证据与计数

- 基线：25 项检查、0 失败（`baseline.stdout.txt`、`baseline.json`）。
- 生产补丁后：95 项检查、0 失败（`tests.json`）。
- 城镇场景 headless：200 项检查 = 历史 197 + 3 项运行时绑定断言（`scene.json`）。`Scene.paused` 世界字节未变；回调实际对象在 tick 前绑定到核心必需标志。
- 完整 28 个套件 + 3 个资产验证器干净通过，时间戳 2026-09-11T19:44:16.859296Z。
- 本轮无新增图形截图；旧 H20 双渲染后端 197 项证据保留，未夸大。

## 架构与范围

实际城镇街道在普通离线/网关/恢复路径中，在推进前绑定视线；必需模式无效时绝不回退。独立遗留核心/headless 夹具默认明确标注为邻近性，保留原状；不声称通用 headless 修复。新来源观察为 `source host_line_of_sight_observation`；视图标签来自实际原始事件，不重写旧邻近性历史。传感器为 3 米逻辑范围内的单条物理射线，指向实际材料显示；所有物体碰撞体不透明，无透明材料语义，360 度方向不是视锥/相机/像素。非自主模型使用，无 NPC 运行时提供者变更，NPC 付费为 0；DeepSeek 编码使用（含失败/截断调用）记录于 `usage.json`（非 API 账单），旧历史保留。

## 最强反对与反例

仅添加视线 API 可能仍让世界授予库存或抹除旧知识；实际核心事务测试覆盖墙体 3→2→看到 2，且实际场景绑定限定作用域。玩法收益是真实的个人陈旧信息加实际有限消耗，而非仅架构本身。

## 限制与后续

无效/空/非布尔/已释放/分离观察者/组件或隐藏视觉均拒绝新感知。部分守卫测试直接调用组件，不声称所有变更路径已单独测试。同一夹具冷加载字节与历史精确一致。加载/重绑时不自动观察。N5 仍为未来工作，完整城镇未完成。下一步在声称导航缺陷前检查实际取料路径可达性。原始私有 13 身份检查点未由夹具重建或恢复。

## 复现命令

聚焦命令：`python -X utf8 tools/run_godot.py --godot <Godot.NET.exe> --name material-visibility --timeout 120 --out <logsdir> -- --headless --script res://tests/town_material_visibility_acceptance.gd`。实际完整运行经由被忽略的集成审查辅助工具，非公开入口；可按上述方式复现单项测试。

## 链接

- [baseline.stdout.txt](town_material_visibility_2026-09-12/baseline.stdout.txt)
- [baseline.json](town_material_visibility_2026-09-12/baseline.json)
- [tests.json](town_material_visibility_2026-09-12/tests.json)
- [scene.json](town_material_visibility_2026-09-12/scene.json)
- [source_sha256.json](town_material_visibility_2026-09-12/source_sha256.json)
- [usage.json](town_material_visibility_2026-09-12/usage.json)
- [tests/town_material_visibility_acceptance.stdout.log](town_material_visibility_2026-09-12/tests/town_material_visibility_acceptance.stdout.log)

来源清单包含六个游戏文件。主要 API 参考：[Godot物理射线说明](https://docs.godotengine.org/en/4.7/tutorials/physics/ray-casting.html) 与 [射线查询参数](https://docs.godotengine.org/en/4.7/classes/class_physicsrayqueryparameters3d.html)。查询在物理回调内执行，排除自身碰撞体的 RID，并启用 `hit_from_inside` 以检测射线起点位于碰撞体内的情况。
