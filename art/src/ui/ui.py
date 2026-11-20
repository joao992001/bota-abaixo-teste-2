"""Kit de interface (estilo papel e giz): logotipo, papel (painel 9-fatias), placa de madeira, faixa,
estrelas, cadeado e carimbo "EM BREVE". Fonte Fredoka (OFL) embutida no SVG.
Rodar: python3 art/src/ui/ui.py
"""
import base64
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from papel import hatch, rect_d, rough, shape  # noqa: E402
from svg import doc, poly, queue, render_all, shade, star_pts  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.."))
SRC = os.path.join(ROOT, "art/src/ui/svg")
OUT = os.path.join(ROOT, "art/out/game/ui")
FONT = base64.b64encode(open(os.path.join(ROOT, "art/src/fontes/fredoka-700.woff2"), "rb").read()).decode()
FONT_CSS = f'<style>@font-face{{font-family:"Fredoka";src:url(data:font/woff2;base64,{FONT}) format("woff2");font-weight:700;}}</style>'
CREAM, CREAM_DK, INKT = "#f6eedb", "#d9c7a3", "#2c4a52"
COLORS = ["#4f86d9", "#5cc45c", "#f06aa8", "#f2c84b"]


def logo():
    """BOTA-ABAIXO: cada letra é um recorte de papel (borda branca), torta, com tracinhos de giz.
    Desenhado em camadas (sombras, bordas brancas, letras) para uma letra não cobrir a outra."""
    rnd = random.Random(5)
    word = "BOTA-ABAIXO"
    adv = {"B": 150, "O": 168, "T": 138, "A": 160, "-": 96, "I": 78, "X": 156}
    W, H = 1700, 340
    wood = ["#d9a35f", "#c8995f", "#e0b06a", "#d9a35f"]
    x = 50
    shadows, borders, fills = [], [], []
    for i, ch in enumerate(word):
        w = adv[ch]
        rot = rnd.uniform(-7, 7)
        dy = rnd.uniform(-12, 12)
        col = wood[i] if i < 4 else ("#5a6370" if ch == "-" else COLORS[(i - 5) % 4])
        cx, cy = x + w / 2, 245 + dy
        tr = f'transform="rotate({rot:.1f} {cx:.0f} {cy - 80:.0f})"'
        t = f'x="{cx:.0f}" y="{cy:.0f}" text-anchor="middle" font-family="Fredoka" font-weight="700" font-size="230"'
        shadows.append(f'<g {tr}><text {t} fill="#1f3a40" opacity="0.22" transform="translate(8,10)" stroke="#1f3a40" stroke-width="28" stroke-linejoin="round">{ch}</text></g>')
        borders.append(f'<g {tr}><text {t} fill="#fffaf0" stroke="#fffaf0" stroke-width="28" stroke-linejoin="round">{ch}</text></g>')
        fills.append(f'<g {tr}><clipPath id="c{i}"><text {t}>{ch}</text></clipPath><text {t} fill="{col}">{ch}</text>'
                     + hatch(f"c{i}", (cx - 100, cy - 200, cx + 100, cy + 30), col, 100 + i, k=3.0, dens=0.9) + "</g>")
        x += w
    return doc(W, H, FONT_CSS + f'<g filter="url(#rough)">{"".join(shadows)}{"".join(borders)}{"".join(fills)}</g>', rough("rough", 7, 1.5, 0.05))


def paper():
    """Painel de papel 192x192 para 9-fatias (margem 40)."""
    d = "M8,10 L60,6 L130,9 L184,7 L186,60 L183,130 L185,184 L130,186 L60,183 L7,185 L9,130 L6,60 Z"
    return doc(192, 192, f'<g filter="url(#rough)"><path d="{d}" fill="{CREAM_DK}" transform="translate(3,5)" opacity="0.6"/>'
                         + shape("p", d, CREAM, 3, (0, 0, 192, 192), k=1.6, dens=0.5, dark="#c9b48c", light="#ffffff") + '</g>',
               rough("rough", 3, 1.2, 0.06))


