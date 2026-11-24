"""Robôs v3 — exatamente o estilo de versoes.png (referência do usuário): papel recortado sem contorno,
textura de giz, membros grossos mais escuros (desenhados pela Godot), mãos de luva brancas.
8 modelos (só visual; a hitbox é a mesma): Lata, TV, Baixinho, Pescoção, Brutamontes, Varapau, Barril e Bolha,
nas 4 cores de jogador. Sem personalização: o modelo é a identidade do robô.
Tela das partes 128x128 (px de jogo), origem do robô (pés no chão) em (64,120). Exporta em 4x.
Gera também art/out/game/robo/modelos.json (nome, quadris, ombros, mãos, topo, grossura dos membros) lido pela Godot.
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

# geometria de cada modelo (px de jogo, tela 128x128, pés em y≈117). Só visual: a hitbox é a mesma para todos.
# top = topo da cabeça (setinha P1 fica acima); limb_w = grossura de braços e pernas; hand_s = tamanho da luva.
MODELS = {
    "lata": dict(hat=[64, 42, 0.42], nome="Lata", hips=[[59, 84], [69, 84]], shoulders=[[54, 62], [74, 62]], hand_back=[44, 74], hand_front=[84, 60],
                 antenna=[63, 38], eyes=[[60, 52], [68.5, 51.5]], eye_r=2.3, mouth=[64, 59], screen=False, mouth_s="lingua",
                 top=26, limb_w=3.4, hand_s=1.0, voz=1.0, danca=0),
    "tv": dict(hat=[64, 35, 0.68], nome="TV", hips=[[60, 86], [68, 86]], shoulders=[[57, 71], [71, 71]], hand_back=[45, 82], hand_front=[83, 74],
               antenna=[64, 35], eyes=[[58, 47], [70, 47]], eye_r=2.6, mouth=[64, 54], screen=True, mouth_s="tela",
               top=22, limb_w=3.4, hand_s=1.0, voz=1.18, danca=3),
    "baixinho": dict(hat=[64, 40, 0.82], nome="Baixinho", hips=[[60, 95], [68, 95]], shoulders=[[57, 85], [71, 85]], hand_back=[44, 88], hand_front=[86, 80],
                     antenna=[64, 38], eyes=[[57, 62], [70, 61]], eye_r=3.0, mouth=[64, 72], screen=False, mouth_s="o",
                     top=25, limb_w=3.0, hand_s=0.9, voz=1.4, danca=2),
    "pescocao": dict(hat=[65, 33, 0.5], nome="Pescoção", hips=[[58, 92], [70, 92]], shoulders=[[54, 75], [74, 75]], hand_back=[43, 86], hand_front=[85, 70],
                     antenna=[68, 32], eyes=[[61, 41], [69.5, 40]], eye_r=2.0, mouth=[65, 46], screen=False, mouth_s="sorriso",
                     top=20, limb_w=3.0, hand_s=1.0, voz=0.78, danca=0),
    "brutamontes": dict(hat=[64, 40, 0.4], nome="Brutamontes", hips=[[56, 94], [72, 94]], shoulders=[[42, 60], [86, 60]], hand_back=[32, 82], hand_front=[94, 70],
                        antenna=[64, 41], eyes=[[59.5, 46.5], [68.5, 46.5]], eye_r=1.9, mouth=[64, 52], screen=False, mouth_s="dentes",
                        top=34, limb_w=6.2, hand_s=1.45, voz=0.66, danca=1),
    "varapau": dict(hat=[64, 16, 0.38], nome="Varapau", hips=[[60, 70], [68, 70]], shoulders=[[57, 40], [71, 40]], hand_back=[48, 62], hand_front=[80, 52],
                    antenna=[64, 12], eyes=[[60.5, 22], [67.5, 22]], eye_r=1.9, mouth=[64, 28], screen=False, mouth_s="sorriso",
                    top=1, limb_w=2.4, hand_s=0.85, voz=0.9, danca=3),
    "barril": dict(hat=[64, 55, 0.66], nome="Barril", hips=[[56, 99], [72, 99]], shoulders=[[45, 74], [83, 74]], hand_back=[36, 90], hand_front=[92, 80],
                   antenna=[70, 52], eyes=[[57, 69], [70, 69]], eye_r=2.6, mouth=[63.5, 79], screen=False, mouth_s="lingua",
                   top=40, limb_w=4.4, hand_s=1.1, voz=1.08, danca=2),
    "bolha": dict(hat=[64, 38, 0.66], nome="Bolha", hips=[[59, 90], [69, 90]], shoulders=[[53, 72], [75, 72]], hand_back=[43, 84], hand_front=[85, 70],
                  antenna=[64, 34], eyes=[[58.5, 49], [69.5, 49]], eye_r=2.7, mouth=[64, 57], screen=False, mouth_s="o",
                  top=22, limb_w=3.0, hand_s=0.95, voz=1.28, danca=1),
}
GLASS, CORE, BAND = "#cdeff7", "#ffe27a", "#5d6b7d"


def wrap(body, seed):
    return doc(128, 128, f'<g filter="url(#rough)">{body}</g>', rough(seed=seed, scale=0.9, freq=0.12))


def side_shade(cid, d, x, w, col, box):
    """Faixa mais escura no lado direito (volume), recortada na forma."""
    return f'<g clip-path="url(#{cid})"><rect x="{x}" y="{box[1]}" width="{w}" height="{box[3] - box[1]}" fill="{col}"/></g>'


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
    elif model == "brutamontes":
        # tronco enorme em trapézio (ombros largos), cabecinha pequena afundada, placa de perigo no peito
        d = "M38,52 C38,46 44,44 50,44 L78,44 C84,44 90,46 90,52 L84,92 C84,96 80,97 76,97 L52,97 C48,97 44,96 44,92 Z"
        b.append(shape("b1", d, c, s, (36, 42, 92, 99)))
        b.append(side_shade("b1", d, 80, 10, dark, (0, 42, 0, 99)))
        hd = rect_d(55, 37, 18, 18, 5)
        b.append(shape("b2", hd, mid, s + 3, (53, 35, 75, 57)))
        b.append(f'<path d="M57,42.5 L71,42.5 L71,50 L57,50 Z" fill="{SCREEN}" opacity="0.18"/>')
        if details:
            b.append(f'<g transform="rotate(-3 64 72)"><rect x="54" y="66" width="20" height="10" rx="1.5" fill="{YELLOW}"/>'
                     f'<path d="M57,76 L61,66 M63,76 L67,66 M69,76 L73,66" stroke="#2a1a2e" stroke-width="2.4"/></g>')
            for x, y in ((44, 52), (84, 52), (49, 89), (79, 89)):
                b.append(f'<circle cx="{x}" cy="{y}" r="1.4" fill="{shade(c, -0.35)}"/>')
    elif model == "varapau":
        # corpo comprido e fino, cabeça pequena no alto; muito mais alto que os outros
        b.append(shape("b1", rect_d(58, 34, 12, 38, 3), c, s, (56, 32, 72, 74)))
        b.append(side_shade("b1", rect_d(58, 34, 12, 38, 3), 67, 3, dark, (0, 32, 0, 74)))
        b.append(f'<path d="M61,31 L67,31 L66.5,35 L61.5,35 Z" fill="{METAL}"/>')
        hd = "M55,22 C55,15 59,13 64,13 C69,13 73,15 73,22 C73,28 69,31 64,31 C59,31 55,28 55,22 Z"
        b.append(shape("b2", hd, c, s + 3, (53, 11, 75, 33)))
        b.append(side_shade("b2", hd, 70, 3, dark, (0, 11, 0, 33)))
        if details:
            for y in (44, 52, 60):
                b.append(f'<path d="M59,{y} H69" stroke="{shade(c, -0.3)}" stroke-width="0.8" opacity="0.7"/>')
    elif model == "barril":
        # barril gordo com cintas de metal, tampa e torneirinha
        d = "M47,56 C42,64 42,90 47,98 C52,101 76,101 81,98 C86,90 86,64 81,56 C76,53 52,53 47,56 Z"
        b.append(shape("b1", d, c, s, (40, 51, 88, 103)))
        b.append(side_shade("b1", d, 77, 11, dark, (0, 51, 0, 103)))
        b.append(f'<g clip-path="url(#b1)"><path d="M40,62 Q64,66 88,62" stroke="{BAND}" stroke-width="3.4" fill="none"/>'
                 f'<path d="M40,92 Q64,96 88,92" stroke="{BAND}" stroke-width="3.4" fill="none"/></g>')
        b.append(shape("b2", ellipse_d(64, 55.5, 17, 3.6), light, s + 1, (45, 51, 83, 60)))
        if details:
            b.append(f'<path d="M83,84 h5 v3 h-2 v3 h-3 Z" fill="{METAL}"/>')
    elif model == "bolha":
        # base em trapézio e cúpula de vidro com um núcleo que brilha
        d = "M50,70 L78,70 L80,92 L48,92 Z"
        b.append(shape("b1", d, c, s, (46, 68, 82, 94)))
        b.append(side_shade("b1", d, 75, 6, dark, (0, 68, 0, 94)))
        b.append(shape("b3", rect_d(46, 64, 36, 8, 3), mid, s + 2, (44, 62, 84, 74)))
        b.append(f'<path d="M45,66 C45,44 52,35 64,35 C76,35 83,44 83,66 Z" fill="{GLASS}" opacity="0.78"/>')
        if details:
            b.append(f'<circle cx="64" cy="81" r="3.6" fill="{CORE}"/><circle cx="64" cy="81" r="6" fill="{CORE}" opacity="0.3"/>')
        b.append('<path d="M50,58 C50,46 55,40 62,38.5" stroke="#ffffff" stroke-width="2.2" fill="none" stroke-linecap="round" opacity="0.85"/>')
    return wrap("".join(b), 100 + s)


def antenna_svg(model):
    def ant(x0, y0, x1, y1, ball):
        return (f'<path d="M{x0},{y0} Q{(x0 + x1) / 2 - 1},{(y0 + y1) / 2} {x1},{y1}" stroke="{METAL}" stroke-width="1.6" fill="none" stroke-linecap="round"/>'
                f'<circle cx="{x1}" cy="{y1 - 1.5}" r="2.6" fill="{ball}"/>')
    b = {"lata": ant(63, 38, 69, 27, YELLOW), "baixinho": ant(64, 38, 67, 26, YELLOW), "pescocao": ant(68, 32, 71, 21, YELLOW),
         "tv": ant(54, 35, 49, 23, RED) + ant(73, 35, 80, 23, YELLOW),
         "brutamontes": f'<rect x="62" y="34" width="4" height="4" fill="{METAL}"/><circle cx="64" cy="33" r="2.4" fill="{RED}"/>',
         "varapau": ant(64, 13, 63, 2, YELLOW), "barril": ant(70, 52, 75, 43, YELLOW), "bolha": ant(64, 35, 64, 26, RED)}[model]
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
        ms = m["mouth_s"]
        if ms == "tela":
            b.append(f'<path d="M{mx - 6},{my - 1} Q{mx},{my + 3} {mx + 6},{my - 1}" stroke="{MINT}" stroke-width="1.6" fill="none" stroke-linecap="round"/>')
        elif ms == "lingua":
            b.append(f'<path d="M{mx - 6},{my - 2} H{mx + 6} Q{mx + 4},{my + 6} {mx},{my + 6} Q{mx - 4},{my + 6} {mx - 6},{my - 2} Z" fill="{MOUTH}"/>')
            b.append(f'<path d="M{mx - 3},{my + 6.4} Q{mx},{my + 5} {mx + 3},{my + 6.2}" stroke="{TONGUE}" stroke-width="1.3" fill="none" stroke-linecap="round"/>')
        elif ms == "o":
            b.append(f'<ellipse cx="{mx}" cy="{my}" rx="3.6" ry="2.7" fill="{MOUTH}"/>')
        elif ms == "dentes":
            b.append(f'<rect x="{mx - 4.5}" y="{my - 1.6}" width="9" height="3.6" rx="0.8" fill="#ffffff"/>'
                     f'<path d="M{mx - 1.5},{my - 1.6} v3.6 M{mx + 1.5},{my - 1.6} v3.6" stroke="#1c2233" stroke-width="0.6"/>'
                     f'<path d="M{mx - 5},{my - 5.5} L{mx - 1},{my - 4} M{mx + 5},{my - 5.5} L{mx + 1},{my - 4}" stroke="#1c2233" stroke-width="1.2" stroke-linecap="round"/>')
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


# ------------------------------------------------------------------ dano (Amassômetro)
# formas do corpo de cada modelo (para recortar o dano) + caixa onde espalhar as marcas
BODY_CLIP = {
    "lata": ([rect_d(53, 40, 22, 45, 4)], (55, 44, 73, 82)),
    "tv": (["M44,35 L84,34 L84.5,66 L44.5,67 Z", rect_d(56, 64, 16, 23, 2)], (46, 37, 82, 84)),
    "baixinho": ([ellipse_d(64, 60, 23, 23), rect_d(56, 80, 16, 17, 3)], (46, 44, 82, 94)),
    "pescocao": ([rect_d(53, 70, 22, 23, 3), "M51,42 C51,34 58,31 66,31 C75,31 80,36 79,43 C78,50 71,52 64,52 C56,52 51,49 51,42 Z"], (52, 33, 77, 91)),
    "brutamontes": (["M38,52 C38,46 44,44 50,44 L78,44 C84,44 90,46 90,52 L84,92 C84,96 80,97 76,97 L52,97 C48,97 44,96 44,92 Z", rect_d(55, 37, 18, 18, 5)], (42, 46, 86, 94)),
    "varapau": ([rect_d(58, 34, 12, 38, 3), "M55,22 C55,15 59,13 64,13 C69,13 73,15 73,22 C73,28 69,31 64,31 C59,31 55,28 55,22 Z"], (57, 15, 71, 70)),
    "barril": (["M47,56 C42,64 42,90 47,98 C52,101 76,101 81,98 C86,90 86,64 81,56 C76,53 52,53 47,56 Z"], (45, 58, 83, 97)),
    "bolha": (["M50,70 L78,70 L80,92 L48,92 Z", rect_d(46, 64, 36, 8, 3), "M45,66 C45,44 52,35 64,35 C76,35 83,44 83,66 Z"], (47, 40, 81, 90)),
}
WIRES = ["#d14d35", "#f2c84b", "#4f86d9"]


def damage_svg(model, lvl):
    import random as _r
    paths, (x0, y0, x1, y1) = BODY_CLIP[model]
    rnd = _r.Random(list(MODELS).index(model) * 7 + 3)
    w, h = x1 - x0, y1 - y0
    pts = lambda: (rnd.uniform(x0 + w * 0.1, x1 - w * 0.1), rnd.uniform(y0 + h * 0.1, y1 - h * 0.1))
    spots = [pts() for _ in range(9)]
    clip = "".join(f'<path d="{d}"/>' for d in paths)
    b = [f'<clipPath id="dc">{clip}</clipPath><g clip-path="url(#dc)">']
    s_ = max(min(w, h) / 30.0, 0.55)
    # estágio 1: amassados (mancha escura + reflexo claro na borda) e riscos
    for (x, y) in spots[:3 + (2 if lvl >= 3 else 0)]:
        rx, ry = rnd.uniform(3.2, 5.2) * s_ * (1.3 if lvl >= 3 else 1.0), rnd.uniform(2.2, 3.6) * s_
        b.append(f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="{rx:.1f}" ry="{ry:.1f}" fill="#2a1a2e" opacity="0.22"/>')
        b.append(f'<path d="M{x - rx:.1f},{y + 0.4:.1f} Q{x:.1f},{y + ry * 1.3:.1f} {x + rx:.1f},{y + 0.4:.1f}" stroke="#ffffff" stroke-width="0.8" fill="none" opacity="0.55"/>')
    for k in range(4):
        x, y = pts()
        l = rnd.uniform(3, 6) * s_
        b.append(f'<path d="M{x:.1f},{y:.1f} l{l:.1f},{rnd.uniform(-1.5, 1.5):.1f}" stroke="#ffffff" stroke-width="0.6" opacity="0.6"/>')
    if lvl >= 2:
        # rachaduras e um remendo de fita adesiva em X
        for (x, y) in spots[5:7]:
            d = f"M{x:.1f},{y:.1f}"
            cx, cy = x, y
            for _ in range(4):
                cx += rnd.uniform(1.5, 3.5) * s_ * rnd.choice([-1, 1])
                cy += rnd.uniform(1.0, 3.0) * s_
                d += f" L{cx:.1f},{cy:.1f}"
            b.append(f'<path d="{d}" stroke="#2a1a2e" stroke-width="1.1" fill="none" stroke-linejoin="round" opacity="0.8"/>')
        tx, ty = spots[7]
        for ang in (35, -35):
            b.append(f'<rect x="{tx - 6 * s_:.1f}" y="{ty - 1.6 * s_:.1f}" width="{12 * s_:.1f}" height="{3.2 * s_:.1f}" fill="#d9d4c4" '
                     f'transform="rotate({ang} {tx:.1f} {ty:.1f})" opacity="0.95"/>')
    if lvl >= 3:
        # buraco com fios aparecendo e fuligem
        hx, hy = spots[8]
        hr = 4.2 * s_
        b.append(f'<ellipse cx="{hx:.1f}" cy="{hy:.1f}" rx="{hr * 1.9:.1f}" ry="{hr * 1.5:.1f}" fill="#2a1a2e" opacity="0.25"/>')
        b.append(f'<path d="M{hx - hr:.1f},{hy:.1f} L{hx - hr * 0.4:.1f},{hy - hr * 0.9:.1f} L{hx + hr * 0.5:.1f},{hy - hr * 0.7:.1f} '
                 f'L{hx + hr:.1f},{hy + 0.2:.1f} L{hx + hr * 0.3:.1f},{hy + hr * 0.9:.1f} L{hx - hr * 0.6:.1f},{hy + hr * 0.7:.1f} Z" fill="#1c1626"/>')
        for k, col in enumerate(WIRES):
            ox = (k - 1) * hr * 0.45
            b.append(f'<path d="M{hx + ox:.1f},{hy:.1f} q{rnd.uniform(-3, 3) * s_:.1f},{3 * s_:.1f} {rnd.uniform(-2, 2) * s_:.1f},{5.5 * s_:.1f}" '
                     f'stroke="{col}" stroke-width="1.1" fill="none" stroke-linecap="round"/>')
    b.append('</g>')
    return wrap("".join(b), 170 + lvl)


def bolt_svg():
    return doc(12, 12, '<g filter="url(#rough)"><circle cx="6" cy="6" r="4.2" fill="#9aa4ae"/><circle cx="6" cy="6" r="1.6" fill="#5d6b7d"/>'
                       '<path d="M3.5,6 H8.5" stroke="#5d6b7d" stroke-width="1"/></g>', rough(seed=17, scale=0.4))


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
    queue(bolt_svg(), f"{SRC}/parafuso.svg", f"{OUT}/parafuso.png", 12, 12, K)
    for model in MODELS:
        for lvl in (1, 2, 3):
            queue(damage_svg(model, lvl), f"{SRC}/dano{lvl}_{model}.svg", f"{OUT}/dano{lvl}_{model}.png", 128, 128, K)
    os.makedirs(OUT, exist_ok=True)
    keys = ("nome", "hat", "hips", "shoulders", "hand_back", "hand_front", "antenna", "eyes", "top", "limb_w", "hand_s", "voz", "danca")
    meta = {"cores": COLORS, "membros": [shade(c, -0.5) for c in COLORS], "ordem": list(MODELS),
            "modelos": {k: {kk: v[kk] for kk in keys} for k, v in MODELS.items()}}
    with open(f"{OUT}/modelos.json", "w") as f:
        json.dump(meta, f, indent=1, ensure_ascii=False)
    print("robôs renderizados:", render_all())


if __name__ == "__main__":
    main()
