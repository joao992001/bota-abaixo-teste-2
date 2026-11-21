"""Fuga, leva 2: fases desenhadas trecho a trecho (cada trecho com uma ideia diferente)."""
import sys
from gerar import C, write


def grid(rows, w=30):
    """Linhas internas (28 colunas) → mapa com paredes I dos lados e teto I."""
    c = C(w, len(rows) + 1, floor_rows=0)
    for y, r in enumerate(rows, start=1):
        r = r.replace(" ", "")
        assert len(r) == w - 2, (y, len(r), r)
        for x, ch in enumerate(r, start=1):
            c.put(x, y, ch)
    return c


def f_obra():
    """Obra Subindo: esteiras contra, ponte de alçapões, ventiladores, portas, plataforma móvel, trampolins."""
    rows = [
        "............................",  # 1
        "............................",  # 2
        ".............E..............",  # 3  elevador
        ".........##########.........",  # 4
        "............................",  # 5
        "............................",  # 6
        "..<<<<<<............>>>>>>..",  # 7  esteiras empurram para fora
        "............................",  # 8
        "............................",  # 9
        "...........======...........",  # 10 tábuas
        "............................",  # 11
        ".L........................L.",  # 12 alavancas (abrem a ponte)
        "####..ddaaaaaaaaaaaadd..####",  # 13 ponte de alçapões
        "............................",  # 14
        "............................",  # 15
        ".dddd.....FF....FF.....dddd.",  # 16 ventiladores sob a ponte
        "............................",  # 17
        "............................",  # 18
        "......######....######......",  # 19
        "............................",  # 20
        "............................",  # 21
        "..====................====..",  # 22
        "......U..............U......",  # 23 portas abertas...
        "......U.....J....L...U......",  # 24 ...que a alavanca fecha; J pula dois andares
        "#############..#############",  # 25
        "............................",  # 26
        "............................",  # 27
        "#####..................#####",  # 28 vão com plataforma móvel
        "............................",  # 29
        "............................",  # 30
        "...dddd..............dddd...",  # 31
        "............................",  # 32
        "............................",  # 33
        "####......>>>>..<<<<......##",  # 34 esteiras para o buraco do meio
        "............................",  # 35
        "............................",  # 36
        "..=====....######....=====..",  # 37
        "............................",  # 38
        "............................",  # 39
        "#######..............#######",  # 40
        "............................",  # 41
        "...1...2.J...........3...4..",  # 42 largada
        "############################",  # 43
        "............................",  # 44
        "^^^^^^^^^^^^^^^^^^^^^^^^^^^^",  # 45
    ]
    c = grid(rows)
    return c, "rolagem: cima, 0.6, 5\nplataformas: 7,28,3,10,0,5\nventilador_ciclo: 3,2\nalcapao_s: 4"


def f_fundicao():
    """Descida da Fundição (câmera DESCE): alçapões, caixotes para quebrar, chamas, portas, portal, esteiras."""
    rows = [
        "............................",  # 1
        "............................",  # 2
        "............................",  # 3
        "....L.1..2........3..4.L....",  # 4  largada; alavanca abre o alçapão do meio
        "..#########aaaaaa#########..",  # 5
        "............................",  # 6
        "............................",  # 7
        "............................",  # 8
        "............................",  # 9
        "###..####dddddddddd####..###",  # 10 caixotes: quebre para descer
        "............................",  # 11
        "............................",  # 12
        "............................",  # 13
        "............................",  # 14
        "#>>>>>>>>>>f....f<<<<<<<<<<#",  # 15 esteiras levam ao buraco entre chamas
        "............................",  # 16
        "............................",  # 17
        ".......U............U.......",  # 18 portas (abertas)...
        "....L..U............U..L....",  # 19 ...que a alavanca adiante fecha
        "#..#########dddd#########..#",  # 20
        "............................",  # 21
        "............................",  # 22
        "............................",  # 23
        ".Y..........................",  # 24 portal: atalho para baixo
        "#############..#############",  # 25
        "............................",  # 26
        "............................",  # 27
        "............................",  # 28
        "............................",  # 29
        "..<<<<<<<<<<<##>>>>>>>>>>>..",  # 30 esteiras levam para as pontas
        "............................",  # 31
        "............................",  # 32
        "............................",  # 33
        "..........................Y.",  # 34 saída do portal
        "##########f......f##########",  # 35
        "............................",  # 36
        "............................",  # 37
        "............................",  # 38
        "............................",  # 39
        "..dddd################dddd..",  # 40
        "............................",  # 41
        "............................",  # 42
        "............................",  # 43
        ".............E..............",  # 44 elevador
        "############################",  # 45
        "############################",  # 46
    ]
    c = grid(rows)
    return c, "rolagem: baixo, 0.7, 5\nchama_ciclo: 2.2, 0.7, 1.0\nalcapao_s: 5"


