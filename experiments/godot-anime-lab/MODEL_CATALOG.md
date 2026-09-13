# 模型目录（MODEL_CATALOG）

生成时间（UTC）：2026-09-13T07:23:58Z ｜ 生成器：`tools/build_catalog.py`

**范围声明**：本目录只统计下面列出的运行时光美术目录里的模型文件（后缀 fbx/glb/gltf/obj，遍历深度 <= 4，单目录文件数上限 2000，跳过 .godot/.git/cache/import 与 `*.import`）。它**不包含** Blender 源文件、`private/` 目录、其它工程或未列出的目录，也**不代表**全仓库美术清单。

**它是索引，不是批准**：`visual_approval`、`status` 等字段来自各目录 manifest；没有 manifest 的行显示名由文件名推导（`label_source=filename-derived`），不代表已获美术批准。

## 总计

| 指标 | 值 |
| --- | --- |
| 逻辑模型数 | 119 |
| 源模型文件数 | 159（731.9 MB） |
| 已复制进实验室的文件 | 9（161.7 MB） |
| 已在预览场景里显示 | 9 |

## 按源目录

| 源目录（相对仓库） | 版本/类别 | 逻辑模型 | 模型文件 | 字节 |
| --- | --- | --- | --- | --- |
| `game/assets/floor1/environment_kit_v2` | V2 现行环境套件（运行时） | 20 | 60 | 49,894,244 |
| `game/assets/floor1/environment_kit_20` | V1 旧环境套件（运行时） | 21 | 21 | 30,177,016 |
| `game/assets/floor1/residences` | 住宅 01-05（运行时 art 目录，GLB 内含 LOD0/1/2） | 5 | 5 | 400,755,944 |
| `game/assets/floor1/deepseek_residences` | 住宅 06（草稿/待评审目录，见 manifest 状态字段） | 1 | 1 | 63,655,396 |
| `game/assets/floor1` | Hero Kit（单文件，含大量模块） | 1 | 1 | 69,677,888 |
| `game/assets/market` | Market Craft V5（单文件） | 1 | 1 | 114,210,064 |
| `game/assets/generated/artisan_workshops_20260912` | 生成物 20260912 工匠作坊道具（无 manifest） | 18 | 18 | 5,139,688 |
| `game/assets/generated/shopfront_details_20260912` | 生成物 20260912 店面细节 | 16 | 16 | 27,231,200 |
| `game/assets/generated/travel_cargo_20260912` | 生成物 20260912 旅行/货运道具 | 36 | 36 | 6,660,316 |

## 全部逻辑模型与源文件变体

`已复制` = 该文件已复制进 `C:/GodotAnimeLab`（复制件哈希见 `_work/copy_manifest.json`）；`已显示` = 该文件出现在默认预览场景 `scenes/material_lab.tscn` 里。


### V2 现行环境套件（运行时）

- **F1_ancient_oak** ｜ 显示名：古橡树（manifest） ｜ 变体 3 ｜ 合计 11,549,720 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | LOD0 | `game/assets/floor1/environment_kit_v2/F1_ancient_oak_LOD0.glb` | 7,597,564 | 否 | 否 | - | - |
  | LOD1 | `game/assets/floor1/environment_kit_v2/F1_ancient_oak_LOD1.glb` | 2,651,520 | 是 | 是 | `assets/v2_trees/F1_ancient_oak_LOD1.glb` | `faf1751048b17ea5`… |
  | LOD2 | `game/assets/floor1/environment_kit_v2/F1_ancient_oak_LOD2.glb` | 1,300,636 | 否 | 否 | - | - |

- **F1_berry_bush** ｜ 显示名：浆果丛（manifest） ｜ 变体 3 ｜ 合计 1,291,136 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | LOD0 | `game/assets/floor1/environment_kit_v2/F1_berry_bush_LOD0.glb` | 708,956 | 否 | 否 | - | - |
  | LOD1 | `game/assets/floor1/environment_kit_v2/F1_berry_bush_LOD1.glb` | 373,520 | 否 | 否 | - | - |
  | LOD2 | `game/assets/floor1/environment_kit_v2/F1_berry_bush_LOD2.glb` | 208,660 | 否 | 否 | - | - |

- **F1_birch_grove** ｜ 显示名：白桦组三株（manifest） ｜ 变体 3 ｜ 合计 4,507,468 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | LOD0 | `game/assets/floor1/environment_kit_v2/F1_birch_grove_LOD0.glb` | 2,478,900 | 否 | 否 | - | - |
  | LOD1 | `game/assets/floor1/environment_kit_v2/F1_birch_grove_LOD1.glb` | 1,334,652 | 否 | 否 | - | - |
  | LOD2 | `game/assets/floor1/environment_kit_v2/F1_birch_grove_LOD2.glb` | 693,916 | 否 | 否 | - | - |

- **F1_canvas_rest_shelter** ｜ 显示名：帆布休憩棚（manifest） ｜ 变体 3 ｜ 合计 741,552 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | LOD0 | `game/assets/floor1/environment_kit_v2/F1_canvas_rest_shelter_LOD0.glb` | 415,952 | 否 | 否 | - | - |
  | LOD1 | `game/assets/floor1/environment_kit_v2/F1_canvas_rest_shelter_LOD1.glb` | 162,800 | 否 | 否 | - | - |
  | LOD2 | `game/assets/floor1/environment_kit_v2/F1_canvas_rest_shelter_LOD2.glb` | 162,800 | 否 | 否 | - | - |

