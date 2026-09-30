#!/usr/bin/env python3
"""Icons for the skill tree, attributes and equipment (drawn big, downsampled)."""
import math
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "godot", "textures")
S = 256
INK = (74, 50, 98, 255)


def canvas():
    return Image.new("RGBA", (S, S), (0, 0, 0, 0))


def finish(img, name, glow_col=None):
    if glow_col:
        g = Image.new("RGBA", img.size, (0, 0, 0, 0))
        a = img.split()[3].filter(ImageFilter.GaussianBlur(10))
        g.paste(Image.new("RGBA", img.size, glow_col), (0, 0), a)
        img = Image.alpha_composite(g, img)
    img.resize((64, 64), Image.LANCZOS).save(os.path.join(OUT, name))
    print("  ", name)


def outlined(draw_fn, fill, width=10):
    """Draws a shape twice: a dark rim, then the fill slightly inset."""
    img = canvas()
    d = ImageDraw.Draw(img)
    draw_fn(d, INK, width)
    draw_fn(d, fill, 0)
    return img


def star_pts(cx, cy, ro, ri, n=5, rot=-90):
    pts = []
    for i in range(n * 2):
        r = ro if i % 2 == 0 else ri
        a = math.radians(rot + i * 180 / n)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def poly(pts):
    def f(d, col, w):
        if w:
            d.polygon(pts, fill=col, outline=col)
            d.line(pts + [pts[0]], fill=col, width=w * 2, joint="curve")
        else:
            d.polygon(pts, fill=col)
    return f


# Sparkle Bolt: a streaking comet star.
img = canvas()
d = ImageDraw.Draw(img)
for i in range(6):
    t = i / 6
    d.ellipse([40 + t * 70, 150 - t * 60 - 14, 70 + t * 70, 150 - t * 60 + 14], fill=(255, 170, 225, int(90 + 120 * t)))
img2 = outlined(poly(star_pts(170, 95, 70, 30)), (255, 214, 240, 255))
finish(Image.alpha_composite(img, img2), "bolt.png", (255, 120, 200, 160))

# Moon Step: crescent moon.
def crescent(d, col, w):
    d.ellipse([48 - w, 40 - w, 208 + w, 200 + w], fill=col)
img = outlined(crescent, (255, 236, 160, 255))
ImageDraw.Draw(img).ellipse([98, 22, 250, 174], fill=(0, 0, 0, 0))
finish(img, "moon.png", (255, 220, 120, 150))

# Thunder Bell: a lightning bolt.
bolt = [(150, 20), (70, 140), (125, 140), (95, 236), (190, 104), (135, 104), (170, 20)]
finish(outlined(poly(bolt), (255, 232, 110, 255)), "thunder.png", (255, 230, 90, 170))

# Petal Shield: a heart-topped shield.
shield = [(128, 28), (214, 62), (206, 150), (128, 228), (50, 150), (42, 62)]
img = outlined(poly(shield), (170, 220, 255, 255))
ImageDraw.Draw(img).polygon(star_pts(128, 118, 46, 20), fill=(255, 180, 220, 255))
finish(img, "shield.png", (140, 200, 255, 140))

# Equipment: wand, hat, robe, charm.
img = canvas()
d = ImageDraw.Draw(img)
d.line([(60, 210), (170, 90)], fill=INK, width=34)
d.line([(60, 210), (170, 90)], fill=(170, 120, 90, 255), width=20)
d.polygon(star_pts(182, 76, 58, 24), fill=INK)
d.polygon(star_pts(182, 76, 46, 18), fill=(255, 225, 120, 255))
finish(img, "wand.png", (255, 220, 120, 120))

hat = [(128, 20), (178, 150), (236, 170), (236, 196), (20, 196), (20, 170), (78, 150)]
img = outlined(poly(hat), (190, 150, 240, 255))
ImageDraw.Draw(img).rectangle([74, 150, 182, 170], fill=(255, 200, 110, 255))
finish(img, "hat.png")

