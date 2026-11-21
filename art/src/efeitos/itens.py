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


def relogio():
    b = []
    for i, (x, a) in enumerate(((17, -30), (47, 30))):
        b.append(f'<g transform="rotate({a} {x} 16)">'
                 + shape(f"rs{i}", "M{0},22 C{0},10 {1},8 {2},8 C{3},8 {4},10 {4},22 Z".format(x - 9, x - 6, x, x + 6, x + 9),
                         "#f2c84b", 241 + i, (x - 11, 6, x + 11, 24), k=1.1, dark="#c99a28", light="#fff1b8")
                 + f'<rect x="{x - 10}" y="20" width="20" height="4" rx="2" fill="#3e4752"/></g>')
    b.append('<path d="M18,54 L13,61 M46,54 L51,61" stroke="#3e4752" stroke-width="4.5" stroke-linecap="round"/>')
    b.append(shape("rc", ellipse_d(32, 37, 22, 22), "#d14d35", 243, (8, 13, 56, 61), k=1.3))
    b.append(shape("rf", ellipse_d(32, 37, 15, 15), "#fdf6e3", 244, (15, 20, 49, 54), k=0.9, dark="#e3d6b8"))
    for a in range(0, 360, 90):
        b.append(f'<path d="M32,24 v3" stroke="#3e4752" stroke-width="2.4" stroke-linecap="round" transform="rotate({a} 32 37)"/>')
    b.append('<path d="M32,37 V27 M32,37 L39,41" stroke="#3e4752" stroke-width="3" stroke-linecap="round"/>')
    b.append('<circle cx="32" cy="37" r="2.4" fill="#3e4752"/>')
    b.append('<path d="M14,30 Q15,22 22,18" stroke="#f08a78" stroke-width="2.6" fill="none" stroke-linecap="round"/>')
    b.append('<path d="M32,15 C32,9 36,7 38,4" stroke="#5a4632" stroke-width="2.2" fill="none" stroke-linecap="round"/>')
    b.append('<path d="M38,4 l3,-2 M38,4 l4,1 M38,4 l-1,-3" stroke="#f2c84b" stroke-width="2" stroke-linecap="round"/>')
    b.append('<circle cx="38" cy="4" r="2.2" fill="#ffffff"/>')
    b.append(shape("rp", "M52,45 h4 v-4 h4 v4 h4 v4 h-4 v4 h-4 v-4 h-4 Z", "#f2c84b", 245, (50, 39, 64, 55), k=0.8,
                   dark="#c99a28", light="#fff1b8"))
    return wrap("".join(b), 241)


# ---- itens novos (2026-11) ----
FUS = '<path d="M{0},{1} l3,-2 M{0},{1} l4,1 M{0},{1} l-1,-3" stroke="#f2c84b" stroke-width="2" stroke-linecap="round"/><circle cx="{0}" cy="{1}" r="2.2" fill="#ffffff"/>'
HL = '<path d="{0}" stroke="#ffffff" stroke-width="2.6" fill="none" stroke-linecap="round"/>'


def dyn(x, y, w, h, seed, fill="#d14d35", sid="d"):
    """Bastão de dinamite com faixa e pavio aceso."""
    cx = x + w / 2
    return (shape(sid, rect_d(x, y, w, h, 3), fill, seed, (x - 2, y - 2, x + w + 2, y + h + 2), k=1.1)
            + f'<rect x="{x}" y="{y + h * 0.35:.1f}" width="{w}" height="5" fill="#3e4752"/>'
            + f'<path d="M{cx},{y} C{cx},{y - 5} {cx + 4},{y - 6} {cx + 5},{y - 9}" stroke="#5a4632" stroke-width="2.2" fill="none" stroke-linecap="round"/>'
            + FUS.format(cx + 5, y - 9))


def isca():
    b = [dyn(20, 18, 22, 40, 301, fill="#e07a5c"),
         '<path d="M25,36 C25,30 37,30 37,36 C37,40 31,40 31,45" stroke="#ffffff" stroke-width="3.6" fill="none" stroke-linecap="round"/>',
         '<circle cx="31" cy="52" r="2.4" fill="#ffffff"/>',
         '<path d="M48,44 l6,-2 M50,52 l7,1" stroke="#c9c4b4" stroke-width="2.4" stroke-linecap="round"/>']
    return wrap("".join(b), 301)


