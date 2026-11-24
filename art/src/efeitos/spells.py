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
    """Caixa de spell: engradado com moldura metálica, cantos aparafusados, alça, placa da família (forma + ícone) e '?'."""
    col, form, ic = FAM[fam]
    dark, light = shade(col, -0.32), shade(col, 0.35)
    b = []
    # corpo do engradado (madeira pintada na cor da família) + ripas
    b.append(shape(f"cb{fam}", rect_d(10, 20, 76, 66, 8), col, 300 + len(fam), (8, 18, 88, 88), k=2.0, dark=dark, light=light))
    for x in (28, 48, 68):
        b.append(f'<rect x="{x - 2}" y="22" width="4" height="62" fill="{dark}" opacity="0.45"/>')
    # moldura metálica e cantos com parafuso
    b.append(f'<rect x="10" y="20" width="76" height="66" rx="8" fill="none" stroke="{METAL}" stroke-width="5"/>')
    for (x, y) in ((14, 24), (82, 24), (14, 82), (82, 82)):
        b.append(f'<rect x="{x - 7}" y="{y - 7}" width="14" height="14" rx="3" fill="{METAL_L}"/><circle cx="{x}" cy="{y}" r="2.4" fill="{METAL_D}"/>')
    # alça no topo
    b.append(f'<path d="M36,20 V10 H60 V20" stroke="{METAL_D}" stroke-width="5" fill="none" stroke-linejoin="round"/>')
    # placa da família (a FORMA muda por família) com o ícone
    if form == "espinhos":
        plate = "M48,30 L56,38 L66,36 L62,46 L68,54 L58,56 L54,66 L48,60 L42,66 L38,56 L28,54 L34,46 L30,36 L40,38 Z"
    elif form == "capsula":
        plate = rect_d(28, 34, 40, 30, 15)
    elif form == "hexagono":
        plate = "M38,30 H58 L68,48 L58,66 H38 L28,48 Z"
    else:
        plate = "M48,28 L68,48 L48,68 L28,48 Z"
    b.append(f'<path d="{plate}" fill="#fff7ee"/>')
    b.append(f'<g transform="translate(33,33) scale(0.47)">{icon(ic, dark)}</g>')
    # "?" estampado no canto (a spell só aparece ao pegar)
    b.append(f'<text x="74" y="80" font-family="Fredoka, Arial" font-weight="700" font-size="20" fill="#fff7ee" text-anchor="middle">?</text>')
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
    """Luva de boxe da ponta do braço de tesoura (aponta para a direita) — 64x50: punho de metal, luva, polegar e brilho."""
    b = [shape("s1k", rect_d(1, 14, 14, 22, 3), METAL, 13, (0, 12, 16, 38), k=1.6, dark=METAL_D)]
    body = "M14,12 C14,4 22,1 34,1 C52,1 63,10 63,25 C63,40 52,49 34,49 C22,49 14,46 14,38 Z"
    b.append(shape("s1l", body, "#e8503a", 14, (12, 0, 64, 50), k=2.0, dark="#a8301f", light="#ff8a6a"))
    b.append('<path d="M22,30 C22,24 30,22 38,25 C44,27 44,34 38,36 C32,38 24,37 22,30 Z" fill="#c93a2a"/>')
    b.append('<path d="M30,7 C40,5 52,9 57,17" stroke="#ffffff" stroke-width="3.4" fill="none" stroke-linecap="round" opacity="0.75"/>')
    b.append('<path d="M14,16 H18 M14,34 H18" stroke="#a8301f" stroke-width="3"/>')
    b.append(f'<circle cx="7" cy="25" r="3" fill="{METAL_L}"/>')
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


