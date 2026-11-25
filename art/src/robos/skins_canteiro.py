"""SKINS do mapa 1 do Derruba (Canteiro de Obras) — PROPOSTAS para aprovação (manual docs/manuais/skins.md).
Regras: origem no MAPA; só camadas POR CIMA do desenho do robô (capacete, colete, faixas, sujeira de obra, adesivos);
mesma silhueta e hitbox; a cor do jogador continua dominante; nenhum efeito de jogo.
Rodar: python3 art/src/robos/skins_canteiro.py → art/out/prancha_skins_canteiro.png
"""
import os
import sys

HERE = os.path.dirname(__file__)
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, ".."))
import elenco as E  # noqa: E402
from elenco import INK, S, YEL, YEL_D, STEEL, STEEL_D, STEEL_L  # noqa: E402
from papel import ellipse_d, rect_d, rough  # noqa: E402
from svg import doc, queue, render_all, shade  # noqa: E402

ORANGE, ORANGE_D = "#f08a3d", "#b85a1e"
WHITE, WHITE_D = "#f4f1ea", "#c9c2b4"
REFL = "#e8eef2"          # faixa refletiva
CEMENT, CEMENT_D = "#b9b2a6", "#8f887c"
DIRT = "#7a5a3e"
LEATHER, LEATHER_D = "#8a5a2b", "#5e3b1a"


def zebra(x0, y0, x1, y1, w, n):
    """Faixa zebrada amarelo/preto entre dois pontos (largura w, n listras)."""
    import math
    L = math.hypot(x1 - x0, y1 - y0)
    a = math.degrees(math.atan2(y1 - y0, x1 - x0))
    out = f'<g transform="translate({x0},{y0}) rotate({a:.1f})"><rect x="0" y="{-w / 2}" width="{L:.1f}" height="{w}" fill="{YEL}"/>'
    for i in range(n):
        x = i * L / n
        out += f'<path d="M{x:.1f},{w / 2} l{w * 0.8:.1f},{-w} l{L / n * 0.45:.1f},0 l{-w * 0.8:.1f},{w} Z" fill="{INK}"/>'
    return out + "</g>"


def splats(pts, col, r=1.0, edge=None):
    out = ""
    for (x, y, s) in pts:
        if edge:
            out += f'<ellipse cx="{x}" cy="{y + 0.5}" rx="{2.2 * s * r + 0.7:.1f}" ry="{1.6 * s * r + 0.7:.1f}" fill="{edge}"/>'
        out += f'<ellipse cx="{x}" cy="{y}" rx="{2.2 * s * r:.1f}" ry="{1.6 * s * r:.1f}" fill="{col}"/>'
        out += f'<circle cx="{x + 2.4 * s:.1f}" cy="{y - 1.2 * s:.1f}" r="{0.7 * s:.1f}" fill="{col}"/>'
    return out


# ---------------------------------------------------------------- MARRETÃO
def mar_a_t(c):   # Mestre de obras: colete refletivo laranja (só nas laterais) com faixas prateadas
    out = S("M-25,-42 L-12,-42 L-14,-2 L-17,-2 C-22,-14 -27,-30 -25,-42 Z", ORANGE, (-28, -44, -10, 0), k=0.5, dark=ORANGE_D)
    out += S("M27,-42 L14,-42 L16,-2 L19,-2 C24,-14 29,-30 27,-42 Z", ORANGE, (12, -44, 30, 0), k=0.5, dark=ORANGE_D)
    for y in (-36, -16):
        out += f'<rect x="-25" y="{y}" width="12" height="3" fill="{REFL}"/><rect x="14" y="{y}" width="12" height="3" fill="{REFL}"/>'
    return out


def mar_a_h(c):   # capacete BRANCO de chefe com faixa
    out = S("M-11,0 C-12,-14 -6,-20 1,-20 C9,-20 13,-14 12,0 Z", WHITE, (-13, -22, 14, 2), k=0.6, dark=WHITE_D)
    out += S("M-13,-1 L17,-1 L17,2 L-13,2 Z", WHITE_D, (-14, -2, 18, 3), k=0.4)
    out += f'<rect x="-10" y="-9" width="21" height="2.4" fill="{ORANGE}"/>'
    return out


def mar_b_t(c):   # Demolidor veterano: fita zebrada atravessada + amassados e rebites
    out = zebra(-24, -44, 22, -4, 6, 7)
    out += f'<path d="M-6,-12 q3,-3 6,0" stroke="{shade(c, -0.4)}" stroke-width="1.6" fill="none"/>'
    out += f'<path d="M10,-38 q3,-2 5,1" stroke="{shade(c, -0.4)}" stroke-width="1.6" fill="none"/>'
    for (x, y) in ((-20, -40), (20, -40), (-16, -6), (16, -6)):
        out += f'<circle cx="{x}" cy="{y}" r="1.6" fill="{STEEL_L}"/>'
    return out