def molabomba():
    b = [dyn(22, 10, 20, 26, 311)]
    for y in (40, 46, 52):
        b.append(f'<path d="M16,{y} Q32,{y - 6} 48,{y} Q32,{y + 4} 16,{y}" fill="none" stroke="#aab4bc" stroke-width="3"/>')
    b.append(shape("mbb", rect_d(12, 56, 40, 6, 2), "#5a6370", 312, (10, 54, 54, 64), k=1.0))
    return wrap("".join(b), 311)


def fumaca():
    d = "M10,46 C2,44 4,30 14,32 C12,20 26,14 32,22 C36,12 52,14 50,28 C60,28 62,44 52,46 Z"
    b = [shape("fm", d, "#9aa4ae", 321, (2, 12, 62, 48), k=1.3, dark="#6a7682", light="#d5dbe1"),
         '<ellipse cx="22" cy="54" rx="6" ry="4" fill="#9aa4ae"/><ellipse cx="40" cy="57" rx="4" ry="3" fill="#aab4bc"/>',
         HL.format("M14,36 C14,30 20,28 24,30"), HL.format("M34,22 C38,18 44,18 46,22")]
    return wrap("".join(b), 321)


def ventosa():
    b = [shape("vc", "M28,4 H36 V34 H28 Z", "#b07a3d", 331, (26, 2, 38, 36), k=1.0, dark="#7a5226", light="#d9a35f"),
         shape("vv", "M10,56 C10,40 20,32 32,32 C44,32 54,40 54,56 Z", "#d14d35", 332, (8, 30, 56, 58), k=1.3),
         '<rect x="8" y="54" width="48" height="5" rx="2" fill="#a83a28"/>',
         HL.format("M16,48 Q18,40 26,37")]
    return wrap("".join(b), 331)


def banana():
    b = [shape("bn", "M8,52 C20,58 46,52 54,30 C56,24 52,22 50,26 C44,40 30,46 12,44 C6,44 4,50 8,52 Z", "#f2c84b", 341,
               (4, 20, 58, 58), k=1.2, dark="#c99a28", light="#fff1b8"),
         shape("bl", "M50,26 C46,14 52,8 58,10 C58,16 54,20 54,28 Z", "#e6b53a", 342, (44, 6, 60, 30), k=1.0, dark="#c99a28"),
         shape("br", "M12,46 C4,40 6,32 12,32 C14,38 18,42 22,45 Z", "#e6b53a", 343, (2, 30, 24, 48), k=1.0, dark="#c99a28"),
         '<path d="M54,10 l3,-4" stroke="#5a4632" stroke-width="3" stroke-linecap="round"/>',
         HL.format("M16,50 C28,52 40,48 48,36")]
    return wrap("".join(b), 341)


def pavioduplo():
    b = [dyn(12, 22, 16, 36, 351, sid="p1"), dyn(34, 22, 16, 36, 352, sid="p2"),
         '<path d="M24,10 C30,4 36,4 42,10" stroke="#f2c84b" stroke-width="2.4" fill="none" stroke-dasharray="3 3" stroke-linecap="round"/>']
    return wrap("".join(b), 351)


def corneta():
    b = [shape("cb", "M28,12 L38,12 L40,40 L26,40 Z", "#d14d35", 361, (24, 10, 42, 42), k=1.1),
         shape("cbt", rect_d(24, 40, 18, 18, 4), "#4f86d9", 362, (22, 38, 44, 60), k=1.1, dark="#2f6fc8", light="#7fb0f0"),
         shape("cbc", rect_d(26, 6, 14, 7, 2), "#3e4752", 363, (24, 4, 42, 15), k=0.8),
         HL.format("M30,46 V54"),
         '<path d="M46,10 q8,-2 12,-6 M46,20 h12 M46,30 q8,2 12,6" stroke="#ffffff" stroke-width="2.6" fill="none" stroke-linecap="round"/>']
    return wrap("".join(b), 361)


