"""Renders the Google Play feature graphic (1024x500) from the app icon's design.

The logo mark is redrawn from app/assets/branding/icon.svg geometry (SVG units,
logo box x 50..350, y 150..250) so it stays crisp at any scale.
Usage: python make_feature_graphic.py <roboto font dir> <output.png>
"""

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

W, H = 1024, 500
SS = 3  # supersampling factor for anti-aliasing

BG_TOP = (0, 0, 0)
BG_BOTTOM = (0, 17, 103)

# Zone colors from app/lib/app/colors.dart.
BARS = [  # (x0, top y, color) in SVG units; each bar is 30 wide
    (50, 202, (78, 97, 121)),
    (80, 186, (0, 157, 244)),
    (110, 172, (1, 198, 83)),
    (140, 160, (253, 108, 0)),
]
PINK = (247, 27, 109)
ECG = [(170, 202), (229, 202), (234, 193), (239, 202), (244, 202), (246, 210),
       (254, 173), (260, 220), (263, 202), (268, 202), (270, 196), (274, 202),
       (350, 202)]

TITLE = "Cardio Rounds"
TAGLINE = "Heart rate zones & recovery"
FOOTNOTE = "Private  ·  Open source  ·  No ads"


def gradient(size, top, bottom):
    w, h = size
    img = Image.new("RGB", size)
    draw = ImageDraw.Draw(img)
    for y in range(h):
        t = y / (h - 1)
        draw.line([(0, y), (w, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))
    return img


def logo(k):
    """Draws the logo mark at k pixels per SVG unit."""
    w, h = round(300 * k), round(100 * k)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    def px(x, y):
        return ((x - 50) * k, (y - 150) * k)

    draw.rectangle([px(170, 150), px(350, 250)], fill=PINK)
    for x0, top, color in BARS:
        draw.rectangle([px(x0, top), px(x0 + 30, 250)], fill=color)
        # 3-unit shadow on the bar's right edge, fading in from the left.
        sx0, sx1 = round((x0 + 27 - 50) * k), round((x0 + 30 - 50) * k)
        for sx in range(sx0, sx1):
            a = round(255 * (sx - sx0 + 1) / (sx1 - sx0))
            draw.line([(sx, (top - 150) * k), (sx, h)], fill=(0, 0, 0, a))

    # Bottom 8-unit shadow across the whole mark.
    shade = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shade)
    sy0 = round(92 * k)
    for sy in range(sy0, h):
        sd.line([(0, sy), (w, sy)], fill=(0, 0, 0, round(150 * (sy - sy0 + 1) / (h - sy0))))
    img = Image.alpha_composite(img, shade)

    draw = ImageDraw.Draw(img)
    stroke = max(1, round(2 * k))
    for dy, color in [(4, (0, 0, 0)), (2, (255, 255, 255)), (0, (255, 255, 255))]:
        draw.line([px(x, y + dy) for x, y in ECG], fill=color, width=stroke, joint="curve")

    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w - 1, h - 1], radius=round(9 * k), fill=255)
    img.putalpha(Image.composite(img.getchannel("A"), mask, mask))
    return img


def main(font_dir, out_path):
    font_dir = Path(font_dir)
    canvas = gradient((W * SS, H * SS), BG_TOP, BG_BOTTOM).convert("RGBA")
    draw = ImageDraw.Draw(canvas)

    title_font = ImageFont.truetype(str(font_dir / "roboto-bold.ttf"), 66 * SS)
    tag_font = ImageFont.truetype(str(font_dir / "roboto-regular.ttf"), 30 * SS)
    foot_font = ImageFont.truetype(str(font_dir / "roboto-medium.ttf"), 21 * SS)

    mark = logo(1.25 * SS)
    gap = 48 * SS

    lines = [(TITLE, title_font, (255, 255, 255)),
             (TAGLINE, tag_font, (214, 214, 230)),
             (FOOTNOTE, foot_font, (144, 144, 168))]
    spacing = [0, 14 * SS, 26 * SS]  # space above each line
    boxes = [draw.textbbox((0, 0), t, font=f) for t, f, _ in lines]
    text_w = max(b[2] - b[0] for b in boxes)
    text_h = sum(b[3] - b[1] for b in boxes) + sum(spacing)

    x0 = (W * SS - (mark.width + gap + text_w)) // 2
    cy = H * SS // 2
    canvas.alpha_composite(mark, (x0, cy - mark.height // 2))

    tx = x0 + mark.width + gap
    ty = cy - text_h // 2
    for (text, font, color), box, space in zip(lines, boxes, spacing):
        ty += space
        draw.text((tx - box[0], ty - box[1]), text, font=font, fill=color)
        ty += box[3] - box[1]

    canvas.convert("RGB").resize((W, H), Image.LANCZOS).save(out_path, optimize=True)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