def mar_b_h(c):   # capacete com adesivos e arranhões
    out = f'<rect x="-6" y="-16" width="6" height="5" rx="1" fill="#d14d35" transform="rotate(-12 -3 -13)"/>'
    out += f'<circle cx="5" cy="-14" r="2.6" fill="#5cc45c"/><path d="M4,-14 l1,1 l2,-2.4" stroke="{WHITE}" stroke-width="0.9" fill="none"/>'
    out += f'<path d="M-9,-7 l5,-2 M6,-6 l5,-1" stroke="{YEL_D}" stroke-width="1"/>'
    return out


# ---------------------------------------------------------------- PICARETA
def pic_a_t(c):   # Topógrafo: colete amarelo-limão em faixa + bolso com régua
    out = S("M-10,-26 C-6,-29 6,-29 10,-26 L9,-10 C4,-8 -4,-8 -9,-10 Z", "#d7e84a", (-11, -30, 11, -7), k=0.5, dark="#a8b82e")
    out += f'<rect x="-10" y="-19" width="20" height="2.4" fill="{REFL}"/>'
    out += f'<rect x="2" y="-16" width="5" height="5" fill="#b8c83a"/><rect x="3.5" y="-20" width="1.6" height="6" fill="{ORANGE}"/>'
    return out


def pic_a_h(c):   # capacete azul de engenheiro + lente de teodolito (mira vermelha)
    out = S("M-8,-24 C-6,-31 6,-33 11,-27 L13,-24 L-10,-23 Z", "#4f9ad9", (-11, -34, 14, -22), k=0.5, dark="#2f6aa8")
    out += f'<circle cx="7" cy="-19.5" r="5.6" fill="none" stroke="{YEL}" stroke-width="1.4"/>'
    out += f'<path d="M7,-23.5 v8 M3,-19.5 h8" stroke="#d14d35" stroke-width="0.8"/>'
    return out


def pic_b_t(c):   # Escavador de túnel: terra nas pernas/corpo
    return splats([(-6, -6, 1.6), (5, -3, 1.3), (-2, -14, 1.1), (7, -20, 1.0), (-7, -24, 0.9)], DIRT, 1.1, "#5a3e28")


def pic_b_h(c):   # capacete com lanterna de túnel
    out = S("M-8,-24 C-6,-31 6,-33 11,-27 L13,-24 L-10,-23 Z", YEL, (-11, -34, 14, -22), k=0.5, dark=YEL_D)
    out += f'<rect x="9" y="-31" width="6" height="5" rx="1.5" fill="{STEEL_D}"/><circle cx="15" cy="-28.5" r="2.4" fill="#fff1b8"/>'
    out += f'<path d="M17,-28.5 L30,-33 L30,-24 Z" fill="#fff1b8" opacity="0.35"/>'
    return out


# ---------------------------------------------------------------- CHAVE
def cha_a_t(c):   # Eletricista: rolo de fio atravessado no peito + selo de raio + fita isolante
    out = f'<path d="M-14,-28 C-6,-22 4,-30 14,-20" stroke="#2a2a2a" stroke-width="2.6" fill="none"/>'
    out += f'<path d="M-14,-26 C-6,-20 4,-28 14,-18" stroke="#d14d35" stroke-width="1.4" fill="none"/>'
    out += f'<circle cx="-8" cy="-17" r="4.2" fill="{YEL}"/><path d="M-8,-21 l-2,4 h3 l-2,4" stroke="{INK}" stroke-width="1.2" fill="none"/>'
    out += f'<rect x="8" y="-8" width="6" height="3" fill="{INK}"/>'
    return out


def cha_a_h(c):   # capacete laranja no lugar do boné (mesmo volume)
    out = S("M-11,-20 C-9,-28 5,-29 9,-21 L-13,-19 Z", ORANGE, (-14, -30, 10, -18), k=0.4, dark=ORANGE_D)
    out += S("M-11,-21 L-17,-19 L-12,-18 Z", ORANGE_D, (-18, -22, -10, -17), k=0.3)
    out += f'<rect x="-6" y="-26" width="8" height="2" fill="{REFL}"/>'
    return out


def cha_b_t(c):   # Soldador: avental de couro sobre o macacão
    out = S("M-11,-26 L11,-26 L12,-1 C4,1 -4,1 -12,-1 Z", LEATHER, (-13, -27, 13, 2), k=0.5, dark=LEATHER_D)
    out += f'<path d="M-11,-26 L-14,-30 M11,-26 L14,-30" stroke="{LEATHER_D}" stroke-width="1.6"/>'
    out += f'<circle cx="-5" cy="-12" r="1.2" fill="#ffd36b"/><circle cx="4" cy="-6" r="0.9" fill="#ffd36b"/>'
    return out


