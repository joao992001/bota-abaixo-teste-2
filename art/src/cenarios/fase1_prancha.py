"""PRANCHA DE ARTE da Fase 1 do Derruba (Canteiro de Obras), as 2 etapas como "tela de jogo" para aprovar antes do código:
Etapa 1 TÉRREO (composição Ponte, manhã) e Etapa 2 FUNDAÇÃO (Bacia, subsolo). Catálogo: docs/fases/derruba/f1_canteiro.md.
Camadas: C0 céu/assinatura · C1 fundo distante vivo · C2 fundo próximo (NPCs, máquinas, placas) · C3 palco · C4 primeiro plano.
Reaproveita as peças do Canteiro atual (art/src/cenarios/canteiro_derruba.py) e os robôs do elenco (art/src/robos/elenco.py).
Rodar: python3 art/src/cenarios/fase1_prancha.py → art/out/fase1_etapa1.png, fase1_etapa2.png
"""
import math
import os
import random
import sys

HERE = os.path.dirname(__file__)
sys.path.insert(0, os.path.join(HERE, ".."))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "../robos"))
import canteiro_derruba as cd  # noqa: E402
import elenco as el  # noqa: E402
from papel import ellipse_d, rect_d, rough, shape  # noqa: E402
from svg import doc, queue, render_all, shade  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "../../.."))
SRC = os.path.join(ROOT, "art/src/cenarios/svg/fase1")
T = 64
W, H = 40 * T, 22 * T
INK = "#2a1a2e"
YEL, YEL_D = "#f2c84b", "#c49a2a"
ORANGE = "#f08a3d"
_id = [0]


def S(d, fill, box, k=2.4, **kw):
    _id[0] += 1
    return shape(f"f1s{_id[0]}", d, fill, 900 + _id[0], box, k=k, **kw)


def R(x, y, w, h, fill, r=4, k=2.4, **kw):
    return S(rect_d(x, y, w, h, r), fill, (x - 2, y - 2, x + w + 2, y + h + 2), k=k, **kw)


def E(cx, cy, rx, ry, fill, k=2.4, **kw):
    return S(ellipse_d(cx, cy, rx, ry), fill, (cx - rx - 2, cy - ry - 2, cx + rx + 2, cy + ry + 2), k=k, **kw)


def robot(cid, pose, col, x, y, s=1.05, flip=False):
    sx = -s if flip else s
    return f'<g transform="translate({x},{y}) scale({sx},{s})">{el.draw(cid, el.POSES[cid][pose], col)}</g>'


def npc(x, y, col, carry="", s=1.0, lamp=False):
    """Robô-operário de fundo (silhueta simples, cor dessaturada, capacete)."""
    b = [f'<g transform="translate({x},{y}) scale({s})">']
    b.append(f'<path d="M-6,0 L-5,-18 M6,0 L5,-18" stroke="{shade(col, -0.25)}" stroke-width="5" stroke-linecap="round"/>')
    b.append(f'<rect x="-11" y="-44" width="22" height="28" rx="7" fill="{col}"/>')
    b.append(f'<circle cx="0" cy="-52" r="10" fill="{col}"/>')
    b.append(f'<path d="M-11,-54 C-11,-66 11,-66 11,-54 Z" fill="{YEL if not lamp else "#e0b53a"}"/><rect x="-13" y="-55" width="26" height="3" fill="{YEL_D}"/>')
    b.append(f'<circle cx="5" cy="-51" r="2" fill="{INK}"/>')
    if lamp:
        b.append(f'<circle cx="0" cy="-62" r="3" fill="#fff4c8"/><path d="M2,-62 L60,-40 L60,-80 Z" fill="#fff4c8" opacity="0.18"/>')
    if carry == "tabua":
        b.append(f'<rect x="-34" y="-50" width="70" height="7" rx="2" fill="#c98a4b" transform="rotate(-8)"/>')
        b.append(f'<path d="M8,-36 L16,-48" stroke="{shade(col, -0.25)}" stroke-width="4" stroke-linecap="round"/>')
    elif carry == "carrinho":
        b.append(f'<path d="M10,-26 L34,-16" stroke="{shade(col, -0.25)}" stroke-width="4"/><path d="M28,-24 L58,-24 L52,-8 L32,-8 Z" fill="#8d98a4"/><circle cx="50" cy="-4" r="6" fill="{INK}"/>')
    b.append('</g>')
    return "".join(b)


def lattice(x0, y0, x1, y1, w, col, sw=5):
    """Treliça (mastro/lança de grua) entre dois pontos."""
    L = math.hypot(x1 - x0, y1 - y0)
    a = math.degrees(math.atan2(y1 - y0, x1 - x0))
    out = [f'<g transform="translate({x0},{y0}) rotate({a:.2f})" stroke="{col}" stroke-width="{sw}" stroke-linecap="round" fill="none">']
    out.append(f'<path d="M0,{-w / 2} H{L} M0,{w / 2} H{L}"/>')
    k = 0.0
    while k < L:
        out.append(f'<path d="M{k},{-w / 2} L{k + w},{w / 2} M{k + w},{-w / 2} L{k + w},{w / 2}"/>')
        k += w
    out.append('</g>')
    return "".join(out)


def cloud(cx, cy, s, col="#f6fbfb"):
    return (f'<path d="M{cx - 120 * s},{cy + 30 * s} C{cx - 120 * s},{cy - 10 * s} {cx - 60 * s},{cy - 20 * s} {cx - 40 * s},{cy - 10 * s} '
            f'C{cx - 20 * s},{cy - 60 * s} {cx + 60 * s},{cy - 60 * s} {cx + 70 * s},{cy - 10 * s} C{cx + 120 * s},{cy - 20 * s} {cx + 140 * s},{cy + 30 * s} {cx + 110 * s},{cy + 30 * s} Z" fill="{col}"/>')