def balao():
    b = [shape("bb", "M32,6 C46,6 52,18 50,28 C48,38 40,44 32,44 C24,44 16,38 14,28 C12,18 18,6 32,6 Z", "#f06aa8", 371,
               (12, 4, 52, 46), k=1.3, dark="#c94a85", light="#ffb0d4"),
         '<path d="M29,44 L35,44 L33,49 L31,49 Z" fill="#c94a85"/>',
         '<path d="M32,49 C26,54 38,56 32,62" stroke="#f5f3ea" stroke-width="2.4" fill="none" stroke-linecap="round"/>',
         HL.format("M20,22 C20,16 24,12 28,11")]
    return wrap("".join(b), 371)


def trocatroca():
    b = ['<path d="M12,30 A20,20 0 0 1 46,14" stroke="#5cc45c" stroke-width="6" fill="none" stroke-linecap="round"/>',
         '<path d="M42,6 L52,16 L40,20 Z" fill="#5cc45c"/>',
         '<path d="M52,34 A20,20 0 0 1 18,50" stroke="#4f86d9" stroke-width="6" fill="none" stroke-linecap="round"/>',
         '<path d="M22,58 L12,48 L24,44 Z" fill="#4f86d9"/>',
         dyn(25, 24, 14, 24, 381)]
    return wrap("".join(b), 381)


def apito():
    b = [shape("ap", "M8,26 H40 C52,26 56,34 56,40 C56,50 48,56 40,56 C30,56 24,48 24,38 H8 Z", "#c9d1d8", 391,
               (6, 24, 58, 58), k=1.2, dark="#8a96a2", light="#ffffff"),
         '<circle cx="40" cy="40" r="6" fill="#3e4752"/>', '<rect x="6" y="24" width="6" height="16" rx="2" fill="#5a6370"/>',
         '<path d="M8,26 C4,16 12,8 22,10" stroke="#f2c84b" stroke-width="2.6" fill="none" stroke-linecap="round"/>',
         '<path d="M44,18 l4,-8 M52,22 l8,-6 M30,18 l-2,-8" stroke="#ffffff" stroke-width="2.6" stroke-linecap="round"/>']
    return wrap("".join(b), 391)


def capacetefalso():
    b = [shape("cf", "M12,44 C12,22 24,14 32,14 C40,14 52,22 52,44 Z", "#f2c84b", 401, (10, 12, 54, 46), k=1.3,
               dark="#c99a28", light="#fff1b8"),
         '<path d="M6,44 Q32,38 58,44 L57,51 Q32,46 7,51 Z" fill="#e0a82a"/>',
         '<path d="M25,30 C25,22 39,22 39,30 C39,34 32,34 32,39" stroke="#ffffff" stroke-width="3.6" fill="none" stroke-linecap="round"/>',
         '<circle cx="32" cy="44" r="0" fill="none"/>',
         '<path d="M50,10 l3,-5 M56,16 l5,-2 M8,14 l-3,-4" stroke="#f2c84b" stroke-width="2.4" stroke-linecap="round"/>']
    return wrap("".join(b), 401)


def armadura():
    d = "M14,10 L24,8 C26,14 38,14 40,8 L50,10 L58,22 L50,28 L50,56 C40,60 24,60 14,56 L14,28 L6,22 Z"
    b = [shape("ar", d, "#aab4bc", 411, (4, 6, 60, 60), k=1.3, dark="#7a8693", light="#e3e8ec"),
         '<path d="M32,14 V56" stroke="#7a8693" stroke-width="2.4"/>',
         '<path d="M20,28 Q32,34 44,28 M20,40 Q32,46 44,40" stroke="#7a8693" stroke-width="2.4" fill="none"/>',
         '<circle cx="20" cy="20" r="2" fill="#5a6370"/><circle cx="44" cy="20" r="2" fill="#5a6370"/>',
         HL.format("M18,30 Q18,42 22,50")]
    return wrap("".join(b), 411)


def cerca():
    wood, dk = "#d9a35f", "#a8743a"
    b = []
    for i, x in enumerate((8, 26, 44)):
        b.append(shape(f"ce{i}", f"M{x},58 V20 L{x + 6},12 L{x + 12},20 V58 Z", wood, 421 + i, (x - 2, 10, x + 14, 60), k=1.0, dark=dk, light="#f0cc95"))
    b.append('<rect x="4" y="28" width="56" height="6" fill="#a8743a"/><rect x="4" y="44" width="56" height="6" fill="#a8743a"/>')
    b.append(shape("cez", "M36,2 L24,22 L32,22 L26,40 L42,16 L34,16 L40,2 Z", "#f2c84b", 425, (22, 0, 44, 42), k=1.0,
                   dark="#c99a28", light="#fff1b8"))
    return wrap("".join(b), 421)


