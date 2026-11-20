"""Temas de arena de metal (mesmo estilo papel e giz de temas.py):
ferro_velho (carros prensados em cubo, sucata, pátio ao fim de tarde) e
fundicao (lingotes, tijolo refratário, chapas; siderúrgica com caldeirões).
Saída: art/out/game/temas/<tema>/{bloco_0..2,fixo,tabua,fundo}.png
Rodar: python3 art/src/cenarios/temas_metal.py
"""
import math
import random

from temas import K, OUT, SRC, base_block, block_doc, gear_d, wrap  # noqa: F401  (temas ajusta o sys.path)
from papel import hatch, rough  # noqa: E402
from svg import doc, queue, render_all, shade  # noqa: E402


def zig(y, amp, step, rnd, x0=-4, x1=68):
    """Linha amassada (zigue-zague irregular) de x0 a x1 na altura y."""
    pts = [f"M{x0},{y:.1f}"]
    x = x0
    while x < x1:
        x += rnd.uniform(step * 0.6, step * 1.3)
        pts.append(f"L{x:.1f},{y + rnd.uniform(-amp, amp):.1f}")
    return " ".join(pts)


def blob(cx, cy, r, rnd, n=9):
    """Mancha irregular (ferrugem, fuligem)."""
    pts = []
    for i in range(n):
        a = 2 * math.pi * i / n
        rr = r * rnd.uniform(0.6, 1.15)
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr * 0.8))
    return "M" + " L".join(f"{x:.1f},{y:.1f}" for x, y in pts) + " Z"


def bevel(fill, top=5, bot=6):
    """Bisel chapado: topo claro, base e lateral direita escuras."""
    return (f'<rect x="0" y="0" width="64" height="{top}" fill="{shade(fill, 0.28)}"/>'
            f'<rect x="0" y="{64 - bot}" width="64" height="{bot}" fill="{shade(fill, -0.32)}"/>'
            f'<rect x="{64 - 4}" y="{top}" width="4" height="{64 - top - bot}" fill="{shade(fill, -0.2)}"/>')


# ================================================================== FERRO-VELHO
RUST, RUST_DK = "#a35b30", "#7c3f22"
CAR = ["#3f9a92", "#d6a33a", "#8e5c9c"]   # verde-água, mostarda, ameixa


def fv_bloco(i):
    rnd = random.Random(400 + i)
    fill = CAR[i]
    dark = shade(fill, -0.34)
    b = base_block(fill, 400 + i, dark, dens=0.6)
    # camadas da lataria prensada (linhas amassadas)
    for y in (17, 31, 45):
        b.append(f'<path d="{zig(y, 2.6, 7, rnd)}" stroke="{shade(fill, -0.3)}" stroke-width="3.2" fill="none" stroke-linejoin="round"/>')
        b.append(f'<path d="{zig(y - 3, 1.6, 9, rnd)}" stroke="{shade(fill, 0.22)}" stroke-width="1.4" fill="none" stroke-linejoin="round" opacity="0.8"/>')
    if i == 0:
        # farol redondo + grade cromada amassada
        b.append('<circle cx="17" cy="24" r="8.5" fill="#d9dcd6"/><circle cx="17" cy="24" r="5.5" fill="#f6ecc0"/>'
                 '<path d="M14,21 q2,-2 5,-1" stroke="#ffffff" stroke-width="2" fill="none" stroke-linecap="round"/>')
        for k in range(4):
            b.append(f'<path d="M{31 + k * 7},{19 + k * 0.6:.1f} l{rnd.uniform(-1, 1):.1f},11" stroke="#c9cdc9" stroke-width="3.4" stroke-linecap="round"/>')
        b.append(f'<path d="{blob(44, 50, 7, rnd)}" fill="{RUST}"/><circle cx="50" cy="44" r="2" fill="{RUST}"/>')
    elif i == 1:
        # janela esmagada com vidro trincado
        b.append('<path d="M10,22 L46,18 L52,32 L8,36 Z" fill="#3d4a58"/><path d="M13,24 L44,21 L48,31 L11,33 Z" fill="#bfdde3"/>'
                 '<path d="M26,22 L30,27 L24,32 M30,27 L38,29" stroke="#ffffff" stroke-width="1.5" fill="none" stroke-linejoin="round"/>')
        b.append(f'<path d="{blob(16, 50, 8, rnd)}" fill="{RUST}"/><path d="{blob(52, 12, 5, rnd)}" fill="{RUST}"/>')
        b.append('<rect x="38" y="44" width="14" height="4" rx="2" fill="#c9cdc9"/>')   # maçaneta
    else:
        # pneu aparecendo no canto + calota
        b.append('<circle cx="46" cy="44" r="15" fill="#34302f"/><circle cx="46" cy="44" r="8" fill="#b9b5ad"/><circle cx="46" cy="44" r="3" fill="#6d6863"/>')
        for a in range(0, 360, 40):
            x, y = 46 + math.cos(math.radians(a)) * 12, 44 + math.sin(math.radians(a)) * 12
            b.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="1.4" fill="#4c4645"/>')
        b.append(f'<path d="{blob(16, 20, 7, rnd)}" fill="{RUST}"/><circle cx="24" cy="12" r="2.2" fill="{RUST}"/>')
        b.append(f'<path d="M6,48 q6,-5 14,0" stroke="{shade(fill, 0.3)}" stroke-width="2.4" fill="none" stroke-linecap="round"/>')   # amassado
    b.append(bevel(fill))
    return block_doc(b)


