"""Elenco novo (2026-11-24, pedido do usuário): 5 robôs de demolição com silhueta, ferramenta e golpes próprios.
Mesmo estilo papel e giz (formas chapadas, textura de giz, sem contorno), mas DE PERFIL (olham para onde andam) e
batendo com as DUAS mãos / o corpo todo. As regras do golpe são iguais para todos; só o visual muda.

Esqueleto de recorte: quadril → tronco (inclinação) → ombros/cabeça; pernas e braços de 2 segmentos resolvidos por IK
(pés e pegadas da ferramenta são alvos). Este mesmo esqueleto e estas poses vão para a Godot depois da aprovação.
Unidades = px de jogo, pés na origem, virado para a direita (+x), y para baixo.
Rodar: python3 art/src/robos/elenco.py  → art/out/prancha_elenco5.png
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from papel import ellipse_d, rect_d, rough, shape  # noqa: E402
from svg import doc, queue, render_all, shade  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.."))
SRC = os.path.join(ROOT, "art/src/robos/svg")
INK = "#2a1a2e"
COLORS = ["#4f86d9", "#5cc45c", "#f06aa8", "#f2c84b", "#f08a3d"]
STEEL, STEEL_D, STEEL_L = "#9aa4ae", "#6b7783", "#c9d1d8"
WOOD, WOOD_D = "#c98a4b", "#8a5a2b"
GLOVE, GLOVE_D = "#f4f1ea", "#c9c2b4"
YEL, YEL_D = "#f2c84b", "#c49a2a"
_n = [0]


def sid():
    _n[0] += 1
    return f"e{_n[0]}"


def S(d, fill, box, k=0.9, **kw):
    """Forma de giz (k pequeno: a peça é desenhada em px de jogo e a prancha amplia)."""
    return shape(sid(), d, fill, _n[0] * 7 + 3, box, k=k, **kw)


# ---------------------------------------------------------------- geometria
def rot(p, a):
    c, s = math.cos(math.radians(a)), math.sin(math.radians(a))
    return (p[0] * c - p[1] * s, p[0] * s + p[1] * c)


def add(a, b):
    return (a[0] + b[0], a[1] + b[1])


def ik(root, target, a, b, prefer):
    """Junta do meio de 2 segmentos (a, b) indo de root a target. prefer(cand) -> pontuação (maior vence)."""
    dx, dy = target[0] - root[0], target[1] - root[1]
    d = max(min(math.hypot(dx, dy), a + b - 0.01), abs(a - b) + 0.01)
    th = math.atan2(dy, dx)
    al = math.acos(max(-1.0, min(1.0, (a * a + d * d - b * b) / (2 * a * d))))
    c1 = (root[0] + math.cos(th + al) * a, root[1] + math.sin(th + al) * a)
    c2 = (root[0] + math.cos(th - al) * a, root[1] + math.sin(th - al) * a)
    end = (root[0] + math.cos(th) * d, root[1] + math.sin(th) * d)
    return (c1 if prefer(c1) >= prefer(c2) else c2), end


def capsule_d(p, q, w):
    ang = math.atan2(q[1] - p[1], q[0] - p[0])
    nx, ny = -math.sin(ang) * w / 2, math.cos(ang) * w / 2
    r = w / 2
    return (f"M{p[0] + nx:.2f},{p[1] + ny:.2f} L{q[0] + nx:.2f},{q[1] + ny:.2f} "
            f"A{r:.2f},{r:.2f} 0 0 0 {q[0] - nx:.2f},{q[1] - ny:.2f} L{p[0] - nx:.2f},{p[1] - ny:.2f} "
            f"A{r:.2f},{r:.2f} 0 0 0 {p[0] + nx:.2f},{p[1] + ny:.2f} Z")


def limb(p, q, w, col):
    box = (min(p[0], q[0]) - w, min(p[1], q[1]) - w, max(p[0], q[0]) + w, max(p[1], q[1]) + w)
    return S(capsule_d(p, q, w), col, box, k=0.6)


def poly_d(pts):
    return "M" + " L".join(f"{x:.2f},{y:.2f}" for x, y in pts) + " Z"


def glove(p, r, back=False):
    col = GLOVE_D if back else GLOVE
    return (S(ellipse_d(p[0], p[1], r, r * 0.92), col, (p[0] - r - 1, p[1] - r - 1, p[0] + r + 1, p[1] + r + 1), k=0.5)
            + f'<path d="M{p[0] - r * 0.5:.1f},{p[1] - r * 0.3:.1f} h{r:.1f}" stroke="{GLOVE_D}" stroke-width="{r * 0.25:.2f}" stroke-linecap="round"/>')


def boot(p, w, h, col, forward=1.0):
    x, y = p
    d = (f"M{x - w * 0.35:.1f},{y - h:.1f} C{x - w * 0.5:.1f},{y - h:.1f} {x - w * 0.5:.1f},{y:.1f} {x - w * 0.3:.1f},{y:.1f} "
         f"L{x + w * 0.65 * forward:.1f},{y:.1f} C{x + w * 0.75 * forward:.1f},{y:.1f} {x + w * 0.75 * forward:.1f},{y - h * 0.9:.1f} {x + w * 0.3 * forward:.1f},{y - h:.1f} Z")
    return S(d, col, (x - w, y - h - 1, x + w, y + 1), k=0.6)


# ---------------------------------------------------------------- personagens
# Cada um: hip_h (altura do quadril), torso(c, expr) desenhado no espaço do tronco (origem no quadril, -y para cima),
# ombros/quadris no tronco, braço (a, b, w), perna (a, b, w, dobra), mão, ferramenta (desenho no espaço da pegada
# da frente, +x para a cabeça da ferramenta) e pegadas.

def face_eye(x, y, r, expr, lens=False):
    out = []
    if lens:
        out.append(f'<circle cx="{x}" cy="{y}" r="{r + 1.6}" fill="{STEEL_D}"/><circle cx="{x}" cy="{y}" r="{r}" fill="{INK}"/>')
        out.append(f'<circle cx="{x + r * 0.25}" cy="{y}" r="{r * 0.55}" fill="#9ff7c8"/><circle cx="{x}" cy="{y - r * 0.35}" r="{r * 0.25}" fill="#ffffff"/>')
    else:
        ry = r * (0.45 if expr in ("esquiva", "forca") else 1.0)
        out.append(f'<ellipse cx="{x}" cy="{y}" rx="{r * 0.9:.2f}" ry="{ry:.2f}" fill="#ffffff"/>')
        out.append(f'<ellipse cx="{x + r * 0.35:.2f}" cy="{y + 0.2:.2f}" rx="{r * 0.45:.2f}" ry="{min(ry, r * 0.55):.2f}" fill="{INK}"/>')
    if expr in ("ataque", "forca", "grito"):
        out.append(f'<path d="M{x - r * 1.1:.1f},{y - r * 1.5:.1f} L{x + r * 1.1:.1f},{y - r * 0.9:.1f}" stroke="{INK}" stroke-width="{r * 0.45:.2f}" stroke-linecap="round"/>')
    return "".join(out)


def mouth(x, y, w, expr):
    if expr == "grito":
        return f'<path d="M{x - w * 0.5:.1f},{y - w * 0.2:.1f} Q{x:.1f},{y - w * 0.35:.1f} {x + w * 0.5:.1f},{y - w * 0.25:.1f} Q{x + w * 0.3:.1f},{y + w * 0.7:.1f} {x - w * 0.4:.1f},{y + w * 0.4:.1f} Z" fill="#7a2232"/>'
    if expr in ("ataque", "forca"):
        return f'<path d="M{x - w * 0.45:.1f},{y:.1f} h{w * 0.9:.1f}" stroke="{INK}" stroke-width="{w * 0.18:.2f}" stroke-linecap="round"/>' + \
            f'<path d="M{x - w * 0.3:.1f},{y - w * 0.12:.1f} v{w * 0.24:.1f} M{x:.1f},{y - w * 0.12:.1f} v{w * 0.24:.1f} M{x + w * 0.3:.1f},{y - w * 0.12:.1f} v{w * 0.24:.1f}" stroke="{INK}" stroke-width="{w * 0.06:.2f}"/>'
    if expr == "esquiva":
        return f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="{w * 0.18:.1f}" ry="{w * 0.24:.1f}" fill="#7a2232"/>'
    return f'<path d="M{x - w * 0.4:.1f},{y - w * 0.1:.1f} Q{x:.1f},{y + w * 0.35:.1f} {x + w * 0.45:.1f},{y - w * 0.15:.1f}" stroke="{INK}" stroke-width="{w * 0.15:.2f}" fill="none" stroke-linecap="round"/>'


# 1 MARRETÃO — brutamontes: tronco em trapézio largo, cabeça pequena de capacete com viseira, braços de pistão, botas.
def t_marretao(c, e):
    d = "M-15,0 L15,0 C20,-10 30,-30 27,-42 C25,-48 -22,-48 -25,-42 C-28,-30 -20,-10 -15,0 Z"
    out = S(d, c, (-30, -50, 30, 2), k=0.7)
    out += S("M-26,-30 L28,-30 L27,-23 L-24,-23 Z", INK, (-28, -32, 30, -21), k=0.4)
    for i in range(7):
        x = -24 + i * 7.6
        out += f'<path d="M{x},-23 l4,-7 l3.5,0 l-4,7 Z" fill="{YEL}"/>'
    out += f'<circle cx="18" cy="-12" r="2.2" fill="{shade(c, -0.35)}"/><circle cx="-14" cy="-12" r="2.2" fill="{shade(c, -0.35)}"/>'
    return out


def h_marretao(c, e):
    out = S("M-11,0 C-12,-14 -6,-20 1,-20 C9,-20 13,-14 12,0 Z", YEL, (-13, -22, 14, 2), k=0.6, dark=YEL_D)
    out += S("M-13,-1 L17,-1 L17,2 L-13,2 Z", YEL_D, (-14, -2, 18, 3), k=0.4)
    out += S("M-9,2 L13,2 L13,11 C13,14 -9,14 -9,11 Z", c, (-10, 1, 14, 15), k=0.5)
    out += S("M0,4 L14,4 L14,9 L0,9 Z", INK, (-1, 3, 15, 10), k=0.3)
    glow = "#ff6a3a" if e in ("forca", "grito") else "#ffd36b"
    out += f'<rect x="7" y="5.2" width="6" height="2.6" rx="1.3" fill="{glow}"/>'
    if e in ("ataque", "forca", "grito"):
        out += f'<path d="M4,3.6 L14,5" stroke="{INK}" stroke-width="1.4"/>'
    return out


def tool_marreta():
    out = S(rect_d(-16, -2.2, 52, 4.4, 2), WOOD, (-17, -3, 37, 3), k=0.5, dark=WOOD_D)
    out += S(rect_d(34, -11, 16, 22, 3), STEEL, (33, -12, 51, 12), k=0.6, dark=STEEL_D, light=STEEL_L)
    out += f'<rect x="38" y="-11" width="3.5" height="22" fill="{YEL}"/><rect x="42.5" y="-11" width="3.5" height="22" fill="{INK}"/>'
    out += f'<rect x="-16" y="-3" width="8" height="6" rx="2" fill="{INK}"/>'
    return out


# 2 PICARETA — magrelo de pernas de pássaro (joelho para trás), pescoço longo, cabeça oval com 1 lente.
def t_picareta(c, e):
    out = S("M-9,-2 C-12,-12 -10,-30 0,-32 C10,-32 12,-14 8,-2 C4,2 -6,2 -9,-2 Z", c, (-13, -34, 13, 3), k=0.6)
    out += f'<rect x="-2" y="-24" width="9" height="5" rx="1.5" fill="{YEL}"/><circle cx="4.5" cy="-21.5" r="1.2" fill="#d14d35"/>'
    return out


def h_picareta(c, e):
    out = f'<path d="M0,0 C1,-6 -1,-10 1,-15" stroke="{shade(c, -0.5)}" stroke-width="3.2" fill="none" stroke-linecap="round"/>'
    out += S("M-9,-16 C-10,-26 0,-30 7,-28 C14,-26 16,-18 12,-13 C8,-9 -6,-9 -9,-16 Z", c, (-11, -31, 16, -8), k=0.5)
    out += f'<path d="M-2,-29 C-4,-34 -1,-37 2,-37" stroke="{STEEL_D}" stroke-width="1.4" fill="none"/><circle cx="2" cy="-37.5" r="2" fill="{YEL}"/>'
    out += face_eye(7, -19.5, 3.6, e, lens=True)
    if e in ("ataque", "forca", "grito"):
        out += f'<path d="M2,-25 L12,-23" stroke="{INK}" stroke-width="1.5" stroke-linecap="round"/>'
    out += mouth(9, -12, 5, e) if e == "grito" else ""
    return out


def tool_picareta():
    out = S(rect_d(-16, -1.8, 50, 3.6, 1.8), WOOD, (-17, -3, 35, 3), k=0.5, dark=WOOD_D)
    out += S("M33,-3 C40,-6 48,-13 52,-22 C50,-12 44,-4 37,1 L37,4 C44,8 50,16 52,26 C46,17 40,10 33,6 Z", STEEL, (32, -23, 53, 27), k=0.6, dark=STEEL_D, light=STEEL_L)
    out += f'<rect x="31" y="-4" width="7" height="8" rx="2" fill="{STEEL_D}"/>'
    return out


# 3 CHAVE — mecânico: tronco de caixa de ferramentas com macacão, cabeça de porca sextavada com boné virado.
def t_chave(c, e):
    out = S(rect_d(-15, -30, 30, 30, 5), c, (-16, -31, 16, 1), k=0.7)
    out += S(rect_d(-15, -12, 30, 12, 4), "#3e5a8a", (-16, -13, 16, 1), k=0.5)
    out += f'<path d="M-10,-12 L-8,-30 M10,-12 L8,-30" stroke="#3e5a8a" stroke-width="3"/>'
    out += f'<rect x="-11" y="-14" width="5" height="4" rx="1" fill="{YEL}"/><rect x="6" y="-14" width="5" height="4" rx="1" fill="{YEL}"/>'
    out += f'<rect x="0" y="-24" width="9" height="7" rx="1.5" fill="{GLOVE}"/><path d="M2,-21 h5" stroke="{INK}" stroke-width="1"/>'
    return out


def h_chave(c, e):
    pts = [(math.cos(math.radians(a)) * 12, -12 + math.sin(math.radians(a)) * 12) for a in range(0, 360, 60)]
    out = S(poly_d(pts), c, (-13, -25, 13, 1), k=0.5)
    out += f'<circle cx="0" cy="-12" r="5.5" fill="{shade(c, -0.25)}"/>'
    out += S("M-11,-20 C-9,-27 5,-28 9,-21 L-13,-19 Z", "#d14d35", (-14, -28, 10, -18), k=0.4)
    out += S("M-11,-21 L-20,-19 L-12,-18 Z", "#a33a26", (-21, -22, -10, -17), k=0.3)
    out += face_eye(3, -12, 2.6, e) + face_eye(9.5, -12.3, 2.3, e)
    if e not in ("ataque", "forca"):
        out += f'<path d="M3,-6 C6,-4.5 9,-4.5 11,-6.5" stroke="{INK}" stroke-width="2.2" fill="none" stroke-linecap="round"/>'
    else:
        out += f'<path d="M3,-5.5 C6,-7 9,-7 11,-5.5" stroke="{INK}" stroke-width="2.4" fill="none" stroke-linecap="round"/>'
    return out


def tool_chave():
    out = S(rect_d(-14, -3, 46, 6, 3), STEEL, (-15, -4, 33, 4), k=0.5, dark=STEEL_D, light=STEEL_L)
    out += S("M30,-8 C36,-14 46,-13 49,-6 L42,-4 L42,4 L49,6 C46,13 36,14 30,8 Z", STEEL, (29, -15, 50, 15), k=0.6, dark=STEEL_D, light=STEEL_L)
    out += f'<path d="M-6,-1 h26" stroke="{STEEL_D}" stroke-width="1.4"/><rect x="-14" y="-4" width="9" height="8" rx="2" fill="#d14d35"/>'
    return out


# 4 BRITADEIRA — baixinho de barril, cabeção de capacete com óculos de proteção, pernas curtas.
def t_brit(c, e):
    out = S(ellipse_d(0, -14, 17, 15), c, (-18, -30, 18, 2), k=0.6)
    out += f'<path d="M-16,-10 C-6,-6 6,-6 16,-10" stroke="{shade(c, -0.3)}" stroke-width="2.4" fill="none"/>'
    out += f'<path d="M-16,-19 C-6,-15 6,-15 16,-19" stroke="{shade(c, -0.3)}" stroke-width="2.4" fill="none"/>'
    return out


def h_brit(c, e):
    out = S(ellipse_d(2, -13, 15, 14), c, (-14, -28, 18, 2), k=0.5)
    out += S("M-14,-15 C-14,-30 18,-30 18,-15 Z", YEL, (-15, -30, 19, -14), k=0.5, dark=YEL_D)
    out += f'<rect x="-16" y="-16.5" width="36" height="3" rx="1.5" fill="{YEL_D}"/>'
    out += f'<rect x="-6" y="-13" width="26" height="4" rx="2" fill="{INK}"/>'
    for x in (6, 15):
        out += f'<circle cx="{x}" cy="-9" r="5" fill="{STEEL_D}"/><circle cx="{x}" cy="-9" r="3.6" fill="#cdeff7"/>'
        sq = 0.5 if e in ("forca", "esquiva") else 1.0
        out += f'<ellipse cx="{x + 1}" cy="-9" rx="1.6" ry="{1.8 * sq:.1f}" fill="{INK}"/>'
    out += mouth(10, -1, 7, e)
    return out


def tool_brit():
    # britadeira: barra em T na pegada (perpendicular), corpo, ponteiro. +x = ponteiro
    out = S(rect_d(-2, -11, 5, 22, 2.5), INK, (-3, -12, 4, 12), k=0.4)
    out += S(rect_d(2, -6, 24, 12, 4), YEL, (1, -7, 27, 7), k=0.6, dark=YEL_D)
    out += f'<rect x="8" y="-6" width="3" height="12" fill="{INK}"/><rect x="15" y="-6" width="3" height="12" fill="{INK}"/>'
    out += S(rect_d(26, -4, 6, 8, 1.5), STEEL_D, (25, -5, 33, 5), k=0.4)
    out += S("M32,-2 L42,-1.2 L45,0 L42,1.2 L32,2 Z", STEEL, (31, -3, 46, 3), k=0.4, light=STEEL_L)
    return out


# 5 GARRA — escavadeira: esteiras no lugar das pernas, cabine com o rosto na janela, braço hidráulico com caçamba.
def t_garra(c, e):
    out = S(rect_d(-15, -30, 28, 28, 5), c, (-16, -31, 14, -1), k=0.7)
    out += S(rect_d(-4, -27, 14, 13, 3), "#cdeff7", (-5, -28, 11, -13), k=0.4)
    out += face_eye(2, -21, 2.2, e) + face_eye(7.5, -21.3, 2.0, e)
    out += mouth(5, -16.5, 5, e) if e in ("grito", "esquiva") else ""
    out += f'<rect x="-15" y="-9" width="28" height="4" fill="{YEL}"/>'
    out += f'<rect x="-13" y="-38" width="4" height="9" rx="1.5" fill="{STEEL_D}"/>'
    return out


def h_garra(c, e):
    return f'<circle cx="0" cy="-2" r="3" fill="{"#ff8a3a" if e in ("forca", "grito") else "#f08a3d"}"/>'


def tool_garra():
    out = S("M-2,-6 L10,-9 C18,-10 22,-4 22,2 L16,12 L12,8 L14,3 L4,6 L-2,6 Z", YEL, (-3, -11, 23, 13), k=0.6, dark=YEL_D)
    for x, y in ((14, 12), (18, 10), (22, 6)):
        out += f'<path d="M{x - 2},{y - 3} L{x + 1},{y + 3} L{x + 3},{y - 1} Z" fill="{STEEL}"/>'
    out += f'<circle cx="0" cy="0" r="3.4" fill="{STEEL_D}"/>'
    return out


def treads(c, lean, dash=False):
    out = S(rect_d(-22, -14, 44, 14, 7), "#3e4752", (-23, -15, 23, 1), k=0.6, dark="#252b33")
    for x in (-15, -5, 5, 15):
        out += f'<circle cx="{x}" cy="-7" r="4.2" fill="{STEEL}"/><circle cx="{x}" cy="-7" r="1.6" fill="{INK}"/>'
    for x in range(-20, 22, 5):
        out += f'<rect x="{x}" y="-15.5" width="2.4" height="2.4" fill="#252b33"/>'
    return out


CHARS = {
    "marretao": dict(nome="MARRETÃO", desc="o forte: tronco largo, marreta de duas mãos", hip_h=30, torso=t_marretao, head=h_marretao,
                     head_at=(5, -48), sh_b=(-14, -38), sh_f=(12, -38), hip_b=(-7, -3), hip_f=(7, -3), arm=(15, 15, 8.5),
                     leg=(14, 14, 10), knee=1, boot=(18, 9), hand=5.6, tool=tool_marreta, grips=[(0, 0), (-12, 0)]),
    "picareta": dict(nome="PICARETA", desc="o ágil: pernas de pássaro, alcance longo", hip_h=40, torso=t_picareta, head=h_picareta,
                     head_at=(3, -30), sh_b=(-4, -24), sh_f=(4, -24), hip_b=(-3, -1), hip_f=(3, -1), arm=(16, 16, 4.2),
                     leg=(20, 22, 5), knee=-1, boot=(12, 5), hand=3.8, tool=tool_picareta, grips=[(0, 0), (-12, 0)]),
    "chave": dict(nome="CHAVE", desc="o mecânico: caixa de ferramentas, chave inglesa gigante", hip_h=26, torso=t_chave, head=h_chave,
                  head_at=(1, -29), sh_b=(-11, -24), sh_f=(11, -24), hip_b=(-6, -2), hip_f=(6, -2), arm=(14, 14, 6),
                  leg=(13, 13, 7), knee=1, boot=(14, 7), hand=4.6, tool=tool_chave, grips=[(0, 0), (-10, 0)]),
    "britadeira": dict(nome="BRITADEIRA", desc="o baixinho: pula na britadeira", hip_h=14, torso=t_brit, head=h_brit,
                       head_at=(2, -24), sh_b=(-10, -18), sh_f=(10, -18), hip_b=(-6, -3), hip_f=(6, -3), arm=(11, 11, 5.6),
                       leg=(8, 8, 7), knee=1, boot=(13, 7), hand=4.4, tool=tool_brit, grips=[(0, 8), (0, -8)]),
    "garra": dict(nome="GARRA", desc="a escavadeira: esteiras e braço hidráulico", hip_h=14, torso=t_garra, head=h_garra,
                  head_at=(-11, -38), sh_b=None, sh_f=(10, -20), hip_b=None, hip_f=None, arm=(20, 20, 7.5),
                  leg=None, knee=1, boot=None, hand=0, tool=tool_garra, grips=[(0, 0)]),
}


def draw(cid, pose, col):
    ch = CHARS[cid]
    limbc = shade(col, -0.45)
    limbb = shade(col, -0.6)
    lean = pose.get("lean", 0)
    hip = (pose.get("dx", 0), -ch["hip_h"] + pose.get("dy", 0))
    T = lambda p: add(rot(p, lean), hip)  # noqa: E731
    e = pose.get("face", "")
    G = pose["tool"][:2]
    A = pose["tool"][2]
    grips = [add(G, rot(g, A)) for g in ch["grips"]]
    parts = {"back_leg": "", "back_arm": "", "torso": "", "front_leg": "", "tool": "", "back_hand": "", "front_arm": "", "fx_back": "", "fx": ""}
    # pernas
    if ch["leg"]:
        a, b, w = ch["leg"]
        for side, key in (("b", "back_leg"), ("f", "front_leg")):
            hp = T(ch["hip_" + side])
            ft = pose["feet"][0 if side == "b" else 1]
            ft = (ft[0], ft[1] - 3)
            knee, end = ik(hp, ft, a, b, (lambda q: q[0]) if ch["knee"] > 0 else (lambda q: -q[0]))
            lc = limbb if side == "b" else limbc
            parts[key] = limb(hp, knee, w, lc) + limb(knee, end, w * 0.9, lc) + boot((end[0], end[1] + 3), ch["boot"][0], ch["boot"][1], shade(col, -0.55) if side == "b" else shade(col, -0.4))
    else:
        parts["back_leg"] = f'<g transform="translate({hip[0]:.1f},{0}) rotate({lean * 0.4:.1f} 0 0)">{treads(col, lean)}</g>'
    # tronco + cabeça
    torso = f'<g transform="translate({hip[0]:.2f},{hip[1]:.2f}) rotate({lean:.2f})">{ch["torso"](col, e)}'
    ha = ch["head_at"]
    torso += f'<g transform="translate({ha[0]},{ha[1]}) rotate({pose.get("head", 0)})">{ch["head"](col, e)}</g></g>'
    parts["torso"] = torso
    # braços
    a, b, w = ch["arm"]
    shf = T(ch["sh_f"])
    elbow_pref = lambda q: q[1]  # noqa: E731  (cotovelo para baixo)
    if ch["sh_b"]:
        shb = T(ch["sh_b"])
        el, end = ik(shb, grips[1], a, b, elbow_pref)
        parts["back_arm"] = limb(shb, el, w, limbb) + limb(el, end, w * 0.9, limbb)
        parts["back_hand"] = glove(end, ch["hand"], back=True)
    if cid == "garra":   # braço telescópico: a haste estica até a caçamba
        el, end = ik(shf, G, a, b, lambda q: -q[1])
        reach = math.hypot(G[0] - el[0], G[1] - el[1])
        parts["front_arm"] = (limb(shf, el, w, YEL_D) + limb(el, G, w * 0.8, YEL)
                              + f'<path d="M{shf[0]:.1f},{shf[1] - 4:.1f} L{el[0]:.1f},{el[1] - 4:.1f}" stroke="{STEEL}" stroke-width="2.6"/>'
                              + f'<circle cx="{el[0]:.1f}" cy="{el[1]:.1f}" r="4" fill="{STEEL_D}"/>')
        if reach > b + 1:
            mid = (el[0] + (G[0] - el[0]) * b / reach, el[1] + (G[1] - el[1]) * b / reach)
            parts["front_arm"] += f'<path d="M{mid[0]:.1f},{mid[1]:.1f} L{G[0]:.1f},{G[1]:.1f}" stroke="{STEEL_L}" stroke-width="3"/>'
    else:
        el, end = ik(shf, grips[0], a, b, elbow_pref)
        parts["front_arm"] = limb(shf, el, w, limbc) + limb(el, end, w * 0.9, limbc) + glove(end, ch["hand"] * 1.05)
    parts["tool"] = f'<g transform="translate({G[0]:.2f},{G[1]:.2f}) rotate({A:.2f})">{ch["tool"]()}</g>'
    order = ["fx_back", "back_arm", "back_leg", "torso", "front_leg", "tool", "back_hand", "front_arm"]
    body = "".join(parts[k] for k in order)
    if pose.get("spin"):
        cx, cy = pose.get("spin_c", (0, -30))
        body = f'<g transform="rotate({pose["spin"]} {cx} {cy})">{body}</g>'
    return fx_draw(pose.get("fx_b", []), True) + body + fx_draw(pose.get("fx", []), False)


# ---------------------------------------------------------------- efeitos (movimento, poeira, impacto)
def fx_draw(items, back):
    out = []
    for it in items:
        k = it[0]
        if k == "arco":   # rastro do golpe: arco grosso branco translúcido
            _, cx, cy, r, a0, a1, w = it
            p0 = (cx + r * math.cos(math.radians(a0)), cy + r * math.sin(math.radians(a0)))
            p1 = (cx + r * math.cos(math.radians(a1)), cy + r * math.sin(math.radians(a1)))
            large = 1 if abs(a1 - a0) > 180 else 0
            sweep = 1 if a1 > a0 else 0
            out.append(f'<path d="M{p0[0]:.1f},{p0[1]:.1f} A{r},{r} 0 {large} {sweep} {p1[0]:.1f},{p1[1]:.1f}" stroke="#ffffff" stroke-opacity="0.75" stroke-width="{w}" fill="none" stroke-linecap="round"/>')
            out.append(f'<path d="M{p0[0]:.1f},{p0[1]:.1f} A{r},{r} 0 {large} {sweep} {p1[0]:.1f},{p1[1]:.1f}" stroke="#ffffff" stroke-width="{w * 0.35}" fill="none" stroke-linecap="round"/>')
        elif k == "linhas":   # linhas de velocidade
            _, x, y, n, ln, dx = it
            for i in range(n):
                yy = y + i * 7
                out.append(f'<path d="M{x + (i % 2) * 6},{yy} h{dx * ln}" stroke="#ffffff" stroke-width="2.4" stroke-opacity="0.8" stroke-linecap="round"/>')
        elif k == "poeira":
            _, x, y, s = it
            for i, (ox, oy, r) in enumerate(((-8, -3, 5), (0, -6, 7), (9, -3, 5), (-15, -1, 3.5), (16, -1, 3.5))):
                out.append(f'<circle cx="{x + ox * s:.1f}" cy="{y + oy * s:.1f}" r="{r * s:.1f}" fill="#e8e0d0" opacity="0.9"/>')
        elif k == "onda":   # onda de choque no chão
            _, x, y, r = it
            out.append(f'<ellipse cx="{x}" cy="{y}" rx="{r}" ry="{r * 0.22}" stroke="#ffffff" stroke-width="3" fill="none" opacity="0.85"/>')
            out.append(f'<ellipse cx="{x}" cy="{y}" rx="{r * 0.6}" ry="{r * 0.13}" stroke="#ffe27a" stroke-width="2.4" fill="none"/>')
        elif k == "estrela":   # impacto cartoon
            _, x, y, r = it
            pts = []
            for i in range(16):
                rr = r if i % 2 == 0 else r * 0.45
                a = math.radians(i * 22.5 - 90)
                pts.append((x + math.cos(a) * rr, y + math.sin(a) * rr))
            out.append(f'<path d="{poly_d(pts)}" fill="#ffe27a"/>')
            out.append(f'<circle cx="{x}" cy="{y}" r="{r * 0.3}" fill="#ffffff"/>')
        elif k == "faiscas":
            _, x, y = it
            for a in (-150, -120, -90, -60, -30):
                ra = math.radians(a)
                out.append(f'<path d="M{x + math.cos(ra) * 4:.1f},{y + math.sin(ra) * 4:.1f} L{x + math.cos(ra) * 11:.1f},{y + math.sin(ra) * 11:.1f}" stroke="#ffd36b" stroke-width="2" stroke-linecap="round"/>')
        elif k == "vibra":   # tremor da britadeira
            _, x, y = it
            for i in range(3):
                out.append(f'<path d="M{x + i * 5},{y - 9} q2,3 0,6 q-2,3 0,6" stroke="#ffffff" stroke-width="1.8" fill="none"/>')
        elif k == "pedras":
            _, x, y = it
            for (ox, oy, r) in ((-10, -12, 3), (6, -16, 2.5), (14, -8, 2), (-4, -20, 2)):
                out.append(f'<rect x="{x + ox}" y="{y + oy}" width="{r * 2}" height="{r * 1.6}" rx="0.8" fill="#a1988a" transform="rotate(20 {x + ox} {y + oy})"/>')
    return "".join(out)


# ---------------------------------------------------------------- poses
# tool = (x, y, ângulo) da pegada da frente; feet = [trás, frente]
POSES = {
    "marretao": {
        "parado": dict(lean=4, feet=[(-11, 0), (11, 0)], tool=(17, -34, 52)),
        "rapido": dict(lean=16, dy=2, feet=[(-13, 0), (15, 0)], tool=(30, -44, -6), face="ataque",
                       fx=[("linhas", 50, -60, 3, 14, -1)], fx_b=[("arco", 4, -50, 46, -70, 0, 9)]),
        "pesado_prep": dict(lean=-18, dy=5, feet=[(-15, 0), (13, 0)], tool=(-8, -72, -118), face="forca", head=-6),
        "pesado_golpe": dict(lean=32, dy=11, feet=[(-17, 0), (17, 0)], tool=(32, -28, 72), face="grito",
                             fx=[("onda", 50, 0, 30), ("estrela", 50, -4, 13), ("pedras", 50, 0)], fx_b=[("arco", 6, -40, 52, -150, 60, 12)]),
        "esquiva": dict(lean=-14, dy=16, dx=-4, feet=[(-22, 0), (14, 0)], tool=(20, -46, -84), face="esquiva",
                        fx_b=[("linhas", -60, -50, 4, 18, 1), ("poeira", -30, 0, 1.0)]),
    },
    "picareta": {
        "parado": dict(lean=6, feet=[(-8, 0), (10, 0)], tool=(14, -52, -72), head=4),
        "rapido": dict(lean=24, dy=7, feet=[(-24, 0), (26, 0)], tool=(40, -48, -4), face="ataque",
                       fx=[("linhas", 70, -58, 3, 16, -1)]),
        "pesado_prep": dict(lean=-14, dy=-7, feet=[(-5, 0), (7, 0)], tool=(-6, -100, -104), face="forca", head=-10),
        "pesado_golpe": dict(lean=42, dy=12, feet=[(-20, 0), (28, 0)], tool=(46, -32, 78), face="grito",
                             fx=[("estrela", 52, 2, 12), ("pedras", 54, 0)], fx_b=[("arco", 4, -50, 62, -110, 75, 10)]),
        "esquiva": dict(lean=0, dy=-26, feet=[(-12, -18), (4, -14)], tool=(-2, -70, -90), face="esquiva", spin=-160, spin_c=(0, -46),
                        fx_b=[("arco", 0, -46, 40, -40, 200, 5)]),
    },
    "chave": {
        "parado": dict(lean=2, feet=[(-10, 0), (10, 0)], tool=(12, -42, -128)),
        "rapido": dict(lean=12, dy=2, feet=[(-12, 0), (17, 0)], tool=(32, -40, 0), face="ataque",
                       fx=[("arco", 82, -40, 12, -80, 80, 4), ("faiscas", 80, -40)]),
        "pesado_prep": dict(lean=-8, dy=5, feet=[(-15, 0), (12, 0)], tool=(-22, -42, 176), face="forca", head=-4),
        "pesado_golpe": dict(lean=6, dy=4, feet=[(-18, 0), (18, 0)], tool=(30, -40, 8), face="grito",
                             fx_b=[("arco", 0, -40, 50, -175, 160, 9)], fx=[("estrela", 76, -40, 12)]),
        "esquiva": dict(lean=-22, dy=12, feet=[(-18, -2), (24, -4)], tool=(-10, -52, -130), face="esquiva",
                        fx=[("faiscas", -10, 0), ("faiscas", 4, 0)], fx_b=[("linhas", -50, -34, 4, 16, 1)]),
    },
    "britadeira": {
        "parado": dict(lean=0, feet=[(-8, 0), (7, 0)], tool=(17, -38, 90)),
        "rapido": dict(lean=12, dy=2, feet=[(-12, 0), (12, 0)], tool=(20, -24, 0), face="ataque",
                       fx=[("vibra", 64, -24), ("linhas", 66, -36, 2, 8, 1)]),
        "pesado_prep": dict(lean=-4, dy=-34, feet=[(0, -28), (14, -28)], tool=(10, -54, 90), face="forca"),
        "pesado_golpe": dict(lean=10, dy=-8, feet=[(2, -8), (16, -8)], tool=(12, -34, 90), face="grito",
                             fx=[("onda", 12, 0, 34), ("estrela", 12, 0, 14), ("pedras", 12, 0)]),
        "esquiva": dict(lean=-10, dy=-18, feet=[(-8, -14), (8, -12)], tool=(16, -38, 62), face="esquiva",
                        fx_b=[("poeira", -20, 0, 0.9), ("linhas", -48, -36, 3, 14, 1)]),
    },
    "garra": {
        "parado": dict(lean=0, tool=(30, -24, 62)),
        "rapido": dict(lean=6, tool=(58, -40, 0), face="ataque", fx=[("linhas", 72, -50, 3, 12, -1), ("estrela", 82, -40, 9)]),
        "pesado_prep": dict(lean=-10, tool=(-4, -88, -80), face="forca"),
        "pesado_golpe": dict(lean=10, tool=(40, -14, 100), face="grito", fx=[("onda", 50, 0, 28), ("pedras", 50, 0), ("estrela", 50, -2, 11)],
                             fx_b=[("arco", 10, -40, 50, -120, 60, 10)]),
        "esquiva": dict(lean=-14, dx=4, tool=(20, -52, -60), face="esquiva", fx_b=[("poeira", -26, 0, 1.0), ("linhas", -54, -30, 4, 18, 1)]),
    },
}
POSE_NAMES = [("parado", "PARADO"), ("rapido", "GOLPE RÁPIDO"), ("pesado_prep", "PESADO: PREPARO"), ("pesado_golpe", "PESADO: IMPACTO"), ("esquiva", "ESQUIVA")]


def label(x, y, t, size=26, col=INK, anchor="middle", weight=700):
    return f'<text x="{x}" y="{y}" font-family="Fredoka, Arial" font-weight="{weight}" font-size="{size}" fill="{col}" text-anchor="{anchor}">{t}</text>'


def prancha():
    W, H = 1920, 2200
    b = [f'<rect width="{W}" height="{H}" fill="#9fe2ec"/>', label(W / 2, 64, "ELENCO NOVO — 5 ROBÔS (para aprovar antes de animar no jogo)", 42)]
    x0, cw, ch_, top = 300, 324, 370, 110
    for j, (_, nm) in enumerate(POSE_NAMES):
        b.append(label(x0 + cw * j + cw / 2, top + 20, nm, 24, "#2a4a58"))
    s = 2.15
    for i, cid in enumerate(CHARS):
        y = top + 40 + i * ch_
        col = COLORS[i]
        b.append(f'<rect x="20" y="{y + 6}" width="{W - 40}" height="{ch_ - 14}" rx="22" fill="#ffffff" opacity="0.35"/>')
        b.append(label(40, y + 90, CHARS[cid]["nome"], 38, INK, "start"))

        words = CHARS[cid]["desc"].split(":")
        b.append(label(40, y + 130, words[0] + ":", 22, "#2a4a58", "start", 600))
        b.append(label(40, y + 158, words[1].strip(), 20, "#2a4a58", "start", 500))
        gy = y + ch_ - 40
        for j, (pk, _) in enumerate(POSE_NAMES):
            cx = x0 + cw * j + cw / 2
            b.append(f'<path d="M{cx - 140},{gy} H{cx + 140}" stroke="#7fb8c4" stroke-width="5" stroke-linecap="round"/>')
            b.append(f'<g transform="translate({cx - 20},{gy}) scale({s})">{draw(cid, POSES[cid][pk], col)}</g>')
    # tamanho real no jogo (1x e 1,5x)
    y = top + 40 + 5 * ch_ + 20
    b.append(label(W / 2, y + 30, "TAMANHO DE JOGO (1x) — nas 4 cores de jogador", 26, "#2a4a58"))
    gy = y + 140
    b.append(f'<rect x="60" y="{gy}" width="{W - 120}" height="40" fill="#d8cdb8"/>')
    k = 0
    for i, cid in enumerate(CHARS):
        for ci in range(4):
            cx = 120 + k * 88
            pose = POSES[cid]["parado"]
            b.append(f'<g transform="translate({cx},{gy}) scale(1)">{draw(cid, pose, COLORS[ci])}</g>')
            k += 1
    return doc(W, H, f'<g filter="url(#rough)">{"".join(b)}</g>', rough(seed=8, scale=0.8, freq=0.08))


def main():
    os.makedirs(SRC, exist_ok=True)
    queue(prancha(), f"{SRC}/prancha_elenco5.svg", os.path.join(ROOT, "art/out/prancha_elenco5.png"), 1920, 2200, 1)
    print("elenco:", render_all())


if __name__ == "__main__":
    main()
