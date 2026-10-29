import cairosvg
import io
import xml.etree.ElementTree as ET
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).parent
ANDROID_RES = ROOT / "android" / "app" / "src" / "main" / "res"
ANDROID = "{http://schemas.android.com/apk/res/android}"
SVG_ATTRIBUTES = {
    "pathData": "d",
    "fillColor": "fill",
    "strokeColor": "stroke",
    "strokeWidth": "stroke-width",
    "strokeLineCap": "stroke-linecap",
}

def android_attributes(element):
    return {name.removeprefix(ANDROID): value for name, value in element.attrib.items()}

def svg_path(path):
    attributes = android_attributes(path)
    unsupported = attributes.keys() - SVG_ATTRIBUTES.keys()
    if unsupported:
        raise ValueError(f"Attributes of the logo drawable that cannot be converted to SVG: {unsupported}")
    svg_attributes = {"fill": "none", **{SVG_ATTRIBUTES[name]: value for name, value in attributes.items()}}
    return ET.Element("path", svg_attributes)

def logo_svg(drawable_file):
    vector = ET.parse(drawable_file).getroot()
    unsupported = {child.tag for child in vector} - {"path"}
    if unsupported:
        raise ValueError(f"Elements of the logo drawable that cannot be converted to SVG: {unsupported}")
    attributes = android_attributes(vector)
    svg = ET.Element("svg", {
        "xmlns": "http://www.w3.org/2000/svg",
        "viewBox": f"0 0 {attributes['viewportWidth']} {attributes['viewportHeight']}",
    })
    svg.extend(svg_path(path) for path in vector)
    return ET.tostring(svg)

def launcher_background_color(colors_file):
    return ET.parse(colors_file).getroot().find("color[@name='ic_launcher_background']").text

LOGO_SVG = logo_svg(ANDROID_RES / "drawable" / "ic_logo.xml")
BACKGROUND_COLOR = launcher_background_color(ANDROID_RES / "values" / "colors.xml")

def generate_icon_png():
    output_file = str(ROOT / "assets" / "icon.png")
    cairosvg.svg2png(
        bytestring=LOGO_SVG,
        write_to=output_file,
        output_width=2000,
        output_height=2000,
        background_color=BACKGROUND_COLOR
    )
    print("Generated", output_file)

def render_launcher_view(size):
    # Framed like the launcher: the visible 72dp of the 108dp layer, with the 9% inset of mipmap-anydpi-v26/ic_launcher.xml
    glyph_size = round(size * 108 / 72 * (1 - 2 * 0.09))
    glyph_png = cairosvg.svg2png(bytestring=LOGO_SVG, output_width=glyph_size, output_height=glyph_size)
    glyph = Image.open(io.BytesIO(glyph_png)).convert("RGBA")
    img = Image.new("RGBA", (size, size), BACKGROUND_COLOR)
    offset = (size - glyph_size) // 2
    img.alpha_composite(glyph.crop((-offset, -offset, size - offset, size - offset)))
    return img

def generate_icon_png_for_readme():
    readme_dir = ROOT / "assets" / "readme"
    output_file = readme_dir / "icon.png"
    img = render_launcher_view(2000)
    width, height = img.size
    radius = int(min(width, height) * 0.25)
    mask = Image.new("L", (width, height), 0)
    from PIL import ImageDraw
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle(
        [(0, 0), (width, height)],
        radius=radius,
        fill=255
    )
    result = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    result.paste(img, (0, 0))
    result.putalpha(mask)
    result.save(str(output_file), "PNG")
    print("Generated", output_file)

def generate_monochrome():
    output_file = str(ROOT / "assets" / "icon-monochrome-432x432.png")

    cairosvg.svg2png(
        bytestring=LOGO_SVG,
        write_to=output_file,
        output_width=432,
        output_height=432,
    )
    img = Image.open(output_file).convert("RGBA")
    mono_img = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    for x in range(432):
        for y in range(432):
            r, g, b, a = img.getpixel((x, y))
            if a > 0:
                mono_img.putpixel((x, y), (255, 255, 255, a))

    mono_img.save(output_file, "PNG")
    print("Generated", output_file)

def generate_store_icon():
    output_file = ROOT / "fastlane" / "metadata" / "android" / "en-US" / "images" / "icon.png"
    render_launcher_view(512).convert("RGB").save(str(output_file), "PNG")
    print("Generated", output_file)

def main():
    generate_icon_png()
    generate_icon_png_for_readme()
    generate_monochrome()
    generate_store_icon()

if __name__ == "__main__":
    main()