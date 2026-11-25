"""Camadas de JOGO da Fase 1 (Canteiro em 2 etapas) para modes/cena.gd — saem da prancha aprovada (fase1_prancha.py):
o que é PARADO vira camada (PNG do tamanho da etapa, 2560x1408 / 2560x1152); o que MEXE vira peça solta (sprite) que o
jogo anima. A geometria da Fundação segue os tiles do levels/canteiro_obras.lvl (linhas 26–43).
Rodar: python3 art/src/cenarios/fase1_jogo.py → art/out/game/fase1/*.png (copiar para game/assets/fase1/)
"""
import os
import random
import sys

HERE = os.path.dirname(__file__)
sys.path.insert(0, HERE)
import fase1_prancha as fp  # noqa: E402
from fase1_prancha import INK, YEL, R, E, S, cloud, escada, lattice, npc, sign  # noqa: E402
import canteiro_derruba as cd  # noqa: E402
from papel import rough  # noqa: E402
from svg import doc, queue, render_all  # noqa: E402

ROOT = fp.ROOT
OUT = os.path.join(ROOT, "art/out/game/fase1")
SRC = os.path.join(ROOT, "art/src/cenarios/svg/fase1_jogo")
T = 64
W = 2560
H1 = 22 * T
H2 = 18 * T


def wrap(w, h, body, seed):
    return doc(w, h, f'<g filter="url(#rough)">{body}</g>', rough(seed=seed, scale=0.8, freq=0.05))


# ---------------------------------------------------------------- etapa 1
def e1_ceu():
    return fp.e1_sky(clouds=False, birds=False)


def e1_cidade():
    return fp.e1_far()


def e1_predio():
    return fp.e1_building(live=False)


def e1_grua():
    return fp.e1_grua(hook=False)


def e1_longe():
    """Céu + cidade numa camada só (menos camadas grandes = menos trabalho da placa de vídeo)."""
    return e1_ceu() + e1_cidade()


def e1_perto():
    """Prédio + grua numa camada só."""
    return e1_predio() + e1_grua()


def e1_frente():
    b = [f'<g transform="translate(-20,90) rotate(-12)" opacity="0.85"><rect x="0" y="0" width="560" height="22" fill="#3a3f4a"/>'
         f'<rect x="0" y="22" width="560" height="26" fill="#4a5060"/><rect x="0" y="48" width="560" height="22" fill="#3a3f4a"/>']
    for k in range(7):
        b.append(f'<circle cx="{40 + k * 76}" cy="35" r="6" fill="#6b7380"/>')
    b.append('</g>')
    return "".join(b)


# ---------------------------------------------------------------- etapa 2 (coordenadas da etapa: linha 26 do mapa = y 0)
FL = 15 * T          # topo do piso
HOLE = (10 * T, 30 * T)


def e2_fundo():
    b = ['<defs><linearGradient id="g2" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#2c3644"/><stop offset="1" stop-color="#1e2530"/></linearGradient></defs>',
         f'<rect width="{W}" height="{H2}" fill="url(#g2)"/>']
    # (o céu/poço do buraco é desenhado pelo jogo em coordenadas do mundo — aqui, em paralaxe, ele descolava do buraco)
    for (x, w) in ((300, 260), (2000, 260)):   # galerias
        b.append(f'<path d="M{x},{FL - 30} V{460} q{w / 2},-150 {w},0 V{FL - 30} Z" fill="#161b23"/>')
    for y, col in ((250, "#7a4a2e"), (310, "#5d6b7d")):   # canos
        b.append(f'<path d="M0,{y} H{W}" stroke="{col}" stroke-width="30"/>')
        for x in range(120, W, 340):
            b.append(f'<rect x="{x}" y="{y - 22}" width="20" height="44" fill="#3a3a46"/>')
    b.append(hung_sign(560, 325, "ALAGA!", "#4f86a8", "#ffffff", 120, 40))   # placas penduradas no cano (não soltas no ar)
    b.append(hung_sign(1960, 325, "", tri=True, w=70, h=60))
    return "".join(b)


