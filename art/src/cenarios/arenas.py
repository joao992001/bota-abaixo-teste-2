"""Peças de cenário das arenas da Demolição (estilo papel e giz): piso de esteira, plataforma de aço
do guindaste, caixote de TNT e bola de demolição.
Rodar: python3 art/src/cenarios/arenas.py
"""
import base64
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from papel import hatch, rect_d, rough, shape  # noqa: E402
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


def main():
    for name, svg, w, h in [("esteira_piso", belt_tile(), 64, 64), ("plataforma_aco", girder(), 192, 40),
                            ("tnt", tnt(), 64, 64), ("bola_demolicao", ball(), 128, 128)]:
        queue(svg, f"{SRC}/{name}.svg", f"{OUT}/{name}.png", w, h, K)
    print("arenas:", render_all())


if __name__ == "__main__":
    main()
