"""Temas de arena (mesmo estilo papel e giz do Canteiro): para cada tema, 3 blocos que quebram, bloco fixo,
tábua (one-way) e fundo 1920x1080. Saída: art/out/game/temas/<tema>/*.png (copiar para game/assets/temas/).
Temas: fabrica (engradados de aço, galpão com engrenagens), porto (contêineres, cais e navios),
cidade (tijolos e telhados, cidade à noite).
Rodar: python3 art/src/cenarios/temas.py
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from papel import hatch, rect_d, rough, shape  # noqa: E402
from svg import doc, poly, queue, render_all, shade  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.."))
SRC = os.path.join(ROOT, "art/src/cenarios/svg/temas")
OUT = os.path.join(ROOT, "art/out/game/temas")
K = 3


def wrap(w, h, body, seed, scale=0.8):
    return doc(w, h, f'<g filter="url(#rough)">{body}</g>', rough(seed=seed, scale=scale, freq=0.08))


def gear_d(cx, cy, r, n, rot, tooth=0.22):
    pts = []
    for i in range(n * 4):
        a = rot + 2 * math.pi * i / (n * 4)
        rr = r if (i % 4) in (1, 2) else r * (1 - tooth)
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    return "M" + " L".join(f"{x:.1f},{y:.1f}" for x, y in pts) + " Z"


def base_block(fill, seed, dark, light=None, dens=0.7):
    """Bloco 64x64 chapado com tracinhos de giz (sem contorno), clip 'all'."""
    return [f'<rect x="0" y="0" width="64" height="64" fill="{fill}"/>',
            hatch("all", (0, 0, 64, 64), fill, seed, k=1.4, dens=dens, dark=dark, light=light)]


def block_doc(parts):
    return doc(64, 64, '<clipPath id="all"><rect width="64" height="64"/></clipPath>' + "".join(parts))


# ================================================================== FÁBRICA
STEEL, STEEL_LT, STEEL_DK, SLATE = "#9aa6b1", "#c3ccd3", "#6a7682", "#4b535e"


def fab_bloco(i):
    rnd = random.Random(100 + i)
    fill = [STEEL, "#e08a4a", "#8fb7c9"][i]
    dark = shade(fill, -0.3)
    b = base_block(fill, 100 + i, dark)
    # moldura e reforço diagonal (engradado de aço)
    b.append(f'<path d="M3,3 H61 V61 H3 Z" stroke="{shade(fill, -0.22)}" stroke-width="5" fill="none"/>')
    b.append(f'<path d="M8,{56 + rnd.uniform(-1, 1):.1f} L56,8" stroke="{shade(fill, -0.18)}" stroke-width="6"/>')
    for x, y in [(8, 8), (56, 8), (8, 56), (56, 56)]:
        b.append(f'<circle cx="{x}" cy="{y}" r="3.2" fill="{STEEL_LT}"/><circle cx="{x}" cy="{y}" r="1.4" fill="{SLATE}"/>')
    if i == 2:
        # faixa de perigo
        b.append('<clipPath id="fx"><rect x="3" y="27" width="58" height="10"/></clipPath><rect x="3" y="27" width="58" height="10" fill="#f2c84b"/><g clip-path="url(#fx)">')
        for k in range(-1, 8):
            b.append(f'<path d="M{3 + k * 12},37 L{13 + k * 12},27 L{19 + k * 12},27 L{9 + k * 12},37 Z" fill="#2f3640"/>')
        b.append('</g>')
    return block_doc(b)


def fab_fixo():
    b = base_block(SLATE, 120, "#363c45", "#6a7682")
    # viga em I vista de lado
    b.append('<rect x="0" y="0" width="64" height="12" fill="#6a7682"/><rect x="0" y="52" width="64" height="12" fill="#6a7682"/>')
    b.append('<rect x="0" y="9" width="64" height="3" fill="#3e4650"/><rect x="0" y="52" width="64" height="3" fill="#3e4650"/>')
    for x in (12, 32, 52):
        b.append(f'<circle cx="{x}" cy="6" r="2.4" fill="#aab4bc"/><circle cx="{x}" cy="58" r="2.4" fill="#aab4bc"/>')
    b.append('<path d="M10,20 L54,44 M54,20 L10,44" stroke="#3e4650" stroke-width="4" opacity="0.7"/>')
    return block_doc(b)


def fab_tabua():
    b = ['<rect x="-1" y="2" width="66" height="12" fill="#7d8894"/>', '<rect x="-1" y="11" width="66" height="3" fill="#4b535e"/>']
    for x in range(2, 64, 8):
        b.append(f'<rect x="{x}" y="4" width="4" height="7" fill="#4b535e"/>')   # grade de passarela
    b.append('<rect x="-1" y="2" width="66" height="2" fill="#c3ccd3"/>')
    return wrap(64, 16, "".join(b), 130, 0.5)


def fab_fundo():
    rnd = random.Random(7)
    defs = ('<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#f6dcb4"/>'
            '<stop offset="0.65" stop-color="#f1cfa4"/><stop offset="1" stop-color="#e9c396"/></linearGradient>') + rough("rough", 5, 2.2, 0.03)
    b = ['<rect width="1920" height="1080" fill="url(#sky)"/>', '<g filter="url(#rough)">']
    # janelas altas do galpão (luz entrando)
    for x in (140, 520, 900, 1280, 1660):
        b.append(f'<rect x="{x}" y="90" width="180" height="330" fill="#fbe9c9"/>')
        for k in range(1, 3):
            b.append(f'<rect x="{x + k * 60 - 3}" y="90" width="6" height="330" fill="#ecc89a"/>')
        b.append(f'<rect x="{x}" y="250" width="180" height="6" fill="#ecc89a"/>')
    # engrenagens grandes
    for cx, cy, r, n in [(330, 640, 190, 10), (1580, 560, 150, 9), (980, 760, 110, 8)]:
        b.append(f'<path d="{gear_d(cx, cy, r, n, rnd.random())}" fill="#e7bd8c"/><circle cx="{cx}" cy="{cy}" r="{r * 0.25:.0f}" fill="#efcb9d"/>')
    # canos
    st = 'stroke="#dfb383" stroke-width="34" fill="none" stroke-linecap="round" stroke-linejoin="round"'
    b.append(f'<path d="M-20,520 H600 V300 H1200 V460 H1940" {st}/>')
    b.append(f'<path d="M1400,-20 V200 H1760 V700" {st}/>')
    # chão de fábrica / máquinas em silhueta
    b.append('<path d="M0,1080 V820 H220 V760 H420 V840 H700 V720 H880 V800 H1120 V700 H1300 V780 H1560 V740 H1760 V820 H1920 V1080 Z" fill="#dcae7d"/>')
    # lâmpadas penduradas
    for x in (420, 1060, 1700):
        b.append(f'<path d="M{x},0 V140" stroke="#c99a6b" stroke-width="4"/><path d="M{x - 40},170 L{x + 40},170 L{x + 22},140 L{x - 22},140 Z" fill="#c99a6b"/>')
        b.append(f'<path d="M{x - 40},170 L{x + 40},170 L{x + 170},560 L{x - 170},560 Z" fill="#fff4dc" opacity="0.35"/>')
    b.append('</g>')
    return doc(1920, 1080, "".join(b), defs)


# ================================================================== PORTO
def porto_bloco(i):
    fill = ["#d9563f", "#3f7fc2", "#4aa66a"][i]
    dark = shade(fill, -0.32)
    b = base_block(fill, 200 + i, dark)
    # contêiner: frisos verticais (chapa corrugada) e moldura
    for x in range(9, 60, 9):
        b.append(f'<rect x="{x}" y="6" width="3.5" height="52" fill="{shade(fill, -0.18)}"/>')
    b.append(f'<path d="M2,2 H62 V62 H2 Z" stroke="{shade(fill, -0.38)}" stroke-width="4" fill="none"/>')
    for x, y in [(5, 5), (59, 5), (5, 59), (59, 59)]:
        b.append(f'<rect x="{x - 3}" y="{y - 3}" width="6" height="6" fill="{shade(fill, -0.45)}"/>')
    if i == 0:
        b.append(f'<rect x="20" y="26" width="24" height="12" fill="{shade(fill, 0.25)}"/>')   # etiqueta
    return block_doc(b)


def porto_fixo():
    b = base_block("#b9b6ad", 220, "#8d8a82", "#d6d3ca")
    b.append('<rect x="0" y="0" width="64" height="8" fill="#d6d3ca"/>')
    b.append('<path d="M10,30 q8,-6 14,2 q6,8 14,0" stroke="#9c998f" stroke-width="3" fill="none"/>')   # manchas do concreto
    b.append('<circle cx="46" cy="44" r="4" fill="#9c998f"/><circle cx="16" cy="50" r="2.5" fill="#9c998f"/>')
    return block_doc(b)


def porto_tabua():
    b = ['<rect x="-1" y="2" width="66" height="12" fill="#a4886a"/><rect x="-1" y="10.5" width="66" height="3.5" fill="#7a6248"/>',
         '<path d="M3,6 H24 M32,7 H58" stroke="#c4a888" stroke-width="1.2" stroke-linecap="round"/>',
         '<circle cx="6" cy="8" r="1.6" fill="#4b535e"/><circle cx="58" cy="8" r="1.6" fill="#4b535e"/>',
         hatch("pk", (0, 2, 64, 14), "#a4886a", 230, k=1.3, dark="#6e5640")]
    return wrap(64, 16, "".join(b), 230, 0.6).replace("<defs>", '<defs><clipPath id="pk"><rect y="2" width="64" height="12"/></clipPath>')


def porto_fundo():
    defs = ('<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#bfe6f2"/>'
            '<stop offset="0.6" stop-color="#f6e3c8"/><stop offset="1" stop-color="#f3d6b4"/></linearGradient>') + rough("rough", 6, 2.2, 0.03)
    b = ['<rect width="1920" height="1080" fill="url(#sky)"/>', '<g filter="url(#rough)">']
    b.append('<circle cx="1500" cy="300" r="110" fill="#fff1d2"/>')   # sol baixo
    # mar
    b.append('<rect x="0" y="640" width="1920" height="440" fill="#9fd4e0"/>')
    for k in range(9):
        y = 680 + k * 44
        b.append(f'<path d="M0,{y} q60,-12 120,0 t120,0 t120,0 t120,0 t120,0 t120,0 t120,0 t120,0 t120,0 t120,0 t120,0 t120,0 t120,0 t120,0 t120,0 t120,0" stroke="#b9e2ea" stroke-width="5" fill="none"/>')
    # navios ao longe
    for x, w in [(260, 320), (980, 240)]:
        b.append(f'<path d="M{x},640 L{x + 20},600 H{x + w - 20} L{x + w},640 Z" fill="#8fbccb"/>')
        b.append(f'<rect x="{x + w * 0.6}" y="560" width="{w * 0.22}" height="40" fill="#8fbccb"/>')
        for c in range(4):
            b.append(f'<rect x="{x + 40 + c * 34}" y="578" width="30" height="22" fill="#a8cbd6"/>')
    # guindastes de contêiner (pórticos) e farol
    st = 'stroke="#a9c9d2" stroke-width="10" fill="none" stroke-linecap="square"'
    for x in (520, 1700):
        b.append(f'<path d="M{x},700 V180 M{x + 120},700 V180 M{x - 160},180 H{x + 300} M{x},300 H{x + 120}" {st}/>')
        b.append(f'<path d="M{x},180 L{x + 60},110 L{x + 120},180" {st}/>')
    b.append('<path d="M1260,640 L1282,360 H1318 L1340,640 Z" fill="#f1e6d6"/><rect x="1282" y="430" width="36" height="34" fill="#e6795a"/><rect x="1276" y="330" width="48" height="30" fill="#e6795a"/>')
    # cais no primeiro plano
    b.append('<rect x="0" y="900" width="1920" height="180" fill="#d8c3a6"/>')
    for x in range(0, 1920, 160):
        b.append(f'<rect x="{x + 20}" y="900" width="18" height="180" fill="#c7b091"/>')
    b.append('</g>')
    return doc(1920, 1080, "".join(b), defs)


# ================================================================== CIDADE À NOITE
def cid_bloco(i):
    rnd = random.Random(300 + i)
    fill = ["#b8604a", "#a85a4f", "#c47457"][i]
    mortar = "#e8cdbb"
    b = [f'<rect x="0" y="0" width="64" height="64" fill="{mortar}"/>']
    # tijolos em fileiras desencontradas
    for row in range(4):
        y = row * 16
        off = 0 if row % 2 == 0 else -16
        for col in range(3):
            x = off + col * 32
            tone = shade(fill, rnd.uniform(-0.1, 0.08))
            b.append(f'<rect x="{x + 1.5}" y="{y + 1.5}" width="29" height="13" fill="{tone}"/>')
    b.append(hatch("all", (0, 0, 64, 64), fill, 300 + i, k=1.4, dens=0.5, dark=shade(fill, -0.35)))
    if i == 2:
        # janelinha acesa
        b.append('<rect x="18" y="16" width="28" height="30" fill="#4a3f6e"/><rect x="21" y="19" width="22" height="24" fill="#ffd97a"/>'
                 '<rect x="31" y="19" width="2.5" height="24" fill="#4a3f6e"/><rect x="21" y="30" width="22" height="2.5" fill="#4a3f6e"/>')
    return block_doc(b)


def cid_fixo():
    b = base_block("#6b6f86", 320, "#4b4e63", "#8b8fa8")
    b.append('<rect x="0" y="0" width="64" height="10" fill="#8b8fa8"/><rect x="0" y="10" width="64" height="3" fill="#4b4e63"/>')   # beiral
    for x in (14, 40):
        b.append(f'<rect x="{x}" y="24" width="12" height="16" fill="#4b4e63"/>')
    return block_doc(b)


def cid_tabua():
    b = ['<rect x="-1" y="3" width="66" height="9" fill="#4b4e63"/>', '<rect x="-1" y="3" width="66" height="2" fill="#8b8fa8"/>']
    for x in range(4, 64, 10):
        b.append(f'<path d="M{x},5 L{x + 6},12" stroke="#2f3145" stroke-width="2"/>')   # escada de incêndio
    return wrap(64, 16, "".join(b), 330, 0.5)


def cid_fundo():
    rnd = random.Random(9)
    defs = ('<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#3e3f78"/>'
            '<stop offset="0.6" stop-color="#6b5a98"/><stop offset="1" stop-color="#a77ea8"/></linearGradient>') + rough("rough", 8, 2.2, 0.03)
    b = ['<rect width="1920" height="1080" fill="url(#sky)"/>', '<g filter="url(#rough)">']
    b.append('<circle cx="1560" cy="220" r="90" fill="#fff4d8"/><circle cx="1530" cy="200" r="20" fill="#f0e2c0"/><circle cx="1590" cy="250" r="12" fill="#f0e2c0"/>')
    for k in range(70):
        x, y = rnd.uniform(0, 1920), rnd.uniform(0, 520)
        b.append(f'<circle cx="{x:.0f}" cy="{y:.0f}" r="{rnd.uniform(1.5, 3.2):.1f}" fill="#fff6dc" opacity="{rnd.uniform(0.5, 1):.2f}"/>')
    # duas camadas de prédios com janelas acesas
    for layer, (col, win, y0, h0, h1) in enumerate([("#5a4f86", "#f2d38a", 520, 220, 460), ("#47406f", "#ffd97a", 640, 160, 380)]):
        x = -40
        while x < 1960:
            w = rnd.uniform(140, 240)
            h = rnd.uniform(h0, h1)
            top = 1080 - h - (0 if layer else 60)
            b.append(f'<rect x="{x:.0f}" y="{top:.0f}" width="{w:.0f}" height="{h + 80:.0f}" fill="{col}"/>')
            if rnd.random() < 0.3:   # caixa d'água ou antena no telhado
                b.append(f'<rect x="{x + w * 0.3:.0f}" y="{top - 50:.0f}" width="40" height="34" fill="{col}"/><path d="M{x + w * 0.3 + 6:.0f},{top - 16:.0f} V{top:.0f} M{x + w * 0.3 + 34:.0f},{top - 16:.0f} V{top:.0f}" stroke="{col}" stroke-width="5"/>')
            for wy in range(int(top) + 24, 1080, 46):
                for wx in range(int(x) + 18, int(x + w) - 22, 34):
                    if rnd.random() < 0.38:
                        b.append(f'<rect x="{wx}" y="{wy}" width="16" height="22" fill="{win}" opacity="{0.55 + 0.4 * rnd.random():.2f}"/>')
            x += w + rnd.uniform(6, 30)
    # outdoor neon
    b.append('<rect x="760" y="420" width="300" height="120" fill="#2f2b4f"/><rect x="772" y="432" width="276" height="96" fill="none" stroke="#ff7ab8" stroke-width="6"/>'
             '<path d="M880,512 L940,452" stroke="#7af0e0" stroke-width="9" fill="none" stroke-linecap="round"/>'
             '<path d="M920,432 L964,476 L986,454 L942,410 Z" stroke="#7af0e0" stroke-width="7" fill="none" stroke-linejoin="round"/>'
             '<circle cx="830" cy="480" r="10" fill="#ff7ab8"/><circle cx="1010" cy="480" r="10" fill="#ff7ab8"/>')
    b.append('</g>')
    return doc(1920, 1080, "".join(b), defs)


TEMAS = {
    "fabrica": (fab_bloco, fab_fixo, fab_tabua, fab_fundo),
    "porto": (porto_bloco, porto_fixo, porto_tabua, porto_fundo),
    "cidade": (cid_bloco, cid_fixo, cid_tabua, cid_fundo),
}


def main():
    for nome, (bloco, fixo, tabua, fundo) in TEMAS.items():
        for i in range(3):
            queue(bloco(i), f"{SRC}/{nome}/bloco_{i}.svg", f"{OUT}/{nome}/bloco_{i}.png", 64, 64, K)
        queue(fixo(), f"{SRC}/{nome}/fixo.svg", f"{OUT}/{nome}/fixo.png", 64, 64, K)
        queue(tabua(), f"{SRC}/{nome}/tabua.svg", f"{OUT}/{nome}/tabua.png", 64, 16, K)
        queue(fundo(), f"{SRC}/{nome}/fundo.svg", f"{OUT}/{nome}/fundo.png", 1920, 1080, 2)
    print("temas:", render_all())


if __name__ == "__main__":
    main()
