"""Peças de cenário das arenas da Demolição (estilo papel e giz): piso de esteira, plataforma de aço
do guindaste, caixote de TNT e bola de demolição.
Rodar: python3 art/src/cenarios/arenas.py
"""
import base64
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from papel import ellipse_d, hatch, rect_d, rough, shape  # noqa: E402
from svg import doc, queue, render_all  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.."))
SRC = os.path.join(ROOT, "art/src/cenarios/svg")
OUT = os.path.join(ROOT, "art/out/game/cenario")
K = 3
FONT = base64.b64encode(open(os.path.join(ROOT, "art/src/fontes/fredoka-700.woff2"), "rb").read()).decode()
FONT_CSS = f'<style>@font-face{{font-family:"Fredoka";src:url(data:font/woff2;base64,{FONT}) format("woff2");font-weight:700;}}</style>'


def wrap(w, h, body, seed, scale=0.8):
    return doc(w, h, f'<g filter="url(#rough)">{body}</g>', rough(seed=seed, scale=scale, freq=0.08))


def belt_tile():
    """Piso de esteira 64x64 (sólido, emenda lado a lado): esteira escura no topo, estrutura de aço embaixo."""
    b = [shape("s", rect_d(0, 14, 64, 50, 0), "#6a7682", 1, (0, 12, 64, 64), k=1.4, dark="#4b535e"),
         '<path d="M0,40 L32,62 L64,40 M0,62 L32,40 L64,62" stroke="#55606b" stroke-width="5" fill="none"/>',
         shape("b", rect_d(0, 0, 64, 18, 0), "#3e4752", 2, (0, 0, 64, 20), k=1.4, dark="#2b323b", light="#5a6370"),
         '<circle cx="16" cy="9" r="5" fill="#9aa4ae"/><circle cx="48" cy="9" r="5" fill="#9aa4ae"/>',
         '<circle cx="16" cy="9" r="1.8" fill="#3e4752"/><circle cx="48" cy="9" r="1.8" fill="#3e4752"/>',
         '<rect x="0" y="18" width="64" height="4" fill="#f2c84b"/>']
    return wrap(64, 64, "".join(b), 3, 0.5)


def girder():
    """Plataforma de aço 192x40 (pendurada no guindaste)."""
    b = [shape("g", rect_d(2, 6, 188, 30, 4), "#8a96a2", 4, (0, 4, 192, 38), k=1.4, dark="#6a7682"),
         '<rect x="2" y="6" width="188" height="7" fill="#aab4bc"/>']
    for x in range(10, 186, 22):
        b.append(f'<path d="M{x},14 L{x + 11},34 L{x + 22},14" stroke="#6a7682" stroke-width="3" fill="none"/>')
    for x in (12, 180):
        b.append(f'<circle cx="{x}" cy="24" r="3" fill="#3e4650"/>')
    b.append('<path d="M2,30 h188" stroke="#f2c84b" stroke-width="4" stroke-dasharray="12 10"/>')
    return wrap(192, 40, "".join(b), 5, 0.6)


def tnt():
    """Caixote de TNT 64x64: madeira avermelhada com faixa e letreiro (vermelho = perigo)."""
    b = ['<rect x="0" y="0" width="64" height="64" fill="#c9574a"/>',
         hatch("all", (0, 0, 64, 64), "#c9574a", 7, k=1.4, dens=0.7, dark="#8a2f26"),
         shape("p", rect_d(4.5, 4.5, 55, 55, 1), "#b5463b", 8, (3, 3, 61, 61), k=1.4, dark="#7a261e"),
         '<rect x="4" y="22" width="56" height="20" fill="#f2e6c8"/>',
         '<text x="32" y="39" text-anchor="middle" font-family="Fredoka" font-weight="700" font-size="19" fill="#d42035">TNT</text>',
         '<path d="M10,10 L18,16 M54,10 L46,16 M10,54 L18,48 M54,54 L46,48" stroke="#7a261e" stroke-width="3"/>']
    return doc(64, 64, FONT_CSS + '<clipPath id="all"><rect width="64" height="64"/></clipPath>' + "".join(b))


def ball():
    """Bola de demolição 128x128."""
    b = [shape("b", "M64,6 A58,58 0 1 0 64.1,6 Z", "#4b535e", 9, (4, 4, 124, 124), k=2.2, dark="#2f3640", light="#6a7682"),
         '<path d="M64,6 A58,58 0 0 1 122,64 A58,58 0 0 1 64,122 A40,58 0 0 0 64,6 Z" fill="#3a414b" opacity="0.7"/>',
         '<path d="M30,40 Q38,24 56,18" stroke="#9aa4ae" stroke-width="7" fill="none" stroke-linecap="round"/>',
         '<rect x="52" y="0" width="24" height="16" rx="4" fill="#6a7682"/>']
    return wrap(128, 128, "".join(b), 9, 1.0)

