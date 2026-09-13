#!/usr/bin/env python3
"""tools/build_catalog.py — 生成 MODEL_CATALOG.md + model_catalog.json

只扫描任务里指定的 7 个运行时美术目录（深度 <= 4，最多 2000 个文件），
不递归整个仓库，跳过 .godot/.git/cache/import 目录与 *.import。
输出是数据（Markdown + JSON），不是电子表格。

用法: python tools/build_catalog.py
"""
import json
import os
import sys
from datetime import datetime, timezone

REPO = r"C:\InfiniteAincrad"
LAB = r"C:\GodotAnimeLab"
MAX_FILES = 2000
MAX_DEPTH = 4
MODEL_EXT = {".glb", ".gltf", ".fbx", ".obj"}
SKIP_DIRS = {".godot", ".git", "cache", "import", "imports", "bin", "obj", "binaries"}

# (相对仓库的目录, 版本类别, 目录内 manifest/说明文件候选)
SOURCES = [
    ("game/assets/floor1/environment_kit_v2", "V2 现行环境套件（运行时）",
     ["manifest.json"]),
    ("game/assets/floor1/environment_kit_20", "V1 旧环境套件（运行时）",
     ["manifest.json"]),
    ("game/assets/floor1/residences", "住宅 01-05（运行时 art 目录，GLB 内含 LOD0/1/2）",
     ["manifest.json"]),
    ("game/assets/floor1/deepseek_residences", "住宅 06（草稿/待评审目录，见 manifest 状态字段）",
     ["manifest.json"]),
    ("game/assets/floor1", "Hero Kit（单文件，含大量模块）",
     ["floor1_hero_kit_manifest.json"]),
    ("game/assets/market", "Market Craft V5（单文件）",
     ["market_craft_v5_manifest.json"]),
    ("game/assets/generated/artisan_workshops_20260912", "生成物 20260912 工匠作坊道具（无 manifest）",
     ["manifest.json"]),
    ("game/assets/generated/shopfront_details_20260912", "生成物 20260912 店面细节",
     ["manifest.json"]),
    ("game/assets/generated/travel_cargo_20260912", "生成物 20260912 旅行/货运道具",
     ["manifest.json"]),
]

# 本实验“已复制/已显示”的资产（相对于实验室目录）
COPIED = {
    "f1_ancient_oak_lod1.glb": "assets/v2_trees/F1_ancient_oak_LOD1.glb",
    "f1_stone_pine_lod1.glb": "assets/v2_trees/F1_stone_pine_LOD1.glb",
    "f1_young_maple_lod1.glb": "assets/v2_trees/F1_young_maple_LOD1.glb",
    "f1_residence_01.glb": "assets/residences/F1_Residence_01.glb",
    "f1_residence_03.glb": "assets/residences/F1_Residence_03.glb",
    "f1_roadside_milestone_lod1.glb": "assets/props/F1_roadside_milestone_LOD1.glb",
    "f1_mossy_boulder_cluster_lod1.glb": "assets/props/F1_mossy_boulder_cluster_LOD1.glb",
    "f1_herb_planter_lod1.glb": "assets/props/F1_herb_planter_LOD1.glb",
    "f1_meadow_grass_lod1.glb": "assets/props/F1_meadow_grass_LOD1.glb",
}
DISPLAYED = set(COPIED.keys())

LABELS = {}


def rel(p):
    return os.path.relpath(p, REPO).replace("\\", "/")


def walk_files(root):
    """有界遍历：深度 <= MAX_DEPTH，文件数上限 MAX_FILES，跳过缓存/导入目录。"""
    out = []
    root = os.path.abspath(root)
    base_depth = root.rstrip("\\").count("\\")
    for dirpath, dirnames, filenames in os.walk(root):
        depth = dirpath.rstrip("\\").count("\\") - base_depth
        if depth >= MAX_DEPTH:
            dirnames[:] = []
        dirnames[:] = [d for d in dirnames if d.lower() not in SKIP_DIRS and not d.startswith(".")]
        for name in filenames:
            if name.endswith(".import"):
                continue
            ext = os.path.splitext(name)[1].lower()
            if ext not in MODEL_EXT:
                continue
            out.append(os.path.join(dirpath, name))
            if len(out) >= MAX_FILES:
                return out
    return out


