import cairosvg
import io
import os
from pathlib import Path
from PIL import Image

BACKGROUND_COLOR = "#101418"

def generate_icon_png(svg_file):
    output_file = svg_file.replace('.svg', '.png')
    cairosvg.svg2png(
        url=svg_file,
        write_to=output_file,
        output_width=2000,
        output_height=2000,
        background_color=BACKGROUND_COLOR
    )
    print("Generated", output_file)

def render_launcher_view(svg_file, size):
    # Framed like the launcher: the visible 72dp of the 108dp layer, with the 9% inset of pubspec.yaml
    glyph_size = round(size * 108 / 72 * (1 - 2 * 0.09))
    glyph_png = cairosvg.svg2png(url=svg_file, output_width=glyph_size, output_height=glyph_size)
    glyph = Image.open(io.BytesIO(glyph_png)).convert("RGBA")
    img = Image.new("RGBA", (size, size), BACKGROUND_COLOR)
    offset = (size - glyph_size) // 2
    img.alpha_composite(glyph.crop((-offset, -offset, size - offset, size - offset)))
    return img

def generate_icon_png_for_readme(svg_file):
    readme_dir = Path(__file__).parent / "assets" / "readme"
    output_file = readme_dir / "icon.png"
    img = render_launcher_view(svg_file, 2000)
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

def generate_adaptive_foreground(svg_file):
    base_name = os.path.splitext(svg_file)[0]
    output_file = f"{base_name}-foreground-432x432.png"
    
    cairosvg.svg2png(
        url=svg_file,
        write_to=output_file,
        output_width=432,
        output_height=432,
    )
    print("Generated", output_file)

def generate_adaptive_monochrome(svg_file):
    base_name = os.path.splitext(svg_file)[0]
    output_file = f"{base_name}-monochrome-432x432.png"

    cairosvg.svg2png(
        url=svg_file,
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

def generate_adaptive_background(svg_file):
    base_name = os.path.splitext(svg_file)[0]
    output_file = f"{base_name}-background.png"

    img = Image.new("RGB", (432, 432), BACKGROUND_COLOR)
    img.save(output_file, "PNG")
    print("Generated", output_file)

def generate_store_icon(svg_file):
    output_file = Path(__file__).parent / "fastlane" / "metadata" / "android" / "en-US" / "images" / "icon.png"
    render_launcher_view(svg_file, 512).convert("RGB").save(str(output_file), "PNG")
    print("Generated", output_file)

def main():
    svg_file = str(Path(__file__).parent / "assets" / "icon.svg")
    generate_icon_png(svg_file)
    generate_icon_png_for_readme(svg_file)
    generate_adaptive_foreground(svg_file)
    generate_adaptive_monochrome(svg_file)
    generate_adaptive_background(svg_file)
    generate_store_icon(svg_file)

if __name__ == "__main__":
    main()