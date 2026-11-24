"""Spells e eventos (Relatório 04) — Etapa 1: caixas das 4 famílias, S01, S03, S06, S10, S11, S13, G10 e HUD.
Estilo papel e giz (formas chapadas, textura de giz, borda tremida). Cada família tem COR + FORMA + ÍCONE (nunca só cor).
Gera art/out/game/spells/*.png (peças que o jogo anima) e a prancha art/out/prancha_spells_etapa1.png.
Rodar: python3 art/src/efeitos/spells.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from papel import ellipse_d, rect_d, rough, shape  # noqa: E402
from svg import doc, queue, render_all, shade  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.."))
SRC = os.path.join(ROOT, "art/src/efeitos/svg/spells")
OUT = os.path.join(ROOT, "art/out/game/spells")
INK = "#2a1a2e"
METAL, METAL_D, METAL_L = "#9aa4ae", "#6b7783", "#c9d1d8"
FAM = {  # cor, forma da caixa, ícone
    "ataque": ("#f08a3d", "espinhos", "punho"),
    "controle": ("#8a63d2", "capsula", "ima"),
    "engenharia": ("#f2c84b", "hexagono", "chave"),
    "transformacao": ("#3fc1c9", "losango", "engrenagem"),
}
ICE, ICE_D, FIRE, FIRE_L = "#9fe3f5", "#5fb6d6", "#f08a3d", "#ffd36b"


def wrap(w, h, body, seed, scale=0.8):
    return doc(w, h, f'<g filter="url(#rough)">{body}</g>', rough(seed=seed, scale=scale, freq=0.08))


def star_pts(cx, cy, n, r0, r1, rot=0.0):
    pts = []
    for i in range(n * 2):
        a = rot + i * math.pi / n
        r = r0 if i % 2 == 0 else r1
        pts.append(f"{cx + r * math.cos(a):.1f},{cy + r * math.sin(a):.1f}")
    return " ".join(pts)


# ---------------------------------------------------------------- ícones (64x64, centro 32,32)
def icon(name, col="#ffffff"):
    if name == "punho":
        return (f'<path d="M18,30 C18,22 24,18 32,18 L42,18 C48,18 50,22 50,27 L50,40 C50,46 46,48 40,48 L26,48 C21,48 18,45 18,40 Z" fill="{col}"/>'
                f'<path d="M26,18 V30 M34,18 V30 M42,19 V30" stroke="{INK}" stroke-width="2.4" opacity="0.5"/>'
                f'<path d="M8,26 h8 M6,34 h10 M8,42 h8" stroke="{col}" stroke-width="3.4" stroke-linecap="round"/>')
    if name == "ima":
        return (f'<path d="M16,14 V34 C16,44 23,50 32,50 C41,50 48,44 48,34 V14 H38 V34 C38,38 35,40 32,40 C29,40 26,38 26,34 V14 Z" fill="{col}"/>'
                f'<path d="M16,14 H26 V20 H16 Z M38,14 H48 V20 H38 Z" fill="{INK}" opacity="0.45"/>')
    if name == "chave":
        return (f'<path d="M20,48 L36,32" stroke="{col}" stroke-width="8" stroke-linecap="round"/>'
                f'<path d="M36,32 C32,24 38,14 48,16 L42,22 L44,28 L50,30 L56,24 C58,34 48,40 40,36 Z" fill="{col}"/>')
    if name == "engrenagem":
        teeth = []
        for k in range(8):
            a = k * math.pi / 4
            teeth.append(f'<rect x="-4" y="-22" width="8" height="10" rx="2" fill="{col}" transform="translate(32,32) rotate({math.degrees(a):.0f})"/>')
        return "".join(teeth) + f'<circle cx="32" cy="32" r="15" fill="{col}"/><circle cx="32" cy="32" r="6" fill="{INK}" opacity="0.45"/>'
    return ""


# ---------------------------------------------------------------- caixas (96x96)
def caixa_body(fam):
    col, form, ic = FAM[fam]
    dark, light = shade(col, -0.3), shade(col, 0.35)
    if form == "espinhos":       # ataque: caixa com cantos pontudos
        d = "M18,22 L8,10 L26,16 H70 L88,10 L78,22 V74 L88,86 L70,80 H26 L8,86 L18,74 Z"
    elif form == "capsula":      # controle: cápsula arredondada
        d = rect_d(10, 16, 76, 64, 30)
    elif form == "hexagono":     # engenharia: porca sextavada
        d = "M30,10 H66 L86,48 L66,86 H30 L10,48 Z"
    else:                        # transformação: losango
        d = "M48,6 L90,48 L48,90 L6,48 Z"
    b = [shape(f"cx{fam}", d, col, 300 + len(fam), (4, 4, 92, 92), k=2.2, dark=dark, light=light)]
    b.append(f'<g transform="translate(16,16)">{icon(ic)}</g>')
    b.append(f'<text x="48" y="58" font-family="Fredoka, Arial" font-weight="700" font-size="0" fill="{INK}">?</text>')
    return "".join(b)


# ---------------------------------------------------------------- spells (peças que o jogo anima)
def s01_canhao():
    """Punho Pneumático: tubo do pistão (preso na mão) — 128x64; a luva (s01_luva) é desenhada à parte e estica."""
    b = [shape("s1b", rect_d(8, 18, 78, 30, 8), "#d9622b", 11, (6, 16, 88, 50), k=2.0, dark="#9e3f17")]
    b.append(shape("s1c", rect_d(80, 14, 18, 38, 4), METAL, 12, (78, 12, 100, 54), k=2.0, dark=METAL_D))
    for x in (22, 38, 54):
        b.append(f'<rect x="{x}" y="18" width="6" height="30" fill="#9e3f17" opacity="0.55"/>')
    b.append(f'<circle cx="24" cy="54" r="8" fill="{METAL_D}"/><circle cx="24" cy="54" r="3" fill="{METAL_L}"/>')
    return b


def s01_luva():
    d = "M8,10 C8,4 14,2 22,2 L44,2 C52,2 56,8 56,16 L56,36 C56,44 50,48 42,48 L18,48 C12,48 8,44 8,38 Z"
    b = [shape("s1l", d, "#e8503a", 13, (6, 0, 58, 50), k=2.0, dark="#a8301f", light="#ff8a6a")]
    b.append(f'<path d="M20,4 V22 M32,3 V22 M44,4 V22" stroke="#a8301f" stroke-width="3"/>')
    return b


def s03_canhao():
    """Canhão Criogênico: tanque de gás + bico com gelo — 128x64."""
    b = [shape("s3t", rect_d(6, 10, 40, 44, 14), "#dfe9f2", 21, (4, 8, 48, 56), k=2.0, dark="#9fb3c4")]
    b.append(f'<rect x="14" y="20" width="24" height="7" rx="2" fill="{ICE_D}"/>')
    b.append(shape("s3c", rect_d(40, 20, 62, 22, 6), "#5f87b8", 22, (38, 18, 104, 44), k=2.0, dark="#3c5e8a"))
    b.append(shape("s3g", "M98,14 L120,20 L124,31 L120,42 L98,48 Z", ICE, 23, (96, 12, 126, 50), k=2.0, dark=ICE_D, light="#ffffff"))
    for (x, y) in ((104, 12), (114, 50), (122, 16)):
        b.append(f'<polygon points="{star_pts(x, y, 4, 5, 2)}" fill="#ffffff"/>')
    return b


def s03_projetil():
    b = [f'<polygon points="{star_pts(32, 32, 6, 26, 12, 0.3)}" fill="{ICE_D}"/>',
         f'<polygon points="{star_pts(32, 32, 6, 18, 8, 0.8)}" fill="{ICE}"/>',
         '<circle cx="32" cy="32" r="7" fill="#ffffff"/>']
    return b


def s03_gelo():
    """Faixa de gelo no chão (128x24): translúcida, borda clara e brilhos — o jogo estica na largura."""
    b = [shape("s3f", rect_d(2, 6, 124, 14, 6), ICE, 24, (0, 4, 128, 22), k=1.6, dark=ICE_D, light="#ffffff")]
    b.append('<path d="M10,9 H60 M74,9 H110" stroke="#ffffff" stroke-width="2.4" stroke-linecap="round" opacity="0.9"/>')
    return b


def s06_ima():
    """Superímã: ferradura com bobinas — 112x80 (polos à direita)."""
    d = "M20,8 H70 C92,8 104,22 104,40 C104,58 92,72 70,72 H20 V54 H70 C80,54 86,48 86,40 C86,32 80,26 70,26 H20 Z"
    b = [shape("s6", d, "#d94a5a", 31, (18, 6, 106, 74), k=2.0, dark="#9e2a3a", light="#ff8a96")]
    b.append(f'<rect x="8" y="8" width="16" height="18" rx="3" fill="{METAL_L}"/><rect x="8" y="54" width="16" height="18" rx="3" fill="{METAL_L}"/>')
    for x in (34, 44, 54):
        b.append(f'<path d="M{x},6 V28 M{x},52 V74" stroke="#f2c84b" stroke-width="4" stroke-linecap="round"/>')
    return b


def s10_andaime():
    """Andaime Relâmpago: plataforma dobrável com pés articulados — 192x56 (3 tiles)."""
    b = [shape("s10", rect_d(4, 4, 184, 16, 4), "#d9a05e", 41, (2, 2, 190, 22), k=2.0, dark="#8f5a2c")]
    for x in (24, 96, 168):
        b.append(f'<path d="M{x},20 L{x - 12},52 M{x},20 L{x + 12},52" stroke="#71829a" stroke-width="5" stroke-linecap="round"/>')
    b.append('<rect x="10" y="20" width="172" height="6" fill="#f2c84b"/>')
    for x in range(14, 182, 20):
        b.append(f'<rect x="{x}" y="20" width="10" height="6" fill="{INK}"/>')
    return b


def s10_holo():
    """Prévia holográfica (contorno tracejado ciano) — 192x56."""
    return [f'<rect x="4" y="4" width="184" height="16" rx="4" fill="#3fc1c9" fill-opacity="0.25" stroke="#3fc1c9" stroke-width="3" stroke-dasharray="10 6"/>',
            '<path d="M24,20 L12,52 M24,20 L36,52 M96,20 L84,52 M96,20 L108,52 M168,20 L156,52 M168,20 L180,52" stroke="#3fc1c9" stroke-width="3" stroke-dasharray="6 5" opacity="0.8"/>']


def s11_controle():
    """Teleporte de Manutenção: controle com antena e tela — 64x64."""
    b = [shape("s11", rect_d(14, 18, 34, 42, 8), "#4a5e9a", 51, (12, 16, 50, 62), k=1.8, dark="#2f3d6e")]
    b.append('<rect x="19" y="24" width="24" height="14" rx="3" fill="#9ff7c8"/>')
    b.append('<circle cx="25" cy="48" r="4" fill="#f2c84b"/><circle cx="37" cy="48" r="4" fill="#d94a5a"/>')
    b.append(f'<path d="M40,18 L48,4" stroke="{METAL_D}" stroke-width="3" stroke-linecap="round"/><circle cx="48" cy="4" r="4" fill="#9ff7c8"/>')
    return b


def s13_armadura():
    """Armadura Fornalha: carcaça de forno com boca de fogo, rebites e chaminé — 160x150 (pés em y≈146)."""
    b = [shape("s13a", "M24,40 C24,26 36,18 52,18 H108 C124,18 136,26 136,40 V128 C136,138 128,144 118,144 H42 C32,144 24,138 24,128 Z",
               "#7c5a4a", 61, (22, 16, 138, 146), k=2.4, dark="#4e372d", light="#a9806a")]
    b.append(shape("s13b", rect_d(46, 58, 68, 46, 10), INK, 62, (44, 56, 116, 106), k=2.0))
    b.append(f'<path d="M54,100 C56,80 66,86 68,70 C74,84 84,78 86,62 C94,80 102,82 104,100 Z" fill="{FIRE}"/>')
    b.append(f'<path d="M66,100 C68,88 74,90 76,80 C80,90 88,88 90,100 Z" fill="{FIRE_L}"/>')
    for (x, y) in ((34, 30), (126, 30), (34, 132), (126, 132), (80, 26)):
        b.append(f'<circle cx="{x}" cy="{y}" r="4" fill="{METAL_L}"/>')
    b.append(shape("s13c", rect_d(104, 0, 18, 24, 3), METAL_D, 63, (102, -2, 124, 26), k=1.8))
    b.append('<rect x="40" y="112" width="80" height="8" rx="3" fill="#f2c84b"/>')
    return b


def g10_capsula():
    """Carga Especial: cápsula com paraquedas listrado — 128x160 (cápsula embaixo)."""
    b = ['<path d="M8,60 C8,20 40,4 64,4 C88,4 120,20 120,60 Z" fill="#ffffff"/>']
    for k in range(4):
        x0 = 8 + k * 28
        b.append(f'<path d="M{x0 + 14},60 C{x0 + 14},30 {x0 + 20},10 {64},4 C{x0 + 6},14 {x0},34 {x0},60 Z" fill="#f08a3d" opacity="0.9"/>')
    b.append('<path d="M12,60 L52,112 M116,60 L76,112 M64,60 V112" stroke="#5a4a3a" stroke-width="2.5"/>')
    b.append(shape("g10", rect_d(40, 108, 48, 48, 12), "#f2c84b", 71, (38, 106, 90, 158), k=2.0, dark="#c49a2a"))
    b.append(f'<text x="64" y="143" font-family="Fredoka, Arial" font-weight="700" font-size="30" fill="{INK}" text-anchor="middle">★</text>')
    return b


PIECES = {  # nome: (largura, altura, função)
    "s01_canhao": (128, 64, s01_canhao), "s01_luva": (64, 50, s01_luva),
    "s03_canhao": (128, 64, s03_canhao), "s03_projetil": (64, 64, s03_projetil), "s03_gelo": (128, 24, s03_gelo),
    "s06_ima": (112, 80, s06_ima), "s10_andaime": (192, 56, s10_andaime), "s10_holo": (192, 56, s10_holo),
    "s11_controle": (64, 64, s11_controle), "s13_armadura": (160, 150, s13_armadura), "g10_capsula": (128, 160, g10_capsula),
}


# ---------------------------------------------------------------- prancha
def label(x, y, t, size=26, col=INK, anchor="middle"):
    return f'<text x="{x}" y="{y}" font-family="Fredoka, Arial" font-weight="700" font-size="{size}" fill="{col}" text-anchor="{anchor}">{t}</text>'


def place(fn, x, y, s=1.0):
    return f'<g transform="translate({x},{y}) scale({s})">{"".join(fn())}</g>'


def prancha():
    b = ['<rect width="1920" height="1080" fill="#eef7f6"/>', label(960, 56, "SPELLS — ETAPA 1 (para aprovar a arte)", 40)]
    # caixas
    b.append(label(250, 110, "CAIXAS (família visível, spell escondida)", 24))
    names = {"ataque": "ATAQUE", "controle": "CONTROLE", "engenharia": "ENGENHARIA", "transformacao": "TRANSFORM."}
    for i, fam in enumerate(FAM):
        x = 40 + i * 120
        b.append(f'<g transform="translate({x},130)">{caixa_body(fam)}</g>')
        b.append(label(x + 48, 250, names[fam], 15))
    # spells
    cards = [
        ("S01 PUNHO PNEUMÁTICO", 40, 300, lambda: (place(s01_canhao, 10, 40, 1.3) + place(s01_luva, 180, 44, 1.3)
                                                    + '<path d="M140,80 H180" stroke="#9e3f17" stroke-width="10"/>'
                                                    + "".join(f'<path d="M{150 + k * 8},{66 + k * 10} h-40" stroke="#ffffff" stroke-width="4" stroke-linecap="round"/>' for k in range(3)))),
        ("S03 CANHÃO CRIOGÊNICO", 520, 300, lambda: (place(s03_canhao, 0, 40, 1.3) + place(s03_projetil, 190, 40, 1.0)
                                                      + place(s03_gelo, 20, 160, 2.2))),
        ("S06 SUPERÍMÃ", 1000, 300, lambda: (place(s06_ima, 0, 40, 1.4)
                                             + "".join(f'<path d="M{170 + k * 40},{40 + k * 6} C{230 + k * 40},{60} {230 + k * 40},{140} {170 + k * 40},{160 - k * 6}" stroke="#d94a5a" stroke-width="3" fill="none" stroke-dasharray="8 6" opacity="{0.8 - k * 0.2}"/>' for k in range(3)))),
        ("S10 ANDAIME RELÂMPAGO", 1440, 300, lambda: (place(s10_holo, 20, 40, 1.8) + place(s10_andaime, 20, 150, 1.8))),
        ("S11 TELEPORTE", 40, 640, lambda: (place(s11_controle, 0, 40, 2.0)
                                            + '<path d="M150,120 h170" stroke="#9ff7c8" stroke-width="4" stroke-dasharray="10 8"/>'
                                            + '<rect x="320" y="40" width="70" height="120" rx="20" fill="#9ff7c8" fill-opacity="0.35" stroke="#3fc1c9" stroke-width="3" stroke-dasharray="8 5"/>'
                                            + "".join(f'<circle cx="{150 + k * 22}" cy="{100 + (k % 3) * 18}" r="5" fill="{METAL}"/>' for k in range(6)))),
        ("S13 ARMADURA FORNALHA", 520, 640, lambda: (place(s13_armadura, 20, 0, 1.4)
                                                     + f'<path d="M230,120 C290,90 330,130 380,104 C350,140 300,150 230,136 Z" fill="{FIRE}"/>'
                                                     + f'<path d="M232,124 C280,108 310,128 340,118 C320,136 280,140 232,132 Z" fill="{FIRE_L}"/>')),
        ("G10 CARGA ESPECIAL", 1000, 640, lambda: (place(g10_capsula, 10, 10, 1.1) + place(g10_capsula, 220, 40, 0.9)
                                                   + '<path d="M330,0 L300,250 M370,0 L340,250" stroke="#fff4c8" stroke-width="40" opacity="0.35"/>')),
    ]
    for (t, x, y, fn) in cards:
        b.append(f'<rect x="{x}" y="{y}" width="440" height="310" rx="18" fill="#ffffff" opacity="0.7"/>')
        b.append(label(x + 220, y + 34, t, 24))
        b.append(f'<g transform="translate({x + 20},{y + 40})">{fn()}</g>')
    # HUD
    hx, hy = 1440, 640
    b.append(f'<rect x="{hx}" y="{hy}" width="440" height="310" rx="18" fill="#ffffff" opacity="0.7"/>')
    b.append(label(hx + 220, hy + 34, "HUD + TROCA (segurar 0,3 s)", 24))
    b.append(f'<circle cx="{hx + 110}" cy="{hy + 160}" r="62" fill="{FAM["ataque"][0]}"/>')
    b.append(f'<g transform="translate({hx + 78},{hy + 128})">{icon("punho")}</g>')
    for k in range(2):
        b.append(f'<circle cx="{hx + 86 + k * 24}" cy="{hy + 246}" r="9" fill="{INK}"/>')
    b.append(label(hx + 110, hy + 285, "PUNHO · 1 carga", 18))
    b.append(f'<circle cx="{hx + 330}" cy="{hy + 160}" r="62" fill="none" stroke="#d9dde2" stroke-width="12"/>')
    b.append(f'<path d="M{hx + 330},{hy + 98} A62,62 0 1,1 {hx + 272},{hy + 182}" fill="none" stroke="#5cc45c" stroke-width="12" stroke-linecap="round"/>')
    b.append(f'<g transform="translate({hx + 282},{hy + 112})">{caixa_body("controle")}</g>')
    b.append(label(hx + 330, hy + 285, "trocando…", 18))
    return doc(1920, 1080, f'<g filter="url(#rough)">{"".join(b)}</g>', rough(seed=5, scale=0.9, freq=0.06))


def main():
    os.makedirs(OUT, exist_ok=True)
    for fam in FAM:
        queue(wrap(96, 96, caixa_body(fam), 10), f"{SRC}/caixa_{fam}.svg", f"{OUT}/caixa_{fam}.png", 96, 96, 2)
        queue(wrap(64, 64, icon(FAM[fam][2]), 11), f"{SRC}/icone_{fam}.svg", f"{OUT}/icone_{fam}.png", 64, 64, 2)
    for name, (w, h, fn) in PIECES.items():
        queue(wrap(w, h, "".join(fn()), 20), f"{SRC}/{name}.svg", f"{OUT}/{name}.png", w, h, 2)
    queue(prancha(), f"{SRC}/prancha.svg", os.path.join(ROOT, "art/out/prancha_spells_etapa1.png"), 1920, 1080, 1)
    print("spells renderizados:", render_all())


if __name__ == "__main__":
    main()
