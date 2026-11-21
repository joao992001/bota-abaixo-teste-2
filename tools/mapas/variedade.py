"""Batata e Rei, leva 2: cada fase com UMA interação principal própria (antes todas repetiam portas+tubos+trampolim).
Ritmo vertical: degraus de 3 linhas (o pulo alcança ~3,9); trampolim J = 6 linhas. Uso: python3 variedade.py [ids]"""
import sys
from gerar import C, write, spawns, W, H, GROUND


# ------------------------------------------------------------------ BATATA-DINAMITE
def b_obra():
    """Obra de Concreto: PORTAS QUE TROCAM. Metade começa aberta, metade fechada; as alavancas invertem todas.
    Alavancas: uma em cada ponta do térreo e uma na casa de máquinas do topo."""
    c = C(W, H)
    c.plat(3, 15, 19); c.clear(6, 15, 3, 1)                            # 2º andar, buraco
    c.box(6, 18, 2, 3, "d")                                            # pilha de caixotes sob o buraco
    c.plat(8, 9, 14); c.clear(12, 9, 3, 1)                             # 3º andar
    c.col(12, 13, 2, "d"); c.col(13, 12, 3, "d")                       # degraus de caixote
    c.plat(17, 6, 5); c.col(17, 7, 2)                                  # casa de máquinas no topo
    c.col(12, 16, 3); c.col(12, 19, 2, "D")                            # paredes com porta
    c.col(21, 16, 3); c.col(21, 19, 2, "U")
    c.col(17, 10, 3); c.col(17, 13, 2, "D")
    c.put(2, 20, "L")
    c.mirror()
    c.col(31, 19, 2, "U"); c.col(26, 13, 2, "U")                        # do outro lado começam abertas
    c.put(21, 5, "L")                                                  # alavanca em cima da casa de máquinas
    spawns(c, [9, 16, 27, 34])
    return c


def b_mina():
    """Galerias da Mina: TÚNEIS NA ROCHA ligados por poços e por TUBOS cruzados; trilhos no túnel do meio."""
    c = C(W, H)
    c.box(1, 5, 42, 16, "#")
    c.clear(1, 18, 42, 3)                                              # túnel do chão (piso 21)
    c.clear(1, 12, 42, 3)                                              # túnel do meio (piso 15)
    c.clear(3, 6, 38, 3)                                               # túnel de cima (piso 9)
    c.clear(5, 15, 3, 3); c.plat(5, 18, 3, "=")                        # poço chão → meio (tábua dentro do poço)
    c.clear(14, 9, 3, 3); c.plat(14, 12, 3, "=")                       # poço meio → cima
    c.clear(8, 5, 3, 1); c.plat(8, 6, 3, "=")                          # saída para o alto da rocha
    c.plat(9, 15, 5, ">")                                              # trilho
    c.plat(16, 4, 3, "d"); c.put(19, 4, "T")                           # carga no alto da rocha
    c.mirror()
    c.put(2, 20, "Y"); c.put(40, 8, "Y")                               # tubos nas pontas dos túneis
    c.put(41, 20, "Z"); c.put(3, 8, "Z")
    spawns(c, [10, 17, 26, 33])
    return c


def b_predio():
    """Prédio Velho: volta completa para correr (escadas nas pontas, buracos no 3º andar);
    ALÇAPÃO no meio do 2º andar com a alavanca no 3º, de onde se vê quem está em cima dele."""
    c = C(W, H)
    c.box(1, 18, 3, 3)                                                 # escada: chão → 2º andar
    c.plat(4, 15, 18); c.plat(18, 15, 4, "a")                          # 2º andar, alçapão no meio
    c.box(4, 12, 2, 3)                                                 # escada: 2º → 3º andar
    c.plat(7, 9, 15); c.clear(13, 9, 2, 1)                             # 3º andar com buraco para descer
    c.put(17, 8, "L")                                                  # alavanca de olho no alçapão
    c.mirror()
    spawns(c, [8, 16, 27, 35])
    return c

def b_viaduto():
    """Sob o Viaduto: PLATAFORMAS QUE VÃO E VOLTAM entre os pilares e VENTILADOR que leva à pista.
    Saliências presas nos pilares (nada pendurado)."""
    c = C(W, H)
    c.plat(1, 6, 21); c.clear(10, 6, 4, 1); c.clear(20, 6, 2, 1)       # pista do viaduto com vãos
    c.col(7, 7, 11); c.col(18, 7, 11)                                  # pilares em arco (passa por baixo)
    c.put(12, GROUND - 1, "F")                                         # ventilador sob o vão
    c.plat(1, 18, 2); c.plat(5, 15, 2); c.plat(1, 12, 2)               # saliências: parede ↔ pilar
    c.plat(16, 18, 2); c.plat(8, 12, 2)
    c.plat(19, 18, 2); c.plat(21, 15, 1); c.plat(19, 12, 2); c.plat(21, 9, 1)   # escada do meio
    c.mirror()
    spawns(c, [4, 14, 29, 39])
    return c, "plataformas: 8,15,3,5,0,4; 32,15,3,-5,0,4\nventilador_ciclo: 3, 2\nventilador_alcance: 14"


