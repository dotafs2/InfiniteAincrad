# 2026-09-18 第一轮美术交付

已交付三件可独立加载的纯视觉 Godot prefab。新增付费请求 **0**，实际新增积分 **0**，无供应商待取回任务。未修改主场景、生活逻辑、原研究存档、ART_STYLE 或 HISTORY。

## 盘点与范围

现有库已含 16 栋房屋、壁炉、烘焙工具架、手磨、餐食、桌椅与货运物件；不重复生成这些资产。实际公共烘焙组件 `town_baking_points.gd` 仍使用方块炉和面粉袋。当前缺口是可以接入真实有限库存显示、尺寸与既有通行规则兼容的独立资源。

本轮炉具复用 `game/assets/floor1/living_props_20260916/hearth.glb` 的 Meshy 炉台、拱口与贴图，裁掉高烟道并加石质封顶，再适配既有炉体体积。面包复用 `Art/Generated/TravelCargo20260912/geometry.py` 已有 `Geo/loaf` 几何配方，单独导出。面粉袋为本轮离线 Blender 制作，沿用麻布、麻绳和麦穗的现有第一层配色方向。没有向 Meshy/Tripo 重复提交。

## 集成接口

三件资源位于 `game/assets/overnight20260918/`。所有根节点原点都在底面中心，Godot Y 向上、正面 +Z，实例缩放 `(1,1,1)`。材质已内嵌 GLB，不依赖私有目录或外部贴图路径。

| prefab / 根节点 | 实际包围尺寸 X/Y/Z（米） | 三角面 | 材质 |
|---|---|---:|---:|
| `baking_oven.tscn` / `BakingOven` | 1.00 / 1.00 / 0.76 | 13,489 | 2 |
| `flour_sack.tscn` / `FlourSack` | 0.24 / 0.30 / 0.24 | 2,636 | 3 |
| `bread_loaf.tscn` / `BreadLoaf` | 0.36 / 0.15 / 0.18 | 1,352 | 3 |

根下固定子节点 `Visual` 是 GLB 实例；prefab 无脚本、碰撞、库存值、动画和 API。展示脚本 `preview.gd` 是独立验收入口，不挂在 prefab 上。

- 炉具 AABB 精确覆盖 x[-0.5,0.5]、y[0,1]、z[-0.38,0.38]；保留工程现有 `OvenCollision`，不要再创建碰撞。已有 +Z 炉前工作点与 `(0,1.05,0)` LOS 目标不改。
- 袋子底面原点与旧方块的中心原点不同；若沿用旧 sack.position，Y 要减去 0.15m。数量始终由真实 `flour_remaining` 控制，耗尽时隐藏，不让资源自行刷新库存。
- 面包只在实际持有/完成生产时显示；本 prefab 不证明居民已烤出面包。没有把固定装饰面包放入公共点。
- 小道具不建议加入碰撞；如以后用于桌面独立可拾取物，由工程按交互需求另加简单形状。

## 聚焦验证与实渲

Blender 5.2.1 导出：三件均无退化三角面。Godot 4.7.2 .NET 在独立临时项目中通过真实编辑器导入，随后加载三个原始 `.tscn`、测量导入后 AABB、检查脚本/碰撞数，再用 Compatibility 实际 viewport 渲染并保存 PNG。三件尺寸与纯视觉检查全部通过；导入/渲染进程均正常退出，最终 stderr 无错误。

![Godot 三件资产正面](../../Art/Generated/Overnight20260918/captures/01-godot-front.png)

![Godot 炉具近景](../../Art/Generated/Overnight20260918/captures/03-godot-oven-close.png)

截图来自真实 Godot 渲染，没有图像生成或截图修补。独立画廊无居民、无模型调用，不构成真实街区采用、导航通过或持续生活的证明。后视角和结构化验证记录见 `Art/Generated/Overnight20260918/captures/`；源资产指纹、导出指纹、面数与来源见同批次 `manifest.json`。

## 复现

在本工作树根目录运行：

```powershell
& 'D:/SteamLibrary/steamapps/common/Blender/blender.exe' --background --factory-startup --threads 4 --python Art/Generated/Overnight20260918/prepare_assets.py
& Art/Generated/Overnight20260918/preview_assets.ps1
```

第二条命令复制本批资源到 ignored 独立预览目录，使用已提供 Godot 路径与命令级 `DOTNET_ROLL_FORWARD=LatestMajor`，后台预览窗口 Hidden，记录自己创建的 PID。输出截图不依赖整个游戏场景或 C# 编译。正式项目正常 Godot 导入后可直接加载 `res://assets/overnight20260918/baking_oven.tscn`。

## 限制与后续

这是复用资产的尺寸适配，原 Meshy 炉具仍有近景贴图纹理和不规则网格；无 LOD，尚未做全街区性能测量。袋子与面包是较简洁的项目原生几何。生活任务已确认接入时保留唯一实体碰撞，并改为显式面粉袋数组；缺失资源时保留旧原语回退，不让资产阻塞生活入口。后续仅围绕协调方实际观察到的场景缺口继续。
