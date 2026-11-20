"""Robôs v2 (traço da ref1/ref4): contorno preto fino com traço de mão, cabeça grande, corpo pequeno,
olhos ovais com pupila, sombra chapada suave e tinta. Pernas e braços finos são desenhados pela Godot
(cut-out com membros de "macarrão"); aqui saem cabeça+corpo, antena, rostos, pé, mão, marreta, acessórios.
Tela das partes: 128x128 (px de jogo), origem do robô (pés no chão) em (64,120). Exporta em 4x.
Rodar: python3 art/src/robos/robos.py
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from svg import OUTLINE, PLAYER, doc, filters, queue, render_all, shade, symbol  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.."))
SRC = os.path.join(ROOT, "art/src/robos/svg")
OUT = os.path.join(ROOT, "art/out/game/robo")
K = 4
O = OUTLINE
SW = 3.2  # contorno do personagem (px de jogo)

HEAD = "M37,58 C36,40 46,31 64,31 C83,31 93,40 92,57 C91,74 84,83 64,83 C45,83 38,75 37,58 Z"
BODY = "M53,86 C53,81 57,79 64,79 C72,79 76,81 76,87 L77,97 C77,102 72,104 64,104 C56,104 52,102 52,97 Z"


def part(body, seed, wob=0.8):
    return doc(128, 128, body, filters(seed, wobble=wob, grain=0.05, blotch=0.10))


def body_svg(ci):
    col = PLAYER[ci]
    dark = shade(col, -0.24)
    defs_clip = (f'<clipPath id="hc"><path d="{HEAD}"/></clipPath><clipPath id="bc"><path d="{BODY}"/></clipPath>')
    fills = (f'<path d="{BODY}" fill="{dark}"/><g clip-path="url(#bc)"><path d="{BODY}" transform="translate(-4,-3)" fill="{col}"/></g>'
             f'<path d="{HEAD}" fill="{dark}"/><g clip-path="url(#hc)"><path d="{HEAD}" transform="translate(-6,-5)" fill="{col}"/></g>')
    lines = (f'<path d="{BODY}" fill="none" stroke="{O}" stroke-width="{SW}"/>'
             f'<path d="{HEAD}" fill="none" stroke="{O}" stroke-width="{SW}"/>'
             # parafusos laterais e painel do peito
             f'<circle cx="37" cy="60" r="4" fill="#a7afbb" stroke="{O}" stroke-width="2.4"/>'
             f'<circle cx="92" cy="59" r="4" fill="#a7afbb" stroke="{O}" stroke-width="2.4"/>'
             f'<rect x="58" y="85" width="13" height="11" rx="3.5" fill="{shade(col, 0.5)}" stroke="{O}" stroke-width="2"/>'
             + symbol(ci, 64.5, 90.5, 3.3, O) +
             # brilho chapado e costura do capô
             '<path d="M45,49 C46,42 50,38 56,37" fill="none" stroke="#ffffff" stroke-width="3.2" stroke-linecap="round" opacity="0.9"/>'
             f'<path d="M52,34 C59,32.5 69,32.5 76,34" fill="none" stroke="{dark}" stroke-width="1.8" stroke-linecap="round"/>')
    return doc(128, 128, f'<defs>{defs_clip}</defs><g filter="url(#paint)">{fills}</g><g filter="url(#wob)">{lines}</g>',
               filters(60 + ci, wobble=0.8, grain=0.05, blotch=0.12))


def antenna_svg():
    return part(f'<g filter="url(#wob)"><path d="M70,32 Q72,24 76,19" fill="none" stroke="{O}" stroke-width="2.6" stroke-linecap="round"/>'
                f'<circle cx="77" cy="17" r="4.2" fill="#ffd23f" stroke="{O}" stroke-width="2.4"/>'
                f'<circle cx="75.8" cy="15.6" r="1.2" fill="#ffffff"/></g>', 70)


def eye(cx, cy, rx, ry, px, py, pr):
    return (f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="#ffffff" stroke="{O}" stroke-width="2.4"/>'
            f'<circle cx="{cx + px}" cy="{cy + py}" r="{pr}" fill="{O}"/>'
            f'<circle cx="{cx + px + pr * 0.35}" cy="{cy + py - pr * 0.45}" r="{pr * 0.3}" fill="#ffffff"/>')


def face_svg(expr):
    L, R, Y = 58, 75, 55
    b = []
    if expr == "normal":
        b += [eye(L, Y, 6.5, 8, 2, 1, 3.3), eye(R, Y, 6.5, 8, 2, 1, 3.3)]
        b.append(f'<path d="M63,70 Q68,74 73,69.5" fill="none" stroke="{O}" stroke-width="2.6" stroke-linecap="round"/>')
    elif expr == "esforco":
        b += [eye(L, Y + 1, 6.5, 7, 2.5, 1.5, 3.2), eye(R, Y + 1, 6.5, 7, 2.5, 1.5, 3.2)]
        b.append(f'<path d="M50,47.5 L65,51.5 M83,46.5 L68,51.5" stroke="{O}" stroke-width="3.4" stroke-linecap="round"/>')
        b.append(f'<rect x="61" y="66" width="15" height="7" rx="2.5" fill="#ffffff" stroke="{O}" stroke-width="2.2"/>')
        b.append(f'<path d="M65,66 V73 M68.5,66 V73 M72,66 V73" stroke="{O}" stroke-width="1.3"/>')
    elif expr == "susto":
        b += [eye(L - 1, Y - 2, 7.8, 9.8, 0.5, -1, 2.2), eye(R + 1, Y - 2, 7.8, 9.8, 0.5, -1, 2.2)]
        b.append(f'<path d="M50,41 Q56,37 62,40 M71,40 Q77,37 83,41" fill="none" stroke="{O}" stroke-width="2.6" stroke-linecap="round"/>')
        b.append(f'<ellipse cx="68" cy="72" rx="4" ry="5" fill="{O}"/>')
    elif expr == "vitoria":
        for cx in (L, R):
            b.append(f'<path d="M{cx - 5.5},{Y + 2} Q{cx},{Y - 6} {cx + 5.5},{Y + 2}" fill="none" stroke="{O}" stroke-width="3.2" stroke-linecap="round"/>')
        b.append(f'<path d="M59,66 Q68,66.5 77,65.5 Q75,78 68,78 Q61,78 59,66 Z" fill="{O}"/>')
        b.append('<path d="M62.5,72.5 Q68,70.5 73.5,72.5 Q72,76.5 68,76.5 Q64,76.5 62.5,72.5 Z" fill="#ff9fb8"/>')
    elif expr == "eliminado":
        for cx in (L, R):
            b.append(f'<path d="M{cx - 5},{Y - 5} L{cx + 5},{Y + 5} M{cx - 5},{Y + 5} L{cx + 5},{Y - 5}" stroke="{O}" stroke-width="3.2" stroke-linecap="round"/>')
        b.append(f'<path d="M59,71 Q62,67.5 65,71 T71,71 T77,71" fill="none" stroke="{O}" stroke-width="2.6" stroke-linecap="round"/>')
    return part(f'<g filter="url(#wob)">{"".join(b)}</g>', 80)


def foot_svg():
    # 24x16, centro em (12,8): bota de obra
    return doc(24, 16, f'<g filter="url(#paint)"><path d="M4,12 C3,6 7,3 12,3 C18,3 21,7 21,12 Z" fill="#4a4f5c"/></g>'
                       f'<g filter="url(#wob)"><path d="M3,12.5 C2.5,5.5 7,2.5 12,2.5 C18,2.5 21.5,6.5 21.5,12.5 Z" fill="none" stroke="{O}" stroke-width="2.4"/>'
                       f'<path d="M2.5,12.5 H21.5" stroke="{O}" stroke-width="2.4"/><path d="M8,6.5 Q11,5 14,5.5" stroke="#8d97a6" stroke-width="1.6" fill="none"/></g>',
               filters(90, wobble=0.5))


def hand_svg():
    return doc(16, 16, f'<circle cx="8" cy="8" r="5" fill="#eef1f5" stroke="{O}" stroke-width="2.4"/>'
                       '<path d="M5.5,6.8 Q6.5,5 8.5,5" stroke="#ffffff" stroke-width="1.4" fill="none"/>')


def hammer_svg():
    # 64x64, cabo vertical, pega em (32,56); cabeça exagerada
    return doc(64, 64, (
        '<g filter="url(#paint)"><rect x="28.5" y="18" width="7" height="44" rx="3" fill="#c98b4e"/>'
        '<rect x="5" y="2" width="54" height="24" rx="6" fill="#9aa3af"/><rect x="42" y="4" width="15" height="20" rx="3" fill="#717a88"/></g>'
        f'<g filter="url(#wob)" fill="none"><rect x="28.5" y="18" width="7" height="44" rx="3" stroke="{O}" stroke-width="2.6"/>'
        '<path d="M31,24 V57" stroke="#e5ad73" stroke-width="1.8" stroke-linecap="round"/>'
        f'<rect x="5" y="2" width="54" height="24" rx="6" stroke="{O}" stroke-width="3"/>'
        '<path d="M11,7.5 H32" stroke="#ffffff" stroke-width="2.6" stroke-linecap="round"/>'
        f'<path d="M25,2 V26 M39,2 V26" stroke="{O}" stroke-width="2"/></g>'), filters(91, wobble=0.6))


def acc_svg(name):
    b = []
    if name == "capacete":
        b.append(f'<path d="M39,45 C39,26 51,19 65,19 C79,19 91,26 91,45 Z" fill="#ffc21a" stroke="{O}" stroke-width="{SW}" stroke-linejoin="round"/>')
        b.append(f'<path d="M31,46 Q64,38 99,46 Q100,52 95,52.5 Q64,47 35,52.5 Q30,52 31,46 Z" fill="#ffc21a" stroke="{O}" stroke-width="{SW}" stroke-linejoin="round"/>')
        b.append(f'<path d="M59,20 Q58,32 59,44 L71,44 Q72,32 71,20" fill="#e09c00" stroke="{O}" stroke-width="2.2"/>')
        b.append('<path d="M45,37 Q47,29 53,25" stroke="#fff3c4" stroke-width="3" fill="none" stroke-linecap="round"/>')
    elif name == "bone":
        b.append(f'<path d="M16,45 Q24,38 42,40 L44,47 Q29,49 18,51 Q13,49 16,45 Z" fill="#4b3fa8" stroke="{O}" stroke-width="{SW}" stroke-linejoin="round"/>')
        b.append(f'<path d="M39,47 C39,29 51,22 65,22 C80,22 90,29 90,47 Q64,42 39,47 Z" fill="#6c5ce7" stroke="{O}" stroke-width="{SW}" stroke-linejoin="round"/>')
        b.append(f'<path d="M64,23 V43" stroke="{O}" stroke-width="1.8"/><circle cx="64" cy="22.5" r="3" fill="#6c5ce7" stroke="{O}" stroke-width="2"/>')
        b.append('<path d="M46,38 Q48,31 54,28" stroke="#a79ef5" stroke-width="3" fill="none" stroke-linecap="round"/>')
        b.append(f'<rect x="72" y="31" width="12" height="7" rx="2" fill="#ffffff" stroke="{O}" stroke-width="1.6"/>')
    elif name == "gorro":
        b.append(f'<path d="M40,44 C38,26 51,18 64,18 C78,18 90,26 88,44 Z" fill="#ff8a3d" stroke="{O}" stroke-width="{SW}" stroke-linejoin="round"/>')
        for x in (52, 64, 76):
            b.append(f'<path d="M{x},22 Q{x - 1},33 {x},42" stroke="#de6a2c" stroke-width="2.2" fill="none"/>')
        b.append(f'<rect x="36" y="40" width="56" height="12" rx="5.5" fill="#f2f2f2" stroke="{O}" stroke-width="{SW}"/>')
        for x in range(42, 90, 6):
            b.append(f'<path d="M{x},43 V49" stroke="#c9ced6" stroke-width="1.8"/>')
        b.append(f'<circle cx="66" cy="14" r="7.5" fill="#f2f2f2" stroke="{O}" stroke-width="{SW}"/><circle cx="63.8" cy="11.8" r="2" fill="#ffffff"/>')
    return doc(128, 128, f'<g filter="url(#paint)"><g filter="url(#wob)">{"".join(b)}</g></g>', filters(95, wobble=0.7, grain=0.04))


def main():
    for ci in range(4):
        queue(body_svg(ci), f"{SRC}/corpo_p{ci + 1}.svg", f"{OUT}/corpo_p{ci + 1}.png", 128, 128, K)
    queue(antenna_svg(), f"{SRC}/antena.svg", f"{OUT}/antena.png", 128, 128, K)
    for e in ("normal", "esforco", "susto", "vitoria", "eliminado"):
        queue(face_svg(e), f"{SRC}/rosto_{e}.svg", f"{OUT}/rosto_{e}.png", 128, 128, K)
    queue(foot_svg(), f"{SRC}/pe.svg", f"{OUT}/pe.png", 24, 16, K)
    queue(hand_svg(), f"{SRC}/mao.svg", f"{OUT}/mao.png", 16, 16, K)
    queue(hammer_svg(), f"{SRC}/marreta.svg", f"{OUT}/marreta.png", 64, 64, K)
    for a in ("capacete", "bone", "gorro"):
        queue(acc_svg(a), f"{ROOT}/art/src/acessorios/{a}.svg", f"{OUT}/acc_{a}.png", 128, 128, K)
    print("robôs renderizados:", render_all())


if __name__ == "__main__":
    main()
