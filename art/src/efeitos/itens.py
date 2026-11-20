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


def gancho():
    b = ['<path d="M8,56 C14,46 18,40 26,34" stroke="#c9a26a" stroke-width="3.2" fill="none" stroke-dasharray="5 3" stroke-linecap="round"/>',
         shape("g", "M28,34 L34,28 L38,10 L44,10 L42,30 L48,34 L52,22 L58,24 L54,40 L40,42 L30,40 Z", "#8a96a2", 51, (26, 8, 60, 44), k=1.2),
         '<path d="M38,10 L44,10 L43,16 L38.6,16 Z" fill="#d5dbe1"/>', '<circle cx="34" cy="38" r="3" fill="#3e4752"/>']
    return wrap("".join(b), 51)


def ima():
    b = [shape("m", "M14,14 H28 V36 C28,44 36,44 36,36 V14 H50 V36 C50,58 14,58 14,36 Z", "#d42035", 61, (12, 12, 52, 56), k=1.3),
         '<rect x="14" y="14" width="14" height="9" fill="#d5dbe1"/><rect x="36" y="14" width="14" height="9" fill="#d5dbe1"/>',
         '<path d="M6,10 l5,4 M58,10 l-5,4 M4,22 h6 M60,22 h-6" stroke="#f2c84b" stroke-width="2.6" stroke-linecap="round"/>']
    return wrap("".join(b), 61)


def tabua():
    b = [shape("t", "M6,30 L58,22 L60,34 L8,42 Z", "#d9a35f", 71, (4, 20, 62, 44), k=1.2),
         '<path d="M14,34 L50,28" stroke="#e9bf86" stroke-width="2" stroke-linecap="round"/>',
         '<circle cx="14" cy="37" r="2" fill="#5a6370"/><circle cx="52" cy="29" r="2" fill="#5a6370"/>',
         '<path d="M32,52 v8 M28,56 h8" stroke="#5cc45c" stroke-width="3.5" stroke-linecap="round"/>']
    return wrap("".join(b), 71)


def furadeira():
    b = [shape("f", "M10,18 H40 C46,18 46,34 40,34 H10 Z", "#f2c84b", 81, (8, 16, 48, 36), k=1.2),
         shape("fh", "M18,34 H30 L32,56 H16 Z", "#3e4752", 82, (14, 32, 34, 58), k=1.2),
         '<path d="M44,22 H52 V30 H44 Z" fill="#5a6370"/>',
         '<path d="M52,26 L62,26 M54,22 L58,30 M58,22 L62,30" stroke="#aab4bc" stroke-width="3" stroke-linecap="round"/>',
         '<rect x="14" y="22" width="8" height="5" fill="#ffe08a"/>']
    return wrap("".join(b), 81)


def cola():
    b = [shape("c", "M20,22 H44 V54 C44,58 20,58 20,54 Z", "#f5f3ea", 91, (18, 20, 46, 58), k=1.2, dark="#c9c4b4"),
         '<rect x="20" y="32" width="24" height="12" fill="#4f86d9"/>',
         shape("ct", "M26,10 H38 L36,22 H28 Z", "#f06aa8", 92, (24, 8, 40, 24), k=1.1),
         '<path d="M44,40 C50,42 52,48 50,54 C49,57 46,56 47,52" stroke="#ffffff" stroke-width="3.5" fill="none" stroke-linecap="round"/>']
    return wrap("".join(b), 91)


def foguete():
    b = [shape("bo", "M14,8 L32,8 L34,30 L48,32 C54,33 54,42 48,42 L14,42 Z", "#d42035", 101, (12, 6, 56, 44), k=1.2),
         '<rect x="12" y="40" width="40" height="4" fill="#2f3640"/>',
         shape("fl", "M18,46 L46,46 L40,58 L32,52 L24,60 Z", "#f6a23a", 102, (16, 44, 48, 62), k=1.1),
         '<path d="M26,48 L38,48 L32,56 Z" fill="#fff1b8"/>', '<path d="M16,16 H30" stroke="#ffffff" stroke-width="3" stroke-linecap="round"/>']
    return wrap("".join(b), 101)


def chave():
    b = [shape("k", "M14,46 L40,20 C36,12 42,4 50,6 L44,12 L48,18 L54,12 C58,20 50,28 42,24 L18,50 C14,54 10,50 14,46 Z", "#aab4bc", 111, (8, 4, 60, 56), k=1.2),
         '<path d="M8,26 C12,12 26,8 34,10" stroke="#ffffff" stroke-width="2.6" fill="none" stroke-dasharray="4 4" stroke-linecap="round"/>',
         '<path d="M30,6 l4,4 l-5,2" stroke="#ffffff" stroke-width="2.6" fill="none" stroke-linecap="round"/>']
    return wrap("".join(b), 111)


def mola_portatil():
    b = [shape("mb", rect_d(10, 52, 44, 8, 2), "#5a6370", 121, (8, 50, 56, 62), k=1.2),
         shape("mt", rect_d(14, 10, 36, 8, 2), "#5cc45c", 122, (12, 8, 52, 20), k=1.2)]
    for y in (22, 30, 38, 46):
        b.append(f'<path d="M16,{y} Q32,{y - 6} 48,{y} Q32,{y + 4} 16,{y}" fill="none" stroke="#aab4bc" stroke-width="3"/>')
    b.append('<path d="M32,4 v-2 M26,5 l-2,-3 M38,5 l2,-3" stroke="#f2c84b" stroke-width="2.4" stroke-linecap="round"/>')
    return wrap("".join(b), 121)


def main():
    for name, fn in (("dinamite", dinamite), ("martelao", martelao), ("capacete", capacete), ("mola", mola),
                     ("gancho", gancho), ("ima", ima), ("tabua", tabua), ("furadeira", furadeira), ("cola", cola),
                     ("foguete", foguete), ("chave", chave), ("mola_portatil", mola_portatil)):
        queue(fn(), f"{SRC}/item_{name}.svg", f"{OUT}/{name}.png", 64, 64, K)
    print("itens:", render_all())


if __name__ == "__main__":
    main()
