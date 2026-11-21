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


def teletransporte():
    b = [shape("tp", ellipse_d(32, 34, 24, 26), "#6b3fb3", 131, (6, 6, 58, 62), k=1.3, dark="#4a2a85", light="#9a6fe0"),
         '<ellipse cx="32" cy="34" rx="15" ry="17" fill="#2a1650"/>',
         '<path d="M32,22 C40,24 42,34 34,38 C28,41 24,36 28,32" stroke="#e7d6ff" stroke-width="3" fill="none" stroke-linecap="round"/>',
         '<path d="M8,14 l6,4 M56,14 l-6,4 M6,52 l7,-3 M58,52 l-7,-3" stroke="#f2c84b" stroke-width="2.6" stroke-linecap="round"/>',
         '<path d="M44,8 l4,0 l-2,4 Z M16,58 l4,0 l-2,-4 Z" fill="#e7d6ff"/>']
    return wrap("".join(b), 131)


def laser():
    b = [shape("lb", "M8,24 H40 C46,24 48,30 48,32 C48,34 46,40 40,40 H8 Z", "#c9d1d8", 141, (6, 22, 50, 42), k=1.2, dark="#8a96a2", light="#ffffff"),
         shape("lh", "M14,40 H26 L24,58 H12 Z", "#d42035", 142, (10, 38, 28, 60), k=1.2, dark="#a01528"),
         '<rect x="48" y="28" width="8" height="8" fill="#5a6370"/>',
         '<path d="M56,32 H63" stroke="#ff4d6a" stroke-width="4" stroke-linecap="round"/>',
         '<circle cx="20" cy="31" r="4" fill="#ff4d6a"/><circle cx="31" cy="31" r="3" fill="#5fd6b0"/>',
         '<path d="M10,20 L18,14 M40,20 L48,12" stroke="#5a6370" stroke-width="3" stroke-linecap="round"/>']
    return wrap("".join(b), 141)


def vortice():
    b = [shape("vb", ellipse_d(30, 36, 22, 22), "#2f2a45", 151, (6, 12, 54, 60), k=1.3, dark="#1c1830", light="#5a4f80"),
         '<path d="M30,22 C42,24 44,40 32,44 C22,46 20,34 28,32 C32,31 34,35 31,37" stroke="#b48cff" stroke-width="3" fill="none" stroke-linecap="round"/>',
         '<rect x="26" y="8" width="10" height="7" rx="2" fill="#6a7682"/>',
         '<path d="M36,10 C42,6 48,8 52,4" stroke="#5a4632" stroke-width="2.2" fill="none" stroke-linecap="round"/>',
         '<circle cx="52" cy="4" r="2.6" fill="#ffffff"/>', '<circle cx="22" cy="28" r="3" fill="#ffffff" opacity="0.7"/>']
    return wrap("".join(b), 151)


def soprador():
    b = [shape("sb", "M10,22 H36 C44,22 46,40 36,42 H10 Z", "#f08a3d", 161, (8, 20, 48, 44), k=1.2, dark="#c0602a", light="#ffb27a"),
         shape("sn", "M36,26 L60,22 L60,42 L36,38 Z", "#5a6370", 162, (34, 20, 62, 44), k=1.2, dark="#3e4752"),
         shape("sh", "M14,42 H24 L22,58 H12 Z", "#3e4752", 163, (10, 40, 26, 60), k=1.1),
         '<circle cx="20" cy="31" r="5" fill="#2f3640"/><path d="M17,31 h6 M20,28 v6" stroke="#aab4bc" stroke-width="1.6"/>',
         '<path d="M62,18 q-4,-6 -10,-4 M63,32 h-0 M62,46 q-4,6 -10,4" stroke="#ffffff" stroke-width="2.4" fill="none" stroke-linecap="round"/>']
    return wrap("".join(b), 161)


def congelador():
    b = [shape("cb", "M8,24 H40 L50,28 V36 L40,40 H8 Z", "#8fd3f0", 171, (6, 22, 52, 42), k=1.2, dark="#4aa6d0", light="#e0f6ff"),
         shape("ch", "M14,40 H26 L24,58 H12 Z", "#3e7fb8", 172, (10, 38, 28, 60), k=1.2),
         '<rect x="18" y="14" width="12" height="10" rx="2" fill="#d5f1ff"/><rect x="20" y="16" width="8" height="5" fill="#8fd3f0"/>']
    cx, cy = 56, 32
    for a in range(0, 180, 60):
        b.append(f'<path d="M{cx},{cy} m-7,0 h14" stroke="#ffffff" stroke-width="2.4" stroke-linecap="round" transform="rotate({a} {cx} {cy})"/>')
    return wrap("".join(b), 171)