def fv_fixo():
    fill = "#4e4644"
    rnd = random.Random(420)
    b = base_block(fill, 420, "#2c2628", "#6d6460")
    for y in (22, 42):   # fardo de ferro compactado
        b.append(f'<path d="{zig(y, 2.0, 8, rnd)}" stroke="#3a3335" stroke-width="3" fill="none"/>')
    b.append(f'<path d="{blob(40, 30, 6, rnd)}" fill="{RUST_DK}" opacity="0.9"/>')
    b.append(bevel(fill, 7, 7))
    for y in (12, 46):   # cintas de aço (horizontais: emendam lado a lado)
        b.append(f'<rect x="0" y="{y}" width="64" height="6" fill="#7d7570"/><rect x="0" y="{y + 4}" width="64" height="2" fill="#4f4846"/>')
    b.append('<rect x="24" y="44" width="14" height="10" rx="2" fill="#a39b94"/><circle cx="31" cy="49" r="2" fill="#3a3334"/>')
    return block_doc(b)


def fv_tabua():
    rnd = random.Random(430)
    b = ['<rect x="-1" y="2" width="66" height="12" fill="#b4835a"/>', '<rect x="-1" y="10.5" width="66" height="3.5" fill="#7a4d32"/>',
         '<rect x="-1" y="2" width="66" height="2.2" fill="#ddb48c"/>']
    for x in range(5, 64, 11):   # chapa perfurada
        b.append(f'<circle cx="{x}" cy="7.5" r="2.1" fill="#5e3a26"/>')
    for _ in range(3):
        b.append(f'<path d="{blob(rnd.uniform(4, 60), rnd.uniform(5, 11), 2.6, rnd, 7)}" fill="{RUST}"/>')
    return wrap(64, 16, "".join(b), 430, 0.5)