def sign(x, y, txt, bg=YEL, fg=INK, w=120, h=44, tri=False):
    b = [f'<path d="M{x + w / 2},{y + h} V{y + h + 50}" stroke="#6b7783" stroke-width="5"/>']
    if tri:
        b.append(f'<path d="M{x + w / 2},{y} L{x + w},{y + h} L{x},{y + h} Z" fill="{bg}" stroke="{INK}" stroke-width="4" stroke-linejoin="round"/>')
        b.append(f'<text x="{x + w / 2}" y="{y + h - 8}" font-family="Fredoka, Arial" font-weight="700" font-size="{h * 0.55}" fill="{fg}" text-anchor="middle">!</text>')
    else:
        b.append(R(x, y, w, h, bg, 6, 1.6))
        b.append(f'<text x="{x + w / 2}" y="{y + h * 0.68}" font-family="Fredoka, Arial" font-weight="700" font-size="{h * 0.45}" fill="{fg}" text-anchor="middle">{txt}</text>')
    return "".join(b)


# ================================================================ ETAPA 1 — TÉRREO
GROUND_Y = 17 * T          # chão dos lados (térreo)
LAJE_Y = 13 * T


def e1_sky(clouds=True, birds=True):
    b = ['<defs><linearGradient id="sk1" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#7fd0e2"/><stop offset="0.65" stop-color="#cdeef0"/>'
         '<stop offset="1" stop-color="#fbeed2"/></linearGradient>'
         '<radialGradient id="sun1"><stop offset="0" stop-color="#fff6d0"/><stop offset="1" stop-color="#fff6d0" stop-opacity="0"/></radialGradient>'
         '<linearGradient id="nv1" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#e9f5f2" stop-opacity="0"/><stop offset="1" stop-color="#e3eeea"/></linearGradient></defs>',
         f'<rect width="{W}" height="{H}" fill="url(#sk1)"/>', f'<circle cx="420" cy="230" r="300" fill="url(#sun1)"/>', '<circle cx="420" cy="230" r="70" fill="#fff3c4"/>']
    for (cx, cy, s) in ((760, 180, 1.1), (1500, 120, 0.8), (2250, 210, 1.2), (1150, 330, 0.55), (200, 420, 0.6)):
        if clouds:
            b.append(cloud(cx, cy, s))
    for (x, y) in (((980, 300), (1010, 285), (1040, 305), (1820, 380), (1850, 370)) if birds else ()):   # pássaros
        b.append(f'<path d="M{x - 10},{y} q5,-7 10,0 q5,-7 10,0" stroke="#5a7a86" stroke-width="3" fill="none"/>')
    return "".join(b)


def e1_far():
    rnd = random.Random(11)
    b = []
    x = -20
    while x < W:   # cidade com janelas
        bw, bh = rnd.uniform(90, 200), rnd.uniform(240, 560)
        top = GROUND_Y - 120 - bh
        b.append(f'<rect x="{x:.0f}" y="{top:.0f}" width="{bw:.0f}" height="{bh + 400:.0f}" fill="#b2dde2"/>')
        for wy in range(int(top + 24), int(GROUND_Y - 120), 34):
            for wx in range(int(x + 14), int(x + bw - 18), 28):
                if rnd.random() < 0.7:
                    b.append(f'<rect x="{wx}" y="{wy}" width="12" height="16" fill="#c8e8ec"/>')
        x += bw + rnd.uniform(14, 40)
    # 2ª grua (distante, azulada)
    b.append(lattice(300, GROUND_Y - 80, 300, 300, 28, "#9fcbd2", 4) + lattice(120, 300, 620, 300, 22, "#9fcbd2", 4))
    b.append(f'<path d="M560,300 V430" stroke="#9fcbd2" stroke-width="3"/><rect x="540" y="430" width="40" height="26" fill="#9fcbd2"/>')
    return "".join(b)


def e1_building(live=True):
    """Prédio em construção (C1/C2): pilares, lajes, tela de proteção, andaime na fachada, solda piscando, operários."""
    x0, x1, top = 1260, 1960, 360
    b = []
    for c in range(6):
        b.append(f'<rect x="{x0 + c * 136}" y="{top}" width="20" height="{GROUND_Y - top}" fill="#9cc4ca"/>')
    for r in range(6):
        y = top + r * 120
        b.append(f'<rect x="{x0 - 20}" y="{y}" width="{x1 - x0 + 40}" height="18" fill="#8fb8bf"/>')
    b.append(f'<rect x="{x0 + 136}" y="{top + 120}" width="400" height="120" fill="#7fbf8e" opacity="0.35"/>')   # tela verde
    b.append(f'<rect x="{x0 + 408}" y="{top + 360}" width="270" height="120" fill="#f08a3d" opacity="0.3"/>')    # tela laranja
    for k in range(10):
        b.append(f'<path d="M{x0 + 136 + k * 40},{top + 120} V{top + 240}" stroke="#ffffff" stroke-width="1.5" opacity="0.4"/>')
    for (sx, sy) in (((x0 + 300, top + 230), (x0 + 560, top + 470), (x0 + 220, top + 590)) if live else ()):   # solda piscando
        b.append(f'<circle cx="{sx}" cy="{sy}" r="22" fill="#fff4c8" opacity="0.45"/><circle cx="{sx}" cy="{sy}" r="7" fill="#ffffff"/>')
        for a in range(0, 360, 60):
            b.append(f'<path d="M{sx},{sy} l{12 * math.cos(math.radians(a)):.1f},{12 * math.sin(math.radians(a)):.1f}" stroke="#fff4c8" stroke-width="2"/>')
    if live:
        b.append(npc(x0 + 420, top + 120, "#8fb2a8", "tabua", 0.8))
        b.append(npc(x0 + 640, top + 360, "#a99ab8", "", 0.8))
    b.append(lattice(x1 + 30, GROUND_Y, x1 + 30, top - 20, 22, "#86aab0", 3))   # andaime de fachada
    return "".join(b)


