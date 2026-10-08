"""Reconstruct current UI draw commands and composite offline asset previews."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
SHOW = HERE.parent
original = ROOT / "tools/render_ui_layout.py"
source = original.read_text()
start = source.index("    d=ImageDraw.Draw(image)\n    def label")
end = source.index("    image.convert('RGB').resize", start)
source = source[:start] + source[end:]
source = source.replace("image = Image.new('RGBA', (540*S, 960*S), '#dce3eb')", "image = Image.new('RGBA', (540*S, 960*S), (0,0,0,0))")
source = source.replace("return image.convert('RGB')", "return image")
ns = {"__name__": "offline_ui_renderer", "__file__": str(original)}
exec(compile(source, str(original), "exec"), ns)
ns["OUT"] = HERE
OUT = HERE / "rendered"
OUT.mkdir(exist_ok=True)


def preview(image, path, rect):
    x, y, width, height = (round(v*2) for v in rect)
    art = Image.open(path).convert("RGBA")
    if art.getextrema()[3][0] == 0:
        bounds = art.getbbox()
        if bounds: art = art.crop(bounds)
    art = ImageOps.contain(art, (width-10, height-10), Image.Resampling.LANCZOS)
    image.alpha_composite(art, (x+(width-art.width)//2, y+(height-art.height)//2))


def main():
    results = []
    for path in sorted(HERE.glob("*.json")):
        data = json.loads(path.read_text())
        if "commands" not in data: continue
        name = path.stem
        image = ns["render"](name)
        for skin, rect in zip(data.get("card_ids", []), data.get("preview_rects", [])):
            asset = SHOW / "skins" / (skin + ".png")
            assert asset.exists(), asset
            preview(image, asset, rect)
        if data.get("hero_visible"):
            hero = SHOW / "city" / ("home-" + data["selected_map"] + "-miniature.png")
            if hero.exists():
                preview(image, hero, [-8,188,556,296])
            else:
                d = ImageDraw.Draw(image)
                f = ns["font"](17)
                d.text((540, 640), "3D miniature not captured", font=f, anchor="mm", fill="#fffdf7")
        # Background photographs are deliberately not placed behind a fixture
        # HUD: the two would not be a single recorded game state.
        base = Image.new("RGBA", image.size, "#dce3eb")
        base.alpha_composite(image)
        if data["phase"] in ["intro", "playing"]:
            d = ImageDraw.Draw(base)
            d.text((540,1120),"UI LAYOUT / TEST STATE",font=ns["font"](18),anchor="mm",fill="#576984")
        out = OUT / (name + ".png")
        base.convert("RGB").resize((720,1280),Image.Resampling.LANCZOS).save(out)
        results.append({"file":str(out.relative_to(SHOW)),"skin_ids":data.get("card_ids",[]),"ui_source_sha256":data["source_sha256"]})
    (HERE / "composition.json").write_text(json.dumps({"scope":"Current 2D draw commands plus offline skin/miniature asset renders; no viewport recording", "screens":results},indent=2)+"\n")
    print("Reconstructed %d UI screens with current skin assets." % len(results))


if __name__ == "__main__":main()