def bumerangue():
    d = "M8,18 C10,10 18,10 22,14 L36,30 L52,44 C58,50 54,58 46,56 L30,40 L14,26 C10,24 8,22 8,18 Z"
    b = [shape("bu", "M6,22 C4,14 12,10 18,14 L34,30 L50,14 C56,10 62,14 58,22 L40,46 C36,52 28,52 24,46 Z",
               "#f08a3d", 431, (2, 6, 62, 58), k=1.2, dark="#c0602a", light="#ffb27a"),
         '<path d="M12,20 L24,32 M44,32 L54,20" stroke="#ffffff" stroke-width="3" stroke-linecap="round"/>',
         '<path d="M6,30 A26,26 0 0 1 30,6" stroke="#ffffff" stroke-width="2.4" fill="none" stroke-dasharray="4 4" stroke-linecap="round"/>']
    return wrap("".join(b), 431)


def rede():
    b = [shape("rf", "M8,12 C20,4 44,4 56,12 L50,50 C40,60 24,60 14,50 Z", "#5fd6b0", 441, (6, 4, 58, 60), k=0.6,
               dark="#3aa888", extra='opacity="0.35"')]
    for x in (16, 24, 32, 40, 48):
        b.append(f'<path d="M{x},8 L{32 + (x - 32) * 0.5},56" stroke="#3aa888" stroke-width="2.4"/>')
    for y in (18, 28, 38, 48):
        b.append(f'<path d="M10,{y} Q32,{y + 6} 54,{y}" stroke="#3aa888" stroke-width="2.4" fill="none"/>')
    b.append('<path d="M8,12 C20,4 44,4 56,12" stroke="#b07a3d" stroke-width="5" fill="none" stroke-linecap="round"/>')
    for x, y in ((14, 52), (32, 60), (50, 52)):
        b.append(f'<circle cx="{x}" cy="{y}" r="3.4" fill="#5a6370"/>')
    return wrap("".join(b), 441)


def imacapacete():
    b = [shape("ic", "M14,58 C14,42 22,36 32,36 C42,36 50,42 50,58 Z", "#f2c84b", 451, (12, 34, 52, 60), k=1.2,
               dark="#c99a28", light="#fff1b8"),
         '<rect x="10" y="56" width="44" height="5" rx="2" fill="#e0a82a"/>',
         shape("im", "M16,4 H26 V18 C26,24 38,24 38,18 V4 H48 V18 C48,34 16,34 16,18 Z", "#d14d35", 452, (14, 2, 50, 32), k=1.2),
         '<rect x="16" y="4" width="10" height="6" fill="#d5dbe1"/><rect x="38" y="4" width="10" height="6" fill="#d5dbe1"/>',
         '<path d="M6,36 l4,4 M58,36 l-4,4" stroke="#ffffff" stroke-width="2.6" stroke-linecap="round"/>']
    return wrap("".join(b), 451)


def skate():
    b = [shape("sk", "M4,30 C4,24 10,26 14,28 H50 C54,26 60,24 60,30 C60,36 56,38 50,38 H14 C8,38 4,36 4,30 Z",
               "#4f86d9", 461, (2, 22, 62, 40), k=1.2, dark="#2f6fc8", light="#7fb0f0"),
         '<path d="M16,30 H48" stroke="#f2c84b" stroke-width="3" stroke-linecap="round"/>',
         '<rect x="14" y="38" width="10" height="4" fill="#5a6370"/><rect x="40" y="38" width="10" height="4" fill="#5a6370"/>']
    for i, x in enumerate((19, 45)):
        b.append(shape(f"sw{i}", ellipse_d(x, 48, 7, 7), "#f5f3ea", 462 + i, (x - 8, 40, x + 8, 56), k=0.8, dark="#c9c4b4"))
        b.append(f'<circle cx="{x}" cy="48" r="2.4" fill="#5a6370"/>')
    b.append('<path d="M2,14 H14 M6,20 H16" stroke="#ffffff" stroke-width="2.6" stroke-linecap="round"/>')
    return wrap("".join(b), 461)


