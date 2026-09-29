#!/usr/bin/env python3
"""Draws the small textures used for particles, UI icons and the app icon."""
import math
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "godot", "textures")
os.makedirs(OUT, exist_ok=True)
S = 128  # draw big, downsample for smooth edges


def save(img, name, size=64):
    img.resize((size, size), Image.LANCZOS).save(os.path.join(OUT, name))
    print("  ", name)


def canvas():
    return Image.new("RGBA", (S * 2, S * 2), (0, 0, 0, 0))


def star_points(cx, cy, r_out, r_in, n=5, rot=-90):
    pts = []
    for i in range(n * 2):
        r = r_out if i % 2 == 0 else r_in
        a = math.radians(rot + i * 180 / n)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def heart_poly(cx, cy, s):
    pts = []
    for i in range(200):
        t = i / 200 * 2 * math.pi
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((cx + x * s, cy - y * s))
    return pts


def glow(img, radius):
    blurred = img.filter(ImageFilter.GaussianBlur(radius))
    return Image.alpha_composite(blurred, img)


# --- particle sprites (white, tinted in engine) ---
img = canvas()
d = ImageDraw.Draw(img)
d.polygon(star_points(S, S, S * 0.95, S * 0.18, n=4, rot=-90), fill=(255, 255, 255, 255))
save(glow(img, 10), "sparkle.png")

img = canvas()
for r in range(S, 0, -2):
    a = int(255 * (1 - r / S) ** 2)
    ImageDraw.Draw(img).ellipse([S - r, S - r, S + r, S + r], fill=(255, 255, 255, a))
save(img, "soft.png")

img = canvas()
ImageDraw.Draw(img).polygon(heart_poly(S, S * 1.05, 6.5), fill=(255, 255, 255, 255))
save(glow(img, 6), "heart.png")

img = canvas()
ImageDraw.Draw(img).polygon(star_points(S, S * 1.05, S * 0.9, S * 0.4), fill=(255, 255, 255, 255))
save(glow(img, 6), "star.png")

# --- UI icons (colored) ---
def icon(name, draw_fn):
    img = canvas()
    draw_fn(ImageDraw.Draw(img))
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    shadow.paste((90, 50, 110, 110), mask=img.split()[3])
    shadow = shadow.filter(ImageFilter.GaussianBlur(4))
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.alpha_composite(shadow, (0, 6))
    out.alpha_composite(img)
    save(out, name)


def coin(d):
    d.ellipse([30, 30, 226, 226], fill=(236, 170, 40), outline=(190, 120, 20), width=10)
    d.ellipse([62, 62, 194, 194], fill=(255, 212, 90))
    d.polygon(star_points(S, S, 50, 22), fill=(236, 170, 40))


def hp(d):
    d.polygon(heart_poly(S, S * 1.05, 6.8), fill=(255, 105, 150), outline=(215, 60, 110))
    d.ellipse([70, 70, 110, 105], fill=(255, 200, 220))


def mp(d):
    d.polygon(star_points(S, S * 1.05, 110, 50), fill=(110, 170, 255), outline=(60, 110, 220))
    d.ellipse([100, 90, 130, 118], fill=(210, 230, 255))


def shard(d):
    d.polygon([(S, 20), (200, 110), (S, 236), (56, 110)], fill=(190, 150, 255), outline=(130, 90, 220))
    d.polygon([(S, 20), (S, 236), (56, 110)], fill=(160, 120, 245))
    d.polygon([(S, 40), (150, 110), (S, 120)], fill=(240, 225, 255))


def muffin(d):
    d.polygon([(60, 140), (196, 140), (176, 230), (80, 230)], fill=(245, 150, 170), outline=(210, 100, 130))
    for x in range(80, 190, 22):
        d.line([(x, 145), (x - 4, 226)], fill=(220, 110, 140), width=5)
    d.ellipse([40, 60, 216, 170], fill=(240, 160, 70), outline=(200, 110, 40), width=6)
    d.ellipse([110, 40, 146, 76], fill=(230, 60, 90))


def tea(d):
    d.rounded_rectangle([56, 90, 180, 220], 30, fill=(150, 200, 255), outline=(90, 140, 220), width=6)
    d.ellipse([160, 110, 226, 180], outline=(90, 140, 220), width=14)
    d.ellipse([70, 80, 166, 110], fill=(255, 250, 200))
    d.polygon(star_points(118, 150, 26, 11), fill=(255, 250, 220))


def fire(d):
    d.polygon([(S, 20), (200, 130), (190, 200), (S, 236), (66, 200), (56, 130), (96, 90), (110, 140)],
              fill=(255, 120, 60), outline=(220, 70, 30))
    d.polygon([(S, 110), (166, 170), (S, 220), (90, 170)], fill=(255, 215, 90))


def ice(d):
    for a in range(0, 180, 60):
        r = math.radians(a)
        dx, dy = 100 * math.cos(r), 100 * math.sin(r)
        d.line([(S - dx, S - dy), (S + dx, S + dy)], fill=(120, 200, 255), width=22)
    d.ellipse([S - 30, S - 30, S + 30, S + 30], fill=(220, 245, 255))


def arcane(d):
    d.polygon(star_points(S, S, 110, 36, n=4), fill=(255, 150, 220), outline=(220, 90, 180))
    d.polygon(star_points(S, S, 50, 18, n=4, rot=-45), fill=(255, 235, 250))


def unknown(d):
    d.ellipse([30, 30, 226, 226], fill=(200, 190, 220), outline=(150, 135, 180), width=8)


icon("coin.png", coin)
icon("hp.png", hp)
icon("mp.png", mp)
icon("shard.png", shard)
icon("muffin.png", muffin)
icon("tea.png", tea)
icon("fire.png", fire)
icon("ice.png", ice)
icon("arcane.png", arcane)
icon("unknown.png", unknown)


def star_gold(d):
    d.polygon(star_points(S, S * 1.05, 110, 48), fill=(255, 205, 70), outline=(225, 150, 30))
    d.ellipse([100, 90, 130, 118], fill=(255, 245, 200))


icon("star_gold.png", star_gold)

# --- app icon: wizard hat on a twilight disc ---
img = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
for r in range(240, 0, -4):
    t = r / 240
    d.ellipse([256 - r, 256 - r, 256 + r, 256 + r],
              fill=(int(120 + 130 * t), int(90 + 80 * (1 - t)), int(200 - 20 * t), 255))
d.polygon([(256, 70), (360, 330), (152, 330)], fill=(120, 80, 200))
d.polygon([(256, 70), (256, 330), (152, 330)], fill=(100, 64, 180))
d.ellipse([96, 300, 416, 380], fill=(90, 58, 170))
d.rectangle([160, 290, 352, 320], fill=(255, 160, 200))
d.polygon(star_points(300, 200, 44, 18), fill=(255, 225, 110))
for (x, y, s) in ((120, 150, 16), (390, 170, 12), (380, 400, 14), (140, 400, 10)):
    d.polygon(star_points(x, y, s, s * 0.3, n=4), fill=(255, 250, 230))
img.resize((256, 256), Image.LANCZOS).save(os.path.join(ROOT, "godot", "icon.png"))
print("   icon.png")
