"""Canteiro de Obras (Derruba) — arena-piloto da demolição progressiva. Estilo papel e giz (ref5_usuario_cenario.png).
Mundo de 40x22 tiles de 64 px (2560x1408). Laje central em 6 segmentos de 4x2 tiles: os 2 do meio (núcleo) ficam
sobre pilares e nunca caem; os 4 de fora ficam sobre escoras de madeira e caem de vez. Andaimes dos lados e uma viga
pendurada no alto também caem de vez. Fora da arena: zonas de KO nos 4 lados.

Gera (art/out/game/canteiro/): laje_<estado>.png (0 íntegra, 1 rachada, 2 crítica), laje_pedaco_<n>.png, pilar.png,
escora.png, andaime.png, viga.png, fundo.png, e a prancha art/out/prancha_canteiro_derruba*.png.
Rodar: python3 art/src/cenarios/canteiro_derruba.py
"""
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from papel import ellipse_d, rect_d, rough, shape  # noqa: E402
from svg import doc, queue, render_all, shade  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.."))
SRC = os.path.join(ROOT, "art/src/cenarios/svg/canteiro")
OUT = os.path.join(ROOT, "art/out/game/canteiro")
PRANCHA = os.path.join(ROOT, "art/out")
T = 64
W, H = 40 * T, 22 * T
INK = "#2a1a2e"
CONC, CONC_TOP, CONC_SIDE = "#cbc2b1", "#e6dece", "#a1988a"
CRACK, REBAR, RUST = "#4a3f3a", "#b0562e", "#8a4a2a"
WOOD, WOOD_D = "#cf914f", "#8f5a2c"
STEEL, STEEL_D = "#71829a", "#4d5a6e"
PLANK = "#d9a05e"
YEL = "#f2c84b"
SKY0, SKY1 = "#8ad6e4", "#d4f1f2"
FAR, MID = "#a7dbe0", "#95c8cf"
DANGER = "#d42035"

# geometria (tiles)
LAJE_Y = 13                       # topo da laje
SEG_X = [8, 12, 16, 20, 24, 28]  # 6 segmentos de 4 tiles; 16 e 20 = núcleo
NUCLEO = (2, 3)
ANDAIME = [(3, 10, 5), (32, 10, 5)]  # (col, linha do topo, largura): 3 tiles acima da laje (pulo simples)
VIGA = (16, 8, 8)                    # 5 tiles acima da laje (pulo duplo)


def wrap(w, h, body, seed, scale=0.9):
    return doc(w, h, f'<g filter="url(#rough)">{body}</g>', rough(seed=seed, scale=scale, freq=0.05))