def b_pantano():
    """Palafitas: casas sobre estacas ligadas por PONTES de tábua (caminho contínuo, ▼ desce);
    TRAMPOLINS na lama levam às pontes; plataforma que vai e volta liga os telhados."""
    c = C(W, H)
    for x0 in (4, 18):
        c.plat(x0, 15, 8)                                              # piso da casa
        c.col(x0, 16, 3); c.col(x0 + 7, 16, 3)                         # estacas (passa por baixo)
        c.col(x0, 11, 2); c.col(x0 + 7, 11, 2)                         # paredes (porta aberta embaixo)
        c.plat(x0, 10, 8)                                              # telhado
    c.plat(12, 15, 6, "=")                                             # ponte entre as casas
    c.box(1, 18, 3, 3, "d")                                            # caixotes para subir
    c.put(14, GROUND - 1, "J")                                         # trampolim sob a ponte
    c.mirror()
    spawns(c, [8, 16, 27, 35])
    return c, "plataformas: 12,7,3,17,0,7"

def b_telhados():
    """Telhados: TRAMPOLINS nos becos levam de telhado em telhado; ventilador no prédio alto; caixa-d'água."""
    c = C(W, H)
    c.box(1, 16, 9, 5); c.box(13, 12, 7, 9); c.box(24, 14, 8, 7); c.box(35, 11, 8, 10)
    c.box(3, 13, 4, 3); c.clear(4, 14, 2, 2); c.clear(6, 14, 1, 2)    # casinha de máquina (aberta)
    c.box(37, 8, 4, 3); c.clear(38, 9, 2, 2); c.clear(37, 9, 1, 2)
    c.box(27, 11, 3, 3)                                                # caixa-d'água
    c.put(11, GROUND - 1, "J"); c.put(22, GROUND - 1, "J"); c.put(33, GROUND - 1, "J"); c.put(9, 15, "J")
    c.put(16, 11, "F")
    c.put(8, 15, "1"); c.put(18, 11, "2"); c.put(25, 13, "3"); c.put(36, 10, "4")
    return c, "ventilador_ciclo: 3, 2\nventilador_alcance: 6"


def r_canteiro():
    """Trono do Canteiro: PORTAS na base da torre (a alavanca abre a escada de dentro); por fora, a subida longa."""
    c = C(W, H)
    c.col(18, 7, 11, "o"); c.put(18, 6, "o")                           # torre de andaime
    c.col(18, 18, 3, "D")                                              # porta da torre
    for y in (18, 15, 12, 9):
        c.plat(19, y, 3, "=")
    c.plat(19, 6, 3, "="); c.put(21, 6, "#")                           # topo: tábuas dos lados, trono no sólido
    c.put(15, 20, "L")
    c.plat(3, 18, 4, "="); c.plat(8, 15, 5, "d"); c.plat(4, 12, 5); c.plat(11, 9, 5)   # subida por fora
    c.mirror()
    c.put(21, 5, "K")
    spawns(c, [5, 11, 32, 38])
    return c


def r_fabrica():
    """Linha de Montagem: ESTEIRAS levam ao VENTILADOR que sopra até o trono; PRENSAS no caminho de cima."""
    c = C(W, H)
    c.plat(4, 18, 9, ">")
    c.plat(14, 15, 4); c.put(17, 14, "F")
    c.plat(7, 12, 5); c.plat(12, 9, 4)
    c.plat(18, 6, 4)
    c.plat(1, 1, 21); c.put(9, 2, "P"); c.put(13, 2, "P")               # viga do teto com as prensas
    c.mirror()
    c.put(21, 5, "K")
    spawns(c, [6, 14, 29, 37])
    return c, ("ventilador_ciclo: 4, 1.5\nventilador_alcance: 9\nesteira_vel: 2.6\nesteira_inverte: 8\n"
               "pistao_ciclo: 3.5")


def r_porto():
    """Rei do Cais: GUINDASTES — elevador e plataforma que vai e volta levam ao trono; ou suba pelos contêineres."""
    c = C(W, H)
    c.box(2, 18, 6, 3, "d"); c.box(10, 18, 2, 3, "d")                  # contêineres
    c.box(13, 15, 5, 6, "d"); c.box(15, 12, 3, 3, "d")
    c.plat(16, 9, 3)                                                   # braço do guindaste
    c.plat(19, 6, 3)                                                   # cabine com o trono
    c.mirror()
    c.put(21, 5, "K")
    c.put(4, 17, "1"); c.put(10, 17, "2"); c.put(33, 17, "3"); c.put(39, 17, "4")
    return c, "plataformas: 9,15,3,0,-9,6; 32,15,3,0,-9,6; 12,6,3,4,0,5; 29,6,3,-4,0,5"


