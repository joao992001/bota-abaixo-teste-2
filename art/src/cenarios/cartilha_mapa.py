"""Esquema da CARTILHA DO MAPA (Derruba): camadas da cena viva (C0–C4), elementos do palco (Z1–Z8) e os atos.
Só diagrama para aprovar a ideia (não é arte de jogo). Rodar: python3 art/src/cenarios/cartilha_mapa.py
→ art/out/cartilha_mapa_derruba.png
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from svg import doc, save  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.."))
INK = "#2a1a2e"
W, H = 1920, 1400


def T(x, y, t, s=24, c=INK, a="middle", w=700):
    return f'<text x="{x}" y="{y}" font-family="Fredoka, Arial" font-weight="{w}" font-size="{s}" fill="{c}" text-anchor="{a}">{t}</text>'


def tag(x, y, z, txt, col):
    return (f'<circle cx="{x}" cy="{y}" r="22" fill="{col}" stroke="{INK}" stroke-width="3"/>' + T(x, y + 8, z, 20, "#ffffff")
            + T(x + 30, y + 8, txt, 20, INK, "start", 600))


def scene(ox, oy, w, h):
    b = []
    # C0 céu + assinatura
    b.append(f'<rect x="{ox}" y="{oy}" width="{w}" height="{h}" rx="18" fill="#bfe8f0"/>')
    b.append(f'<circle cx="{ox + w - 160}" cy="{oy + 80}" r="46" fill="#ffe7a8"/>')
    # C1 cidade distante + gruas
    for i, (x, hh) in enumerate([(40, 160), (120, 220), (210, 140), (300, 250), (420, 180), (560, 210), (700, 150), (830, 260), (980, 170), (1120, 230), (1260, 160)]):
        b.append(f'<rect x="{ox + x}" y="{oy + h - 330 - hh}" width="90" height="{hh + 200}" fill="#9fcfd9"/>')
    for gx in (ox + 260, ox + 1060):
        b.append(f'<path d="M{gx},{oy + 120} V{oy + h - 300} M{gx - 120},{oy + 140} H{gx + 220}" stroke="#86bcc8" stroke-width="10"/>')
        b.append(f'<path d="M{gx + 200},{oy + 140} V{oy + 230}" stroke="#86bcc8" stroke-width="3"/>')
    # C2 fundo próximo: betoneira e operário NPC
    b.append(f'<ellipse cx="{ox + 1180}" cy="{oy + h - 300}" rx="80" ry="55" fill="#d9a46a"/><rect x="{ox + 1110}" y="{oy + h - 260}" width="160" height="40" fill="#a87a4a"/>')
    b.append(f'<rect x="{ox + 150}" y="{oy + h - 330}" width="26" height="50" rx="8" fill="#7fae7a"/><circle cx="{ox + 163}" cy="{oy + h - 345}" r="14" fill="#7fae7a"/>')
    # C3 palco: base demolível (trechos), núcleo, andaimes, vigas, bordas
    gy = oy + h - 210
    segs = [(170, False), (330, False), (490, True), (650, True), (810, False), (970, False)]
    for x, nuc in segs:
        b.append(f'<rect x="{ox + x}" y="{gy}" width="156" height="60" fill="{"#c8bba6" if nuc else "#d8ccb6"}" stroke="{INK}" stroke-width="2"/>')
        if not nuc:
            b.append(f'<path d="M{ox + x + 20},{gy + 10} l30,30 l20,-12" stroke="{INK}" stroke-width="2" fill="none" opacity="0.5"/>')
    for x in (520, 680):
        b.append(f'<rect x="{ox + x + 40}" y="{gy + 60}" width="60" height="150" fill="#b8ab96"/>')
    for x in (60, 1140):
        b.append(f'<rect x="{ox + x}" y="{gy - 150}" width="120" height="14" fill="#c98a4b"/><path d="M{ox + x + 10},{gy - 136} V{gy + 200} M{ox + x + 110},{gy - 136} V{gy + 200}" stroke="#6b7783" stroke-width="6"/>')
    b.append(f'<rect x="{ox + 560}" y="{gy - 270}" width="300" height="16" fill="#6b7783"/><path d="M{ox + 600},{oy} V{gy - 270} M{ox + 820},{oy} V{gy - 270}" stroke="#5a4a3a" stroke-width="3"/>')
    b.append(f'<rect x="{ox + 330}" y="{gy - 120}" width="150" height="12" fill="#6b7783"/>')
    # Z7 mecanismo: elevador de obra
    b.append(f'<rect x="{ox + 1300}" y="{gy - 260}" width="16" height="470" fill="#6b7783"/><rect x="{ox + 1250}" y="{gy - 170}" width="110" height="20" fill="#f2c84b" stroke="{INK}" stroke-width="2"/>')
    # Z6 caixa
    b.append(f'<rect x="{ox + 700}" y="{gy - 300}" width="30" height="28" rx="5" fill="#f08a3d" stroke="{INK}" stroke-width="2"/>')
    # Z4 KO
    b.append(f'<rect x="{ox}" y="{oy}" width="{w}" height="{h}" rx="18" fill="none" stroke="#d94a3a" stroke-width="6" stroke-dasharray="18 12"/>')
    # C4 primeiro plano
    b.append(f'<path d="M{ox + 20},{oy + h - 20} L{ox + 260},{oy + h - 120}" stroke="#4a3a2e" stroke-width="26" opacity="0.55"/>')
    b.append(f'<path d="M{ox + w - 40},{oy + 30} q-60,120 -10,220" stroke="#f2c84b" stroke-width="8" fill="none" opacity="0.7"/>')
    return "".join(b), gy


def main():
    b = [f'<rect width="{W}" height="{H}" fill="#eef7f6"/>', T(W / 2, 60, "CARTILHA DO MAPA — DERRUBA: A FASE É UMA CENA VIVA EM ATOS", 38)]
    sc, gy = scene(60, 100, 1380, 680)
    b.append(sc)
    # legendas das camadas
    lx = 1470
    b.append(T(lx, 130, "CAMADAS", 26, INK, "start"))
    for i, (c, txt, col) in enumerate([("C0", "céu + silhueta-assinatura", "#bfe8f0"), ("C1", "fundo distante vivo (gruas, cidade)", "#9fcfd9"),
                                       ("C2", "fundo próximo (máquinas, operários)", "#d9a46a"), ("C3", "PALCO jogável (contraste máximo)", "#d8ccb6"),
                                       ("C4", "primeiro plano (vigas, fitas, poeira)", "#4a3a2e")]):
        y = 170 + i * 48
        b.append(f'<rect x="{lx}" y="{y - 22}" width="36" height="30" rx="6" fill="{col}" stroke="{INK}" stroke-width="2"/>' + T(lx + 18, y, c, 16, "#ffffff" if c == "C4" else INK))
        b.append(T(lx + 48, y, txt, 18, INK, "start", 500))
    b.append(T(lx, 440, "PALCO", 26, INK, "start"))
    zs = [("Z1", "núcleo (nunca cai no ato 1)", "#3c9a46"), ("Z2", "base demolível em trechos", "#f08a3d"), ("Z3", "estruturas elevadas", "#8a63d2"),
          ("Z4", "bordas + KO nos 4 lados", "#d94a3a"), ("Z5", "rotas de volta (≥2 por lado)", "#3fc1c9"), ("Z6", "pontos de disputa (caixas)", "#f2c84b"),
          ("Z7", "mecanismos da fase (2–3)", "#2a1a2e"), ("Z8", "vida de ambiente (não colide)", "#7fae7a")]
    for i, (z, txt, col) in enumerate(zs):
        b.append(tag(lx + 22, 480 + i * 46, z, txt, col))
    # marcadores no desenho
    ox = 60
    for (x, y, z, col) in [(ox + 640, gy + 30, "Z1", "#3c9a46"), (ox + 250, gy + 30, "Z2", "#f08a3d"), (ox + 710, gy - 300, "Z3", "#8a63d2"),
                           (ox + 30, 140, "Z4", "#d94a3a"), (ox + 120, gy - 175, "Z5", "#3fc1c9"), (ox + 760, gy - 330, "Z6", "#f2c84b"),
                           (ox + 1305, gy - 205, "Z7", "#2a1a2e"), (ox + 165, gy - 145, "Z8", "#7fae7a")]:
        b.append(f'<circle cx="{x}" cy="{y}" r="22" fill="{col}" stroke="#ffffff" stroke-width="4"/>' + T(x, y + 8, z, 20, "#ffffff"))
    # linha do tempo dos atos
    ty = 860
    b.append(T(W / 2, ty, "A PARTIDA COMO UMA CENA", 32))
    steps = [("ABERTURA", "Ato 1 · palco completo", "#9fe3f5"), ("ESCALADA", "demolição + eventos + mecanismos", "#f2c84b"),
             ("VIRADA", "60% caído ou ~90 s → cena 2–3 s", "#f08a3d"), ("CLÍMAX", "Ato 2 · outra região, outra arte", "#d94a3a")]
    for i, (nm, sub, col) in enumerate(steps):
        x = 90 + i * 450
        b.append(f'<rect x="{x}" y="{ty + 30}" width="400" height="120" rx="20" fill="{col}" stroke="{INK}" stroke-width="3"/>')
        b.append(T(x + 200, ty + 82, nm, 30) + T(x + 200, ty + 122, sub, 20, INK, "middle", 500))
        if i < 3:
            b.append(f'<path d="M{x + 408},{ty + 90} l34,0 m-12,-12 l12,12 l-12,12" stroke="{INK}" stroke-width="5" fill="none"/>')
    # opções da virada no Canteiro
    oy = 1050
    b.append(T(W / 2, oy, "CANTEIRO — ESCOLHER A VIRADA", 30))
    for i, (titulo, sub, desc, up) in enumerate([("A) A OBRA CEDE", "Ato 2: SUBSOLO / FUNDAÇÃO (bacia)", "laje desaba em poeira · todos caem · escuro, estacas, canos, bate-estaca gigante", False),
                                                 ("B) SUBIU A LAJE", "Ato 2: COBERTURA (ilhas)", "grua iça o núcleo · topo do prédio, fim de tarde, vento · contrapeso varrendo", True)]):
        x = 140 + i * 860
        b.append(f'<rect x="{x}" y="{oy + 24}" width="780" height="290" rx="22" fill="#ffffff" stroke="{INK}" stroke-width="3"/>')
        b.append(T(x + 390, oy + 70, titulo, 28) + T(x + 390, oy + 104, sub, 22, "#2a4a58", "middle", 600))
        # mini ato 1 → ato 2
        b.append(f'<rect x="{x + 60}" y="{oy + 170}" width="240" height="26" fill="#d8ccb6" stroke="{INK}" stroke-width="2"/>')
        b.append(T(x + 180, oy + 160, "ato 1", 18))
        if up:
            b.append(f'<path d="M{x + 330},{oy + 200} q60,-60 120,-60" stroke="{INK}" stroke-width="5" fill="none"/><path d="M{x + 440},{oy + 128} l14,12 l-16,8" fill="{INK}"/>')
            for k, (px, pw) in enumerate([(480, 80), (580, 70), (670, 70)]):
                b.append(f'<rect x="{x + px}" y="{oy + 150 + k * 18}" width="{pw}" height="18" fill="#c98a4b" stroke="{INK}" stroke-width="2"/>')
            b.append(f'<rect x="{x + 470}" y="{oy + 120}" width="290" height="110" rx="10" fill="#ffd9a8" opacity="0.5"/>')
        else:
            b.append(f'<path d="M{x + 330},{oy + 160} q60,0 110,70" stroke="{INK}" stroke-width="5" fill="none"/><path d="M{x + 432},{oy + 236} l18,4 l-4,-18" fill="{INK}"/>')
            b.append(f'<path d="M{x + 470},{oy + 150} V{oy + 250} H{x + 760} V{oy + 150}" stroke="{INK}" stroke-width="4" fill="#5d6b7d" opacity="0.8"/>')
            b.append(f'<rect x="{x + 560}" y="{oy + 225}" width="110" height="18" fill="#8a7a66" stroke="{INK}" stroke-width="2"/>')
        b.append(T(x + 390, oy + 290, desc, 19, INK, "middle", 500))
    save(doc(W, H, "".join(b)), os.path.join(ROOT, "art/src/cenarios/svg/cartilha_mapa.svg"), os.path.join(ROOT, "art/out/cartilha_mapa_derruba.png"))


if __name__ == "__main__":
    main()
