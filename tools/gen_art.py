#!/usr/bin/env python3
"""XenoHeart art generator — bold-ink "SVG in code" sprites.

Design language:
  * heavy clean black outlines (variable line weight: thick silhouettes,
    thin interior details)
  * flat cel fills, minimal shading (one soft shadow band per shape)
  * pointy-top hex terrain textures with distinct geometric grid contrast

All sprites are 96x96 RGBA PNGs on transparent canvas. Output is
deterministic (no randomness) so builds are reproducible.
"""
import math
import os
import sys
from PIL import Image, ImageDraw, ImageFilter

SIZE = 96
OUT = sys.argv[1] if len(sys.argv) > 1 else "art/sprites"
os.makedirs(OUT, exist_ok=True)

INK = (18, 16, 14, 255)          # near-black ink
PAPER = (245, 240, 228, 255)     # paper white

# palette (muted, storybook-ink)
GRASS_A = (178, 205, 143, 255)
GRASS_B = (156, 188, 122, 255)
OCEAN_A = (122, 168, 190, 255)
OCEAN_B = (98, 145, 176, 255)
HILL_A = (196, 178, 148, 255)
HILL_B = (168, 150, 120, 255)
BARK = (122, 96, 66, 255)
LEAF = (128, 164, 96, 255)
ORE = (150, 128, 190, 255)
STONE = (188, 186, 178, 255)
CHEST_A = (176, 132, 74, 255)
CHEST_B = (146, 104, 54, 255)
GOLD = (214, 178, 92, 255)
SKIN = (244, 214, 188, 255)
HAIR = (74, 62, 54, 255)
CLOTH = (214, 148, 96, 255)
CLOTH_D = (190, 122, 74, 255)
ZOMB = (128, 156, 112, 255)
ZOMB_D = (104, 132, 92, 255)
WOLF = (148, 148, 158, 255)
WOLF_D = (116, 116, 132, 255)
VIL_A = (168, 148, 190, 255)
VIL_B = (140, 120, 164, 255)
CRYST = (110, 82, 170, 255)
CRYST_D = (82, 58, 138, 255)
DARK_A = (74, 70, 88, 255)
DARK_B = (58, 54, 72, 255)
PATH_A = (216, 200, 168, 255)
BUILD_A = (222, 208, 182, 255)
BUILD_B = (196, 180, 152, 255)
ROOF_A = (168, 92, 82, 255)
ROOF_B = (144, 74, 66, 255)


def hex_points(cx, cy, r, pointy=True):
    """Pointy-top hexagon vertices."""
    pts = []
    for i in range(6):
        ang = math.radians(60 * i - 30 if pointy else 60 * i)
        pts.append((cx + r * math.cos(ang), cy + r * math.sin(ang)))
    return pts


def new_canvas():
    return Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))


def save(img, name):
    p = os.path.join(OUT, name + ".png")
    img.save(p)
    print("wrote", p)


# ================================================================ terrain

def tex_grass():
    img = new_canvas()
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, SIZE, SIZE], fill=GRASS_A)
    # a few soft blades (thin ink lines)
    d.line([20, 66, 24, 52], fill=GRASS_B, width=3)
    d.line([58, 74, 62, 60], fill=GRASS_B, width=3)
    d.line([76, 40, 72, 28], fill=GRASS_B, width=2)
    d.line([40, 30, 44, 20], fill=GRASS_B, width=2)
    return img


def tex_ocean():
    img = new_canvas()
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, SIZE, SIZE], fill=OCEAN_A)
    for y, x0 in [(28, 8), (52, 30), (76, 4)]:
        d.arc([x0, y - 8, x0 + 52, y + 8], 200, 340, fill=INK, width=3)
        d.arc([x0, y - 14, x0 + 52, y + 2], 200, 340, fill=OCEAN_B, width=4)
    return img


def tex_hill():
    img = new_canvas()
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, SIZE, SIZE], fill=HILL_A)
    d.polygon([(12, 78), (48, 18), (88, 78), (70, 78), (48, 42), (30, 78)], fill=HILL_B)
    d.line([(12, 78), (48, 18), (88, 78)], fill=INK, width=4)
    d.line([(48, 42), (48, 18)], fill=INK, width=2)
    return img