def r_mina():
    """Mina de Ouro: ELEVADOR central até o trono; TUBOS cruzam a caverna; galerias na rocha dos lados."""
    c = C(W, H)
    c.box(1, 12, 13, 2); c.box(1, 6, 10, 2); c.put(10, 8, "#")         # rocha com galeria
    c.plat(14, 18, 4, "="); c.plat(14, 15, 3, "=")
    c.plat(12, 9, 3, "="); c.plat(13, 5, 3, "=")
    c.plat(18, 4, 4, "="); c.put(21, 4, "#")
    c.mirror()
    c.put(21, 3, "K")
    c.put(2, 20, "Y"); c.put(40, 5, "Y"); c.put(41, 20, "Z"); c.put(3, 5, "Z")
    spawns(c, [9, 16, 27, 34])
    return c, "plataformas: 20.5,18,3,0,-10,7"


def r_serraria():
    """Serraria Real: PIRÂMIDE DE TORAS com o trono no alto; GANGORRAS no chão e trampolins dos lados."""
    c = C(W, H)
    c.box(14, 18, 8, 3); c.box(17, 15, 5, 3); c.box(19, 12, 3, 3); c.box(20, 9, 2, 3)   # pirâmide em degraus
    c.plat(14, 18, 3, "d"); c.plat(17, 15, 2, "d")                     # toras soltas na beirada
    c.box(1, 18, 4, 3, "d")                                            # pilha de toras do lado
    c.put(12, GROUND - 1, "J")
    c.mirror()
    c.put(21, 8, "K")
    c.put(2, 17, "1"); c.put(10, GROUND - 1, "2"); c.put(33, GROUND - 1, "3"); c.put(41, 17, "4")
    return c, "gangorras: 8.5,19,6; 34.5,19,6"


def r_demolicao():
    """Prédio em Demolição: esqueleto do prédio com colunas; a BOLA varre o 3º andar e o trono;
    ALÇAPÕES no meio do 2º andar (alavancas nas pontas); entulho de caixote para subir."""
    c = C(W, H)
    c.box(2, 18, 4, 3, "d")                                            # entulho
    c.plat(8, 15, 14); c.plat(19, 15, 3, "a")                          # 2º andar, alçapão no meio
    c.col(8, 16, 3); c.col(14, 16, 3)                                  # vigas (passa por baixo)
    c.box(10, 12, 2, 3, "d")                                           # entulho no 2º andar
    c.plat(12, 9, 10); c.clear(15, 9, 2, 1)                            # 3º andar, buraco
    c.col(12, 10, 2)
    c.plat(19, 6, 3); c.col(21, 7, 2)                                  # trono num pilar
    c.put(9, 14, "L")
    c.mirror()
    c.put(21, 5, "K")
    spawns(c, [7, 11, 32, 36])
    return c, "bola: 21.5,0,8,60,4.4"


def d_gangorras():
    """Gangorras (Derruba, serraria): pilhas de toras firmes saindo do poço; gangorras sobre estacas."""
    c = C(30, 16, floor_rows=0)
    for x in range(30):
        c.put(x, 15, "^")
    c.box(1, 9, 4, 6)                                                  # cais da esquerda
    c.col(8, 8, 7)                                                     # estaca da gangorra
    c.box(12, 10, 3, 5); c.plat(13, 9, 2, "d"); c.put(14, 8, "d")      # pilha do meio (metade)
    c.put(14, 7, "#")                                                  # apoio da gangorra do alto
    c.mirror()
    c.put(2, 8, "1"); c.put(12, 9, "2"); c.put(17, 9, "3"); c.put(27, 8, "4")
    return c, "gangorras: 8,7,6; 14.5,6,7; 21,7,6\nterremoto: 70"


ALL = {
    "gangorras": ("derruba", "serraria", d_gangorras),
    "obra_concreto": ("batata", "concreto", b_obra), "galerias_mina": ("batata", "mina", b_mina),
    "predio_velho": ("batata", "demolicao", b_predio), "sob_viaduto": ("batata", "viaduto", b_viaduto),
    "palafitas": ("batata", "pantano", b_pantano), "telhados": ("batata", "cidade", b_telhados),
    "canteiro_rei": ("rei", "canteiro", r_canteiro), "linha_montagem": ("rei", "fabrica", r_fabrica),
    "cais_rei": ("rei", "porto", r_porto), "mina_ouro": ("rei", "mina", r_mina),
    "serraria_rei": ("rei", "serraria", r_serraria), "predio_demolicao": ("rei", "demolicao", r_demolicao),
}

if __name__ == "__main__":
    only = sys.argv[1:]
    for id_, (kind, tema, fn) in ALL.items():
        if only and id_ not in only:
            continue
        r = fn()
        c, extra = (r if isinstance(r, tuple) else (r, ""))
        base = "" if "terremoto" in extra else "terremoto: 0\n"
        write(id_, c, kind, f"tema: {tema}\n{base}alcapao_s: 3.5\n" + extra)
