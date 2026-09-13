# Godot Shader 实验室快照 · 2026-09-13

这里保存 `C:/GodotAnimeLab` 在本次备份时已经写入磁盘的文件。原实验室和正在使用的 Godot 编辑器没有被修改。此目录是独立 Godot 项目，入口是本目录的 `project.godot`，并非主游戏的 `game/project.godot`。

## 从 Git 恢复后打开

1. 安装 Git LFS，克隆此分支后运行 `git lfs pull`，取得 GLB 和 `.res` 网格文件。
2. 打开 Godot 项目管理器，选择 **Import → Browse**，找到本目录的 `project.godot`，然后 **Import & Edit**。原机使用 Godot 4.7.2、Forward+。
3. 在 **FileSystem** 中打开 `scenes/material_lab.tscn`。选择 `PreviewCamera` 后勾选 3D 视口的 **Preview**，可看到示例构图。
4. 双击 `shaders/anime_style.gdshaderinc` 修改全局风格常量；表面算法在 `anime_surface.gdshader`，后处理在 `anime_post.gdshader`。保存后观察编辑器预览，语法错误见 Shader Editor 下方提示。

随快照保留的 `Open-Lab.ps1` 是原电脑的启动器，仍使用原来的绝对路径；换目录或换电脑请使用上述 **Import** 流程。`tools/build_catalog.py` 也保留原始来源路径。不要为了打开实验室运行构建脚本覆盖自己已经调整过的场景或材质。

场景包含 3 棵树、2 栋房屋、4 件道具，以及测试球和地面。模型目录索引了 119 个逻辑条目、159 个源模型文件；索引中的模型并未全部复制或转换。

树木和道具来自主项目 [environment_kit_v2](../../game/assets/floor1/environment_kit_v2/PROVENANCE.md)，房屋来自 [residences](../../game/assets/floor1/residences/PROVENANCE.md)。它们的来源记录说明几何和纹理由本项目原创生成；本次上传不新增或变更项目许可证。渲染用 `.res` 是这些模型的 LOD1 派生网格。

[早先实际渲染截图与验证记录](../../docs/validation/local_work_2026-09-13/README.md) · [SAO 场景参考图与来源](../../docs/references/sao-season1/README.md) · [原实验室教程](README.md) · [模型目录](MODEL_CATALOG.md)

这是可修改的三渲二学习模板，包含表面分层光照和可选深度描边；不是官方 SAO Shader，也不是已经完成的工业制作管线。早先的验证截图不代表后来每一次手动编辑都重新通过验证。