- **F1_cypress_column** ｜ 显示名：柱形柏树（manifest） ｜ 变体 3 ｜ 合计 4,934,544 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | LOD0 | `game/assets/floor1/environment_kit_v2/F1_cypress_column_LOD0.glb` | 3,366,524 | 否 | 否 | - | - |
  | LOD1 | `game/assets/floor1/environment_kit_v2/F1_cypress_column_LOD1.glb` | 1,138,556 | 否 | 否 | - | - |
  | LOD2 | `game/assets/floor1/environment_kit_v2/F1_cypress_column_LOD2.glb` | 429,464 | 否 | 否 | - | - |

- **F1_fern_patch** ｜ 显示名：蕨类地被（manifest） ｜ 变体 3 ｜ 合计 895,188 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | LOD0 | `game/assets/floor1/environment_kit_v2/F1_fern_patch_LOD0.glb` | 517,356 | 否 | 否 | - | - |
  | LOD1 | `game/assets/floor1/environment_kit_v2/F1_fern_patch_LOD1.glb` | 260,768 | 否 | 否 | - | - |
  | LOD2 | `game/assets/floor1/environment_kit_v2/F1_fern_patch_LOD2.glb` | 117,064 | 否 | 否 | - | - |

- **F1_flowering_shrub** ｜ 显示名：开花灌木（manifest） ｜ 变体 3 ｜ 合计 1,586,268 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | LOD0 | `game/assets/floor1/environment_kit_v2/F1_flowering_shrub_LOD0.glb` | 906,520 | 否 | 否 | - | - |
  | LOD1 | `game/assets/floor1/environment_kit_v2/F1_flowering_shrub_LOD1.glb` | 455,632 | 否 | 否 | - | - |
  | LOD2 | `game/assets/floor1/environment_kit_v2/F1_flowering_shrub_LOD2.glb` | 224,116 | 否 | 否 | - | - |

- **F1_herb_planter** ｜ 显示名：香草种植箱（manifest） ｜ 变体 3 ｜ 合计 1,483,884 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | LOD0 | `game/assets/floor1/environment_kit_v2/F1_herb_planter_LOD0.glb` | 875,284 | 否 | 否 | - | - |
  | LOD1 | `game/assets/floor1/environment_kit_v2/F1_herb_planter_LOD1.glb` | 357,756 | 是 | 是 | `assets/props/F1_herb_planter_LOD1.glb` | `f05f65de0ed85e10`… |
  | LOD2 | `game/assets/floor1/environment_kit_v2/F1_herb_planter_LOD2.glb` | 250,844 | 否 | 否 | - | - |

- **F1_ivy_wall_panel** ｜ 显示名：常春藤墙面（manifest） ｜ 变体 3 ｜ 合计 418,100 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | LOD0 | `game/assets/floor1/environment_kit_v2/F1_ivy_wall_panel_LOD0.glb` | 254,036 | 否 | 否 | - | - |
  | LOD1 | `game/assets/floor1/environment_kit_v2/F1_ivy_wall_panel_LOD1.glb` | 106,720 | 否 | 否 | - | - |
  | LOD2 | `game/assets/floor1/environment_kit_v2/F1_ivy_wall_panel_LOD2.glb` | 57,344 | 否 | 否 | - | - |

- **F1_meadow_grass** ｜ 显示名：草甸草簇（manifest） ｜ 变体 3 ｜ 合计 229,024 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | LOD0 | `game/assets/floor1/environment_kit_v2/F1_meadow_grass_LOD0.glb` | 138,420 | 否 | 否 | - | - |
  | LOD1 | `game/assets/floor1/environment_kit_v2/F1_meadow_grass_LOD1.glb` | 67,184 | 是 | 是 | `assets/props/F1_meadow_grass_LOD1.glb` | `da0a038ecd7bbd2c`… |
  | LOD2 | `game/assets/floor1/environment_kit_v2/F1_meadow_grass_LOD2.glb` | 23,420 | 否 | 否 | - | - |

- **F1_mossy_boulder_cluster** ｜ 显示名：苔石组（manifest） ｜ 变体 3 ｜ 合计 417,036 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | LOD0 | `game/assets/floor1/environment_kit_v2/F1_mossy_boulder_cluster_LOD0.glb` | 199,056 | 否 | 否 | - | - |
  | LOD1 | `game/assets/floor1/environment_kit_v2/F1_mossy_boulder_cluster_LOD1.glb` | 134,576 | 是 | 是 | `assets/props/F1_mossy_boulder_cluster_LOD1.glb` | `84fe5a1aa6a11fc0`… |
  | LOD2 | `game/assets/floor1/environment_kit_v2/F1_mossy_boulder_cluster_LOD2.glb` | 83,404 | 否 | 否 | - | - |

- **F1_mossy_fallen_log** ｜ 显示名：苔藓倒木（manifest） ｜ 变体 3 ｜ 合计 403,064 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | LOD0 | `game/assets/floor1/environment_kit_v2/F1_mossy_fallen_log_LOD0.glb` | 174,004 | 否 | 否 | - | - |
  | LOD1 | `game/assets/floor1/environment_kit_v2/F1_mossy_fallen_log_LOD1.glb` | 128,084 | 否 | 否 | - | - |
  | LOD2 | `game/assets/floor1/environment_kit_v2/F1_mossy_fallen_log_LOD2.glb` | 100,976 | 否 | 否 | - | - |