def oleo():
    b = [shape("op", "M4,52 C4,44 18,44 26,46 C36,42 60,44 60,52 C60,60 40,60 30,58 C18,62 4,60 4,52 Z", "#2f2a45", 471,
               (2, 40, 62, 62), k=1.0, dark="#1c1830", light="#5a4f80"),
         shape("og", "M32,4 C38,16 48,24 48,34 C48,44 40,48 32,48 C24,48 16,44 16,34 C16,24 26,16 32,4 Z", "#3a3550", 472,
               (14, 2, 50, 50), k=1.2, dark="#1c1830", light="#6a5f95"),
         '<path d="M22,32 C22,26 26,22 28,20" stroke="#b48cff" stroke-width="3" fill="none" stroke-linecap="round"/>',
         '<ellipse cx="44" cy="52" rx="6" ry="2" fill="#b48cff" opacity="0.7"/>']
    return wrap("".join(b), 471)


def chave_atalho():
    b = [shape("ka", ellipse_d(18, 22, 12, 12), "#f2c84b", 481, (4, 8, 32, 36), k=1.2, dark="#c99a28", light="#fff1b8"),
         '<circle cx="18" cy="22" r="5" fill="#ffffff" opacity="0"/><circle cx="18" cy="22" r="4.5" fill="#c99a28"/>',
         shape("kb", "M28,26 L56,26 L56,32 L52,32 L52,40 L46,40 L46,32 L40,32 L40,38 L34,38 L34,32 L28,32 Z", "#f2c84b", 482,
               (26, 24, 58, 42), k=1.0, dark="#c99a28", light="#fff1b8"),
         '<path d="M10,52 H44" stroke="#5cc45c" stroke-width="6" stroke-linecap="round"/>',
         '<path d="M42,44 L56,52 L42,60 Z" fill="#5cc45c"/>',
         HL.format("M10,18 Q12,12 18,11")]
    return wrap("".join(b), 481)


def ancora():
    b = [shape("an", "M29,16 H35 V48 C42,47 48,42 50,36 L46,36 L54,28 L58,40 L54,38 C50,50 42,56 32,56 C22,56 14,50 10,38 "
               "L6,40 L10,28 L18,36 L14,36 C16,42 22,47 29,48 Z", "#8a96a2", 491, (4, 14, 60, 58), k=1.2, dark="#5a6370", light="#d5dbe1"),
         '<rect x="20" y="20" width="24" height="6" rx="2" fill="#3e4752"/>',
         '<circle cx="32" cy="10" r="6" fill="none" stroke="#8a96a2" stroke-width="4"/>',
         HL.format("M14,40 Q18,48 24,51")]
    return wrap("".join(b), 491)


def turbo():
    b = [shape("tb", ellipse_d(26, 32, 20, 22), "#5a6370", 501, (4, 8, 48, 56), k=1.2, dark="#3e4752", light="#aab4bc"),
         '<ellipse cx="26" cy="32" rx="14" ry="16" fill="#2f3640"/>']
    for a in (0, 90, 180, 270):
        b.append(f'<path d="M26,32 C30,24 34,20 34,18 C30,18 26,22 26,32 Z" fill="#c9d1d8" transform="rotate({a + 20} 26 32)"/>')
    b.append('<circle cx="26" cy="32" r="3.4" fill="#f2c84b"/>')
    b.append(shape("tf", "M46,20 L62,26 L56,32 L62,38 L46,44 Z", "#f6a23a", 502, (44, 18, 64, 46), k=1.0))
    b.append('<path d="M48,28 L56,32 L48,36 Z" fill="#fff1b8"/>')
    return wrap("".join(b), 501)


