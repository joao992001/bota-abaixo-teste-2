"""Temas de arena 'natureza' (mesmo estilo papel e giz de temas.py): pantano, mina, serraria.
Para cada tema: bloco_0..2 (quebram), fixo (indestrutível), tabua (one-way 64x16) e fundo 1920x1080.
Saída: art/out/game/temas/<tema>/*.png (copiar para game/assets/temas/).
Rodar: python3 art/src/cenarios/temas_natureza.py
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from papel import hatch, rect_d, rough, shape  # noqa: E402
from svg import doc, queue, render_all, shade  # noqa: E402
from temas import K, OUT, SRC, base_block, block_doc, gear_d, wrap  # noqa: E402,F401


# ------------------------------------------------------------------ utilidades
def bevel(fill, top=5, bot=6, k_top=0.22, k_bot=-0.26):
    """Bisel discreto como os caixotes da ref5: faixa clara em cima, escura embaixo."""
    return [f'<rect x="0" y="0" width="64" height="{top}" fill="{shade(fill, k_top)}"/>',
            f'<rect x="0" y="{64 - bot}" width="64" height="{bot}" fill="{shade(fill, k_bot)}"/>']


def wavy_down(x0, x1, y0, amp, rnd, step=8.0):
    """Borda inferior ondulada (musgo escorrendo) da direita para a esquerda; pontas na mesma altura (encaixa)."""
    pts = [(x1, y0)]
    x = x1
    while x - step > x0 + 2:
        x -= step * rnd.uniform(0.7, 1.2)
        pts.append((x, y0 + rnd.uniform(-1, 1) * amp * 0.3 + (amp if rnd.random() < 0.45 else 0)))
    pts.append((x0, y0))
    d = f" L{pts[0][0]:.1f},{pts[0][1]:.1f}"
    for (ax, ay), (bx, by) in zip(pts, pts[1:]):
        mx = (ax + bx) / 2
        d += f" Q{mx:.1f},{max(ay, by) + 3:.1f} {bx:.1f},{by:.1f}"
    return d


def taper(pts, w0, w1):
    """Polígono de um galho/tronco a partir da linha central, afinando de w0 para w1."""
    n = len(pts)
    left, right = [], []
    for i, (x, y) in enumerate(pts):
        ax, ay = pts[max(i - 1, 0)]
        bx, by = pts[min(i + 1, n - 1)]
        dx, dy = bx - ax, by - ay
        ln = math.hypot(dx, dy) or 1
        nx, ny = -dy / ln, dx / ln
        w = (w0 + (w1 - w0) * i / (n - 1)) / 2
        left.append((x + nx * w, y + ny * w))
        right.append((x - nx * w, y - ny * w))
    poly = left + right[::-1]
    return "M" + " L".join(f"{x:.1f},{y:.1f}" for x, y in poly) + " Z"


def bent_line(x, y, ang, length, segs, wob, rnd):
    pts = [(x, y)]
    for _ in range(segs):
        ang += rnd.uniform(-wob, wob)
        x += math.cos(ang) * length / segs
        y += math.sin(ang) * length / segs
        pts.append((x, y))
    return pts, ang


def sky(c0, c1, c2, m=0.6):
    return (f'<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{c0}"/>'
            f'<stop offset="{m}" stop-color="{c1}"/><stop offset="1" stop-color="{c2}"/></linearGradient>')


# ================================================================== PÂNTANO
MUD, MOSS, MOSS_LT, MOSS_DK = "#8b6a47", "#7c9c45", "#a6c462", "#56702f"


def pan_bloco(i):
    rnd = random.Random(400 + i)
    if i == 0:   # torrão de terra com musgo escorrendo
        b = base_block(MUD, 400, shade(MUD, -0.32), dens=0.75)
        b += bevel(MUD, top=0, bot=6)
        for _ in range(6):   # pedrinhas
            x, y, r = rnd.uniform(8, 56), rnd.uniform(26, 54), rnd.uniform(2.2, 4.2)
            b.append(f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="{r * 1.3:.1f}" ry="{r:.1f}" fill="{shade(MUD, rnd.choice([-0.18, 0.18]))}"/>')
        b.append(f'<path d="M12,30 q6,8 2,16 q-3,6 2,10 M44,26 q-5,9 1,15 q4,5 -1,11" stroke="{shade(MUD, -0.38)}" stroke-width="2" fill="none" stroke-linecap="round"/>')
        d = "M-1,-1 H65" + wavy_down(-1, 65, 12, 8, rnd) + " Z"
        b.append(shape("mo", d, MOSS, 401, (0, 0, 64, 24), k=1.3, dens=0.7, dark=MOSS_DK))
        b.append(f'<rect x="0" y="0" width="64" height="4" fill="{MOSS_LT}"/>')
        for x in (10, 30, 50):   # tufos
            b.append(f'<path d="M{x},4 l2,-4 l2,4 l2,-3 l1,3" fill="{MOSS_LT}"/>')
    elif i == 1:   # sacos de areia em fileiras desencontradas
        gap = "#6a5638"
        sack = "#c9b07a"
        b = [f'<rect width="64" height="64" fill="{gap}"/>']
        for row, (y, xs) in enumerate([(1.5, (1.5, 33.5)), (33, (-14.5, 17.5, 49.5))]):
            for k, x in enumerate(xs):
                tone = shade(sack, rnd.uniform(-0.06, 0.06))
                sid = f"s{row}{k}"
                d = rect_d(x, y, 29, 29.5, 11)
                b.append(shape(sid, d, tone, 410 + row * 3 + k, (x, y, x + 29, y + 30), k=1.2, dens=0.6, dark=shade(sack, -0.3)))
                b.append(f'<path d="M{x + 3},{y + 23} Q{x + 14.5},{y + 30} {x + 26},{y + 23} V{y + 29.5} H{x + 3} Z" fill="{shade(tone, -0.18)}" clip-path="url(#{sid})"/>')
                b.append(f'<path d="M{x + 5},{y + 6} q4,-3 9,-2" stroke="{shade(tone, 0.45)}" stroke-width="2.4" fill="none" stroke-linecap="round"/>')
                b.append(f'<path d="M{x + 23},{y + 4} v22" stroke="{shade(tone, -0.3)}" stroke-width="1.6" stroke-dasharray="2.5 2.5"/>')
    else:   # tronco podre: casca vertical, oco e orelha-de-pau
        wood = "#7d705a"
        b = base_block(wood, 420, shade(wood, -0.35), dens=0.8)
        b += bevel(wood, top=4, bot=6, k_top=0.18)
        for x in (6, 17, 29, 41, 53):
            d = f"M{x},0 C{x + rnd.uniform(-5, 5):.1f},20 {x + rnd.uniform(-5, 5):.1f},42 {x + rnd.uniform(-2, 2):.1f},64"
            b.append(f'<path d="{d}" stroke="{shade(wood, -0.3)}" stroke-width="2.6" fill="none"/>')
        b.append(f'<ellipse cx="25" cy="30" rx="8" ry="11" fill="{shade(wood, 0.2)}"/><ellipse cx="25" cy="31" rx="5" ry="8" fill="#3d3236"/>')
        b.append('<path d="M40,40 q12,-5 22,1 q-10,6 -22,-1 Z M44,50 q8,-3 16,1 q-8,4 -16,-1 Z" fill="#d9a865"/>'
                 '<path d="M42,40 q10,-3 18,1" stroke="#f0cd8c" stroke-width="1.6" fill="none"/>')
        b.append(f'<path d="M0,56 q6,-8 12,-2 q4,-6 10,0 V64 H0 Z" fill="{MOSS}"/><path d="M48,8 q5,-6 10,0 q3,-3 6,0 V14 H48 Z" fill="{MOSS}" opacity="0.9"/>')
    return block_doc(b)


def pan_fixo():
    stone = "#4f5648"
    b = base_block(stone, 430, "#363b33", "#6b7462", dens=0.8)
    for (x, y, w, h) in [(3, 13, 58, 22), (-8, 38, 38, 23), (34, 38, 38, 23)]:
        b.append(f'<path d="{rect_d(x, y, w, h, 8)}" fill="{shade(stone, 0.1)}"/>')
        b.append(f'<path d="M{x + 4},{y + 5} q{w * 0.3:.0f},-3 {w * 0.55:.0f},0" stroke="{shade(stone, 0.32)}" stroke-width="2.4" fill="none" stroke-linecap="round"/>')
    b.append('<path d="M-1,-1 H65 V9 Q58,14 52,9 Q44,15 36,9 Q28,13 20,8 Q12,15 4,9 L-1,9 Z" fill="#4f6a32"/>')
    b.append('<rect x="0" y="0" width="64" height="3" fill="#6f8d45"/>')
    return block_doc(b)


def pan_tabua():
    wood, rope = "#8c7650", "#d1b67c"
    b = [f'<rect x="-1" y="2" width="66" height="11" fill="{wood}"/>', f'<rect x="-1" y="10" width="66" height="3" fill="{shade(wood, -0.3)}"/>',
         f'<rect x="-1" y="2" width="66" height="2" fill="{shade(wood, 0.3)}"/>',
         hatch("pk", (0, 2, 64, 13), wood, 440, k=1.2, dark=shade(wood, -0.35)),
         f'<path d="M31,3 V12" stroke="{shade(wood, -0.35)}" stroke-width="1.6"/>']
    for x in (6, 52):   # amarração de corda
        b.append(f'<rect x="{x}" y="1" width="7" height="13" rx="2" fill="{rope}"/>')
        for k in range(3):
            b.append(f'<path d="M{x},{4 + k * 3.5} l7,-2.4" stroke="{shade(rope, -0.3)}" stroke-width="1.2"/>')
    return wrap(64, 16, "".join(b), 440, 0.6).replace("<defs>", '<defs><clipPath id="pk"><rect y="2" width="64" height="11"/></clipPath>')


def swamp_tree(b, x, base, h, lean, rnd, col, w0):
    pts, ang = bent_line(x, base, -math.pi / 2 + lean, h, 7, 0.28, rnd)
    b.append(f'<path d="{taper(pts, w0, w0 * 0.3)}" fill="{col}"/>')
    # raízes de mangue
    for s in (-1, 1):
        rp = [(x + s * w0 * 0.2, base - h * 0.12), (x + s * w0 * 0.9, base - h * 0.04), (x + s * w0 * 1.5, base + 10)]
        b.append(f'<path d="{taper(rp, w0 * 0.32, w0 * 0.18)}" fill="{col}"/>')
    tips = [pts[-1]]
    for j in range(rnd.randint(3, 4)):
        px, py = pts[rnd.randint(3, 6)]
        side = rnd.choice([-1, 1])
        bp, _ = bent_line(px, py, -math.pi / 2 + side * rnd.uniform(0.7, 1.3), h * rnd.uniform(0.25, 0.4), 4, 0.45, rnd)
        b.append(f'<path d="{taper(bp, w0 * 0.35, w0 * 0.08)}" fill="{col}"/>')
        tips.append(bp[-1])
    for tx, ty in tips:   # copa achatada e barba-de-velho pendurada
        for _ in range(3):
            b.append(f'<ellipse cx="{tx + rnd.uniform(-40, 40):.0f}" cy="{ty + rnd.uniform(-10, 14):.0f}" rx="{rnd.uniform(45, 80):.0f}" ry="{rnd.uniform(18, 30):.0f}" fill="{col}"/>')
        for _ in range(4):
            mx = tx + rnd.uniform(-60, 60)
            ln = rnd.uniform(40, 110)
            b.append(f'<path d="M{mx:.0f},{ty + 10:.0f} q{rnd.uniform(-8, 8):.0f},{ln / 2:.0f} 0,{ln:.0f}" stroke="{col}" stroke-width="5" fill="none" stroke-linecap="round"/>')


def pan_fundo():
    rnd = random.Random(41)
    defs = sky("#e3ead2", "#d3dfc0", "#c7d6b4") + rough("rough", 11, 2.2, 0.03)
    b = ['<rect width="1920" height="1080" fill="url(#sky)"/>', '<g filter="url(#rough)">']
    b.append('<circle cx="1380" cy="250" r="120" fill="#eef1dc"/><circle cx="1380" cy="250" r="170" fill="#eef1dc" opacity="0.4"/>')
    # árvores distantes (camada clara) e médias
    for x in range(40, 2000, 330):
        swamp_tree(b, x + rnd.uniform(-40, 40), 840, rnd.uniform(380, 500), rnd.uniform(-0.25, 0.25), rnd, "#c9d7b9", 26)
    b.append('<ellipse cx="960" cy="760" rx="1300" ry="70" fill="#f2f4e6" opacity="0.55"/>')   # névoa de trás
    for x in (150, 820, 1560):
        swamp_tree(b, x + rnd.uniform(-40, 40), 860, rnd.uniform(560, 680), rnd.uniform(-0.3, 0.3), rnd, "#afc2a2", 44)
    # água parada
    b.append('<rect x="0" y="830" width="1920" height="250" fill="#b5cbb2"/>')
    for k in range(7):
        y = 860 + k * 32
        for _ in range(5):
            x = rnd.uniform(0, 1800)
            b.append(f'<path d="M{x:.0f},{y} h{rnd.uniform(60, 180):.0f}" stroke="#cadccb" stroke-width="5" stroke-linecap="round"/>')
    for _ in range(9):   # vitórias-régias
        x, y = rnd.uniform(40, 1880), rnd.uniform(880, 1050)
        b.append(f'<path d="M{x:.0f},{y:.0f} m-34,0 a34,12 0 1 0 68,0 a34,12 0 1 0 -68,0 Z" fill="#9db98e"/><path d="M{x:.0f},{y:.0f} l30,-6 l0,8 Z" fill="#b5cbb2"/>')
    for x in list(range(30, 1920, 140)):   # juncos e taboas
        for j in range(rnd.randint(2, 4)):
            xx = x + rnd.uniform(-25, 25)
            hh = rnd.uniform(70, 150)
            b.append(f'<path d="M{xx:.0f},900 q{rnd.uniform(-12, 12):.0f},{-hh / 2:.0f} {rnd.uniform(-10, 10):.0f},{-hh:.0f}" stroke="#97ae88" stroke-width="5" fill="none" stroke-linecap="round"/>')
            if rnd.random() < 0.4:
                b.append(f'<rect x="{xx - 5:.0f}" y="{900 - hh * 0.9:.0f}" width="10" height="30" rx="5" fill="#b3a58a"/>')
    # névoa baixa
    b.append('<ellipse cx="480" cy="840" rx="760" ry="46" fill="#f4f6ea" opacity="0.5"/><ellipse cx="1500" cy="860" rx="700" ry="40" fill="#f4f6ea" opacity="0.45"/>')
    b.append('</g>')
    for _ in range(30):   # vagalumes (sem o filtro, redondinhos)
        x, y = rnd.uniform(30, 1890), rnd.uniform(260, 1000)
        b.append(f'<circle cx="{x:.0f}" cy="{y:.0f}" r="11" fill="#f6f2b0" opacity="0.28"/><circle cx="{x:.0f}" cy="{y:.0f}" r="3.6" fill="#fbf8d2"/>')
    return doc(1920, 1080, "".join(b), defs)


# ================================================================== MINA
COAL = "#3c3440"


def mina_bloco(i):
    rnd = random.Random(500 + i)
    fill = ["#9c8b79", "#a77860", "#8693a1"][i]
    b = base_block(fill, 500 + i, shade(fill, -0.32), dens=0.8)
    b += bevel(fill)
    # facetas de rocha
    for _ in range(3):
        x, y = rnd.uniform(4, 40), rnd.uniform(8, 40)
        b.append(f'<path d="M{x:.0f},{y + 14:.0f} l{rnd.uniform(6, 10):.0f},-{rnd.uniform(10, 14):.0f} l{rnd.uniform(10, 16):.0f},{rnd.uniform(2, 5):.0f} l-4,{rnd.uniform(10, 14):.0f} Z" fill="{shade(fill, 0.13)}"/>')
    if i == 0:   # veios de carvão
        b.append(f'<path d="M-1,22 C14,16 22,30 36,24 S56,16 65,20 V28 C52,26 44,36 32,33 S10,28 -1,31 Z" fill="{COAL}"/>')
        b.append(f'<path d="M-1,47 C10,44 18,52 30,48 L34,53 C22,58 10,52 -1,55 Z" fill="{COAL}"/>')
        b.append('<path d="M10,25 l4,-2 M40,27 l5,-2" stroke="#6d6378" stroke-width="2" stroke-linecap="round"/>')
    elif i == 1:   # pepitas de ouro
        for x, y, r in [(16, 20, 5), (44, 16, 4), (36, 40, 6), (12, 46, 3.5), (52, 46, 4)]:
            b.append(f'<path d="M{x - r},{y} l{r * 0.6:.1f},-{r:.1f} l{r * 1.1:.1f},{r * 0.2:.1f} l{r * 0.4:.1f},{r * 0.9:.1f} l-{r:.1f},{r * 0.6:.1f} Z" fill="#e8a63c"/>'
                     f'<path d="M{x - r * 0.4:.1f},{y - r * 0.4:.1f} l{r * 0.5:.1f},-{r * 0.3:.1f}" stroke="#fde7a6" stroke-width="1.8" stroke-linecap="round"/>')
    else:   # cristais
        for x, y, s, a in [(18, 50, 1.0, -0.35), (30, 52, 1.3, 0.0), (42, 50, 0.9, 0.4), (50, 20, 0.7, 0.2)]:
            ca, sa = math.cos(a), math.sin(a)

            def p(u, v):
                return f"{x + (u * ca - v * sa) * s:.1f},{y + (u * sa + v * ca) * s:.1f}"
            b.append(f'<path d="M{p(-5, 0)} L{p(-5, -16)} L{p(0, -24)} L{p(5, -16)} L{p(5, 0)} Z" fill="#9fe0de"/>'
                     f'<path d="M{p(0, 0)} L{p(0, -24)} L{p(5, -16)} L{p(5, 0)} Z" fill="#6fb9c0"/>'
                     f'<path d="M{p(-3, -4)} L{p(-3, -14)}" stroke="#e6fbf8" stroke-width="1.8" stroke-linecap="round"/>')
    return block_doc(b)


def mina_fixo():
    rock, beam = "#4c4043", "#a07a52"
    b = base_block(rock, 530, "#332a2e", "#6a5a5c", dens=0.8)
    b.append(f'<path d="M4,52 l8,-22 l22,2 l4,22 Z" fill="{shade(rock, 0.12)}"/><path d="M38,58 l4,-26 l16,-4 l6,20 V58 Z" fill="{shade(rock, 0.07)}"/>')
    b.append(f'<path d="M8,34 l18,-6" stroke="{shade(rock, 0.3)}" stroke-width="2.4" stroke-linecap="round"/>')
    # viga de escora no topo, presa com grampos de ferro
    b.append(f'<rect x="0" y="0" width="64" height="16" fill="{beam}"/><rect x="0" y="0" width="64" height="3" fill="{shade(beam, 0.3)}"/><rect x="0" y="13" width="64" height="3" fill="{shade(beam, -0.4)}"/>')
    b.append(hatch("all", (0, 0, 64, 15), beam, 531, k=1.3, dens=0.5, dark=shade(beam, -0.4)))
    for x in (12, 52):
        b.append(f'<rect x="{x - 4}" y="0" width="8" height="16" fill="#5d5860"/><circle cx="{x}" cy="8" r="1.8" fill="#9a96a0"/>')
    return block_doc(b)


def mina_tabua():
    wood, iron = "#a07850", "#5d5860"
    b = [f'<rect x="-1" y="2" width="66" height="11" fill="{wood}"/>', f'<rect x="-1" y="10" width="66" height="3" fill="{shade(wood, -0.3)}"/>',
         f'<rect x="-1" y="2" width="66" height="2" fill="{shade(wood, 0.28)}"/>',
         hatch("pk", (0, 2, 64, 13), wood, 540, k=1.2, dark=shade(wood, -0.35))]
    for x in (8, 48):   # cintas de ferro
        b.append(f'<rect x="{x}" y="1.5" width="8" height="12" fill="{iron}"/><circle cx="{x + 4}" cy="7.5" r="1.6" fill="#9a96a0"/>')
    return wrap(64, 16, "".join(b), 540, 0.6).replace("<defs>", '<defs><clipPath id="pk"><rect y="2" width="64" height="11"/></clipPath>')


def lantern(b, x, y, wire_top):
    b.append(f'<path d="M{x},{wire_top} V{y - 22}" stroke="#4a3b3a" stroke-width="4"/>')
    b.append(f'<circle cx="{x}" cy="{y}" r="200" fill="#f2cf94" opacity="0.4" filter="url(#glow)"/>'
             f'<circle cx="{x}" cy="{y}" r="90" fill="#f7dcaa" opacity="0.5" filter="url(#glow)"/>')
    b.append(f'<rect x="{x - 18}" y="{y - 24}" width="36" height="8" rx="3" fill="#4a3b3a"/>'
             f'<rect x="{x - 14}" y="{y - 16}" width="28" height="30" rx="6" fill="#ffe2a2"/>'
             f'<rect x="{x - 18}" y="{y + 14}" width="36" height="8" rx="3" fill="#4a3b3a"/>'
             f'<path d="M{x},{y - 16} V{y + 14}" stroke="#4a3b3a" stroke-width="3"/>')


def mina_fundo():
    rnd = random.Random(51)
    defs = (sky("#4f3f42", "#6e5852", "#7e6558", 0.55) + rough("rough", 13, 2.2, 0.03)
            + '<filter id="glow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="40"/></filter>')
    b = ['<rect width="1920" height="1080" fill="url(#sky)"/>', '<g filter="url(#rough)">']
    # parede do fundo em lajes de rocha
    for _ in range(26):
        x, y = rnd.uniform(-100, 1900), rnd.uniform(120, 860)
        w, h = rnd.uniform(160, 340), rnd.uniform(90, 200)
        b.append(f'<path d="M{x:.0f},{y + h * 0.4:.0f} L{x + w * 0.3:.0f},{y:.0f} L{x + w * 0.85:.0f},{y + h * 0.1:.0f} L{x + w:.0f},{y + h * 0.65:.0f} L{x + w * 0.6:.0f},{y + h:.0f} L{x + w * 0.1:.0f},{y + h * 0.9:.0f} Z" fill="{rnd.choice(["#76605a", "#715b55", "#7c665d"])}" opacity="0.8"/>')
    # túneis com moldura de escoras
    for cx, w, h in [(420, 300, 330), (1500, 260, 300)]:
        top = 840 - h
        b.append(f'<path d="M{cx - w / 2},840 V{top + 70} Q{cx - w / 2},{top} {cx},{top} Q{cx + w / 2},{top} {cx + w / 2},{top + 70} V840 Z" fill="#4a3b3e"/>')
        b.append(f'<rect x="{cx - w / 2 - 26}" y="{top + 10}" width="26" height="{h - 10}" fill="#8a6c55"/><rect x="{cx + w / 2}" y="{top + 10}" width="26" height="{h - 10}" fill="#8a6c55"/>'
                 f'<rect x="{cx - w / 2 - 50}" y="{top - 14}" width="{w + 100}" height="28" fill="#957560"/>')
    # cristais no fundo (brilho turquesa suave)
    for cx, cy, s in [(980, 560, 1.4), (1180, 820, 1.0), (180, 760, 1.1), (1780, 600, 1.2), (760, 840, 0.8)]:
        for a, hh in ((-0.45, 70), (0, 100), (0.4, 60), (0.8, 40)):
            ca, sa = math.cos(a), math.sin(a)

            def p(u, v):
                return f"{cx + (u * ca - v * sa) * s:.1f},{cy + (u * sa + v * ca) * s:.1f}"
            b.append(f'<path d="M{p(-12, 0)} L{p(-12, -hh * 0.75)} L{p(0, -hh)} L{p(12, -hh * 0.75)} L{p(12, 0)} Z" fill="#8eaaa6"/>'
                     f'<path d="M{p(0, 0)} L{p(0, -hh)} L{p(12, -hh * 0.75)} L{p(12, 0)} Z" fill="#7a9696"/>')
    # teto com estalactites e vigas de escora
    b.append('<path d="M0,0 H1920 V70 ' + " ".join(f"L{x + 40},{70 + rnd.uniform(30, 110):.0f} L{x + 80},70" for x in range(1920, -80, -80)) + ' L0,70 Z" fill="#3e3135"/>')
    for x in (130, 960, 1820):
        b.append(f'<rect x="{x - 14}" y="60" width="28" height="800" fill="#7c614f" opacity="0.8"/>')
    b.append('<rect x="0" y="92" width="1920" height="30" fill="#8a6c55" opacity="0.9"/>')
    for x, y in [(300, 300), (1050, 260), (1660, 330)]:
        lantern(b, x, y, 120)
    # chão com trilho e vagonete
    b.append('<path d="M0,1080 V860 Q480,836 960,852 T1920,846 V1080 Z" fill="#6a534a"/>')
    for x in range(-20, 1940, 60):
        b.append(f'<rect x="{x}" y="902" width="34" height="14" fill="#7f6555"/>')
    b.append('<rect x="0" y="894" width="1920" height="8" fill="#a3918a"/>')
    cx = 1180
    b.append(f'<path d="M{cx - 120},790 H{cx + 120} L{cx + 100},880 H{cx - 100} Z" fill="#5a4a4a"/><rect x="{cx - 130}" y="780" width="260" height="16" fill="#685757"/>'
             f'<circle cx="{cx - 65}" cy="884" r="18" fill="#4a3d3e"/><circle cx="{cx + 65}" cy="884" r="18" fill="#4a3d3e"/>')
    for _ in range(7):
        b.append(f'<circle cx="{cx + rnd.uniform(-95, 95):.0f}" cy="{778 - rnd.uniform(0, 20):.0f}" r="{rnd.uniform(14, 24):.0f}" fill="#7a6a66"/>')
    b.append('</g>')
    return doc(1920, 1080, "".join(b), defs)


# ================================================================== SERRARIA
LOG_END, BARK = "#ddb07a", "#8a5a38"


def ser_bloco(i):
    rnd = random.Random(600 + i)
    if i == 0:   # toras empilhadas (pontas com anéis)
        b = [f'<rect width="64" height="64" fill="{shade(BARK, -0.35)}"/>']
        for row, (cy, xs) in enumerate([(16, (16, 48)), (48, (0, 32, 64))]):
            for k, cx in enumerate(xs):
                r = 15.5
                b.append(f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{BARK}"/>')
                tone = shade(LOG_END, rnd.uniform(-0.05, 0.05))
                b.append(shape(f"t{row}{k}", f"M{cx - r + 3},{cy} a{r - 3},{r - 3} 0 1 0 {2 * (r - 3)},0 a{r - 3},{r - 3} 0 1 0 {-2 * (r - 3)},0 Z",
                               tone, 600 + row * 3 + k, (cx - r, cy - r, cx + r, cy + r), k=1.1, dens=0.5, dark=shade(LOG_END, -0.25)))
                for rr in (8.5, 4.5):
                    b.append(f'<circle cx="{cx + 0.6:.1f}" cy="{cy + 0.4:.1f}" r="{rr}" fill="none" stroke="{shade(LOG_END, -0.22)}" stroke-width="1.5"/>')
                b.append(f'<circle cx="{cx}" cy="{cy}" r="1.6" fill="{shade(LOG_END, -0.35)}"/>')
                b.append(f'<path d="M{cx - 8},{cy - 7} q4,-4 10,-4" stroke="{shade(LOG_END, 0.45)}" stroke-width="2" fill="none" stroke-linecap="round"/>')
    elif i == 1:   # pilha de tábuas (de lado)
        plank = "#c88a52"
        b = [f'<rect width="64" height="64" fill="{shade(plank, -0.4)}"/>']
        for r in range(5):
            y = r * 12.8
            tone = shade(plank, rnd.uniform(-0.08, 0.1))
            sid = f"p{r}"
            b.append(shape(sid, rect_d(0, y + 1, 64, 11, 0), tone, 610 + r, (0, y, 64, y + 13), k=1.2, dens=0.7, dark=shade(plank, -0.3)))
            b.append(f'<rect x="0" y="{y + 1}" width="64" height="2" fill="{shade(tone, 0.3)}"/>')
            off = rnd.uniform(8, 40)
            b.append(f'<path d="M{off:.0f},{y + 6:.1f} q8,-2 16,0" stroke="{shade(tone, -0.25)}" stroke-width="1.4" fill="none"/>')
            b.append(f'<circle cx="{(r * 23 + 7) % 56 + 4}" cy="{y + 7:.1f}" r="1.5" fill="#5d5860"/>')
    else:   # fardo de serragem amarrado
        dust, rope = "#e4c58c", "#9a6b3c"
        b = base_block(dust, 620, shade(dust, -0.3), shade(dust, 0.5), dens=1.0)
        b += bevel(dust)
        for _ in range(40):   # lascas
            x, y = rnd.uniform(2, 62), rnd.uniform(6, 58)
            a = rnd.uniform(0, math.pi)
            b.append(f'<path d="M{x:.1f},{y:.1f} l{math.cos(a) * 3:.1f},{math.sin(a) * 3:.1f}" stroke="{rnd.choice([shade(dust, -0.25), "#b98a50", shade(dust, 0.4)])}" stroke-width="1.6" stroke-linecap="round"/>')
        for x in (17, 47):   # cordas
            b.append(f'<rect x="{x - 3}" y="0" width="6" height="64" fill="{rope}"/>')
            for y in range(2, 64, 6):
                b.append(f'<path d="M{x - 3},{y + 4} l6,-4" stroke="{shade(rope, -0.3)}" stroke-width="1.3"/>')
        b.append(f'<path d="M14,30 q3,5 6,0 q-3,-5 -6,0 Z" fill="{shade(rope, 0.15)}"/>')   # nó
    return block_doc(b)


def ser_fixo():
    wood, iron = "#5b3d2c", "#3f3a42"
    b = base_block(wood, 630, "#3e2a20", "#7d5a44", dens=0.85)
    for y in (0, 32):   # duas pranchas grossas de madeira de lei
        b.append(f'<rect x="0" y="{y}" width="64" height="3" fill="#7a5640"/><rect x="0" y="{y + 28}" width="64" height="4" fill="#3a271e"/>')
    b.append('<path d="M14,12 q14,-4 28,0 M24,44 q12,-3 24,0" stroke="#7d5a44" stroke-width="2" fill="none" stroke-linecap="round"/>')
    b.append(f'<rect x="26" y="0" width="12" height="64" fill="{iron}"/><rect x="26" y="0" width="3" height="64" fill="#6a6470"/>')   # cinta de ferro
    for y in (8, 24, 40, 56):
        b.append(f'<circle cx="32" cy="{y}" r="2" fill="#8d8792"/>')
    return block_doc(b)


def ser_tabua():
    wood = "#d9a464"
    b = [f'<rect x="-1" y="2" width="66" height="11" fill="{wood}"/>', f'<rect x="-1" y="10" width="66" height="3" fill="{shade(wood, -0.3)}"/>',
         f'<rect x="-1" y="2" width="66" height="2" fill="{shade(wood, 0.35)}"/>',
         hatch("pk", (0, 2, 64, 13), wood, 640, k=1.2, dark=shade(wood, -0.32)),
         f'<path d="M6,6.5 q14,-2.5 26,0 M36,7.5 q12,2 24,0" stroke="{shade(wood, -0.22)}" stroke-width="1.2" fill="none"/>',
         f'<ellipse cx="44" cy="7" rx="3" ry="1.8" fill="{shade(wood, -0.3)}"/>',
         '<circle cx="4" cy="7.5" r="1.5" fill="#5d5860"/><circle cx="60" cy="7.5" r="1.5" fill="#5d5860"/>']
    return wrap(64, 16, "".join(b), 640, 0.6).replace("<defs>", '<defs><clipPath id="pk"><rect y="2" width="64" height="11"/></clipPath>')


def pine(b, x, base, h, col, w=None):
    w = w or h * 0.42
    b.append(f'<rect x="{x - w * 0.06:.0f}" y="{base - h * 0.2:.0f}" width="{w * 0.12:.0f}" height="{h * 0.2 + 4:.0f}" fill="{shade(col, -0.12)}"/>')
    for k in range(3):
        t = base - h * 0.15 - k * h * 0.27
        ww = w * (1 - k * 0.24) / 2
        b.append(f'<path d="M{x - ww:.0f},{t:.0f} Q{x},{t + 12:.0f} {x + ww:.0f},{t:.0f} L{x},{t - h * 0.42:.0f} Z" fill="{col}"/>')


def ser_fundo():
    rnd = random.Random(61)
    defs = sky("#cfe5e8", "#eef0dc", "#f3e6c9", 0.55) + rough("rough", 15, 2.2, 0.03)
    b = ['<rect width="1920" height="1080" fill="url(#sky)"/>', '<g filter="url(#rough)">']
    for cx, cy, s in [(300, 170, 1.0), (1240, 120, 0.8), (1700, 230, 0.7)]:   # nuvens
        b.append(f'<path d="M{cx - 120 * s:.0f},{cy + 30 * s:.0f} a{50 * s:.0f},{40 * s:.0f} 0 0 1 {70 * s:.0f},-{50 * s:.0f} a{60 * s:.0f},{55 * s:.0f} 0 0 1 {110 * s:.0f},-{10 * s:.0f} a{45 * s:.0f},{40 * s:.0f} 0 0 1 {60 * s:.0f},{60 * s:.0f} Z" fill="#fbfaf2"/>')
    # montanhas (duas camadas)
    pts = " ".join(f"L{x},{rnd.uniform(330, 470):.0f}" if (x // 160) % 2 else f"L{x},{rnd.uniform(520, 600):.0f}" for x in range(0, 2081, 160))
    b.append(f'<path d="M0,700 {pts} L1920,700 Z" fill="#bfd0d2"/>')
    pts2 = " ".join(f"L{x},{rnd.uniform(470, 540):.0f}" if (x // 120) % 2 else f"L{x},{rnd.uniform(590, 630):.0f}" for x in range(-60, 2041, 120))
    b.append(f'<path d="M0,760 {pts2} L1920,760 Z" fill="#aac1bf"/>')
    # floresta de pinheiros (longe e perto)
    for x in range(-30, 1980, 46):
        pine(b, x + rnd.uniform(-10, 10), 760, rnd.uniform(170, 250), "#9ab8a6")
    b.append('<rect x="0" y="750" width="1920" height="40" fill="#9ab8a6"/>')
    for x in range(-40, 1990, 78):
        if 560 < x < 1360:
            continue
        pine(b, x + rnd.uniform(-14, 14), 850, rnd.uniform(240, 340), "#88a995")
    # galpão da serraria
    gx, gy, gw = 640, 560, 640
    b.append(f'<rect x="{gx}" y="{gy}" width="{gw}" height="300" fill="#ddd0bb"/>')
    for x in range(gx + 10, gx + gw, 40):
        b.append(f'<rect x="{x}" y="{gy}" width="6" height="300" fill="#d2c3ad"/>')
    b.append(f'<path d="M{gx - 50},{gy + 10} L{gx + gw / 2},{gy - 150} L{gx + gw + 50},{gy + 10} Z" fill="#c8b29c"/>'
             f'<rect x="{gx + gw - 140}" y="{gy - 230}" width="44" height="160" fill="#bea691"/>')
    for k, (dx, r) in enumerate([(0, 30), (30, 42), (80, 54)]):   # fumaça
        b.append(f'<circle cx="{gx + gw - 118 + dx}" cy="{gy - 270 - k * 60}" r="{r}" fill="#f6f4ec" opacity="0.85"/>')
    b.append(f'<rect x="{gx + 200}" y="{gy + 110}" width="240" height="190" fill="#bfab95"/>')   # portão aberto
    b.append(f'<rect x="{gx + 120}" y="{gy + 200}" width="400" height="44" rx="22" fill="#cdb79d"/><circle cx="{gx + 498}" cy="{gy + 222}" r="16" fill="#e2d3bb"/>')   # tora entrando
    b.append(f'<rect x="{gx + 160}" y="{gy + 244}" width="320" height="20" fill="#d2c3ad"/>')
    # roda d'água
    wx, wy = gx + gw + 80, gy + 200
    b.append(f'<circle cx="{wx}" cy="{wy}" r="110" fill="none" stroke="#c6b29c" stroke-width="14"/>')
    for k in range(8):
        a = k * math.pi / 4
        b.append(f'<path d="M{wx},{wy} L{wx + math.cos(a) * 110:.0f},{wy + math.sin(a) * 110:.0f}" stroke="#c6b29c" stroke-width="10"/>')
    # chão e pilhas de toras
    b.append('<path d="M0,1080 V840 Q480,820 960,836 T1920,830 V1080 Z" fill="#d8c5a0"/>')
    for x0 in (120, 1500):   # toras deitadas, vistas de lado
        for row in range(3):
            y = 820 - row * 34
            x = x0 + row * 30
            w = 300 - row * 60
            b.append(f'<rect x="{x}" y="{y}" width="{w}" height="34" rx="17" fill="#c9b596"/><ellipse cx="{x + w - 14}" cy="{y + 17}" rx="12" ry="15" fill="#e3d4ba"/>')
    b.append('</g>')
    return doc(1920, 1080, "".join(b), defs)


TEMAS = {
    "pantano": (pan_bloco, pan_fixo, pan_tabua, pan_fundo),
    "mina": (mina_bloco, mina_fixo, mina_tabua, mina_fundo),
    "serraria": (ser_bloco, ser_fixo, ser_tabua, ser_fundo),
}


def main():
    for nome, (bloco, fixo, tabua, fundo) in TEMAS.items():
        for i in range(3):
            queue(bloco(i), f"{SRC}/{nome}/bloco_{i}.svg", f"{OUT}/{nome}/bloco_{i}.png", 64, 64, K)
        queue(fixo(), f"{SRC}/{nome}/fixo.svg", f"{OUT}/{nome}/fixo.png", 64, 64, K)
        queue(tabua(), f"{SRC}/{nome}/tabua.svg", f"{OUT}/{nome}/tabua.png", 64, 16, K)
        queue(fundo(), f"{SRC}/{nome}/fundo.svg", f"{OUT}/{nome}/fundo.png", 1920, 1080, 2)
    print("temas natureza:", render_all())


if __name__ == "__main__":
    main()
