"""Kit do Canteiro (estilo ref1): blocos-cubo com bisel, one-way, espinho, lama, elevador,
fundo turquesa, plateia em silhueta, poeira; e as peças P01–P04 em cada cor de dono.
Rodar: python3 art/src/cenarios/canteiro.py
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from svg import DANGER, INK, PLAYER, doc, poly, save, shade, star_pts, symbol  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.."))
SRC_C = os.path.join(ROOT, "art/src/cenarios/svg")
SRC_P = os.path.join(ROOT, "art/src/pecas/svg")
SRC_E = os.path.join(ROOT, "art/src/efeitos/svg")
OUT_C = os.path.join(ROOT, "art/out/game/cenario")
OUT_P = os.path.join(ROOT, "art/out/game/pecas")
K = 2  # exporta em 2x (a Godot desenha em 0,5)

ORANGE = "#e0894a"
MAGENTA = "#d9567f"
GOLD = "#e8b23a"
STEEL = "#8d97a6"


# ------------------------------------------------------------------ blocos
def cube(base, emblem=False):
    """Cubo gordinho: frente na cor base, topo claro, lateral escura, contorno grosso."""
    top, side, front = shade(base, 0.32), shade(base, -0.28), base
    o = 3  # margem: os cubos ficam levemente separados, como na ref1
    d = 9  # profundidade do bisel
    b = []
    outer = [(o, o + d), (o + d, o), (64 - o, o), (64 - o, 64 - o - d), (64 - o - d, 64 - o), (o, 64 - o)]
    b.append(poly(outer, INK, INK, 6))
    b.append(poly([(o + 2, o + d), (o + d, o + 2), (64 - o - 2, o + 2), (64 - o - d - 2, o + d)], top))
    b.append(poly([(64 - o - d - 2, o + d), (64 - o - 2, o + 2), (64 - o - 2, 64 - o - d - 2), (64 - o - d - 2, 64 - o - 2)], side))
    b.append(f'<rect x="{o + 2}" y="{o + d}" width="{64 - 2 * o - d - 4}" height="{64 - 2 * o - d - 2}" fill="{front}"/>')
    # leve degradê chapado: faixa inferior um tom mais escura
    b.append(f'<rect x="{o + 2}" y="{64 - o - 14}" width="{64 - 2 * o - d - 4}" height="12" fill="{shade(base, -0.1)}"/>')
    b.append(f'<path d="M{o + d},{o + d} H{64 - o - d - 2} L{64 - o - 2},{o + 2} M{64 - o - d - 2},{o + d} V{64 - o - 2}" stroke="{INK}" stroke-width="2" fill="none"/>')
    b.append(f'<path d="M{o + 8},{o + d + 5} H{o + 22}" stroke="{shade(base, 0.55)}" stroke-width="3" stroke-linecap="round"/>')
    if emblem:  # emblema próprio: capacete de obra
        cx, cy = 28, 37
        em = shade(base, -0.22)
        b.append(f'<path d="M{cx - 12},{cy + 3} C{cx - 12},{cy - 9} {cx - 6},{cy - 13} {cx},{cy - 13} C{cx + 6},{cy - 13} {cx + 12},{cy - 9} {cx + 12},{cy + 3} Z" fill="{em}"/>')
        b.append(f'<rect x="{cx - 17}" y="{cy + 2}" width="34" height="6" rx="3" fill="{em}"/>')
        b.append(f'<rect x="{cx - 3}" y="{cy - 13}" width="6" height="15" fill="{shade(base, 0.25)}"/>')
    return doc(64, 64, "".join(b))


def oneway():
    return doc(64, 64, (
        f'<rect x="-2" y="3" width="68" height="17" rx="4" fill="{INK}"/>'
        f'<rect x="1" y="6" width="62" height="11" rx="2" fill="#d79a5a"/>'
        f'<rect x="1" y="6" width="62" height="3.5" fill="#efc08a"/>'
        f'<path d="M20,7 Q26,11 22,16 M44,8 Q38,12 46,16" stroke="#a96c35" stroke-width="1.8" fill="none"/>'
        f'<circle cx="7" cy="12" r="2" fill="{INK}"/><circle cx="57" cy="12" r="2" fill="{INK}"/>'))


def spikes():
    b = []
    for i in range(3):
        x = 2 + i * 20
        tip = (x + 10, 18)
        b.append(poly([(x, 64), tip, (x + 20, 64)], "#55505e", INK, 5))
        b.append(poly([(x + 10, 24), (x + 15, 62), (x + 18, 64), (x + 10, 64)], "#3e3a47"))
        b.append(poly([tip, (x + 7.3, 28), (x + 12.7, 28)], DANGER))
        b.append(f'<path d="M{x + 6},{58} L{x + 9},{34}" stroke="#8b8496" stroke-width="2" stroke-linecap="round"/>')
    return doc(64, 64, "".join(b))


def mud():
    w = []
    for i in range(0, 65, 4):
        w.append((i, 22 + 4 * math.sin(i / 64 * 2 * math.pi * 2)))
    top = " ".join(f"L{x},{y:.1f}" for x, y in w)
    return doc(64, 64, (
        f'<path d="M0,64 {top} L64,64 Z" fill="#8a4fa8"/>'
        f'<path d="M0,64 {" ".join(f"L{x},{y + 9:.1f}" for x, y in w)} L64,64 Z" fill="#6e3b8a"/>'
        f'<path d="M0,{w[0][1]:.1f} {top}" stroke="#c48be0" stroke-width="5" fill="none"/>'
        f'<circle cx="18" cy="42" r="3" fill="#b07fd6"/><circle cx="46" cy="48" r="2" fill="#b07fd6"/>'))


def elevator():
    b = [f'<rect x="4" y="18" width="120" height="172" rx="8" fill="{INK}"/>',
         '<rect x="10" y="24" width="108" height="160" rx="4" fill="#f2b632"/>',
         '<rect x="10" y="24" width="108" height="8" fill="#ffd970"/>',
         f'<rect x="22" y="44" width="84" height="140" rx="3" fill="{INK}"/>',
         '<rect x="26" y="48" width="37" height="136" fill="#5a6070"/>',
         '<rect x="65" y="48" width="37" height="136" fill="#4b5060"/>']
    for y in range(58, 184, 16):  # grade da porta-pantográfica
        b.append(f'<path d="M26,{y} L63,{y + 12} M63,{y} L26,{y + 12} M65,{y} L102,{y + 12} M102,{y} L65,{y + 12}" stroke="#7b8294" stroke-width="2.5"/>')
    b.append('<path d="M30,52 V182" stroke="#8d97a6" stroke-width="3"/>')
    # faixa de atenção (amarelo/preto) no topo
    b.append(f'<rect x="4" y="2" width="120" height="22" rx="6" fill="{INK}"/>')
    b.append('<rect x="9" y="6" width="110" height="14" rx="3" fill="#ffd23f"/>')
    for x in range(0, 120, 16):
        b.append(poly([(9 + x, 20), (17 + x, 6), (25 + x, 6), (17 + x, 20)], INK, extra='clip-path="url(#sc)"'))
    # luz de chegada (seta para cima)
    b.append(f'<circle cx="64" cy="36" r="9" fill="#ffffff" stroke="{INK}" stroke-width="3.5"/>')
    b.append(poly([(64, 30), (70, 39), (58, 39)], "#3aa7a3"))
    defs = '<clipPath id="sc"><rect x="9" y="6" width="110" height="14"/></clipPath>'
    return doc(128, 192, "".join(b), defs)


def background():
    rnd = random.Random(7)
    W, H = 1920, 1080
    b = ['<rect width="1920" height="1080" fill="url(#sky)"/>']
    defs = ('<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">'
            '<stop offset="0" stop-color="#46b5b0"/><stop offset="1" stop-color="#2f9590"/></linearGradient>')
    # camada distante: morros e prédios em teal escuro (sem contorno)
    far = "#2c8a86"
    b.append(f'<path d="M0,760 C200,640 360,700 520,620 C700,540 820,690 1000,640 C1180,590 1300,520 1500,600 C1680,670 1800,560 1920,600 V1080 H0 Z" fill="{far}"/>')
    for x, w, h in [(140, 120, 300), (300, 80, 220), (1240, 140, 360), (1420, 90, 260), (1700, 110, 320)]:
        b.append(f'<rect x="{x}" y="{1080 - 300 - h}" width="{w}" height="{h + 300}" rx="10" fill="{far}"/>')
    # guindaste distante (silhueta clara)
    crane = "#5cc2bd"
    b.append(f'<rect x="1560" y="170" width="26" height="700" fill="{crane}"/>')
    b.append(f'<rect x="1290" y="170" width="520" height="22" fill="{crane}"/>')
    for x in range(1300, 1800, 40):
        b.append(f'<path d="M{x},192 L{x + 20},170 L{x + 40},192" stroke="{crane}" stroke-width="6" fill="none"/>')
    b.append(f'<path d="M1360,192 V330" stroke="{crane}" stroke-width="4"/><rect x="1340" y="330" width="40" height="26" rx="6" fill="{crane}"/>')
    # formas brancas grandes e suaves (nossas: engrenagens, parafusos e capacetes)
    soft = 'fill="#ffffff" opacity="0.5"'
    for cx, cy, r in [(250, 230, 95), (1010, 140, 70), (700, 520, 60), (1750, 560, 80)]:
        b.append(poly(star_pts(cx, cy, 9, r, r * 0.8, rnd.random()), "#ffffff", extra='opacity="0.42"'))
        b.append(f'<circle cx="{cx}" cy="{cy}" r="{r * 0.32}" fill="#3aa7a3" opacity="0.9"/>')
    for cx, cy, s in [(560, 210, 1.3), (1380, 430, 1.0), (120, 560, 0.9)]:
        b.append(f'<g transform="translate({cx},{cy}) scale({s})"><polygon points="-40,0 -20,-34 20,-34 40,0 20,34 -20,34" {soft}/>'
                 f'<circle r="15" fill="#3aa7a3" opacity="0.7"/></g>')
    for cx, cy, s in [(820, 330, 1.4), (1650, 300, 1.1)]:
        b.append(f'<g transform="translate({cx},{cy}) scale({s})" {soft}><path d="M-46,10 C-46,-28 -24,-40 0,-40 C24,-40 46,-28 46,10 Z"/>'
                 f'<rect x="-60" y="6" width="120" height="16" rx="8"/></g>')
    for _ in range(26):  # brilhinhos
        x, y, r = rnd.randint(0, W), rnd.randint(60, 800), rnd.choice([5, 7, 9])
        b.append(poly(star_pts(x, y, 4, r, r * 0.35), "#ffffff", extra='opacity="0.55"'))
    return doc(W, H, "".join(b), defs)


def audience():
    """Plateia de operários em silhueta (borda inferior), 1920x150."""
    rnd = random.Random(3)
    b = []
    x = -20
    while x < 1940:
        w = rnd.randint(46, 64)
        h = rnd.randint(70, 110)
        cx = x + w / 2
        top = 150 - h
        col = rnd.choice(["#1a0e1c", "#22132a", "#150a17"])
        b.append(f'<rect x="{x}" y="{top + 30}" width="{w}" height="{h}" rx="{w / 2.4:.0f}" fill="{col}"/>')
        b.append(f'<circle cx="{cx}" cy="{top + 22}" r="{w * 0.32:.0f}" fill="{col}"/>')
        hat = rnd.random()
        if hat < 0.6:  # capacete
            b.append(f'<path d="M{cx - w * 0.36},{top + 16} C{cx - w * 0.36},{top - 4} {cx + w * 0.36},{top - 4} {cx + w * 0.36},{top + 16} Z" fill="{col}"/>')
            b.append(f'<rect x="{cx - w * 0.48}" y="{top + 12}" width="{w * 0.96}" height="7" rx="3" fill="{col}"/>')
        elif hat < 0.8:  # braço levantado comemorando
            side = rnd.choice([-1, 1])
            b.append(f'<path d="M{cx + side * w * 0.3},{top + 50} L{cx + side * w * 0.6},{top - 6}" stroke="{col}" stroke-width="13" stroke-linecap="round"/>')
        x += w - rnd.randint(4, 14)
    return doc(1920, 150, "".join(b))


def dust():
    return doc(64, 64, (
        '<circle cx="24" cy="38" r="15" fill="#9c7350"/><circle cx="40" cy="34" r="17" fill="#9c7350"/>'
        '<circle cx="32" cy="26" r="13" fill="#9c7350"/>'
        '<circle cx="28" cy="31" r="11" fill="#b88d66"/><circle cx="40" cy="28" r="10" fill="#b88d66"/>'
        '<circle cx="34" cy="22" r="5" fill="#d2ad85"/>'))


def sparkle():
    return doc(32, 32, poly(star_pts(16, 16, 4, 14, 4.5), "#ffffff", INK, 2))


# ------------------------------------------------------------------ peças (por cor do dono)
def badge(ci, cx, cy, r):
    return (f'<circle cx="{cx}" cy="{cy}" r="{r + 3.5}" fill="{INK}"/><circle cx="{cx}" cy="{cy}" r="{r}" fill="{PLAYER[ci]}"/>'
            f'<circle cx="{cx - r * 0.3}" cy="{cy - r * 0.35}" r="{r * 0.25}" fill="#ffffff" opacity="0.7"/>'
            + symbol(ci, cx, cy + 0.5, r * 0.5))


def viga(ci):
    col = PLAYER[ci]
    b = [f'<rect x="3" y="8" width="186" height="50" rx="9" fill="{INK}"/>',
         f'<rect x="8" y="13" width="176" height="40" rx="5" fill="{STEEL}"/>',
         f'<rect x="8" y="40" width="176" height="13" rx="4" fill="{shade(STEEL, -0.25)}"/>',
         f'<rect x="8" y="13" width="176" height="15" rx="4" fill="{col}"/>',
         f'<rect x="8" y="24" width="176" height="4" fill="{shade(col, -0.25)}"/>',
         f'<path d="M14,17 H70" stroke="#ffffff" stroke-width="3" stroke-linecap="round" opacity="0.8"/>',
         f'<path d="M8,28.5 H184" stroke="{INK}" stroke-width="2.5"/>']
    for x in (36, 84, 132):
        b.append(f'<ellipse cx="{x}" cy="38" rx="11" ry="5.5" fill="{shade(STEEL, -0.45)}"/>')
    for x in (16, 176):
        b.append(f'<circle cx="{x}" cy="47" r="3" fill="{INK}"/>')
    b.append(badge(ci, 160, 38, 10))
    return doc(192, 64, "".join(b))


def mola(ci, compressed):
    col = PLAYER[ci]
    top = 26 if compressed else 4
    b = [f'<rect x="5" y="47" width="54" height="15" rx="4" fill="{INK}"/>',
         f'<rect x="9" y="51" width="46" height="7" rx="2" fill="{STEEL}"/>']
    n = 4
    y0, y1 = top + 16, 50
    for i in range(n):
        ya = y0 + (y1 - y0) * i / n
        yb = y0 + (y1 - y0) * (i + 0.5) / n
        yc = y0 + (y1 - y0) * (i + 1) / n
        b.append(f'<path d="M14,{ya:.1f} L50,{yb:.1f} L14,{yc:.1f}" stroke="{INK}" stroke-width="8" fill="none" stroke-linejoin="round" stroke-linecap="round"/>')
        b.append(f'<path d="M14,{ya:.1f} L50,{yb:.1f} L14,{yc:.1f}" stroke="#c9ced6" stroke-width="3.5" fill="none" stroke-linejoin="round" stroke-linecap="round"/>')
    b.append(f'<rect x="2" y="{top}" width="60" height="19" rx="6" fill="{INK}"/>')
    b.append(f'<rect x="6" y="{top + 4}" width="52" height="11" rx="3" fill="{col}"/>')
    b.append(f'<path d="M10,{top + 7} H30" stroke="#ffffff" stroke-width="2.5" stroke-linecap="round" opacity="0.8"/>')
    b.append(symbol(ci, 46, top + 9.5, 4, INK))
    return doc(64, 64, "".join(b))


def serra_blade(rival):
    b = []
    if rival:
        b.append(poly(star_pts(32, 32, 12, 31, 22), INK, INK, 3))
        b.append(poly(star_pts(32, 32, 12, 26.5, 19.5), "#55505e"))
        for i in range(12):  # pontas vermelhas
            a = math.pi * 2 * i / 12
            b.append(poly([(32 + math.cos(a) * 26.5, 32 + math.sin(a) * 26.5),
                           (32 + math.cos(a - 0.12) * 21.5, 32 + math.sin(a - 0.12) * 21.5),
                           (32 + math.cos(a + 0.12) * 21.5, 32 + math.sin(a + 0.12) * 21.5)], DANGER))
        b.append(f'<circle cx="32" cy="32" r="19" fill="{INK}"/><circle cx="32" cy="32" r="16" fill="#c4cad3"/>')
    else:
        b.append(f'<circle cx="32" cy="32" r="22" fill="{INK}"/><circle cx="32" cy="32" r="18" fill="#c4cad3"/>')
    for i in range(3):
        a = math.pi * 2 * i / 3
        b.append(f'<path d="M{32 + math.cos(a) * 8:.1f},{32 + math.sin(a) * 8:.1f} L{32 + math.cos(a) * 14:.1f},{32 + math.sin(a) * 14:.1f}" stroke="#8d97a6" stroke-width="4" stroke-linecap="round"/>')
    b.append('<path d="M20,24 A14,14 0 0 1 30,18" stroke="#ffffff" stroke-width="3" fill="none" stroke-linecap="round"/>')
    return doc(64, 64, "".join(b))


def serra_hub(ci):
    return doc(64, 64, badge(ci, 32, 32, 9))


def esteira(ci):
    col = PLAYER[ci]
    b = [f'<rect x="3" y="10" width="186" height="50" rx="25" fill="{INK}"/>',
         f'<rect x="8" y="15" width="176" height="40" rx="20" fill="#454a57"/>',
         f'<rect x="20" y="15" width="152" height="10" fill="{col}"/>',
         f'<path d="M20,25 H172" stroke="{INK}" stroke-width="2.5"/>',
         f'<path d="M26,18.5 H80" stroke="#ffffff" stroke-width="2.5" stroke-linecap="round" opacity="0.75"/>']
    for x in (28, 74, 118, 164):
        b.append(f'<circle cx="{x}" cy="42" r="10" fill="{INK}"/><circle cx="{x}" cy="42" r="7" fill="#b9c0ca"/><circle cx="{x}" cy="42" r="2.4" fill="{INK}"/>')
    b.append(badge(ci, 96, 9, 9))
    return doc(192, 64, "".join(b))


def seta():
    return doc(32, 32, f'<path d="M9,6 L22,16 L9,26" stroke="{INK}" stroke-width="9" fill="none" stroke-linecap="round" stroke-linejoin="round"/>'
                       f'<path d="M9,6 L22,16 L9,26" stroke="#ffffff" stroke-width="4" fill="none" stroke-linecap="round" stroke-linejoin="round"/>')


def main():
    for name, svg in [("bloco_laranja", cube(ORANGE)), ("bloco_magenta", cube(MAGENTA)), ("bloco_dourado", cube(GOLD, True)),
                      ("oneway", oneway()), ("espinho", spikes()), ("lama", mud()), ("elevador", elevator())]:
        save(svg, f"{SRC_C}/{name}.svg", f"{OUT_C}/{name}.png", K)
    save(background(), f"{SRC_C}/fundo_canteiro.svg", f"{OUT_C}/fundo_canteiro.png", 1)
    save(audience(), f"{SRC_C}/plateia.svg", f"{OUT_C}/plateia.png", 1)
    save(dust(), f"{SRC_E}/poeira.svg", f"{OUT_C}/poeira.png", K)
    save(sparkle(), f"{SRC_E}/brilho.svg", f"{OUT_C}/brilho.png", K)
    for ci in range(5):
        c = f"c{ci}"
        save(viga(ci), f"{SRC_P}/viga_{c}.svg", f"{OUT_P}/viga_{c}.png", K)
        save(mola(ci, False), f"{SRC_P}/mola_{c}.svg", f"{OUT_P}/mola_{c}.png", K)
        save(mola(ci, True), f"{SRC_P}/mola_comprimida_{c}.svg", f"{OUT_P}/mola_comprimida_{c}.png", K)
        save(serra_hub(ci), f"{SRC_P}/serra_cubo_{c}.svg", f"{OUT_P}/serra_cubo_{c}.png", K)
        save(esteira(ci), f"{SRC_P}/esteira_{c}.svg", f"{OUT_P}/esteira_{c}.png", K)
    save(serra_blade(True), f"{SRC_P}/serra_rival.svg", f"{OUT_P}/serra_rival.png", K)
    save(serra_blade(False), f"{SRC_P}/serra_dono.svg", f"{OUT_P}/serra_dono.png", K)
    save(seta(), f"{SRC_P}/esteira_seta.svg", f"{OUT_P}/esteira_seta.png", K)
    print("cenário e peças gerados")


if __name__ == "__main__":
    main()
