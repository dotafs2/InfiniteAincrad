"""Assemble this parallel art contribution from three explicitly owned packs."""
import json, hashlib, datetime
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
packs=[
 ('店铺外立面','ShopfrontDetails20260912','shopfront_details_20260912',['ShopfrontDetails20260912.blend'],'shopfront/overview.png'),
 ('职业工坊设备','ArtisanWorkshops20260912','artisan_workshops_20260912',['artisan_workshops_library.blend'],'workshops/workshops_overview.png'),
 ('旅行与河岸运输','TravelCargo20260912','travel_cargo_20260912',['travel_cargo_library.blend','river_trade_library.blend'],'travel/travel_contact_sheet.png')]
audit=json.loads((HERE/'glb_audit.json').read_text(encoding='utf-8'))
godot=json.loads((HERE/'godot_import.json').read_text(encoding='utf-8'))
by_file={a['file']:a for a in audit['files']};deliveries=[];all_assets=[]
for title,source,runtime,libraries,overview in packs:
    source_dir=ROOT/'Art/Generated'/source
    manifest=json.loads((source_dir/'manifest.json').read_text(encoding='utf-8'))
    for asset in manifest['assets']:
        p=(ROOT/asset['file']).resolve();assert p.is_relative_to(ROOT)
        sha=hashlib.sha256(p.read_bytes()).hexdigest()
        assert sha==asset['sha256']==by_file[asset['file']]['sha256'],asset['id']+' hash mismatch'
        assert asset['triangles']==by_file[asset['file']]['triangles'],asset['id']+' triangle mismatch'
    sources=[]
    for filename in libraries:
        p=source_dir/filename;assert p.stat().st_size>1000
        sources.append({'file':p.relative_to(ROOT).as_posix(),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
    entry={'title_zh':title,'asset_count':len(manifest['assets']),'manifest':(source_dir/'manifest.json').relative_to(ROOT).as_posix(),
      'runtime_directory':'game/assets/generated/'+runtime,'source_libraries':sources,'overview':overview,
      'triangles':sum(a['triangles'] for a in manifest['assets']),'glb_bytes':sum(by_file[a['file']]['bytes'] for a in manifest['assets'])}
    deliveries.append(entry);all_assets+=manifest['assets']
assert len(all_assets)==audit['glb_count']==godot['tested']==70
assert not audit['errors'] and not godot['failures'] and audit['degenerate_triangles']==0
report={'thread_id':'01a09446-f4cf-7f52-8014-261e856a140b','generated_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
 'checkout':str(ROOT),'baseline_commit':'71f7640','asset_count':len(all_assets),'packs':deliveries,
 'source_library_count':sum(len(p['source_libraries']) for p in deliveries),'total_triangles':audit['total_triangles_including_lods'],
 'total_glb_bytes':sum(p['glb_bytes'] for p in deliveries),'binary_audit':'70/70, no errors or tiny triangles; valid normals/materials/UV0',
 'godot_import':'70/70 GLTFDocument import, no world loaded','world_or_gameplay_claims':False,
 'scope':'Local static art contribution only, separate from neighboring 108-asset contribution. No new resident or GM runs, reset, commit or push.',
 'usage_ledger':'C:/InfiniteAincrad/private/art_parallel_20260912_usage.json','assets':all_assets}
(HERE/'delivery.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
lines=['# 并行美术交付：新增70件','',
 '用户本次明确授权两个 GPT-6 Astra Ultra 子 Agent 加根代理并行制作 Blender 美术，截止北京时间2026-09-12 15:00。本页只统计该并行线程新增资产，邻线程的108件另计。','',
 '| 资产组 | 独立模型 | GLB三角数 | 编辑源 |','| --- | ---: | ---: | --- |']
for p in deliveries:
    links=' · '.join('['+Path(b['file']).name+'](../../../'+b['file']+')' for b in p['source_libraries'])
    lines.append(f"| {p['title_zh']} | {p['asset_count']} | {p['triangles']:,} | {links} |")
lines += ['',f"总计 **70件独立GLB、4个可编辑Blender库、{report['total_triangles']:,}个三角形、{report['total_glb_bytes']/1024/1024:.2f} MiB GLB**。",'',
 '**验证：** [独立二进制审计](glb_audit.json) 70/70通过，有限坐标、单位法线、材质索引与UV有效，退化三角0；[Godot实际导入](godot_import.json) 70/70通过，未加载世界场景或存档。旅行组另有[Blender回导36/36](travel/blender_roundtrip.json)，店面/工坊回导证据在各子目录。交付清单逐件重新计算SHA-256，并与各组manifest及审计记录核对。','',
 '**近景修订：** 修复曲管截面跳变导致的轮箍黑缝、使运输绳网贴合货物；店面修正雨檐椽条、烟囱错缝和橱窗格数标注；工坊同步曲管连续截面修正。初次失败/中止日志保留，最终以各组最终验证记录为准。','',
 '**使用范围：** 静态装饰资产；没有新增碰撞、LOD、车辆操作、生产技能或居民行为。窗门按各自manifest记录的墙面挂点安装，需要宿主立面预留位置。运输与工坊按米制地面原点使用。图集为方便比较而归一化展示尺寸，GLB保持实际米制比例。','',
 '**来源与权限：** 原创程序几何，使用本项目已有最小几何辅助函数；没有导入受限人物、私有存档或外部模型。项目统一再分发许可仍由维护者决定。本批没有使用reset、调用居民模型、提交或推送Git。','',
 '完整可机读清单：[delivery.json](delivery.json)。每组源目录README包含重建命令及限制。根代理与子Agent用量按各会话累计计数的增量写入私有ledger；不能把账号共享额度变化归为本线程精确费用。','',
 '## 真实渲染图集','']
for p in deliveries:lines += ['### '+p['title_zh'],'','!['+p['title_zh']+']('+p['overview']+')','']
lines += ['### 河岸运输补充12件','','![河岸运输](travel/river_trade_contact_sheet.png)','','### 旅行营地近景','','![营地近景](travel/caravan_camp_detail.png)','','### 河舟近景','','![河舟近景](travel/river_trade_detail.png)','']
(HERE/'README.md').write_text('\n'.join(lines),encoding='utf-8')
print(json.dumps({k:report[k] for k in ('asset_count','source_library_count','total_triangles','total_glb_bytes')},ensure_ascii=False))
