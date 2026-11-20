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
                 hat=[64, 42, 0.42], eyes=[[60, 52], [68.5, 51.5]], eye_r=2.3, mouth=[64, 59], screen=False),
    "tv": dict(hips=[[60, 86], [68, 86]], shoulders=[[57, 71], [71, 71]], hand_back=[45, 82], hand_front=[83, 74],
               hat=[64, 35, 0.68], eyes=[[58, 47], [70, 47]], eye_r=2.6, mouth=[64, 54], screen=True),
    "baixinho": dict(hips=[[60, 95], [68, 95]], shoulders=[[57, 85], [71, 85]], hand_back=[44, 88], hand_front=[86, 80],
                     hat=[64, 40, 0.82], eyes=[[57, 62], [70, 61]], eye_r=3.0, mouth=[64, 72], screen=False),
    "pescocao": dict(hips=[[58, 92], [70, 92]], shoulders=[[54, 75], [74, 75]], hand_back=[43, 86], hand_front=[85, 70],
                     hat=[65, 33, 0.5], eyes=[[61, 41], [69.5, 40]], eye_r=2.0, mouth=[65, 46], screen=False),
}


def wrap(body, seed):
    return doc(128, 128, f'<g filter="url(#rough)">{body}</g>', rough(seed=seed, scale=0.9, freq=0.12))


def side_shade(cid, d, x, w, col, box):
    """Faixa mais escura no lado direito (volume), recortada na forma."""
    return f'<g clip-path="url(#{cid})"><rect x="{x}" y="{box[1]}" width="{w}" height="{box[3] - box[1]}" fill="{col}"/></g>'


def body_svg(model, ci):
    c = COLORS[ci]
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
        b.append(f'<path d="M48.5,38.5 L79.5,38 L79,62 L49,62.5 Z" fill="{SCREEN}"/>')
    elif model == "baixinho":
        b.append(shape("b1", rect_d(56, 80, 16, 17, 3), mid, s + 2, (54, 78, 74, 98)))
        d = ellipse_d(64, 60, 23, 23)
        b.append(shape("b2", d, dark, s, (40, 36, 88, 84)))
        b.append('<g clip-path="url(#b2)">' + shape("b3", ellipse_d(61, 57.5, 23, 23), c, s + 5, (37, 33, 85, 81)) + '</g>')
        b.append(f'<path d="M47,50 Q52,41 61,39" stroke="{light}" stroke-width="2.2" fill="none" stroke-linecap="round"/>')
    elif model == "pescocao":
        b.append(f'<path d="M64,72 C61,66 67,61 63,56 C60,52 65,50 64,47" stroke="{METAL}" stroke-width="2.2" fill="none" stroke-linecap="round"/>')
        d = rect_d(53, 70, 22, 23, 3)
        b.append(shape("b1", d, c, s, (50, 68, 78, 94)))
        b.append(side_shade("b1", d, 71, 4, dark, (0, 68, 0, 94)))
        b.append(f'<rect x="58" y="77" width="8.5" height="6" rx="1" fill="{YELLOW}"/><circle cx="60.3" cy="80" r="0.9" fill="{RED}"/>')
        hd = "M51,42 C51,34 58,31 66,31 C75,31 80,36 79,43 C78,50 71,52 64,52 C56,52 51,49 51,42 Z"
        b.append(shape("b2", hd, dark, s + 3, (49, 29, 81, 54)))
        hd2 = "M48,40 C48,32 55,29 63,29 C72,29 77,34 76,41 C75,48 68,50 61,50 C53,50 48,47 48,40 Z"
        b.append('<g clip-path="url(#b2)">' + shape("b3", hd2, c, s + 6, (46, 27, 78, 52)) + '</g>')
    return wrap("".join(b), 100 + s)


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

    if expr == "normal":
        b += [eye(lx, ly, er), eye(rx, ry, er)]
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
        for e in ("normal", "esforco", "susto", "vitoria", "eliminado"):
            queue(face_svg(model, e), f"{SRC}/rosto_{model}_{e}.svg", f"{OUT}/rosto_{model}_{e}.png", 128, 128, K)
    queue(hand_svg(), f"{SRC}/mao.svg", f"{OUT}/mao.png", 16, 16, K)
    queue(foot_svg(), f"{SRC}/pe.svg", f"{OUT}/pe.png", 24, 14, K)
    queue(hammer_svg(), f"{SRC}/marreta.svg", f"{OUT}/marreta.png", 64, 64, K)
    for a in ("capacete", "bone", "gorro"):
        queue(hat_svg(a), f"{ROOT}/art/src/acessorios/{a}.svg", f"{OUT}/acc_{a}.png", 128, 128, K)
    os.makedirs(OUT, exist_ok=True)
    meta = {"cores": COLORS, "membros": [shade(c, -0.5) for c in COLORS],
            "modelos": {k: {kk: v[kk] for kk in ("hips", "shoulders", "hand_back", "hand_front", "hat")} for k, v in MODELS.items()}}
    with open(f"{OUT}/modelos.json", "w") as f:
        json.dump(meta, f, indent=1)
    print("robôs renderizados:", render_all())


if __name__ == "__main__":
    main()
