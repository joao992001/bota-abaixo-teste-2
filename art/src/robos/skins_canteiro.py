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


# ---------------------------------------------------------------- VERSÃO 2 (2026-11-25): "fantasia completa"
# A v1 (só adesivos/faixas) foi reprovada: "mudanças muito sutis". Agora o TRONCO veste o uniforme inteiro, a COR DO
# JOGADOR vai para o capacete grande (e continua nos braços e pernas), a ferramenta ganha acabamento temático.
TORSO = {   # contorno do tronco de cada robô (para recortar o uniforme exatamente no corpo)
    "marretao": "M-15,0 L15,0 C20,-10 30,-30 27,-42 C25,-48 -22,-48 -25,-42 C-28,-30 -20,-10 -15,0 Z",
    "picareta": "M-9,-2 C-12,-12 -10,-30 0,-32 C10,-32 12,-14 8,-2 C4,2 -6,2 -9,-2 Z",
    "chave": rect_d(-15, -30, 30, 30, 5),
    "britadeira": ellipse_d(0, -14, 17, 15),
    "pa": "M-12,-2 C-15,-14 -15,-30 -11,-36 L11,-36 C15,-30 15,-14 12,-2 C6,1 -6,1 -12,-2 Z",
}
_cl = [0]


def vest(cid, body):
    """Desenha `body` recortado no contorno do tronco do robô."""
    _cl[0] += 1
    k = f"sk{_cl[0]}"
    return f'<defs><clipPath id="{k}"><path d="{TORSO[cid]}"/></clipPath></defs><g clip-path="url(#{k})">{body}</g>'


def stripes(y, h, col=REFL, x0=-40, x1=40):
    return f'<rect x="{x0}" y="{y}" width="{x1 - x0}" height="{h}" fill="{col}"/>'


# 1 MARRETÃO — MESTRE DE OBRAS: uniforme laranja refletivo, capacete GRANDE na cor do jogador com lanterna, marreta zebrada
def mar_t(c):
    body = f'<rect x="-40" y="-60" width="80" height="70" fill="{ORANGE}"/>' + stripes(-34, 5) + stripes(-16, 5)
    body += f'<rect x="-3" y="-50" width="6" height="52" fill="{ORANGE_D}"/>'
    body += f'<rect x="7" y="-30" width="10" height="9" rx="1.5" fill="{ORANGE_D}"/><rect x="9" y="-33" width="2" height="6" fill="{INK}"/>'
    return vest("marretao", body)


def mar_h(c):
    out = S("M-15,1 C-16,-18 -7,-27 1,-27 C12,-27 17,-18 16,1 Z", c, (-17, -29, 18, 2), k=0.6, dark=shade(c, -0.3))
    out += S("M-19,-1 L22,-1 L21,3 L-18,3 Z", shade(c, -0.35), (-20, -2, 23, 4), k=0.4)
    out += f'<path d="M1,-27 V-2" stroke="{shade(c, -0.25)}" stroke-width="3"/>'
    out += f'<rect x="-13" y="-10" width="27" height="3" fill="{REFL}"/>'
    out += f'<rect x="11" y="-19" width="7" height="7" rx="2" fill="{INK}"/><circle cx="16" cy="-15.5" r="2.6" fill="#fff1b8"/>'
    return out


def mar_tool():
    out = S(rect_d(-16, -2.6, 52, 5.2, 2.6), "#2a2a2a", (-17, -3, 37, 3), k=0.5)
    for x in range(-12, 32, 7):
        out += f'<rect x="{x}" y="-2.6" width="3.5" height="5.2" fill="{YEL}"/>'
    out += S(rect_d(33, -13, 18, 26, 3), YEL, (32, -14, 52, 14), k=0.6, dark=YEL_D)
    for i in range(4):
        out += f'<path d="M{33 + i * 5},13 l5,-26 l2.5,0 l-5,26 Z" fill="{INK}"/>'
    return out


# 2 PICARETA — TOPÓGRAFO: colete limão inteiro com faixas, capacete na cor do jogador, luneta de teodolito no olho,
# picareta listrada vermelho/branco como baliza de topografia
def pic_t(c):
    body = f'<rect x="-20" y="-40" width="40" height="50" fill="#d7e84a"/>' + stripes(-24, 3.5) + stripes(-12, 3.5)
    body += f'<rect x="2" y="-20" width="7" height="7" fill="#b8c83a"/><rect x="4" y="-25" width="2" height="9" fill="{ORANGE}"/>'
    return vest("picareta", body)