def bolha():
    b = [shape("bo", ellipse_d(32, 32, 24, 24), "#8fd3f0", 511, (6, 6, 58, 58), k=0.6, dark="#4aa6d0", light="#e0f6ff",
               extra='opacity="0.55"'),
         '<circle cx="32" cy="32" r="24" fill="none" stroke="#4aa6d0" stroke-width="3"/>',
         '<path d="M16,26 C18,18 24,14 30,13" stroke="#ffffff" stroke-width="4" fill="none" stroke-linecap="round"/>',
         '<circle cx="44" cy="44" r="3" fill="#ffffff"/>',
         '<path d="M54,6 v8 M50,10 h8" stroke="#f2c84b" stroke-width="2.6" stroke-linecap="round"/>',
         '<circle cx="10" cy="54" r="4" fill="none" stroke="#4aa6d0" stroke-width="2"/>']
    return wrap("".join(b), 511)


def luva():
    b = [shape("lv", "M30,12 C42,6 58,12 58,26 C58,40 46,48 34,46 C28,46 26,42 26,38 L26,20 C26,16 28,13 30,12 Z", "#d14d35",
               521, (24, 4, 60, 50), k=1.3),
         shape("lp", "M30,28 C24,28 22,36 28,38 L36,38", "#d14d35", 522, (20, 26, 38, 40), k=0.8),
         '<path d="M30,28 C24,28 22,36 28,38" stroke="#a83a28" stroke-width="2.4" fill="none"/>',
         shape("lc", rect_d(20, 18, 8, 26, 2), "#f5f3ea", 523, (18, 16, 30, 46), k=0.8, dark="#c9c4b4")]
    b.append('<path d="M20,31 L16,24 L12,38 L8,24 L4,31" stroke="#aab4bc" stroke-width="3" fill="none" stroke-linejoin="round" stroke-linecap="round"/>')
    b.append(HL.format("M38,14 Q48,12 52,18"))
    return wrap("".join(b), 521)


def bolaferro():
    b = []
    for i, (x, y) in enumerate(((8, 10), (14, 16), (20, 22), (26, 28))):
        b.append(f'<ellipse cx="{x}" cy="{y}" rx="4.5" ry="3" fill="none" stroke="#8a96a2" stroke-width="2.6" transform="rotate({45 if i % 2 else -45} {x} {y})"/>')
    b.append(shape("bf", ellipse_d(38, 42, 18, 18), "#5a6370", 531, (18, 22, 58, 62), k=1.3, dark="#3e4752", light="#8a96a2"))
    b.append('<circle cx="28" cy="30" r="4" fill="none" stroke="#aab4bc" stroke-width="3"/>')
    b.append(HL.format("M28,40 Q30,32 36,30"))
    return wrap("".join(b), 531)


def mina():
    b = [shape("mn", "M6,50 C6,36 18,30 32,30 C46,30 58,36 58,50 Z", "#5a6370", 541, (4, 28, 60, 52), k=1.3, dark="#3e4752", light="#8a96a2"),
         shape("mnb", rect_d(4, 48, 56, 8, 3), "#3e4752", 542, (2, 46, 62, 58), k=1.0),
         '<rect x="26" y="20" width="12" height="12" rx="2" fill="#3e4752"/>',
         '<circle cx="32" cy="18" r="5" fill="#d42035"/><circle cx="30.5" cy="16.5" r="1.6" fill="#ffffff"/>',
         '<path d="M14,40 l6,0 M44,40 l6,0" stroke="#d42035" stroke-width="3" stroke-linecap="round"/>',
         '<path d="M22,8 l-4,-4 M42,8 l4,-4 M32,6 v-5" stroke="#d42035" stroke-width="2.4" stroke-linecap="round"/>']
    return wrap("".join(b), 541)


def guindaste():
    b = ['<path d="M32,0 V14" stroke="#3e4752" stroke-width="4"/>',
         shape("gb", rect_d(22, 12, 20, 14, 3), "#f2c84b", 551, (20, 10, 44, 28), k=1.0, dark="#c99a28", light="#fff1b8"),
         '<rect x="22" y="17" width="20" height="4" fill="#3e4752"/>',
         shape("gh", "M29,26 H35 V38 C35,40 44,40 46,46 C48,56 38,62 28,58 C20,55 18,48 22,44 L27,48 C26,52 32,54 36,52 "
               "C40,50 40,46 36,44 C32,43 29,42 29,38 Z", "#8a96a2", 552, (16, 24, 50, 62), k=1.2, dark="#5a6370", light="#d5dbe1"),
         '<path d="M20,46 L22,40 L28,46 Z" fill="#5a6370"/>']
    return wrap("".join(b), 551)