def scrap_ridge(rnd, y0, amp, fill, extra_col, n_bits):
    """Monte de sucata: morro irregular + pedaços (rodas, carros, canos) saindo do contorno."""
    pts = [f"M-20,1080 L-20,{y0}"]
    x, ys = -20, []
    while x < 1960:
        x += rnd.uniform(60, 140)
        y = y0 + rnd.uniform(-amp, amp * 0.4)
        ys.append((x, y))
        pts.append(f"Q{x - 40:.0f},{y - rnd.uniform(10, 40):.0f} {x:.0f},{y:.0f}")
    pts.append("L1960,1080 Z")
    out = [f'<path d="{" ".join(pts)}" fill="{fill}"/>']
    for _ in range(n_bits):
        x, y = rnd.choice(ys)
        x += rnd.uniform(-30, 30)
        kind = rnd.random()
        if kind < 0.35:   # roda
            r = rnd.uniform(22, 34)
            out.append(f'<circle cx="{x:.0f}" cy="{y + 6:.0f}" r="{r:.0f}" fill="{fill}"/><circle cx="{x:.0f}" cy="{y + 6:.0f}" r="{r * 0.4:.0f}" fill="{extra_col}"/>')
        elif kind < 0.7:   # carro inclinado
            a = rnd.uniform(-25, 25)
            out.append(f'<g transform="translate({x:.0f},{y + 10:.0f}) rotate({a:.0f})"><path d="M-70,0 V-26 H-40 L-24,-48 H26 L42,-26 H70 V0 Z" fill="{fill}"/>'
                       f'<path d="M-18,-42 H20 L32,-28 H-28 Z" fill="{extra_col}"/></g>')
        else:   # cano / viga torta
            a = rnd.uniform(-60, 60)
            out.append(f'<g transform="translate({x:.0f},{y + 10:.0f}) rotate({a:.0f})"><rect x="-10" y="-110" width="20" height="120" fill="{fill}"/></g>')
    return "".join(out)