- **F1_orchard_apple** ｜ 显示名：果园苹果树（manifest） ｜ 变体 3 ｜ 合计 7,037,168 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | LOD0 | `game/assets/floor1/environment_kit_v2/F1_orchard_apple_LOD0.glb` | 3,924,836 | 否 | 否 | - | - |
  | LOD1 | `game/assets/floor1/environment_kit_v2/F1_orchard_apple_LOD1.glb` | 2,072,416 | 否 | 否 | - | - |
  | LOD2 | `game/assets/floor1/environment_kit_v2/F1_orchard_apple_LOD2.glb` | 1,039,916 | 否 | 否 | - | - |

- **F1_reed_cluster** ｜ 显示名：芦苇簇（manifest） ｜ 变体 3 ｜ 合计 265,488 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | LOD0 | `game/assets/floor1/environment_kit_v2/F1_reed_cluster_LOD0.glb` | 134,356 | 否 | 否 | - | - |
  | LOD1 | `game/assets/floor1/environment_kit_v2/F1_reed_cluster_LOD1.glb` | 80,276 | 否 | 否 | - | - |
  | LOD2 | `game/assets/floor1/environment_kit_v2/F1_reed_cluster_LOD2.glb` | 50,856 | 否 | 否 | - | - |

- **F1_roadside_milestone** ｜ 显示名：道路里程碑（manifest） ｜ 变体 3 ｜ 合计 280,712 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | LOD0 | `game/assets/floor1/environment_kit_v2/F1_roadside_milestone_LOD0.glb` | 163,520 | 否 | 否 | - | - |
  | LOD1 | `game/assets/floor1/environment_kit_v2/F1_roadside_milestone_LOD1.glb` | 62,800 | 是 | 是 | `assets/props/F1_roadside_milestone_LOD1.glb` | `01628a25a68e0dd6`… |
  | LOD2 | `game/assets/floor1/environment_kit_v2/F1_roadside_milestone_LOD2.glb` | 54,392 | 否 | 否 | - | - |

- **F1_stone_pine** ｜ 显示名：石地松树（manifest） ｜ 变体 3 ｜ 合计 3,661,784 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | LOD0 | `game/assets/floor1/environment_kit_v2/F1_stone_pine_LOD0.glb` | 2,500,732 | 否 | 否 | - | - |
  | LOD1 | `game/assets/floor1/environment_kit_v2/F1_stone_pine_LOD1.glb` | 843,368 | 是 | 是 | `assets/v2_trees/F1_stone_pine_LOD1.glb` | `85f5228cc3667e37`… |
  | LOD2 | `game/assets/floor1/environment_kit_v2/F1_stone_pine_LOD2.glb` | 317,684 | 否 | 否 | - | - |

- **F1_stone_water_trough** ｜ 显示名：石质水槽（manifest） ｜ 变体 3 ｜ 合计 524,440 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | LOD0 | `game/assets/floor1/environment_kit_v2/F1_stone_water_trough_LOD0.glb` | 297,164 | 否 | 否 | - | - |
  | LOD1 | `game/assets/floor1/environment_kit_v2/F1_stone_water_trough_LOD1.glb` | 117,844 | 否 | 否 | - | - |
  | LOD2 | `game/assets/floor1/environment_kit_v2/F1_stone_water_trough_LOD2.glb` | 109,432 | 否 | 否 | - | - |

- **F1_timber_fence_vine** ｜ 显示名：藤蔓木栅栏（manifest） ｜ 变体 3 ｜ 合计 202,544 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | LOD0 | `game/assets/floor1/environment_kit_v2/F1_timber_fence_vine_LOD0.glb` | 99,388 | 否 | 否 | - | - |
  | LOD1 | `game/assets/floor1/environment_kit_v2/F1_timber_fence_vine_LOD1.glb` | 59,632 | 否 | 否 | - | - |
  | LOD2 | `game/assets/floor1/environment_kit_v2/F1_timber_fence_vine_LOD2.glb` | 43,524 | 否 | 否 | - | - |

- **F1_wildflower_patch** ｜ 显示名：野花草簇（manifest） ｜ 变体 3 ｜ 合计 696,076 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | LOD0 | `game/assets/floor1/environment_kit_v2/F1_wildflower_patch_LOD0.glb` | 395,136 | 否 | 否 | - | - |
  | LOD1 | `game/assets/floor1/environment_kit_v2/F1_wildflower_patch_LOD1.glb` | 202,884 | 否 | 否 | - | - |
  | LOD2 | `game/assets/floor1/environment_kit_v2/F1_wildflower_patch_LOD2.glb` | 98,056 | 否 | 否 | - | - |

- **F1_young_maple** ｜ 显示名：幼枫树（manifest） ｜ 变体 3 ｜ 合计 8,769,048 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | LOD0 | `game/assets/floor1/environment_kit_v2/F1_young_maple_LOD0.glb` | 5,753,244 | 否 | 否 | - | - |
  | LOD1 | `game/assets/floor1/environment_kit_v2/F1_young_maple_LOD1.glb` | 2,018,776 | 是 | 是 | `assets/v2_trees/F1_young_maple_LOD1.glb` | `2e2dd58afedaa80d`… |
  | LOD2 | `game/assets/floor1/environment_kit_v2/F1_young_maple_LOD2.glb` | 997,028 | 否 | 否 | - | - |

### V1 旧环境套件（运行时）

- **F1_ancient_oak** ｜ 显示名：古橡树（manifest） ｜ 变体 1 ｜ 合计 764,764 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/floor1/environment_kit_20/F1_ancient_oak.glb` | 764,764 | 否 | 否 | - | - |

- **F1_berry_bush** ｜ 显示名：浆果丛（manifest） ｜ 变体 1 ｜ 合计 1,070,028 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/floor1/environment_kit_20/F1_berry_bush.glb` | 1,070,028 | 否 | 否 | - | - |