WOOD, WOOD_HI, WOOD_DK = "#c8995f", "#dba462", "#8a5a2a"
STEEL_LT, STEEL, STEEL_DK, SLATE = "#aab4bc", "#8a96a2", "#6a7682", "#4b535e"
YEL, RED = "#f2c84b", "#d42035"


def stripes(x, y, w, h, sid):
    """Faixa amarela e preta de perigo."""
    out = [f'<clipPath id="{sid}"><rect x="{x}" y="{y}" width="{w}" height="{h}"/></clipPath>',
           f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{YEL}"/><g clip-path="url(#{sid})">']
    for k in range(-2, int(w / 10) + 3):
        xx = x + k * 14
        out.append(f'<path d="M{xx},{y + h} L{xx + h},{y} L{xx + h + 7},{y} L{xx + 7},{y + h} Z" fill="#2f3640"/>')
    out.append('</g>')
    return "".join(out)


def fan_base():
    """Ventilador de chão 64x64 (a hélice gira por cima, desenhada à parte)."""
    b = [shape("f", rect_d(2, 8, 60, 56, 6), STEEL, 21, (0, 6, 64, 64), k=1.4, dark=STEEL_DK),
         '<circle cx="32" cy="34" r="25" fill="#3e4752"/>',
         '<circle cx="32" cy="34" r="25" fill="none" stroke="#aab4bc" stroke-width="3"/>',
         stripes(2, 56, 60, 8, "fs")]
    for a in range(0, 360, 30):
        b.append(f'<path d="M32,34 m0,-25 v6" stroke="#6a7682" stroke-width="2" transform="rotate({a} 32 34)"/>')
    return wrap(64, 64, "".join(b), 21, 0.6)


def fan_blades():
    """Hélice 56x56 (gira no jogo)."""
    b = []
    for a in (0, 120, 240):
        b.append(f'<path d="M28,28 C24,16 26,6 34,4 C42,6 40,18 28,28 Z" fill="#e9eef2" transform="rotate({a} 28 28)"/>')
        b.append(f'<path d="M28,28 C30,18 34,10 36,6" stroke="#aab4bc" stroke-width="2" fill="none" transform="rotate({a} 28 28)"/>')
    b.append('<circle cx="28" cy="28" r="6" fill="#d42035"/><circle cx="28" cy="28" r="2" fill="#2f3640"/>')
    return wrap(56, 56, "".join(b), 22, 0.5)


def burner():
    """Bico de chama 64x64 (sólido; a chama sai por cima)."""
    b = [shape("bu", rect_d(4, 18, 56, 46, 3), "#5a6370", 31, (2, 16, 62, 64), k=1.4, dark="#3e4752"),
         shape("bt", "M14,4 H50 L46,20 H18 Z", "#2f3640", 32, (12, 2, 52, 22), k=1.4),
         '<rect x="10" y="30" width="44" height="10" fill="#d4572a"/>',
         '<path d="M14,35 h36" stroke="#f2a14b" stroke-width="3" stroke-dasharray="6 5"/>',
         '<circle cx="14" cy="52" r="3" fill="#aab4bc"/><circle cx="50" cy="52" r="3" fill="#aab4bc"/>']
    return wrap(64, 64, "".join(b), 31, 0.6)


def flame():
    """Jato de chama 64x160 (vertical, base embaixo): laranja, amarelo e miolo claro, recortado."""
    outer = "M8,160 C2,120 14,96 10,70 C8,50 20,40 18,18 C28,30 30,10 34,0 C40,18 50,26 46,46 C56,40 58,64 54,84 C62,104 58,132 56,160 Z"
    mid = "M16,160 C12,130 22,112 20,92 C20,76 28,66 30,46 C36,60 42,66 40,84 C48,86 48,106 46,122 C52,136 50,150 48,160 Z"
    core = "M24,160 C22,142 28,130 28,116 C32,124 36,128 36,140 C40,146 40,154 40,160 Z"
    b = [shape("fo", outer, "#ef6b2a", 41, (0, 0, 64, 160), k=1.6, dark="#c94a1c", light="#f8a04a"),
         shape("fm", mid, "#f6a23a", 42, (0, 40, 64, 160), k=1.6, dark="#e0782a", light="#ffd27a"),
         f'<path d="{core}" fill="#fff1b8"/>']
    return wrap(64, 160, "".join(b), 41, 1.2)


def piston_housing():
    """Caixa do pistão 64x64 (no teto)."""
    b = [shape("ph", rect_d(0, 0, 64, 56, 3), STEEL_DK, 51, (0, 0, 64, 58), k=1.4, dark="#4b535e"),
         stripes(0, 48, 64, 12, "phs"),
         '<rect x="20" y="10" width="24" height="30" fill="#3e4752"/>',
         '<circle cx="10" cy="10" r="3" fill="#aab4bc"/><circle cx="54" cy="10" r="3" fill="#aab4bc"/>']
    return wrap(64, 64, "".join(b), 51, 0.6)


def piston_rod():
    """Haste do pistão 32x64 (emenda na vertical)."""
    b = ['<rect x="4" y="-2" width="24" height="68" fill="#aab4bc"/>',
         '<rect x="4" y="-2" width="7" height="68" fill="#d5dbe1"/>',
         '<rect x="22" y="-2" width="6" height="68" fill="#8a96a2"/>']
    return doc(32, 64, "".join(b))


def piston_head():
    """Prensa 64x48 (cabeça pesada do pistão)."""
    b = [shape("pp", rect_d(0, 6, 64, 42, 4), "#5a6370", 53, (0, 4, 64, 48), k=1.4, dark="#3e4752", light="#7d8894"),
         stripes(2, 36, 60, 10, "pps"),
         shape("pt", rect_d(18, 0, 28, 10, 2), STEEL, 54, (16, 0, 48, 10), k=1.2)]
    return wrap(64, 48, "".join(b), 53, 0.6)


def saw():
    """Serra circular 96x96."""
    import math
    pts = []
    n = 16
    for i in range(n * 2):
        a = math.pi * 2 * i / (n * 2)
        r = 46 if i % 2 == 0 else 37
        a2 = a + (0.12 if i % 2 == 0 else 0)
        pts.append(f"{48 + r * math.cos(a2):.1f},{48 + r * math.sin(a2):.1f}")
    d = "M" + " L".join(pts) + " Z"
    b = [shape("sw", d, "#c9d1d8", 61, (0, 0, 96, 96), k=1.6, dark="#8a96a2", light="#ffffff"),
         '<circle cx="48" cy="48" r="26" fill="#aab4bc"/>',
         '<circle cx="48" cy="48" r="13" fill="#d42035"/><circle cx="48" cy="48" r="4" fill="#2f3640"/>',
         '<path d="M30,40 A20,20 0 0 1 44,28" stroke="#ffffff" stroke-width="4" fill="none" stroke-linecap="round"/>']
    return wrap(96, 96, "".join(b), 61, 0.8)


def rail():
    """Trilho 64x16 (emenda na horizontal)."""
    b = ['<rect x="-1" y="5" width="66" height="7" fill="#3e4752"/>', '<rect x="-1" y="5" width="66" height="2" fill="#6a7682"/>',
         '<rect x="6" y="2" width="6" height="13" fill="#5a6370"/><rect x="38" y="2" width="6" height="13" fill="#5a6370"/>']
    return doc(64, 16, "".join(b))


def barrel():
    """Barril 56x56 (rola)."""
    b = [shape("ba", ellipse_d(28, 28, 26, 26), "#b5713b", 71, (0, 0, 56, 56), k=1.4, dark="#7a4a22", light="#d99a5e"),
         '<circle cx="28" cy="28" r="26" fill="none" stroke="#5a6370" stroke-width="5"/>',
         '<circle cx="28" cy="28" r="14" fill="none" stroke="#5a6370" stroke-width="4"/>',
         '<path d="M28,2 V54 M2,28 H54" stroke="#8a5a2a" stroke-width="3"/>',
         '<circle cx="28" cy="28" r="5" fill="#d42035"/>']
    return wrap(56, 56, "".join(b), 71, 0.6)


def lever_base():
    """Base da alavanca 64x32."""
    b = [shape("lb", "M4,32 L10,10 Q32,0 54,10 L60,32 Z", "#5a6370", 81, (2, 0, 62, 32), k=1.3, dark="#3e4752"),
         '<circle cx="32" cy="14" r="6" fill="#aab4bc"/>', stripes(6, 24, 52, 8, "lbs")]
    return wrap(64, 32, "".join(b), 81, 0.5)


def lever_stick():
    """Haste da alavanca 16x56 (gira na base), bola vermelha na ponta."""
    b = ['<rect x="5" y="12" width="6" height="44" rx="2" fill="#8a96a2"/>', '<rect x="5" y="12" width="2" height="44" fill="#d5dbe1"/>',
         shape("lk", ellipse_d(8, 9, 8, 8), RED, 82, (0, 0, 16, 18), k=1.2, dark="#a01528", light="#ff6b7a")]
    return wrap(16, 56, "".join(b), 82, 0.4)


def trapdoor():
    """Alçapão 64x24: tábua de madeira com faixa de perigo e dobradiça."""
    b = [shape("td", rect_d(0, 2, 64, 20, 2), WOOD, 91, (0, 0, 64, 24), k=1.3, dark=WOOD_DK, light=WOOD_HI),
         stripes(4, 8, 56, 7, "tds"),
         '<rect x="0" y="4" width="8" height="16" fill="#5a6370"/><circle cx="4" cy="12" r="2" fill="#aab4bc"/>']
    return wrap(64, 24, "".join(b), 91, 0.5)


def seesaw_plank():
    """Tábua da gangorra 64x28 (emenda na horizontal)."""
    b = ['<rect x="-1" y="2" width="66" height="24" fill="#c98f4b"/>',
         hatch("sp", (0, 2, 64, 26), "#c98f4b", 95, k=1.3, dark="#8a5a2a", light="#e9bf86"),
         '<rect x="-1" y="20" width="66" height="6" fill="#a8713b"/>',
         '<path d="M4,9 H26 M34,13 H58" stroke="#e9bf86" stroke-width="1.4" stroke-linecap="round"/>',
         '<circle cx="8" cy="14" r="2.2" fill="#5a6370"/><circle cx="56" cy="14" r="2.2" fill="#5a6370"/>']
    return wrap(64, 28, "".join(b), 95, 0.5).replace("<defs>", '<defs><clipPath id="sp"><rect y="2" width="64" height="24"/></clipPath>')


def seesaw_pivot():
    """Suporte da gangorra 64x64 (triângulo de aço)."""
    b = [shape("pv", "M32,4 L62,64 H2 Z", STEEL, 97, (0, 0, 64, 64), k=1.4, dark=STEEL_DK, light=STEEL_LT),
         '<circle cx="32" cy="14" r="7" fill="#3e4752"/><circle cx="32" cy="14" r="2.5" fill="#aab4bc"/>',
         stripes(8, 52, 48, 10, "pvs")]
    return wrap(64, 64, "".join(b), 97, 0.6)


def chute():
    """Calha de barris 64x64 (cano saindo da parede)."""
    b = [shape("ch", rect_d(0, 10, 64, 46, 4), "#7d8894", 99, (0, 8, 64, 58), k=1.4, dark=STEEL_DK),
         '<rect x="8" y="18" width="48" height="30" rx="4" fill="#2f3640"/>',
         stripes(0, 2, 64, 9, "chs")]
    return wrap(64, 64, "".join(b), 99, 0.6)



def mud():
    """Lama roxa 64x64 (emenda na horizontal): borda de cima ondulada com bolhas, corpo mais escuro embaixo."""
    top = "M0,20 C10,13 22,13 32,20 C42,27 54,27 64,20 V64 H0 Z"
    b = [shape("lm", top, "#9a7fd0", 101, (0, 10, 64, 64), k=1.4, dark="#6f55a8", light="#c4b0ee"),
         '<rect x="0" y="44" width="64" height="20" fill="#7a5fb3"/>',
         '<path d="M4,22 C14,16 22,16 30,21" stroke="#d8c8f6" stroke-width="3" fill="none" stroke-linecap="round"/>',
         '<circle cx="46" cy="34" r="5" fill="none" stroke="#c4b0ee" stroke-width="2"/>',
         '<circle cx="18" cy="40" r="3" fill="none" stroke="#c4b0ee" stroke-width="1.6"/>',
         '<circle cx="47" cy="32.5" r="1.4" fill="#ffffff"/>']
    return wrap(64, 64, "".join(b), 103, 0.5)


def main():
    for name, svg, w, h in [("esteira_piso", belt_tile(), 64, 64), ("plataforma_aco", girder(), 192, 40),
                            ("tnt", tnt(), 64, 64), ("bola_demolicao", ball(), 128, 128),
                            ("ventilador", fan_base(), 64, 64), ("helice", fan_blades(), 56, 56),
                            ("bico_chama", burner(), 64, 64), ("chama", flame(), 64, 160),
                            ("pistao_caixa", piston_housing(), 64, 64), ("pistao_haste", piston_rod(), 32, 64),
                            ("pistao_prensa", piston_head(), 64, 48), ("serra", saw(), 96, 96), ("trilho", rail(), 64, 16),
                            ("barril", barrel(), 56, 56), ("alavanca_base", lever_base(), 64, 32),
                            ("alavanca_haste", lever_stick(), 16, 56), ("alcapao", trapdoor(), 64, 24),
                            ("gangorra_tabua", seesaw_plank(), 64, 28), ("gangorra_apoio", seesaw_pivot(), 64, 64),
                            ("calha", chute(), 64, 64), ("lama", mud(), 64, 64)]:
        queue(svg, f"{SRC}/{name}.svg", f"{OUT}/{name}.png", w, h, K)
    print("arenas:", render_all())


if __name__ == "__main__":
    main()