# ---------------------------------------------------------------- laje
def laje_body(x, y, w, h, state, seed, sid):
    """Segmento de laje (concreto) em x,y (px), estado 0..2. Topo claro, face lateral escura, ferros nas pontas."""
    rnd = random.Random(seed)
    b = []
    sag = [0, 0, 3][state]
    top = rect_d(x, y + sag, w, 14, 3)
    face = f"M{x},{y + 12 + sag} H{x + w} V{y + h - 6} Q{x + w},{y + h} {x + w - 6},{y + h} H{x + 6} Q{x},{y + h} {x},{y + h - 6} Z"
    if state == 2:   # crítica: borda de baixo comida e o meio cedendo
        face = (f"M{x},{y + 12 + sag} H{x + w} V{y + h - 14} L{x + w * 0.8},{y + h - 4} L{x + w * 0.62},{y + h + 4} "
                f"L{x + w * 0.4},{y + h - 2} L{x + w * 0.18},{y + h + 2} L{x},{y + h - 10} Z")
    b.append(shape(sid + "f", face, CONC, seed, (x, y, x + w, y + h + 6), k=3, dark=CONC_SIDE))
    b.append(shape(sid + "t", top, CONC_TOP, seed + 1, (x, y, x + w, y + 16 + sag), k=3))
    # faixa de sombra embaixo do topo e furinhos de forma
    b.append(f'<rect x="{x}" y="{y + 14 + sag}" width="{w}" height="5" fill="{CONC_SIDE}" opacity="0.6"/>')
    for k in range(int(w // 64)):
        cx = x + 32 + k * 64
        b.append(f'<circle cx="{cx}" cy="{y + h * 0.62}" r="3.2" fill="{CONC_SIDE}"/>')
    # ferros saindo da emenda
    for side in (0, 1):
        ex = x + (2 if side == 0 else w - 2)
        for yy in (y + 30, y + 50, y + 70, y + 92):
            if yy < y + h - 8:
                b.append(f'<path d="M{ex},{yy} l{-7 if side == 0 else 7},{rnd.uniform(-2, 2):.1f}" stroke="{RUST}" stroke-width="3" stroke-linecap="round"/>')
    if state >= 1:
        # rachaduras (2 grandes ramificadas + lascas na borda)
        for _ in range(3 if state == 1 else 4):
            cx, cy = rnd.uniform(x + 30, x + w - 30), y + 16 + sag
            d = f"M{cx:.1f},{cy:.1f}"
            for s in range(5 if state == 1 else 7):
                cx += rnd.uniform(-14, 14)
                cy += rnd.uniform(10, 18)
                if cy > y + h - 4:
                    break
                d += f" L{cx:.1f},{cy:.1f}"
                if rnd.random() < 0.35:
                    b.append(f'<path d="M{cx:.1f},{cy:.1f} l{rnd.uniform(-16, 16):.1f},{rnd.uniform(4, 10):.1f}" stroke="{CRACK}" stroke-width="2.2" fill="none" stroke-linecap="round"/>')
            b.append(f'<path d="{d}" stroke="{CRACK}" stroke-width="{3.4 if state == 2 else 2.6}" fill="none" stroke-linejoin="round" stroke-linecap="round"/>')
        for _ in range(3 if state == 1 else 6):   # lascas no topo
            cx = rnd.uniform(x + 10, x + w - 10)
            b.append(f'<path d="M{cx - 8:.1f},{y + sag} L{cx:.1f},{y + 7 + sag} L{cx + 9:.1f},{y + sag} Z" fill="{SKY1}"/>')
    if state == 2:
        # ferragem aparecendo nos buracos + fita zebrada no topo (aviso do ciclo)
        for k in range(3):
            hx = x + w * (0.25 + 0.25 * k)
            hy = y + h * 0.58
            b.append(f'<ellipse cx="{hx:.1f}" cy="{hy:.1f}" rx="15" ry="11" fill="{CRACK}" opacity="0.9"/>')
            b.append(f'<path d="M{hx - 16:.1f},{hy - 3:.1f} Q{hx:.1f},{hy + 8:.1f} {hx + 16:.1f},{hy - 2:.1f} M{hx - 12:.1f},{hy + 5:.1f} L{hx + 14:.1f},{hy + 4:.1f}" '
                     f'stroke="{REBAR}" stroke-width="3" fill="none" stroke-linecap="round"/>')
        b.append(zebra(x + 6, y - 2 + sag, w - 12, 9))
    return "".join(b)


def zebra(x, y, w, h):
    out = [f'<clipPath id="zc{int(x)}{int(y)}"><rect x="{x}" y="{y}" width="{w}" height="{h}" rx="2"/></clipPath>',
           f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="2" fill="{YEL}"/>', f'<g clip-path="url(#zc{int(x)}{int(y)})">']
    s = x - h
    while s < x + w:
        out.append(f'<path d="M{s},{y + h} L{s + h},{y} L{s + h + 9},{y} L{s + 9},{y + h} Z" fill="{INK}"/>')
        s += 22
    out.append('</g>')
    return "".join(out)


def laje_svg(state):
    w, h = 4 * T, 2 * T
    pad = 12
    body = f'<g transform="translate({pad},{pad})">' + laje_body(0, 0, w, h, state, 40 + state, f"l{state}") + '</g>'
    return wrap(w + 2 * pad, h + 2 * pad + 8, body, 50 + state), w + 2 * pad, h + 2 * pad + 8


def pedaco_svg(n):
    """Pedaço de laje caindo (6 formatos), com ferro torto."""
    rnd = random.Random(90 + n)
    pts = []
    cx, cy = 48, 40
    for k in range(7):
        a = k / 7 * 6.283 + rnd.uniform(-0.25, 0.25)
        r = rnd.uniform(24, 38)
        pts.append((cx + r * 1.15 * __import__("math").cos(a), cy + r * 0.8 * __import__("math").sin(a)))
    d = "M" + " L".join(f"{px:.1f},{py:.1f}" for px, py in pts) + " Z"
    body = shape(f"pd{n}", d, CONC, 91 + n, (0, 0, 96, 80), k=3, dark=CONC_SIDE)
    body += f'<path d="M{pts[0][0]:.1f},{pts[0][1]:.1f} q10,-14 22,-6" stroke="{REBAR}" stroke-width="3" fill="none" stroke-linecap="round"/>'
    top = f"M{pts[4][0]:.1f},{pts[4][1]:.1f} L{pts[5][0]:.1f},{pts[5][1]:.1f} L{pts[6][0]:.1f},{pts[6][1]:.1f}"
    body += f'<path d="{top}" stroke="{CONC_TOP}" stroke-width="5" fill="none" stroke-linecap="round"/>'
    return wrap(96, 80, body, 95 + n)


# ---------------------------------------------------------------- estruturas
def pilar_body(x, y, w, h, seed):
    b = [shape(f"pl{seed}", rect_d(x, y, w, h, 4), "#b9b09f", seed, (x, y, x + w, y + h), k=3, dark="#958c7c")]
    b.append(f'<rect x="{x + w - 14}" y="{y}" width="14" height="{h}" fill="#958c7c" opacity="0.55"/>')
    for yy in range(int(y + 40), int(y + h), 90):
        b.append(f'<path d="M{x + 6},{yy} H{x + w - 6}" stroke="#958c7c" stroke-width="3"/>')
    return "".join(b)


def escora_body(x, y, h, seed):
    """Escoras de madeira (2 postes compridos que descem até o chão, sumindo na névoa) + travessas em X."""
    b = []
    for px in (x + 34, x + 222):
        b.append(shape(f"es{seed}{px}", rect_d(px - 7, y, 14, h, 2), WOOD, seed + px, (px - 8, y, px + 8, y + h), k=2.4, dark=WOOD_D))
    yy = y + 16
    while yy < y + h - 60:
        b.append(f'<path d="M{x + 40},{yy} L{x + 216},{yy + 150} M{x + 216},{yy} L{x + 40},{yy + 150}" stroke="{WOOD_D}" stroke-width="7" stroke-linecap="round" opacity="0.95"/>')
        yy += 150
    return "".join(b)


def andaime_body(x, y, w, h, seed):
    """Torre de andaime: tubos de aço em X e tábua no topo (a parte de cima é a plataforma)."""
    b = []
    for px in (x + 10, x + w - 10):
        b.append(f'<path d="M{px},{y + 12} V{y + h}" stroke="{STEEL}" stroke-width="7" stroke-linecap="round"/>')
    yy = y + 14
    while yy < y + h - 40:
        b.append(f'<path d="M{x + 10},{yy} L{x + w - 10},{yy + 110} M{x + w - 10},{yy} L{x + 10},{yy + 110}" stroke="{STEEL}" stroke-width="5" opacity="0.9" stroke-linecap="round"/>')
        b.append(f'<path d="M{x + 6},{yy} H{x + w - 6}" stroke="{STEEL_D}" stroke-width="6" stroke-linecap="round"/>')
        yy += 110
    b.append(shape(f"ab{seed}", rect_d(x - 6, y, w + 12, 20, 4), PLANK, seed, (x - 8, y, x + w + 8, y + 22), k=2.6, dark=WOOD_D))
    b.append(zebra(x + 4, y + 22, w - 8, 8))
    return "".join(b)


def viga_body(x, y, w, seed):
    """Viga de aço pendurada por 2 cabos (plataforma do alto)."""
    b = []
    for cx in (x + 40, x + w - 40):
        b.append(f'<path d="M{cx},{y - 420} C{cx + 4},{y - 300} {cx - 4},{y - 140} {cx},{y}" stroke="#5a4a3a" stroke-width="4" fill="none"/>')
        b.append(f'<path d="M{cx - 10},{y - 6} L{cx},{y - 22} L{cx + 10},{y - 6}" stroke="#5a4a3a" stroke-width="4" fill="none"/>')
    b.append(shape(f"vg{seed}", rect_d(x, y, w, 26, 3), "#8796ab", seed, (x, y, x + w, y + 28), k=2.6, dark=STEEL_D))
    b.append(f'<rect x="{x}" y="{y}" width="{w}" height="6" fill="#a9b6c7"/><rect x="{x}" y="{y + 20}" width="{w}" height="6" fill="{STEEL_D}"/>')
    for ex in (x, x + w - 30):
        b.append(zebra(ex, y + 7, 30, 12))
    return "".join(b)


# ---------------------------------------------------------------- fundo
def viga_solo(x, y, w, seed):
    """Só a viga (sem os cabos, que o jogo desenha e pode romper)."""
    b = [shape(f"vs{seed}", rect_d(x, y, w, 26, 3), "#8796ab", seed, (x, y, x + w, y + 28), k=2.6, dark=STEEL_D)]
    b.append(f'<rect x="{x}" y="{y}" width="{w}" height="6" fill="#a9b6c7"/><rect x="{x}" y="{y + 20}" width="{w}" height="6" fill="{STEEL_D}"/>')
    for ex in (x, x + w - 30):
        b.append(zebra(ex, y + 7, 30, 12))
    return "".join(b)


def fundo_body():
    rnd = random.Random(7)
    b = [f'<defs><linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{SKY0}"/>'
         f'<stop offset="1" stop-color="{SKY1}"/></linearGradient>'
         f'<linearGradient id="nevoa" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{SKY1}" stop-opacity="0"/>'
         f'<stop offset="1" stop-color="#e9f7f6" stop-opacity="1"/></linearGradient></defs>',
         f'<rect width="{W}" height="{H}" fill="url(#sky)"/>']
    # nuvens
    for cx, cy, s in ((380, 210, 1.0), (1380, 140, 0.8), (2150, 260, 1.15), (900, 380, 0.6)):
        b.append(f'<path d="M{cx - 120 * s},{cy + 30 * s} C{cx - 120 * s},{cy - 10 * s} {cx - 60 * s},{cy - 20 * s} {cx - 40 * s},{cy - 10 * s} '
                 f'C{cx - 20 * s},{cy - 60 * s} {cx + 60 * s},{cy - 60 * s} {cx + 70 * s},{cy - 10 * s} C{cx + 120 * s},{cy - 20 * s} {cx + 140 * s},{cy + 30 * s} {cx + 110 * s},{cy + 30 * s} Z" fill="#f4fbfb"/>')
    # cidade longe (silhuetas)
    x = -40
    while x < W:
        bw, bh = rnd.uniform(90, 190), rnd.uniform(260, 620)
        b.append(f'<rect x="{x:.0f}" y="{H - 380 - bh:.0f}" width="{bw:.0f}" height="{bh + 400:.0f}" fill="{FAR}"/>')
        x += bw + rnd.uniform(10, 50)
    # grua grande ao fundo (decoração)
    gx = 2050
    b.append(f'<g stroke="{MID}" stroke-width="10" fill="none" stroke-linecap="round">'
             f'<path d="M{gx},{H} V220 M{gx + 70},{H} V220"/>')
    for yy in range(260, H, 120):
        b.append(f'<path d="M{gx},{yy} L{gx + 70},{yy + 120} M{gx + 70},{yy} L{gx},{yy + 120}"/>')
    b.append(f'<path d="M{gx - 900},230 H{gx + 360} M{gx - 900},230 L{gx + 35},150 L{gx + 360},230 M{gx - 700},230 V420"/></g>')
    b.append(f'<rect x="{gx - 760}" y="420" width="120" height="70" fill="{MID}"/>')
    # esqueleto de prédio em obra (meio)
    px0 = 260
    for c in range(5):
        b.append(f'<rect x="{px0 + c * 150}" y="520" width="22" height="{H - 520}" fill="{MID}"/>')
    for r in range(5):
        b.append(f'<rect x="{px0 - 20}" y="{520 + r * 170}" width="{4 * 150 + 62}" height="20" fill="{MID}"/>')
    # névoa de profundidade embaixo (o vazio)
    b.append(f'<rect x="0" y="{H - 520}" width="{W}" height="520" fill="url(#nevoa)"/>')
    return "".join(b)


# ---------------------------------------------------------------- arena montada (prancha)
def arena_body(states=None):
    """Arena inteira; states[i] = estado do segmento i (0..2, 3 = caiu)."""
    states = states or [0] * 6
    b = [fundo_body()]
    ly = LAJE_Y * T
    # pilares do núcleo
    for col in (17, 22):
        b.append(pilar_body(col * T + 8, ly + 2 * T - 4, 2 * T - 16, H - ly, 300 + col))
    # escoras dos segmentos de fora
    for i, sx in enumerate(SEG_X):
        if i in NUCLEO or states[i] == 3:
            continue
        b.append(escora_body(sx * T, ly + 2 * T - 6, H - ly - 2 * T + 6, 320 + i))
    # andaimes e viga
    for (c, r, wd) in ANDAIME:
        b.append(andaime_body(c * T, r * T, wd * T, H - r * T, 400 + c))
    vc, vr, vw = VIGA
    b.append(viga_body(vc * T, vr * T, vw * T, 500))
    # laje
    for i, sx in enumerate(SEG_X):
        if states[i] == 3:
            continue
        b.append(laje_body(sx * T, ly, 4 * T, 2 * T, states[i], 60 + i, f"lj{i}"))
    # juntas entre os segmentos: frestas escuras com ferro aparecendo (mostram onde cada pedaço pode cair)
    for i in range(1, 6):
        jx = SEG_X[i] * T
        if states[i - 1] == 3 or states[i] == 3:
            continue
        b.append(f'<path d="M{jx},{ly + 3} L{jx - 2},{ly + 40} L{jx + 2},{ly + 78} L{jx},{ly + 2 * T - 2}" stroke="{CRACK}" stroke-width="4" fill="none"/>')
        b.append(f'<path d="M{jx - 9},{ly + 26} h18 M{jx - 9},{ly + 96} h18" stroke="{RUST}" stroke-width="3"/>')
    # marca discreta do núcleo (não cai): placas amarelas nos pilares
    for col in (17, 22):
        b.append(f'<rect x="{col * T + 30}" y="{ly + 2 * T + 30}" width="60" height="34" rx="4" fill="{YEL}"/>'
                 f'<path d="M{col * T + 40},{ly + 2 * T + 47} h40" stroke="{INK}" stroke-width="4"/>')
    return "".join(b)


def prancha_estados():
    """Prancha 2: 4 estados do segmento + conceito do KO (voo + explosão na borda)."""
    b = [f'<rect width="1920" height="1080" fill="#eef7f6"/>']
    labels = ["1 · ÍNTEGRA", "2 · RACHADA", "3 · CRÍTICA (aviso)", "4 · DESABA"]
    for i in range(4):
        x0 = 70 + i * 460
        y0 = 150
        b.append(f'<text x="{x0 + 190}" y="110" font-family="Fredoka, Arial" font-weight="700" font-size="36" fill="{INK}" text-anchor="middle">{labels[i]}</text>')
        b.append(f'<g transform="translate({x0},{y0}) scale(1.45)">')
        if i < 3:
            b.append(laje_body(0, 0, 4 * T, 2 * T, i, 60 + i, f"pe{i}"))
            if i == 2:
                # tremendo: riscos de vibração + pedrinhas caindo
                for k in range(5):
                    b.append(f'<circle cx="{30 + k * 50}" cy="{150 + (k % 2) * 24}" r="{5 - k % 3}" fill="{CONC_SIDE}"/>')
                b.append(f'<path d="M-14,30 q-8,20 0,40 M270,30 q8,20 0,40" stroke="{INK}" stroke-width="3" fill="none" opacity="0.6"/>')
        else:
            rnd = random.Random(5)
            for k in range(6):
                ox, oy = k % 3 * 84 + rnd.uniform(-6, 6), (k // 3) * 60 + 40 + k * 10
                ang = rnd.uniform(-35, 35)
                b.append(f'<g transform="translate({ox},{oy}) rotate({ang:.0f} 48 40)">{pedaco_inner(k)}</g>')
            for k in range(5):
                cx, cy = rnd.uniform(0, 256), rnd.uniform(-10, 60)
                b.append(f'<ellipse cx="{cx:.0f}" cy="{cy:.0f}" rx="{rnd.uniform(24, 44):.0f}" ry="{rnd.uniform(16, 26):.0f}" fill="#d9cdb8" opacity="0.8"/>')
        b.append('</g>')
    # KO: robô voando com riscos de velocidade, estouro na borda e peças
    b.append(f'<text x="960" y="560" font-family="Fredoka, Arial" font-weight="700" font-size="36" fill="{INK}" text-anchor="middle">KO PELA BORDA: voa girando com rastro → estoura na linha de KO → peças e parafusos espalham</text>')
    b.append(f'<rect x="70" y="600" width="1780" height="420" rx="18" fill="{SKY1}"/>')
    b.append(f'<path d="M1500,600 V1020" stroke="{DANGER}" stroke-width="5" stroke-dasharray="18 14"/>')
    b.append(f'<text x="1515" y="640" font-family="Fredoka, Arial" font-weight="700" font-size="24" fill="{DANGER}">limite de KO (invisível no jogo)</text>')
    for k in range(5):
        b.append(f'<path d="M{380 + k * 30},{760 + k * 18} H{1020 + k * 40}" stroke="#ffffff" stroke-width="{8 - k}" stroke-linecap="round" opacity="0.9"/>')
    # explosão cartoon (como a ref2): nuvem amarela/laranja + fumaça escura contornada
    ex, ey = 1500, 800
    rnd = random.Random(3)
    for k, (col, r) in enumerate((("#3d3340", 150), ("#f08a3d", 120), (YEL, 88), ("#fff4c8", 46))):
        pts = []
        n = 14
        for j in range(n * 2):
            a = j / (n * 2) * 6.283
            rr = r * (1.0 if j % 2 == 0 else 0.72) * rnd.uniform(0.9, 1.1)
            pts.append(f"{ex + rr * 1.15 * __import__('math').cos(a):.0f},{ey + rr * __import__('math').sin(a):.0f}")
        b.append(f'<polygon points="{" ".join(pts)}" fill="{col}"/>')
    for k in range(8):
        a = k / 8 * 6.283
        b.append(f'<circle cx="{ex + 260 * __import__("math").cos(a):.0f}" cy="{ey + 170 * __import__("math").sin(a):.0f}" r="{10 + k % 3 * 5}" fill="#9aa4ae"/>')
    return doc(1920, 1080, f'<g filter="url(#rough)">{"".join(b)}</g>', rough(seed=4, scale=1.2, freq=0.05))


def pedaco_inner(n):
    s = pedaco_svg(n)
    return s[s.index('<g filter'):s.rindex('</svg>')]


def main():
    os.makedirs(OUT, exist_ok=True)
    K = 2
    for st in range(3):
        svg, w, h = laje_svg(st)
        queue(svg, f"{SRC}/laje_{st}.svg", f"{OUT}/laje_{st}.png", w, h, K)
    for n in range(6):
        queue(pedaco_svg(n), f"{SRC}/laje_pedaco_{n}.svg", f"{OUT}/laje_pedaco_{n}.png", 96, 80, K)
    queue(wrap(W, H, fundo_body(), 8, 0.6), f"{SRC}/fundo.svg", f"{OUT}/fundo.png", W, H, 0.75)
    # peças avulsas (o jogo desenha, derruba e anima cada uma): coordenadas a partir de (pad, pad)
    pad = 10
    pieces = {
        "andaime": (5 * T, 12 * T, lambda: andaime_body(pad, pad, 5 * T, 12 * T, 401)),
        "viga": (8 * T, 26, lambda: viga_body(pad, pad, 8 * T, 501).split('<path d="M' + str(pad + 40), 1)[0] if False else viga_solo(pad, pad, 8 * T, 501)),
        "viga4": (4 * T, 26, lambda: viga_solo(pad, pad, 4 * T, 503)),
        "pilar": (2 * T - 16, 8 * T, lambda: pilar_body(pad, pad, 2 * T - 16, 8 * T, 317)),
        "escora": (4 * T, 8 * T, lambda: escora_body(pad, pad, 8 * T, 321)),
    }
    for name, (pw, ph, fn) in pieces.items():
        queue(wrap(pw + 2 * pad, ph + 2 * pad, fn(), 600 + len(name)), f"{SRC}/{name}.svg", f"{OUT}/{name}.png", pw + 2 * pad, ph + 2 * pad, 2)
    # prancha 1: arena íntegra e arena no meio da rodada (2 segmentos caídos, 1 crítico, andaime esquerdo caído)
    queue(wrap(W, H, arena_body(), 9, 1.0), f"{SRC}/arena_integra.svg", f"{PRANCHA}/prancha_canteiro_derruba_1.png", W, H, 0.75)
    queue(wrap(W, H, arena_body([3, 1, 0, 0, 2, 3]), 9, 1.0), f"{SRC}/arena_meio.svg", f"{PRANCHA}/prancha_canteiro_derruba_2.png", W, H, 0.75)
    queue(prancha_estados(), f"{SRC}/estados.svg", f"{PRANCHA}/prancha_canteiro_derruba_3.png", 1920, 1080, 1)
    print("canteiro renderizado:", render_all())


if __name__ == "__main__":
    main()