def tex_path():
    img = new_canvas()
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, SIZE, SIZE], fill=PATH_A)
    d.ellipse([24, 30, 34, 38], fill=STONE)
    d.ellipse([58, 52, 70, 60], fill=STONE)
    d.ellipse([40, 68, 50, 75], fill=STONE)
    return img


def tex_building():
    img = new_canvas()
    d = ImageDraw.Draw(img)
    # hut: walls
    d.rectangle([22, 44, 74, 84], fill=BUILD_A)
    d.line([(22, 44), (74, 44)], fill=INK, width=4)
    d.rectangle([22, 44, 74, 84], outline=INK, width=4)
    # roof
    d.polygon([(14, 46), (48, 14), (82, 46)], fill=ROOF_A)
    d.line([(14, 46), (48, 14)], fill=INK, width=5)
    d.line([(48, 14), (82, 46)], fill=INK, width=5)
    d.line([(14, 46), (82, 46)], fill=INK, width=4)
    # roof ridge line (thin)
    d.line([(48, 20), (30, 42)], fill=ROOF_B, width=2)
    d.line([(48, 20), (66, 42)], fill=ROOF_B, width=2)
    # door
    d.rectangle([40, 58, 58, 84], fill=INK)
    return img


def tex_dark():
    img = new_canvas()
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, SIZE, SIZE], fill=DARK_A)
    # faint grass silhouette under the gloom
    d.line([24, 70, 28, 56], fill=DARK_B, width=3)
    d.line([66, 64, 62, 50], fill=DARK_B, width=3)
    # small void motes
    d.ellipse([34, 30, 39, 35], fill=DARK_B)
    d.ellipse([60, 44, 66, 48], fill=DARK_B)
    d.ellipse([48, 56, 52, 59], fill=DARK_B)
    return img


# ================================================================ props

def prop_tree():
    img = new_canvas()
    d = ImageDraw.Draw(img)
    # trunk (thick ink outline, bark fill)
    d.polygon([(42, 88), (48, 54), (56, 54), (54, 88)], fill=BARK, outline=INK, width=4)
    # canopy: three overlapping leaf blobs, thick silhouette + thin interior
    for cx, cy, r in [(48, 34, 26), (30, 44, 16), (66, 44, 16)]:
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=LEAF, outline=INK, width=5)
    # interior detail (thin)
    d.arc([34, 22, 62, 48], 20, 160, fill=INK, width=2)
    d.arc([22, 36, 44, 58], 300, 80, fill=INK, width=2)
    d.arc([52, 36, 74, 58], 200, 40, fill=INK, width=2)
    return img


def prop_ore():
    img = new_canvas()
    d = ImageDraw.Draw(img)
    # rock mound
    d.polygon([(20, 80), (34, 56), (52, 62), (60, 50), (78, 80)], fill=STONE, outline=INK, width=4)
    # crystals
    for pts, fill in [
        ([(38, 58), (46, 34), (54, 56)], ORE),
        ([(52, 54), (62, 30), (70, 52)], ORE),
        ([(30, 60), (36, 44), (42, 58)], (178, 158, 214, 255)),
    ]:
        d.polygon(pts, fill=fill, outline=INK, width=3)
    # glints (thin)
    d.line([(46, 38), (48, 50)], fill=PAPER, width=2)
    d.line([(60, 36), (62, 48)], fill=PAPER, width=2)
    return img


def prop_chest():
    img = new_canvas()
    d = ImageDraw.Draw(img)
    # body
    d.rounded_rectangle([26, 48, 70, 82], radius=6, fill=CHEST_A, outline=INK, width=5)
    # lid
    d.rounded_rectangle([24, 34, 72, 54], radius=10, fill=CHEST_B, outline=INK, width=5)
    # band + lock
    d.rectangle([26, 58, 70, 66], fill=GOLD)
    d.line([(26, 58), (70, 58)], fill=INK, width=3)
    d.line([(26, 66), (70, 66)], fill=INK, width=3)
    d.rectangle([44, 56, 52, 68], fill=GOLD, outline=INK, width=3)
    # planks (thin)
    d.line([(34, 70), (62, 70)], fill=INK, width=2)
    d.line([(34, 76), (62, 76)], fill=INK, width=2)
    return img