def estilingue():
    b = [shape("ef", "M27,60 C27,62 35,62 35,60 L35,42 L47,28 L48,9 C48,6 42,6 42,9 L41,25 L31,36 L22,25 L21,9 "
               "C21,6 15,6 15,9 L16,28 L27,42 Z", "#b07a3d", 181, (13, 4, 50, 62), k=1.2, dark="#7a5226", light="#d9a35f"),
         '<path d="M18,10 L28,30 M45,10 L36,30" stroke="#3e4752" stroke-width="3" stroke-linecap="round"/>',
         shape("ed", rect_d(26, 14, 12, 20, 2), "#d14d35", 182, (24, 12, 40, 36), k=1.1),
         '<rect x="26" y="21" width="12" height="4" fill="#3e4752"/>',
         '<path d="M26,32 Q32,36 38,32" stroke="#3e4752" stroke-width="3" fill="none" stroke-linecap="round"/>',
         '<path d="M32,14 C32,9 36,8 37,5" stroke="#5a4632" stroke-width="2.2" fill="none" stroke-linecap="round"/>',
         '<path d="M37,5 l3,-2 M37,5 l4,1 M37,5 l-1,-3" stroke="#f2c84b" stroke-width="2" stroke-linecap="round"/>',
         '<circle cx="37" cy="5" r="2.2" fill="#ffffff"/>',
         '<path d="M18,30 L24,38" stroke="#e0b47a" stroke-width="2" stroke-linecap="round"/>']
    return wrap("".join(b), 181)


def patins():
    b = [shape("pb", "M16,8 L36,8 L38,26 L50,29 C55,30 56,40 50,40 L14,40 Z", "#f2c84b", 191, (12, 6, 58, 42), k=1.2,
               dark="#c99a28", light="#fff1b8"),
         '<rect x="16" y="8" width="20" height="6" fill="#d14d35"/>',
         '<path d="M36,22 L44,26" stroke="#d14d35" stroke-width="3.2" stroke-linecap="round"/>',
         '<path d="M22,18 l8,4 M22,24 l8,4 M30,18 l-8,4 M30,24 l-8,4" stroke="#ffffff" stroke-width="1.8" stroke-linecap="round"/>',
         shape("pp", rect_d(12, 39, 42, 6, 2), "#d14d35", 192, (10, 37, 56, 47), k=1.1),
         '<path d="M50,39 L56,36 L58,42 L54,45 Z" fill="#3e4752"/>']
    for i, x in enumerate((21, 43)):
        b.append(shape(f"pw{i}", ellipse_d(x, 52, 8, 8), "#3e4752", 193 + i, (x - 9, 43, x + 9, 61), k=1.0))
        b.append(f'<circle cx="{x}" cy="52" r="3" fill="#d5dbe1"/>')
    b.append('<path d="M2,20 H10 M4,30 H10 M2,40 H8" stroke="#ffffff" stroke-width="2.6" stroke-linecap="round"/>')
    return wrap("".join(b), 191)


def escudo():
    b = [shape("sh", "M32,4 C40,8 50,9 56,9 C56,34 48,52 32,60 C16,52 8,34 8,9 C14,9 24,8 32,4 Z", "#2f6fc8", 201,
               (6, 2, 58, 62), k=1.3, dark="#1f4f99", light="#7fb0f0"),
         '<path d="M32,10 C38,13 45,14 50,14 C50,34 44,47 32,54 C20,47 14,34 14,14 C19,14 26,13 32,10 Z" fill="#4f86d9"/>',
         shape("sd0", rect_d(20, 24, 8, 22, 2), "#d14d35", 202, (18, 22, 30, 48), k=1.0),
         shape("sd1", rect_d(28, 24, 8, 22, 2), "#d14d35", 203, (26, 22, 38, 48), k=1.0),
         shape("sd2", rect_d(36, 24, 8, 22, 2), "#d14d35", 204, (34, 22, 46, 48), k=1.0),
         '<rect x="19" y="32" width="26" height="5" fill="#3e4752"/>',
         '<path d="M32,24 C32,19 36,18 38,15" stroke="#5a4632" stroke-width="2" fill="none" stroke-linecap="round"/>',
         '<path d="M17,19 L47,49 M47,19 L17,49" stroke="#1f4f99" stroke-width="7" stroke-linecap="round" opacity="0.55"/>',
         '<path d="M17,19 L47,49 M47,19 L17,49" stroke="#ffffff" stroke-width="4" stroke-linecap="round"/>',
         '<path d="M14,16 Q15,30 20,40" stroke="#ffffff" stroke-width="2.6" fill="none" stroke-linecap="round" opacity="0.8"/>']
    return wrap("".join(b), 201)