def pic_h(c):
    out = S("M-10,-21 C-9,-35 9,-37 14,-27 L16,-21 Z", c, (-11, -38, 17, -20), k=0.5, dark=shade(c, -0.3))
    out += f'<rect x="-12" y="-22" width="30" height="3" rx="1.5" fill="{shade(c, -0.35)}"/>'
    out += S(rect_d(9, -24, 14, 9, 2), INK, (8, -25, 24, -14), k=0.3)
    out += f'<circle cx="23" cy="-19.5" r="3.4" fill="{YEL}"/><circle cx="23" cy="-19.5" r="2" fill="#cdeff7"/>'
    return out


def pic_tool():
    out = S(rect_d(-16, -1.8, 50, 3.6, 1.8), ORANGE, (-17, -3, 35, 3), k=0.5, dark=ORANGE_D)
    head = "M33,-3 C40,-6 48,-13 52,-22 C50,-12 44,-4 37,1 L37,4 C44,8 50,16 52,26 C46,17 40,10 33,6 Z"
    out += f'<path d="{head}" fill="none" stroke="{INK}" stroke-width="3" stroke-linejoin="round"/>'
    out += S(head, "#d14d35", (32, -23, 53, 27), k=0.6, dark="#9a2f20")
    out += f'<path d="M41,-6 L46,-12 M47,-14 L50,-19 M41,10 L46,15 M47,18 L50,22" stroke="{WHITE}" stroke-width="3.2" stroke-linecap="round"/>'
    return out


# 3 CHAVE — SOLDADOR: avental de couro inteiro com tachas, máscara de solda GRANDE na cor do jogador (levantada),
# chave de cobre
def cha_t(c):
    body = f'<rect x="-20" y="-36" width="40" height="40" fill="{LEATHER}"/>'
    body += f'<path d="M-15,-22 H15 M-15,-8 H15" stroke="{LEATHER_D}" stroke-width="2"/>'
    for x in (-11, -4, 3, 10):
        body += f'<circle cx="{x}" cy="-22" r="1.3" fill="{STEEL_L}"/>'
    body += f'<circle cx="-6" cy="-14" r="1.4" fill="#ffd36b"/><circle cx="6" cy="-4" r="1.1" fill="#ffd36b"/><circle cx="9" cy="-13" r="0.9" fill="#ff8a3a"/>'
    return vest("chave", body)


def cha_h(c):
    out = S("M-15,-16 C-15,-33 13,-35 14,-18 L13,-15 L-15,-15 Z", c, (-16, -36, 15, -14), k=0.5, dark=shade(c, -0.3))
    out += S(rect_d(-6, -30, 15, 6, 2), INK, (-7, -31, 10, -23), k=0.3)
    out += f'<rect x="-4" y="-29" width="11" height="4" rx="1" fill="#2f7a3a"/><path d="M-3,-28 l4,0" stroke="#bff0c8" stroke-width="0.8"/>'
    out += f'<circle cx="-14" cy="-17" r="2.4" fill="{STEEL_D}"/>'
    return out


def cha_tool():
    cu, cu_d, cu_l = "#c8743a", "#8a4a22", "#e8a46a"
    out = S(rect_d(-14, -3, 46, 6, 3), cu, (-15, -4, 33, 4), k=0.5, dark=cu_d, light=cu_l)
    out += S("M30,-8 C36,-14 46,-13 49,-6 L42,-4 L42,4 L49,6 C46,13 36,14 30,8 Z", cu, (29, -15, 50, 15), k=0.6, dark=cu_d, light=cu_l)
    out += f'<rect x="-14" y="-4" width="9" height="8" rx="2" fill="{LEATHER_D}"/>'
    return out


# 4 BRITADEIRA — CONCRETEIRO: corpo coberto de cimento, capacete na cor do jogador respingado, máscara de pó grande,
# britadeira suja de concreto
def bri_t(c):
    body = f'<rect x="-20" y="-32" width="40" height="36" fill="{CEMENT}"/>'
    body += f'<path d="M-20,-24 C-10,-28 -2,-20 6,-26 C12,-30 18,-24 20,-26 V-32 H-20 Z" fill="{shade(c, -0.1)}"/>'
    body += splats([(-8, -12, 1.8), (8, -6, 1.6), (-12, -2, 1.2)], CEMENT_D, 1.2)
    body += f'<rect x="-20" y="-9" width="40" height="3" fill="{REFL}"/>'
    return vest("britadeira", body)