- **F1_birch_grove** ｜ 显示名：白桦组三株（manifest） ｜ 变体 1 ｜ 合计 992,832 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/floor1/environment_kit_20/F1_birch_grove.glb` | 992,832 | 否 | 否 | - | - |

- **F1_canvas_rest_shelter** ｜ 显示名：帆布休憩棚（manifest） ｜ 变体 1 ｜ 合计 995,480 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/floor1/environment_kit_20/F1_canvas_rest_shelter.glb` | 995,480 | 否 | 否 | - | - |

- **F1_cypress_column** ｜ 显示名：柱形柏树（manifest） ｜ 变体 1 ｜ 合计 546,112 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/floor1/environment_kit_20/F1_cypress_column.glb` | 546,112 | 否 | 否 | - | - |

- **F1_fern_patch** ｜ 显示名：蕨类地被（manifest） ｜ 变体 1 ｜ 合计 2,233,200 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/floor1/environment_kit_20/F1_fern_patch.glb` | 2,233,200 | 否 | 否 | - | - |

- **F1_flowering_shrub** ｜ 显示名：开花灌木（manifest） ｜ 变体 1 ｜ 合计 1,127,932 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/floor1/environment_kit_20/F1_flowering_shrub.glb` | 1,127,932 | 否 | 否 | - | - |

- **F1_herb_planter** ｜ 显示名：香草种植箱（manifest） ｜ 变体 1 ｜ 合计 1,012,544 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/floor1/environment_kit_20/F1_herb_planter.glb` | 1,012,544 | 否 | 否 | - | - |

- **F1_ivy_wall_panel** ｜ 显示名：常春藤墙面（manifest） ｜ 变体 1 ｜ 合计 1,558,420 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/floor1/environment_kit_20/F1_ivy_wall_panel.glb` | 1,558,420 | 否 | 否 | - | - |

- **F1_meadow_grass** ｜ 显示名：草甸草簇（manifest） ｜ 变体 1 ｜ 合计 182,208 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/floor1/environment_kit_20/F1_meadow_grass.glb` | 182,208 | 否 | 否 | - | - |

- **F1_mossy_boulder_cluster** ｜ 显示名：苔石组（manifest） ｜ 变体 1 ｜ 合计 532,664 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/floor1/environment_kit_20/F1_mossy_boulder_cluster.glb` | 532,664 | 否 | 否 | - | - |

- **F1_mossy_fallen_log** ｜ 显示名：苔藓倒木（manifest） ｜ 变体 1 ｜ 合计 548,972 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/floor1/environment_kit_20/F1_mossy_fallen_log.glb` | 548,972 | 否 | 否 | - | - |

- **F1_orchard_apple** ｜ 显示名：果园苹果树（manifest） ｜ 变体 1 ｜ 合计 877,604 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/floor1/environment_kit_20/F1_orchard_apple.glb` | 877,604 | 否 | 否 | - | - |

- **F1_reed_cluster** ｜ 显示名：芦苇簇（manifest） ｜ 变体 1 ｜ 合计 787,572 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/floor1/environment_kit_20/F1_reed_cluster.glb` | 787,572 | 否 | 否 | - | - |

- **F1_roadside_milestone** ｜ 显示名：道路里程碑（manifest） ｜ 变体 1 ｜ 合计 554,996 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/floor1/environment_kit_20/F1_roadside_milestone.glb` | 554,996 | 否 | 否 | - | - |

- **F1_stone_pine** ｜ 显示名：石地松树（manifest） ｜ 变体 1 ｜ 合计 1,258,580 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/floor1/environment_kit_20/F1_stone_pine.glb` | 1,258,580 | 否 | 否 | - | - |

- **F1_stone_water_trough** ｜ 显示名：石质水槽（manifest） ｜ 变体 1 ｜ 合计 549,612 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/floor1/environment_kit_20/F1_stone_water_trough.glb` | 549,612 | 否 | 否 | - | - |

- **F1_timber_fence_vine** ｜ 显示名：藤蔓木栅栏（manifest） ｜ 变体 1 ｜ 合计 800,540 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/floor1/environment_kit_20/F1_timber_fence_vine.glb` | 800,540 | 否 | 否 | - | - |

- **F1_wildflower_patch** ｜ 显示名：野花草簇（manifest） ｜ 变体 1 ｜ 合计 1,527,396 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/floor1/environment_kit_20/F1_wildflower_patch.glb` | 1,527,396 | 否 | 否 | - | - |

- **F1_young_maple** ｜ 显示名：幼枫树（manifest） ｜ 变体 1 ｜ 合计 700,720 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/floor1/environment_kit_20/F1_young_maple.glb` | 700,720 | 否 | 否 | - | - |

- **Floor1_EnvironmentKit20_Showcase** ｜ 显示名：（无 manifest 标签）（filename-derived） ｜ 变体 1 ｜ 合计 11,554,840 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/floor1/environment_kit_20/Floor1_EnvironmentKit20_Showcase.glb` | 11,554,840 | 否 | 否 | - | - |

### 住宅 01-05（运行时 art 目录，GLB 内含 LOD0/1/2）

- **F1_Residence_01** ｜ 显示名：菩提庭院宅（manifest） ｜ 变体 1 ｜ 合计 73,003,124 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/floor1/residences/F1_Residence_01.glb` | 73,003,124 | 是 | 是 | `assets/residences/F1_Residence_01.glb` | `6c406a932f9f5bb4`… |