def choque():
    b = ['<path d="M10,22 A24,24 0 0 1 22,9 M54,42 A24,24 0 0 1 42,55" stroke="#f6a23a" stroke-width="3" fill="none" stroke-linecap="round"/>',
         '<path d="M4,34 A28,28 0 0 1 10,15 M60,30 A28,28 0 0 1 54,49" stroke="#ffe08a" stroke-width="2.6" fill="none" stroke-linecap="round"/>',
         '<path d="M18,46 A16,16 0 0 1 16,26 M46,18 A16,16 0 0 1 48,38" stroke="#f6a23a" stroke-width="2.6" fill="none" stroke-linecap="round"/>',
         shape("cz", "M36,4 L18,34 L30,34 L24,60 L46,26 L34,26 L42,4 Z", "#f2c84b", 211, (16, 2, 48, 62), k=1.2,
               dark="#c99a28", light="#fff1b8"),
         '<path d="M36,4 L42,4 L38,14 L33,9 Z" fill="#fff1b8"/>',
         '<circle cx="12" cy="52" r="2.4" fill="#f2c84b"/><circle cx="54" cy="10" r="2.4" fill="#f2c84b"/>']
    return wrap("".join(b), 211)


def laco():
    rope = "#c9a26a"
    d_loop = "M24,34 C8,30 10,10 34,8 C56,6 62,24 46,32 C40,35 30,36 24,34"
    d_tail = "M24,34 C18,40 22,46 16,50 C10,54 6,50 10,46 C14,42 20,48 16,56 L12,61"
    b = [f'<path d="{d_loop}" stroke="{rope}" stroke-width="5.5" fill="none" stroke-linecap="round"/>',
         f'<path d="{d_loop}" stroke="#8a6a3e" stroke-width="5.5" fill="none" stroke-dasharray="1.6 3.4"/>',
         f'<path d="{d_tail}" stroke="{rope}" stroke-width="5" fill="none" stroke-linecap="round"/>',
         f'<path d="{d_tail}" stroke="#8a6a3e" stroke-width="5" fill="none" stroke-dasharray="1.6 3.4"/>',
         '<path d="M16,20 C18,14 26,11 32,11" stroke="#f0d6a8" stroke-width="1.8" fill="none" stroke-linecap="round"/>',
         shape("lk", rect_d(19, 29, 10, 10, 3), "#a8834c", 221, (17, 27, 31, 41), k=1.0),
         '<path d="M50,44 l6,-3 M52,52 l7,0 M48,58 l5,3" stroke="#ffffff" stroke-width="2.4" stroke-linecap="round"/>']
    return wrap("".join(b), 221)


def barreira():
    wood, dk = "#d9a35f", "#a8743a"
    b = []
    for i, (x, y) in enumerate(((5, 34), (33, 34), (19, 8))):
        b.append(shape(f"bc{i}", rect_d(x, y, 26, 26, 2), wood, 231 + i, (x - 2, y - 2, x + 28, y + 28), k=1.1,
                       dark=dk, light="#f0cc95"))
        b.append(f'<rect x="{x}" y="{y}" width="26" height="4" fill="{dk}"/>'
                 f'<rect x="{x}" y="{y + 22}" width="26" height="4" fill="{dk}"/>'
                 f'<path d="M{x + 3},{y + 21} L{x + 23},{y + 5}" stroke="{dk}" stroke-width="3.2" stroke-linecap="round"/>')
    b.append('<clipPath id="bz"><rect x="3" y="40" width="58" height="9"/></clipPath>'
             '<rect x="3" y="40" width="58" height="9" fill="#f2c84b"/><g clip-path="url(#bz)">'
             + "".join(f'<path d="M{x},49 L{x + 9},40 L{x + 14},40 L{x + 5},49 Z" fill="#2f3640"/>' for x in range(-6, 62, 10))
             + '</g>')
    b.append('<path d="M23,12 H41" stroke="#fff1b8" stroke-width="1.8" stroke-linecap="round"/>')
    return wrap("".join(b), 231)


def main():
    for name, fn in (("dinamite", dinamite), ("martelao", martelao), ("capacete", capacete), ("mola", mola),
                     ("gancho", gancho), ("ima", ima), ("tabua", tabua), ("furadeira", furadeira), ("cola", cola),
                     ("foguete", foguete), ("chave", chave), ("mola_portatil", mola_portatil),
                     ("teletransporte", teletransporte), ("laser", laser), ("vortice", vortice), ("soprador", soprador),
                     ("congelador", congelador), ("estilingue", estilingue), ("patins", patins),
                     ("escudo", escudo), ("choque", choque), ("laco", laco), ("barreira", barreira)):
        queue(fn(), f"{SRC}/item_{name}.svg", f"{OUT}/{name}.png", 64, 64, K)
    print("itens:", render_all())


if __name__ == "__main__":
    main()
