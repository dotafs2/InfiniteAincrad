# City Sample Houdini cache preview

This folder is a portable cache-only Houdini 21.0.440 preview of the official Epic Games City Sample Small City setup.

## Open

1. Open `CitySample_CachePreview_Original.hip` in Houdini.
2. The scene reads the three original official caches from `CACHES/` using `$HIP/CACHES/...` paths.
3. The `cache_city_view` merge is the visible output. The startup script in `houdini/scripts/456.py` cooks the caches and frames the viewport.

Included caches:

- `BUILDING_VOLUME.bgeo.sc`: building volume geometry
- `ROAD_GEOM.bgeo.sc`: road geometry
- `GROUND_PC.bgeo.sc`: ground point cloud

The cache files were restored from `C:\CitySample\CitySample_HoudiniFiles.zip` after a City Processor run had overwritten the working cache outputs. The original source tree at `C:\CitySample` was not modified. The patched `City_Processors.hda` is included for inspection under `houdini/otls/`; run any new processor output into a separate generated-cache directory so these reference caches remain unchanged.

This package is intentionally cache-only so it opens reliably in Houdini 21 without the Unreal-only source graph dependencies. The full local combined inspection scene remains in the working checkout under `tmp/citysample-source/Small_City/CitySample_CombinedDemo_OriginalCache.hip`.
