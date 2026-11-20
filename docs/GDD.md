# Bota-Abaixo — GDD

## Fantasia
Pequenos robôs de demolição disputam quem chega primeiro ao elevador de uma obra caótica. Antes de cada corrida, cada um instala uma peça com a sua cor: ela **ajuda o dono e atrapalha os rivais**. A obra cresce a cada rodada até alguém vencer.

## Jogadores
2–4 locais; cada um com controle (até 2 podem dividir o teclado). Na entrada, cada jogador escolhe **cor** e **acessório** (chapéu/óculos/etc.).

## Verbos
Correr · pular (altura variável) · deslizar e pular na parede · **marretar** (1 vez por rodada; destrói uma peça rival encostada) · na construção: escolher, mover, girar e colocar a peça.

## Rodada
1. **Escolha (10 s):** esteira com `jogadores + 2` peças; o último no placar escolhe primeiro.
2. **Construção (20 s, simultânea):** cada jogador coloca a sua peça na grade; proibido perto dos spawns e do elevador.
3. **Corrida (60 s):** todos correm até o elevador; tocar perigo rival = eliminado da rodada (de forma engraçada).
4. **Placar (5 s):** soma de pontos. Vence quem chegar a 60.

## Peças com dono (`data/pieces.json`)
| ID | Peça | Dono | Rivais | Marco |
|---|---|---|---|---|
| P01 | Viga | atravessa por baixo | bloco sólido | 1 |
| P02 | Mola | lança 5 tiles | lança 3 tiles | 1 |
| P03 | Serra circular | inofensiva | elimina | 1 |
| P04 | Esteira | sempre a favor | empurra na direção marcada | 1 |
| P05 | Compensado frágil | firme | quebra após 0,5 s | 2 |
| P06 | Bate-estaca | empurra | esmaga | 2 |
| P07 | Gancho de guindaste | balança | escorrega | 2 |
| P08 | Andaime | sobe rápido | sobe devagar | 2 |
| P09 | Cone | atravessável | bloqueia | 2 |
| P10 | Bola de demolição | atravessa o dono | elimina | 2 |
| P11 | Ventilador | vento a favor | vento contra | 2 |
| P12 | Dinamite (sem dono) | explode peças num raio de 1 tile | — | 2 |

## Pontuação (`data/scoring.json`, hipótese)
Chegou +10 · primeiro +5 · rival eliminado por peça sua +3 (máx. +6) · marretada +1. Se **todos** chegam, ninguém leva os +10. Se ninguém chega por 2 rodadas, a peça que mais eliminou é demolida.

## Mapas (cada um com o visual de uma referência)
| Mapa | Jogo | Visual |
|---|---|---|
| **Canteiro** | horizontal, ensina o loop | BattleBlock Theater: céu turquesa, blocos gordinhos laranja e magenta, plateia de operários em silhueta |
| **Andaimes** | vertical, pulo de parede | Heave Ho: céu pastel, nuvens fofas, montanhas nevadas, pilares pintados, espinhos cinza |
| **Cais Noturno** | duas rotas que se cruzam | referência 2: noite com aurora, blocos de vidro/gelo com aro branco, água refletindo, explosões cartoon |

## Fora de escopo
Online, campanha solo, bots jogáveis, desbloqueios, editor de mapas, mais de 4 jogadores.

## Hipóteses para testar jogando
Peças com dono deixam a construção mais estratégica (teste com e sem dono) · a marreta ajuda quem está atrás · partida de 8–12 min com meta de 60 pontos.

## Mudança de rumo (2026-11-20): Modo Festa
Playtest do usuário: colocar armadilhas e correr ficou confuso e curto. Novo núcleo: **Modo Festa**, rodadas curtas
com desafios diferentes na mesma obra, mesmos robôs e marreta; pontos (⭐) acumulam até a meta.
1. **Demolição** (protótipo jogável): caixotes sobre espinhos; marreta quebra caixote (2 golpes) e empurra robô;
   pular na cabeça atordoa; caixote racha se alguém fica parado; terremoto aos 25 s; último em pé ganha ⭐; 5 ⭐ vence.
2. Rei da Obra · 3. Corrida Sabotada · 4. Torre Maluca — depois que a Demolição for aprovada jogando.
O modo antigo (peças com dono) continua acessível com F7 na entrada, para comparar. Números em `data/modos.json`.
