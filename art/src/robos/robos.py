"""Robôs v3 — exatamente o estilo de versoes.png (referência do usuário): papel recortado sem contorno,
textura de giz, membros grossos mais escuros (desenhados pela Godot), mãos de luva brancas.
4 modelos: A Lata · B TV · C Baixinho · D Pescoção, nas 4 cores de jogador.
Tela das partes 128x128 (px de jogo), origem do robô (pés no chão) em (64,120). Exporta em 4x.
Gera também art/out/game/robo/modelos.json (quadris, ombros, mãos, ponto do chapéu) lido pela Godot.
Rodar: python3 art/src/robos/robos.py
"""
import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from papel import ellipse_d, hatch, rect_d, rough, shape  # noqa: E402
from svg import doc, queue, render_all, shade  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.."))
SRC = os.path.join(ROOT, "art/src/robos/svg")
OUT = os.path.join(ROOT, "art/out/game/robo")
K = 4
COLORS = ["#4f86d9", "#5cc45c", "#f06aa8", "#f2c84b"]   # azul da referência + 3 no mesmo tom
MOUTH, TONGUE, MINT, SCREEN, METAL = "#7a2232", "#e8603c", "#9ff7c8", "#1c2a4f", "#7a8ba1"
YELLOW, RED = "#f2c84b", "#d14d35"

# geometria de cada modelo (px de jogo, tela 128x128, pés em y≈117)
MODELS = {
    "lata": dict(hips=[[59, 84], [69, 84]], shoulders=[[54, 62], [74, 62]], hand_back=[44, 74], hand_front=[84, 60],
                 hat=[64, 42, 0.42], antenna=[63, 38], eyes=[[60, 52], [68.5, 51.5]], eye_r=2.3, mouth=[64, 59], screen=False),
    "tv": dict(hips=[[60, 86], [68, 86]], shoulders=[[57, 71], [71, 71]], hand_back=[45, 82], hand_front=[83, 74],
               hat=[64, 35, 0.68], antenna=[64, 35], eyes=[[58, 47], [70, 47]], eye_r=2.6, mouth=[64, 54], screen=True),
    "baixinho": dict(hips=[[60, 95], [68, 95]], shoulders=[[57, 85], [71, 85]], hand_back=[44, 88], hand_front=[86, 80],
                     hat=[64, 40, 0.82], antenna=[64, 38], eyes=[[57, 62], [70, 61]], eye_r=3.0, mouth=[64, 72], screen=False),
    "pescocao": dict(hips=[[58, 92], [70, 92]], shoulders=[[54, 75], [74, 75]], hand_back=[43, 86], hand_front=[85, 70],
                     hat=[65, 33, 0.5], antenna=[68, 32], eyes=[[61, 41], [69.5, 40]], eye_r=2.0, mouth=[65, 46], screen=False),
}


def wrap(body, seed):
    return doc(128, 128, f'<g filter="url(#rough)">{body}</g>', rough(seed=seed, scale=0.9, freq=0.12))


def side_shade(cid, d, x, w, col, box):
    """Faixa mais escura no lado direito (volume), recortada na forma."""
    return f'<g clip-path="url(#{cid})"><rect x="{x}" y="{box[1]}" width="{w}" height="{box[3] - box[1]}" fill="{col}"/></g>'


NEUTRAL = "#f2f2f2"   # corpo neutro: a Godot pinta na cor escolhida (personalização)