def prop_crystal():
    img = new_canvas()
    d = ImageDraw.Draw(img)
    # shadow ring
    d.ellipse([30, 78, 66, 90], fill=(40, 36, 52, 160))
    # main shard
    d.polygon([(48, 10), (64, 44), (58, 84), (38, 84), (32, 44)], fill=CRYST, outline=INK, width=5)
    # facet lines (thin)
    d.line([(48, 10), (48, 84)], fill=CRYST_D, width=2)
    d.line([(48, 10), (32, 44)], fill=CRYST_D, width=2)
    d.line([(48, 10), (64, 44)], fill=CRYST_D, width=2)
    # side shards
    d.polygon([(24, 52), (32, 38), (36, 62)], fill=CRYST_D, outline=INK, width=3)
    d.polygon([(62, 40), (72, 50), (64, 66)], fill=CRYST_D, outline=INK, width=3)
    # glint
    d.line([(42, 26), (40, 40)], fill=PAPER, width=2)
    return img


# ================================================================ creatures

def face_eyes(d, x1, y1, x2, y2, r=4, fill=INK):
    d.ellipse([x1 - r, y1 - r, x1 + r, y1 + r], fill=fill)
    d.ellipse([x2 - r, y2 - r, x2 + r, y2 + r], fill=fill)


def sprite_player():
    """Cute chubby anime boy, short hair, basic cloth tunic."""
    img = new_canvas()
    d = ImageDraw.Draw(img)
    # chubby body (tunic)
    d.rounded_rectangle([30, 44, 66, 84], radius=14, fill=CLOTH, outline=INK, width=5)
    # tunic hem fold (thin)
    d.arc([32, 66, 64, 84], 20, 160, fill=INK, width=2)
    # little feet
    d.rounded_rectangle([36, 80, 46, 90], radius=4, fill=INK)
    d.rounded_rectangle([50, 80, 60, 90], radius=4, fill=INK)
    # head (chubby round)
    d.ellipse([28, 12, 68, 50], fill=SKIN, outline=INK, width=5)
    # short hair cap
    d.pieslice([26, 8, 70, 44], 150, 390, fill=HAIR, outline=INK, width=4)
    d.line([(30, 34), (38, 26)], fill=INK, width=2)
    d.line([(34, 38), (44, 30)], fill=INK, width=2)
    d.line([(40, 40), (50, 32)], fill=INK, width=2)
    # eyes (big, anime)
    face_eyes(d, 41, 38, 57, 38, r=4)
    d.ellipse([42, 36, 45, 39], fill=PAPER)
    d.ellipse([58, 36, 61, 39], fill=PAPER)
    # blush + smile
    d.ellipse([32, 42, 38, 45], fill=(236, 150, 140, 140))
    d.ellipse([58, 42, 64, 45], fill=(236, 150, 140, 140))
    d.arc([44, 40, 54, 48], 20, 160, fill=INK, width=2)
    return img


def sprite_zombie():
    img = new_canvas()
    d = ImageDraw.Draw(img)
    # hunched body
    d.rounded_rectangle([32, 42, 66, 84], radius=12, fill=ZOMB, outline=INK, width=5)
    # tatters (thin)
    d.line([(36, 60), (48, 64)], fill=INK, width=2)
    d.line([(44, 70), (58, 74)], fill=INK, width=2)
    # feet
    d.rounded_rectangle([38, 80, 48, 90], radius=4, fill=INK)
    d.rounded_rectangle([52, 80, 62, 90], radius=4, fill=INK)
    # head, slightly tilted
    d.ellipse([30, 14, 68, 48], fill=ZOMB, outline=INK, width=5)
    # patchy skin (thin)
    d.ellipse([38, 24, 46, 30], fill=ZOMB_D)
    d.ellipse([54, 30, 62, 36], fill=ZOMB_D)
    # hollow eyes + stitched mouth
    face_eyes(d, 43, 30, 57, 30, r=4, fill=(30, 34, 26, 255))
    d.arc([44, 36, 54, 44], 10, 170, fill=INK, width=2)
    d.line([(47, 38), (47, 42)], fill=INK, width=2)
    d.line([(51, 37), (51, 43)], fill=INK, width=2)
    return img


