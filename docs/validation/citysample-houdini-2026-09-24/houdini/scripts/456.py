import os
import hou

hou.setUpdateMode(hou.updateMode.AutoUpdate)
_state = {'done': False}


def _init_citysample():
    if _state['done']:
        return
    try:
        preview = hou.node('/obj/CitySample_CachePreview')
        official = hou.node('/obj/Small_City')
        if official:
            official.setDisplayFlag(False)
        if preview:
            preview.setDisplayFlag(True)
        for path in (
            '/obj/CitySample_CachePreview/building_volume_cache',
            '/obj/CitySample_CachePreview/road_geometry_cache',
            '/obj/CitySample_CachePreview/ground_points_cache',
        ):
            node = hou.node(path)
            if node:
                node.cook(force=True)
        merge = hou.node('/obj/CitySample_CachePreview/cache_city_view')
        if merge:
            merge.setDisplayFlag(True)
            merge.setRenderFlag(True)
            merge.cook(force=True)
            merge.setSelected(True, clear_all_selected=True)
        target = hou.node('/obj/Small_City') or hou.node('/obj/CitySample_CachePreview')
        for pane in hou.ui.paneTabs():
            if pane.type() == hou.paneTabType.NetworkEditor and target:
                pane.setPwd(target)
        for viewer in hou.ui.paneTabs():
            if viewer.type() == hou.paneTabType.SceneViewer:
                viewer.curViewport().homeAll()
        root = hou.expandString('$HIP')
        with open(os.path.join(root, 'startup_456_ran.txt'), 'w') as f:
            f.write('AutoUpdate cache preview initialized\n')
    except Exception as exc:
        try:
            root = hou.expandString('$HIP')
            with open(os.path.join(root, 'startup_456_error.txt'), 'w') as f:
                f.write(repr(exc))
        except Exception:
            pass
    finally:
        _state['done'] = True


try:
    hou.ui.addEventLoopCallback(_init_citysample)
except Exception:
    _init_citysample()