def wood():
    """Placa de madeira 256x96 (9-fatias na horizontal, margem 48)."""
    b = [shape("w", rect_d(6, 10, 244, 78, 6), "#d9a35f", 9, (0, 0, 256, 96), k=1.6, dark="#9c6a35"),
         '<rect x="6" y="70" width="244" height="18" fill="#b07a3d" opacity="0.9"/>',
         '<path d="M14,34 H120 M140,52 H240" stroke="#e9bf86" stroke-width="2" stroke-linecap="round"/>',
         '<circle cx="22" cy="24" r="4" fill="#5a4632"/><circle cx="234" cy="24" r="4" fill="#5a4632"/>']
    return doc(256, 96, f'<g filter="url(#rough)">{"".join(b)}</g>', rough("rough", 9, 1.0, 0.06))


def ribbon():
    """Faixa amarela com pontas dobradas 512x128 (9-fatias na horizontal, margem 96)."""
    b = ['<path d="M0,40 L70,40 L70,112 L0,112 L26,76 Z" fill="#c9a032"/>',
         '<path d="M512,40 L442,40 L442,112 L512,112 L486,76 Z" fill="#c9a032"/>',
         '<path d="M50,104 L70,112 L70,96 Z" fill="#8f6f1c"/><path d="M462,104 L442,112 L442,96 Z" fill="#8f6f1c"/>',
         shape("r", "M50,22 L462,22 L462,104 L50,104 Z", "#f2c84b", 12, (40, 18, 472, 108), k=1.8, dark="#c99a28")]
    return doc(512, 128, f'<g filter="url(#rough)">{"".join(b)}</g>', rough("rough", 12, 1.2, 0.05))


def star(filled):
    pts = star_pts(48, 50, 5, 44, 20, -1.5708)
    d = "M" + " L".join(f"{x:.1f},{y:.1f}" for x, y in pts) + " Z"
    if filled:
        body = shape("s", d, "#f2c84b", 14, (0, 0, 96, 96), k=1.4, dark="#c99a28") + \
               '<path d="M36,30 L44,18" stroke="#fff4c8" stroke-width="4" stroke-linecap="round"/>'
    else:
        body = f'<path d="{d}" fill="#8a7a5a" fill-opacity="0.18" stroke="#a8946a" stroke-width="5" stroke-linejoin="round" stroke-dasharray="9 6"/>'
    return doc(96, 96, f'<g filter="url(#rough)">{body}</g>', rough("rough", 14, 0.8, 0.08))


def lock():
    b = ['<path d="M30,44 V32 C30,18 66,18 66,32 V44" stroke="#8e98a8" stroke-width="9" fill="none"/>',
         shape("l", rect_d(20, 42, 56, 44, 8), "#5a6370", 15, (16, 38, 80, 90), k=1.4),
         '<circle cx="48" cy="60" r="6" fill="#f6eedb"/><rect x="45" y="62" width="6" height="12" fill="#f6eedb"/>']
    return doc(96, 96, f'<g filter="url(#rough)">{"".join(b)}</g>', rough("rough", 15, 0.8, 0.08))


def stamp():
    return doc(300, 110, FONT_CSS + '<g filter="url(#rough)" transform="rotate(-8 150 55)">'
               f'<rect x="12" y="16" width="276" height="78" rx="10" fill="none" stroke="{INKT}" stroke-width="7"/>'
               f'<text x="150" y="76" text-anchor="middle" font-family="Fredoka" font-weight="700" font-size="54" fill="{INKT}">EM BREVE</text></g>',
               rough("rough", 16, 2.5, 0.09))


def main():
    for name, svg, w, h, k in [("logo", logo(), 1700, 340, 2), ("papel", paper(), 192, 192, 1), ("madeira", wood(), 256, 96, 1),
                               ("faixa", ribbon(), 512, 128, 1), ("estrela", star(True), 96, 96, 2),
                               ("estrela_vazia", star(False), 96, 96, 2), ("cadeado", lock(), 96, 96, 2),
                               ("em_breve", stamp(), 300, 110, 2)]:
        queue(svg, f"{SRC}/{name}.svg", f"{OUT}/{name}.png", w, h, k)
    print("ui:", render_all())


if __name__ == "__main__":
    main()