def bri_h(c):
    out = S("M-15,-14 C-15,-33 19,-33 19,-14 Z", c, (-16, -34, 20, -13), k=0.5, dark=shade(c, -0.3))
    out += f'<rect x="-18" y="-16" width="40" height="3.4" rx="1.7" fill="{shade(c, -0.35)}"/>'
    out += splats([(-6, -26, 1.4), (9, -28, 1.1), (14, -20, 0.9)], CEMENT, 1.2, CEMENT_D)
    out += S("M4,-6 C4,1 19,1 19,-6 L16,-8 L7,-8 Z", WHITE, (3, -9, 20, 2), k=0.3, dark=WHITE_D)
    out += f'<circle cx="11.5" cy="-3" r="1.8" fill="{WHITE_D}"/>'
    return out


def bri_tool():
    out = E.tool_brit()
    out += splats([(10, -2, 1.6), (20, 3, 1.3), (30, -1, 1.0)], CEMENT, 1.1, CEMENT_D)
    return out


# 5 PÁ — OPERADOR DE ESCAVADEIRA: tronco pintado de máquina (amarelo com zebra e número), cabine na cor do jogador com
# santo-antônio e giroflex grande, pá vira caçamba com dentes
def pa_t(c):
    body = f'<rect x="-20" y="-40" width="40" height="44" fill="{YEL}"/>' + zebra(-20, -10.5, 20, -10.5, 6, 6)
    body += f'<rect x="-9" y="-31" width="13" height="11" rx="2" fill="{INK}"/>'
    body += f'<text x="-2.5" y="-22.5" font-family="Fredoka, Arial" font-weight="700" font-size="9" fill="{YEL}" text-anchor="middle">01</text>'
    return vest("pa", body)


def pa_h(c):
    out = f'<path d="M-12,-1 V-25 H14 V-1" stroke="{INK}" stroke-width="2.6" fill="none"/>'
    out += f'<path d="M-12,-25 L14,-25" stroke="{STEEL_D}" stroke-width="1.4"/>'
    out += S(rect_d(-4, -35, 12, 9, 4), "#ffb03a", (-5, -36, 9, -25), k=0.4, dark=ORANGE_D)
    out += f'<path d="M2,-38 v-3 M-6,-35 l-3,-2 M10,-35 l3,-2" stroke="#ffd36b" stroke-width="1.4"/>'
    return out


def pa_tool():
    out = f'<path d="M-16,-6 C-23,-6 -23,6 -16,6" stroke="{INK}" stroke-width="2.6" fill="none"/><path d="M-21,-5 L-21,5" stroke="{INK}" stroke-width="2.6"/>'
    out += S(rect_d(-17, -2.4, 49, 4.8, 2), YEL, (-18, -3, 33, 3), k=0.5, dark=YEL_D)
    out += S("M33,-12 L52,-12 C58,-8 58,8 52,12 L33,12 Z", YEL, (32, -13, 59, 13), k=0.6, dark=YEL_D)
    for y in (-9, -3, 3, 9):
        out += f'<path d="M54,{y - 2.4} L59,{y} L54,{y + 2.4} Z" fill="{STEEL_L}"/>'
    out += f'<rect x="33" y="-12" width="4" height="24" fill="{INK}"/>'
    return out


SKINS = {
    "marretao": [("MESTRE DE OBRAS", "uniforme laranja refletivo, capacete grande com lanterna, marreta zebrada", mar_t, mar_h, mar_tool)],
    "picareta": [("TOPÓGRAFO", "colete limão, luneta de teodolito no olho, picareta-baliza", pic_t, pic_h, pic_tool)],
    "chave": [("SOLDADOR", "avental de couro, máscara de solda grande, chave de cobre", cha_t, cha_h, cha_tool)],
    "britadeira": [("CONCRETEIRO", "coberto de cimento, máscara de pó, britadeira suja", bri_t, bri_h, bri_tool)],
    "pa": [("OPERADOR DE ESCAVADEIRA", "corpo de máquina nº 01, santo-antônio e giroflex, pá-caçamba", pa_t, pa_h, pa_tool)],
}

_ORIG = {cid: (E.CHARS[cid]["torso"], E.CHARS[cid]["head"], E.CHARS[cid]["tool"]) for cid in E.CHARS}


def vestir(cid, k):
    """Aplica a skin k (-1 = padrão) por cima do desenho original do robô."""
    t0, h0, tl0 = _ORIG[cid]
    if k < 0:
        E.CHARS[cid]["torso"], E.CHARS[cid]["head"], E.CHARS[cid]["tool"] = t0, h0, tl0
        return
    _, _, ft, fh, ftl = SKINS[cid][k]
    E.CHARS[cid]["tool"] = ftl
    E.CHARS[cid]["torso"] = lambda c, e, t0=t0, ft=ft: t0(c, e) + ft(c)
    E.CHARS[cid]["head"] = lambda c, e, L="all", h0=h0, fh=fh: h0(c, e, L) + (fh(c) if L in ("all", "base") else "")