def body_svg(model, ci, color=None, details=True):
    c = color or COLORS[ci]
    dark, light, mid = shade(c, -0.18), shade(c, 0.3), shade(c, -0.08)
    s = ci * 10 + list(MODELS).index(model)
    b = []
    if model == "lata":
        d = rect_d(53, 40, 22, 45, 4)
        b.append(shape("b1", d, c, s, (50, 38, 78, 86)))
        b.append(side_shade("b1", d, 70, 6, dark, (0, 38, 0, 86)))
        b.append(f'<path d="M70,44 Q71,64 70.5,84" stroke="{shade(c, -0.3)}" stroke-width="0.7" fill="none" opacity="0.7"/>')
        b.append(shape("b2", ellipse_d(64, 41, 11, 3.4), light, s + 1, (52, 37, 76, 45)))
    elif model == "tv":
        d = "M44,35 L84,34 L84.5,66 L44.5,67 Z"
        b.append(shape("b1", rect_d(56, 64, 16, 23, 2), mid, s + 2, (54, 62, 74, 88)))
        b.append(shape("b2", d, c, s, (42, 32, 86, 68)))
        b.append(side_shade("b2", d, 80, 5, dark, (0, 32, 0, 68)))
        if details:
            b.append(f'<path d="M48.5,38.5 L79.5,38 L79,62 L49,62.5 Z" fill="{SCREEN}"/>')
    elif model == "baixinho":
        b.append(shape("b1", rect_d(56, 80, 16, 17, 3), mid, s + 2, (54, 78, 74, 98)))
        d = ellipse_d(64, 60, 23, 23)
        b.append(shape("b2", d, dark, s, (40, 36, 88, 84)))
        b.append('<g clip-path="url(#b2)">' + shape("b3", ellipse_d(61, 57.5, 23, 23), c, s + 5, (37, 33, 85, 81)) + '</g>')
        b.append(f'<path d="M47,50 Q52,41 61,39" stroke="{light}" stroke-width="2.2" fill="none" stroke-linecap="round"/>')
    elif model == "pescocao":
        if details:
            b.append(f'<path d="M64,72 C61,66 67,61 63,56 C60,52 65,50 64,47" stroke="{METAL}" stroke-width="2.2" fill="none" stroke-linecap="round"/>')
        d = rect_d(53, 70, 22, 23, 3)
        b.append(shape("b1", d, c, s, (50, 68, 78, 94)))
        b.append(side_shade("b1", d, 71, 4, dark, (0, 68, 0, 94)))
        if details:
            b.append(f'<rect x="58" y="77" width="8.5" height="6" rx="1" fill="{YELLOW}"/><circle cx="60.3" cy="80" r="0.9" fill="{RED}"/>')
        hd = "M51,42 C51,34 58,31 66,31 C75,31 80,36 79,43 C78,50 71,52 64,52 C56,52 51,49 51,42 Z"
        b.append(shape("b2", hd, dark, s + 3, (49, 29, 81, 54)))
        hd2 = "M48,40 C48,32 55,29 63,29 C72,29 77,34 76,41 C75,48 68,50 61,50 C53,50 48,47 48,40 Z"
        b.append('<g clip-path="url(#b2)">' + shape("b3", hd2, c, s + 6, (46, 27, 78, 52)) + '</g>')
    return wrap("".join(b), 100 + s)


# ------------------------------------------------------------------ personalização
# formas pintáveis de cada modelo (para recortar os padrões)
BODY_PATHS = {
    "lata": [rect_d(53, 40, 22, 45, 4)],
    "tv": ["M44,35 L84,34 L84.5,66 L44.5,67 Z", rect_d(56, 64, 16, 23, 2)],
    "baixinho": [ellipse_d(64, 60, 23, 23), rect_d(56, 80, 16, 17, 3)],
    "pescocao": [rect_d(53, 70, 22, 23, 3), "M51,42 C51,34 58,31 66,31 C75,31 80,36 79,43 C78,50 71,52 64,52 C56,52 51,49 51,42 Z"],
}


def detail_svg(model):
    """Partes que não mudam de cor (tela da TV, pescoço e plaquinha do Pescoção)."""
    b = []
    if model == "tv":
        b.append(f'<path d="M48.5,38.5 L79.5,38 L79,62 L49,62.5 Z" fill="{SCREEN}"/>')
    elif model == "pescocao":
        b.append(f'<path d="M64,72 C61,66 67,61 63,56 C60,52 65,50 64,47" stroke="{METAL}" stroke-width="2.2" fill="none" stroke-linecap="round"/>')
        b.append(f'<rect x="58" y="77" width="8.5" height="6" rx="1" fill="{YELLOW}"/><circle cx="60.3" cy="80" r="0.9" fill="{RED}"/>')
    return wrap("".join(b), 150)


