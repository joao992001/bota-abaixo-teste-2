"""Objetos dos modos (estilo papel e giz): a dinamite da Batata-Dinamite e o capacete de ouro do Rei da Obra.
(Os itens antigos foram removidos em 2026-11-24; spells ficam em art/src/efeitos/spells.py.)
Rodar: python3 art/src/efeitos/itens.py
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from papel import ellipse_d, rect_d, rough, shape  # noqa: E402
from svg import doc, queue, render_all  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.."))
SRC = os.path.join(ROOT, "art/src/efeitos/svg")
OUT = os.path.join(ROOT, "art/out/game/itens")
K = 3


def wrap(body, seed):
    return doc(64, 64, f'<g filter="url(#rough)">{body}</g>', rough(seed=seed, scale=0.8, freq=0.09))


def dinamite():
    b = []
    for i, x in enumerate((18, 28, 38)):
        b.append(shape(f"s{i}", rect_d(x, 22, 10, 34, 3), "#d14d35", 10 + i, (x - 2, 20, x + 12, 58), k=1.2))
    b.append(f'<rect x="16" y="34" width="34" height="7" fill="#3e4752"/>')
    b.append('<path d="M33,22 C33,14 40,14 42,10 C44,6 48,8 50,6" stroke="#5a4632" stroke-width="2.2" fill="none" stroke-linecap="round"/>')
    b.append('<path d="M50,6 l3,-3 M50,6 l4,1 M50,6 l1,-4 M50,6 l-1,-3" stroke="#f2c84b" stroke-width="2" stroke-linecap="round"/>')
    b.append('<circle cx="50" cy="6" r="2.4" fill="#ffffff"/>')
    return wrap("".join(b), 1)


def capacete():
    b = [shape("c", "M12,42 C12,20 24,12 32,12 C40,12 52,20 52,42 Z", "#c4ccd2", 31, (10, 10, 54, 44), k=1.3),
         '<path d="M6,42 Q32,36 58,42 L57,49 Q32,44 7,49 Z" fill="#aab4bc"/>',
         '<path d="M28,13 L36,13 L37,41 L27,41 Z" fill="#9aa4ae"/>',
         '<path d="M18,30 Q20,20 27,16" stroke="#ffffff" stroke-width="3" fill="none" stroke-linecap="round"/>']
    return wrap("".join(b), 3)



def main():
    for name, fn in (("dinamite", dinamite), ("capacete", capacete)):
        queue(fn(), f"{SRC}/item_{name}.svg", f"{OUT}/{name}.png", 64, 64, K)
    print("objetos:", render_all())


if __name__ == "__main__":
    main()