- **F1_Residence_02** ｜ 显示名：铜檐窄街宅（manifest） ｜ 变体 1 ｜ 合计 71,648,184 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/floor1/residences/F1_Residence_02.glb` | 71,648,184 | 否 | 否 | - | - |

- **F1_Residence_03** ｜ 显示名：蔷薇花院宅（manifest） ｜ 变体 1 ｜ 合计 83,140,096 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/floor1/residences/F1_Residence_03.glb` | 83,140,096 | 是 | 是 | `assets/residences/F1_Residence_03.glb` | `b85b5bb58c4e215f`… |

- **F1_Residence_04** ｜ 显示名：鼠尾草长廊宅（manifest） ｜ 变体 1 ｜ 合计 73,224,636 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/floor1/residences/F1_Residence_04.glb` | 73,224,636 | 否 | 否 | - | - |

- **F1_Residence_05** ｜ 显示名：青瓷转角宅（manifest） ｜ 变体 1 ｜ 合计 99,739,904 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/floor1/residences/F1_Residence_05.glb` | 99,739,904 | 否 | 否 | - | - |

### 住宅 06（草稿/待评审目录，见 manifest 状态字段）

- **F1_Residence_06** ｜ 显示名：连廊屋（manifest） ｜ 变体 1 ｜ 合计 63,655,396 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/floor1/deepseek_residences/F1_Residence_06.glb` | 63,655,396 | 否 | 否 | - | - |

### Hero Kit（单文件，含大量模块）

- **StartingTown_Floor1_HeroKit** ｜ 显示名：（无 manifest 标签）（filename-derived） ｜ 变体 1 ｜ 合计 69,677,888 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/floor1/StartingTown_Floor1_HeroKit.glb` | 69,677,888 | 否 | 否 | - | - |

### Market Craft V5（单文件）

- **StartingTown_Market_CraftV5** ｜ 显示名：（无 manifest 标签）（filename-derived） ｜ 变体 1 ｜ 合计 114,210,064 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/market/StartingTown_Market_CraftV5.glb` | 114,210,064 | 否 | 否 | - | - |

### 生成物 20260912 工匠作坊道具（无 manifest）

- **arched_pottery_kiln** ｜ 显示名：（无 manifest 标签）（filename-derived） ｜ 变体 1 ｜ 合计 504,724 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/artisan_workshops_20260912/arched_pottery_kiln.glb` | 504,724 | 否 | 否 | - | - |

- **bakers_oven_peel_rack** ｜ 显示名：（无 manifest 标签）（filename-derived） ｜ 变体 1 ｜ 合计 113,548 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/artisan_workshops_20260912/bakers_oven_peel_rack.glb` | 113,548 | 否 | 否 | - | - |

- **bowyers_shaping_form** ｜ 显示名：（无 manifest 标签）（filename-derived） ｜ 变体 1 ｜ 合计 179,624 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/artisan_workshops_20260912/bowyers_shaping_form.glb` | 179,624 | 否 | 否 | - | - |

- **candle_mold_rack** ｜ 显示名：（无 manifest 标签）（filename-derived） ｜ 变体 1 ｜ 合计 245,372 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/artisan_workshops_20260912/candle_mold_rack.glb` | 245,372 | 否 | 否 | - | - |

- **clay_drying_shelves** ｜ 显示名：（无 manifest 标签）（filename-derived） ｜ 变体 1 ｜ 合计 682,468 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/artisan_workshops_20260912/clay_drying_shelves.glb` | 682,468 | 否 | 否 | - | - |

- **coopers_stave_jig** ｜ 显示名：（无 manifest 标签）（filename-derived） ｜ 变体 1 ｜ 合计 692,712 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/artisan_workshops_20260912/coopers_stave_jig.glb` | 692,712 | 否 | 否 | - | - |

- **forge_with_bellows** ｜ 显示名：（无 manifest 标签）（filename-derived） ｜ 变体 1 ｜ 合计 186,816 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/artisan_workshops_20260912/forge_with_bellows.glb` | 186,816 | 否 | 否 | - | - |

- **grain_hand_quern** ｜ 显示名：（无 manifest 标签）（filename-derived） ｜ 变体 1 ｜ 合计 189,092 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/artisan_workshops_20260912/grain_hand_quern.glb` | 189,092 | 否 | 否 | - | - |

- **honey_basket_press** ｜ 显示名：（无 manifest 标签）（filename-derived） ｜ 变体 1 ｜ 合计 400,348 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/artisan_workshops_20260912/honey_basket_press.glb` | 400,348 | 否 | 否 | - | - |

- **horn_anvil_stump** ｜ 显示名：（无 manifest 标签）（filename-derived） ｜ 变体 1 ｜ 合计 146,336 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/artisan_workshops_20260912/horn_anvil_stump.glb` | 146,336 | 否 | 否 | - | - |

- **jewelers_drawbench** ｜ 显示名：（无 manifest 标签）（filename-derived） ｜ 变体 1 ｜ 合计 262,740 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/artisan_workshops_20260912/jewelers_drawbench.glb` | 262,740 | 否 | 否 | - | - |