def cha_b_h(c):   # máscara de solda levantada no alto da cabeça
    out = S("M-12,-20 C-10,-29 6,-30 10,-22 L8,-17 L-12,-17 Z", "#3e4752", (-13, -31, 11, -16), k=0.5, dark="#252b33")
    out += f'<rect x="-4" y="-25" width="9" height="3" rx="1" fill="#1d3a22"/>'
    return out


# ---------------------------------------------------------------- BRITADEIRA
def bri_a_t(c):   # Concreteiro: respingos de cimento no barril
    return splats([(-10, -20, 1.6), (6, -8, 1.5), (12, -22, 1.1), (-4, -4, 1.2), (0, -26, 1.0)], CEMENT, 1.2, CEMENT_D)


def bri_a_h(c):   # cimento no capacete + máscara de pó
    out = splats([(-6, -24, 1.2), (8, -26, 1.0)], CEMENT, 1.2, CEMENT_D)
    out += S("M6,-5 C6,-1 16,-1 16,-5 L14,-7 L8,-7 Z", WHITE, (5, -8, 17, 0), k=0.3, dark=WHITE_D)
    out += f'<path d="M6,-6 L-6,-11 M16,-6 L20,-11" stroke="{WHITE_D}" stroke-width="0.9"/>'
    return out


def bri_b_t(c):   # Sinaleiro: faixas refletivas no barril
    return (f'<path d="M-16,-10 C-6,-6 6,-6 16,-10" stroke="{REFL}" stroke-width="2.6" fill="none"/>'
            f'<path d="M-16,-19 C-6,-15 6,-15 16,-19" stroke="{ORANGE}" stroke-width="2.6" fill="none"/>')


def bri_b_h(c):   # capacete laranja + abafador de ouvido
    out = S("M-14,-15 C-14,-30 18,-30 18,-15 Z", ORANGE, (-15, -30, 19, -14), k=0.5, dark=ORANGE_D)
    out += f'<rect x="-16" y="-16.5" width="36" height="3" rx="1.5" fill="{ORANGE_D}"/>'
    out += f'<path d="M-9,-24 C-10,-12 -10,-12 -9,-8" stroke="{INK}" stroke-width="1.6" fill="none"/>'
    out += S(ellipse_d(-9, -7, 3.6, 4.4), YEL, (-13, -12, -5, -2), k=0.3, dark=YEL_D)
    return out


# ---------------------------------------------------------------- PÁ
def pa_a_t(c):   # Operador de escavadeira: tronco com faixa refletiva extra e placa "ON"
    out = f'<rect x="-14" y="-30" width="28" height="3" fill="{REFL}"/>'
    out += f'<rect x="-10" y="-24" width="8" height="5" rx="1" fill="{INK}"/><path d="M-8.5,-21.5 h5" stroke="#5cc45c" stroke-width="1.4"/>'
    return out


def pa_a_h(c):   # cabine com teto zebrado e giroflex grande
    out = zebra(-10, -21.5, 12, -21.5, 3.2, 5)
    out += f'<rect x="-3" y="-30" width="9" height="7" rx="3" fill="{ORANGE}"/><rect x="-4" y="-24" width="11" height="2" fill="{STEEL_D}"/>'
    out += f'<path d="M1.5,-29 v-2 M-2,-28 l-2,-2 M5,-28 l2,-2" stroke="#ffd36b" stroke-width="1"/>'
    return out


def pa_b_t(c):   # Turno da noite: fita de LED amarela no peito + faixas refletivas
    out = f'<rect x="-14" y="-23" width="28" height="4" fill="{INK}"/>'
    for x in range(-12, 13, 4):
        out += f'<circle cx="{x}" cy="-21" r="1.4" fill="#fff1b8"/>'
    out += f'<rect x="-14" y="-31" width="28" height="2.4" fill="{REFL}"/>'
    return out


def pa_b_h(c):   # faróis na cabine
    out = ""
    for y in (-19, -11):
        out += f'<rect x="10.5" y="{y}" width="4" height="5" rx="1.2" fill="{INK}"/><rect x="11.5" y="{y + 1}" width="3" height="3" rx="1" fill="#fff1b8"/>'
    out += f'<path d="M14.5,-18 L30,-24 L30,-4 L14.5,-10 Z" fill="#fff1b8" opacity="0.4"/>'
    return out


