# 美术风格与 Shader 对比

[历史全部流水](HISTORY.md) · [唯一流程图](ROADMAP.md) · [项目介绍](README.md)

## 已有参考方向

保留现有 SAO 场景参考，用于比较建筑体块、石墙与红瓦的色彩、树冠色块、林间明暗和远景层次。下面同时保留项目自己的 Shader 对照；它们是已有实验记录，当前模板仍有细节噪点、材质近似和渲染范围限制，不代表已经达到参考图的最终美术效果。

## 我们的 Shader 对照

本轮第一层场景迭代的实际图片、门窗组件和减面结果另见[2026-09-16持续记录](docs/validation/floor1_art_iteration_2026-09-16.md)。当前采用米制场景、象牙灰泥/红瓦/暖木/少量蓝绿窗扇，城镇接草地、农地和林缘；是项目原创布局，不是原著精确地图。跨楼层参考只用于色彩和构图。

资产处理按实际结果选择：三种Meshy住宅采用重拓扑后三档LOD与默认2K贴图；单株庭院橡树采用原拓扑Blender减面，保留大叶团。可交互住宅单独建立真实墙洞和完整DoorUnit/WindowUnit，生成式单体网格不等于自动得到可动门窗。原始高精度资产保留；面数、纹理体积、实际画面和通路分别验证，低面数或生成成功本身不代表可采用。

本轮对照进一步表明：新UV重烘能够修复部分窗板和花箱纹理，却可能从相邻烟囱拾取错误颜色；目前60K住宅仍是未采用候选。给平墙增加细微灰泥纹理，保持原色后也没有明显改善街景层次，因此没有采用。后续近景住宅应先解决结构、立面节奏和局部烘焙错误，再决定是否增加纹理分辨率。林缘则已采用同一14,783面橡树的十株共享实例形成局部疏密，而非复制高精度庭院树铺满森林。

以下五张图来自 2026-09-13 同一实验场景的已有验证；此次整理没有重新渲染。

| 表面卡通光照＋后处理 | 表面卡通光照，关闭后处理 |
| --- | --- |
| ![开启后处理](docs/validation/local_work_2026-09-13/shader-lab/01_baseline_post_on.png) | ![关闭后处理](docs/validation/local_work_2026-09-13/shader-lab/01b_baseline_post_off.png) |

| 修改共享风格常量 | 保存后从磁盘重新加载 |
| --- | --- |
| ![共享常量修改](docs/validation/local_work_2026-09-13/shader-lab/02_live_include_edit.png) | ![磁盘重新加载](docs/validation/local_work_2026-09-13/shader-lab/03_shared_disk_reload_edit.png) |

恢复默认参数后的原图：

![恢复默认](docs/validation/local_work_2026-09-13/shader-lab/04_restored_default.png)

原验证记录中，修改常量后的图与重新加载图哈希一致，恢复默认图与初始图哈希一致。[原验证数据](docs/validation/local_work_2026-09-13/shader-lab/validation.json)。

## Shader 分工与调整位置

| 部分 | 当前作用 | 文件 |
| --- | --- | --- |
| 逐表面 Shader | 按表面法线和光照方向分层明暗 | [anime_surface.gdshader](experiments/godot-anime-lab/shaders/anime_surface.gdshader) |
| 共享风格参数 | 阈值、过渡、明暗偏色、贴图强度和风；所有预览材质共用 | [anime_style.gdshaderinc](experiments/godot-anime-lab/shaders/anime_style.gdshaderinc) |
| 可选后处理 | 屏幕空间深度轮廓线与轻微饱和度调整 | [anime_post.gdshader](experiments/godot-anime-lab/shaders/anime_post.gdshader) |

本模板使用逐表面分层光照加可选深度描边。后处理看不到其采样阶段之后绘制的半透明物体；全屏硬色阶和植被法线描边不属于这个已验证模板。正式人物、脸部、手绘贴图和完整动画仍是后续工作。

## 打开已有实验室

仓库中的[实验室 project.godot](experiments/godot-anime-lab/project.godot)是独立项目。用 Godot 项目管理器导入它，打开 `scenes/material_lab.tscn`，选中 `PreviewCamera` 并勾选 3D 视口的 Preview。打开共享 include、调整常量并保存后观察画面。当前电脑另有 `C:/GodotAnimeLab`；保留其中正在使用的项目和编辑器。

