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


def e1_frente():
    b = [f'<g transform="translate(-60,40) rotate(-12)" opacity="0.85"><rect x="0" y="0" width="560" height="22" fill="#3a3f4a"/>'
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
    b.append(f'<rect x="{HOLE[0]}" y="0" width="{HOLE[1] - HOLE[0]}" height="140" fill="#bfe8f0"/>')
    b.append(cloud(1150, 60, 0.6))
    b.append(lattice(HOLE[0] - 40, 34, HOLE[1] + 40, 34, 18, "#e7b941", 4))
    for (x, w) in ((300, 260), (2000, 260)):   # galerias
        b.append(f'<path d="M{x},{FL - 30} V{460} q{w / 2},-150 {w},0 V{FL - 30} Z" fill="#161b23"/>')
    for y, col in ((250, "#7a4a2e"), (310, "#5d6b7d")):   # canos
        b.append(f'<path d="M0,{y} H{W}" stroke="{col}" stroke-width="30"/>')
        for x in range(120, W, 340):
            b.append(f'<rect x="{x}" y="{y - 22}" width="20" height="44" fill="#3a3a46"/>')
    b.append(sign(620, 300, "ALAGA!", "#4f86a8", "#ffffff", 120, 40))
    b.append(sign(1990, 330, "", tri=True, w=70, h=60))
    return "".join(b)


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
    # paredes de contenção (3 tiles) com umidade, placa e musgo
    for (x0, w) in ((0, 3 * T), (W - 3 * T, 3 * T)):
        b.append(R(x0, 2 * T, w, H2 - 2 * T, "#5d6b7d", 0, 3, dark="#454f5c"))
        for yy in range(2 * T + 60, H2, 120):
            b.append(f'<path d="M{x0},{yy} H{x0 + w}" stroke="#454f5c" stroke-width="4"/>')
        for k in range(4):
            sx = x0 + 30 + k * 40
            sy = rnd.uniform(160, 520)
            b.append(f'<path d="M{sx},{sy:.0f} q8,{rnd.uniform(120, 240):.0f} -2,{rnd.uniform(240, 380):.0f} h14 q-6,-200 2,-{rnd.uniform(280, 380):.0f} Z" fill="#3f4855" opacity="0.55"/>')
        b.append(R(x0 + 30, 420, w - 60, 80, "#6b7783", 4, 1.6) + "".join(f'<circle cx="{x0 + 44 + j * 36}" cy="434" r="4" fill="#9aa4ae"/>' for j in range(4)))
        b.append(f'<path d="M{x0 + 40},{FL - 50} q30,-30 60,0 q20,20 50,0" stroke="#4f7a52" stroke-width="10" fill="none" opacity="0.8"/>')
        for k in range(9):   # régua do nível da água
            b.append(f'<rect x="{x0 + (w - 40 if x0 == 0 else 14)}" y="{FL - 30 - k * 24}" width="26" height="4" fill="#9fe3f5"/>')
    b.append(escada(3 * T + 6, 2 * T, FL))
    b.append(escada(W - 3 * T - 32, 2 * T, FL))
    # piso
    b.append(R(3 * T, FL, W - 6 * T, H2 - FL, "#7d8896", 0, 3, dark="#5d6878"))
    b.append(f'<rect x="{3 * T}" y="{FL}" width="{W - 6 * T}" height="10" fill="#9aa4ae"/>')
    for k in range(int((W - 6 * T) // 180)):
        x = 3 * T + 40 + k * 180
        b.append(f'<path d="M{x},{FL + 10} V{H2}" stroke="#5d6878" stroke-width="3"/>')
        b.append(f'<rect x="{x + 30}" y="{FL + 90 + (k % 2) * 30}" width="18" height="12" fill="#a1988a" transform="rotate({k * 20} {x + 30} {FL + 90})"/>')
    # blocos de fundação (linhas 13–14)
    for x0 in (3 * T, 32 * T):
        b.append(R(x0, 13 * T, 5 * T, 2 * T, "#6f7b8a", 4, 2.6, dark="#56606d"))
        b.append(f'<path d="M{x0 + 10},{13 * T + 40} H{x0 + 5 * T - 10}" stroke="#56606d" stroke-width="4"/>')
    # baldrames (linha 11) e plataformas com estaca (linhas 9 e 6)
    for (c0, n) in ((4, 4), (32, 4)):
        b.append(R(c0 * T, 11 * T, n * T, 18, "#a8582e", 3, 1.8, dark="#7a3a18"))
        for xx in (c0 * T + 14, (c0 + n) * T - 22):
            b.append(f'<path d="M{xx},{11 * T + 18} V{13 * T}" stroke="#7a3a18" stroke-width="6"/>')
    for (c0, n, row) in ((8, 5, 9), (27, 5, 9), (18, 4, 6)):
        x, y, w = c0 * T, row * T, n * T
        b.append(R(x, y, w, 22, "#8d98a4", 3, 2, dark="#6b7783"))
        b.append(cd.zebra(x, y + 22, w, 8))
        b.append(R(x + w / 2 - 22, y + 30, 44, FL - y - 30, "#a9b2bc", 3, 2.4, dark="#8691a0"))
        for yy in range(y + 80, FL, 90):
            b.append(f'<path d="M{x + w / 2 - 20},{yy} h40" stroke="#8691a0" stroke-width="3"/>')
    # registro da bomba (parede direita)
    b.append(f'<path d="M{W - 3 * T},{FL - 260} H{W - 3 * T - 60} V{FL - 20}" stroke="#7a4a2e" stroke-width="22" fill="none"/>')
    b.append(f'<circle cx="{W - 3 * T - 60}" cy="{FL - 190}" r="26" fill="none" stroke="#d94a3a" stroke-width="8"/>'
             f'<path d="M{W - 3 * T - 86},{FL - 190} h52 M{W - 3 * T - 60},{FL - 216} v52" stroke="#d94a3a" stroke-width="6"/>')
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
}


def main():
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(SRC, exist_ok=True)
    layers = {"e1_ceu": (W, H1, e1_ceu), "e1_cidade": (W, H1, e1_cidade), "e1_predio": (W, H1, e1_predio), "e1_grua": (W, H1, e1_grua),
              "e1_frente": (W, H1, e1_frente), "e2_fundo": (W, H2, e2_fundo), "e2_palco": (W, H2, e2_palco)}
    for i, (name, (w, h, fn)) in enumerate(layers.items()):
        queue(wrap(w, h, fn(), 40 + i), f"{SRC}/{name}.svg", f"{OUT}/{name}.png", w, h, 1)
    for i, (name, (w, h, fn)) in enumerate(SPRITES.items()):
        queue(wrap(w, h, fn(), 60 + i), f"{SRC}/{name}.svg", f"{OUT}/{name}.png", w, h, 2)
    print("fase 1 (jogo):", render_all())


if __name__ == "__main__":
    main()
