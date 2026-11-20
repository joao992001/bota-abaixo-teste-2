"""Robôs de Bota-Abaixo: corpo por cor, 5 rostos, pés, mão, marreta e 3 acessórios.

Todas as partes de corpo/rosto/acessório usam a mesma tela 128x128 (unidades = px de jogo),
com origem do robô (centro entre os pés, no chão) em (64,120). Exporta em 2x para o jogo.
Rodar: python3 art/src/robos/robos.py
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from svg import INK, PLAYER, doc, save, shade, symbol  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.."))
SRC = os.path.join(ROOT, "art/src/robos")
OUT = os.path.join(ROOT, "art/out/game/robo")
W = H = 128
SCALE = 2

# formas-base (cabeça grande em feijão + corpinho)
HEAD = "M36,62 C36,40 48,33 64,33 C82,33 93,41 93,61 C93,80 84,88 64,88 C45,88 36,81 36,62 Z"
BODY = "M46,86 C46,82 50,80 64,80 C78,80 82,82 82,88 L82,104 C82,110 78,112 64,112 C50,112 46,110 46,104 Z"


def body_svg(ci):
    col = PLAYER[ci]
    dark = shade(col, -0.32)
    light = shade(col, 0.55)
    defs = (f'<clipPath id="hc"><path d="{HEAD}"/></clipPath>'
            f'<clipPath id="bc"><path d="{BODY}"/></clipPath>')
    b = []
    # parafusos laterais (orelhas de robô) atrás da cabeça
    for x in (34, 95):
        b.append(f'<rect x="{x - 7}" y="54" width="14" height="16" rx="5" fill="#9aa3af" stroke="{INK}" stroke-width="5"/>')
    # contorno unificado (traço grosso por baixo)
    b.append(f'<path d="{BODY}" fill="{INK}" stroke="{INK}" stroke-width="12" stroke-linejoin="round"/>')
    b.append(f'<path d="{HEAD}" fill="{INK}" stroke="{INK}" stroke-width="12" stroke-linejoin="round"/>')
    # corpo: sombra chapada + base deslocada
    b.append(f'<g clip-path="url(#bc)"><rect x="40" y="76" width="50" height="40" fill="{dark}"/>'
             f'<path d="{BODY}" transform="translate(-6,-4)" fill="{col}"/></g>')
    # painel do peito com símbolo
    b.append(f'<rect x="55" y="90" width="18" height="15" rx="5" fill="{light}" stroke="{INK}" stroke-width="2.5"/>')
    b.append(symbol(ci, 64, 97.5, 4.6))
    # cabeça
    b.append(f'<g clip-path="url(#hc)"><rect x="30" y="28" width="70" height="66" fill="{dark}"/>'
             f'<path d="{HEAD}" transform="translate(-7,-6)" fill="{col}"/></g>')
    # brilho branco chapado
    b.append('<path d="M44,52 C45,44 50,40 57,39" fill="none" stroke="#ffffff" stroke-width="5" stroke-linecap="round"/>')
    b.append('<circle cx="42.5" cy="58" r="2.6" fill="#ffffff"/>')
    # costura do capô
    b.append(f'<path d="M50,35.5 C58,33 70,33 78,35.5" fill="none" stroke="{dark}" stroke-width="2.5" stroke-linecap="round"/>')
    return doc(W, H, "".join(b), defs)


def eye(cx, cy, rx, ry, px, py, pr):
    return (f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="#ffffff" stroke="{INK}" stroke-width="3.5"/>'
            f'<circle cx="{cx + px}" cy="{cy + py}" r="{pr}" fill="{INK}"/>'
            f'<circle cx="{cx + px + pr * 0.35}" cy="{cy + py - pr * 0.4}" r="{pr * 0.32}" fill="#ffffff"/>')


def face_svg(expr):
    L, R, Y = 57, 76, 59  # olhos (olhando para a direita)
    b = []
    if expr == "normal":
        b += [eye(L, Y, 8.5, 11, 2.5, 1, 4.6), eye(R, Y, 8.5, 11, 2.5, 1, 4.6)]
        b.append(f'<path d="M62,76 Q68,81 74,75.5" fill="none" stroke="{INK}" stroke-width="3.5" stroke-linecap="round"/>')
    elif expr == "esforco":
        b += [eye(L, Y + 1, 8.5, 10, 3, 2, 4.4), eye(R, Y + 1, 8.5, 10, 3, 2, 4.4)]
        # pálpebras de esforço
        b.append(f'<path d="M47,52 L67,57" stroke="{INK}" stroke-width="5" stroke-linecap="round"/>')
        b.append(f'<path d="M86,51 L67,57" stroke="{INK}" stroke-width="5" stroke-linecap="round"/>')
        b.append(f'<rect x="59" y="73" width="19" height="9" rx="3" fill="#ffffff" stroke="{INK}" stroke-width="3"/>')
        b.append(f'<path d="M63.5,73 V82 M68.5,73 V82 M73.5,73 V82" stroke="{INK}" stroke-width="1.8"/>')
    elif expr == "susto":
        b += [eye(L - 1, Y - 2, 10, 13, 1, -1, 3), eye(R + 1, Y - 2, 10, 13, 1, -1, 3)]
        b.append(f'<path d="M48,42 Q55,37 62,41" fill="none" stroke="{INK}" stroke-width="3.5" stroke-linecap="round"/>')
        b.append(f'<path d="M71,41 Q78,37 85,42" fill="none" stroke="{INK}" stroke-width="3.5" stroke-linecap="round"/>')
        b.append(f'<ellipse cx="68" cy="79" rx="5" ry="6.5" fill="{INK}"/>')
    elif expr == "vitoria":
        for cx in (L, R):
            b.append(f'<path d="M{cx - 7},{Y + 3} Q{cx},{Y - 8} {cx + 7},{Y + 3}" fill="none" stroke="{INK}" stroke-width="4.5" stroke-linecap="round"/>')
        b.append(f'<path d="M58,72 Q68,72 79,71 Q77,85 68,85 Q60,85 58,72 Z" fill="{INK}"/>')
        b.append('<path d="M62,79 Q68,77 74,79 Q72,83 68,83 Q64,83 62,79 Z" fill="#ff9fb8"/>')
    elif expr == "eliminado":
        for cx in (L, R):
            b.append(f'<path d="M{cx - 6},{Y - 6} L{cx + 6},{Y + 6} M{cx - 6},{Y + 6} L{cx + 6},{Y - 6}" stroke="{INK}" stroke-width="4.5" stroke-linecap="round"/>')
        b.append(f'<path d="M58,79 Q61,75 64,79 T70,79 T76,79" fill="none" stroke="{INK}" stroke-width="3.5" stroke-linecap="round"/>')
    return doc(W, H, "".join(b))


def foot_svg():
    # 32x20, pivô no centro do topo (16,4)
    return doc(32, 20, f'<ellipse cx="16" cy="11" rx="12" ry="7" fill="#4a4f5c" stroke="{INK}" stroke-width="4.5"/>'
                       f'<path d="M9,8.5 Q14,6.5 19,7.5" stroke="#8d97a6" stroke-width="2.4" fill="none" stroke-linecap="round"/>')


def hand_svg():
    # 24x24, pivô no centro
    return doc(24, 24, f'<circle cx="12" cy="12" r="7.5" fill="#eef1f5" stroke="{INK}" stroke-width="4"/>'
                       f'<path d="M8.5,10 Q10,7.5 13,7.5" stroke="#ffffff" stroke-width="2" fill="none"/>')


def hammer_svg():
    # 64x64, cabo na vertical, pega em (32,54)
    return doc(64, 64, (
        f'<rect x="27.5" y="16" width="9" height="44" rx="4" fill="#c98b4e" stroke="{INK}" stroke-width="4.5"/>'
        f'<path d="M30,22 V55" stroke="#e5ad73" stroke-width="2.4" stroke-linecap="round"/>'
        f'<rect x="8" y="3" width="48" height="23" rx="6" fill="#9aa3af" stroke="{INK}" stroke-width="5"/>'
        f'<rect x="40" y="5.5" width="13" height="18" rx="3" fill="#6f7886"/>'
        f'<path d="M14,9 H34" stroke="#ffffff" stroke-width="3.2" stroke-linecap="round"/>'
        f'<rect x="25" y="1" width="14" height="27" rx="3" fill="none" stroke="{INK}" stroke-width="3"/>'))


def acc_svg(name):
    b = []
    if name == "capacete":
        b.append(f'<path d="M37,47 C37,28 50,21 65,21 C80,21 92,28 92,47 Z" fill="#ffc21a" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/>')
        b.append(f'<path d="M30,48 Q64,40 99,48 Q100,55 94,55 Q64,49 34,55 Q28,54 30,48 Z" fill="#ffc21a" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/>')
        b.append(f'<path d="M58,22 Q57,34 58,45 L71,45 Q72,34 71,22" fill="#e09c00" stroke="{INK}" stroke-width="3"/>')
        b.append('<path d="M43,38 Q45,30 52,26" stroke="#fff3c4" stroke-width="4" fill="none" stroke-linecap="round"/>')
    elif name == "bone":  # boné virado: aba para trás (esquerda)
        b.append(f'<path d="M14,47 Q22,40 42,42 L44,49 Q28,51 16,53 Q11,51 14,47 Z" fill="#4b3fa8" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/>')
        b.append(f'<path d="M38,49 C38,30 50,24 65,24 C80,24 91,31 91,49 Q64,44 38,49 Z" fill="#6c5ce7" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/>')
        b.append(f'<path d="M64,25 V45" stroke="{INK}" stroke-width="2.4"/>')
        b.append(f'<circle cx="64" cy="24" r="3.5" fill="#6c5ce7" stroke="{INK}" stroke-width="2.5"/>')
        b.append('<path d="M45,40 Q47,32 54,29" stroke="#a79ef5" stroke-width="3.5" fill="none" stroke-linecap="round"/>')
        b.append(f'<rect x="72" y="33" width="13" height="8" rx="2" fill="#ffffff" stroke="{INK}" stroke-width="2"/>')
    elif name == "gorro":
        b.append(f'<path d="M39,46 C37,27 50,19 64,19 C79,19 91,27 89,46 Z" fill="#ff8a3d" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/>')
        for x in (52, 64, 76):
            b.append(f'<path d="M{x},23 Q{x - 1},34 {x},44" stroke="#e0662a" stroke-width="3" fill="none"/>')
        b.append(f'<rect x="35" y="41" width="58" height="13" rx="6" fill="#f2f2f2" stroke="{INK}" stroke-width="5"/>')
        for x in range(42, 90, 7):
            b.append(f'<path d="M{x},44 V51" stroke="#c9ced6" stroke-width="2.4"/>')
        b.append(f'<circle cx="66" cy="15" r="8.5" fill="#f2f2f2" stroke="{INK}" stroke-width="5"/>')
        b.append('<circle cx="63.5" cy="12.5" r="2.6" fill="#ffffff"/>')
    return doc(W, H, "".join(b))


def main():
    for ci in range(4):
        save(body_svg(ci), f"{SRC}/svg/corpo_p{ci + 1}.svg", f"{OUT}/corpo_p{ci + 1}.png", SCALE)
    for e in ("normal", "esforco", "susto", "vitoria", "eliminado"):
        save(face_svg(e), f"{SRC}/svg/rosto_{e}.svg", f"{OUT}/rosto_{e}.png", SCALE)
    save(foot_svg(), f"{SRC}/svg/pe.svg", f"{OUT}/pe.png", SCALE)
    save(hand_svg(), f"{SRC}/svg/mao.svg", f"{OUT}/mao.png", SCALE)
    save(hammer_svg(), f"{SRC}/svg/marreta.svg", f"{OUT}/marreta.png", SCALE)
    for a in ("capacete", "bone", "gorro"):
        save(acc_svg(a), f"{ROOT}/art/src/acessorios/{a}.svg", f"{OUT}/acc_{a}.png", SCALE)
    print("robôs gerados em", OUT)


if __name__ == "__main__":
    main()