def e1_grua(hook=True):
    """ASSINATURA: grua amarela gigante, lança sobre a cena, contrapeso, carrinho com balde de concreto (G05/V1)."""
    mx = 2230
    b = [lattice(mx, GROUND_Y + 40, mx, 150, 46, "#e7b941", 6)]
    b.append(lattice(mx - 1500, 150, mx + 300, 150, 34, "#e7b941", 5))
    b.append(f'<path d="M{mx},{60} L{mx - 1500},{150} M{mx},{60} L{mx + 300},{150}" stroke="#d2a32f" stroke-width="5"/>')
    b.append(R(mx - 40, 110, 80, 70, "#e7b941", 6, 2))   # cabine
    b.append(f'<rect x="{mx - 26}" y="122" width="40" height="26" rx="4" fill="#cdeff7"/>')
    b.append(R(mx + 180, 160, 120, 90, "#9aa4ae", 6, 2))  # contrapeso
    b.append(f'<path d="M{mx + 190},{205} h100" stroke="{INK}" stroke-width="4" opacity="0.4"/>')
    hx = 900   # carrinho + cabo + balde
    if not hook:
        hx = -9999
    b.append(R(hx - 30, 160, 60, 24, "#c49a2a", 4, 1.6))
    b.append(f'<path d="M{hx},{184} V{430}" stroke="#3a3a46" stroke-width="4"/>')
    b.append(S(f"M{hx - 34},{440} L{hx + 34},{440} L{hx + 20},{500} L{hx - 20},{500} Z", "#8d98a4", (hx - 36, 438, hx + 36, 502), k=1.6))
    b.append(f'<path d="M{hx - 34},{440} L{hx},{428} L{hx + 34},{440}" stroke="#3a3a46" stroke-width="3" fill="none"/>')
    b.append(f'<circle cx="{hx}" cy="{428}" r="6" fill="{ORANGE}"/>')
    # bandeirolas da lança
    for k in range(14):
        fx = mx - 1450 + k * 100
        b.append(f'<path d="M{fx},{168} l18,0 l-9,22 Z" fill="{[ORANGE, YEL, "#3fc1c9"][k % 3]}"/>')
    return "".join(b)


def e1_ground_props():
    """C2 no nível do térreo: tapume com placas, contêiner-escritório, banheiro químico, areia, tijolos, cones,
    caminhão betoneira, operários (carregando tábua, empurrando carrinho)."""
    b = []
    # tapume ao fundo (os dois lados)
    for (x0, x1) in ((0, 520), (2040, W)):
        b.append(R(x0, GROUND_Y - 150, x1 - x0, 150, "#e9ecef", 0, 2, dark="#c9ced3"))
        for x in range(int(x0), int(x1), 64):
            b.append(f'<path d="M{x},{GROUND_Y - 150} V{GROUND_Y}" stroke="#c9ced3" stroke-width="3"/>')
        b.append(f'<rect x="{x0}" y="{GROUND_Y - 40}" width="{x1 - x0}" height="14" fill="{ORANGE}"/>')
    # faixa da construtora pendurada no prédio (C1) + operário empurrando carrinho no fundo
    b.append(f'<path d="M1300,600 V560 M1780,600 V560" stroke="#6b7783" stroke-width="4"/>')
    b.append(R(1280, 600, 520, 76, "#3c9a46", 6, 1.8, dark="#25682d"))
    b.append(f'<text x="1540" y="652" font-family="Fredoka, Arial" font-weight="700" font-size="34" fill="#ffffff" text-anchor="middle">CONSTRUTORA <tspan fill="{YEL}">BOTA-ABAIXO</tspan></text>')
    b.append(npc(1120, LAJE_Y - 6, "#9fb9c0", "carrinho", 0.6))
    b.append(npc(1900, LAJE_Y - 6, "#b4a9c4", "tabua", 0.6))
    return "".join(b)


def betoneira(x, y):
    """M1 — betoneira: tambor laranja listrado girando, bica despejando concreto numa faixa marcada."""
    b = [R(x - 60, y - 40, 150, 34, "#6b7783", 6, 1.8, dark="#4d5a6e")]
    for wx in (x - 40, x + 60):
        b.append(E(wx, y - 6, 16, 16, INK, 1.2) + f'<circle cx="{wx}" cy="{y - 6}" r="6" fill="#9aa4ae"/>')
    b.append(S(f"M{x - 50},{y - 50} C{x - 70},{y - 110} {x - 20},{y - 160} {x + 40},{y - 150} L{x + 90},{y - 100} C{x + 70},{y - 60} {x + 20},{y - 40} {x - 50},{y - 50} Z",
               ORANGE, (x - 72, y - 162, x + 92, y - 38), k=2.2, dark="#b05a20"))
    for k in range(3):
        b.append(f'<path d="M{x - 40 + k * 34},{y - 140 + k * 6} C{x - 20 + k * 34},{y - 110} {x - 30 + k * 34},{y - 70} {x - 44 + k * 34},{y - 52}" stroke="#ffd08a" stroke-width="7" fill="none"/>')
    b.append(f'<path d="M{x + 88},{y - 104} L{x + 140},{y - 66}" stroke="#6b7783" stroke-width="12" stroke-linecap="round"/>')
    b.append(f'<path d="M{x + 140},{y - 66} C{x + 150},{y - 40} {x + 140},{y - 20} {x + 150},{y}" stroke="#b9b2a6" stroke-width="16" fill="none" stroke-linecap="round"/>')
    b.append(E(x + 175, y - 4, 70, 9, "#b9b2a6", 1.4))   # concreto fresco no chão
    b.append(cd.zebra(x + 105, y + 2, 140, 8))
    b.append(R(x + 20, y - 34, 26, 18, YEL, 3, 1.0) + f'<rect x="{x + 28}" y="{y - 30}" width="10" height="10" fill="#d94a3a"/>')   # alavanca/botão
    return "".join(b)


