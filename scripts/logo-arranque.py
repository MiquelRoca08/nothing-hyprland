#!/usr/bin/env python3
# Generates the «NOTHING OS LINUX» boot logo (dots, «OS» in red) with the grid of Nothing's
# logo: 5×5-dot letters, one column between letters and three between words. The dots touch
# horizontally and are further apart vertically. Needs Pillow (python-pillow).
#   python3 scripts/logo-arranque.py
# Writes (already in the repo; only needed if the logo changes):
#   system/usr/local/share/nothing/splash.bmp          UKI splash (systemd-stub, actual size)
#   system/usr/share/plymouth/themes/nothing/logo.png  the same, for Plymouth (same place on screen)
# Limine's background (system/boot/EFI/BOOT/limine-nothing.png) has no logo or machine name since 29 Sep.
import os
from PIL import Image, ImageDraw

AQUI = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(AQUI)
BLANCO, ROJO = (255, 255, 255), (215, 25, 33)       # #d71921, the red of Theme.qml and Limine

G = {
    "N": ["#...#", "##..#", "#.#.#", "#..##", "#...#"],
    "O": [".###.", "#...#", "#...#", "#...#", ".###."],
    "T": ["#####", "..#..", "..#..", "..#..", "..#.."],
    "H": ["#...#", "#...#", "#####", "#...#", "#...#"],
    "I": [".###.", "..#..", "..#..", "..#..", ".###."],
    "G": [".####", "#....", "#.###", "#...#", ".###."],
    "S": [".####", "#....", ".###.", "....#", "####."],
    "L": ["#....", "#....", "#....", "#....", "#####"],
    "U": ["#...#", "#...#", "#...#", "#...#", ".###."],
    "X": ["#...#", ".#.#.", "..#..", ".#.#.", "#...#"],
}
TEXTO = [("NOTHING", BLANCO), ("OS", ROJO), ("LINUX", BLANCO)]
PASO_X, PASO_Y, DIAM = 24.15, 36.25, 24      # measurements of the original logo (1280×170)


def puntos():
    """(column, row, color) of every lit dot"""
    out, col = [], 0
    for w, (palabra, color) in enumerate(TEXTO):
        if w: col += 3
        for i, letra in enumerate(palabra):
            if i: col += 1
            for f, linea in enumerate(G[letra]):
                for c, ch in enumerate(linea):
                    if ch == "#": out.append((col + c, f, color))
            col += 5
    return out, col


def logo(escala, fondo=(0, 0, 0, 0)):
    """The logo image; drawn at 4× and scaled down to smooth the edges"""
    ss = 4
    pts, cols = puntos()
    d, px, py = DIAM * escala * ss, PASO_X * escala * ss, PASO_Y * escala * ss
    w, h = round((cols - 1) * px + d), round(4 * py + d)
    im = Image.new("RGBA", (w, h), fondo)
    dr = ImageDraw.Draw(im)
    for c, f, color in pts:
        x, y = c * px, f * py
        dr.ellipse((x, y, x + d, y + d), fill=color + (255,))
    return im.resize((round(w / ss), round(h / ss)), Image.LANCZOS)


def guardar(im, ruta, **kw):
    ruta = os.path.join(REPO, ruta)
    os.makedirs(os.path.dirname(ruta), exist_ok=True)
    im.save(ruta, **kw)
    print(ruta, im.size)


# Splash (UKI and Plymouth): at 2880×1800 it takes 45 % of the width, centered
ESCALA = 0.62
l = logo(ESCALA)
negro = Image.new("RGB", l.size, (0, 0, 0))
negro.paste(l, mask=l)
guardar(negro, "system/usr/local/share/nothing/splash.bmp")
guardar(l, "system/usr/share/plymouth/themes/nothing/logo.png")

