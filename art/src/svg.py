"""Utilidades mínimas para escrever SVG e rasterizar (cairosvg)."""
import math
import os

import cairosvg

INK = "#2a1a2e"
PLAYER = ["#2f8ff0", "#5fd35f", "#ff6fb5", "#ffd23f", "#dfe3ea"]  # índice 4 = neutro (peça ainda sem dono)
DANGER = "#d42035"


def shade(hexcol, k):
    """k<0 escurece, k>0 clareia (mistura com preto-arroxeado / branco)."""
    h = hexcol.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) for i in (0, 2, 4))
    if k < 0:
        t = -k
        tr, tg, tb = 42, 26, 60  # escurece puxando para roxo, como nas sombras da ref1
        r, g, b = r + (tr - r) * t, g + (tg - g) * t, b + (tb - b) * t
    else:
        r, g, b = r + (255 - r) * k, g + (255 - g) * k, b + (255 - b) * k
    return "#%02x%02x%02x" % (round(r), round(g), round(b))


def doc(w, h, body, defs=""):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">'
            f'<defs>{defs}</defs>{body}</svg>')


def save(svg, src_path, png_path, scale=1.0):
    os.makedirs(os.path.dirname(src_path), exist_ok=True)
    os.makedirs(os.path.dirname(png_path), exist_ok=True)
    with open(src_path, "w") as f:
        f.write(svg)
    cairosvg.svg2png(bytestring=svg.encode(), write_to=png_path, scale=scale)


def symbol(idx, cx, cy, r, fill=INK, stroke=None, sw=0):
    st = f' stroke="{stroke}" stroke-width="{sw}" stroke-linejoin="round"' if stroke else ""
    if idx >= 4:
        return ""
    if idx == 0:
        return f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{fill}"{st}/>'
    if idx == 1:
        pts = [(cx, cy - r * 1.15), (cx + r * 1.05, cy + r * 0.8), (cx - r * 1.05, cy + r * 0.8)]
    elif idx == 2:
        pts = [(cx - r * 0.88, cy - r * 0.88), (cx + r * 0.88, cy - r * 0.88), (cx + r * 0.88, cy + r * 0.88), (cx - r * 0.88, cy + r * 0.88)]
    else:
        pts = [(cx, cy - r * 1.2), (cx + r * 1.0, cy), (cx, cy + r * 1.2), (cx - r * 1.0, cy)]
    return f'<polygon points="{" ".join(f"{x:.1f},{y:.1f}" for x, y in pts)}" fill="{fill}"{st}/>'


def poly(pts, fill, stroke=None, sw=0, extra=""):
    st = f' stroke="{stroke}" stroke-width="{sw}" stroke-linejoin="round"' if stroke else ""
    return f'<polygon points="{" ".join(f"{x:.1f},{y:.1f}" for x, y in pts)}" fill="{fill}"{st} {extra}/>'


def star_pts(cx, cy, n, r_out, r_in, rot=0.0):
    pts = []
    for i in range(n * 2):
        a = rot + math.pi * i / n
        r = r_out if i % 2 == 0 else r_in
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return pts