不要直接照搬原电脑启动器的绝对路径。完整旧教程与快照说明已收入历史：[实验室教程](HISTORY.md#history-experiments-godot-anime-lab-readme-md)、[快照与打开方式](HISTORY.md#history-experiments-godot-anime-lab-snapshot-md)、[旧模型目录](HISTORY.md#history-experiments-godot-anime-lab-model-catalog-md)。

## 我们的五张场景参考图

保存本次讨论的五张参考图的来源与外部预览，供场景构图、树木、建筑和三渲二调色对照。图片文件仍由来源网站提供，没有复制进此公开仓库，也不属于项目可再分发的游戏资产。外部预览可能受来源站防盗链或链接变化影响，可点击对应来源页面查看。

以下不构成“全网最高人气”排名。可核实的人气依据仅是 [SAO 官方 2014 年投票](https://www.swordart-online.net/SAOA/en/) 的 Best Environment 类别，浮游城 Aincrad 排在首位。

### 1. 艾恩葛朗特全景

类型：官方投票获奖壁纸，适合参考整体轮廓、远景空气透视和天空色彩；不是地图平面图。

[官方来源](https://www.swordart-online.net/SAOA/en/) · [查看原图](https://www.swordart-online.net/SAOA/img/wp/pc1/BestofEnvironment.jpg)

![艾恩葛朗特官方壁纸](https://www.swordart-online.net/SAOA/img/wp/pc1/BestofEnvironment.jpg)

### 2. 托尔巴纳 Tolbana

类型：动画场景截图。参考石砌街区、红瓦屋顶的色彩关系和建筑层次。

[来源与场景说明](https://swordartonline.fandom.com/wiki/Tolbana)

![托尔巴纳场景](https://vignette.wikia.nocookie.net/swordartonline/images/f/f6/Tolbana.png/revision/latest?cb=20140309033544)

### 3. 第二十二层森林小屋

类型：动画场景截图。参考树冠的大色块、林间光影、木屋与草地的明度关系。

[来源与场景说明](https://swordartonline.fandom.com/wiki/Forest_House_K4)

![森林小屋场景](https://vignette2.wikia.nocookie.net/swordartonline/images/a/af/Forest_Home.png/revision/latest?cb=20140414053602)

### 4. 森林小屋外观设计线稿

类型：来源 Wiki 标注的 exterior design art，可用于观察建筑比例和体块。尚未核实它对应的原始出版物、页码及具体制作批次，不把它当作已经确认出处的第一季原画扫描。

[来源图库](https://swordartonline.fandom.com/wiki/Forest_House_K4#Gallery)

![森林小屋外观设计线稿](https://vignette.wikia.nocookie.net/swordartonline/images/c/ce/Forest_House_K4_%28outside%29_design_art.png/revision/latest?cb=20150604115903)

### 5. 第四十七层回忆之丘

类型：动画场景截图。参考花海、远景和树木之间的颜色分组与景深层次。

[来源与场景说明](https://swordartonline.fandom.com/wiki/47th_Floor_%28Aincrad%29)

![回忆之丘](https://vignette.wikia.nocookie.net/swordartonline/images/3/34/Hill_of_Memories_2.png/revision/latest?cb=20140313034239)

### 制作方资料入口

- [Bamboo 官方第一季背景美术图库](https://www.bamboo-inc.com/gallery/view/34)：优先从制作方页面查看背景作品，本仓库不复制其图库文件。
- [Aniplex《Sword Art Online Design Works》](https://online.aniplex.co.jp/itemlvjsCYfj.html)：官方设定资料书入口，核对设计原稿来源时使用。
- [Bamboo 画集出版社页面](https://bnn.co.jp/products/9784802512060)：画集资料入口。

参考图的著作权属于各自权利方。Wiki 页面文字的许可不自动赋予其收录的动画截图或设定图相同的许可。项目规则要求公开迁入资产前核实再分发权限；本次未取得这些第三方图片的相应授权，故只保存来源链接及外部预览。
