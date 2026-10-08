# Clearcoat source verification

The proposed removal of clearcoat was withdrawn after checking the primary sources. The claim that Godot 4.5 limits clearcoat to Forward+ was incorrect: the tutorial's Forward+-only sentence belongs to **Subsurface Scattering**, not Clearcoat.

- [Godot 4.5 Standard Material tutorial](https://docs.godotengine.org/en/4.5/tutorials/3d/standard_material_3d.html#clearcoat) describes clearcoat as an added specular layer. Its later subsurface-scattering section carries the renderer restriction.
- [Godot 4.5 Compatibility GLES3 shader](https://github.com/godotengine/godot/blob/4.5-stable/drivers/gles3/shaders/scene.glsl#L1323) implements the `LIGHT_CLEARCOAT_USED` branch, and its directional-light path passes clearcoat values into that calculation.
- [BaseMaterial3D clearcoat API](https://docs.godotengine.org/en/stable/classes/class_basematerial3d.html#class-basematerial3d-property-clearcoat-enabled) describes the additional specular calculation and notes that unshaded materials do not display it.

Accordingly, the original reviewed skin material remains unchanged: clearcoat enabled, strength 0.22 and roughness 0.30, alongside the ordinary per-pixel material. There is no new custom shader or renderer switch. Exact source restoration is checked against `prior-coated/`; the temporary no-coat implementation and its 547-check receipt are retained under `withdrawn-simplification/` and are **not the shipped proposal**. The restored final author suite again has 486 checks, and the final images/manifest are the original coated previews.

This establishes source-level Compatibility support; it does not certify current browser pixels. Blender's Principled lighting remains an approximation of Godot's rendering, as the contact sheet and main report state. The previews must not be presented as gameplay screenshots or renderer-equivalent evidence.
