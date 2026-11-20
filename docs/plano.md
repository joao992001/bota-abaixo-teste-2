# Plano — 4 marcos

Cada marco termina com o jogo rodando e uma parada para você jogar. Relatório de até 15 linhas.

## Marco 1 — Jogável + prancha de estilo
**Sessão principal (código):**
- Projeto Godot 1920×1080, 60 ticks; entrada de 2–4 jogadores (controle e teclado dividido).
- Robô controlável (`data/controller.json`), pulo variável, parede, marreta.
- Mapa **Canteiro** em `levels/canteiro.lvl`, carregado pela Godot.
- Peças **P01–P04** com comportamento de dono e rival.
- Rodada completa: escolha → construção → corrida → placar → vitória. Formas simples coloridas até a arte chegar.
- Teclas de debug: pular de rodada, colocar qualquer peça como qualquer jogador.

**Em paralelo (subagentes):**
- `artista-personagens`: robô base nas 4 cores, 5 expressões, 3 acessórios, partes para cut-out.
- `artista-cenarios`: kit de blocos do Canteiro, fundo, serra e mola com estados dono/rival, poeira.
- Ambos entregam a **prancha de estilo**: uma tela 1920×1080 do Canteiro com 4 robôs e 3 peças + comparações com as referências.

**Fim:** arte da prancha aplicada no jogo. `revisor` faz uma passada rápida. **Você joga e aprova o estilo.**

## Marco 2 — Arte de verdade no jogo + todas as peças
- Robôs cut-out animados com expressões; seleção de cor e acessório na entrada.
- Peças P05–P12, marreta completa, regras de pontuação.
- Todas as 12 peças desenhadas, com estado dono/rival.
- **Você joga com amigos** (skill `playtest`).

## Marco 3 — Mapas Andaimes e Cais Noturno + efeitos e som
- 2 mapas com o visual de suas referências.
- Explosões, poeira, "+pontos", confete, tremor desligável.
- Sons e música curta (`tools/sfxforge.py`).
- 8 acessórios.
- **Você joga.**

## Marco 4 — Polimento
Ajustes pelos playtests: números de peças e pontuação, legibilidade, menus, opções (volume, tremor), build exportado.