def s10_tabua():
    """Andaime Relâmpago: deque (192x24) em 3 pedaços (o jogo desliza as abas): tábuas de madeira, ponteiras de
    metal, rodapé zebrado e parafusos. Cortado em terços pelo jogo."""
    b = [shape("s10a", rect_d(1, 1, 190, 16, 3), "#d9a05e", 41, (0, 0, 192, 18), k=1.6, dark="#8f5a2c", light="#f0c487")]
    for x in (64, 128):
        b.append(f'<rect x="{x - 1}" y="1" width="2" height="16" fill="#8f5a2c"/>')
    for x0 in (8, 72, 136):
        b.append(f'<path d="M{x0},6 C{x0 + 14},4 {x0 + 30},8 {x0 + 48},5 M{x0 + 4},12 C{x0 + 20},10 {x0 + 34},13 {x0 + 50},11" stroke="#b47a3e" stroke-width="1.4" fill="none"/>')
    b.append('<rect x="1" y="17" width="190" height="6" fill="#f2c84b"/>')
    for x in range(4, 190, 12):
        b.append(f'<path d="M{x},23 L{x + 6},17 L{x + 10},17 L{x + 4},23 Z" fill="{INK}"/>')
    for x0 in (0, 184):
        b.append(f'<rect x="{x0}" y="0" width="8" height="24" rx="2" fill="#71829a"/>')
    for x in (32, 96, 160):
        b.append(f'<circle cx="{x}" cy="9" r="2.2" fill="{METAL_L}"/>')
    return b


def s10_trouxa():
    """Andaime dobrado (a 'trouxa' que o robô arremessa) — 48x32: tábuas empilhadas, tubos e cinta amarela."""
    b = [shape("s10t", rect_d(4, 8, 40, 18, 3), "#d9a05e", 44, (2, 6, 46, 28), k=1.6, dark="#8f5a2c")]
    b.append('<path d="M2,10 L46,6 M2,26 L46,22" stroke="#71829a" stroke-width="4" stroke-linecap="round"/>')
    b.append('<rect x="20" y="4" width="8" height="26" rx="2" fill="#f2c84b"/>')
    b.append(f'<path d="M21,8 H27 M21,14 H27 M21,20 H27" stroke="{INK}" stroke-width="2"/>')
    return b


def s11_portal():
    """Teleporte de Manutenção: escotilha de bolso (anel zebrado + miolo azul em espiral) — 80x80."""
    b = []
    b.append(f'<circle cx="40" cy="40" r="36" fill="{INK}"/>')
    for k in range(12):
        a0, a1 = k * 30, k * 30 + 15
        r0, r1 = 36, 27
        p = []
        for a_, r_ in ((a0, r0), (a1, r0), (a1, r1), (a0, r1)):
            p.append(f"{40 + r_ * math.cos(math.radians(a_)):.1f},{40 + r_ * math.sin(math.radians(a_)):.1f}")
        b.append(f'<polygon points="{" ".join(p)}" fill="#f2c84b"/>')
    b.append('<circle cx="40" cy="40" r="26" fill="#3fc1c9"/>')
    for k in range(3):
        b.append(f'<path d="M40,40 m0,-{20 - k * 6} a{20 - k * 6},{20 - k * 6} 0 1,1 -{(20 - k * 6) * 0.8:.1f},{(20 - k * 6) * 0.6:.1f}" stroke="#bff6ff" stroke-width="3" fill="none" stroke-linecap="round"/>')
    b.append('<circle cx="40" cy="40" r="5" fill="#ffffff"/>')
    for (x, y) in ((40, 6), (74, 40), (40, 74), (6, 40)):
        b.append(f'<circle cx="{x}" cy="{y}" r="3.2" fill="{METAL_L}"/>')
    return b


