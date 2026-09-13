# Godot 动画材质实验室（Godot Anime Material Lab）

自包含的 Godot 4.7.2 Forward+ 小工程，用来在**内置 Shader 编辑器 + 实时预览**里研究
“逐表面卡通光照 + 可选深度描边后处理”的材质模板。

**声明**：这不是官方《刀剑神域》着色器，也不是任何行业标准；这里没有角色、没有脸部内容。

## 打开（推荐：一条命令 + 独立编辑器偏好）

```
pwsh -File C:/GodotAnimeLab/Open-Lab.ps1
```

`Open-Lab.ps1` 只启动**一个可见** Godot 编辑器，并把编辑器自己的偏好/缓存限定在工程内的
`_editor_profile/`（只改这个子进程的 `APPDATA` / `LOCALAPPDATA`，不动系统环境变量，也不碰你其它 Godot 工程的设置）。
所以编辑器可以正常保存自己的设置、布局和日志；PID、启动时间、可执行文件和完整参数记录在
`_work/editor-process.json`，重复运行不会开出第二个编辑器。

手动等价命令（不隔离偏好）：

```
"<Godot 4.7.2 mono 可执行文件>" -e --path C:/GodotAnimeLab --scene res://scenes/material_lab.tscn --max-fps 30
```

小插件 `addons/lab_boot/` 会在**图形**编辑器启动时打开 `scenes/material_lab.tscn`、切到 3D 主屏幕、
选中 `PreviewCamera`，并用 `EditorInterface.edit_resource` 打开共享 include 的代码编辑器（headless 时跳过）。

打开后 3D 视口直接显示：2 栋住宅 + 3 棵 V2 树 + 4 个小道具 + 地面 + 测试球。
- 默认视口是编辑器自由视角，可能只看到一部分模型。想一次看全 9 个模型：在场景树里选中 `PreviewCamera`，然后勾选 **3D 视口左上角的 `Preview` 复选框**（视口工具栏里的相机取景开关），视口就切到该相机看到的画面。**`F` 只框住当前选中的节点**：选中 `PreviewCamera` 时按 `F` 只会框住相机节点本身，不会显示九个模型。

- 场景树里选任意模型 → 检查器 → 材质，即可看到该表面的 Shader 参数。
- 双击 `shaders/anime_style.gdshaderinc`（共享风格 include）打开内置编辑器；改代码实时生效。
  （shader 代码是 Godot 的 GLSL-like 方言，不是 HLSL。）
- 视口导航（Godot 4 默认 3D 导航）：**中键拖动 = 旋转**、**Shift + 中键拖动 = 平移**、
  **按住右键 = 自由视角（W/A/S/D 移动）**、滚轮缩放、选中节点后按 **F** 框住它（`F` 只作用于当前选中的那个节点）。
- 改完记得 Ctrl+S 保存场景/资源。

## 逐表面光照 vs 后处理，为什么要两个一起用

- `shaders/anime_surface.gdshader`（逐表面，算在 `light()` 里）：每个表面按法线与光照方向做明暗分层。
  明暗边界跟着**几何**走，所以墙根、檐下、树干上的暗部有体积感，不是按屏幕像素切色块。
- `shaders/anime_post.gdshader`（可选，屏幕空间）：只做两件事 —— 细的深度轮廓线 + 轻微饱和度。
  它**不做**整屏硬化海报化，也不做全屏法线描边（植被法线很吵，会满屏噪线）。
- 组合理由：分层留在表面里最稳定；轮廓既可以做在后处理里（深度/法线边缘检测），也可以用
  **反向外壳（inverted hull）等物体空间几何**做——本模板只是**选择**了屏幕空间深度后处理这一条路线，
  并不是说轮廓"只能"这么做。逐表面卡通光照同样是本模板的**推荐**做法，不是所有 cel/动画风渲染的通用定律。

## 共享旋钮在哪（改一处，全部模型一起变）

`shaders/anime_style.gdshaderinc`：阈值、过渡宽度、受光增益、暗部/亮部偏色、艺术化地板色、
高光强度、贴图强度、风。所有预览材质共用同一个 Shader 资源 + 同一个 include。

- **重要**：材质（`materials/*.tres`）里存的是 uniform 的“当前值”。被材质覆盖过的 uniform
  不会再跟随 shader 默认值 —— 所以风格值全部写成 `const`（材质无法覆盖），材质只保存自己的
  数据：贴图、颜色、是否使用顶点色 / 贴图 / 风 / 双面法线。
