"""Gera as fases novas (Batata, Rei, Fuga) em levels/*.lvl, com checagens. Uso único (as fases ficam como texto)."""
import sys
from pathlib import Path

LEV = Path(__file__).resolve().parents[2] / "levels"
SOLID = set("#oIdTFfPBJDa<>")


class C:
    def __init__(self, w, h, floor_rows=3, spikes=False, walls="I"):
        self.w, self.h = w, h
        self.g = [["."] * w for _ in range(h)]
        for x in range(w):
            self.g[0][x] = "I"
        for y in range(h):
            self.g[y][0] = walls
            self.g[y][w - 1] = walls
        for y in range(h - floor_rows, h):
            for x in range(w):
                self.g[y][x] = "^" if (spikes and y == h - 1) else "#"

    def put(self, x, y, ch):
        assert 0 <= x < self.w and 0 <= y < self.h, (x, y)
        self.g[y][x] = ch

    def plat(self, x, y, n, ch="#"):
        for i in range(n):
            self.put(x + i, y, ch)

    def col(self, x, y, n, ch="#"):
        for i in range(n):
            self.put(x, y + i, ch)

    def box(self, x, y, w, h, ch="#"):
        for j in range(h):
            self.plat(x, y + j, w, ch)

    def clear(self, x, y, w, h):
        self.box(x, y, w, h, ".")

    def mirror(self):
        """Espelha a metade esquerda na direita (fases simétricas, justas para os 4 spawns)."""
        for y in range(self.h):
            for x in range(self.w // 2):
                ch = self.g[y][x]
                m = {"<": ">", ">": "<"}.get(ch, ch)
                if ch not in "1234YZKE":
                    self.g[y][self.w - 1 - x] = m

    def text(self):
        return "\n".join("".join(r) for r in self.g)


def check(name, c, kind):
    rows = c.text().split("\n")
    errs = []
    g = c.g
    def solid(x, y):
        if x < 0 or y < 0 or x >= c.w or y >= c.h:
            return True
        return g[y][x] in SOLID
    for y in range(2, c.h):
        for x in range(c.w):
            if solid(x, y) and g[y][x] != "I" and not solid(x, y - 1) and solid(x, y - 2):
                errs.append(f"vão de 1 bloco em ({x},{y})")
    for s in "1234":
        pos = [(x, y) for y in range(c.h) for x in range(c.w) if g[y][x] == s]
        if len(pos) != 1:
            errs.append(f"spawn {s}: {len(pos)}")
        elif not solid(pos[0][0], pos[0][1] + 1):
            errs.append(f"spawn {s} sem chão")
    for p in "YZ":
        n = sum(r.count(p) for r in rows)
        if n not in (0, 2):
            errs.append(f"tubo {p}: {n} bocas")
    if kind in ("batata", "rei") and any("^" in r or "w" in r for r in rows):
        errs.append("tem espinho/água")
    if kind == "rei" and sum(r.count("K") for r in rows) != 1:
        errs.append("sem trono K")
    if kind == "fuga" and sum(r.count("E") for r in rows) != 1:
        errs.append("sem elevador E")
    if errs:
        print(name, "PROBLEMAS:", errs[:6])
        return False
    return True


def write(id_, c, kind, header):
    ok = check(id_, c, kind)
    legend = 'legend: "# sólido, d caixote, T TNT, = tábua, D porta, L alavanca (abre/fecha portas e alçapões a), J trampolim, Y/Z tubos, F ventilador, < > esteira, K trono, E elevador, 1-4 spawn"'
    head = f"id: {id_}\n" + header.strip() + f"\nsize: {c.w}x{c.h}\nspawns: 1,2,3,4\n{legend}\n=== map\n"
    (LEV / f"{id_}.lvl").write_text(head + c.text() + "\n", encoding="utf-8")
    print(f"{id_:22s} {c.w}x{c.h} {'ok' if ok else 'COM PROBLEMAS'}")
    return ok


W, H = 44, 24
GROUND = H - 3        # linha do chão (topo em y = 21)


def spawns(c, xs, y=GROUND - 1):
    for i, x in enumerate(xs):
        c.put(x, y, str(i + 1))


# =============================================================== BATATA-DINAMITE (fechadas, sem poço)
def b_obra():
    """Obra de Concreto: prédio em 3 andares; sala central com portas; poços com trampolim; tubos."""
    c = C(W, H)
    c.plat(6, 15, 7); c.plat(16, 15, 6); c.put(12, 15, "d"); c.put(16, 15, "d")   # 2º andar (vãos nos poços)
    c.plat(10, 9, 9); c.put(10, 9, "d")                                                # 3º andar
    c.plat(19, 4, 3)                                                                   # cobertura
    c.col(17, 10, 2, "#"); c.col(17, 12, 3, "D")                                       # parede + porta da sala
    c.put(15, 14, "L")
    c.put(14, GROUND - 1, "J")                                                         # poço com trampolim
    c.plat(2, 18, 3, "="); c.plat(2, 12, 3, "=")
    c.put(5, 20, "d"); c.put(6, 20, "d")
    c.mirror()
    c.put(2, GROUND - 1, "Y"); c.put(21, 3, "Y")
    c.put(11, 8, "Z"); c.put(41, GROUND - 1, "Z")
    spawns(c, [8, 17, 26, 35])
    return c


def b_mina():
    """Galerias da Mina: rocha com túneis, trilhos (esteiras), portas nas galerias, poços com trampolim."""
    c = C(W, H)
    c.box(1, 5, 42, 3, "#"); c.box(1, 13, 42, 2, "#")                                 # duas camadas de rocha
    c.clear(4, 5, 3, 3); c.clear(19, 13, 6, 2)                                        # passagens (descer)
    c.plat(8, 12, 10, ">"); c.plat(26, 12, 10, "<")                                   # trilhos na galeria do meio
    c.col(15, 8, 4, "#"); c.col(15, 9, 3, "D"); c.put(13, 11, "L")                    # porta na galeria
    c.put(10, GROUND - 1, "J"); c.clear(10, 13, 2, 2)                                 # poço de trampolim até a galeria
    c.put(21, 17, "T"); c.plat(16, 17, 4, "d")
    c.plat(3, 3, 4, "=")
    c.mirror()
    c.put(2, 4, "Y"); c.put(41, 20, "Y")
    c.put(2, 20, "Z"); c.put(41, 4, "Z")
    spawns(c, [6, 16, 27, 37])
    return c


def b_predio():
    """Prédio Velho: cômodos com paredes de caixote (dá para quebrar), alçapões com alavanca, portas."""
    c = C(W, H)
    for y in (15, 9):
        c.plat(4, y, 36, "#")
    c.plat(10, 15, 4, "a"); c.plat(30, 15, 4, "a")                                    # alçapões entre o 1º e o 2º andar
    c.plat(19, 9, 6, "a")
    c.col(14, 16, 5, "d"); c.col(29, 16, 5, "d")                                      # paredes de caixote no térreo
    c.col(21, 10, 2, "#"); c.col(21, 12, 3, "D"); c.col(22, 10, 2, "#"); c.col(22, 12, 3, "D")
    c.put(7, 14, "L"); c.put(36, 14, "L"); c.put(21, 8, "L")
    c.put(2, GROUND - 1, "J"); c.put(41, GROUND - 1, "J")
    c.plat(1, 5, 4, "="); c.plat(39, 5, 4, "=")
    c.put(8, 20, "d"); c.put(35, 20, "d")
    c.put(5, 8, "Y"); c.put(38, 20, "Y")
    c.put(38, 8, "Z"); c.put(5, 20, "Z")
    spawns(c, [10, 18, 25, 33])
    return c


def b_viaduto():
    """Sob o Viaduto: pilares, plataformas que vão e voltam, ventiladores que sobem, trampolins."""
    c = C(W, H)
    c.plat(1, 6, 42, "#"); c.clear(9, 6, 4, 1); c.clear(31, 6, 4, 1); c.clear(20, 6, 4, 1)   # pista do viaduto
    for x in (7, 18, 25, 36):
        c.col(x, 7, 14, "#")                                                           # pilares
    c.put(13, GROUND - 1, "F"); c.put(30, GROUND - 1, "F")                             # ventiladores (sobem)
    c.put(22, GROUND - 1, "J")
    c.col(18, 16, 3, "D"); c.col(25, 16, 3, "D"); c.put(20, 20, "L"); c.put(23, 20, "L")
    c.plat(2, 14, 4, "="); c.plat(38, 14, 4, "="); c.plat(9, 11, 3, "="); c.plat(32, 11, 3, "=")
    c.put(3, 5, "Y"); c.put(40, 20, "Y"); c.put(40, 5, "Z"); c.put(3, 20, "Z")
    spawns(c, [4, 11, 32, 39])
    return c, "plataformas: 8,13,3,4,0,5; 33,13,3,-4,0,5\nventilador_ciclo: 3, 2\nventilador_alcance: 9"


def b_pantano():
    """Palafitas do Pântano: casinhas sobre estacas ligadas por gangorras e tábuas; portas nas casas."""
    c = C(W, H)
    for x0 in (3, 18, 33):
        c.plat(x0, 13, 8, "#"); c.col(x0, 14, 7, "#"); c.col(x0 + 7, 14, 7, "#")      # casa sobre estacas
        c.col(x0 + 1, 9, 4, "#"); c.col(x0 + 6, 9, 4, "#"); c.plat(x0 + 1, 8, 6, "#")  # paredes e telhado
        c.col(x0 + 1, 10, 3, "D"); c.put(x0 + 3, 12, "L")
    c.plat(12, 10, 5, "="); c.plat(27, 10, 5, "=")
    c.put(14, GROUND - 1, "J"); c.put(29, GROUND - 1, "J")
    c.put(2, 20, "Y"); c.put(22, 7, "Y"); c.put(41, 20, "Z"); c.put(5, 7, "Z")
    spawns(c, [12, 16, 27, 31])
    return c, "gangorras: 14.5,16,6; 29.5,16,6"


def b_telhados():
    """Telhados da Cidade: prédios de alturas diferentes, casinhas de máquina com porta, trampolins e ventiladores."""
    c = C(W, H)
    c.box(1, 16, 9, 5, "#"); c.box(13, 12, 7, 9, "#"); c.box(24, 14, 8, 7, "#"); c.box(35, 10, 8, 11, "#")
    c.box(3, 13, 4, 3, "#"); c.clear(4, 14, 2, 2); c.put(3, 14, "D"); c.put(3, 15, "D"); c.put(5, 15, "L")
    c.box(37, 7, 4, 3, "#"); c.clear(38, 8, 2, 2); c.put(40, 8, "D"); c.put(40, 9, "D"); c.put(38, 9, "L")
    c.put(11, GROUND - 1, "J"); c.put(22, GROUND - 1, "J"); c.put(33, GROUND - 1, "J")
    c.put(16, 11, "F"); c.plat(20, 8, 4, "="); c.plat(8, 9, 3, "=")
    c.put(2, 15, "Y"); c.put(28, 13, "Y"); c.put(12, GROUND - 1, "Z"); c.put(15, 11, "Z")
    c.put(8, 15, "1"); c.put(18, 11, "2"); c.put(26, 13, "3"); c.put(36, 9, "4")
    return c, "ventilador_ciclo: 3, 2\nventilador_alcance: 6"


# =============================================================== REI DA OBRA (trono K no alto, sem espinho)
def r_canteiro():
    """Canteiro do Rei: torre de andaime no centro com o trono; portas na base da torre (alavancas trancam a subida)."""
    c = C(W, H)
    c.box(18, 4, 8, 1, "#"); c.put(21, 3, "K")                                         # trono
    c.col(18, 5, 12, "o"); c.col(25, 5, 12, "o")                                       # estrutura da torre
    for y in (8, 12, 16):
        c.plat(19, y, 6, "=")
    c.col(18, 17, 4, "D"); c.col(25, 17, 4, "D"); c.put(15, 20, "L"); c.put(28, 20, "L")
    c.plat(5, 16, 7, "d"); c.plat(32, 16, 7, "d"); c.plat(9, 11, 6, "#"); c.plat(29, 11, 6, "#")
    c.plat(13, 7, 3, "="); c.plat(28, 7, 3, "=")
    c.put(3, GROUND - 1, "J"); c.put(40, GROUND - 1, "J")
    c.put(10, 10, "Y"); c.put(33, 20, "Y"); c.put(33, 10, "Z"); c.put(10, 20, "Z")
    spawns(c, [6, 12, 31, 37])
    return c


def r_fabrica():
    """Linha de Montagem: esteiras no chão, ventiladores que levam ao trono, portas de atalho."""
    c = C(W, H)
    c.plat(1, GROUND, 42, "#")
    c.plat(4, 17, 14, ">"); c.plat(26, 17, 14, "<")                                   # esteiras do meio
    c.plat(17, 6, 10, "#"); c.put(21, 5, "K")
    c.put(14, 16, "F"); c.put(29, 16, "F")                                            # ventiladores sobem para o trono
    c.plat(8, 12, 5, "#"); c.plat(31, 12, 5, "#"); c.col(12, 9, 3, "D"); c.col(31, 9, 3, "D")
    c.put(9, 11, "L"); c.put(34, 11, "L"); c.plat(9, 8, 4, "#"); c.plat(31, 8, 4, "#")
    c.put(2, GROUND - 1, "J"); c.put(41, GROUND - 1, "J")
    c.put(3, 16, "Y"); c.put(40, 7, "Y"); c.put(40, 16, "Z"); c.put(3, 7, "Z")
    spawns(c, [8, 16, 27, 35])
    return c, "ventilador_ciclo: 4, 1.5\nventilador_alcance: 10\nesteira_vel: 2.6\nesteira_inverte: 8"


def r_porto():
    """Cais do Rei: pilhas de contêineres, guindastes que movem plataformas até a cabine com o trono."""
    c = C(W, H)
    c.box(2, 17, 6, 4, "d"); c.box(36, 17, 6, 4, "d"); c.box(13, 14, 5, 7, "d"); c.box(26, 14, 5, 7, "d")
    c.box(19, 5, 6, 1, "#"); c.put(21, 4, "K")
    c.plat(3, 11, 6, "#"); c.plat(35, 11, 6, "#")
    c.col(18, 15, 3, "D"); c.col(25, 15, 3, "D"); c.put(20, 20, "L"); c.put(23, 20, "L")
    c.put(10, GROUND - 1, "J"); c.put(33, GROUND - 1, "J")
    c.put(4, 10, "Y"); c.put(28, 13, "Y"); c.put(39, 10, "Z"); c.put(15, 13, "Z")
    c.put(4, 16, "1"); c.put(11, GROUND - 1, "2"); c.put(32, GROUND - 1, "3"); c.put(39, 16, "4")
    return c, "plataformas: 9,9,3,0,6,6; 32,9,3,0,6,6; 14,7,3,4,0,5"


def r_mina():
    """Mina de Ouro: caverna central com elevador até o trono; túneis laterais com portas."""
    c = C(W, H)
    c.box(1, 12, 13, 2, "#"); c.box(30, 12, 13, 2, "#"); c.box(1, 6, 10, 2, "#"); c.box(33, 6, 10, 2, "#")
    c.col(10, 8, 4, "#"); c.col(33, 8, 4, "#"); c.col(10, 9, 3, "D"); c.col(33, 9, 3, "D")
    c.put(5, 11, "L"); c.put(38, 11, "L")
    c.plat(18, 4, 8, "#"); c.put(21, 3, "K")
    c.plat(14, 16, 3, "="); c.plat(27, 16, 3, "="); c.plat(12, 9, 3, "="); c.plat(29, 9, 3, "=")
    c.put(6, GROUND - 1, "J"); c.put(37, GROUND - 1, "J")
    c.put(2, 20, "Y"); c.put(3, 5, "Y"); c.put(41, 20, "Z"); c.put(40, 5, "Z")
    spawns(c, [9, 16, 27, 34])
    return c, "plataformas: 20.5,18,3,0,-12,7"


def r_serraria():
    """Serraria do Rei: torres de toras, gangorras de tábua, trampolins; trono no alto da pilha central."""
    c = C(W, H)
    c.box(19, 7, 6, 14, "d"); c.clear(20, 15, 4, 3); c.col(19, 15, 3, "D"); c.col(24, 15, 3, "D"); c.put(21, 17, "L")
    c.put(21, 6, "K")
    c.box(4, 15, 5, 6, "d"); c.box(35, 15, 5, 6, "d")
    c.plat(10, 10, 5, "#"); c.plat(29, 10, 5, "#"); c.plat(14, 6, 3, "="); c.plat(27, 6, 3, "=")
    c.put(2, GROUND - 1, "J"); c.put(41, GROUND - 1, "J"); c.put(16, GROUND - 1, "J"); c.put(27, GROUND - 1, "J")
    c.put(5, 14, "Y"); c.put(31, 9, "Y"); c.put(38, 14, "Z"); c.put(12, 9, "Z")
    spawns(c, [10, 13, 30, 33])
    return c, "gangorras: 11.5,18,6; 31.5,18,6"


def r_demolicao():
    """Prédio em Demolição: a bola varre embaixo do trono; paredes de caixote; alçapões."""
    c = C(W, H)
    c.plat(18, 5, 8, "#"); c.put(21, 4, "K")
    c.plat(3, 15, 12, "#"); c.plat(29, 15, 12, "#"); c.plat(7, 10, 8, "#"); c.plat(29, 10, 8, "#")
    c.plat(10, 15, 3, "a"); c.plat(31, 15, 3, "a"); c.put(4, 14, "L"); c.put(39, 14, "L")
    c.col(14, 16, 5, "d"); c.col(29, 16, 5, "d"); c.col(7, 11, 4, "d"); c.col(36, 11, 4, "d")
    c.plat(15, 8, 3, "="); c.plat(26, 8, 3, "=")
    c.put(2, GROUND - 1, "J"); c.put(41, GROUND - 1, "J")
    c.put(8, 9, "Y"); c.put(35, 20, "Y"); c.put(35, 9, "Z"); c.put(8, 20, "Z")
    spawns(c, [10, 18, 25, 33])
    return c, "bola: 21.5,0,13,55,4.4"


# =============================================================== FUGA
def f_obra():
    """Obra Subindo (30x48): zigue-zague de lajes, trampolins, portas que trancam quem vem atrás; elevador no topo."""
    c = C(30, 48, floor_rows=1, spikes=True)
    y = 44
    side = 0
    while y > 6:
        if side == 0:
            c.plat(1, y, 19, "#" if y % 2 == 0 else "d")
        else:
            c.plat(10, y, 19, "#" if y % 2 == 0 else "d")
        if y % 8 == 4:
            c.put(5 if side == 0 else 24, y - 1, "J")
        if y % 12 == 8:
            x = 15
            c.col(x, y - 3, 3, "D"); c.put(x - 3 if side == 0 else x + 3, y - 1, "L")
        y -= 4
        side ^= 1
    c.plat(10, 4, 10, "#"); c.put(14, 3, "E")
    for i, x in enumerate([4, 8, 12, 16]):
        c.put(x, 43, str(i + 1))
    return c, "rolagem: cima, 0.6, 5\nalcapao_s: 4"


def f_fundicao():
    """Fuga da Fundição (30x48, câmera DESCE): desça pelos andares antes que a tela te deixe para cima."""
    c = C(30, 48, floor_rows=1)
    y = 6
    side = 0
    while y < 44:
        if side == 0:
            c.plat(1, y, 21, "#" if y % 2 == 0 else "d"); c.plat(26, y, 3, "=")
        else:
            c.plat(8, y, 21, "#" if y % 2 == 0 else "d"); c.plat(1, y, 3, "=")
        if y % 10 == 6:
            c.col(14, y - 3, 3, "D"); c.put(11, y - 1, "L")
        y += 4
        side ^= 1
    c.plat(1, 46, 28, "#"); c.put(14, 45, "E")
    for i, x in enumerate([4, 8, 12, 16]):
        c.put(x, 5, str(i + 1))
    return c, "rolagem: baixo, 0.7, 5\nalcapao_s: 4"


def f_viaduto():
    """Viaduto em Obras (84x18, câmera avança): duas pistas claras (alta e baixa), vãos regulares, portas com alavanca."""
    w = 84
    c = C(w, 18, floor_rows=1, spikes=True)
    for x in range(1, w - 1):
        c.put(x, 14, "#")                      # pista baixa
        c.put(x, 15, "#")
    for x0 in range(14, w - 8, 12):
        c.clear(x0, 14, 3, 2)                  # vãos regulares na pista baixa
    for x0 in range(6, w - 6, 16):
        c.plat(x0, 9, 9, "#")                  # pista alta (trechos)
        c.put(x0 + 1, 13, "J")
    for x0 in range(17, w - 12, 16):
        c.col(x0, 11, 3, "D"); c.put(x0 - 3, 13, "L")
    c.plat(w - 8, 13, 7, "#"); c.put(w - 4, 12, "E")
    for i, x in enumerate([3, 5, 7, 9]):
        c.put(x, 13, str(i + 1))
    return c, "rolagem: direita, 1.0, 5\nalcapao_s: 4"


def f_ferro_velho():
    """Ferro-velho (84x18, câmera avança): montes de sucata, esteiras que ajudam/atrasam, tubos de atalho curtos."""
    w = 84
    c = C(w, 18, floor_rows=1, spikes=True)
    x = 1
    k = 0
    while x < w - 10:
        n = 7 + (k % 3)
        h = 12 - (k % 3)
        c.plat(x, h, n, "#" if k % 2 == 0 else "d")
        c.plat(x, h + 1, n, "#")
        if k % 2 == 1:
            c.plat(x + 1, h, n - 2, ">")
        x += n + 3
        k += 1
    c.plat(w - 9, 12, 8, "#"); c.plat(w - 9, 13, 8, "#"); c.put(w - 4, 11, "E")
    c.put(12, 10, "Y"); c.put(30, 9, "Y")
    c.put(46, 10, "Z"); c.put(62, 9, "Z")
    first = [i for i in range(1, 8)]
    for i, xx in enumerate([2, 3, 5, 6]):
        c.put(xx, 11, str(i + 1))
    return c, "rolagem: direita, 1.0, 5\nesteira_vel: 2.4"


def f_pantano():
    """Pântano que Sobe (30x36): a lama sobe; suba pelas palafitas e gangorras até o elevador."""
    c = C(30, 36, floor_rows=1)
    ys = list(range(32, 6, -4))
    for i, y in enumerate(ys):
        if i % 2 == 0:
            c.plat(2, y, 8, "#"); c.plat(20, y, 8, "#"); c.plat(13, y - 2, 4, "=")
        else:
            c.plat(8, y, 14, "#")
            c.put(9, y - 1, "J") if i % 4 == 1 else None
    c.plat(10, 4, 10, "#"); c.put(14, 3, "E")
    c.put(3, 31, "1"); c.put(6, 31, "2"); c.put(22, 31, "3"); c.put(25, 31, "4")
    return c, "mare_inicio: 5\nmare_vel: 0.32\nmare_topo: 4"


ALL = {
    "obra_concreto": ("batata", "concreto", b_obra), "galerias_mina": ("batata", "mina", b_mina),
    "predio_velho": ("batata", "demolicao", b_predio), "sob_viaduto": ("batata", "viaduto", b_viaduto),
    "palafitas": ("batata", "pantano", b_pantano), "telhados": ("batata", "cidade", b_telhados),
    "canteiro_rei": ("rei", "canteiro", r_canteiro), "linha_montagem": ("rei", "fabrica", r_fabrica),
    "cais_rei": ("rei", "porto", r_porto), "mina_ouro": ("rei", "mina", r_mina),
    "serraria_rei": ("rei", "serraria", r_serraria), "predio_demolicao": ("rei", "demolicao", r_demolicao),
    "obra_subindo": ("fuga", "concreto", f_obra), "fuga_fundicao": ("fuga", "fundicao", f_fundicao),
    "viaduto_obras": ("fuga", "viaduto", f_viaduto), "ferro_velho": ("fuga", "ferro_velho", f_ferro_velho),
    "pantano_sobe": ("fuga", "pantano", f_pantano),
}

if __name__ == "__main__":
    only = sys.argv[1:]
    bad = 0
    for id_, (kind, tema, fn) in ALL.items():
        if only and id_ not in only:
            continue
        r = fn()
        c, extra = (r if isinstance(r, tuple) else (r, ""))
        hdr = f"tema: {tema}\nterremoto: 0\nalcapao_s: 3.5\n" + extra
        bad += 0 if write(id_, c, kind, hdr) else 1
    print("com problemas:", bad)