def s13_frente():
    """Armadura Fornalha (frente): tronco de fornalha com VIGIA de vidro (o rosto do robô aparece nela), ombreiras,
    grelha de fogo e rebites — 150x130 (o jogo põe sobre o corpo do robô; pés em y≈130)."""
    b = []
    body = "M22,34 C22,22 32,14 46,14 H104 C118,14 128,22 128,34 V104 C128,116 120,124 108,124 H42 C30,124 22,116 22,104 Z"
    b.append(shape("a13f", body, "#7c5a4a", 61, (20, 12, 130, 126), k=2.4, dark="#4e372d", light="#a9806a"))
    # ombreiras
    for x0 in (4, 112):
        b.append(shape(f"a13o{x0}", rect_d(x0, 18, 34, 26, 10), "#5f4438", 62 + x0, (x0 - 2, 16, x0 + 36, 46), k=2.0, dark="#3d2b23"))
        b.append(f'<rect x="{x0 + 4}" y="22" width="26" height="6" rx="2" fill="#f2c84b"/>')
    # vigia (aro de latão + vidro escuro; o jogo desenha o rosto do robô dentro)
    b.append('<circle cx="75" cy="50" r="27" fill="#c9a03a"/><circle cx="75" cy="50" r="21" fill="#2b3d4f"/>')
    b.append('<path d="M60,40 C64,33 70,31 76,31" stroke="#ffffff" stroke-width="3" fill="none" stroke-linecap="round" opacity="0.7"/>')
    for k in range(8):
        a_ = k * math.pi / 4
        b.append(f'<circle cx="{75 + 24 * math.cos(a_):.1f}" cy="{50 + 24 * math.sin(a_):.1f}" r="2" fill="#7a5a1a"/>')
    # grelha de fogo
    b.append(shape("a13g", rect_d(44, 84, 62, 28, 6), INK, 63, (42, 82, 108, 114), k=1.8))
    b.append(f'<path d="M50,110 C52,96 60,100 62,90 C68,100 76,96 78,86 C84,98 92,96 100,110 Z" fill="{FIRE}"/>')
    b.append(f'<path d="M60,110 C62,102 68,104 70,96 C74,104 82,102 88,110 Z" fill="{FIRE_L}"/>')
    for x in range(50, 104, 10):
        b.append(f'<rect x="{x}" y="84" width="3" height="28" fill="#3d2b23"/>')
    for (x, y) in ((30, 26), (120, 26), (30, 116), (120, 116)):
        b.append(f'<circle cx="{x}" cy="{y}" r="3.4" fill="{METAL_L}"/>')
    return b


def s13_costas():
    """Armadura Fornalha (costas): tanque de carvão e chaminé soltando fumaça — 150x130."""
    b = [shape("a13c", rect_d(30, 20, 90, 96, 18), "#5f4438", 64, (28, 18, 122, 118), k=2.2, dark="#3d2b23")]
    b.append(shape("a13ch", rect_d(92, 0, 20, 30, 3), METAL_D, 65, (90, -2, 114, 32), k=1.8))
    b.append('<ellipse cx="102" cy="2" rx="12" ry="4" fill="#3d3340"/>')
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


# ---------------------------------------------------------------- Etapa 2 (ataque)
def s02_laser():
    """Laser de Corte: corpo de maçarico com aletas, lente incandescente na ponta — 128x64."""
    b = [shape("s2c", rect_d(8, 16, 76, 30, 8), "#4a5566", 81, (6, 14, 86, 48), k=2.0, dark="#2e3642", light="#71829a")]
    for x in (20, 30, 40, 50):
        b.append(f'<rect x="{x}" y="10" width="5" height="42" rx="2" fill="#71829a"/>')
    b.append(shape("s2b", rect_d(80, 22, 28, 18, 4), METAL, 82, (78, 20, 110, 42), k=1.6, dark=METAL_D))
    b.append('<circle cx="112" cy="31" r="12" fill="#c9a03a"/><circle cx="112" cy="31" r="8" fill="#ff5a3a"/>')
    b.append('<circle cx="109" cy="28" r="3" fill="#ffe2b0"/>')
    b.append(f'<rect x="12" y="44" width="14" height="16" rx="3" fill="{INK}"/>')
    b.append('<path d="M60,20 H74" stroke="#f2c84b" stroke-width="4" stroke-linecap="round"/>')
    return b