- **laced_leather_frame** ｜ 显示名：（无 manifest 标签）（filename-derived） ｜ 变体 1 ｜ 合计 171,156 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/artisan_workshops_20260912/laced_leather_frame.glb` | 171,156 | 否 | 否 | - | - |

- **rope_winding_winch** ｜ 显示名：（无 manifest 标签）（filename-derived） ｜ 变体 1 ｜ 合计 311,972 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/artisan_workshops_20260912/rope_winding_winch.glb` | 311,972 | 否 | 否 | - | - |

- **sage_dye_vat** ｜ 显示名：（无 manifest 标签）（filename-derived） ｜ 变体 1 ｜ 合计 239,748 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/artisan_workshops_20260912/sage_dye_vat.glb` | 239,748 | 否 | 否 | - | - |

- **screw_book_press** ｜ 显示名：（无 manifest 标签）（filename-derived） ｜ 变体 1 ｜ 合计 267,984 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/artisan_workshops_20260912/screw_book_press.glb` | 267,984 | 否 | 否 | - | - |

- **smith_tong_rack** ｜ 显示名：（无 manifest 标签）（filename-derived） ｜ 变体 1 ｜ 合计 154,768 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/artisan_workshops_20260912/smith_tong_rack.glb` | 154,768 | 否 | 否 | - | - |

- **treadle_potters_wheel** ｜ 显示名：（无 manifest 标签）（filename-derived） ｜ 变体 1 ｜ 合计 269,592 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/artisan_workshops_20260912/treadle_potters_wheel.glb` | 269,592 | 否 | 否 | - | - |

- **treadle_shaving_horse** ｜ 显示名：（无 manifest 标签）（filename-derived） ｜ 变体 1 ｜ 合计 120,688 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/artisan_workshops_20260912/treadle_shaving_horse.glb` | 120,688 | 否 | 否 | - | - |

### 生成物 20260912 店面细节

- **SF01_Mercer_Display_Window** ｜ 显示名：（无 manifest 标签）（filename-derived） ｜ 变体 1 ｜ 合计 1,242,432 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/shopfront_details_20260912/SF01_Mercer_Display_Window.glb` | 1,242,432 | 否 | 否 | - | - |

- **SF02_Folding_Service_Hatch** ｜ 显示名：（无 manifest 标签）（filename-derived） ｜ 变体 1 ｜ 合计 1,038,688 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/shopfront_details_20260912/SF02_Folding_Service_Hatch.glb` | 1,038,688 | 否 | 否 | - | - |

- **SF03_Diamond_Lead_Casement** ｜ 显示名：（无 manifest 标签）（filename-derived） ｜ 变体 1 ｜ 合计 1,315,056 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/shopfront_details_20260912/SF03_Diamond_Lead_Casement.glb` | 1,315,056 | 否 | 否 | - | - |

- **SF04_Radial_Attic_Oculus** ｜ 显示名：（无 manifest 标签）（filename-derived） ｜ 变体 1 ｜ 合计 2,600,296 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/shopfront_details_20260912/SF04_Radial_Attic_Oculus.glb` | 2,600,296 | 否 | 否 | - | - |

- **SF05_Tiled_Gable_Dormer** ｜ 显示名：（无 manifest 标签）（filename-derived） ｜ 变体 1 ｜ 合计 1,801,036 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/shopfront_details_20260912/SF05_Tiled_Gable_Dormer.glb` | 1,801,036 | 否 | 否 | - | - |

- **SF06_Open_Flue_Chimney** ｜ 显示名：（无 manifest 标签）（filename-derived） ｜ 变体 1 ｜ 合计 2,762,548 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/shopfront_details_20260912/SF06_Open_Flue_Chimney.glb` | 2,762,548 | 否 | 否 | - | - |

- **SF07_Clay_Tile_Rain_Eave** ｜ 显示名：（无 manifest 标签）（filename-derived） ｜ 变体 1 ｜ 合计 1,370,776 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/shopfront_details_20260912/SF07_Clay_Tile_Rain_Eave.glb` | 1,370,776 | 否 | 否 | - | - |

- **SF08_Carved_Timber_Corbel** ｜ 显示名：（无 manifest 标签）（filename-derived） ｜ 变体 1 ｜ 合计 570,068 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/shopfront_details_20260912/SF08_Carved_Timber_Corbel.glb` | 570,068 | 否 | 否 | - | - |

- **SF09_Scalloped_Cloth_Canopy** ｜ 显示名：（无 manifest 标签）（filename-derived） ｜ 变体 1 ｜ 合计 4,071,344 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/shopfront_details_20260912/SF09_Scalloped_Cloth_Canopy.glb` | 4,071,344 | 否 | 否 | - | - |

- **SF10_Stone_Double_Portal** ｜ 显示名：（无 manifest 标签）（filename-derived） ｜ 变体 1 ｜ 合计 2,064,640 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/shopfront_details_20260912/SF10_Stone_Double_Portal.glb` | 2,064,640 | 否 | 否 | - | - |

- **SF11_Glazed_Shop_Door** ｜ 显示名：（无 manifest 标签）（filename-derived） ｜ 变体 1 ｜ 合计 1,054,368 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/shopfront_details_20260912/SF11_Glazed_Shop_Door.glb` | 1,054,368 | 否 | 否 | - | - |

- **SF12_Herbal_Stone_Niche** ｜ 显示名：（无 manifest 标签）（filename-derived） ｜ 变体 1 ｜ 合计 1,571,564 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/shopfront_details_20260912/SF12_Herbal_Stone_Niche.glb` | 1,571,564 | 否 | 否 | - | - |

- **SF13_Bakery_Pretzel_Emblem** ｜ 显示名：（无 manifest 标签）（filename-derived） ｜ 变体 1 ｜ 合计 644,620 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/shopfront_details_20260912/SF13_Bakery_Pretzel_Emblem.glb` | 644,620 | 否 | 否 | - | - |