def harvest_labels(path, inherited=None):
    if not os.path.isfile(path):
        return
    try:
        with open(path, "r", encoding="utf-8") as fh:
            data = json.load(fh)
    except Exception as exc:  # 只报告，不中断
        print("manifest 读取失败 %s: %s" % (path, exc))
        return

    def walk(node, inherited_label):
        if isinstance(node, dict):
            label = (node.get("label_zh") or node.get("label") or node.get("display_name")
                     or node.get("name") or inherited_label)
            for key in ("file", "glb", "path", "model", "asset"):
                value = node.get(key)
                if isinstance(value, str) and os.path.splitext(value)[1].lower() in MODEL_EXT:
                    LABELS.setdefault(os.path.basename(value).lower(), label)
            ident = node.get("id")
            if isinstance(ident, str) and label:
                LABELS.setdefault(("id::" + ident).lower(), label)
            for value in node.values():
                walk(value, label)
        elif isinstance(node, list):
            for value in node:
                walk(value, inherited_label)

    walk(data, inherited)
    for key in ("visual_approval", "status", "review", "notes", "summary"):
        if isinstance(data, dict) and key in data:
            LABELS.setdefault(("meta::" + os.path.basename(path)).lower(), json.dumps(
                {key: data[key]}, ensure_ascii=False))


def lod_of(name):
    stem = os.path.splitext(name)[0]
    for level in ("LOD0", "LOD1", "LOD2", "LOD3"):
        if level in stem.upper():
            return level
    return "-"


def logical_key(name):
    stem = os.path.splitext(name)[0]
    upper = stem.upper()
    for level in ("_LOD0", "_LOD1", "_LOD2", "_LOD3"):
        if level in upper:
            stem = stem[: upper.index(level)]
            break
    return stem