def hung_sign(x, pipe_y, txt, bg="#f2c84b", fg=INK, w=120, h=44, tri=False):
    """Placa pendurada por duas correntes num cano (pipe_y = borda de baixo do cano)."""
    y = pipe_y + 26
    b = []
    for cx in ((x + 14, x + w - 14) if not tri else (x + w / 2 - 6, x + w / 2 + 6)):
        b.append(f'<path d="M{cx},{pipe_y - 8} V{y + (4 if not tri else 8)}" stroke="#3a3a46" stroke-width="3" stroke-dasharray="5 3"/>')
        b.append(f'<circle cx="{cx}" cy="{pipe_y - 10}" r="5" fill="none" stroke="#3a3a46" stroke-width="3"/>')
    s = sign(x, y, txt, bg, fg, w, h, tri)
    return "".join(b) + s.split("/>", 1)[1]   # sem o poste da placa


def e2_palco():
    """Teto quebrado, paredes, piso, blocos, plataformas com estacas e baldrames — em cima dos tiles do mapa."""
    rnd = random.Random(8)
    b = []
    # teto (2 linhas) com bordas quebradas e ferros no buraco
    b.append(R(0, 0, HOLE[0], 2 * T, "#4a5566", 0, 2.6, dark="#323a46"))
    b.append(R(HOLE[1], 0, W - HOLE[1], 2 * T, "#4a5566", 0, 2.6, dark="#323a46"))
    for x0, sgn in ((HOLE[0], 1), (HOLE[1], -1)):
        b.append(f'<path d="M{x0},0 L{x0 + sgn * 26},50 L{x0 - sgn * 8},86 L{x0 + sgn * 30},{2 * T} L{x0 - sgn * 4},{2 * T} Z" fill="#4a5566"/>')
        for k in range(4):
            b.append(f'<path d="M{x0},{20 + k * 26} q{sgn * 30},10 {sgn * 50},-5" stroke="#b0562e" stroke-width="4" fill="none"/>')
    # o VAZIO embaixo do piso (cair = KO): escuro que some para baixo
    b.append('<defs><linearGradient id="vz" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#0d1015" stop-opacity="0.2"/>'
             '<stop offset="1" stop-color="#05070a"/></linearGradient></defs>')
    b.append(f'<rect x="0" y="{FL + T}" width="{W}" height="{H2 - FL - T}" fill="url(#vz)"/>')
    # 3 lajes de fundação (piso, 1 tile) sobre pilares que somem no escuro; vãos abertos entre elas
    for (c0, c1) in ((3, 13), (16, 24), (27, 37)):
        x0, x1 = c0 * T, c1 * T
        for px in range(x0 + 60, x1 - 40, 220):
            b.append(R(px, FL + T - 4, 46, H2 - FL, "#4a5566", 3, 2, dark="#323a46"))
        b.append(R(x0, FL, x1 - x0, T, "#7d8896", 4, 3, dark="#5d6878"))
        b.append(f'<rect x="{x0}" y="{FL}" width="{x1 - x0}" height="10" fill="#9aa4ae"/>')
        for k in range(int((x1 - x0) // 180)):
            x = x0 + 40 + k * 180
            b.append(f'<rect x="{x + 30}" y="{FL + 28}" width="18" height="12" fill="#a1988a" transform="rotate({k * 20} {x + 30} {FL + 28})"/>')
        for ex, sg in ((x0, -1), (x1, 1)):   # ferros na borda da laje + faixa de perigo
            for k in range(3):
                b.append(f'<path d="M{ex},{FL + 14 + k * 16} l{sg * 9},{2 - k}" stroke="#b0562e" stroke-width="3" stroke-linecap="round"/>')
        b.append(cd.zebra(x0 + 4, FL - 2, 40, 7) + cd.zebra(x1 - 44, FL - 2, 40, 7))
    # registro da bomba (cano saindo do piso, à esquerda do bloco direito)
    b.append(f'<path d="M{32 * T + 16},{FL} V{FL - 150} H{33 * T}" stroke="#7a4a2e" stroke-width="22" fill="none"/>')
    b.append(f'<circle cx="{32 * T + 16}" cy="{FL - 150}" r="26" fill="none" stroke="#d94a3a" stroke-width="8"/>'
             f'<path d="M{32 * T - 10},{FL - 150} h52 M{32 * T + 16},{FL - 176} v52" stroke="#d94a3a" stroke-width="6"/>')
    for k in range(8):   # régua do nível da água no bloco esquerdo
        b.append(f'<rect x="{7 * T - 34}" y="{FL - 20 - k * 22}" width="22" height="4" fill="#9fe3f5"/>')
    # blocos de fundação (linhas 13–14)
    for x0 in (3 * T, 33 * T):
        b.append(R(x0, 13 * T, 4 * T, 2 * T, "#6f7b8a", 4, 2.6, dark="#56606d"))
        b.append(f'<path d="M{x0 + 10},{13 * T + 40} H{x0 + 4 * T - 10}" stroke="#56606d" stroke-width="4"/>')
    # baldrames (linha 11) e plataformas com estaca (linhas 9 e 6)
    for (c0, n) in ((4, 4), (32, 4)):
        b.append(R(c0 * T, 11 * T, n * T, 18, "#a8582e", 3, 1.8, dark="#7a3a18"))
        for xx in (c0 * T + 14, (c0 + n) * T - 22):
            b.append(f'<path d="M{xx},{11 * T + 18} V{13 * T}" stroke="#7a3a18" stroke-width="6"/>')
    # (as plataformas com estaca são peças do jogo: quebram — sprites "plataforma" e "estaca")
    return "".join(b)


# ---------------------------------------------------------------- peças soltas (animadas pelo jogo)
SPRITES = {
    "nuvem": (300, 120, lambda: cloud(150, 80, 1.0)),
    "nuvem_p": (200, 90, lambda: cloud(100, 60, 0.62)),
    "balde": (90, 90, lambda: S("M10,24 L80,24 L66,84 L24,84 Z", "#8d98a4", (8, 22, 82, 86), k=1.6)
              + '<path d="M10,24 L45,8 L80,24" stroke="#3a3a46" stroke-width="3" fill="none"/><circle cx="45" cy="8" r="6" fill="#f08a3d"/>'),
    "carrinho_grua": (70, 30, lambda: R(4, 4, 62, 22, "#c49a2a", 4, 1.6)),
    "npc_tabua": (140, 110, lambda: npc(60, 100, "#8fb2a8", "tabua", 1.4)),
    "npc_carrinho": (160, 110, lambda: npc(50, 100, "#9fb9c0", "carrinho", 1.4)),
    "npc": (80, 110, lambda: npc(40, 100, "#b4a9c4", "", 1.4)),
    "npc_lanterna": (200, 110, lambda: npc(40, 100, "#55606e", "", 1.4, lamp=True)),
    # mecanismos (posicionados e animados por modes/mecanismos.gd); chão/base na borda de baixo
    "plataforma": (320, 40, lambda: R(4, 4, 312, 22, "#8d98a4", 3, 2, dark="#6b7783") + cd.zebra(4, 26, 312, 8)),
    "estaca": (44, 560, lambda: R(0, 0, 44, 560, "#a9b2bc", 3, 2.4, dark="#8691a0") + "".join(
        f'<path d="M2,{y} h40" stroke="#8691a0" stroke-width="3"/>' for y in range(50, 560, 90))),
    "grelha": (256, 40, lambda: R(0, 0, 256, 40, "#3a3f4a", 3, 1.6) + "".join(
        f'<rect x="{8 + k * 31}" y="4" width="14" height="32" rx="3" fill="#8d98a4"/>' for k in range(8))),
    "m_betoneira": (330, 170, lambda: f'<g transform="translate(70,160)">' + fp.betoneira(0, 0).split('<ellipse')[0] + '</g>'),
    "m_esteira": (300, 70, lambda: R(4, 38, 240, 26, "#3e4752", 12, 1.8, dark="#252b33") + "".join(
        f'<rect x="{10 + k * 28}" y="40" width="16" height="4" fill="#71829a"/>' for k in range(8)) + "".join(
        f'<circle cx="{x}" cy="51" r="11" fill="#71829a"/><circle cx="{x}" cy="51" r="4" fill="#2a1a2e"/>' for x in (18, 230))
        + R(254, 4, 30, 60, "#6b7783", 4, 1.4) + '<circle cx="269" cy="18" r="9" fill="#d94a3a"/>'),
    "m_tubo": (84, 84, lambda: E(42, 42, 38, 38, "#c4beb2", 2, dark="#9e9789") + '<circle cx="42" cy="42" r="22" fill="#7d776c"/><circle cx="42" cy="42" r="17" fill="#5a554d"/>'
               + '<path d="M42,6 V20" stroke="#9e9789" stroke-width="4"/>'),
    "m_serra": (76, 76, lambda: E(38, 38, 30, 30, "#c9d1d8", 1.6, dark="#8d98a4") + "".join(
        f'<path d="M{38 + 26 * __import__("math").cos(__import__("math").radians(a)):.1f},{38 + 26 * __import__("math").sin(__import__("math").radians(a)):.1f} '
        f'L{38 + 36 * __import__("math").cos(__import__("math").radians(a) + 0.15):.1f},{38 + 36 * __import__("math").sin(__import__("math").radians(a) + 0.15):.1f}" stroke="#8d98a4" stroke-width="5"/>'
        for a in range(0, 360, 30)) + '<circle cx="38" cy="38" r="6" fill="#2a1a2e"/>'),
    "m_bancada": (110, 40, lambda: R(8, 6, 94, 30, "#4a5566", 4, 1.6)),
    # torre do bate-estaca: esteira + cabine embaixo (apoiadas no chão), mastro de treliça até a roldana lá em cima.
    # O mastro fica no x 120 do sprite (= x do martelo); a base do sprite é o piso.
    "m_bate_torre": (260, 860, lambda: lattice(120, 820, 120, 60, 40, "#e7b941", 5)
                     + '<path d="M120,330 L222,760" stroke="#c49a2a" stroke-width="7" stroke-linecap="round"/>'
                     + '<path d="M120,470 L30,770" stroke="#c49a2a" stroke-width="6" stroke-linecap="round"/>'
                     + R(92, 36, 56, 30, "#c49a2a", 4, 1.6, dark="#8a6a1a")
                     + '<circle cx="120" cy="40" r="22" fill="#3a3a46"/><circle cx="120" cy="40" r="9" fill="#9aa4ae"/>'
                     + R(40, 700, 190, 104, "#f2c84b", 8, 2.2, dark="#c49a2a")
                     + R(150, 716, 64, 46, "#2b3d4f", 4, 1.2) + '<path d="M158,724 l18,-6" stroke="#bfe8f0" stroke-width="4" opacity="0.6"/>'
                     + cd.zebra(44, 772, 100, 12)
                     + '<circle cx="80" cy="740" r="14" fill="#3a3a46"/><circle cx="80" cy="740" r="6" fill="#9aa4ae"/>'
                     + R(14, 800, 236, 52, "#3a3a46", 22, 1.6, dark="#252b33")
                     + "".join(f'<circle cx="{x}" cy="826" r="15" fill="#71829a"/><circle cx="{x}" cy="826" r="5" fill="#2a1a2e"/>' for x in (44, 96, 148, 200, 224))),
    "m_martelo": (140, 110, lambda: R(10, 10, 120, 80, "#6b7783", 8, 2, dark="#4d5a6e") + cd.zebra(10, 74, 120, 14)),
    "m_vagonete": (170, 110, lambda: S("M10,20 L160,20 L140,82 L30,82 Z", "#a8582e", (8, 18, 162, 84), k=2, dark="#7a3a18")
                   + "".join(f'<rect x="{x}" y="{4 + (i % 2) * 6}" width="30" height="22" fill="#a1988a" transform="rotate(14 {x} 10)"/>' for i, x in enumerate((40, 80, 112)))
                   + "".join(f'<circle cx="{x}" cy="92" r="14" fill="#2a1a2e"/><circle cx="{x}" cy="92" r="5" fill="#9aa4ae"/>' for x in (50, 120))
                   + '<circle cx="158" cy="36" r="8" fill="#fff4c8"/>'),
    "m_gerador": (170, 130, lambda: R(10, 10, 150, 116, "#3c9a46", 8, 2.4, dark="#25682d") + "".join(
        f'<rect x="{24 + k * 26}" y="30" width="14" height="56" rx="3" fill="#25682d"/>' for k in range(5))
                  + '<path d="M122,52 l14,-14 l-4,12 l12,-2 l-16,18 l4,-12 Z" fill="#f2c84b"/>'),
}


def main():
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(SRC, exist_ok=True)
    layers = {"e1_longe": (W, H1, e1_longe), "e1_perto": (W, H1, e1_perto), "e1_frente": (640, 200, e1_frente),
              "e2_fundo": (W, H2, e2_fundo), "e2_palco": (W, H2, e2_palco)}
    for i, (name, (w, h, fn)) in enumerate(layers.items()):
        queue(wrap(w, h, fn(), 40 + i), f"{SRC}/{name}.svg", f"{OUT}/{name}.png", w, h, 1)
    for i, (name, (w, h, fn)) in enumerate(SPRITES.items()):
        queue(wrap(w, h, fn(), 60 + i), f"{SRC}/{name}.svg", f"{OUT}/{name}.png", w, h, 2)
    print("fase 1 (jogo):", render_all())


if __name__ == "__main__":
    main()