def fv_fundo():
    rnd = random.Random(41)
    defs = ('<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#f7eebd"/>'
            '<stop offset="0.55" stop-color="#f6dc96"/><stop offset="1" stop-color="#f1c98f"/></linearGradient>') + rough("rough", 11, 2.2, 0.03)
    b = ['<rect width="1920" height="1080" fill="url(#sky)"/>', '<g filter="url(#rough)">']
    # sol baixo de fim de tarde + faixas de nuvem
    b.append('<circle cx="560" cy="430" r="150" fill="#fff4cc"/>')
    for x, y, w in [(180, 210, 420), (1180, 150, 520), (1500, 300, 300)]:
        b.append(f'<rect x="{x}" y="{y}" width="{w}" height="26" rx="13" fill="#fbecc0"/><rect x="{x + 60}" y="{y + 34}" width="{w * 0.6:.0f}" height="18" rx="9" fill="#fbecc0"/>')
    # montes de sucata ao longe
    b.append(scrap_ridge(rnd, 600, 120, "#ecd2a2", "#f3dcae", 14))
    # monte de sucata médio
    b.append(scrap_ridge(rnd, 820, 70, "#e0be92", "#e9cba0", 10))
    # pilhas de pneus
    tc = "#d4ad86"
    for x, n in [(150, 4), (262, 3), (760, 2), (1250, 4), (1360, 2), (1800, 3)]:
        for k in range(n):
            y = 900 - k * 38
            b.append(f'<rect x="{x - 56}" y="{y - 34}" width="112" height="36" rx="16" fill="{tc}"/><rect x="{x - 46}" y="{y - 30}" width="92" height="5" rx="2.5" fill="#dcb990"/>'
                     f'<rect x="{x - 24}" y="{y - 20}" width="48" height="10" rx="5" fill="#e6c79d"/>')
    # guindaste com eletroímã (camada média)
    gc = "#d2ad84"
    bx, by = 1560, 860
    b.append(f'<rect x="{bx - 90}" y="{by - 70}" width="180" height="90" rx="10" fill="{gc}"/>')   # cabine/base
    b.append(f'<rect x="{bx - 20}" y="{by - 130}" width="80" height="64" rx="8" fill="{gc}"/><rect x="{bx}" y="{by - 116}" width="44" height="30" rx="4" fill="#ecd2a2"/>')
    tipx, tipy = 1080, 170
    b.append(f'<path d="M{bx - 40},{by - 90} L{tipx},{tipy} M{bx + 10},{by - 70} L{tipx + 30},{tipy + 10}" stroke="{gc}" stroke-width="16" stroke-linecap="round"/>')
    for k in range(1, 10):   # treliça da lança
        t0, t1 = k / 10, (k + 0.5) / 10
        x0, y0 = bx - 40 + (tipx - bx + 40) * t0, by - 90 + (tipy - by + 90) * t0
        x1, y1 = bx + 10 + (tipx + 30 - bx - 10) * t1, by - 70 + (tipy + 10 - by + 70) * t1
        b.append(f'<path d="M{x0:.0f},{y0:.0f} L{x1:.0f},{y1:.0f}" stroke="{gc}" stroke-width="7"/>')
    b.append(f'<path d="M{tipx + 10},{tipy} V440" stroke="#c49c74" stroke-width="5"/>')   # cabo
    mx = tipx + 10
    b.append(f'<path d="M{mx - 14},440 L{mx - 40},462 M{mx + 14},440 L{mx + 40},462" stroke="#c49c74" stroke-width="5"/>'
             f'<rect x="{mx - 80}" y="458" width="160" height="40" rx="18" fill="{gc}"/><rect x="{mx - 66}" y="490" width="132" height="8" rx="4" fill="#c09670"/>')
    b.append(f'<g transform="rotate(8 {mx} 520)"><path d="M{mx - 86},556 V532 L{mx - 50},526 L{mx - 30},500 H{mx + 34} L{mx + 56},526 L{mx + 88},532 V556 Z" fill="#e2c194"/>'
             f'<path d="M{mx - 24},506 H{mx + 28} L{mx + 44},524 H{mx - 38} Z" fill="#eed5ae"/>'
             f'<circle cx="{mx - 50}" cy="558" r="17" fill="#cfa780"/><circle cx="{mx + 52}" cy="558" r="17" fill="#cfa780"/>'
             f'<circle cx="{mx - 50}" cy="558" r="7" fill="#e8cba2"/><circle cx="{mx + 52}" cy="558" r="7" fill="#e8cba2"/></g>')   # carro grudado no ímã
    # cerca de arame
    fc = "#c8a37c"
    b.append(f'<g opacity="0.55">')
    for x in range(-40, 1960, 28):
        b.append(f'<path d="M{x},760 L{x + 200},960 M{x + 200},760 L{x},960" stroke="{fc}" stroke-width="2.2"/>')
    b.append('</g>')
    for x in range(40, 1960, 300):
        b.append(f'<rect x="{x}" y="730" width="12" height="240" fill="{fc}"/>')
    b.append(f'<path d="M0,758 H1920 M0,962 H1920" stroke="{fc}" stroke-width="5"/>')
    b.append(f'<path d="M0,742 q20,-8 40,0 t40,0 t40,0 t40,0 t40,0 t40,0 t40,0 t40,0 t40,0 t40,0 t40,0 t40,0 t40,0 t40,0 t40,0 t40,0 t40,0 t40,0 t40,0 t40,0 t40,0 t40,0 t40,0 t40,0 t40,0 t40,0 t40,0 t40,0 t40,0 t40,0 t40,0 t40,0 t40,0 t40,0 t40,0 t40,0 t40,0 t40,0 t40,0 t40,0 t40,0 t40,0 t40,0 t40,0 t40,0 t40,0 t40,0 t40,0" stroke="{fc}" stroke-width="3" fill="none"/>')
    # chão de terra
    b.append('<path d="M0,1080 V960 Q480,940 960,962 T1920,952 V1080 Z" fill="#d7b088"/>')
    for _ in range(26):
        x, y = rnd.uniform(0, 1920), rnd.uniform(985, 1070)
        b.append(f'<ellipse cx="{x:.0f}" cy="{y:.0f}" rx="{rnd.uniform(8, 22):.0f}" ry="5" fill="#cfa47c"/>')
    b.append('</g>')
    return doc(1920, 1080, "".join(b), defs)