def main():
    lab_copied_bytes = 0
    # 复制清单（含 sha256）来自 _work/copy_manifest.json
    copy_manifest = {}
    cm_path = os.path.join(LAB, "_work", "copy_manifest.json")
    if os.path.isfile(cm_path):
        with open(cm_path, "r", encoding="utf-8") as fh:
            for item in json.load(fh)["copies"]:
                copy_manifest[os.path.basename(item["source_relative_path"]).lower()] = item
                lab_copied_bytes += item["bytes"]

    folders = []
    total_files = 0
    total_bytes = 0
    logical_rows = []
    for rel_dir, category, manifest_names in SOURCES:
        abs_dir = os.path.join(REPO, rel_dir.replace("/", os.sep))
        if not os.path.isdir(abs_dir):
            folders.append({"dir": rel_dir, "category": category, "exists": False})
            continue
        for manifest_name in manifest_names:
            harvest_labels(os.path.join(abs_dir, manifest_name))
        files = walk_files(abs_dir)
        # Hero Kit 行只看 floor1 根目录本身，不重复统计它下面的子目录（那些各有自己的行）
        if "Hero Kit" in category:
            files = [f for f in files if os.path.dirname(os.path.abspath(f)) == os.path.abspath(abs_dir)]
        if "Market" in category:
            files = [f for f in files if os.path.basename(f).lower().startswith("startingtown_market")]
        groups = {}
        for path in files:
            name = os.path.basename(path)
            key = logical_key(name)
            groups.setdefault(key, []).append(path)
        folder_bytes = 0
        for path in files:
            folder_bytes += os.path.getsize(path)
        total_files += len(files)
        total_bytes += folder_bytes
        folders.append({
            "dir": rel_dir,
            "category": category,
            "exists": True,
            "model_files": len(files),
            "bytes": folder_bytes,
            "logical_models": len(groups),
        })
        for key in sorted(groups.keys()):
            variants = []
            for path in sorted(groups[key]):
                name = os.path.basename(path)
                low = name.lower()
                item = copy_manifest.get(low)
                variants.append({
                    "file": rel(path),
                    "name": name,
                    "lod": lod_of(name),
                    "bytes": os.path.getsize(path),
                    "sha256_in_manifest": (item or {}).get("source_sha256"),
                    "copied": low in COPIED,
                    "displayed_in_lab_scene": low in DISPLAYED,
                    "lab_path": COPIED.get(low),
                })
            label = None
            for variant in variants:
                label = LABELS.get(variant["name"].lower())
                if label:
                    break
            label = label or LABELS.get(("id::" + key).lower())
            logical_rows.append({
                "logical_id": key,
                "display_name": label,
                "label_source": "manifest" if label else "filename-derived",
                "category": category,
                "source_dir": rel_dir,
                "variant_count": len(variants),
                "bytes": sum(v["bytes"] for v in variants),
                "copied_variants": sum(1 for v in variants if v["copied"]),
                "displayed_variants": sum(1 for v in variants if v["displayed_in_lab_scene"]),
                "variants": variants,
            })

    generated_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    data = {
        "generated_at_utc": generated_at,
        "generator": "tools/build_catalog.py",
        "source_root": REPO,
        "lab_root": LAB,
        "scanned_dirs": [s[0] for s in SOURCES],
        "bounds": {"max_depth": MAX_DEPTH, "max_files": MAX_FILES, "model_ext": sorted(MODEL_EXT)},
        "scope_note": ("只扫描上列运行时光美术目录里的模型文件，不含 Blender 源文件、"
                       "不含 private/ 目录、不含其它工程；不是全仓库美术清单。"),
        "totals": {
            "logical_models": len(logical_rows),
            "model_files": total_files,
            "model_bytes": total_bytes,
            "copied_files": len(COPIED),
            "copied_bytes": lab_copied_bytes,
            "displayed_files": len(DISPLAYED),
        },
        "folders": folders,
        "models": logical_rows,
    }
    with open(os.path.join(LAB, "model_catalog.json"), "w", encoding="utf-8") as fh:
        json.dump(data, fh, ensure_ascii=False, indent=1)

    lines = []
    add = lines.append
    add("# 模型目录（MODEL_CATALOG）")
    add("")
    add("生成时间（UTC）：%s ｜ 生成器：`tools/build_catalog.py`" % generated_at)
    add("")
    add("**范围声明**：本目录只统计下面列出的运行时光美术目录里的模型文件（后缀 %s，"
        "遍历深度 <= %d，单目录文件数上限 %d，跳过 .godot/.git/cache/import 与 `*.import`）。"
        "它**不包含** Blender 源文件、`private/` 目录、其它工程或未列出的目录，"
        "也**不代表**全仓库美术清单。" % ("/".join(sorted(e.lstrip(".") for e in MODEL_EXT)), MAX_DEPTH, MAX_FILES))
    add("")
    add("**它是索引，不是批准**：`visual_approval`、`status` 等字段来自各目录 manifest；"
        "没有 manifest 的行显示名由文件名推导（`label_source=filename-derived`），不代表已获美术批准。")
    add("")
    add("## 总计")
    add("")
    add("| 指标 | 值 |")
    add("| --- | --- |")
    add("| 逻辑模型数 | %d |" % len(logical_rows))
    add("| 源模型文件数 | %d（%.1f MB） |" % (total_files, total_bytes / 1048576.0))
    add("| 已复制进实验室的文件 | %d（%.1f MB） |" % (len(COPIED), lab_copied_bytes / 1048576.0))
    add("| 已在预览场景里显示 | %d |" % len(DISPLAYED))
    add("")
    add("## 按源目录")
    add("")
    add("| 源目录（相对仓库） | 版本/类别 | 逻辑模型 | 模型文件 | 字节 |")
    add("| --- | --- | --- | --- | --- |")
    for folder in folders:
        if not folder.get("exists"):
            add("| `%s` | %s | 目录不存在 | - | - |" % (folder["dir"], folder["category"]))
            continue
        add("| `%s` | %s | %d | %d | %s |" % (folder["dir"], folder["category"],
                                              folder["logical_models"], folder["model_files"],
                                              "{:,}".format(folder["bytes"])))
    add("")
    add("## 全部逻辑模型与源文件变体")
    add("")
    add("`已复制` = 该文件已复制进 `C:/GodotAnimeLab`（复制件哈希见 `_work/copy_manifest.json`）；"
        "`已显示` = 该文件出现在默认预览场景 `scenes/material_lab.tscn` 里。")
    add("")
    current = None
    for row in logical_rows:
        if row["category"] != current:
            current = row["category"]
            add("")
            add("### %s" % current)
        name = row["display_name"] or "（无 manifest 标签）"
        add("")
        add("- **%s** ｜ 显示名：%s（%s） ｜ 变体 %d ｜ 合计 %s 字节" % (
            row["logical_id"], name, row["label_source"], row["variant_count"],
            "{:,}".format(row["bytes"])))
        add("")
        add("  | LOD | 源文件 | 字节 | 已复制 | 已显示 | 实验室路径 | sha256（源 manifest） |")
        add("  | --- | --- | --- | --- | --- | --- | --- |")
        for variant in row["variants"]:
            add("  | %s | `%s` | %s | %s | %s | %s | %s |" % (
                variant["lod"], variant["file"], "{:,}".format(variant["bytes"]),
                "是" if variant["copied"] else "否",
                "是" if variant["displayed_in_lab_scene"] else "否",
                ("`%s`" % variant["lab_path"]) if variant["lab_path"] else "-",
                ("`%s`" % variant["sha256_in_manifest"][:16] + "…") if variant["sha256_in_manifest"] else "-"))
    add("")
    add("## 未纳入（先说清楚）")
    add("")
    add("- 未列出的目录、`private/`、Blender `.blend` 源文件、其它工程资产都不在统计范围内。")
    add("- 场景里只用了上面标 `已显示` 的少数资产；其余仅为索引，没有复制、没有导入。")
    add("- 草稿/待评审目录（如 `deepseek_residences`）按 manifest 原样标注，不当作已批准资产。")
    add("")
    with open(os.path.join(LAB, "MODEL_CATALOG.md"), "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))
    print("models=%d files=%d bytes=%d copied=%d" % (len(logical_rows), total_files, total_bytes, len(COPIED)))


if __name__ == "__main__":
    sys.exit(main())