def s05_rebiteira():
    """Rebiteira Ricochete: pistola pneumática gorda — cilindro de aço, cabo de pistola, pente de rebites em cima,
    bico com mola e mangueira de ar — 128x64 (cabo em x≈40, bico em x≈124)."""
    b = []
    b.append('<path d="M14,34 C0,40 2,58 18,60 C26,61 30,56 34,54" stroke="#2e3642" stroke-width="6" fill="none" stroke-linecap="round"/>')
    b.append(shape("s5g", "M30,34 L50,34 L46,60 C46,62 44,63 42,63 L30,63 C28,63 27,61 27,59 Z", "#3e4752", 83, (26, 32, 52, 64), k=1.6, dark="#252b33"))
    b.append(shape("s5c", "M12,20 C12,12 18,9 26,9 H92 C100,9 104,14 104,22 V30 C104,38 100,40 92,40 H26 C18,40 12,36 12,30 Z",
               METAL, 84, (10, 7, 106, 42), k=2.0, dark=METAL_D, light=METAL_L))
    b.append('<rect x="20" y="16" width="70" height="7" rx="3" fill="#f08a3d"/>')
    b.append(shape("s5m", rect_d(46, 0, 34, 12, 3), "#3e4752", 85, (44, -2, 82, 14), k=1.4))
    for x in (53, 63, 73):
        b.append(f'<path d="M{x - 4},10 A4,4 0 0 1 {x + 4},10 Z" fill="#f2c84b"/>')
    b.append(shape("s5n", rect_d(102, 15, 14, 20, 3), "#f08a3d", 86, (100, 13, 118, 37), k=1.4, dark="#b05a20"))
    b.append(shape("s5t", rect_d(114, 19, 12, 12, 2), METAL_D, 87, (112, 17, 128, 33), k=1.2))
    b.append(f'<circle cx="122" cy="25" r="3" fill="{INK}"/>')
    for x in (30, 40):
        b.append(f'<circle cx="{x}" cy="30" r="2.4" fill="{METAL_D}"/>')
    return b


def s04_marreta():
    """Marreta Sísmica: cabeça de aço enorme com faixa zebrada, amortecedor de pistão e núcleo laranja aceso;
    cabo longo com fita — 64x128 (cabeça em cima, pega em (32,120))."""
    b = []
    b.append(shape("s4c", rect_d(27, 34, 10, 92, 4), "#8f5a2c", 91, (25, 32, 39, 128), k=1.6, dark="#5e3a1a"))
    for y in (98, 106, 114):
        b.append(f'<rect x="26" y="{y}" width="12" height="4" fill="#2a1a2e"/>')
    b.append(shape("s4p", rect_d(24, 26, 16, 14, 3), METAL_D, 92, (22, 24, 42, 42), k=1.4))
    b.append(shape("s4h", rect_d(2, 2, 60, 30, 7), "#4a5566", 93, (0, 0, 64, 34), k=2.2, dark="#2e3642", light="#71829a"))
    b.append('<rect x="2" y="12" width="60" height="9" fill="#f2c84b"/>')
    for x in range(4, 60, 10):
        b.append(f'<path d="M{x},21 L{x + 5},12 L{x + 9},12 L{x + 4},21 Z" fill="{INK}"/>')
    b.append('<rect x="0" y="4" width="6" height="26" rx="2" fill="#9aa4ae"/><rect x="58" y="4" width="6" height="26" rx="2" fill="#9aa4ae"/>')
    b.append('<circle cx="32" cy="7" r="4" fill="#ff8a3a"/><circle cx="32" cy="7" r="2" fill="#ffe2b0"/>')
    return b


def s18_disco():
    """Disco de Corte: serra circular com dentes, furo central e reflexo — 64x64."""
    pts = []
    for k in range(24):
        a = k * math.pi * 2 / 24
        r = 31 if k % 2 == 0 else 26
        pts.append(f"{32 + r * math.cos(a):.1f},{32 + r * math.sin(a):.1f}")
    b = [f'<polygon points="{" ".join(pts)}" fill="{METAL_D}"/>']
    b.append(shape("s18", ellipse_d(32, 32, 24, 24), METAL_L, 85, (6, 6, 58, 58), k=1.6, dark=METAL))
    b.append('<circle cx="32" cy="32" r="9" fill="#d9622b"/><circle cx="32" cy="32" r="4" fill="#2a1a2e"/>')
    b.append('<path d="M18,22 C22,15 30,12 38,13" stroke="#ffffff" stroke-width="3" fill="none" stroke-linecap="round" opacity="0.8"/>')
    return b