SKINS = {
    "marretao": [("MESTRE DE OBRAS", "capacete branco de chefe, colete refletivo", mar_a_t, mar_a_h),
                 ("DEMOLIDOR VETERANO", "fita zebrada no peito, adesivos e rebites", mar_b_t, mar_b_h)],
    "picareta": [("TOPÓGRAFO", "capacete azul, colete limão, lente de teodolito", pic_a_t, pic_a_h),
                 ("ESCAVADOR DE TÚNEL", "capacete com lanterna, terra no corpo", pic_b_t, pic_b_h)],
    "chave": [("ELETRICISTA", "capacete laranja, fio no peito, selo de raio", cha_a_t, cha_a_h),
              ("SOLDADOR", "máscara de solda levantada, avental de couro", cha_b_t, cha_b_h)],
    "britadeira": [("CONCRETEIRO", "respingos de cimento, máscara de pó", bri_a_t, bri_a_h),
                   ("SINALEIRO", "capacete laranja, abafador, faixas refletivas", bri_b_t, bri_b_h)],
    "pa": [("OPERADOR DE ESCAVADEIRA", "teto zebrado, giroflex grande", pa_a_t, pa_a_h),
           ("TURNO DA NOITE", "faróis na cabine, fita de LED", pa_b_t, pa_b_h)],
}

_ORIG = {cid: (E.CHARS[cid]["torso"], E.CHARS[cid]["head"]) for cid in E.CHARS}


def vestir(cid, k):
    """Aplica a skin k (-1 = padrão) por cima do desenho original do robô."""
    t0, h0 = _ORIG[cid]
    if k < 0:
        E.CHARS[cid]["torso"], E.CHARS[cid]["head"] = t0, h0
        return
    _, _, ft, fh = SKINS[cid][k]
    E.CHARS[cid]["torso"] = lambda c, e, t0=t0, ft=ft: t0(c, e) + ft(c)
    E.CHARS[cid]["head"] = lambda c, e, L="all", h0=h0, fh=fh: h0(c, e, L) + (fh(c) if L in ("all", "base") else "")


def prancha():
    W, row = 1920, 470
    H = 170 + row * len(E.CHARS) + 30
    L = E.label
    b = [f'<rect width="{W}" height="{H}" fill="#cdeef0"/>',
         L(W / 2, 62, "SKINS DO CANTEIRO DE OBRAS (Derruba · mapa 1) — PROPOSTAS PARA APROVAR", 40),
         L(W / 2, 104, "só camadas por cima do robô: mesma silhueta e hitbox, cor do jogador dominante, sem efeito de jogo", 22, "#2a4a58", weight=500)]
    cols = [(-1, "PADRÃO"), (0, "SKIN A"), (1, "SKIN B")]
    x0, cw = 250, 556
    for j, (_, nm) in enumerate(cols):
        b.append(L(x0 + cw * j + cw / 2, 150, nm, 28, "#2a4a58"))
    for i, cid in enumerate(E.CHARS):
        y = 170 + i * row
        b.append(f'<rect x="16" y="{y + 6}" width="{W - 32}" height="{row - 14}" rx="22" fill="#ffffff" opacity="0.4"/>')
        b.append(L(30, y + 60, E.CHARS[cid]["nome"], 34, INK, "start"))
        for j, (k, _) in enumerate(cols):
            vestir(cid, k)
            cx = x0 + cw * j
            gy = y + 318
            b.append(f'<path d="M{cx + 20},{gy} H{cx + cw - 20}" stroke="#9cc7cf" stroke-width="5" stroke-linecap="round"/>')
            b.append(f'<g transform="translate({cx + 120},{gy}) scale(2.3)">{E.draw(cid, E.POSES[cid]["parado"], E.COLORS[i])}</g>')
            b.append(f'<g transform="translate({cx + 330},{gy}) scale(2.3)">{E.draw(cid, E.POSES[cid]["pesado_golpe"], E.COLORS[i])}</g>')
            gy2 = y + 418
            b.append(f'<rect x="{cx + 40}" y="{gy2}" width="{cw - 80}" height="10" fill="#d8cdb8"/>')
            for ci in range(4):   # tamanho de jogo, nas 4 cores de jogador
                b.append(f'<g transform="translate({cx + 110 + ci * 105},{gy2}) scale(1.15)">{E.draw(cid, E.POSES[cid]["parado"], E.COLORS[ci])}</g>')
            if k >= 0:
                nome, desc, _, _ = SKINS[cid][k]
                b.append(L(cx + cw / 2, y + 44, nome, 24, ORANGE_D))
                b.append(L(cx + cw / 2, y + 70, desc, 17, "#2a4a58", weight=500))
        vestir(cid, -1)
    return doc(W, H, f'<g filter="url(#rough)">{"".join(b)}</g>', rough(seed=11, scale=0.8, freq=0.08))


def main():
    src = os.path.join(E.ROOT, "art/src/robos/svg")
    os.makedirs(src, exist_ok=True)
    out = os.path.join(E.ROOT, "art/out/prancha_skins_canteiro.png")
    queue(prancha(), f"{src}/prancha_skins_canteiro.svg", out, 1920, 170 + 470 * len(E.CHARS) + 30, 1)
    print("skins:", render_all(), out)


if __name__ == "__main__":
    main()