def espelho():
    b = [shape("es", "M32,4 C40,8 50,9 56,9 C56,34 48,52 32,60 C16,52 8,34 8,9 C14,9 24,8 32,4 Z", "#8a96a2", 561,
               (6, 2, 58, 62), k=1.3, dark="#5a6370", light="#c9d1d8"),
         '<path d="M32,10 C38,13 45,14 50,14 C50,34 44,47 32,54 C20,47 14,34 14,14 C19,14 26,13 32,10 Z" fill="#d5f1ff"/>',
         '<path d="M20,22 L30,14 M18,34 L40,16 M24,44 L46,26" stroke="#ffffff" stroke-width="3.4" stroke-linecap="round"/>',
         '<path d="M58,40 l4,-4 M58,48 h5" stroke="#f2c84b" stroke-width="2.4" stroke-linecap="round"/>']
    return wrap("".join(b), 561)


def superpisao():
    b = [shape("sp", "M18,4 H36 V28 L50,32 C56,34 56,44 50,44 H14 L16,28 Z", "#b07a3d", 571, (12, 2, 58, 46), k=1.2,
               dark="#7a5226", light="#d9a35f"),
         '<rect x="12" y="42" width="44" height="6" rx="2" fill="#3e4752"/>',
         '<path d="M22,14 h10 M22,20 h10" stroke="#f2c84b" stroke-width="2.4" stroke-linecap="round"/>',
         '<rect x="2" y="52" width="60" height="10" fill="#c9c4b4"/>',
         '<path d="M34,52 L30,58 L36,62 M20,52 L14,62 M48,52 L54,58 L52,62" stroke="#3e4752" stroke-width="2.4" fill="none" stroke-linecap="round"/>',
         '<path d="M4,46 l-2,-4 M60,46 l2,-4 M6,38 l-4,-2" stroke="#ffffff" stroke-width="2.4" stroke-linecap="round"/>']
    return wrap("".join(b), 571)


def dado():
    b = [shape("dd", rect_d(10, 10, 44, 44, 9), "#f5f3ea", 581, (8, 8, 56, 56), k=1.2, dark="#c9c4b4"),
         '<path d="M12,48 Q32,56 52,48 L52,50 Q50,54 46,54 H18 Q12,54 12,48 Z" fill="#c9c4b4"/>']
    for x, y in ((20, 20), (44, 20), (32, 32), (20, 44), (44, 44)):
        b.append(f'<circle cx="{x}" cy="{y}" r="4.4" fill="#3e4752"/>')
    b.append(HL.format("M16,26 V18 Q16,15 20,15"))
    b.append('<path d="M58,6 l-3,5 M62,14 l-5,1" stroke="#f2c84b" stroke-width="2.4" stroke-linecap="round"/>')
    return wrap("".join(b), 581)


NOVOS = ("isca molabomba fumaca ventosa banana pavioduplo corneta balao trocatroca apito capacetefalso armadura cerca "
         "bumerangue rede imacapacete skate oleo chave_atalho ancora turbo bolha luva bolaferro mina guindaste espelho "
         "superpisao dado").split()


def main_novos():
    for name in NOVOS:
        queue(globals()[name](), f"{SRC}/item_{name}.svg", f"{OUT}/{name}.png", 64, 64, K)
    print("itens novos:", render_all())


def main():
    for name, fn in (("dinamite", dinamite), ("martelao", martelao), ("capacete", capacete), ("mola", mola),
                     ("gancho", gancho), ("ima", ima), ("tabua", tabua), ("furadeira", furadeira), ("cola", cola),
                     ("foguete", foguete), ("chave", chave), ("mola_portatil", mola_portatil),
                     ("teletransporte", teletransporte), ("laser", laser), ("vortice", vortice), ("soprador", soprador),
                     ("congelador", congelador), ("estilingue", estilingue), ("patins", patins),
                     ("escudo", escudo), ("choque", choque), ("laco", laco), ("barreira", barreira),
                     ("relogio", relogio)):
        queue(fn(), f"{SRC}/item_{name}.svg", f"{OUT}/{name}.png", 64, 64, K)
    print("itens:", render_all())
    main_novos()


if __name__ == "__main__":
    main_novos() if "--novos" in sys.argv else main()