def sprite_wolf():
    img = new_canvas()
    d = ImageDraw.Draw(img)
    # low quadruped body, facing left
    d.rounded_rectangle([16, 44, 78, 74], radius=16, fill=WOLF, outline=INK, width=5)
    # legs
    for x in (22, 38, 56, 70):
        d.rectangle([x, 70, x + 8, 88], fill=WOLF, outline=INK, width=3)
    # tail
    d.polygon([(76, 52), (92, 40), (84, 62)], fill=WOLF, outline=INK, width=4)
    # head
    d.ellipse([8, 34, 40, 64], fill=WOLF, outline=INK, width=5)
    # snout
    d.polygon([(8, 48), (-2, 52), (8, 58)], fill=WOLF_D, outline=INK, width=3)
    # ear
    d.polygon([(24, 36), (20, 18), (34, 34)], fill=WOLF, outline=INK, width=4)
    d.polygon([(34, 36), (36, 22), (44, 38)], fill=WOLF_D, outline=INK, width=3)
    # eye + back stripes (thin)
    d.ellipse([18, 44, 24, 50], fill=INK)
    d.line([(48, 50), (46, 64)], fill=WOLF_D, width=3)
    d.line([(60, 50), (58, 64)], fill=WOLF_D, width=3)
    return img


def sprite_villager():
    img = new_canvas()
    d = ImageDraw.Draw(img)
    # hooded cloak body
    d.polygon([(48, 14), (26, 84), (70, 84)], fill=VIL_A, outline=INK, width=5)
    # hood
    d.ellipse([32, 10, 64, 44], fill=VIL_B, outline=INK, width=5)
    # face
    d.ellipse([38, 24, 58, 42], fill=SKIN)
    face_eyes(d, 44, 32, 52, 32, r=3)
    d.arc([44, 34, 52, 40], 20, 160, fill=INK, width=2)
    # cloak fold (thin)
    d.line([(48, 44), (44, 80)], fill=INK, width=2)
    d.line([(48, 44), (54, 80)], fill=INK, width=2)
    # satchel
    d.rounded_rectangle([54, 56, 70, 74], radius=5, fill=CHEST_A, outline=INK, width=3)
    return img


# ================================================================ icons

def _icon_base(fill):
    img = new_canvas()
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([18, 18, 78, 78], radius=10, fill=fill, outline=INK, width=4)
    return img, d


def icon_wood():
    img, d = _icon_base(GRASS_B)
    for y in (38, 54):
        d.rounded_rectangle([28, y, 68, y + 10], radius=5, fill=BARK, outline=INK, width=3)
        d.ellipse([62, y, 70, y + 10], fill=STONE, outline=INK, width=2)
    return img


def icon_ore():
    img, d = _icon_base(STONE)
    d.polygon([(48, 28), (64, 52), (58, 68), (38, 68), (32, 52)], fill=ORE, outline=INK, width=4)
    d.line([(48, 28), (48, 68)], fill=INK, width=2)
    d.line([(48, 28), (32, 52)], fill=INK, width=2)
    d.line([(48, 28), (64, 52)], fill=INK, width=2)
    return img


def icon_stone():
    img, d = _icon_base(STONE)
    d.polygon([(30, 62), (40, 36), (56, 30), (68, 48), (60, 66), (38, 68)], fill=(168, 166, 158, 255), outline=INK, width=4)
    d.line([(40, 36), (48, 52)], fill=INK, width=2)
    d.line([(48, 52), (60, 44)], fill=INK, width=2)
    return img


def icon_crystal():
    img, d = _icon_base((210, 200, 230, 255))
    d.polygon([(48, 22), (62, 46), (56, 70), (40, 70), (34, 46)], fill=CRYST, outline=INK, width=4)
    d.line([(48, 22), (48, 70)], fill=CRYST_D, width=2)
    d.line([(48, 22), (34, 46)], fill=CRYST_D, width=2)
    d.line([(48, 22), (62, 46)], fill=CRYST_D, width=2)
    return img


