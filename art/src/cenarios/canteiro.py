"""Canteiro v3 — exatamente o estilo de cenario.png (referência do usuário): céu pastel, silhuetas claras
(engrenagens, chaminés, fábrica, morros, guindaste em linhas), nuvens chapadas, caixotes de madeira com X,
espinhos cinza, tábua pendurada, elevador; peças P01–P04 (viga com cobertura na cor do dono, mola de tábua,
serra-engrenagem com miolo na cor do dono, esteira com faixa do dono). Sem contorno, textura de giz.
Rodar: python3 art/src/cenarios/canteiro.py
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from papel import ellipse_d, hatch, rect_d, rough, shape  # noqa: E402
from svg import doc, poly, queue, render_all, shade, star_pts  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.."))
SRC_C = os.path.join(ROOT, "art/src/cenarios/svg")
SRC_P = os.path.join(ROOT, "art/src/pecas/svg")
SRC_E = os.path.join(ROOT, "art/src/efeitos/svg")
OUT_C = os.path.join(ROOT, "art/out/game/cenario")
OUT_P = os.path.join(ROOT, "art/out/game/pecas")
K = 3
OWNER = ["#4f86d9", "#5cc45c", "#f06aa8", "#f2c84b", "#d5dbe1"]  # índice 4 = sem dono
WOOD, WOOD_HI, WOOD_X, WOOD_DK = "#c8995f", "#dba462", "#a8713b", "#8a5a2a"
SLATE, STEEL_LT, STEEL, STEEL_DK = "#5a6370", "#aab4bc", "#8a96a2", "#6a7682"


def wrap(w, h, body, seed, scale=0.8):
    return doc(w, h, f'<g filter="url(#rough)">{body}</g>', rough(seed=seed, scale=scale, freq=0.08))


# ------------------------------------------------------------------ mapa
def crate(seed):
    rnd = random.Random(seed)
    b = [f'<rect x="0" y="0" width="64" height="64" fill="{WOOD_HI}"/>']
    b.append(hatch("all", (0, 0, 64, 64), WOOD_HI, seed, k=1.4, dens=0.7, dark=WOOD_DK))
    panel = rect_d(4.5, 4.5, 55, 55, 1)
    b.append(shape("p", panel, WOOD, seed + 1, (3, 3, 61, 61), k=1.4, dark=WOOD_DK))
    b.append('<g clip-path="url(#p)" stroke-linecap="butt">'
             f'<path d="M{8 + rnd.uniform(-1, 1)},{9} L{56},{56 + rnd.uniform(-1, 1)} M{56 + rnd.uniform(-1, 1)},{9} L{8},{56}" stroke="{WOOD_X}" stroke-width="7.5" opacity="0.85"/>'
             '</g>')
    for y in (21, 43):
        y += rnd.uniform(-1.5, 1.5)
        b.append(f'<path d="M4.5,{y:.1f} Q22,{y - 1:.1f} 36,{y + 0.6:.1f} T59.5,{y - 0.4:.1f}" stroke="#e8be86" stroke-width="1.2" fill="none" opacity="0.85"/>')
    defs = '<clipPath id="all"><rect width="64" height="64"/></clipPath>'
    return doc(64, 64, defs + "".join(b))


def spikes(seed):
    rnd = random.Random(seed)
    b = []
    x = -4
    while x < 64:
        w = rnd.uniform(30, 40)
        h = rnd.uniform(80, 124)
        tip = (x + w / 2 + rnd.uniform(-1.5, 1.5), 128 - h)
        b.append(poly([(x, 128), tip, (x + w, 128)], SLATE))
        b.append(poly([(x + w * 0.5, 128), tip, (x + w, 128)], "#4b535e"))
        x += w * rnd.uniform(0.85, 1.0)
    return wrap(64, 128, "".join(b), seed, 0.6)


def plank():
    return wrap(64, 16, (f'<rect x="-1" y="2" width="66" height="12" fill="#d9a35f"/><rect x="-1" y="10.5" width="66" height="3.5" fill="#b07a3d"/>'
                         '<path d="M3,6.5 H22 M30,5.5 H52 M10,9 H40" stroke="#e9bf86" stroke-width="1" stroke-linecap="round"/>'
                         + hatch("pk", (0, 2, 64, 14), "#d9a35f", 5, k=1.3, dark="#9c6a35")), 15, 0.6).replace("<defs>", '<defs><clipPath id="pk"><rect y="2" width="64" height="12"/></clipPath>')


def elevator():
    b = [shape("e", rect_d(10, 26, 108, 166, 2), "#e9b44c", 31, (8, 24, 120, 194), k=1.6),
         f'<rect x="22" y="44" width="84" height="148" fill="{SLATE}"/>',
         f'<rect x="25" y="47" width="38" height="145" fill="#7d8894"/><rect x="65" y="47" width="38" height="145" fill="#717c88"/>',
         '<rect x="10" y="8" width="108" height="18" fill="#f2c84b"/>']
    for x in range(-12, 120, 18):
        b.append(poly([(10 + x, 26), (19 + x, 8), (28 + x, 8), (19 + x, 26)], "#4b535e", extra='clip-path="url(#stripe)"'))
    for y in range(56, 188, 18):
        b.append(f'<path d="M25,{y} L63,{y + 14} M63,{y} L25,{y + 14} M65,{y} L103,{y + 14} M103,{y} L65,{y + 14}" stroke="#9aa4ae" stroke-width="2"/>')
    b.append('<circle cx="64" cy="35" r="6.5" fill="#ffffff"/>' + poly([(64, 31), (68.5, 38), (59.5, 38)], "#5cc45c"))
    return wrap(128, 192, '<defs><clipPath id="stripe"><rect x="10" y="8" width="108" height="18"/></clipPath></defs>' + "".join(b), 30)


def gear_d(cx, cy, r, n, rot, tooth=0.22):
    pts = []
    for i in range(n * 4):
        a = rot + 2 * math.pi * i / (n * 4)
        rr = r if (i % 4) in (1, 2) else r * (1 - tooth)
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    return "M" + " L".join(f"{x:.1f},{y:.1f}" for x, y in pts) + " Z"


def background():
    rnd = random.Random(4)
    defs = ('<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#8adde8"/>'
            '<stop offset="0.7" stop-color="#a7e6ea"/><stop offset="1" stop-color="#b3e6df"/></linearGradient>') + rough("rough", 3, 2.2, 0.03)
    b = ['<rect width="1920" height="1080" fill="url(#sky)"/>', '<g filter="url(#rough)">']
    # engrenagens claras
    for cx, cy, r, n in [(330, 180, 100, 8), (1000, 120, 50, 8), (1340, 300, 75, 8)]:
        b.append(f'<path d="{gear_d(cx, cy, r, n, rnd.random())}" fill="#a6e3e2"/>'
                 f'<circle cx="{cx}" cy="{cy}" r="{r * 0.18:.0f}" fill="#9ee0e2"/>')
    # morros ao fundo
    b.append('<path d="M0,1080 V760 C80,700 160,690 260,700 C380,712 420,680 520,640 C640,600 720,610 820,640 '
             'C960,680 1060,620 1180,600 C1300,590 1380,650 1500,640 C1620,630 1700,580 1800,600 C1860,612 1900,640 1920,650 V1080 Z" fill="#a8dcd5"/>')
    # chaminés / caixas d'água
    for x, top, w in [(120, 300, 130), (1560, 230, 150)]:
        b.append(f'<path d="M{x},{top} H{x + w} V{top + 40} H{x + w - 18} V1080 H{x + 18} V{top + 40} H{x} Z" fill="#98d4cf"/>')
    # fábrica com telhado serrilhado
    b.append('<path d="M760,720 V485 L880,540 V478 L1000,540 V478 L1120,540 V720 Z" fill="#9bd5cf"/>')
    # guindaste em linhas
    st = 'stroke="#84b9c4" stroke-width="4" fill="none" stroke-linecap="round"'
    b.append(f'<path d="M1760,760 V80 M1820,760 V80 M1700,80 H1920" {st}/>')
    zz = " ".join(f"L{1760 if i % 2 else 1820},{120 + i * 80}" for i in range(9))
    b.append(f'<path d="M1760,120 {zz}" {st}/>')
    b.append('</g>')
    # nuvens chapadas (base reta)
    for cx, cy, s in [(675, 210, 1.0), (1555, 150, 0.85), (260, 520, 0.6)]:
        b.append(f'<g transform="translate({cx},{cy}) scale({s})" fill="#e9f9fa">'
                 '<path d="M-116,0 Q-100,-26 -60,-24 Q-40,-58 0,-56 Q40,-58 60,-30 Q104,-34 114,0 Z"/></g>')
    return doc(1920, 1080, "".join(b), defs)


def dust():
    return wrap(64, 64, ('<circle cx="24" cy="38" r="14" fill="#d8c3a2"/><circle cx="40" cy="35" r="16" fill="#d8c3a2"/>'
                         '<circle cx="32" cy="26" r="12" fill="#e4d3b6"/><circle cx="38" cy="28" r="7" fill="#efe3cc"/>'), 40)


def sparkle():
    return doc(32, 32, poly(star_pts(16, 16, 4, 14, 4), "#ffffff"))


# ------------------------------------------------------------------ peças
def viga(ci):
    col = OWNER[ci]
    rnd = random.Random(ci)
    goo = "M4,12 " + " ".join(f"Q{x + 8},{9 + rnd.uniform(-1.5, 1.5):.1f} {x + 16},12" for x in range(4, 188, 16)) + " V24 " + \
          " ".join(f"Q{x - 8},{30 + rnd.uniform(-2, 4):.1f} {x - 16},24" for x in range(188, 4, -16)) + " Z"
    b = [shape("s", rect_d(4, 18, 184, 40, 2), STEEL, 50 + ci, (2, 16, 190, 60), k=1.4, dark=STEEL_DK),
         f'<rect x="4" y="44" width="184" height="14" fill="{STEEL_DK}"/>',
         f'<circle cx="44" cy="38" r="4" fill="#3e4650"/><circle cx="150" cy="38" r="4" fill="#3e4650"/>',
         shape("g", goo, col, 60 + ci, (2, 6, 190, 34), k=1.4)]
    return wrap(192, 64, "".join(b), 50 + ci)


def mola(ci, compressed):
    col = OWNER[ci]
    top = 22 if compressed else 4
    b = [f'<rect x="8" y="55" width="48" height="7" fill="{SLATE}"/>']
    n = 4
    y0, y1 = top + 22, 54
    for i in range(n):
        y = y0 + (y1 - y0) * (i + 0.5) / n
        b.append(f'<ellipse cx="32" cy="{y:.1f}" rx="14" ry="{max((y1 - y0) / n / 2 - 0.5, 1.5):.1f}" fill="none" stroke="{STEEL_LT}" stroke-width="3"/>')
    b.append(shape("t", f"M24,{top + 10} H40 V{top + 24} H24 Z", "#c98f4b", 70, (22, top + 8, 42, top + 26), k=1.4))
    b.append(shape("p", f"M6,{top + 2} H58 V{top + 11} H6 Z", "#c98f4b", 71, (4, top, 60, top + 13), k=1.4))
    b.append(f'<rect x="6" y="{top}" width="52" height="4" fill="{col}"/>')
    return wrap(64, 64, "".join(b), 70 + ci)


def serra_blade(rival):
    d = gear_d(32, 32, 30 if rival else 22, 8, 0.2, 0.28 if rival else 0.0)
    return wrap(64, 64, shape("g", d, STEEL_LT, 80, (0, 0, 64, 64), k=1.4, dark=STEEL_DK)
                + '<circle cx="32" cy="32" r="13" fill="#d0d8de"/>', 80)


def serra_hub(ci):
    # miolo em fechadura, na cor do dono
    col = OWNER[ci] if ci < 4 else SLATE
    return wrap(64, 64, f'<circle cx="32" cy="29" r="6" fill="{col}"/><path d="M29,31 L35,31 L36,41 L28,41 Z" fill="{col}"/>', 81)


def esteira(ci):
    col = OWNER[ci]
    b = [shape("e", rect_d(4, 14, 184, 44, 22), "#3e4752", 90 + ci, (2, 12, 190, 60), k=1.4, dark="#2b323b", light="#5a6370"),
         f'<path d="M18,16 H174 V24 H18 Z" fill="{col}"/>']
    for x in (30, 74, 118, 162):
        b.append(f'<circle cx="{x}" cy="42" r="8.5" fill="#d8dee3"/><circle cx="{x}" cy="42" r="3.2" fill="{SLATE}"/>')
    return wrap(192, 64, "".join(b), 90 + ci)


def seta():
    return doc(32, 32, '<path d="M11,8 L21,16 L11,24" stroke="#ffffff" stroke-width="3.6" fill="none" stroke-linecap="round" stroke-linejoin="round" opacity="0.85"/>')


def main():
    for i in range(3):
        queue(crate(10 + i), f"{SRC_C}/caixote_{i}.svg", f"{OUT_C}/caixote_{i}.png", 64, 64, K)
    for i in range(3):
        queue(spikes(20 + i), f"{SRC_C}/espinho_{i}.svg", f"{OUT_C}/espinho_{i}.png", 64, 128, K)
    queue(plank(), f"{SRC_C}/tabua.svg", f"{OUT_C}/tabua.png", 64, 16, K)
    queue(elevator(), f"{SRC_C}/elevador.svg", f"{OUT_C}/elevador.png", 128, 192, K)
    queue(background(), f"{SRC_C}/fundo_canteiro.svg", f"{OUT_C}/fundo_canteiro.png", 1920, 1080, 2)
    queue(dust(), f"{SRC_E}/poeira.svg", f"{OUT_C}/poeira.png", 64, 64, K)
    queue(sparkle(), f"{SRC_E}/brilho.svg", f"{OUT_C}/brilho.png", 32, 32, K)
    for ci in range(5):
        c = f"c{ci}"
        queue(viga(ci), f"{SRC_P}/viga_{c}.svg", f"{OUT_P}/viga_{c}.png", 192, 64, K)
        queue(mola(ci, False), f"{SRC_P}/mola_{c}.svg", f"{OUT_P}/mola_{c}.png", 64, 64, K)
        queue(mola(ci, True), f"{SRC_P}/mola_comprimida_{c}.svg", f"{OUT_P}/mola_comprimida_{c}.png", 64, 64, K)
        queue(serra_hub(ci), f"{SRC_P}/serra_cubo_{c}.svg", f"{OUT_P}/serra_cubo_{c}.png", 64, 64, K)
        queue(esteira(ci), f"{SRC_P}/esteira_{c}.svg", f"{OUT_P}/esteira_{c}.png", 192, 64, K)
    queue(serra_blade(True), f"{SRC_P}/serra_rival.svg", f"{OUT_P}/serra_rival.png", 64, 64, K)
    queue(serra_blade(False), f"{SRC_P}/serra_dono.svg", f"{OUT_P}/serra_dono.png", 64, 64, K)
    queue(seta(), f"{SRC_P}/esteira_seta.svg", f"{OUT_P}/esteira_seta.png", 32, 32, K)
    print("renderizados:", render_all())


if __name__ == "__main__":
    main()
