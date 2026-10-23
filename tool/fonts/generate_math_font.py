import io
import unicodedata
from pathlib import Path

import requests
from fontTools.feaLib.builder import addOpenTypeFeaturesFromString
from fontTools.subset import Options, Subsetter
from fontTools.ttLib import TTFont

# Posts write bold or italic with the mathematical letters of Unicode. The fallback fonts of Android lack
# the combining accents they carry, so the app falls back to this subset of Noto Sans Math, which has them.
SOURCE_URL = "https://fonts.gstatic.com/s/notosansmath/v19/7Aump_cpkSecTWaHRlH2hyV5UHkD.woff2"
OUTPUT = Path(__file__).parents[2] / "assets" / "fonts" / "NotoSansMath-Accents.ttf"
UNICODES = [*range(0x0300, 0x0370), *range(0x2100, 0x2150), *range(0x1D400, 0x1D800)]
STYLED_LETTERS = [*range(0x2100, 0x2150), *range(0x1D400, 0x1D800)]


def download_font():
    font = TTFont(io.BytesIO(requests.get(SOURCE_URL, timeout=60).content))
    font.flavor = None
    return font


def subset(font):
    options = Options()
    options.layout_features = ["*"]
    options.notdef_outline = True
    options.name_IDs = ["*"]
    subsetter = Subsetter(options)
    subsetter.populate(unicodes=UNICODES)
    subsetter.subset(font)


def mark_to_base_subtables(font):
    for lookup in font["GPOS"].table.LookupList.Lookup:
        for subtable in lookup.SubTable:
            subtable = subtable.ExtSubTable if lookup.LookupType == 9 else subtable
            if subtable.LookupType == 4:
                yield subtable


def plain_letters(font):
    cmap = font.getBestCmap()
    pairs = ((cmap.get(code), unicodedata.normalize("NFKC", chr(code))) for code in STYLED_LETTERS)
    return {styled: plain for styled, plain in pairs if styled and len(plain) == 1}


def anchor(record):
    return f"<anchor {record.XCoordinate} {record.YCoordinate}>"


def moved_anchor(record, plain, styled):
    x = record.XCoordinate - (plain.xMin + plain.xMax) / 2 + (styled.xMin + styled.xMax) / 2
    above = record.YCoordinate >= (plain.yMin + plain.yMax) / 2
    y = record.YCoordinate + (styled.yMax - plain.yMax if above else styled.yMin - plain.yMin)
    return f"<anchor {round(x)} {round(y)}>"


def base_anchors(font, source, subtable):
    glyf, source_glyf, source_cmap = font["glyf"], source["glyf"], source.getBestCmap()
    bases = {glyph: record.BaseAnchor[0] for glyph, record in zip(subtable.BaseCoverage.glyphs, subtable.BaseArray.BaseRecord)}
    kept = {glyph: anchor(record) for glyph, record in bases.items() if glyph in glyf}
    plain_glyphs = {styled: source_cmap.get(ord(plain)) for styled, plain in plain_letters(font).items()}
    moved = {styled: moved_anchor(bases[plain], source_glyf[plain], glyf[styled])
             for styled, plain in plain_glyphs.items()
             if plain in bases and styled not in kept and glyf[styled].numberOfContours}
    return kept | moved


def accents_lookup(font, source, index, subtable):
    marks = [f"markClass {mark} {anchor(record.MarkAnchor)} @accents{index};"
             for mark, record in zip(subtable.MarkCoverage.glyphs, subtable.MarkArray.MarkRecord) if mark in font["glyf"]]
    bases = [f"pos base {glyph} {position} mark @accents{index};"
             for glyph, position in base_anchors(font, source, subtable).items()]
    return "\n".join([*marks, f"lookup accents{index} {{", *bases, f"}} accents{index};"])


def accents_feature(font, source):
    lookups = [accents_lookup(font, source, index, subtable)
               for index, subtable in enumerate(mark_to_base_subtables(source))]
    return "\n".join(lookups) + "\nfeature mark {\n" + "\n".join(
        f"lookup accents{index};" for index in range(len(lookups))) + "\n} mark;"


def rename(font, family):
    for record in font["name"].names:
        if record.nameID in (1, 4, 16):
            record.string = family
        if record.nameID == 3:
            record.string = record.toUnicode().replace("NotoSansMath", family.replace(" ", ""))
        if record.nameID == 6:
            record.string = family.replace(" ", "")


def main():
    source = download_font()
    font = download_font()
    subset(font)
    addOpenTypeFeaturesFromString(font, accents_feature(font, source))
    rename(font, "Noto Sans Math Accents")
    OUTPUT.parent.mkdir(exist_ok=True)
    font.save(OUTPUT)
    print("Generated", OUTPUT)


if __name__ == "__main__":
    main()