# ================================================================== FUNDIÇÃO
def fu_bloco(i):
    rnd = random.Random(500 + i)
    if i == 0:
        # pilha de lingotes de ferro
        fill = "#8a9bb0"
        b = [f'<rect width="64" height="64" fill="#4b4558"/>']
        for row in range(3):
            y = 2 + row * 21
            off = 0 if row % 2 == 0 else -16
            for col in range(3):
                x = off + col * 32 + 1
                tone = shade(fill, rnd.uniform(-0.08, 0.06))
                b.append(f'<path d="M{x},{y + 19} L{x + 4},{y} H{x + 26} L{x + 30},{y + 19} Z" fill="{tone}"/>'
                         f'<rect x="{x + 5}" y="{y}" width="20" height="4" fill="{shade(tone, 0.35)}"/>'
                         f'<path d="M{x + 26},{y} L{x + 30},{y + 19} H{x + 25} Z" fill="{shade(tone, -0.22)}"/>')
        b.append(hatch("all", (0, 0, 64, 64), fill, 500, k=1.4, dens=0.5, dark=shade(fill, -0.38)))
        return block_doc(b)
    if i == 1:
        # tijolo refratário (creme) com fuligem
        fill = "#e2c58e"
        b = ['<rect width="64" height="64" fill="#8b6f62"/>']
        for row in range(3):
            y = row * 21.33
            off = 0 if row % 2 == 0 else -21
            for col in range(3):
                x = off + col * 42
                tone = shade(fill, rnd.uniform(-0.1, 0.05))
                b.append(f'<rect x="{x + 1.6:.1f}" y="{y + 1.6:.1f}" width="38.8" height="18.1" rx="2" fill="{tone}"/>'
                         f'<rect x="{x + 1.6:.1f}" y="{y + 1.6:.1f}" width="38.8" height="3" fill="{shade(tone, 0.3)}"/>')
        b.append(hatch("all", (0, 0, 64, 64), fill, 501, k=1.4, dens=0.55, dark=shade(fill, -0.35)))
        b.append(f'<path d="{blob(46, 56, 13, rnd)}" fill="#4b4558" opacity="0.45"/><path d="{blob(14, 8, 8, rnd)}" fill="#4b4558" opacity="0.35"/>')
        return block_doc(b)
    # chapa de bronze rebitada com mancha de têmpera
    fill = "#c98a55"
    b = base_block(fill, 502, shade(fill, -0.34))
    b.append('<path d="M18,40 q10,-10 22,-4 q10,6 8,16 q-12,6 -24,0 Z" fill="#8f7fb4" opacity="0.7"/>'
             '<path d="M24,42 q8,-5 15,-1 q5,4 4,9 q-9,3 -17,-1 Z" fill="#6f9ac0" opacity="0.65"/>')
    wy = 21 + rnd.uniform(-1, 1)
    b.append(f'<path d="M4,{wy:.1f} H60" stroke="{shade(fill, -0.28)}" stroke-width="3.4" stroke-linecap="round"/>'
             f'<path d="M4,{wy - 1.6:.1f} H60" stroke="{shade(fill, 0.25)}" stroke-width="1.1"/>')   # cordão de solda
    b.append(bevel(fill, 6, 6))
    for x, y in [(9, 12), (55, 12), (9, 52), (55, 52), (32, 12)]:
        b.append(f'<circle cx="{x}" cy="{y}" r="4" fill="{shade(fill, -0.3)}"/><circle cx="{x - 0.8}" cy="{y - 0.8}" r="2.6" fill="{shade(fill, 0.32)}"/>')
    return block_doc(b)


def fu_fixo():
    fill = "#3a3442"
    b = base_block(fill, 520, "#211c27", "#5c5468")
    b.append('<rect x="14" y="14" width="36" height="36" rx="4" fill="#47404f"/><rect x="14" y="14" width="36" height="5" fill="#5f5769"/>'
             '<rect x="18" y="47" width="32" height="3" fill="#29232f"/>')
    b.append(bevel(fill, 7, 7))
    for x, y in [(8, 8), (56, 8), (8, 56), (56, 56)]:
        hexp = " ".join(f"{x + math.cos(math.radians(a)) * 5:.1f},{y + math.sin(math.radians(a)) * 5:.1f}" for a in range(0, 360, 60))
        b.append(f'<polygon points="{hexp}" fill="#8c8496"/><circle cx="{x}" cy="{y}" r="1.8" fill="#2a2430"/>')
    return block_doc(b)