- 想用真正的全局量（Project Settings → Shader Globals + `global uniform`）也行；本模板没有
  走这条路，避免两套覆盖机制混在一起（README 说明写在 `anime_style.gdshaderinc` 的注释里）。

### 30 秒上手（验证"改一处，9 个模型一起变"）

1. 双击 `shaders/anime_style.gdshaderinc`（用 `Open-Lab.ps1` 打开时它会自动弹出）。
2. 把 `const float STYLE_THRESHOLD = 0.42;` 改成 `0.7`。
3. `Ctrl+S` 保存：3D 视口里**全部 9 个模型**的暗部一起变多。
4. 想还原就把 `0.42` 改回去再 `Ctrl+S`。

## 后处理怎么关

场景树 → `PreviewCamera` → 子节点 `PostOutlineQuad` → 检查器里取消勾选 **Visible**（也可以删除该节点）。
它是相机前的一块 2x2 四边形，材质 `materials/anime_post.tres`：`outline_strength`、
`outline_thickness`、`outline_color`、`saturation`。

限制（实话）：它采样“不透明之后、透明之前”的屏幕纹理，看不到之后绘制的半透明物体，
所以它不是最终合成器；Forward+ 专用写法，其它渲染器未验证。

## 模型目录

`MODEL_CATALOG.md` + `model_catalog.json`（由 `tools/build_catalog.py` 生成）：只统计指定运行时
美术目录的模型文件，含 LOD 变体、字节数、相对路径与“已复制 / 已显示”标记。
它是**索引**，不是美术批准；没 manifest 的行显示名来自文件名。

## 源隔离

- 源仓库 `C:/InfiniteAincrad` 全程**只读**：没有写文件、没有 git 写操作、没有把编辑器指向它。
- `assets/` 里是**副本**（不是硬链接/符号链接）；源-副本 SHA256 成对记录在
  `_work/copy_manifest.json`（17 个文件全部 match）。
- `assets/residences/F1_Residence_0*_*.png` 是 Godot 导入 GLB 时**自动解包**的内嵌贴图
  （不是人工复制），保留是为了让 GLB 自身的贴图引用有效。

## 已知限制

- 风只对植被材质开启（V2 的 UV2.x 权重 + UV2.y 相位）；其它材质 `material_wind = 0`。
  想要省电：把 include 里的 `STYLE_WIND_SCALE` 设为 0。
- 住宅的 `Residence_metal / glass / plain` 在源工程里用 GLB 内嵌贴图；本实验只复制了 4 张共享
  albedo（+orm），这几类表面用纯色/顶点色近似，外观会与运行时略有差别。
- 法线贴图默认关闭（`material_normal_strength = 0`）以避免噪带；需要时给材质指定 `material_normal`。
- alpha 裁剪走 `discard`，不写 `ALPHA`（写 ALPHA 会让描边拿不到深度）；目前没有半透明材质。
- 首次打开或改 shader 的几秒内可能先黑一下，等编译完成即可。
- 没有光源时模型也不会全黑：那是 `EMISSION` 里的艺术化地板色，不是物理环境光
  （WorldEnvironment 的环境光已关闭）。
- 场景里的模型网格是 LOD1 的**快照副本**（`meshes/*.res`，约 30.7 MB），这是为了只留 LOD1、
  并且不让场景引用源工程贴图；源 GLB 仍然完整保留在 `assets/`，随时可以重建。

## 下一步（本模板没有实现）

脸部 SDF、手绘/插画化贴图、角色与表情、骨骼驱动 —— 都属于另外的课题，这里**没有**实现。

## 可以马上动手试的钩子

- `anime_style.gdshaderinc`：`STYLE_THRESHOLD` 调到 0.7（暗部更多）；`STYLE_SHADOW_TINT` 换成暖色。
- `anime_surface.gdshader`：把 `light()` 里的 `style_toon_ramp(ndl)` 换成硬 `step()`；或给 `EMISSION` 加边缘光。
- `anime_post.gdshader`：`outline_thickness` 调大、`saturation` 调到 1.4。
- `tools/build_lab.gd` 的 `models` 数组：换/加 LOD1 资产后重建场景（命令见 `_work/RESULT.md`）。
