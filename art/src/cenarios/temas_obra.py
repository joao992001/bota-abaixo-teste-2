"""Temas de arena de obra (estilo papel e giz de temas.py): 3 blocos que quebram, bloco fixo, tábua (one-way)
e fundo 1920x1080. Saída: art/out/game/temas/<tema>/*.png (copiar para game/assets/temas/).
Temas: concreto (canteiro de obra de dia: concreto, tijolo baiano, sacos de cimento; prédio subindo e guindaste),
demolicao (prédio velho caindo: papel de parede, tijolo aparente, azulejo; poeira e bola de demolição),
viaduto (concreto e asfalto ao entardecer: faixas, guard-rail; rio e cidade em silhueta).
Rodar: python3 art/src/cenarios/temas_obra.py
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from papel import hatch, rough  # noqa: E402
from svg import doc, queue, render_all, shade  # noqa: E402
from temas import K, OUT, SRC, base_block, block_doc, wrap  # noqa: E402


def face(fill, gap, seed, dens=0.7, dark=None, r=4):
    """Bloco com junta (gap) na borda, face chapada com giz e bisel de 1 tom (topo claro, base escura)."""
    return [f'<rect width="64" height="64" fill="{gap}"/>',
            f'<clipPath id="fc"><rect x="2" y="2" width="60" height="60" rx="{r}"/></clipPath>',
            f'<rect x="2" y="2" width="60" height="60" rx="{r}" fill="{fill}"/>',
            f'<g clip-path="url(#fc)"><rect x="0" y="2" width="64" height="5" fill="{shade(fill, 0.22)}"/>'
            f'<rect x="0" y="56" width="64" height="6" fill="{shade(fill, -0.16)}"/></g>',
            hatch("fc", (0, 0, 64, 64), fill, seed, k=1.4, dens=dens, dark=dark or shade(fill, -0.3))]


def pebbles(rnd, n, col, box=(6, 8, 58, 56), rmax=1.8):
    x0, y0, x1, y1 = box
    return "".join(f'<circle cx="{rnd.uniform(x0, x1):.1f}" cy="{rnd.uniform(y0, y1):.1f}" r="{rnd.uniform(0.8, rmax):.1f}" fill="{col}"/>'
                   for _ in range(n))


def cloud(x, y, s, col, op=0.9):
    """Nuvem chapada de base reta (lobos redondos)."""
    return (f'<path d="M{x},{y} q{8 * s},{-34 * s} {46 * s},{-30 * s} q{18 * s},{-40 * s} {64 * s},{-26 * s} '
            f'q{40 * s},{-8 * s} {50 * s},{26 * s} q{30 * s},{2 * s} {34 * s},{30 * s} Z" fill="{col}" opacity="{op}"/>')


def lattice(x0, y0, x1, y1, n, col, w):
    """Treliça (duas linhas + zigue-zague) de (x0,y0) a (x1,y1), largura w perpendicular."""
    dx, dy = x1 - x0, y1 - y0
    ln = math.hypot(dx, dy)
    nx, ny = -dy / ln * w / 2, dx / ln * w / 2
    a = [(x0 + nx, y0 + ny), (x1 + nx, y1 + ny)]
    b = [(x0 - nx, y0 - ny), (x1 - nx, y1 - ny)]
    d = f"M{a[0][0]:.0f},{a[0][1]:.0f} L{a[1][0]:.0f},{a[1][1]:.0f} M{b[0][0]:.0f},{b[0][1]:.0f} L{b[1][0]:.0f},{b[1][1]:.0f} M"
    pts = []
    for i in range(n + 1):
        t = i / n
        side = (nx, ny) if i % 2 == 0 else (-nx, -ny)
        pts.append(f"{x0 + dx * t + side[0]:.0f},{y0 + dy * t + side[1]:.0f}")
    return f'<path d="{d}{" L".join(pts)}" stroke="{col}" stroke-width="{max(3, w * 0.12):.0f}" fill="none" stroke-linejoin="round"/>'


# ================================================================== CANTEIRO (obra de dia)
def can_bloco(i):
    rnd = random.Random(400 + i)
    if i == 0:   # bloco de concreto (2 furos)
        fill = "#bdb6a8"
        b = face(fill, "#857e72", 400)
        for x in (9, 35):
            b.append(f'<rect x="{x}" y="15" width="20" height="34" rx="4" fill="#6f685e"/>'
                     f'<rect x="{x}" y="15" width="20" height="7" rx="3" fill="#57514a"/>')
        b.append(pebbles(rnd, 9, "#9a9385"))
        return block_doc(b)
    if i == 1:   # tijolo baiano (8 furos)
        fill = "#d9864c"
        b = face(fill, "#a8683e", 401)
        for r in range(2):
            for c in range(4):
                x, y = 8 + c * 13, 15 + r * 19
                b.append(f'<rect x="{x}" y="{y}" width="9.5" height="14" rx="2.5" fill="#8c4a2b"/>'
                         f'<rect x="{x}" y="{y}" width="9.5" height="4" rx="2" fill="#6e3820"/>')
        return block_doc(b)
    # sacos de cimento empilhados
    kraft = "#e6d09a"
    b = ['<rect width="64" height="64" fill="#9c8a62"/>']
    for k, (y, h) in enumerate([(2, 29), (33, 29)]):
        sid = f"sc{k}"
        d = f"M5,{y} H59 Q63,{y} 62,{y + 6} Q60,{y + h / 2} 62,{y + h - 6} Q63,{y + h} 59,{y + h} H5 Q1,{y + h} 2,{y + h - 6} Q4,{y + h / 2} 2,{y + 6} Q1,{y} 5,{y} Z"
        b.append(f'<clipPath id="{sid}"><path d="{d}"/></clipPath><path d="{d}" fill="{kraft}"/>')
        b.append(f'<g clip-path="url(#{sid})"><rect x="0" y="{y}" width="64" height="4" fill="#f3e4bd"/>'
                 f'<rect x="0" y="{y + h - 5}" width="64" height="5" fill="#c9b07a"/>'
                 f'<rect x="0" y="{y + h / 2 - 4:.1f}" width="64" height="8" fill="#4f8fb8"/>'
                 f'<rect x="{26 + 6 * k}" y="{y + h / 2 - 2:.1f}" width="10" height="4" rx="2" fill="#e9f1f5"/></g>')
        b.append(hatch(sid, (0, y, 64, y + h), kraft, 402 + k, k=1.4, dens=0.6, dark="#a88f5c"))
        # dobras nos cantos
        b.append(f'<path d="M6,{y + 4} l5,5 M58,{y + 4} l-5,5 M6,{y + h - 4} l5,-5 M58,{y + h - 4} l-5,-5" stroke="#b79d68" stroke-width="1.6" stroke-linecap="round"/>')
    return block_doc(b)


def can_fixo():
    b = base_block("#555963", 420, "#3b3e47", "#737783")
    b.append('<rect width="64" height="8" fill="#757986"/><rect y="8" width="64" height="3" fill="#3b3e47"/>'
             '<rect y="56" width="64" height="8" fill="#41444d"/>')
    for y in (24, 40):   # marcas da fôrma de madeira
        b.append(f'<rect y="{y}" width="64" height="2.5" fill="#484b55"/>')
    for x, y in [(13, 31), (51, 31), (32, 48)]:   # pontas de vergalhão
        b.append(f'<circle cx="{x}" cy="{y}" r="4.6" fill="#b5703f"/><circle cx="{x}" cy="{y}" r="2" fill="#7a4526"/>')
    return block_doc(b)


def can_tabua():
    b = ['<rect x="-1" y="2" width="66" height="12" fill="#e2b265"/><rect x="-1" y="10.5" width="66" height="3.5" fill="#b07f3e"/>',
         '<rect x="-1" y="2" width="66" height="2" fill="#f2d398"/>',
         '<path d="M4,6.5 H22 M30,8 H50 M54,6 H62" stroke="#c4914d" stroke-width="1.2" stroke-linecap="round"/>',
         '<circle cx="6" cy="8" r="1.5" fill="#5a5d66"/><circle cx="58" cy="8" r="1.5" fill="#5a5d66"/>',
         '<rect x="28" y="2" width="8" height="12" fill="#e0a03c"/>',   # cinta de aço pintada
         hatch("pk", (0, 2, 64, 14), "#e2b265", 430, k=1.3, dark="#9e7036")]
    return wrap(64, 16, "".join(b), 430, 0.5).replace("<defs>", '<defs><clipPath id="pk"><rect y="2" width="64" height="12"/></clipPath>')


def can_fundo():
    rnd = random.Random(11)
    defs = ('<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#a8daee"/>'
            '<stop offset="0.6" stop-color="#cdebf0"/><stop offset="1" stop-color="#e4f2ea"/></linearGradient>') + rough("rough", 12, 2.2, 0.03)
    b = ['<rect width="1920" height="1080" fill="url(#sky)"/>', '<g filter="url(#rough)">']
    for x, y, s in [(140, 210, 1.5), (760, 130, 1.1), (1500, 250, 1.3), (1100, 380, 0.8)]:
        b.append(cloud(x, y, s, "#f6fbfb"))
    # cidade distante
    x = -20
    while x < 1940:
        w, h = rnd.uniform(90, 170), rnd.uniform(120, 260)
        b.append(f'<rect x="{x:.0f}" y="{820 - h:.0f}" width="{w:.0f}" height="{h + 100:.0f}" fill="#c4e0e6"/>')
        x += w + rnd.uniform(10, 40)
    # prédio em construção: esqueleto de concreto, andares com tijolo, vergalhões no topo
    bx, bw, col = 1120, 560, "#b2cfd6"
    floors = [880, 760, 640, 520, 400]
    for k, y in enumerate(floors):
        if k < 3:   # alvenaria nos andares de baixo
            for j in range(4):
                if not (k == 2 and j == 3):
                    b.append(f'<rect x="{bx + 20 + j * 135}" y="{y - 100}" width="120" height="100" fill="#cddfe0"/>')
                    if k < 2:
                        b.append(f'<rect x="{bx + 50 + j * 135}" y="{y - 78}" width="60" height="50" fill="#bdd6dc"/>')
        b.append(f'<rect x="{bx - 20}" y="{y}" width="{bw + 40}" height="22" fill="{col}"/>')
    for j in range(5):
        b.append(f'<rect x="{bx + j * 135}" y="{floors[-1]}" width="22" height="{1080 - floors[-1]}" fill="{col}"/>')
        b.append(f'<path d="M{bx + 6 + j * 135},{floors[-1]} v-50 M{bx + 16 + j * 135},{floors[-1]} v-60" stroke="{col}" stroke-width="5"/>')
    # andaime na lateral
    st = 'stroke="#c0d6da" stroke-width="7" fill="none"'
    b.append(f'<path d="M{bx + bw + 40},1080 V420 M{bx + bw + 110},1080 V420 ' +
             " ".join(f"M{bx + bw + 40},{y} H{bx + bw + 110}" for y in range(440, 1080, 110)) + f'" {st}/>')
    # guindaste de torre (amarelo bem desbotado)
    cr = "#d9e2cf"
    tx = 560
    b.append(lattice(tx, 1080, tx, 170, 16, cr, 44))
    b.append(lattice(tx - 260, 175, tx + 720, 175, 26, cr, 30))
    b.append(f'<path d="M{tx - 22},150 L{tx},60 L{tx + 22},150" stroke="{cr}" stroke-width="7" fill="none"/>'
             f'<path d="M{tx},62 L{tx - 250},162 M{tx},62 L{tx + 700},162" stroke="{cr}" stroke-width="4"/>'
             f'<rect x="{tx - 270}" y="186" width="90" height="60" fill="#cfdccb"/>'
             f'<rect x="{tx + 24}" y="190" width="52" height="44" fill="#cfdccb"/><rect x="{tx + 32}" y="198" width="26" height="20" fill="#eef3ee"/>')
    hx = tx + 520
    b.append(f'<path d="M{hx},190 V460 M{hx + 14},190 V460" stroke="#bfd2d2" stroke-width="3"/>'
             f'<rect x="{hx - 8}" y="190" width="30" height="16" fill="#cfdccb"/>'
             f'<path d="M{hx + 7},460 q-14,10 0,22 q10,6 12,-6" stroke="#bfd2d2" stroke-width="5" fill="none"/>'
             f'<path d="M{hx + 7},486 L{hx - 60},530 M{hx + 7},486 L{hx + 74},530" stroke="#bfd2d2" stroke-width="3"/>'
             f'<rect x="{hx - 70}" y="530" width="154" height="30" fill="#d8e4d8"/><rect x="{hx - 70}" y="552" width="154" height="8" fill="#c9d8cf"/>')
    # terreno: montes de areia e tapume
    b.append('<path d="M0,1080 V900 Q160,840 320,890 T700,880 Q900,830 1080,900 T1500,890 Q1700,850 1920,900 V1080 Z" fill="#e3e3c6"/>')
    b.append('<path d="M180,1080 Q300,900 430,1080 Z" fill="#ecdcb6"/><path d="M1720,1080 Q1800,960 1900,1080 Z" fill="#ecdcb6"/>')
    for x in range(0, 1920, 120):
        b.append(f'<rect x="{x + 6}" y="980" width="108" height="100" fill="#d9e6dc" opacity="0.8"/>')
    b.append('</g>')
    return doc(1920, 1080, "".join(b), defs)


# ================================================================== DEMOLIÇÃO (prédio velho)
def dem_bloco(i):
    rnd = random.Random(500 + i)
    if i == 0:   # reboco com papel de parede listrado e florzinha, canto descascado mostrando tijolo
        fill = "#8fbf9a"
        b = face(fill, "#5f8a6c", 500, dens=0.55)
        b.append('<g clip-path="url(#fc)">')
        for x in (10, 30, 50):
            b.append(f'<rect x="{x}" y="0" width="7" height="64" fill="#b5d6b4"/>')
        for x, y in [(20.5, 18), (40.5, 38), (20.5, 52), (40.5, 12)]:
            b.append("".join(f'<circle cx="{x + 3 * math.cos(a):.1f}" cy="{y + 3 * math.sin(a):.1f}" r="2" fill="#f0dfa6"/>'
                             for a in (0, 1.57, 3.14, 4.71)) + f'<circle cx="{x}" cy="{y}" r="1.5" fill="#c98a5a"/>')
        # descascado: reboco claro e tijolo por baixo
        b.append('<path d="M38,64 L40,52 L47,49 L50,42 L58,40 L64,34 V64 Z" fill="#e9dcc4"/>'
                 '<path d="M45,64 L47,56 L53,52 L64,47 V64 Z" fill="#b8694c"/>'
                 '<path d="M50,58 H64 M56,52 V58" stroke="#e2c7ad" stroke-width="1.5"/></g>')
        return block_doc(b)
    if i == 1:   # tijolo aparente velho com restos de reboco
        mortar = "#d9c6ae"
        b = [f'<rect width="64" height="64" fill="{mortar}"/>']
        for row in range(4):
            y, off = row * 16, (0 if row % 2 == 0 else -16)
            for col in range(3):
                x = off + col * 32
                tone = shade("#b06d50", rnd.uniform(-0.12, 0.06))
                b.append(f'<rect x="{x + 1.5}" y="{y + 1.5}" width="29" height="13" rx="2" fill="{tone}"/>'
                         f'<rect x="{x + 1.5}" y="{y + 1.5}" width="29" height="3" rx="1.5" fill="{shade(tone, 0.15)}"/>')
        b.append('<rect x="18" y="34" width="29" height="13" rx="2" fill="#5e3a35"/>')   # tijolo que falta
        b.append('<path d="M0,0 H26 Q24,8 16,9 Q10,16 0,14 Z" fill="#e9dcc4"/><path d="M64,22 Q54,24 52,30 Q56,36 64,35 Z" fill="#e9dcc4"/>')
        b.append(hatch("all", (0, 0, 64, 64), "#b06d50", 501, k=1.4, dens=0.5, dark="#6e3f30"))
        return block_doc(b)
    # azulejo 2x2 com motivo próprio (losango + pétalas), rejunte branco
    b = ['<rect width="64" height="64" fill="#f1ede2"/>']
    for r in range(2):
        for c in range(2):
            x, y = 2 + c * 31, 2 + r * 31
            cx, cy = x + 14.5, y + 14.5
            b.append(f'<rect x="{x}" y="{y}" width="29" height="29" rx="3" fill="#8ccfd0"/>'
                     f'<rect x="{x}" y="{y}" width="29" height="4" rx="2" fill="#b4e2e0"/>'
                     f'<path d="M{cx},{cy - 11} L{cx + 11},{cy} L{cx},{cy + 11} L{cx - 11},{cy} Z" fill="#2f6f95"/>'
                     f'<path d="M{cx},{cy - 6} L{cx + 6},{cy} L{cx},{cy + 6} L{cx - 6},{cy} Z" fill="#f6efd8"/>'
                     f'<circle cx="{cx}" cy="{cy}" r="2.2" fill="#e4a64a"/>')
            for qx, qy in [(x + 2, y + 2), (x + 27, y + 2), (x + 2, y + 27), (x + 27, y + 27)]:
                b.append(f'<path d="M{qx},{qy} m-0,0 l{5 if qx < cx else -5},0 l{-5 if qx < cx else 5},{5 if qy < cy else -5} Z" fill="#2f6f95"/>')
    b.append('<path d="M33,64 L33,33 L64,33 V64 Z" fill="#cfc6b6"/>')   # azulejo caído (reboco atrás)
    b.append('<path d="M36,62 L40,52 L38,44 L46,38 M52,62 L56,48 L62,44" stroke="#b3a894" stroke-width="2" fill="none" stroke-linecap="round"/>')
    b.append(hatch("all", (0, 0, 64, 64), "#8ccfd0", 502, k=1.4, dens=0.45, dark="#5d9ea2"))
    return block_doc(b)


def dem_fixo():
    b = base_block("#4e4d55", 520, "#34333b", "#6b6a73")
    b.append('<rect width="64" height="9" fill="#6c6b75"/><rect y="9" width="64" height="3" fill="#34333b"/><rect y="56" width="64" height="8" fill="#3c3b43"/>')
    # concreto armado quebrado: miolo mostrando a ferragem
    b.append('<path d="M14,20 L30,17 L48,22 L52,38 L44,50 L24,52 L12,40 Z" fill="#3a3940"/>')
    b.append('<path d="M10,26 H54 M10,40 H54 M22,14 V56 M40,14 V56" stroke="#a8643e" stroke-width="3.2" stroke-linecap="round"/>')
    b.append('<path d="M10,26 H54 M22,14 V56" stroke="#c98657" stroke-width="1.2" stroke-linecap="round"/>')
    return block_doc(b)


def dem_tabua():
    b = ['<rect x="-1" y="2" width="66" height="12" fill="#a8774f"/><rect x="-1" y="10.5" width="66" height="3.5" fill="#74502f"/>',
         '<rect x="-1" y="2" width="66" height="2" fill="#c99a6e"/>']
    for x in (0, 21, 43):   # tacos do assoalho
        b.append(f'<path d="M{x + 0.5},3 V13" stroke="#74502f" stroke-width="1.6"/>')
        b.append(f'<path d="M{x + 5},7 H{x + 16}" stroke="#bd8c60" stroke-width="1.1" stroke-linecap="round"/>')
    b.append('<circle cx="10" cy="8" r="1.4" fill="#4b4a52"/><circle cx="54" cy="8" r="1.4" fill="#4b4a52"/>')
    b.append(hatch("pk", (0, 2, 64, 14), "#a8774f", 530, k=1.3, dark="#6a4528"))
    return wrap(64, 16, "".join(b), 530, 0.6).replace("<defs>", '<defs><clipPath id="pk"><rect y="2" width="64" height="12"/></clipPath>')


def dem_fundo():
    rnd = random.Random(13)
    defs = ('<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#e6ddd2"/>'
            '<stop offset="0.6" stop-color="#efe4d4"/><stop offset="1" stop-color="#e8d9c6"/></linearGradient>') + rough("rough", 14, 2.2, 0.03)
    b = ['<rect width="1920" height="1080" fill="url(#sky)"/>', '<g filter="url(#rough)">']
    b.append('<circle cx="1640" cy="190" r="80" fill="#f6eedf"/>')   # sol fosco atrás da poeira
    # prédios distantes
    x = -30
    while x < 1950:
        w, h = rnd.uniform(110, 200), rnd.uniform(160, 300)
        b.append(f'<rect x="{x:.0f}" y="{860 - h:.0f}" width="{w:.0f}" height="{h + 100:.0f}" fill="#e0d3c6"/>')
        x += w + rnd.uniform(20, 60)
    # guindaste de demolição com a bola, à esquerda
    cr = "#cdbfb6"
    b.append(f'<rect x="120" y="830" width="260" height="90" rx="20" fill="{cr}"/><rect x="170" y="760" width="120" height="80" fill="{cr}"/>'
             f'<rect x="186" y="774" width="50" height="40" fill="#e9e0d4"/>')
    b.append(lattice(260, 800, 640, 210, 18, cr, 34))
    # garra de demolição (não uma bola: a arena Bola tem a bola de verdade e o fundo não pode imitar perigo)
    b.append(f'<path d="M640,210 V430" stroke="#c4b6ac" stroke-width="4" fill="none"/>'
             f'<rect x="618" y="428" width="44" height="26" rx="6" fill="#c2b3aa"/>'
             f'<path d="M622,450 L588,500 L604,548 L618,540 L608,506 L634,456 Z" fill="#c2b3aa"/>'
             f'<path d="M658,450 L692,500 L676,548 L662,540 L672,506 L646,456 Z" fill="#c2b3aa"/>')
    # prédio velho meio desmoronado (direita): fachada + cômodos expostos com papel de parede
    fx, fw, top = 900, 760, 260
    facade = (f"M{fx},1080 V{top} H{fx + 330} L{fx + 380},{top + 70} L{fx + 430},{top + 40} L{fx + 470},{top + 170} "
              f"L{fx + 560},{top + 220} L{fx + 610},{top + 340} L{fx + 700},{top + 380} L{fx + fw},{top + 470} V1080 Z")
    b.append(f'<clipPath id="fac"><path d="{facade}"/></clipPath><path d="{facade}" fill="#dccbbb"/><g clip-path="url(#fac)">')
    walls = ["#e6d3c8", "#d5dccb", "#e2d6bd", "#d6d0dc"]
    for k in range(5):   # andares
        y = top + 40 + k * 150
        for j in range(4):
            wx = fx + 30 + j * 180
            if j >= 2 and k <= 2 and (j + k) % 2 == 0:
                # cômodo exposto: papel de parede pastel com listras
                b.append(f'<rect x="{wx - 10}" y="{y - 10}" width="170" height="130" fill="{walls[(j + k) % 4]}"/>')
                for s in range(4):
                    b.append(f'<rect x="{wx + 10 + s * 40}" y="{y - 10}" width="12" height="130" fill="#efe4da" opacity="0.6"/>')
                b.append(f'<rect x="{wx + 40}" y="{y + 20}" width="50" height="40" fill="#ccbcae"/>')   # quadro na parede
            else:
                b.append(f'<rect x="{wx + 20}" y="{y + 10}" width="70" height="90" fill="#cbb8aa"/>'
                         f'<rect x="{wx + 20}" y="{y + 54}" width="70" height="5" fill="#dccbbb"/>')
        b.append(f'<rect x="{fx}" y="{y + 120}" width="{fw}" height="14" fill="#cfbeb0"/>')
    b.append('</g>')
    b.append(f'<path d="M{fx + 610},{top + 410} l90,-10 l-6,14 Z M{fx + 470},{top + 190} l70,4 l-4,14 Z" fill="#cfbeb0"/>')   # laje pendurada
    # entulho e poeira
    b.append('<path d="M0,1080 V960 Q120,920 240,950 Q380,900 520,940 Q700,890 860,950 Q1060,880 1240,930 Q1460,870 1640,930 Q1800,900 1920,940 V1080 Z" fill="#d6c6b6"/>')
    for k in range(40):
        x, y = rnd.uniform(0, 1920), rnd.uniform(940, 1060)
        s = rnd.uniform(10, 28)
        b.append(f'<rect x="{x:.0f}" y="{y:.0f}" width="{s * 1.6:.0f}" height="{s:.0f}" fill="#cbb9a8" transform="rotate({rnd.uniform(-30, 30):.0f} {x:.0f} {y:.0f})"/>')
    # nuvens de poeira (lobos redondos, base reta) subindo do desabamento
    for cx, cy, s in [(1560, 330, 1.6), (1760, 610, 1.3), (1250, 930, 1.8), (380, 960, 1.5)]:
        b.append(cloud(cx - 120 * s, cy, s, "#f3eadf", 0.75))
    for k in range(26):   # grãos de poeira caindo
        x, y = rnd.uniform(1250, 1900), rnd.uniform(250, 800)
        b.append(f'<circle cx="{x:.0f}" cy="{y:.0f}" r="{rnd.uniform(3, 7):.0f}" fill="#cdbcae" opacity="0.7"/>')
    b.append('</g>')
    return doc(1920, 1080, "".join(b), defs)


# ================================================================== VIADUTO (entardecer)
def via_bloco(i):
    rnd = random.Random(600 + i)
    if i == 0:   # concreto com faixa amarela tracejada (pista)
        fill = "#9ba5b8"
        b = face(fill, "#68718a", 600)
        b.append('<rect x="2" y="2" width="60" height="16" fill="#4f5266"/><rect x="2" y="2" width="60" height="4" fill="#666a80"/>')   # asfalto
        b.append('<rect x="8" y="9" width="22" height="5" rx="1.5" fill="#f2c94c"/><rect x="40" y="9" width="22" height="5" rx="1.5" fill="#f2c94c"/>')
        b.append(pebbles(rnd, 10, "#828ca0", (6, 24, 58, 54)))
        return block_doc(b)
    if i == 1:   # barreira: faixa diagonal laranja e creme
        fill = "#8f9ab0"
        b = face(fill, "#606a84", 601)
        b.append('<clipPath id="fx"><rect x="2" y="22" width="60" height="22"/></clipPath><rect x="2" y="22" width="60" height="22" fill="#f6ead2"/><g clip-path="url(#fx)">')
        for k in range(-2, 6):
            b.append(f'<path d="M{k * 16},44 L{k * 16 + 22},22 L{k * 16 + 30},22 L{k * 16 + 8},44 Z" fill="#ee8a3a"/>')
        b.append('</g><rect x="2" y="42" width="60" height="2.5" fill="#606a84"/>')
        b.append(pebbles(rnd, 5, "#7c869c", (6, 48, 58, 56)))
        return block_doc(b)
    # concreto com dreno, mancha de ferrugem e olho-de-gato
    fill = "#aab0b8"
    b = face(fill, "#737a88", 602)
    b.append('<circle cx="20" cy="22" r="7.5" fill="#5f564f"/><circle cx="20" cy="22" r="4.5" fill="#3f3940"/>')
    b.append('<path d="M15,28 Q14,42 18,58 H25 Q27,42 25,28 Z" fill="#b97b4e" opacity="0.75"/>')
    b.append('<rect x="38" y="30" width="16" height="10" rx="3" fill="#5f564f"/><rect x="41" y="32.5" width="10" height="5" rx="2" fill="#f2c94c"/>')
    b.append('<path d="M2,48 H62" stroke="#8a919e" stroke-width="2.5"/>')   # junta de dilatação
    b.append(pebbles(rnd, 6, "#929aa6", (32, 8, 58, 26)))
    return block_doc(b)


def via_fixo():
    b = base_block("#47424f", 620, "#2f2b37", "#635d6c")
    b.append('<rect width="64" height="12" fill="#6b6575"/><rect y="12" width="64" height="3" fill="#2f2b37"/><rect y="56" width="64" height="8" fill="#38343f"/>')
    for x in (10, 32, 54):   # chapa de apoio parafusada
        b.append(f'<circle cx="{x}" cy="6" r="2.6" fill="#a39cab"/>')
    b.append('<path d="M16,15 V56 M48,15 V56" stroke="#3a3643" stroke-width="5"/>')
    b.append('<rect x="22" y="28" width="20" height="16" rx="2" fill="#3a3643"/>')
    return block_doc(b)


def via_tabua():
    # guard-rail (lâmina em W) com parafusos
    b = ['<rect x="-1" y="2" width="66" height="12" fill="#c3c6cf"/>',
         '<rect x="-1" y="5" width="66" height="2.5" fill="#8e92a0"/><rect x="-1" y="9.5" width="66" height="2.5" fill="#8e92a0"/>',
         '<rect x="-1" y="2" width="66" height="2" fill="#eceef2"/><rect x="-1" y="12" width="66" height="2" fill="#6f7382"/>',
         '<circle cx="8" cy="8.2" r="1.5" fill="#55596a"/><circle cx="56" cy="8.2" r="1.5" fill="#55596a"/>',
         '<rect x="29" y="2" width="6" height="12" fill="#f2c94c"/>']   # refletor
    return wrap(64, 16, "".join(b), 630, 0.4)


def via_fundo():
    rnd = random.Random(17)
    defs = ('<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#bba8d8"/>'
            '<stop offset="0.3" stop-color="#e6bacb"/><stop offset="0.6" stop-color="#f8c99e"/><stop offset="1" stop-color="#f6d3b0"/></linearGradient>'
            ) + rough("rough", 18, 2.2, 0.03)
    b = ['<rect width="1920" height="1080" fill="url(#sky)"/>', '<g filter="url(#rough)">']
    hz = 690
    b.append(f'<circle cx="1180" cy="{hz - 120}" r="150" fill="#fde6b8"/>')
    for x, y, s in [(200, 260, 1.4), (1450, 180, 1.1), (700, 380, 0.9)]:
        b.append(cloud(x, y, s, "#f6d8d2", 0.8))
    # cidade em silhueta (2 camadas)
    for col, h0, h1 in [("#dcbac6", 130, 290), ("#cdacbf", 60, 170)]:
        x = -30
        while x < 1950:
            w, h = rnd.uniform(80, 170), rnd.uniform(h0, h1)
            b.append(f'<rect x="{x:.0f}" y="{hz - h:.0f}" width="{w:.0f}" height="{h:.0f}" fill="{col}"/>')
            if rnd.random() < 0.25:
                b.append(f'<path d="M{x + w / 2:.0f},{hz - h:.0f} v-60" stroke="{col}" stroke-width="5"/>')
            x += w + rnd.uniform(0, 30)
    # rio com reflexo do sol
    b.append(f'<rect x="0" y="{hz}" width="1920" height="{1080 - hz}" fill="#dcb9c6"/>')
    for k in range(12):
        y = hz + 18 + k * 30
        w = 260 - k * 14
        b.append(f'<rect x="{1180 - w / 2 + rnd.uniform(-30, 30):.0f}" y="{y}" width="{w}" height="7" rx="3.5" fill="#f6dcb6"/>')
        b.append(f'<path d="M{rnd.uniform(0, 300):.0f},{y + 12} h{rnd.uniform(80, 200):.0f} M{rnd.uniform(1500, 1800):.0f},{y + 6} h{rnd.uniform(60, 160):.0f}" stroke="#e8cad2" stroke-width="5" stroke-linecap="round"/>')
    # viaduto distante com pilares e arcos
    dc = "#cfa9bf"
    dy = hz - 70
    b.append(f'<rect x="-10" y="{dy}" width="1940" height="22" fill="{dc}"/><rect x="-10" y="{dy - 8}" width="1940" height="5" fill="{dc}"/>')
    for x in range(140, 1920, 360):
        b.append(f'<path d="M{x},{dy + 22} V{hz + 8} H{x + 30} V{dy + 22} Z" fill="{dc}"/>')
        b.append(f'<path d="M{x + 30},{dy + 22} Q{x + 195},{hz + 4} {x + 360},{dy + 22}" stroke="{dc}" stroke-width="8" fill="none"/>')
    for x in range(60, 1920, 180):   # postes de luz acesos
        b.append(f'<path d="M{x},{dy - 8} V{dy - 50} h14" stroke="{dc}" stroke-width="4" fill="none"/><circle cx="{x + 16}" cy="{dy - 48}" r="5" fill="#fde6b8"/>')
    # margem em primeiro plano
    b.append('<path d="M0,1080 V980 Q300,950 620,970 T1300,965 Q1640,945 1920,970 V1080 Z" fill="#d7b3b8"/>')
    for x in range(40, 1920, 260):   # juncos na margem
        b.append(f'<path d="M{x},975 q-6,-40 -16,-60 M{x + 10},975 q2,-50 8,-70 M{x + 20},975 q10,-30 22,-44" stroke="#c9a3ae" stroke-width="5" fill="none" stroke-linecap="round"/>')
    b.append('</g>')
    return doc(1920, 1080, "".join(b), defs)


TEMAS = {
    "concreto": (can_bloco, can_fixo, can_tabua, can_fundo),
    "demolicao": (dem_bloco, dem_fixo, dem_tabua, dem_fundo),
    "viaduto": (via_bloco, via_fixo, via_tabua, via_fundo),
}


def main():
    for nome, (bloco, fixo, tabua, fundo) in TEMAS.items():
        for i in range(3):
            queue(bloco(i), f"{SRC}/{nome}/bloco_{i}.svg", f"{OUT}/{nome}/bloco_{i}.png", 64, 64, K)
        queue(fixo(), f"{SRC}/{nome}/fixo.svg", f"{OUT}/{nome}/fixo.png", 64, 64, K)
        queue(tabua(), f"{SRC}/{nome}/tabua.svg", f"{OUT}/{nome}/tabua.png", 64, 16, K)
        queue(fundo(), f"{SRC}/{nome}/fundo.svg", f"{OUT}/{nome}/fundo.png", 1920, 1080, 2)
    print("temas_obra:", render_all())


if __name__ == "__main__":
    main()
