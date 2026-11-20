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


# ------------------------------------------------------------------ v2: Chromium + filtros (tinta e traço de mão)
import json
import subprocess

OUTLINE = "#1c1418"      # contorno de personagem (quase preto, como na ref1)
BROWN = "#3a2026"        # contorno de cenário (marrom-escuro quente, como os blocos da ref1)
_JOBS = []


def filters(seed=1, wobble=1.2, grain=0.10, blotch=0.10):
    """'wob': traço tremido; 'paint': manchas de tinta + grão dentro da forma."""
    return (
        f'<filter id="wob" x="-10%" y="-10%" width="120%" height="120%">'
        f'<feTurbulence type="fractalNoise" baseFrequency="0.045" numOctaves="2" seed="{seed}"/>'
        f'<feDisplacementMap in="SourceGraphic" scale="{wobble * 2}" xChannelSelector="R" yChannelSelector="G"/></filter>'
        f'<filter id="paint" x="0" y="0" width="100%" height="100%">'
        f'<feTurbulence type="fractalNoise" baseFrequency="0.035" numOctaves="3" seed="{seed + 7}" result="b"/>'
        f'<feColorMatrix in="b" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  {blotch * 4} 0 0 0 {-blotch * 1.6}" result="ba"/>'
        f'<feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="1" seed="{seed + 3}" result="g"/>'
        f'<feColorMatrix in="g" type="matrix" values="0 0 0 0 1  0 0 0 0 1  0 0 0 0 1  {grain * 3} 0 0 0 {-grain * 1.2}" result="ga"/>'
        f'<feMerge result="m"><feMergeNode in="ba"/><feMergeNode in="ga"/></feMerge>'
        f'<feComposite in="m" in2="SourceAlpha" operator="in" result="mi"/>'
        f'<feMerge><feMergeNode in="SourceGraphic"/><feMergeNode in="mi"/></feMerge></filter>')


def queue(svg, src_path, png_path, w, h, scale):
    os.makedirs(os.path.dirname(src_path), exist_ok=True)
    os.makedirs(os.path.dirname(png_path), exist_ok=True)
    with open(src_path, "w") as f:
        f.write(svg)
    _JOBS.append({"svg": src_path, "png": png_path, "w": w, "h": h, "scale": scale})


def render_all():
    root = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
    jobs = os.path.join(root, "art/out/.jobs.json")
    os.makedirs(os.path.dirname(jobs), exist_ok=True)
    with open(jobs, "w") as f:
        json.dump(_JOBS, f)
    subprocess.run(["node", os.path.join(root, "tools/render_svg.js"), jobs], check=True)
    n = len(_JOBS)
    _JOBS.clear()
    return n