- **SF14_Apothecary_Mortar_Emblem** ｜ 显示名：（无 manifest 标签）（filename-derived） ｜ 变体 1 ｜ 合计 413,924 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/shopfront_details_20260912/SF14_Apothecary_Mortar_Emblem.glb` | 413,924 | 否 | 否 | - | - |

- **SF15_Tailor_Shears_Emblem** ｜ 显示名：（无 manifest 标签）（filename-derived） ｜ 变体 1 ｜ 合计 681,504 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/shopfront_details_20260912/SF15_Tailor_Shears_Emblem.glb` | 681,504 | 否 | 否 | - | - |

- **SF16_Barber_Spiral_Emblem** ｜ 显示名：（无 manifest 标签）（filename-derived） ｜ 变体 1 ｜ 合计 4,028,336 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/shopfront_details_20260912/SF16_Barber_Spiral_Emblem.glb` | 4,028,336 | 否 | 否 | - | - |

### 生成物 20260912 旅行/货运道具

- **air_drying_fish_rack** ｜ 显示名：悬挂风干鱼架（manifest） ｜ 变体 1 ｜ 合计 132,520 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/travel_cargo_20260912/air_drying_fish_rack.glb` | 132,520 | 否 | 否 | - | - |

- **caged_travel_lantern** ｜ 显示名：护笼旅行提灯（manifest） ｜ 变体 1 ｜ 合计 46,732 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/travel_cargo_20260912/caged_travel_lantern.glb` | 46,732 | 否 | 否 | - | - |

- **carved_route_waystone** ｜ 显示名：刻箭头路石（manifest） ｜ 变体 1 ｜ 合计 35,428 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/travel_cargo_20260912/carved_route_waystone.glb` | 35,428 | 否 | 否 | - | - |

- **coiled_hemp_rope** ｜ 显示名：连续盘绕麻绳（manifest） ｜ 变体 1 ｜ 合计 298,748 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/travel_cargo_20260912/coiled_hemp_rope.glb` | 298,748 | 否 | 否 | - | - |

- **covered_caravan_wagon** ｜ 显示名：帆篷四轮旅行车（manifest） ｜ 变体 1 ｜ 合计 679,944 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/travel_cargo_20260912/covered_caravan_wagon.glb` | 679,944 | 否 | 否 | - | - |

- **diamond_fishing_net_frame** ｜ 显示名：菱格渔网晾架（manifest） ｜ 变体 1 ｜ 合计 319,072 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/travel_cargo_20260912/diamond_fishing_net_frame.glb` | 319,072 | 否 | 否 | - | - |

- **empty_courier_bird_cage** ｜ 显示名：空信鸟运输笼（manifest） ｜ 变体 1 ｜ 合计 334,836 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/travel_cargo_20260912/empty_courier_bird_cage.glb` | 334,836 | 否 | 否 | - | - |

- **fishing_rod_stand** ｜ 显示名：渔竿与浮标架（manifest） ｜ 变体 1 ｜ 合计 181,096 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/travel_cargo_20260912/fishing_rod_stand.glb` | 181,096 | 否 | 否 | - | - |

- **flagged_wooden_fishing_buoy** ｜ 显示名：木浮标与布旗（manifest） ｜ 变体 1 ｜ 合计 65,384 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/travel_cargo_20260912/flagged_wooden_fishing_buoy.glb` | 65,384 | 否 | 否 | - | - |

- **folding_field_stool** ｜ 显示名：交叉折叠营凳（manifest） ｜ 变体 1 ｜ 合计 36,884 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/travel_cargo_20260912/folding_field_stool.glb` | 36,884 | 否 | 否 | - | - |

- **folding_route_map_table** ｜ 显示名：折叠路线图桌（manifest） ｜ 变体 1 ｜ 合计 127,296 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/travel_cargo_20260912/folding_route_map_table.glb` | 127,296 | 否 | 否 | - | - |

- **furled_canvas_sail** ｜ 显示名：卷帆与桁杆（manifest） ｜ 变体 1 ｜ 合计 107,256 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/travel_cargo_20260912/furled_canvas_sail.glb` | 107,256 | 否 | 否 | - | - |

- **hoist_barrel_sling** ｜ 显示名：吊桶绳套（manifest） ｜ 变体 1 ｜ 合计 109,396 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/travel_cargo_20260912/hoist_barrel_sling.glb` | 109,396 | 否 | 否 | - | - |

- **iron_mooring_cleat** ｜ 显示名：铁制系缆座（manifest） ｜ 变体 1 ｜ 合计 19,356 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/travel_cargo_20260912/iron_mooring_cleat.glb` | 19,356 | 否 | 否 | - | - |

- **lapstrake_river_rowboat** ｜ 显示名：搭接木板河舟（manifest） ｜ 变体 1 ｜ 合计 141,684 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/travel_cargo_20260912/lapstrake_river_rowboat.glb` | 141,684 | 否 | 否 | - | - |

- **leather_scroll_case** ｜ 显示名：皮革地图筒（manifest） ｜ 变体 1 ｜ 合计 45,720 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/travel_cargo_20260912/leather_scroll_case.glb` | 45,720 | 否 | 否 | - | - |

- **netted_cargo_bundle** ｜ 显示名：绳网货物包（manifest） ｜ 变体 1 ｜ 合计 88,488 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/travel_cargo_20260912/netted_cargo_bundle.glb` | 88,488 | 否 | 否 | - | - |