def fu_tabua():
    b = ['<rect x="-1" y="2" width="66" height="11" fill="#8a8594"/>', '<rect x="-1" y="10" width="66" height="4" fill="#4f4a59"/>',
         '<rect x="-1" y="2" width="66" height="2.2" fill="#c8c3d0"/>']
    for k in range(9):   # chapa xadrez (relevo)
        x = 2 + k * 7
        d = "M{},{} l4,-3".format(x, 8.5 if k % 2 else 6.5) if k % 2 else "M{},{} l4,3".format(x, 5)
        b.append(f'<path d="{d}" stroke="#b2adbb" stroke-width="1.6" stroke-linecap="round"/>')
    return wrap(64, 16, "".join(b), 530, 0.5)


def ladle(cx, top, w, h, body, rim, metal, tilt=0):
    """Caldeirão de metal derretido (sem contorno)."""
    return (f'<g transform="rotate({tilt} {cx} {top})">'
            f'<path d="M{cx - w / 2},{top} H{cx + w / 2} L{cx + w * 0.4},{top + h * 0.8} Q{cx},{top + h * 1.08} {cx - w * 0.4},{top + h * 0.8} Z" fill="{body}"/>'
            f'<rect x="{cx - w / 2 - 14}" y="{top - 14}" width="{w + 28}" height="28" rx="14" fill="{rim}"/>'
            f'<ellipse cx="{cx}" cy="{top - 2}" rx="{w / 2 - 6}" ry="9" fill="{metal}"/>'
            f'<rect x="{cx - w / 2 + 10}" y="{top + h * 0.35}" width="{w - 20}" height="14" rx="7" fill="{rim}"/></g>')


