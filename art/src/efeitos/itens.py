"""Ícones dos itens do Modo Festa (estilo papel e giz): dinamite, martelão, capacete de aço, botas de mola.
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


def martelao():
    b = [f'<path d="M22,58 L27,58 L40,24 L35,22 Z" fill="#b07a3d"/>',
         shape("h", "M20,8 L56,20 L50,36 L14,24 Z", "#f2c84b", 21, (12, 6, 58, 38), k=1.3),
         '<path d="M20,8 L56,20 L54.5,24 L18.8,12 Z" fill="#ffe08a" opacity="0.9"/>',
         '<path d="M30,12 L25,27 M40,15 L35,30" stroke="#c99a28" stroke-width="2"/>']
    return wrap("".join(b), 2)


def capacete():
    b = [shape("c", "M12,42 C12,20 24,12 32,12 C40,12 52,20 52,42 Z", "#c4ccd2", 31, (10, 10, 54, 44), k=1.3),
         '<path d="M6,42 Q32,36 58,42 L57,49 Q32,44 7,49 Z" fill="#aab4bc"/>',
         '<path d="M28,13 L36,13 L37,41 L27,41 Z" fill="#9aa4ae"/>',
         '<path d="M18,30 Q20,20 27,16" stroke="#ffffff" stroke-width="3" fill="none" stroke-linecap="round"/>']
    return wrap("".join(b), 3)


def mola():
    b = [shape("b", "M16,10 L36,10 L38,28 L50,30 C54,31 54,38 50,38 L16,38 Z", "#4f5a68", 41, (14, 8, 56, 40), k=1.2),
         '<rect x="14" y="36" width="40" height="4" fill="#2f3640"/>']
    for i, y in enumerate((44, 49, 54)):
        b.append(f'<ellipse cx="34" cy="{y}" rx="13" ry="2.6" fill="none" stroke="#aab4bc" stroke-width="2.8"/>')
    b.append('<rect x="18" y="57" width="32" height="4" fill="#5cc45c"/>')
    return wrap("".join(b), 4)


def main():
    for name, fn in (("dinamite", dinamite), ("martelao", martelao), ("capacete", capacete), ("mola", mola)):
        queue(fn(), f"{SRC}/item_{name}.svg", f"{OUT}/{name}.png", 64, 64, K)
    print("itens:", render_all())


if __name__ == "__main__":
    main()