def _weapon_icon(shape):
    img, d = _icon_base(GRASS_A)
    hilt = [(40, 66), (56, 50)]
    if shape == "sword":
        d.polygon([(56, 50), (70, 24), (64, 20), (48, 44)], fill=STONE, outline=INK, width=3)
        d.line(hilt, fill=INK, width=6)
        d.line([(44, 48), (56, 60)], fill=BARK, width=6)
    elif shape == "spear":
        d.line([(40, 70), (64, 34)], fill=BARK, width=6)
        d.polygon([(64, 34), (74, 20), (60, 24)], fill=STONE, outline=INK, width=3)
    elif shape == "axe":
        d.line([(42, 70), (58, 34)], fill=BARK, width=6)
        d.polygon([(58, 24), (74, 30), (66, 46), (54, 40)], fill=STONE, outline=INK, width=3)
    elif shape == "hammer":
        d.line([(42, 70), (56, 42)], fill=BARK, width=6)
        d.rounded_rectangle([46, 24, 70, 46], radius=6, fill=STONE, outline=INK, width=3)
    elif shape == "ultimate_sword":
        d.polygon([(56, 50), (72, 22), (64, 16), (46, 42)], fill=CRYST, outline=INK, width=3)
        d.line(hilt, fill=INK, width=6)
        d.line([(42, 46), (56, 60)], fill=GOLD, width=6)
        d.line([(52, 40), (64, 26)], fill=PAPER, width=2)
    return img


def icon_armor(ultimate=False):
    img, d = _icon_base(STONE)
    col = CRYST if ultimate else ORE
    d.polygon([(48, 22), (68, 34), (64, 66), (48, 74), (32, 66), (28, 34)], fill=col, outline=INK, width=4)
    d.line([(48, 22), (48, 74)], fill=INK, width=2)
    d.line([(28, 34), (68, 34)], fill=INK, width=2)
    if ultimate:
        d.line([(40, 44), (56, 44)], fill=PAPER, width=2)
        d.line([(40, 52), (56, 52)], fill=PAPER, width=2)
    return img


def icon_heart():
    img, d = _icon_base(PAPER)
    d.polygon(
        [(48, 66), (30, 50), (30, 34), (40, 28), (48, 36), (56, 28), (66, 34), (66, 50)],
        fill=(214, 96, 96, 255), outline=INK, width=4)
    return img


def icon_quest():
    img, d = _icon_base(GOLD)
    d.rounded_rectangle([32, 24, 64, 72], radius=4, fill=PAPER, outline=INK, width=4)
    for y in (38, 50, 62):
        d.line([(38, y), (58, y)], fill=INK, width=2)
    d.line([(36, 30), (48, 30)], fill=INK, width=3)
    return img


# ================================================================ hex grid overlay

def tex_hex_grid():
    """Transparent hex outline texture (tiled) for the geometric grid look."""
    img = new_canvas()
    d = ImageDraw.Draw(img)
    s = 24  # hex radius in this tile
    for cx, cy in [(s, s * 1.5), (s * 3, s * 1.5), (0, s * 3), (s * 2, s * 3), (s * 4, s * 3)]:
        d.polygon(hex_points(cx, cy, s), outline=INK, width=2)
    return img


# ================================================================ main

def main():
    # terrain tiles
    save(tex_grass(), "tex_grass")
    save(tex_ocean(), "tex_ocean")
    save(tex_hill(), "tex_hill")
    save(tex_path(), "tex_path")
    save(tex_building(), "tex_building")
    save(tex_dark(), "tex_dark")
    save(tex_hex_grid(), "tex_hexgrid")
    # props
    save(prop_tree(), "prop_tree")
    save(prop_ore(), "prop_ore")
    save(prop_chest(), "prop_chest")
    save(prop_crystal(), "prop_crystal")
    # creatures
    save(sprite_player(), "spr_player")
    save(sprite_zombie(), "spr_zombie")
    save(sprite_wolf(), "spr_wolf")
    save(sprite_villager(), "spr_villager")
    # icons
    save(icon_wood(), "icn_wood")
    save(icon_ore(), "icn_ore")
    save(icon_stone(), "icn_stone")
    save(icon_crystal(), "icn_crystal")
    save(icon_armor(), "icn_armor_leather")
    save(icon_armor(True), "icn_armor_ultimate")
    save(_weapon_icon("sword"), "icn_sword")
    save(_weapon_icon("spear"), "icn_spear")
    save(_weapon_icon("axe"), "icn_axe")
    save(_weapon_icon("hammer"), "icn_hammer")
    save(_weapon_icon("ultimate_sword"), "icn_ultimate_sword")
    save(icon_heart(), "icn_heart")
    save(icon_quest(), "icn_quest")
    # steel armor = leather icon recolored-ish (reuse stone body via armor var)
    save(icon_armor(False), "icn_armor_steel")
    print("DONE")


if __name__ == "__main__":
    main()
