"""Esquema da FASE 1 do Derruba (Canteiro): Etapa 1 Térreo, a virada "a obra cede" e a Etapa 2 Fundação, com os códigos
do catálogo (docs/fases/derruba/f1_canteiro.md). Diagrama para aprovar a composição — não é arte de jogo.
Rodar: python3 art/src/cenarios/fase1_catalogo.py → art/out/fase1_canteiro_catalogo.png
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from svg import doc, save  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.."))
INK = "#2a1a2e"
W, H = 1920, 2060
COL = {"E": "#3c9a46", "D": "#f08a3d", "M": "#8a63d2", "V": "#d94a3a", "A": "#3fc1c9"}


def T(x, y, t, s=24, c=INK, a="middle", w=700):
    return f'<text x="{x}" y="{y}" font-family="Fredoka, Arial" font-weight="{w}" font-size="{s}" fill="{c}" text-anchor="{a}">{t}</text>'


def tag(x, y, code):
    c = COL[code[0]]
    w = 18 + 13 * len(code)
    return (f'<rect x="{x - w / 2}" y="{y - 16}" width="{w}" height="30" rx="15" fill="{c}" stroke="#ffffff" stroke-width="3"/>'
            + T(x, y + 7, code, 18, "#ffffff"))


def rect(x, y, w, h, fill, sw=2, rx=0, op=1.0):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" stroke="{INK}" stroke-width="{sw}" opacity="{op}"/>'


def etapa1(ox, oy, w, h):
    b = [f'<rect x="{ox}" y="{oy}" width="{w}" height="{h}" rx="18" fill="#bfe9ef"/>']
    # A: fundo vivo
    b.append(f'<rect x="{ox + 980}" y="{oy + 70}" width="320" height="{h - 260}" fill="#a8d6df"/>')
    for k in range(5):
        b.append(f'<path d="M{ox + 980},{oy + 120 + k * 60} H{ox + 1300}" stroke="#8fc2cc" stroke-width="6"/>')
    b.append(f'<path d="M{ox + 1250},{oy + 40} V{oy + 330} M{ox + 1000},{oy + 60} H{ox + 1480}" stroke="#f2c84b" stroke-width="14"/>')
    b.append(f'<rect x="{ox + 1420}" y="{oy + 64}" width="60" height="40" fill="#c49a2a"/>')
    for x in (120, 260, 760):
        b.append(f'<rect x="{ox + x}" y="{oy + h - 330}" width="70" height="200" fill="#a8d6df"/>')
    b.append(f'<rect x="{ox + 1100}" y="{oy + h - 300}" width="24" height="40" rx="8" fill="#7fae7a"/><circle cx="{ox + 1112}" cy="{oy + h - 312}" r="12" fill="#7fae7a"/>')
    b.append(f'<rect x="{ox + 1150}" y="{oy + h - 300}" width="24" height="40" rx="8" fill="#7fae7a"/><circle cx="{ox + 1162}" cy="{oy + h - 312}" r="12" fill="#7fae7a"/>')
    b.append(f'<rect x="{ox + 20}" y="{oy + h - 150}" width="{w - 40}" height="40" fill="#e6d3b0" opacity="0.8"/>')
    # palco
    gy = oy + h - 300
    x0 = ox + 260
    for i in range(6):
        nuc = i in (2, 3)
        b.append(rect(x0 + i * 150, gy, 146, 56, "#c8bba6" if nuc else "#d8ccb6"))
        if not nuc:
            b.append(f'<path d="M{x0 + i * 150 + 40},{gy + 56} L{x0 + i * 150 + 70},{gy + 170} M{x0 + i * 150 + 110},{gy + 56} L{x0 + i * 150 + 80},{gy + 170}" stroke="#a8703a" stroke-width="8"/>')
    for i in (2, 3):
        b.append(rect(x0 + i * 150 + 45, gy + 56, 56, 170, "#b8ab96", 0))
    # andaimes
    for x in (x0 - 220, x0 + 900 + 60):
        b.append(rect(x, gy - 130, 170, 14, "#c98a4b"))
        b.append(f'<path d="M{x + 10},{gy - 116} V{gy + 230} M{x + 160},{gy - 116} V{gy + 230} M{x + 10},{gy - 100} L{x + 160},{gy + 60}" stroke="#6b7783" stroke-width="5"/>')
    # vigas
    b.append(rect(x0 + 300, gy - 240, 300, 14, "#6b7783"))
    b.append(f'<path d="M{x0 + 330},{oy} V{gy - 240} M{x0 + 570},{oy} V{gy - 240}" stroke="#5a4a3a" stroke-width="3"/>')
    for x in (x0 + 90, x0 + 690):
        b.append(rect(x, gy - 110, 130, 12, "#6b7783"))
        b.append(f'<path d="M{x + 20},{oy} V{gy - 110} M{x + 110},{oy} V{gy - 110}" stroke="#5a4a3a" stroke-width="2"/>')
    for x in (x0 + 20, x0 + 760):
        b.append(rect(x, gy - 330, 130, 12, "#6b7783"))
    # E7 passarela + M5 serra
    b.append(rect(x0 - 60, gy - 200, 160, 10, "#d9a46a"))
    b.append(f'<circle cx="{x0 + 30}" cy="{gy - 212}" r="16" fill="#c9d1d8" stroke="{INK}" stroke-width="2"/>')
    # E8 escada
    for x in (x0 + 296, x0 + 590):
        b.append(f'<path d="M{x},{gy} V{gy + 200} M{x + 16},{gy} V{gy + 200}" stroke="{INK}" stroke-width="3"/>')
        for k in range(6):
            b.append(f'<path d="M{x},{gy + 20 + k * 30} h16" stroke="{INK}" stroke-width="3"/>')
    # E6 pilha de tubos
    for (x, y) in ((x0 + 960 + 260, gy + 210), (x0 + 960 + 300, gy + 210), (x0 + 960 + 280, gy + 175)):
        b.append(f'<circle cx="{x}" cy="{y}" r="20" fill="#b8b8b8" stroke="{INK}" stroke-width="2"/><circle cx="{x}" cy="{y}" r="9" fill="#7a7a7a"/>')
    # M1 betoneira
    b.append(f'<ellipse cx="{ox + 130}" cy="{gy + 170}" rx="70" ry="48" fill="#f08a3d" stroke="{INK}" stroke-width="2"/>')
    b.append(rect(ox + 70, gy + 210, 130, 24, "#6b7783"))
    b.append(f'<rect x="{ox + 200}" y="{gy + 232}" width="140" height="8" fill="#9aa4ae" opacity="0.8"/>')
    # M2 elevador
    b.append(f'<rect x="{ox + w - 120}" y="{gy - 240}" width="14" height="480" fill="#6b7783"/>')
    b.append(rect(ox + w - 190, gy - 60, 100, 18, "#f2c84b"))
    # M3 esteira
    b.append(rect(x0 - 230, gy + 230, 230, 22, "#3e4752", 2, 10))
    for k in range(5):
        b.append(f'<path d="M{x0 - 210 + k * 44},{gy + 241} l-12,-7 v14 Z" fill="#f2c84b"/>')
    # chão do térreo (borda) e vão
    b.append(f'<rect x="{ox}" y="{oy + h - 60}" width="{w}" height="60" rx="0" fill="#9e8a6a" opacity="0.5"/>')
    tags = [(x0 + 375, gy + 30, "E1"), (x0 + 75, gy + 30, "E2"), (x0 - 140, gy - 150, "E3"), (x0 + 450, gy - 270, "E4"),
            (x0 + 60, gy + 110, "E5"), (x0 + 1240, gy + 140, "E6"), (x0 + 20, gy - 180, "E7"), (x0 + 300, gy + 120, "E8"),
            (x0 + 450, gy - 300, "E10"),
            (ox + 130, gy + 120, "M1"), (ox + w - 140, gy - 90, "M2"), (x0 - 120, gy + 275, "M3"), (x0 + 1290, gy + 110, "M4"), (x0 + 30, gy - 245, "M5"),
            (ox + 1250, oy + 30, "A"), (ox + 1130, oy + h - 340, "A")]
    for (x, y, c) in tags:
        b.append(tag(x, y, c))
    b.append(T(ox + 30, oy + 46, "ETAPA 1 · TÉRREO DA OBRA · composição PONTE · manhã", 30, INK, "start"))
    return "".join(b)


def etapa2(ox, oy, w, h):
    b = [f'<rect x="{ox}" y="{oy}" width="{w}" height="{h}" rx="18" fill="#3a4554"/>']
    # buraco no teto (C0)
    b.append(f'<path d="M{ox + 520},{oy} L{ox + 600},{oy + 70} L{ox + 1100},{oy + 70} L{ox + 1180},{oy} Z" fill="#bfe9ef"/>')
    b.append(f'<path d="M{ox + 1050},{oy + 6} V{oy + 50} M{ox + 900},{oy + 14} H{ox + 1120}" stroke="#f2c84b" stroke-width="8"/>')
    for k in range(4):
        b.append(f'<path d="M{ox + 620 + k * 120},{oy + 70} L{ox + 560 + k * 150},{oy + h - 120}" stroke="#ffe7a8" stroke-width="40" opacity="0.08"/>')
    # galerias e canos (C1/C2)
    for x in (80, 1450):
        b.append(f'<path d="M{ox + x},{oy + 260} q90,-90 180,0 V{oy + h - 160} H{ox + x} Z" fill="#2c3542"/>')
    b.append(f'<path d="M{ox + 40},{oy + 150} H{ox + w - 40}" stroke="#a8582e" stroke-width="18"/>')
    b.append(f'<circle cx="{ox + 330}" cy="{oy + 330}" r="8" fill="#ffe7a8"/><circle cx="{ox + 1530}" cy="{oy + 360}" r="8" fill="#ffe7a8"/>')
    # paredes de contenção (bacia)
    gy = oy + h - 150
    b.append(rect(ox + 40, oy + 200, 120, h - 230, "#5d6b7d"))
    b.append(rect(ox + w - 160, oy + 200, 120, h - 230, "#5d6b7d"))
    for x in (ox + 170, ox + w - 190):
        b.append(f'<path d="M{x},{oy + 220} V{gy}" stroke="#c9d1d8" stroke-width="3"/><path d="M{x + 16},{oy + 220} V{gy}" stroke="#c9d1d8" stroke-width="3"/>')
    # blocos laterais (degraus)
    b.append(rect(ox + 160, gy - 110, 220, 110, "#6f7b8a"))
    b.append(rect(ox + w - 380, gy - 110, 220, 110, "#6f7b8a"))
    # piso + grelha
    b.append(rect(ox + 160, gy, w - 320, 60, "#7d8896"))
    b.append(rect(ox + 820, gy, 200, 60, "#2a2f38"))
    for k in range(7):
        b.append(f'<path d="M{ox + 832 + k * 28},{gy + 4} V{gy + 56}" stroke="#9aa4ae" stroke-width="5"/>')
    # estacas + plataformas altas
    for (x, pw) in ((520, 220), (1200, 220)):
        b.append(rect(ox + x, gy - 290, pw, 18, "#8d98a4"))
        b.append(rect(ox + x + pw / 2 - 18, gy - 272, 36, 272, "#9aa4ae"))
    b.append(rect(ox + 860, gy - 420, 200, 18, "#8d98a4"))
    b.append(rect(ox + 942, gy - 402, 36, 252, "#9aa4ae"))
    # baldrame
    b.append(rect(ox + 330, gy - 200, 160, 14, "#a8582e"))
    b.append(rect(ox + 1430, gy - 200, 160, 14, "#a8582e"))
    # pedaços da laje inclinados (E16)
    b.append(f'<path d="M{ox + 620},{gy} L{ox + 780},{gy - 70} L{ox + 790},{gy - 50} L{ox + 640},{gy + 8} Z" fill="#d8ccb6" stroke="{INK}" stroke-width="2"/>')
    b.append(f'<path d="M{ox + 1080},{gy - 40} L{ox + 1230},{gy} L{ox + 1220},{gy + 12} L{ox + 1074},{gy - 22} Z" fill="#d8ccb6" stroke="{INK}" stroke-width="2"/>')
    # M7 água
    b.append(f'<rect x="{ox + 160}" y="{gy - 26}" width="{w - 320}" height="26" fill="#4f86a8" opacity="0.55"/>')
    # M6 bate-estaca
    b.append(rect(ox + 1340, oy + 80, 70, 300, "#f2c84b"))
    b.append(rect(ox + 1320, oy + 380, 110, 50, "#6b7783"))
    b.append(f'<rect x="{ox + 1320}" y="{gy - 8}" width="110" height="8" fill="#d94a3a" opacity="0.9"/>')
    # M8 vagonete + trilho
    b.append(f'<path d="M{ox + 160},{gy - 4} H{ox + w - 160}" stroke="{INK}" stroke-width="3" stroke-dasharray="14 8"/>')
    b.append(rect(ox + 380, gy - 60, 90, 50, "#a8582e", 2, 6))
    b.append(f'<circle cx="{ox + 400}" cy="{gy - 8}" r="10" fill="{INK}"/><circle cx="{ox + 450}" cy="{gy - 8}" r="10" fill="{INK}"/>')
    # M9 gerador
    b.append(rect(ox + 200, gy - 190, 110, 80, "#3c9a46"))
    b.append(f'<path d="M{ox + 310},{gy - 150} q60,40 40,130" stroke="{INK}" stroke-width="5" fill="none"/>')
    # lâmpadas C4
    for x in (360, 760, 1160, 1560):
        b.append(f'<path d="M{ox + x},{oy} V{oy + 120}" stroke="{INK}" stroke-width="2"/><circle cx="{ox + x}" cy="{oy + 128}" r="12" fill="#ffe7a8"/>')
    tags = [(ox + 700, gy + 30, "E11"), (ox + 920, gy + 30, "E12"), (ox + 270, gy - 60, "E13"), (ox + 630, gy - 150, "E14"),
            (ox + 410, gy - 230, "E15"), (ox + 720, gy - 70, "E16"), (ox + 100, oy + 400, "E17"), (ox + 960, gy - 450, "E18"),
            (ox + 920, gy + 85, "D8"), (ox + 1310, gy - 100, "D9"), (ox + 360, oy + 160, "D11"),
            (ox + 1375, oy + 240, "M6"), (ox + 1650, gy - 40, "M7"), (ox + 425, gy - 90, "M8"), (ox + 255, gy - 220, "M9"),
            (ox + 850, oy + 40, "A"), (ox + 200, oy + 300, "A")]
    for (x, y, c) in tags:
        b.append(tag(x, y, c))
    b.append(T(ox + 30, oy + h - 20, "ETAPA 2 · FUNDAÇÃO (subsolo) · composição BACIA · escuro + luz do buraco", 30, "#ffffff", "start"))
    return "".join(b)


def virada(ox, oy):
    b = [T(W / 2, oy + 10, "VIRADA — \"A OBRA CEDE\" (storyboard)", 32)]
    frames = [("−3 s", "sirene + rachaduras por toda a laje", "warn"), ("0 s", "o chão inteiro se parte", "break"),
              ("0–2 s", "QUEDA: câmera desce junto, robôs girando", "fall"), ("2 s", "pouso na Fundação + poeira", "land")]
    for i, (tm, txt, kind) in enumerate(frames):
        x = 60 + i * 460
        y = oy + 40
        b.append(f'<rect x="{x}" y="{y}" width="420" height="230" rx="16" fill="#ffffff" stroke="{INK}" stroke-width="3"/>')
        if kind == "warn":
            b.append(rect(x + 40, y + 110, 340, 36, "#d8ccb6"))
            for k in range(5):
                b.append(f'<path d="M{x + 60 + k * 66},{y + 110} l16,18 l-10,18" stroke="{INK}" stroke-width="3" fill="none"/>')
            b.append(f'<rect x="{x + 40}" y="{y + 160}" width="340" height="14" fill="#f2c84b"/>')
            b.append(f'<circle cx="{x + 380}" cy="{y + 70}" r="14" fill="#d94a3a"/>')
        elif kind == "break":
            for k in range(5):
                b.append(f'<rect x="{x + 40 + k * 70}" y="{y + 110 + (k % 2) * 14}" width="62" height="36" fill="#d8ccb6" stroke="{INK}" stroke-width="2" transform="rotate({(k - 2) * 8} {x + 70 + k * 70} {y + 128})"/>')
        elif kind == "fall":
            b.append(f'<rect x="{x + 10}" y="{y + 10}" width="400" height="210" fill="#5d6b7d" opacity="0.25"/>')
            for (px, py, r) in ((120, 70, -20), (230, 140, 15), (320, 90, 30)):
                b.append(f'<rect x="{x + px}" y="{y + py}" width="56" height="26" fill="#d8ccb6" stroke="{INK}" stroke-width="2" transform="rotate({r} {x + px} {y + py})"/>')
            for (px, py) in ((180, 100), (280, 60)):
                b.append(f'<circle cx="{x + px}" cy="{y + py}" r="16" fill="#4f86d9" stroke="{INK}" stroke-width="2"/>')
            b.append(f'<path d="M{x + 380},{y + 40} V{y + 190} m-14,-16 l14,16 l14,-16" stroke="{INK}" stroke-width="5" fill="none"/>')
        else:
            b.append(f'<rect x="{x + 10}" y="{y + 10}" width="400" height="210" fill="#3a4554"/>')
            b.append(rect(x + 30, y + 170, 360, 30, "#7d8896"))
            b.append(f'<ellipse cx="{x + 210}" cy="{y + 170}" rx="170" ry="26" fill="#e8e0d0" opacity="0.8"/>')
            b.append(f'<path d="M{x + 120},{y + 170} L{x + 230},{y + 130} L{x + 236},{y + 146} L{x + 130},{y + 176} Z" fill="#d8ccb6" stroke="{INK}" stroke-width="2"/>')
        tc = "#ffffff" if kind == "land" else INK
        b.append(T(x + 210, y + 40, tm, 26, tc) + T(x + 210, y + 215, txt, 19, tc, "middle", 600))
        if i < 3:
            b.append(f'<path d="M{x + 424},{y + 115} h28 m-10,-10 l10,10 l-10,10" stroke="{INK}" stroke-width="4" fill="none"/>')
    return "".join(b)


def main():
    b = [f'<rect width="{W}" height="{H}" fill="#eef7f6"/>', T(W / 2, 56, "FASE 1 DO DERRUBA — CANTEIRO DE OBRAS (catálogo para aprovar)", 36)]
    b.append(etapa1(40, 90, 1840, 760))
    b.append(virada(0, 880))
    b.append(etapa2(40, 1220, 1840, 720))
    lx = 60
    for i, (k, nm) in enumerate([("E", "estrutura"), ("D", "demolição"), ("M", "mecanismo"), ("A", "fundo vivo")]):
        b.append(tag(lx + 30 + i * 260, 1990, k) + T(lx + 60 + i * 260, 1997, nm, 22, INK, "start", 600))
    b.append(T(1880, 1997, "lista completa: docs/fases/derruba/f1_canteiro.md", 20, "#2a4a58", "end", 500))
    save(doc(W, H, "".join(b)), os.path.join(ROOT, "art/src/cenarios/svg/fase1_catalogo.svg"), os.path.join(ROOT, "art/out/fase1_canteiro_catalogo.png"))


if __name__ == "__main__":
    main()