- **open_travel_ration_case** ｜ 显示名：开盖旅行食盒（manifest） ｜ 变体 1 ｜ 合计 64,860 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/travel_cargo_20260912/open_travel_ration_case.glb` | 64,860 | 否 | 否 | - | - |

- **open_traveller_tent** ｜ 显示名：敞口旅行帐篷（manifest） ｜ 变体 1 ｜ 合计 60,356 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/travel_cargo_20260912/open_traveller_tent.glb` | 60,356 | 否 | 否 | - | - |

- **paired_leather_panniers** ｜ 显示名：双侧皮革驮袋（manifest） ｜ 变体 1 ｜ 合计 54,084 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/travel_cargo_20260912/paired_leather_panniers.glb` | 54,084 | 否 | 否 | - | - |

- **paired_wooden_oars** ｜ 显示名：双支木桨（manifest） ｜ 变体 1 ｜ 合计 79,416 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/travel_cargo_20260912/paired_wooden_oars.glb` | 79,416 | 否 | 否 | - | - |

- **partitioned_ceramic_crate** ｜ 显示名：陶器分格运输箱（manifest） ｜ 变体 1 ｜ 合计 1,060,576 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/travel_cargo_20260912/partitioned_ceramic_crate.glb` | 1,060,576 | 否 | 否 | - | - |

- **porters_luggage_trolley** ｜ 显示名：搬运双轮行李架（manifest） ｜ 变体 1 ｜ 合计 234,824 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/travel_cargo_20260912/porters_luggage_trolley.glb` | 234,824 | 否 | 否 | - | - |

- **rope_bound_cloth_bale** ｜ 显示名：麻绳布料包（manifest） ｜ 变体 1 ｜ 合计 48,516 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/travel_cargo_20260912/rope_bound_cloth_bale.glb` | 48,516 | 否 | 否 | - | - |

- **roped_ferry_gangplank** ｜ 显示名：扶绳渡船跳板（manifest） ｜ 变体 1 ｜ 合计 165,044 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/travel_cargo_20260912/roped_ferry_gangplank.glb` | 165,044 | 否 | 否 | - | - |

- **stacked_timber_pallets** ｜ 显示名：叠放木货板（manifest） ｜ 变体 1 ｜ 合计 203,972 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/travel_cargo_20260912/stacked_timber_pallets.glb` | 203,972 | 否 | 否 | - | - |

- **stitched_waterskin** ｜ 显示名：缝线皮水囊（manifest） ｜ 变体 1 ｜ 合计 44,756 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/travel_cargo_20260912/stitched_waterskin.glb` | 44,756 | 否 | 否 | - | - |

- **strapped_tent_bundle** ｜ 显示名：绑扎帐篷与营杆（manifest） ｜ 变体 1 ｜ 合计 109,384 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/travel_cargo_20260912/strapped_tent_bundle.glb` | 109,384 | 否 | 否 | - | - |

- **timber_frame_hammock** ｜ 显示名：木架悬吊布床（manifest） ｜ 变体 1 ｜ 合计 62,248 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/travel_cargo_20260912/timber_frame_hammock.glb` | 62,248 | 否 | 否 | - | - |

- **timber_pack_saddle** ｜ 显示名：木制驮架（manifest） ｜ 变体 1 ｜ 合计 68,524 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/travel_cargo_20260912/timber_pack_saddle.glb` | 68,524 | 否 | 否 | - | - |

- **trail_walking_stick_rack** ｜ 显示名：旅行手杖架（manifest） ｜ 变体 1 ｜ 合计 169,800 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/travel_cargo_20260912/trail_walking_stick_rack.glb` | 169,800 | 否 | 否 | - | - |

- **water_delivery_cart** ｜ 显示名：横桶送水车（manifest） ｜ 变体 1 ｜ 合计 650,348 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/travel_cargo_20260912/water_delivery_cart.glb` | 650,348 | 否 | 否 | - | - |

- **wood_stock_river_anchor** ｜ 显示名：木横杆河锚（manifest） ｜ 变体 1 ｜ 合计 40,760 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/travel_cargo_20260912/wood_stock_river_anchor.glb` | 40,760 | 否 | 否 | - | - |

- **wooden_pulley_block** ｜ 显示名：木壳吊运滑轮（manifest） ｜ 变体 1 ｜ 合计 84,460 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/travel_cargo_20260912/wooden_pulley_block.glb` | 84,460 | 否 | 否 | - | - |

- **woven_fishing_creel** ｜ 显示名：开口编织鱼篓（manifest） ｜ 变体 1 ｜ 合计 428,684 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/travel_cargo_20260912/woven_fishing_creel.glb` | 428,684 | 否 | 否 | - | - |

- **woven_funnel_fish_trap** ｜ 显示名：漏斗口编织鱼笼（manifest） ｜ 变体 1 ｜ 合计 259,864 字节

  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |
  | --- | --- | --- | --- | --- | --- | --- |
  | - | `game/assets/generated/travel_cargo_20260912/woven_funnel_fish_trap.glb` | 259,864 | 否 | 否 | - | - |

## 未纳入（先说清楚）

- 未列出的目录、`private/`、Blender `.blend` 源文件、其它工程资产都不在统计范围内。
- 场景里只用了上面标 `已显示` 的少数资产；其余仅为索引，没有复制、没有导入。
- 草稿/待评审目录（如 `deepseek_residences`）按 manifest 原样标注，不当作已批准资产。