def pattern_svg(model, pat):
    """Padrão branco recortado no corpo (a Godot pinta com a cor secundária)."""
    import random as _r
    rnd = _r.Random(hash(model + pat) % 1000)
    clip = "".join(f'<path d="{d}"/>' for d in BODY_PATHS[model])
    b = [f'<clipPath id="pc">{clip}</clipPath><g clip-path="url(#pc)">']
    if pat == "listras":
        for y in range(20, 110, 8):
            b.append(f'<rect x="20" y="{y}" width="90" height="3.6" fill="#ffffff"/>')
    elif pat == "bolinhas":
        for row, y in enumerate(range(24, 108, 7)):
            for x in range(28, 100, 7):
                b.append(f'<circle cx="{x + (row % 2) * 3.5}" cy="{y}" r="1.7" fill="#ffffff"/>')
    elif pat == "manchas":
        for k in range(16):
            x, y = rnd.uniform(40, 90), rnd.uniform(28, 100)
            b.append(f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="{rnd.uniform(2.5, 5.5):.1f}" ry="{rnd.uniform(1.8, 4):.1f}" fill="#ffffff"/>')
    elif pat == "raio":
        b.append('<path d="M40,58 L60,48 L58,58 L90,44 L90,52 L64,64 L66,54 L40,66 Z" fill="#ffffff"/>')
        b.append('<path d="M40,84 L62,74 L60,82 L90,70 L90,76 L64,88 L66,80 L40,90 Z" fill="#ffffff"/>')
    b.append('</g>')
    return wrap("".join(b), 160)


def hat_svg2(name):
    """Chapéus novos (aba centrada em (64,64), largura ~60, mesmo esquema do hat_svg)."""
    b = []
    if name == "cartola":
        b.append(shape("a", rect_d(46, 22, 36, 40, 2), "#2f3145", 31, (44, 20, 84, 64), k=1.4))
        b.append('<rect x="46" y="48" width="36" height="7" fill="#d14d35"/><path d="M32,60 Q64,56 96,60 L95,66 Q64,62 33,66 Z" fill="#2f3145"/>')
    elif name == "coroa":
        b.append(shape("a", "M40,62 L40,36 L52,48 L64,30 L76,48 L88,36 L88,62 Z", "#f2c84b", 32, (38, 28, 90, 64), k=1.4))
        b.append('<circle cx="64" cy="52" r="4" fill="#d14d35"/><circle cx="50" cy="56" r="3" fill="#4f86d9"/><circle cx="78" cy="56" r="3" fill="#5cc45c"/>')
    elif name == "cowboy":
        b.append(shape("a", "M46,58 C44,40 52,32 64,32 C76,32 84,40 82,58 Z", "#b07a3d", 33, (42, 30, 86, 60), k=1.4))
        b.append('<path d="M20,58 Q30,66 64,64 Q98,66 108,58 Q100,72 64,72 Q28,72 20,58 Z" fill="#8a5a2a"/><rect x="46" y="52" width="36" height="5" fill="#5a3a1c"/>')
    elif name == "chef":
        b.append(shape("a", "M44,60 L44,44 C34,40 38,24 50,28 C52,18 76,18 78,28 C90,24 94,40 84,44 L84,60 Z", "#ffffff", 34, (36, 16, 92, 62), k=1.4, dark="#cfd6de"))
        b.append('<rect x="44" y="54" width="40" height="8" fill="#e9eef2"/>')
    elif name == "viking":
        b.append(shape("a", "M40,62 C40,42 50,34 64,34 C78,34 88,42 88,62 Z", "#8a96a2", 35, (38, 32, 90, 64), k=1.4))
        b.append('<path d="M42,50 C30,46 26,34 30,22 C34,34 40,40 46,42 Z M86,50 C98,46 102,34 98,22 C94,34 88,40 82,42 Z" fill="#f2e6c8"/><rect x="40" y="56" width="48" height="6" fill="#b07a3d"/>')
    elif name == "helice":
        b.append(shape("a", "M40,62 C40,44 50,38 64,38 C78,38 88,44 88,62 Q64,58 40,62 Z", "#5cc45c", 36, (38, 36, 90, 64), k=1.4))
        b.append('<path d="M64,38 V26" stroke="#4b535e" stroke-width="3"/><path d="M40,24 Q64,18 88,24 Q64,30 40,24 Z" fill="#d14d35"/><circle cx="64" cy="25" r="3.5" fill="#f2c84b"/>')
    elif name == "laco":
        b.append('<path d="M64,52 L44,40 Q38,52 44,64 Z M64,52 L84,40 Q90,52 84,64 Z" fill="#f06aa8"/><circle cx="64" cy="52" r="6" fill="#d94a8c"/>')
    elif name == "fone":
        b.append('<path d="M38,64 C36,36 50,26 64,26 C78,26 92,36 90,64" stroke="#2f3640" stroke-width="6" fill="none"/>')
        b.append('<rect x="30" y="56" width="14" height="22" rx="5" fill="#d14d35"/><rect x="84" y="56" width="14" height="22" rx="5" fill="#d14d35"/>')
    elif name == "pirata":
        b.append(shape("a", "M30,60 Q36,34 64,36 Q92,34 98,60 Q64,52 30,60 Z", "#2f3145", 37, (28, 32, 100, 62), k=1.4))
        b.append('<circle cx="64" cy="48" r="5" fill="#f2f2f2"/><path d="M59,55 L69,61 M69,55 L59,61" stroke="#f2f2f2" stroke-width="2"/>')
    elif name == "flor":
        for k in range(6):
            import math as _m
            a = k * _m.pi / 3
            b.append(f'<circle cx="{64 + _m.cos(a) * 8:.1f}" cy="{46 + _m.sin(a) * 8:.1f}" r="6.5" fill="#f06aa8"/>')
        b.append('<circle cx="64" cy="46" r="5.5" fill="#f2c84b"/><path d="M64,54 Q62,60 66,64" stroke="#5cc45c" stroke-width="3" fill="none"/>')
    elif name == "cone":
        b.append(shape("a", "M64,18 L84,62 L44,62 Z", "#f08a3d", 38, (42, 16, 86, 64), k=1.4))
        b.append('<path d="M55,40 L73,40 L76,48 L52,48 Z" fill="#ffffff"/><rect x="38" y="60" width="52" height="7" fill="#e0782a"/>')
    elif name == "balde":
        b.append(shape("a", "M44,64 L48,30 L80,30 L84,64 Z", "#8fb7c9", 39, (42, 28, 86, 66), k=1.4))
        b.append('<path d="M44,34 Q64,14 84,34" stroke="#5a6370" stroke-width="2.5" fill="none"/><rect x="47" y="36" width="34" height="4" fill="#6d97ab"/>')
    return wrap("".join(b), 141)


def face_item_svg(name):
    """Itens de rosto 64x32, centro (32,16) entre os olhos; espaço entre olhos ~12 px."""
    b = []
    if name == "oculos_sol":
        b.append('<rect x="12" y="10" width="17" height="12" rx="4" fill="#2f3145"/><rect x="35" y="10" width="17" height="12" rx="4" fill="#2f3145"/>'
                 '<path d="M29,14 H35" stroke="#2f3145" stroke-width="3"/><path d="M15,13 L21,13" stroke="#8a8fb0" stroke-width="2"/>')
    elif name == "oculos_solda":
        b.append('<path d="M6,16 H58" stroke="#3e4752" stroke-width="5"/><circle cx="22" cy="16" r="9" fill="#5a6370"/><circle cx="42" cy="16" r="9" fill="#5a6370"/>'
                 '<circle cx="22" cy="16" r="6" fill="#2f6b4f"/><circle cx="42" cy="16" r="6" fill="#2f6b4f"/><path d="M19,13 l3,-2" stroke="#9ff7c8" stroke-width="2"/>')
    elif name == "bigode":
        b.append('<path d="M32,26 C26,22 18,22 12,28 C18,32 26,32 32,28 C38,32 46,32 52,28 C46,22 38,22 32,26 Z" fill="#5a3a1c"/>')
    elif name == "tapa_olho":
        b.append('<path d="M4,8 L60,20" stroke="#2f3145" stroke-width="2"/><ellipse cx="22" cy="15" rx="8" ry="7" fill="#2f3145"/>')
    elif name == "oculos_redondos":
        b.append('<circle cx="21" cy="16" r="8" fill="none" stroke="#b07a3d" stroke-width="2.6"/><circle cx="43" cy="16" r="8" fill="none" stroke="#b07a3d" stroke-width="2.6"/>'
                 '<path d="M29,15 Q32,12 35,15" stroke="#b07a3d" stroke-width="2.4" fill="none"/>')
    return doc(64, 32, "".join(b))


def tool_svg(name):
    """Ferramentas 64x64 no lugar da marreta: cabo vertical, pega em (32,56)."""
    handle = '<path d="M31,26 L33.4,26 L33.8,62 L31.3,62 Z" fill="#b07a3d"/><path d="M31.8,28 L32.1,60" stroke="#d29a58" stroke-width="0.6"/>'
    if name == "picareta":
        head = shape("h", "M10,26 Q32,8 54,26 L50,28 Q32,16 14,28 Z", "#9aa4ae", 51, (8, 8, 56, 30), k=1.0)
        return doc(64, 64, f'<g filter="url(#rough)">{handle}{head}</g>', rough(seed=51, scale=0.8))
    if name == "chave_inglesa":
        body = shape("h", "M30,62 L30,26 C24,24 22,14 28,8 L30,16 L36,16 L38,8 C44,14 42,24 36,26 L36,62 Z", "#c3ccd3", 52, (20, 6, 46, 64), k=1.0, dark="#8a96a2")
        return doc(64, 64, f'<g filter="url(#rough)">{body}</g>', rough(seed=52, scale=0.8))
    if name == "frigideira":
        pan = shape("h", ellipse_d(32, 20, 17, 14), "#3e4752", 53, (14, 4, 50, 36), k=1.0)
        return doc(64, 64, f'<g filter="url(#rough)"><path d="M30,32 L34,32 L34.6,62 L29.4,62 Z" fill="#2f3640"/>{pan}<ellipse cx="32" cy="20" rx="12" ry="9.5" fill="#5a6370"/><path d="M24,14 Q28,10 34,11" stroke="#8a96a2" stroke-width="2" fill="none"/></g>', rough(seed=53, scale=0.8))
    if name == "martelo_borracha":
        head = shape("h", rect_d(16, 12, 32, 18, 7), "#f06aa8", 54, (14, 10, 50, 32), k=1.0, dark="#c94a86")
        return doc(64, 64, f'<g filter="url(#rough)">{handle}{head}<path d="M20,15 H36" stroke="#ff9ccb" stroke-width="2.4" stroke-linecap="round"/></g>', rough(seed=54, scale=0.8))
    if name == "desentupidor":
        cup = shape("h", "M16,30 C16,16 48,16 48,30 Z", "#d14d35", 55, (14, 14, 50, 32), k=1.0)
        return doc(64, 64, f'<g filter="url(#rough)"><path d="M30.6,28 L33.4,28 L33.8,62 L30.3,62 Z" fill="#e3c08a"/>{cup}<rect x="14" y="28" width="36" height="4" rx="2" fill="#a83a28"/></g>', rough(seed=55, scale=0.8))
    return hammer_svg()


def antenna_svg(model):
    def ant(x0, y0, x1, y1, ball):
        return (f'<path d="M{x0},{y0} Q{(x0 + x1) / 2 - 1},{(y0 + y1) / 2} {x1},{y1}" stroke="{METAL}" stroke-width="1.6" fill="none" stroke-linecap="round"/>'
                f'<circle cx="{x1}" cy="{y1 - 1.5}" r="2.6" fill="{ball}"/>')
    b = {"lata": ant(63, 38, 69, 27, YELLOW), "baixinho": ant(64, 38, 67, 26, YELLOW), "pescocao": ant(68, 32, 71, 21, YELLOW),
         "tv": ant(54, 35, 49, 23, RED) + ant(73, 35, 80, 23, YELLOW)}[model]
    return wrap(b, 120)


def face_svg(model, expr):
    m = MODELS[model]
    (lx, ly), (rx, ry) = m["eyes"]
    er = m["eye_r"]
    mx, my = m["mouth"]
    tv = m["screen"]
    ink = MINT if tv else "#1c2233"
    b = []

    def eye(x, y, r, py=0.3, pr=0.55):
        if tv:
            return f'<circle cx="{x}" cy="{y}" r="{r * 0.9}" fill="{MINT}"/>'
        return (f'<ellipse cx="{x}" cy="{y}" rx="{r}" ry="{r * 1.1}" fill="#ffffff"/>'
                f'<circle cx="{x + r * 0.15}" cy="{y + r * py}" r="{r * pr}" fill="#1c2233"/>')

    if expr in ("normal", "piscar"):
        if expr == "normal":
            b += [eye(lx, ly, er), eye(rx, ry, er)]
        else:  # olhos fechados (piscada)
            for x, y in ((lx, ly), (rx, ry)):
                b.append(f'<path d="M{x - er},{y} Q{x},{y + er * 0.9} {x + er},{y}" stroke="{ink}" stroke-width="1.4" fill="none" stroke-linecap="round"/>')
        if tv:
            b.append(f'<path d="M{mx - 6},{my - 1} Q{mx},{my + 3} {mx + 6},{my - 1}" stroke="{MINT}" stroke-width="1.6" fill="none" stroke-linecap="round"/>')
        elif model == "lata":
            b.append(f'<path d="M{mx - 6},{my - 2} H{mx + 6} Q{mx + 4},{my + 6} {mx},{my + 6} Q{mx - 4},{my + 6} {mx - 6},{my - 2} Z" fill="{MOUTH}"/>')
            b.append(f'<path d="M{mx - 3},{my + 6.4} Q{mx},{my + 5} {mx + 3},{my + 6.2}" stroke="{TONGUE}" stroke-width="1.3" fill="none" stroke-linecap="round"/>')
        elif model == "baixinho":
            b.append(f'<ellipse cx="{mx}" cy="{my}" rx="3.6" ry="2.7" fill="{MOUTH}"/>')
        else:
            b.append(f'<path d="M{mx - 4},{my} Q{mx},{my + 2.6} {mx + 4},{my - 0.5}" stroke="#1c2233" stroke-width="1.1" fill="none" stroke-linecap="round"/>')
    elif expr == "esforco":
        for x, y in ((lx, ly), (rx, ry)):
            b.append(f'<path d="M{x - er},{y + 0.5} Q{x},{y - er * 0.8} {x + er},{y + 0.5}" stroke="{ink}" stroke-width="1.5" fill="none" stroke-linecap="round"/>')
        b.append(f'<path d="M{lx - er * 1.3},{ly - er * 1.8} L{lx + er},{ly - er * 1.1} M{rx + er * 1.3},{ry - er * 1.8} L{rx - er},{ry - er * 1.1}" stroke="{ink}" stroke-width="1.3" stroke-linecap="round"/>')
        b.append(f'<rect x="{mx - 4.5}" y="{my - 1.5}" width="9" height="4" rx="1" fill="{MINT if tv else "#ffffff"}"/>')
        if not tv:
            b.append(f'<path d="M{mx - 1.5},{my - 1.5} v4 M{mx + 1.5},{my - 1.5} v4" stroke="#1c2233" stroke-width="0.6"/>')
    elif expr == "susto":
        b += [eye(lx, ly - 0.5, er * 1.25, 0.0, 0.35), eye(rx, ry - 0.5, er * 1.25, 0.0, 0.35)]
        b.append(f'<ellipse cx="{mx}" cy="{my + 1}" rx="2.6" ry="3.4" fill="{MINT if tv else MOUTH}"/>')
    elif expr == "vitoria":
        for x, y in ((lx, ly), (rx, ry)):
            b.append(f'<path d="M{x - er},{y + 1} Q{x},{y - er * 1.4} {x + er},{y + 1}" stroke="{ink}" stroke-width="1.6" fill="none" stroke-linecap="round"/>')
        b.append(f'<path d="M{mx - 6},{my - 1.5} H{mx + 6} Q{mx + 4.5},{my + 6} {mx},{my + 6} Q{mx - 4.5},{my + 6} {mx - 6},{my - 1.5} Z" fill="{MINT if tv else MOUTH}"/>')
        if not tv:
            b.append(f'<path d="M{mx - 3},{my + 4.8} Q{mx},{my + 3} {mx + 3},{my + 4.8}" stroke="{TONGUE}" stroke-width="1.4" fill="none" stroke-linecap="round"/>')
    elif expr == "eliminado":
        for x, y in ((lx, ly), (rx, ry)):
            r = er * 0.9
            b.append(f'<path d="M{x - r},{y - r} L{x + r},{y + r} M{x - r},{y + r} L{x + r},{y - r}" stroke="{ink}" stroke-width="1.4" stroke-linecap="round"/>')
        b.append(f'<path d="M{mx - 5},{my + 1} q1.6,-2 3.3,0 t3.3,0 t3.3,0" stroke="{ink}" stroke-width="1.2" fill="none" stroke-linecap="round"/>')
    return wrap("".join(b), 130)


def hand_svg():
    # luva branca 16x16, centro (8,8)
    d = "M3.5,8.5 C3,4.5 5.5,3 8.5,3.2 C11.5,3.4 13,5.5 12.6,8.6 C12.3,11.5 10.2,12.8 7.8,12.6 C5.4,12.4 3.8,11 3.5,8.5 Z"
    return doc(16, 16, f'<g filter="url(#rough)">{shape("h", d, "#eef3f8", 7, (2, 2, 14, 14), dark="#c4cdd8", light="#ffffff")}'
                       f'<path d="M12,7 C14,6 15,8 13.4,9.4" fill="#eef3f8"/></g>', rough(seed=9, scale=0.5))


def foot_svg():
    # bota branca (a Godot pinta com a cor do membro), 24x14, centro (12,7)
    return doc(24, 14, f'<g filter="url(#rough)">{shape("f", "M2,9 C2,4 7,2.5 12,2.5 C18,2.5 22,5 22,9 C22,11.5 17,12 12,12 C6,12 2,11.5 2,9 Z", "#ffffff", 11, (1, 1, 23, 13), dark="#c9c9c9")}</g>',
               rough(seed=11, scale=0.5))


def hammer_svg():
    # 64x64, cabo vertical, pega em (32,56)
    head = "M19,15 L45,14 L46,28 L20,29 Z"
    return doc(64, 64, (
        f'<g filter="url(#rough)"><path d="M31,28 L33.4,28 L33.8,62 L31.3,62 Z" fill="#b07a3d"/>'
        f'<path d="M31.8,30 L32.1,60" stroke="#d29a58" stroke-width="0.6"/>'
        + shape("hh", head, "#9aa4ae", 13, (17, 12, 48, 31), k=1.0)
        + '<path d="M19,15 L45,14 L45.2,17 L19.2,18 Z" fill="#b7c0c8" opacity="0.9"/>'
        '<path d="M42.5,14.1 L46,28 L43.4,28.1 L41,14.2 Z" fill="#7b858f" opacity="0.8"/></g>'), rough(seed=13, scale=0.8))


def hat_svg(name):
    # aba centrada em (64,64), largura ~60
    b = []
    if name == "capacete":
        b.append(shape("a", "M38,62 C38,40 50,32 64,32 C78,32 90,40 90,62 Z", "#f2c84b", 21, (36, 30, 92, 64), k=1.4))
        b.append('<path d="M30,61 Q64,56 98,61 L97,67 Q64,63 31,67 Z" fill="#e0b23c"/><path d="M59,33 L69,33 L70,61 L58,61 Z" fill="#e0b23c"/>')
    elif name == "bone":
        b.append('<path d="M14,62 Q24,56 42,58 L43,65 Q28,66 16,68 Z" fill="#4b3fa8"/>')
        b.append(shape("a", "M38,64 C38,44 50,36 64,36 C79,36 90,44 90,64 Q64,59 38,64 Z", "#6c5ce7", 22, (36, 34, 92, 66), k=1.4))
        b.append('<rect x="72" y="45" width="11" height="6" rx="1" fill="#ffffff"/>')
    elif name == "gorro":
        b.append(shape("a", "M40,60 C38,40 51,30 64,30 C78,30 90,40 88,60 Z", "#ff8a3d", 23, (36, 28, 92, 62), k=1.4))
        b.append(shape("a2", rect_d(36, 56, 56, 12, 5), "#f2f2f2", 24, (34, 54, 94, 70), k=1.4, dark="#c9ced6"))
        b.append(shape("a3", ellipse_d(66, 27, 7, 7), "#f2f2f2", 25, (58, 19, 74, 35), k=1.4, dark="#c9ced6"))
    return wrap("".join(b), 140)


def main():
    for model in MODELS:
        for ci in range(4):
            queue(body_svg(model, ci), f"{SRC}/corpo_{model}_p{ci + 1}.svg", f"{OUT}/corpo_{model}_p{ci + 1}.png", 128, 128, K)
        queue(antenna_svg(model), f"{SRC}/antena_{model}.svg", f"{OUT}/antena_{model}.png", 128, 128, K)
        for e in ("normal", "piscar", "esforco", "susto", "vitoria", "eliminado"):
            queue(face_svg(model, e), f"{SRC}/rosto_{model}_{e}.svg", f"{OUT}/rosto_{model}_{e}.png", 128, 128, K)
    queue(hand_svg(), f"{SRC}/mao.svg", f"{OUT}/mao.png", 16, 16, K)
    queue(foot_svg(), f"{SRC}/pe.svg", f"{OUT}/pe.png", 24, 14, K)
    queue(hammer_svg(), f"{SRC}/marreta.svg", f"{OUT}/marreta.png", 64, 64, K)
    for a in ("capacete", "bone", "gorro"):
        queue(hat_svg(a), f"{ROOT}/art/src/acessorios/{a}.svg", f"{OUT}/acc_{a}.png", 128, 128, K)
    # personalização: corpo neutro (pintado pela Godot), detalhes, padrões, chapéus, rosto, ferramentas
    for model in MODELS:
        queue(body_svg(model, 0, NEUTRAL, details=False), f"{SRC}/corpo_{model}.svg", f"{OUT}/corpo_{model}.png", 128, 128, K)
        queue(detail_svg(model), f"{SRC}/detalhe_{model}.svg", f"{OUT}/detalhe_{model}.png", 128, 128, K)
        for pat in ("listras", "bolinhas", "manchas", "raio"):
            queue(pattern_svg(model, pat), f"{SRC}/padrao_{pat}_{model}.svg", f"{OUT}/padrao_{pat}_{model}.png", 128, 128, K)
    for a in ("cartola", "coroa", "cowboy", "chef", "viking", "helice", "laco", "fone", "pirata", "flor", "cone", "balde"):
        queue(hat_svg2(a), f"{ROOT}/art/src/acessorios/{a}.svg", f"{OUT}/acc_{a}.png", 128, 128, K)
    for f in ("oculos_sol", "oculos_solda", "bigode", "tapa_olho", "oculos_redondos"):
        queue(face_item_svg(f), f"{ROOT}/art/src/acessorios/rosto_{f}.svg", f"{OUT}/rosto_item_{f}.png", 64, 32, K)
    for tl in ("picareta", "chave_inglesa", "frigideira", "martelo_borracha", "desentupidor"):
        queue(tool_svg(tl), f"{SRC}/ferramenta_{tl}.svg", f"{OUT}/ferramenta_{tl}.png", 64, 64, K)
    os.makedirs(OUT, exist_ok=True)
    meta = {"cores": COLORS, "membros": [shade(c, -0.5) for c in COLORS],
            "modelos": {k: {kk: v[kk] for kk in ("hips", "shoulders", "hand_back", "hand_front", "hat", "antenna", "eyes")} for k, v in MODELS.items()}}
    with open(f"{OUT}/modelos.json", "w") as f:
        json.dump(meta, f, indent=1)
    print("robôs renderizados:", render_all())


if __name__ == "__main__":
    main()