def f_viaduto():
    """Viaduto em Obras (câmera avança): plataforma móvel, porta com desvio por cima, trampolim sobre o poço,
    esteira contra, ventilador para passar o muro, parede de TNT."""
    w = 84
    c = C(w, 18, floor_rows=1, spikes=True)
    def floor(x0, x1, y=14):
        for x in range(x0, x1 + 1):
            c.put(x, y, "#"); c.put(x, y + 1, "#")
    floor(1, 10)                                   # largada
    for i, x in enumerate([2, 4, 6, 8]):
        c.put(x, 13, str(i + 1))
    c.plat(14, 10, 4, "=")                         # vão com plataforma móvel (y 13) e tábua acima
    floor(20, 33)                                  # porta aberta no chão; a alavanca adiante fecha
    c.col(27, 12, 2, "U"); c.put(31, 13, "L")
    c.plat(22, 11, 4, "#"); c.plat(29, 11, 4, "#")   # desvio por cima
    c.put(33, 13, "J")                             # trampolim por cima do poço
    c.put(37, 12, "d"); c.put(41, 12, "d")         # ou pule nos caixotes (que quebram)
    c.plat(40, 9, 7, "#")                          # pouso alto
    floor(47, 61)
    c.plat(50, 14, 8, "<")                         # esteira contra no chão...
    c.plat(50, 11, 8, "=")                         # ...ou tábuas por cima
    c.put(59, 13, "F"); c.put(60, 13, "F")         # ventilador para passar o muro
    for y in range(8, 16):
        c.put(62, y, "#"); c.put(63, y, "#")
    floor(64, 75)
    for y in (11, 12, 13):
        c.put(70, y, "T")                          # parede de TNT: pule por cima ou exploda
    floor(78, 82, 13); c.put(78, 15, "#"); c.put(80, 12, "E")
    return c, "rolagem: direita, 1.0, 5\nplataformas: 11,13,3,5,0,3\nventilador_ciclo: 2.5,1.5\nalcapao_s: 4"


def f_ferro_velho():
    """Ferro-Velho (câmera avança): montes de sucata que sobem e descem, prensas presas numa viga,
    esteiras a favor e contra, tubo de atalho, gangorra sobre o poço."""
    w = 84
    c = C(w, 18, floor_rows=1, spikes=True)
    def pile(x0, x1, top, ch="#"):
        for x in range(x0, x1 + 1):
            for y in range(top, 16):
                c.put(x, y, ch if y == top else "#")
    c.plat(1, 1, w - 2)                                                # viga do galpão (as prensas ficam presas nela)
    def press(x0, x1, xs):
        for x in xs:
            c.put(x, 2, "P")
    pile(1, 9, 13)
    for i, x in enumerate([2, 4, 6, 8]):
        c.put(x, 12, str(i + 1))
    pile(12, 19, 13, ">"); press(12, 19, [14, 17])                     # esteira a favor sob a prensa
    pile(22, 26, 10)                                                   # monte alto
    pile(28, 30, 12, "d")                                              # monte de caixotes
    pile(32, 39, 12, "<"); press(34, 37, [35])                         # esteira contra
    c.put(33, 11, "Y")                                                 # tubo: atalho até o monte seguinte
    pile(42, 45, 9)                                                    # torre de sucata
    pile(47, 48, 12, "d")
    pile(50, 57, 13); c.put(54, 12, "Y"); press(55, 58, [56])
    pile(60, 62, 11, "d")
    pile(70, 75, 13); press(70, 75, [71, 74])                          # gangorra no poço antes (cabeçalho)
    pile(77, 82, 12); c.put(80, 11, "E")
    return c, "rolagem: direita, 1.0, 5\nesteira_vel: 2.6\npistao_ciclo: 3.2\ngangorras: 66,14,6"

def f_pantano():
    """Pântano Subindo (a lama sobe): gangorras, tubo de atalho, plataforma que sobe e desce, caixotes, tábuas."""
    rows = [
        "............................",  # 1
        "............................",  # 2
        ".............E..............",  # 3  elevador
        "..........########..........",  # 4
        "............................",  # 5
        "............................",  # 6
        "...=====............=====...",  # 7  tábuas
        "............................",  # 8
        "............................",  # 9
        "...........dddddd...........",  # 10 caixotes
        "............................",  # 11
        "............................",  # 12
        ".......####........####.....",  # 13 a plataforma do meio sobe até aqui
        "............................",  # 14
        "............................",  # 15
        "............................",  # 16
        "............................",  # 17 (plataforma móvel: linhas 17 → 13)
        "............................",  # 18
        ".....................Y......",  # 19 saída do tubo
        "..######..........######....",  # 20
        "............................",  # 21
        "............................",  # 22
        "...........######...........",  # 23
        "............................",  # 24
        "............................",  # 25 gangorras (cabeçalho)
        "............................",  # 26
        "............................",  # 27
        "...Y........................",  # 28 tubo: atalho para a direita, no alto
        "..####...............####...",  # 29
        "............................",  # 30
        "..1...2..............3...4..",  # 31 largada
        "############################",  # 32
        "############################",  # 33
    ]
    c = grid(rows)
    return c, ("mare_inicio: 5\nmare_vel: 0.3\nmare_topo: 4\ngangorras: 9.5,27,5; 19.5,27,5\n"
               "plataformas: 13,17,4,0,-4,4")


ALL = {"obra_subindo": ("concreto", f_obra), "fuga_fundicao": ("fundicao", f_fundicao),
       "viaduto_obras": ("viaduto", f_viaduto), "ferro_velho": ("ferro_velho", f_ferro_velho),
       "pantano_sobe": ("pantano", f_pantano)}

if __name__ == "__main__":
    only = sys.argv[1:]
    for id_, (tema, fn) in ALL.items():
        if only and id_ not in only:
            continue
        c, extra = fn()
        write(id_, c, "fuga", f"tema: {tema}\nterremoto: 0\nalcapao_s: 3.5\n" + extra)