def prancha():
    W, row = 1920, 470
    H = 170 + row * len(E.CHARS) + 30
    L = E.label
    b = [f'<rect width="{W}" height="{H}" fill="#cdeef0"/>',
         L(W / 2, 62, "SKINS DO CANTEIRO DE OBRAS (Derruba · mapa 1) — PROPOSTA v2 (fantasia completa)", 40),
         L(W / 2, 104, "tronco veste o uniforme; a cor do jogador vai para o capacete, braços e pernas; mesma hitbox, sem efeito de jogo", 22, "#2a4a58", weight=500)]
    cols = [(-1, "PADRÃO"), (0, "SKIN DO CANTEIRO (v2)")]
    x0, cw = 260, 820
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
            b.append(f'<g transform="translate({cx + 200},{gy}) scale(2.6)">{E.draw(cid, E.POSES[cid]["parado"], E.COLORS[i])}</g>')
            b.append(f'<g transform="translate({cx + 520},{gy}) scale(2.6)">{E.draw(cid, E.POSES[cid]["pesado_golpe"], E.COLORS[i])}</g>')
            gy2 = y + 418
            b.append(f'<rect x="{cx + 40}" y="{gy2}" width="{cw - 80}" height="10" fill="#d8cdb8"/>')
            for ci in range(4):   # tamanho de jogo, nas 4 cores de jogador
                b.append(f'<g transform="translate({cx + 200 + ci * 130},{gy2}) scale(1.2)">{E.draw(cid, E.POSES[cid]["parado"], E.COLORS[ci])}</g>')
            if k >= 0:
                nome, desc = SKINS[cid][k][0], SKINS[cid][k][1]
                b.append(L(cx + cw / 2, y + 44, nome, 24, ORANGE_D))
                b.append(L(cx + cw / 2, y + 70, desc, 17, "#2a4a58", weight=500))
        vestir(cid, -1)
    return doc(W, H, f'<g filter="url(#rough)">{"".join(b)}</g>', rough(seed=11, scale=0.8, freq=0.08))


def export_game():
    """Texturas de jogo das skins (mesma geometria do robô): corpo_<robô>_<k#>_p<cor>.png e ferramenta_<robô>_<k#>.png.
    O desenho do robô no jogo (robot_visual.gd) troca só estas texturas quando o robô veste a skin."""
    out_dir = os.path.join(E.ROOT, "art/out/game/robo")
    src = os.path.join(E.ROOT, "art/src/robos/svg/skins")
    os.makedirs(src, exist_ok=True)
    ids = {"marretao": "k1", "picareta": "k2", "chave": "k3", "britadeira": "k4", "pa": "k5"}
    for mi, cid in enumerate(E.CHARS):
        vestir(cid, 0)
        ch = E.CHARS[cid]
        seed = 40 + mi * 3
        k = ids[cid]
        for ci in range(4):
            col = E.COLORS[ci]
            body = f'<g transform="{E._xf(cid)}">{ch["torso"](col, "")}</g><g transform="{E._head_xf(cid)}">{ch["head"](col, "", "base")}</g>'
            queue(E._gwrap(body, seed), f"{src}/corpo_{cid}_{k}_p{ci + 1}.svg", f"{out_dir}/corpo_{cid}_{k}_p{ci + 1}.png", 128, 128, E.K4)
        tbody, tsize, _, _, _ = E._tool_export(cid)
        queue(E._gwrap(tbody, seed + 7, tsize[0], tsize[1]), f"{src}/ferramenta_{cid}_{k}.svg", f"{out_dir}/ferramenta_{cid}_{k}.png", tsize[0], tsize[1], E.K4)
        vestir(cid, -1)


def main():
    if "--jogo" in sys.argv:
        export_game()
        print("skins (jogo):", render_all())
        return
    src = os.path.join(E.ROOT, "art/src/robos/svg")
    os.makedirs(src, exist_ok=True)
    out = os.path.join(E.ROOT, "art/out/prancha_skins_canteiro.png")
    queue(prancha(), f"{src}/prancha_skins_canteiro.svg", out, 1920, 170 + 470 * len(E.CHARS) + 30, 1)
    print("skins:", render_all(), out)


if __name__ == "__main__":
    main()