def s20_canhao():
    """Canhão de Molas: cano largo vermelho com boca de bumbo e janela mostrando a mola — 128x64."""
    b = [shape("s20", rect_d(6, 12, 92, 40, 10), "#d94a3a", 86, (4, 10, 100, 54), k=2.0, dark="#9e2a20", light="#ff8a6a")]
    b.append(shape("s20b", rect_d(94, 6, 28, 52, 8), "#f2c84b", 87, (92, 4, 124, 60), k=1.6, dark="#c49a2a"))
    b.append(f'<rect x="28" y="22" width="52" height="20" rx="4" fill="{INK}"/>')
    b.append('<path d="M32,32 L36,24 L40,40 L44,24 L48,40 L52,24 L56,40 L60,24 L64,40 L68,24 L72,40 L76,32" stroke="#c9d1d8" stroke-width="3" fill="none"/>')
    b.append(f'<rect x="16" y="50" width="16" height="12" rx="3" fill="{INK}"/>')
    return b


def s17_estaca():
    """Bate-Estaca: caixa do pistão (em cima) + estaca de aço com ponta zebrada — 64x192 (a estaca é esticada pelo jogo)."""
    b = [shape("s17h", rect_d(4, 2, 56, 46, 8), "#f2c84b", 88, (2, 0, 62, 50), k=2.0, dark="#c49a2a")]
    for x in range(6, 58, 12):
        b.append(f'<path d="M{x},40 L{x + 6},48 L{x + 12},48 L{x + 6},40 Z" fill="{INK}"/>')
    b.append('<circle cx="16" cy="14" r="4" fill="#d94a3a"/><circle cx="48" cy="14" r="4" fill="#d94a3a"/>')
    b.append(shape("s17p", rect_d(18, 46, 28, 120, 3), METAL, 89, (16, 44, 48, 168), k=1.8, dark=METAL_D, light=METAL_L))
    b.append(f'<rect x="22" y="60" width="4" height="96" fill="{METAL_L}"/>')
    b.append(shape("s17t", "M12,164 H52 L48,190 H16 Z", "#4a5566", 90, (10, 162, 54, 192), k=1.6, dark="#2e3642"))
    return b


PIECES = {  # nome: (largura, altura, função)
    "s01_canhao": (128, 64, s01_canhao), "s01_luva": (64, 50, s01_luva),
    "s03_canhao": (128, 64, s03_canhao),
    "s06_ima": (112, 80, s06_ima), "s10_tabua": (192, 24, s10_tabua), "s10_trouxa": (48, 32, s10_trouxa),
    "s13_frente": (150, 130, s13_frente), "s13_costas": (150, 130, s13_costas),
    "g10_capsula": (128, 160, g10_capsula),
    "s02_laser": (128, 64, s02_laser), "s05_rebiteira": (128, 64, s05_rebiteira), "s18_disco": (64, 64, s18_disco),
    "s20_canhao": (128, 64, s20_canhao), "s17_estaca": (64, 192, s17_estaca), "s04_marreta": (64, 128, s04_marreta),
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
        ("S10 ANDAIME RELÂMPAGO", 1440, 300, lambda: (place(s10_trouxa, 20, 40, 2.4) + place(s10_tabua, 20, 150, 1.8))),
        ("S11 TELEPORTE", 40, 640, lambda: (place(s11_portal, 20, 60, 1.4) + place(s11_portal, 300, 60, 1.4)
                                            + '<path d="M150,120 h170" stroke="#9ff7c8" stroke-width="4" stroke-dasharray="10 8"/>'
                                            + '<rect x="320" y="40" width="70" height="120" rx="20" fill="#9ff7c8" fill-opacity="0.35" stroke="#3fc1c9" stroke-width="3" stroke-dasharray="8 5"/>'
                                            + "".join(f'<circle cx="{150 + k * 22}" cy="{100 + (k % 3) * 18}" r="5" fill="{METAL}"/>' for k in range(6)))),
        ("S13 ARMADURA FORNALHA", 520, 640, lambda: (place(s13_costas, 20, 30, 1.4) + place(s13_frente, 20, 30, 1.4)
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