def fu_fundo():
    rnd = random.Random(53)
    defs = ('<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#6b5866"/>'
            '<stop offset="0.6" stop-color="#8a6966"/><stop offset="1" stop-color="#a7786a"/></linearGradient>'
            '<radialGradient id="glow"><stop offset="0" stop-color="#eda876" stop-opacity="0.42"/><stop offset="1" stop-color="#f3a866" stop-opacity="0"/></radialGradient>'
            ) + rough("rough", 13, 2.2, 0.03)
    b = ['<rect width="1920" height="1080" fill="url(#sky)"/>', '<g filter="url(#rough)">']
    # chaminés ao fundo com fumaça
    far = "#7c6470"
    for x, w, h in [(120, 90, 700), (330, 70, 560), (1380, 110, 760), (1640, 80, 600), (1790, 60, 480)]:
        top = 1080 - h
        b.append(f'<rect x="{x}" y="{top}" width="{w}" height="{h}" fill="{far}"/>'
                 f'<rect x="{x - 8}" y="{top}" width="{w + 16}" height="22" fill="{shade(far, 0.1)}"/>'
                 f'<rect x="{x}" y="{top + 90}" width="{w}" height="14" fill="{shade(far, 0.08)}"/>')
        sx, sy = x + w / 2, top - 30
        b.append('<g fill="#7f6873" opacity="0.6">')
        for k in range(4):
            b.append(f'<circle cx="{sx + k * 46:.0f}" cy="{sy - k * 50:.0f}" r="{38 + k * 16}"/>')
        b.append('</g>')
    # treliça do telhado do galpão
    tc = "#6a5664"
    b.append(f'<path d="M0,120 H1920 M0,40 H1920" stroke="{tc}" stroke-width="14"/>')
    for x in range(0, 1920, 120):
        b.append(f'<path d="M{x},40 L{x + 60},120 L{x + 120},40" stroke="{tc}" stroke-width="7" fill="none"/>')
    # pórtico rolante com gancho e caldeirão suspenso
    b.append(f'<rect x="0" y="170" width="1920" height="30" fill="{tc}"/>')
    b.append(f'<rect x="1050" y="196" width="120" height="40" rx="8" fill="{tc}"/><path d="M1090,236 V330 M1130,236 V330" stroke="{tc}" stroke-width="6"/>')
    b.append(f'<path d="M1070,346 Q1110,300 1150,346" stroke="{tc}" stroke-width="12" fill="none"/>')
    # brilhos do metal (antes dos caldeirões)
    for cx, cy, r in [(1110, 520, 260), (520, 760, 300), (840, 900, 220)]:
        b.append(f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="url(#glow)"/>')
    body, rim, metal = "#7e6672", "#8b7380", "#ebbb8e"
    b.append(ladle(1110, 360, 190, 170, body, rim, metal, tilt=0))
    # suporte do caldeirão
    b.append(f'<path d="M380,880 L440,640 M600,880 L540,640" stroke="#76606d" stroke-width="26" stroke-linecap="round"/>')
    # caldeirão grande inclinado derramando nos moldes
    b.append(ladle(470, 600, 240, 220, body, rim, metal, tilt=-24))
    b.append('<path d="M598,560 Q680,570 690,640 L700,850" stroke="#e5ab80" stroke-width="20" fill="none" stroke-linecap="round"/>'
             '<path d="M604,566 Q672,576 682,640 L690,850" stroke="#f1cfaa" stroke-width="6" fill="none" stroke-linecap="round"/>')
    # fileira de moldes no chão (brilho no topo)
    for k in range(7):
        x = 640 + k * 130
        hot = k < 3
        b.append(f'<rect x="{x}" y="850" width="104" height="60" rx="6" fill="#7a6470"/>'
                 f'<rect x="{x + 10}" y="852" width="84" height="12" rx="5" fill="{"#e6b088" if hot else "#8a7280"}"/>')
    # faíscas
    for _ in range(28):
        a = rnd.uniform(-2.6, -0.3)
        d = rnd.uniform(30, 230)
        x, y = 700 + math.cos(a) * d, 850 + math.sin(a) * d * 0.9
        ln = rnd.uniform(6, 14)
        b.append(f'<path d="M{x:.0f},{y:.0f} l{math.cos(a) * ln:.1f},{math.sin(a) * ln:.1f}" stroke="#f6d6ae" stroke-width="{rnd.uniform(2, 3):.1f}" stroke-linecap="round" opacity="{rnd.uniform(0.45, 0.8):.2f}"/>')
    # chão da fundição
    b.append('<rect x="0" y="910" width="1920" height="170" fill="#5c4856"/><rect x="0" y="910" width="1920" height="10" fill="#6e5866"/>')
    for x in range(60, 1920, 220):
        b.append(f'<rect x="{x}" y="940" width="120" height="8" rx="4" fill="#655060"/>')
    b.append('</g>')
    return doc(1920, 1080, "".join(b), defs)


TEMAS = {
    "ferro_velho": (fv_bloco, fv_fixo, fv_tabua, fv_fundo),
    "fundicao": (fu_bloco, fu_fixo, fu_tabua, fu_fundo),
}


def main():
    for nome, (bloco, fixo, tabua, fundo) in TEMAS.items():
        for i in range(3):
            queue(bloco(i), f"{SRC}/{nome}/bloco_{i}.svg", f"{OUT}/{nome}/bloco_{i}.png", 64, 64, K)
        queue(fixo(), f"{SRC}/{nome}/fixo.svg", f"{OUT}/{nome}/fixo.png", 64, 64, K)
        queue(tabua(), f"{SRC}/{nome}/tabua.svg", f"{OUT}/{nome}/tabua.png", 64, 16, K)
        queue(fundo(), f"{SRC}/{nome}/fundo.svg", f"{OUT}/{nome}/fundo.png", 1920, 1080, 2)
    print("temas_metal:", render_all())


if __name__ == "__main__":
    main()
