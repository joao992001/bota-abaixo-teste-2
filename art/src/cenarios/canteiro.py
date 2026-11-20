"""Kit do Canteiro v2 (estilo ref1): blocos em massa (autotile: bisel só nas faces expostas),
painel de caixote, contorno marrom fino com traço de mão, tinta; fundo pintado, plateia,
lama, espinho, elevador, poeira; peças P01–P04 por cor do dono (índice 4 = neutro).
Rodar: python3 art/src/cenarios/canteiro.py   (renderiza com o Chromium, tools/render_svg.js)
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from svg import BROWN, DANGER, PLAYER, doc, filters, poly, queue, render_all, shade, star_pts, symbol  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.."))
SRC_C = os.path.join(ROOT, "art/src/cenarios/svg")
SRC_P = os.path.join(ROOT, "art/src/pecas/svg")
SRC_E = os.path.join(ROOT, "art/src/efeitos/svg")
OUT_C = os.path.join(ROOT, "art/out/game/cenario")
OUT_P = os.path.join(ROOT, "art/out/game/pecas")
K = 3  # tiles e peças em 3x (a câmera aproxima até ~1,6x)

D = 11  # profundidade do bisel (px de jogo)
PAL = {
    "laranja": dict(front="#c47546", low="#b0653b", top="#dc9562", side="#d98a5c", line="#93502c", hi="#d99368"),
    "magenta": dict(front="#b8456e", low="#a43a61", top="#d0648a", side="#dc6c9c", line="#82294b", hi="#cc6189"),
    "dourado": dict(front="#c8963c", low="#b4842f", top="#e0b65a", side="#d9a94a", line="#8e621c", hi="#ddb062"),
}
STEEL = "#8e98a8"


# ------------------------------------------------------------------ blocos (autotile)
def block(pal_name, T, R, L, B, C, seed):
    p = PAL[pal_name]
    x1 = 64 - D if R else 64
    y0 = D if T else 0
    defs = filters(seed=seed, wobble=0.9, grain=0.03, blotch=0.12)
    defs += (f'<linearGradient id="fg" x1="0" y1="0" x2="0.25" y2="1"><stop offset="0" stop-color="{p["front"]}"/>'
             f'<stop offset="1" stop-color="{p["low"]}"/></linearGradient>')
    fill = []
    fill.append(f'<rect x="0" y="{y0}" width="{x1}" height="{64 - y0}" fill="url(#fg)"/>')
    if T:
        top = ([(0, D), (D, 0)] if L else [(0, D), (0, 0)]) + [(64, 0), (x1, D)]
        fill.append(poly(top, p["top"]))
        fill.append(f'<path d="M{D + 6 if L else 4},{D * 0.45:.1f} H{x1 - 8}" stroke="{shade(p["top"], 0.35)}" stroke-width="2" stroke-linecap="round" opacity="0.7"/>')
    if R:
        rtop = [(x1, D), (64, 0)] if T else [(x1, 0), (64, 0)]
        rbot = [(64, 64 - D), (x1, 64)] if C else [(64, 64), (x1, 64)]
        fill.append(poly(rtop + rbot, p["side"]))
    # painel de caixote na frente
    px0, py0, px1, py1 = 6, y0 + 6, x1 - 6, 58
    fill.append(f'<rect x="{px0 + 1.5}" y="{py0 + 1.5}" width="{px1 - px0}" height="{py1 - py0}" rx="5" fill="none" stroke="{p["hi"]}" stroke-width="1.6" opacity="0.8"/>')
    lines = [f'<rect x="{px0}" y="{py0}" width="{px1 - px0}" height="{py1 - py0}" rx="5" fill="none" stroke="{p["line"]}" stroke-width="2.2"/>']
    if pal_name == "dourado":  # emblema próprio (capacete de obra) em traço, como os emblemas da ref1
        cx, cy = (px0 + px1) / 2, (py0 + py1) / 2 + 2
        lines.append(f'<path d="M{cx - 13},{cy + 3} C{cx - 13},{cy - 10} {cx - 6},{cy - 14} {cx},{cy - 14} C{cx + 6},{cy - 14} {cx + 13},{cy - 10} {cx + 13},{cy + 3} '
                     f'M{cx - 18},{cy + 3} H{cx + 18} V{cy + 8} H{cx - 18} Z M{cx - 4},{cy - 14} V{cy + 2} M{cx + 4},{cy - 14} V{cy + 2}" '
                     f'fill="none" stroke="{p["line"]}" stroke-width="2.4" stroke-linejoin="round"/>')
    # costuras (finas) entre faces e entre cubos
    if T:
        lines.append(f'<path d="M0,{D} H{x1}" stroke="{BROWN}" stroke-width="1.8"/>')
        if not L:
            lines.append(f'<path d="M0,{D} L{D * 0.7},{D * 0.3}" stroke="{p["line"]}" stroke-width="1.6"/>')
    if R:
        lines.append(f'<path d="M{x1},{y0} V64" stroke="{BROWN}" stroke-width="1.8"/>')
    if not L:
        lines.append(f'<path d="M0.8,{y0} V64" stroke="{p["line"]}" stroke-width="1.6"/>')
    if not B:
        lines.append(f'<path d="M0,63.2 H{x1}" stroke="{p["line"]}" stroke-width="1.6"/>')
    # contorno grosso só nas bordas expostas da massa
    ow, h = 3.4, 1.7
    if T:
        lines.append(f'<path d="{"M%s,%s L%s,%s" % (h, D, D, h) if L else "M0,%s" % h} H64" stroke="{BROWN}" stroke-width="{ow}" fill="none" stroke-linejoin="round"/>')
    if R:
        lines.append(f'<path d="M{64 - h},{0 if T or True else 0} V{64 - D if C else 64}{" L%s,%s" % (x1, 64 - h) if C else ""}" stroke="{BROWN}" stroke-width="{ow}" fill="none" stroke-linejoin="round"/>')
    if L:
        lines.append(f'<path d="M{h},{D if T else 0} V64" stroke="{BROWN}" stroke-width="{ow}"/>')
    if B:
        lines.append(f'<path d="M0,{64 - h} H{x1}" stroke="{BROWN}" stroke-width="{ow}"/>')
    body = f'<g filter="url(#paint)">{"".join(fill)}</g><g filter="url(#wob)" stroke-linecap="round">{"".join(lines)}</g>'
    return doc(64, 64, body, defs)


def block_variants():
    n = 0
    for name in PAL:
        for bits in range(32):
            T, R, L, B, C = [(bits >> i) & 1 for i in range(5)]
            if C and not R:
                continue
            key = f"{T}{R}{L}{B}{C}"
            queue(block(name, T, R, L, B, C, seed=bits + 1), f"{SRC_C}/blocos/{name}_{key}.svg", f"{OUT_C}/blocos/{name}_{key}.png", 64, 64, K)
            n += 1
    return n


# ------------------------------------------------------------------ demais elementos do mapa
def oneway():
    return doc(64, 64, defs=filters(4), body=(
        f'<g filter="url(#paint)"><rect x="0" y="4" width="64" height="14" fill="#cf9659"/>'
        f'<rect x="0" y="4" width="64" height="4" fill="#e8b87e"/></g>'
        f'<g filter="url(#wob)"><path d="M0,4.5 H64 M0,17.5 H64" stroke="{BROWN}" stroke-width="3"/>'
        f'<path d="M18,8 Q24,11 20,15 M42,8 Q37,12 45,15" stroke="#9c6334" stroke-width="1.6" fill="none"/>'
        f'<circle cx="6" cy="11" r="1.8" fill="{BROWN}"/><circle cx="58" cy="11" r="1.8" fill="{BROWN}"/></g>'))


def spikes():
    b = []
    for i in range(3):
        x = 2 + i * 20
        tip = (x + 10, 16)
        b.append(poly([(x, 64), tip, (x + 20, 64)], "#5d5866", BROWN, 3))
        b.append(poly([(x + 10, 22), (x + 16, 62), (x + 18.5, 64), (x + 10.5, 64)], "#45404f"))
        b.append(poly([tip, (x + 7.2, 27), (x + 12.8, 27)], DANGER))
        b.append(f'<path d="M{x + 6},{58} L{x + 9},{34}" stroke="#8f889a" stroke-width="1.8" stroke-linecap="round"/>')
    return doc(64, 64, f'<g filter="url(#wob)">{"".join(b)}</g>', filters(5, wobble=0.7))


def mud():
    w = [(i, 24 + 3.5 * math.sin(i / 64 * 2 * math.pi * 2)) for i in range(0, 65, 4)]
    top = " ".join(f"L{x},{y:.1f}" for x, y in w)
    return doc(64, 64, (
        f'<g filter="url(#paint)"><path d="M0,64 {top} L64,64 Z" fill="#9a7fd2"/>'
        f'<path d="M0,64 {" ".join(f"L{x},{y + 8:.1f}" for x, y in w)} L64,64 Z" fill="#8a6fc4"/>'
        f'<path d="M0,64 {" ".join(f"L{x},{y + 26:.1f}" for x, y in w)} L64,64 Z" fill="#7a5fb3"/></g>'
        f'<path d="M0,{w[0][1] + 2:.1f} {" ".join(f"L{x},{y + 2:.1f}" for x, y in w)}" stroke="#c4b0f0" stroke-width="3.5" fill="none"/>'
        f'<g filter="url(#wob)"><path d="M0,{w[0][1]:.1f} {top}" stroke="{BROWN}" stroke-width="2" fill="none"/></g>'
        f'<circle cx="16" cy="44" r="1.6" fill="#ffffff" opacity="0.6"/><circle cx="44" cy="50" r="1.2" fill="#ffffff" opacity="0.6"/>'
        f'<circle cx="31" cy="38" r="1" fill="#ffffff" opacity="0.6"/>'), filters(6))


def elevator():
    b = ['<g filter="url(#paint)">',
         '<rect x="6" y="20" width="116" height="170" rx="7" fill="#e9ad35"/>',
         '<rect x="6" y="20" width="116" height="9" fill="#f7cf6c"/>',
         '<rect x="22" y="44" width="84" height="146" rx="3" fill="#3b3442"/>',
         '<rect x="26" y="48" width="37" height="142" fill="#5d6070"/>',
         '<rect x="65" y="48" width="37" height="142" fill="#51545f"/>',
         '<rect x="6" y="3" width="116" height="20" rx="5" fill="#ffd23f"/>', '</g>']
    for x in range(-8, 120, 16):
        b.append(poly([(10 + x, 21), (18 + x, 5), (26 + x, 5), (18 + x, 21)], "#2c2230", extra='clip-path="url(#sc)"'))
    b.append('<g filter="url(#wob)" fill="none">')
    for y in range(58, 186, 16):
        b.append(f'<path d="M26,{y} L63,{y + 12} M63,{y} L26,{y + 12} M65,{y} L102,{y + 12} M102,{y} L65,{y + 12}" stroke="#808697" stroke-width="2"/>')
    b.append(f'<rect x="6" y="20" width="116" height="170" rx="7" stroke="{BROWN}" stroke-width="3.4"/>')
    b.append(f'<rect x="6" y="3" width="116" height="20" rx="5" stroke="{BROWN}" stroke-width="3.4"/>')
    b.append(f'<rect x="22" y="44" width="84" height="146" rx="3" stroke="{BROWN}" stroke-width="2.4"/>')
    b.append(f'<circle cx="64" cy="35" r="8" fill="#ffffff" stroke="{BROWN}" stroke-width="2.6"/></g>')
    b.append(poly([(64, 30), (69.5, 38.5), (58.5, 38.5)], "#3aa7a3"))
    defs = filters(9) + '<clipPath id="sc"><rect x="9" y="5" width="110" height="16"/></clipPath>'
    return doc(128, 192, "".join(b), defs)


def gear(cx, cy, r, rot, fill, shadow):
    pts = star_pts(cx, cy, 9, r, r * 0.8, rot)
    pts_s = star_pts(cx + r * 0.06, cy + r * 0.08, 9, r, r * 0.8, rot)
    return (poly(pts_s, shadow) + poly(pts, fill) +
            f'<circle cx="{cx}" cy="{cy}" r="{r * 0.33:.1f}" fill="#2f9ea3"/>')


def background():
    rnd = random.Random(7)
    W, H = 1920, 1080
    defs = ('<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#3aabae"/>'
            '<stop offset="1" stop-color="#2a929a"/></linearGradient>'
            '<radialGradient id="vig" cx="0.5" cy="0.45" r="0.75"><stop offset="0.6" stop-color="#000" stop-opacity="0"/>'
            '<stop offset="1" stop-color="#0b2a33" stop-opacity="0.45"/></radialGradient>'
            '<filter id="soft"><feGaussianBlur stdDeviation="2.2"/></filter>'
            '<filter id="beam"><feGaussianBlur stdDeviation="14"/></filter>') + filters(11, blotch=0.14, grain=0.05)
    b = ['<g filter="url(#paint)"><rect width="1920" height="1080" fill="url(#sky)"/>']
    # fachos de luz de palco
    for x, w in [(380, 170), (980, 220), (1480, 160)]:
        b.append(f'<path d="M{x},0 L{x + w},0 L{x + w * 1.8},1080 L{x - w * 0.6},1080 Z" fill="#ffffff" opacity="0.06" filter="url(#beam)"/>')
    # massas distantes (teal escuro, bordas suaves)
    far = "#22828b"
    b.append(f'<g filter="url(#soft)" fill="{far}">'
             '<path d="M-20,1080 V700 C80,610 210,640 300,700 C360,560 470,500 560,560 C620,600 640,700 700,760 V1080 Z"/>'
             '<path d="M1180,1080 V560 C1240,470 1330,430 1420,470 C1500,380 1640,360 1720,450 C1800,520 1860,560 1940,560 V1080 Z"/>'
             '<rect x="760" y="300" width="150" height="800" rx="70"/><rect x="1530" y="160" width="120" height="900" rx="60"/>'
             '<rect x="120" y="380" width="110" height="700" rx="55"/></g>')
    # guindaste em silhueta clara
    crane = "#56bdb9"
    b.append(f'<g filter="url(#soft)" fill="{crane}" opacity="0.8"><rect x="1690" y="140" width="24" height="760"/>'
             '<rect x="1360" y="140" width="520" height="20"/><rect x="1430" y="160" width="4" height="150"/>'
             '<rect x="1414" y="306" width="36" height="24" rx="5"/></g>')
    b.append('</g>')  # fim da tinta: formas brancas ficam limpas, como na ref1
    # formas brancas grandes e suaves (nossas: engrenagens, porcas, capacete)
    b.append('<g filter="url(#soft)" opacity="0.92">')
    for cx, cy, r in [(250, 220, 105), (1060, 150, 72), (640, 560, 62), (1300, 640, 88)]:
        b.append(gear(cx, cy, r, rnd.random(), "#e9f0f0", "#b7c9cb"))
    for cx, cy, s in [(560, 200, 1.5), (1460, 380, 1.1), (110, 620, 1.0)]:
        b.append(f'<g transform="translate({cx},{cy}) scale({s}) rotate({rnd.randint(0, 40)})">'
                 '<polygon points="-38,4 -18,-30 22,-30 42,4 22,38 -18,38" fill="#b7c9cb"/>'
                 '<polygon points="-40,0 -20,-34 20,-34 40,0 20,34 -20,34" fill="#e9f0f0"/><circle r="14" fill="#2f9ea3"/></g>')
    for cx, cy, s in [(860, 360, 1.5), (1780, 300, 1.0)]:
        b.append(f'<g transform="translate({cx},{cy}) scale({s})"><path d="M-46,14 C-46,-26 -24,-38 0,-38 C24,-38 46,-26 46,14 Z" fill="#b7c9cb"/>'
                 '<path d="M-48,8 C-48,-30 -26,-42 -2,-42 C22,-42 44,-30 44,8 Z" fill="#e9f0f0"/>'
                 '<rect x="-62" y="6" width="120" height="16" rx="8" fill="#e9f0f0"/></g>')
    b.append('</g>')
    for _ in range(30):
        x, y, r = rnd.randint(0, W), rnd.randint(60, 820), rnd.choice([4, 6, 8])
        b.append(poly(star_pts(x, y, 4, r, r * 0.33), "#ffffff", extra='opacity="0.5"'))
    for _ in range(14):
        x, y, r = rnd.randint(0, W), rnd.randint(60, 820), rnd.choice([3, 4])
        b.append(f'<rect x="{x}" y="{y}" width="{r}" height="{r}" fill="#ffffff" opacity="0.45"/>')
    b.append('<rect width="1920" height="1080" fill="url(#vig)"/>')
    return doc(W, H, "".join(b), defs)


def audience():
    rnd = random.Random(3)
    b = []
    x = -20
    while x < 1940:
        w, h = rnd.randint(50, 70), rnd.randint(78, 118)
        cx, top = x + w / 2, 160 - h
        col = rnd.choice(["#150b13", "#1b0f19", "#120810"])
        b.append(f'<g fill="{col}"><rect x="{x}" y="{top + 32}" width="{w}" height="{h}" rx="{w / 2.3:.0f}"/>'
                 f'<circle cx="{cx}" cy="{top + 24}" r="{w * 0.33:.0f}"/>')
        r = rnd.random()
        if r < 0.6:
            b.append(f'<path d="M{cx - w * 0.37},{top + 17} C{cx - w * 0.37},{top - 5} {cx + w * 0.37},{top - 5} {cx + w * 0.37},{top + 17} Z"/>'
                     f'<rect x="{cx - w * 0.5}" y="{top + 13}" width="{w}" height="7" rx="3"/>')
        elif r < 0.8:
            s = rnd.choice([-1, 1])
            b.append(f'<path d="M{cx + s * w * 0.3},{top + 52} L{cx + s * w * 0.62},{top - 6}" stroke="{col}" stroke-width="14" stroke-linecap="round"/>')
        b.append('</g>')
        b.append(f'<path d="M{cx - w * 0.3},{top + 8} Q{cx},{top - 2} {cx + w * 0.3},{top + 8}" stroke="#4a2433" stroke-width="2.5" fill="none" opacity="0.7"/>')
        x += w - rnd.randint(6, 16)
    return doc(1920, 160, "".join(b))


def dust():
    return doc(64, 64, (
        '<g filter="url(#paint)"><circle cx="24" cy="38" r="15" fill="#9a7352"/><circle cx="40" cy="34" r="17" fill="#9a7352"/>'
        '<circle cx="32" cy="25" r="13" fill="#a98262"/><circle cx="28" cy="31" r="10" fill="#b79272"/>'
        '<circle cx="40" cy="28" r="9" fill="#b79272"/><circle cx="34" cy="21" r="4.5" fill="#cdae8e"/></g>'), filters(12, blotch=0.2))


def sparkle():
    return doc(32, 32, poly(star_pts(16, 16, 4, 14, 4), "#ffffff", BROWN, 1.6))


# ------------------------------------------------------------------ peças
def badge(ci, cx, cy, r):
    return (f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{PLAYER[ci]}" stroke="{BROWN}" stroke-width="3"/>'
            f'<circle cx="{cx - r * 0.3}" cy="{cy - r * 0.38}" r="{r * 0.22}" fill="#ffffff" opacity="0.7"/>'
            + symbol(ci, cx, cy + 0.5, r * 0.5, BROWN))


def piece_doc(w, h, fills, lines, seed):
    return doc(w, h, f'<g filter="url(#paint)">{fills}</g><g filter="url(#wob)" fill="none" stroke-linejoin="round" stroke-linecap="round">{lines}</g>',
               filters(seed, wobble=0.8))


def viga(ci):
    col = PLAYER[ci]
    f = (f'<rect x="4" y="10" width="184" height="46" rx="7" fill="{STEEL}"/>'
         f'<rect x="4" y="40" width="184" height="16" rx="5" fill="{shade(STEEL, -0.22)}"/>'
         f'<rect x="4" y="10" width="184" height="16" rx="5" fill="{col}"/>'
         f'<rect x="4" y="22" width="184" height="5" fill="{shade(col, -0.25)}"/>')
    for x in (36, 84, 132):
        f += f'<ellipse cx="{x}" cy="38" rx="11" ry="5" fill="{shade(STEEL, -0.45)}"/>'
    lines = (f'<rect x="4" y="10" width="184" height="46" rx="7" stroke="{BROWN}" stroke-width="3.4"/>'
             f'<path d="M5,27 H187" stroke="{BROWN}" stroke-width="2"/><path d="M12,15 H70" stroke="#ffffff" stroke-width="2.6" opacity="0.8"/>'
             f'<circle cx="15" cy="47" r="2.2" fill="{BROWN}"/><circle cx="177" cy="47" r="2.2" fill="{BROWN}"/>')
    return piece_doc(192, 64, f, lines + badge(ci, 160, 38, 9), 20 + ci)


def mola(ci, compressed):
    col = PLAYER[ci]
    top = 26 if compressed else 4
    f = f'<rect x="6" y="48" width="52" height="13" rx="4" fill="{STEEL}"/><rect x="2" y="{top}" width="60" height="17" rx="6" fill="{col}"/>'
    lines = ""
    n, y0, y1 = 4, top + 16, 50
    for i in range(n):
        ya, yb, yc = (y0 + (y1 - y0) * k / n for k in (i, i + 0.5, i + 1))
        lines += (f'<path d="M14,{ya:.1f} L50,{yb:.1f} L14,{yc:.1f}" stroke="{BROWN}" stroke-width="7"/>'
                  f'<path d="M14,{ya:.1f} L50,{yb:.1f} L14,{yc:.1f}" stroke="#cdd2da" stroke-width="3"/>')
    lines += (f'<rect x="6" y="48" width="52" height="13" rx="4" stroke="{BROWN}" stroke-width="3"/>'
              f'<rect x="2" y="{top}" width="60" height="17" rx="6" stroke="{BROWN}" stroke-width="3.2"/>'
              f'<path d="M9,{top + 5} H28" stroke="#ffffff" stroke-width="2.4" opacity="0.8"/>')
    return piece_doc(64, 64, f, lines + symbol(ci, 47, top + 8.5, 4, BROWN), 30 + ci)


def serra_blade(rival):
    f, lines = "", ""
    if rival:
        f += poly(star_pts(32, 32, 12, 30, 21), "#5d5866")
        for i in range(12):
            a = math.pi * 2 * i / 12
            f += poly([(32 + math.cos(a) * 30, 32 + math.sin(a) * 30), (32 + math.cos(a - 0.13) * 24.5, 32 + math.sin(a - 0.13) * 24.5),
                       (32 + math.cos(a + 0.13) * 24.5, 32 + math.sin(a + 0.13) * 24.5)], DANGER)
        lines += poly(star_pts(32, 32, 12, 30, 21), "none", BROWN, 2.6)
    f += '<circle cx="32" cy="32" r="18" fill="#c4cad3"/>'
    lines += f'<circle cx="32" cy="32" r="18" stroke="{BROWN}" stroke-width="3"/>'
    for i in range(3):
        a = math.pi * 2 * i / 3
        lines += f'<path d="M{32 + math.cos(a) * 9:.1f},{32 + math.sin(a) * 9:.1f} L{32 + math.cos(a) * 14:.1f},{32 + math.sin(a) * 14:.1f}" stroke="#8d97a6" stroke-width="3.4"/>'
    lines += '<path d="M21,25 A13,13 0 0 1 30,19" stroke="#ffffff" stroke-width="2.6"/>'
    return piece_doc(64, 64, f, lines, 40 + rival)


def serra_hub(ci):
    return doc(64, 64, badge(ci, 32, 32, 9))


def esteira(ci):
    col = PLAYER[ci]
    f = (f'<rect x="4" y="12" width="184" height="46" rx="23" fill="#474c59"/>'
         f'<rect x="20" y="12" width="152" height="10" fill="{col}"/>')
    lines = (f'<rect x="4" y="12" width="184" height="46" rx="23" stroke="{BROWN}" stroke-width="3.4"/>'
             f'<path d="M20,22.5 H172" stroke="{BROWN}" stroke-width="2"/><path d="M26,16 H80" stroke="#ffffff" stroke-width="2.2" opacity="0.75"/>')
    for x in (28, 74, 118, 164):
        lines += f'<circle cx="{x}" cy="42" r="8" fill="#b9c0ca" stroke="{BROWN}" stroke-width="2.6"/><circle cx="{x}" cy="42" r="2" fill="{BROWN}"/>'
    return piece_doc(192, 64, f, lines + badge(ci, 96, 10, 8.5), 50 + ci)


def seta():
    return doc(32, 32, f'<path d="M10,6 L22,16 L10,26" stroke="{BROWN}" stroke-width="8" fill="none" stroke-linecap="round" stroke-linejoin="round"/>'
                       f'<path d="M10,6 L22,16 L10,26" stroke="#ffffff" stroke-width="3.6" fill="none" stroke-linecap="round" stroke-linejoin="round"/>')


def main():
    n = block_variants()
    for name, svg, w, h in [("oneway", oneway(), 64, 64), ("espinho", spikes(), 64, 64), ("lama", mud(), 64, 64), ("elevador", elevator(), 128, 192)]:
        queue(svg, f"{SRC_C}/{name}.svg", f"{OUT_C}/{name}.png", w, h, K)
    queue(background(), f"{SRC_C}/fundo_canteiro.svg", f"{OUT_C}/fundo_canteiro.png", 1920, 1080, 2)
    queue(audience(), f"{SRC_C}/plateia.svg", f"{OUT_C}/plateia.png", 1920, 160, 2)
    queue(dust(), f"{SRC_E}/poeira.svg", f"{OUT_C}/poeira.png", 64, 64, K)
    queue(sparkle(), f"{SRC_E}/brilho.svg", f"{OUT_C}/brilho.png", 32, 32, K)
    for ci in range(5):
        c = f"c{ci}"
        queue(viga(ci), f"{SRC_P}/viga_{c}.svg", f"{OUT_P}/viga_{c}.png", 192, 64, K)
        queue(mola(ci, False), f"{SRC_P}/mola_{c}.svg", f"{OUT_P}/mola_{c}.png", 64, 64, K)
        queue(mola(ci, True), f"{SRC_P}/mola_comprimida_{c}.svg", f"{OUT_P}/mola_comprimida_{c}.png", 64, 64, K)
        queue(serra_hub(ci), f"{SRC_P}/serra_cubo_{c}.svg", f"{OUT_P}/serra_cubo_{c}.png", 64, 64, K)
        queue(esteira(ci), f"{SRC_P}/esteira_{c}.svg", f"{OUT_P}/esteira_{c}.png", 192, 64, K)
    queue(serra_blade(1), f"{SRC_P}/serra_rival.svg", f"{OUT_P}/serra_rival.png", 64, 64, K)
    queue(serra_blade(0), f"{SRC_P}/serra_dono.svg", f"{OUT_P}/serra_dono.png", 64, 64, K)
    queue(seta(), f"{SRC_P}/esteira_seta.svg", f"{OUT_P}/esteira_seta.png", 32, 32, K)
    print("renderizados:", render_all(), "arquivos (", n, "blocos )")


if __name__ == "__main__":
    main()