robe = [(96, 30), (160, 30), (200, 70), (236, 120), (206, 140), (190, 112), (212, 230), (44, 230), (66, 112), (50, 140), (20, 120), (56, 70)]
img = outlined(poly(robe), (255, 170, 205, 255))
d = ImageDraw.Draw(img)
for y in (90, 130, 170):
    d.ellipse([120, y, 136, y + 16], fill=(255, 240, 200, 255))
finish(img, "robe.png")

img = canvas()
d = ImageDraw.Draw(img)
d.arc([70, 10, 186, 130], 200, 340, fill=INK, width=12)
d.ellipse([54, 84, 202, 232], fill=INK)
d.ellipse([66, 96, 190, 220], fill=(140, 230, 210, 255))
d.ellipse([92, 116, 132, 150], fill=(230, 255, 250, 255))
finish(img, "charm.png", (120, 230, 210, 140))

# Treasure: a little chest (item drop / bag).
img = canvas()
d = ImageDraw.Draw(img)
d.rounded_rectangle([30, 90, 226, 222], 24, fill=INK)
d.rounded_rectangle([42, 102, 214, 210], 18, fill=(214, 150, 100, 255))
d.pieslice([30, 30, 226, 150], 180, 360, fill=INK)
d.pieslice([42, 42, 214, 140], 180, 360, fill=(236, 176, 120, 255))
d.rectangle([112, 96, 144, 140], fill=(255, 220, 110, 255))
finish(img, "chest.png", (255, 220, 120, 150))

# Attributes.
fist = [(70, 200), (70, 110), (100, 70), (190, 70), (206, 100), (206, 170), (180, 210)]
img = outlined(poly(fist), (255, 170, 150, 255))
d = ImageDraw.Draw(img)
for x in (110, 140, 170):
    d.line([(x, 72), (x, 120)], fill=INK, width=6)
finish(img, "str.png")

book = [(40, 60), (128, 80), (216, 60), (216, 210), (128, 230), (40, 210)]
img = outlined(poly(book), (150, 190, 255, 255))
ImageDraw.Draw(img).line([(128, 80), (128, 228)], fill=INK, width=8)
ImageDraw.Draw(img).polygon(star_pts(84, 140, 26, 11), fill=(255, 240, 160, 255))
finish(img, "int.png")

img = canvas()
d = ImageDraw.Draw(img)
pts = []
for i in range(120):
    t = i / 120 * 2 * math.pi
    x = 16 * math.sin(t) ** 3
    y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
    pts.append((128 + x * 6.6, 132 - y * 6.6))
d.polygon(pts, fill=INK)
pts2 = [(128 + (x - 128) * 0.86, 132 + (y - 132) * 0.86) for x, y in pts]
d.polygon(pts2, fill=(255, 120, 150, 255))
d.rectangle([114, 90, 142, 170], fill=(255, 255, 255, 255))
d.rectangle([88, 116, 168, 144], fill=(255, 255, 255, 255))
finish(img, "vit.png")

feather = [(200, 24), (230, 60), (160, 170), (70, 232), (56, 220), (110, 140)]
img = outlined(poly(feather), (170, 240, 200, 255))
ImageDraw.Draw(img).line([(206, 40), (66, 226)], fill=INK, width=6)
finish(img, "agi.png")

img = canvas()
d = ImageDraw.Draw(img)
for ang in (0, 90, 180, 270):
    a = math.radians(ang)
    cx, cy = 128 + math.cos(a) * 48, 118 + math.sin(a) * 48
    d.ellipse([cx - 50, cy - 50, cx + 50, cy + 50], fill=INK)
for ang in (0, 90, 180, 270):
    a = math.radians(ang)
    cx, cy = 128 + math.cos(a) * 48, 118 + math.sin(a) * 48
    d.ellipse([cx - 40, cy - 40, cx + 40, cy + 40], fill=(120, 220, 120, 255))
d.line([(128, 150), (150, 240)], fill=INK, width=14)
finish(img, "luk.png")

# Skill point: a rounded diamond gem.
gem = [(128, 20), (220, 110), (128, 236), (36, 110)]
img = outlined(poly(gem), (200, 170, 255, 255))
ImageDraw.Draw(img).polygon([(128, 40), (190, 110), (128, 110)], fill=(236, 220, 255, 255))
finish(img, "gem.png", (190, 150, 255, 150))