def esteira(x, y, w):
    """M3 — esteira de entulho levando para fora (setas piscando, botão de inverter)."""
    b = [R(x, y - 26, w, 26, "#3e4752", 12, 1.8, dark="#252b33")]
    for k in range(int(w // 28)):
        b.append(f'<rect x="{x + 6 + k * 28}" y="{y - 24}" width="16" height="4" fill="#71829a"/>')
    for k in range(4):
        ax = x + 40 + k * (w - 60) / 4
        b.append(f'<path d="M{ax + 14},{y - 20} l-16,7 l16,7 Z" fill="{YEL}"/>')
    for wx in (x + 14, x + w - 14):
        b.append(f'<circle cx="{wx}" cy="{y - 13}" r="11" fill="#71829a"/><circle cx="{wx}" cy="{y - 13}" r="4" fill="{INK}"/>')
    for (cx, s) in ((x + 70, 1), (x + 150, 0.7)):   # entulho em cima
        b.append(f'<rect x="{cx}" y="{y - 26 - 18 * s}" width="{26 * s}" height="{18 * s}" fill="#a1988a" transform="rotate(12 {cx} {y - 26})"/>')
    b.append(R(x + w + 10, y - 60, 30, 60, "#6b7783", 4, 1.4) + f'<circle cx="{x + w + 25}" cy="{y - 46}" r="9" fill="#d94a3a"/>')
    return "".join(b)


def elevador(x, top, bottom, py):
    """M2 — elevador de obra: torre de cremalheira, cabine-plataforma, luz giratória."""
    b = [lattice(x, bottom, x, top, 30, "#8d98a4", 4)]
    b.append(f'<path d="M{x - 6},{top} V{bottom}" stroke="#c9d1d8" stroke-width="4" stroke-dasharray="6 6"/>')
    b.append(R(x - 150, py, 140, 20, YEL, 4, 2, dark=YEL_D))
    b.append(f'<path d="M{x - 150},{py} V{py - 70} H{x - 10} V{py}" stroke="#6b7783" stroke-width="5" fill="none"/>')
    for k in range(4):
        b.append(f'<path d="M{x - 140 + k * 36},{py - 66} V{py - 2}" stroke="#6b7783" stroke-width="2"/>')
    b.append(f'<circle cx="{x - 80}" cy="{py - 82}" r="10" fill="{ORANGE}"/><path d="M{x - 80},{py - 82} L{x - 30},{py - 120} L{x - 20},{py - 96} Z" fill="#ffd08a" opacity="0.5"/>')
    b.append(cd.zebra(x - 150, py + 20, 140, 8))
    return "".join(b)


def tubos(x, y):
    """E6/M4 — pilha de tubos de concreto com cunha (marretar solta)."""
    b = []
    for (cx, cy) in ((x, y - 38), (x + 78, y - 38), (x + 156, y - 38), (x + 39, y - 104), (x + 117, y - 104), (x + 78, y - 170)):
        b.append(E(cx, cy, 38, 38, "#c4beb2", 2, dark="#9e9789") + f'<circle cx="{cx}" cy="{cy}" r="22" fill="#7d776c"/><circle cx="{cx}" cy="{cy}" r="17" fill="#5a554d"/>')
    b.append(f'<path d="M{x + 200},{y} L{x + 230},{y} L{x + 200},{y - 30} Z" fill="{YEL}" stroke="{INK}" stroke-width="2"/>')
    return "".join(b)


def passarela(x0, x1, y):
    """E7 + M5 — passarela de tábuas com a serra de bancada no meio."""
    b = []
    for k, x in enumerate(range(int(x0), int(x1), 40)):
        b.append(R(x, y + (2 if k % 2 else 0), 38, 14, "#d9a05e", 2, 1.4, dark="#8f5a2c"))
    b.append(f'<path d="M{x0},{y - 34} H{x1} M{x0},{y - 17} H{x1}" stroke="{YEL}" stroke-width="4"/>')
    for x in range(int(x0), int(x1) + 1, 80):
        b.append(f'<path d="M{x},{y} V{y - 36}" stroke="#8f5a2c" stroke-width="4"/>')
    sx = (x0 + x1) / 2
    b.append(R(sx - 46, y - 30, 92, 30, "#4a5566", 4, 1.6))
    b.append(E(sx, y - 30, 30, 30, "#c9d1d8", 1.6, dark="#8d98a4"))
    for a in range(0, 360, 30):
        r = math.radians(a)
        b.append(f'<path d="M{sx + 26 * math.cos(r):.1f},{y - 30 + 26 * math.sin(r):.1f} L{sx + 34 * math.cos(r + 0.15):.1f},{y - 30 + 34 * math.sin(r + 0.15):.1f}" stroke="#8d98a4" stroke-width="5"/>')
    b.append(f'<circle cx="{sx}" cy="{y - 30}" r="6" fill="{INK}"/>')
    for a in (-150, -120, -60):
        r = math.radians(a)
        b.append(f'<path d="M{sx + 30 * math.cos(r):.1f},{y - 30 + 30 * math.sin(r):.1f} l{14 * math.cos(r):.1f},{14 * math.sin(r):.1f}" stroke="#ffd36b" stroke-width="3"/>')
    return "".join(b)


def escada(x, y0, y1):
    """E8 — escada de marinheiro presa embaixo da laje (rota de volta)."""
    b = [f'<path d="M{x},{y0} V{y1} M{x + 26},{y0} V{y1}" stroke="#6b7783" stroke-width="6"/>']
    for yy in range(int(y0) + 18, int(y1), 26):
        b.append(f'<path d="M{x},{yy} h26" stroke="#8d98a4" stroke-width="5"/>')
    return "".join(b)


def e1_stage():
    b = []
    ly = LAJE_Y
    # vão central: névoa + um pouco da fundação lá embaixo (prenuncia a virada)
    b.append(f'<rect x="512" y="{ly + 2 * T}" width="{2048 - 512}" height="{H - ly}" fill="url(#nv1)"/>')
    b.append(f'<rect x="512" y="{H - 90}" width="{2048 - 512}" height="90" fill="#5d6b7d" opacity="0.35"/>')
    for col in (17, 22):
        b.append(cd.pilar_body(col * T + 8, ly + 2 * T - 4, 2 * T - 16, H - ly, 300 + col))
    for i, sx in enumerate(cd.SEG_X):
        if i not in cd.NUCLEO:
            b.append(cd.escora_body(sx * T, ly + 2 * T - 6, H - ly - 2 * T + 6, 320 + i))
    # chão dos lados (térreo)
    for (x0, x1) in ((0, 512), (2048, W)):
        b.append(R(x0, GROUND_Y, x1 - x0, H - GROUND_Y, "#b9ab8f", 0, 3, dark="#958a72"))
        b.append(f'<rect x="{x0}" y="{GROUND_Y}" width="{x1 - x0}" height="12" fill="#d9ccb0"/>')
        for k in range(int((x1 - x0) // 70)):
            b.append(f'<circle cx="{x0 + 30 + k * 70}" cy="{GROUND_Y + 40 + (k % 3) * 18}" r="4" fill="#958a72"/>')
    # andaimes (chegam no chão do térreo)
    for (c, r, wd) in ((3, 10, 5), (32, 10, 5)):
        b.append(cd.andaime_body(c * T, r * T, wd * T, GROUND_Y - r * T, 400 + c))
    # vigas penduradas
    b.append(cd.viga_body(16 * T, 8 * T, 8 * T, 500))
    for (vc, vr, vw) in ((10, 11, 4), (26, 11, 4), (9, 5, 4), (27, 5, 4)):
        b.append(cd.viga_body(vc * T, vr * T, vw * T, 510 + vc))
    # laje: estados variados (meio da rodada)
    states = [1, 0, 0, 0, 2, 0]
    for i, sx in enumerate(cd.SEG_X):
        b.append(cd.laje_body(sx * T, ly, 4 * T, 2 * T, states[i], 60 + i, f"e1lj{i}"))
    for col in (17, 22):
        b.append(f'<rect x="{col * T + 30}" y="{ly + 2 * T + 30}" width="60" height="34" rx="4" fill="{YEL}"/><path d="M{col * T + 40},{ly + 2 * T + 47} h40" stroke="{INK}" stroke-width="4"/>')
    b.append(escada(cd.SEG_X[2] * T - 40, ly + 2 * T, ly + 2 * T + 300))
    b.append(escada(cd.SEG_X[4] * T + 14, ly + 2 * T, ly + 2 * T + 300))
    # mecanismos
    b.append(esteira(216, GROUND_Y, 250))
    b.append(betoneira(70, GROUND_Y))
    b.append(tubos(2130, GROUND_Y))
    b.append(elevador(2520, 9 * T, GROUND_Y, 12 * T + 20))
    b.append(sign(290, GROUND_Y - 300, "USE EPI", w=110, h=40))
    b.append(sign(2400, GROUND_Y - 120, "", tri=True, w=60, h=52))
    for cx in (560, 2010):
        b.append(f'<path d="M{cx - 14},{LAJE_Y} L{cx},{LAJE_Y - 40} L{cx + 14},{LAJE_Y} Z" fill="{ORANGE}"/><rect x="{cx - 9}" y="{LAJE_Y - 26}" width="18" height="6" fill="#ffffff"/>')
    b.append(passarela(8 * T, 10 * T + 40, 10 * T))
    # caixa de spell no núcleo
    b.append(f'<g transform="translate({20 * T - 48},{ly - 96}) scale(1)"><rect x="0" y="0" width="96" height="96" fill="none"/></g>')
    return "".join(b)


def e1_actors():
    b = [robot("marretao", "pesado_prep", el.COLORS[0], 1150, LAJE_Y),
         robot("picareta", "rapido", el.COLORS[1], 1340, LAJE_Y, flip=True),
         robot("chave", "parado", el.COLORS[2], 2180, 10 * T),
         robot("britadeira", "esquiva", el.COLORS[3], 1560, 8 * T)]
    # rastro e poeira no pulo
    b.append(f'<path d="M1500,{8 * T - 40} h-60 M1505,{8 * T - 25} h-50" stroke="#ffffff" stroke-width="5" stroke-linecap="round" opacity="0.8"/>')
    # pedaço caindo do trecho crítico + pedrinhas
    for (x, y, r) in ((1660, 1010, 20), (1720, 1120, -30), (1600, 1180, 50)):
        b.append(f'<rect x="{x}" y="{y}" width="44" height="26" fill="#cbc2b1" transform="rotate({r} {x} {y})" stroke="#a1988a" stroke-width="2"/>')
    return "".join(b)


def e1_front():
    # viga I de aço no primeiro plano (canto de cima), desfocada e escura
    b = [f'<g transform="translate(-60,40) rotate(-12)" opacity="0.85"><rect x="0" y="0" width="560" height="22" fill="#3a3f4a"/>'
         f'<rect x="0" y="22" width="560" height="26" fill="#4a5060"/><rect x="0" y="48" width="560" height="22" fill="#3a3f4a"/>']
    for k in range(7):
        b.append(f'<circle cx="{40 + k * 76}" cy="35" r="6" fill="#6b7380"/>')
    b.append('</g>')
    b.append(f'<path d="M{W - 260},0 V120" stroke="{INK}" stroke-width="3"/>' + R(W - 300, 120, 80, 44, YEL, 8, 1.4) + f'<circle cx="{W - 260}" cy="180" r="40" fill="#fff4c8" opacity="0.35"/>')
    b.append(f'<path d="M{W - 640},{H} q120,-60 240,-20 q120,40 400,-30" stroke="{YEL}" stroke-width="16" fill="none" opacity="0.9"/>')
    b.append(f'<path d="M{W - 640},{H} q120,-60 240,-20 q120,40 400,-30" stroke="{INK}" stroke-width="16" fill="none" stroke-dasharray="14 18" opacity="0.9"/>')
    rnd = random.Random(5)
    for _ in range(40):   # poeira no ar
        b.append(f'<circle cx="{rnd.uniform(0, W):.0f}" cy="{rnd.uniform(300, H):.0f}" r="{rnd.uniform(2, 5):.1f}" fill="#ffffff" opacity="0.5"/>')
    return "".join(b)


def etapa1():
    body = e1_sky() + e1_far() + e1_grua() + e1_building() + e1_ground_props() + e1_stage() + e1_actors() + e1_front()
    return doc(W, H, f'<g filter="url(#rough)">{body}</g>', rough(seed=21, scale=0.8, freq=0.05))


# ================================================================ ETAPA 2 — FUNDAÇÃO
FLOOR = 18 * T + 20
HOLE = (880, 1680)


def e2_back():
    b = ['<defs><linearGradient id="sk2" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#2c3644"/><stop offset="1" stop-color="#1e2530"/></linearGradient>'
         '<linearGradient id="ray" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff2c4" stop-opacity="0.35"/><stop offset="1" stop-color="#fff2c4" stop-opacity="0"/></linearGradient>'
         '<radialGradient id="lamp"><stop offset="0" stop-color="#ffe7a8" stop-opacity="0.55"/><stop offset="1" stop-color="#ffe7a8" stop-opacity="0"/></radialGradient></defs>',
         f'<rect width="{W}" height="{H}" fill="url(#sk2)"/>']
    # C0: o buraco no teto com o céu e a grua lá em cima
    b.append(f'<rect x="{HOLE[0]}" y="0" width="{HOLE[1] - HOLE[0]}" height="160" fill="#bfe8f0"/>')
    b.append(cloud(1150, 70, 0.6))
    b.append(lattice(HOLE[0] - 40, 40, HOLE[1] + 40, 40, 18, "#e7b941", 4))
    b.append(f'<path d="M1420,40 V150" stroke="#3a3a46" stroke-width="3"/><rect x="1404" y="150" width="32" height="18" fill="#8d98a4"/>')
    # C1: galerias em arco com lanternas ao longe, canos
    for (x, w) in ((240, 260), (2060, 260)):
        b.append(f'<path d="M{x},{FLOOR - 40} V{560} q{w / 2},-150 {w},0 V{FLOOR - 40} Z" fill="#161b23"/>')
        b.append(f'<circle cx="{x + w * 0.4}" cy="{FLOOR - 200}" r="5" fill="#fff4c8"/><circle cx="{x + w * 0.4}" cy="{FLOOR - 200}" r="40" fill="url(#lamp)"/>')
        b.append(npc(x + w * 0.4, FLOOR - 120, "#55606e", "", 0.5, lamp=True))
    for y, col in ((300, "#7a4a2e"), (360, "#5d6b7d")):
        b.append(f'<path d="M0,{y} H{W}" stroke="{col}" stroke-width="30"/>')
        for x in range(120, W, 340):
            b.append(f'<rect x="{x}" y="{y - 22}" width="20" height="44" fill="#3a3a46"/>')
    # feixes de luz do buraco (com poeira)
    for k in range(5):
        x = HOLE[0] + 80 + k * 150
        b.append(f'<path d="M{x},160 L{x + 60},160 L{x - 160 + k * 40},{FLOOR} L{x - 260 + k * 40},{FLOOR} Z" fill="url(#ray)"/>')
    rnd = random.Random(3)
    for _ in range(60):
        b.append(f'<circle cx="{rnd.uniform(HOLE[0] - 200, HOLE[1]):.0f}" cy="{rnd.uniform(180, FLOOR):.0f}" r="{rnd.uniform(1.5, 4):.1f}" fill="#fff4c8" opacity="0.5"/>')
    # teto de concreto com bordas quebradas e ferros
    b.append(R(0, 0, HOLE[0], 160, "#4a5566", 0, 2.6, dark="#323a46"))
    b.append(R(HOLE[1], 0, W - HOLE[1], 160, "#4a5566", 0, 2.6, dark="#323a46"))
    for x0, sgn in ((HOLE[0], 1), (HOLE[1], -1)):
        b.append(f'<path d="M{x0},0 L{x0 + sgn * 30},60 L{x0 - sgn * 10},100 L{x0 + sgn * 40},160 L{x0 - sgn * 20},160 Z" fill="#4a5566"/>')
        for k in range(4):
            b.append(f'<path d="M{x0},{30 + k * 30} q{sgn * 30},10 {sgn * 50},-5" stroke="#b0562e" stroke-width="4" fill="none"/>')
    # placas
    b.append(sign(560, FLOOR - 470, "ALAGA!", "#4f86a8", "#ffffff", 120, 40))
    b.append(sign(1980, FLOOR - 520, "", tri=True, w=70, h=60))
    # ratinhos-robô
    for x in (700, 1890):
        b.append(f'<ellipse cx="{x}" cy="{FLOOR - 6}" rx="14" ry="8" fill="#8d98a4"/><circle cx="{x + 12}" cy="{FLOOR - 10}" r="2" fill="#d94a3a"/><path d="M{x - 14},{FLOOR - 6} q-14,-6 -20,4" stroke="#8d98a4" stroke-width="2" fill="none"/>')
    return "".join(b)


def bate_estaca(x, y_top, floor):
    """M6 — bate-estaca gigante preso no teto: torre amarela, martelo erguido, sombra listrada no chão."""
    b = [lattice(x, y_top, x, floor - 260, 40, "#e7b941", 5)]
    b.append(R(x - 60, floor - 300, 120, 80, "#6b7783", 8, 2, dark="#4d5a6e"))
    b.append(f'<rect x="{x - 60}" y="{floor - 236}" width="120" height="14" fill="{YEL}"/>')
    b.append(cd.zebra(x - 60, floor - 236, 120, 14))
    b.append(f'<path d="M{x},{floor - 220} V{floor - 40}" stroke="#c9d1d8" stroke-width="10" stroke-dasharray="4 16" opacity="0.6"/>')
    b.append(E(x, floor - 4, 80, 10, "#000000", 1.0) .replace('fill="#000000"', 'fill="#000000" fill-opacity="0.3"'))
    b.append(f'<rect x="{x - 70}" y="{floor - 6}" width="140" height="8" fill="#d94a3a" opacity="0.8"/>')
    return "".join(b)


def e2_stage():
    b = []
    # paredes de contenção + escadas (E17)
    for (x0, w) in ((0, 200), (W - 200, 200)):
        b.append(R(x0, 260, w, H - 260, "#5d6b7d", 0, 3, dark="#454f5c"))
        for yy in range(300, H, 120):
            b.append(f'<path d="M{x0},{yy} H{x0 + w}" stroke="#454f5c" stroke-width="4"/>')
        for k in range(10):   # régua do nível da água (M7)
            b.append(f'<rect x="{x0 + (w - 40 if x0 == 0 else 14)}" y="{FLOOR - 40 - k * 24}" width="26" height="4" fill="#9fe3f5"/>')
    rnd = random.Random(8)
    for (x0, w) in ((0, 200), (W - 200, 200)):   # manchas de umidade, musgo, placas de aço e parafusos
        for k in range(4):   # escorridos de umidade (verticais)
            sx = x0 + 30 + k * 40
            sy = rnd.uniform(280, 700)
            b.append(f'<path d="M{sx},{sy:.0f} q8,{rnd.uniform(120, 260):.0f} -2,{rnd.uniform(260, 420):.0f} h14 q-6,-200 2,-{rnd.uniform(300, 420):.0f} Z" fill="#3f4855" opacity="0.55"/>')
        b.append(R(x0 + 30, 520, w - 60, 90, "#6b7783", 4, 1.6) + "".join(f'<circle cx="{x0 + 44 + j * 36}" cy="534" r="4" fill="#9aa4ae"/>' for j in range(4)))
        b.append(f'<path d="M{x0 + 40},{FLOOR - 60} q30,-30 60,0 q20,20 50,0" stroke="#4f7a52" stroke-width="10" fill="none" opacity="0.8"/>')
        b.append(f'<path d="M{x0 + w * 0.3},{300} l20,60 l-14,50 l24,70" stroke="#2c333d" stroke-width="4" fill="none"/>')
    b.append(escada(210, 300, FLOOR))
    b.append(escada(W - 236, 300, FLOOR))
    # piso + grelha do poço (E11/E12)
    b.append(R(200, FLOOR, W - 400, H - FLOOR, "#7d8896", 0, 3, dark="#5d6878"))
    b.append(f'<rect x="200" y="{FLOOR}" width="{W - 400}" height="10" fill="#9aa4ae"/>')
    for k in range(int((W - 400) // 180)):   # juntas, manchas, entulho e ferros no piso
        x = 240 + k * 180
        b.append(f'<path d="M{x},{FLOOR + 10} V{H}" stroke="#5d6878" stroke-width="3"/>')
        b.append(f'<ellipse cx="{x + 80}" cy="{FLOOR + 80 + (k % 3) * 40}" rx="{50 + (k % 2) * 30}" ry="14" fill="#4f86a8" opacity="0.25"/>')
        b.append(f'<rect x="{x + 30}" y="{FLOOR + 140 + (k % 2) * 30}" width="18" height="12" fill="#a1988a" transform="rotate({k * 20} {x + 30} {FLOOR + 140})"/>')
    gx = 1180
    b.append(R(gx, FLOOR, 200, H - FLOOR, "#1b2028", 0, 1.4))
    for k in range(8):
        b.append(f'<rect x="{gx + 10 + k * 24}" y="{FLOOR + 4}" width="10" height="{H - FLOOR - 8}" fill="#8d98a4"/>')
    b.append(cd.zebra(gx, FLOOR - 4, 200, 8))
    # blocos de fundação (E13)
    b.append(R(200, FLOOR - 150, 300, 150, "#6f7b8a", 4, 2.6, dark="#56606d"))
    b.append(R(W - 500, FLOOR - 150, 300, 150, "#6f7b8a", 4, 2.6, dark="#56606d"))
    # gerador + cabos (M9)
    b.append(R(240, FLOOR - 270, 150, 120, "#3c9a46", 8, 2.4, dark="#25682d"))
    for k in range(5):
        b.append(f'<rect x="{254 + k * 26}" y="{FLOOR - 250}" width="14" height="56" rx="3" fill="#25682d"/>')
    b.append(f'<path d="M352,{FLOOR - 220} l14,-14 l-4,12 l12,-2 l-16,18 l4,-12 Z" fill="{YEL}"/>')
    b.append(f'<path d="M390,{FLOOR - 200} C470,{FLOOR - 220} 520,{FLOOR - 120} 600,{FLOOR - 20} C640,{FLOOR + 10} 700,{FLOOR - 10} 760,{FLOOR - 10}" stroke="{INK}" stroke-width="7" fill="none"/>')
    for a in (-150, -110, -70, -30):
        r = math.radians(a)
        b.append(f'<path d="M760,{FLOOR - 10} l{16 * math.cos(r):.1f},{16 * math.sin(r):.1f}" stroke="#ffd36b" stroke-width="3"/>')
    # estacas + plataformas altas (E14) e central (E18)
    for (x, w, y) in ((620, 280, 740), (1660, 280, 740), (1150, 260, 520)):
        b.append(R(x, y, w, 22, "#8d98a4", 3, 2, dark="#6b7783"))
        b.append(cd.zebra(x, y + 22, w, 8))
        b.append(R(x + w / 2 - 22, y + 30, 44, FLOOR - y - 30, "#a9b2bc", 3, 2.4, dark="#8691a0"))
        for yy in range(y + 80, FLOOR, 90):
            b.append(f'<path d="M{x + w / 2 - 20},{yy} h40" stroke="#8691a0" stroke-width="3"/>')
    b.append(f'<path d="M{1660 + 140 - 22},{1000} l16,24 l-10,22" stroke="{INK}" stroke-width="3" fill="none"/>')   # estaca rachada (D9)
    # baldrames (E15)
    b.append(R(380, 900, 200, 18, "#a8582e", 3, 1.8, dark="#7a3a18"))
    b.append(R(W - 580, 900, 200, 18, "#a8582e", 3, 1.8, dark="#7a3a18"))
    # pedaços da laje do Térreo caídos (E16) — continuidade da virada
    b.append(f'<g transform="rotate(-14 900 {FLOOR})">' + cd.laje_body(760, FLOOR - 90, 256, 60, 2, 77, "e2lj1") + '</g>')
    b.append(f'<g transform="rotate(10 1560 {FLOOR})">' + cd.laje_body(1440, FLOOR - 70, 220, 50, 1, 78, "e2lj2") + '</g>')
    # trilho + vagonete (M8)
    b.append(f'<path d="M200,{FLOOR - 4} H{W - 200}" stroke="#3a3a46" stroke-width="5"/><path d="M200,{FLOOR - 12} H{W - 200}" stroke="#6b7783" stroke-width="3" stroke-dasharray="10 14"/>')
    b.append(S(f"M600,{FLOOR - 80} L740,{FLOOR - 80} L720,{FLOOR - 22} L620,{FLOOR - 22} Z", "#a8582e", (598, FLOOR - 82, 742, FLOOR - 20), k=2, dark="#7a3a18"))
    for (cx, s) in ((630, 1.0), (680, 0.8), (710, 0.6)):
        b.append(f'<rect x="{cx}" y="{FLOOR - 104}" width="{30 * s}" height="{24 * s}" fill="#a1988a" transform="rotate(14 {cx} {FLOOR - 92})"/>')
    for wx in (640, 700):
        b.append(f'<circle cx="{wx}" cy="{FLOOR - 16}" r="13" fill="{INK}"/><circle cx="{wx}" cy="{FLOOR - 16}" r="5" fill="#9aa4ae"/>')
    b.append(f'<circle cx="746" cy="{FLOOR - 66}" r="8" fill="#fff4c8"/><path d="M746,{FLOOR - 66} L880,{FLOOR - 100} L880,{FLOOR - 30} Z" fill="#fff4c8" opacity="0.2"/>')
    # bate-estaca (M6)
    b.append(bate_estaca(1535, 160, FLOOR))
    # registro da bomba (interação do M7) na parede direita
    b.append(f'<path d="M{W - 200},{FLOOR - 300} H{W - 260} V{FLOOR - 40}" stroke="#7a4a2e" stroke-width="22" fill="none"/>')
    b.append(f'<circle cx="{W - 260}" cy="{FLOOR - 230}" r="26" fill="none" stroke="#d94a3a" stroke-width="8"/><path d="M{W - 286},{FLOOR - 230} h52 M{W - 260},{FLOOR - 256} v52" stroke="#d94a3a" stroke-width="6"/>')
    # água (M7) com reflexos
    b.append(f'<rect x="200" y="{FLOOR - 30}" width="{W - 400}" height="30" fill="#4f86a8" opacity="0.5"/>')
    for x in range(260, W - 260, 160):
        b.append(f'<path d="M{x},{FLOOR - 26} q20,-6 40,0 q20,6 40,0" stroke="#bfe8f0" stroke-width="3" fill="none" opacity="0.7"/>')
    return "".join(b)


def e2_actors():
    return (robot("pa", "pesado_prep", el.COLORS[0], 760, 740) + robot("chave", "rapido", el.COLORS[2], 1240, FLOOR - 30)
            + robot("picareta", "esquiva", el.COLORS[1], 1400, 600, flip=True) + robot("britadeira", "parado", el.COLORS[3], 2150, FLOOR - 150, flip=True))


def e2_front():
    b = []
    for (x, l) in ((380, 240), (1000, 160), (1500, 220), (2240, 180)):   # lâmpadas penduradas (C4)
        b.append(f'<path d="M{x},0 V{l}" stroke="{INK}" stroke-width="3"/><circle cx="{x}" cy="{l + 16}" r="90" fill="url(#lamp)"/>')
        b.append(f'<path d="M{x - 18},{l} h36 l-8,14 h-20 Z" fill="#3a3a46"/><circle cx="{x}" cy="{l + 16}" r="10" fill="#ffe7a8"/>')
    for x in (600, 1280, 2000):   # gotas
        b.append(f'<path d="M{x},{240} q-6,12 0,16 q6,-4 0,-16 Z" fill="#9fe3f5" opacity="0.8"/>')
    b.append(f'<path d="M{W + 20},{H - 120} L{W - 420},{H + 20}" stroke="#141820" stroke-width="64" opacity="0.7"/>')
    return "".join(b)


def etapa2():
    body = e2_back() + e2_stage() + e2_actors() + e2_front()
    return doc(W, H, f'<g filter="url(#rough)">{body}</g>', rough(seed=33, scale=0.8, freq=0.05))


def main():
    os.makedirs(SRC, exist_ok=True)
    queue(etapa1(), f"{SRC}/etapa1.svg", os.path.join(ROOT, "art/out/fase1_etapa1.png"), W, H, 0.75)
    queue(etapa2(), f"{SRC}/etapa2.svg", os.path.join(ROOT, "art/out/fase1_etapa2.png"), W, H, 0.75)
    print("prancha fase 1:", render_all())


if __name__ == "__main__":
    main()
