# Decisões (uma linha cada)

- 2026-11-19 · Gênero, tema, 2–4 jogadores locais, peças com dono, Claude Code + Godot 4 — usuário.
- 2026-11-19 · Marreta (1 vez por rodada) para conter quem sai na frente — hipótese do Configurador.
- 2026-11-19 · Vermelho de perigo `#d42035` escolhido por distinguir das 4 cores de jogador também em cinza e para daltônicos — Configurador (v1).
- 2026-11-19 · **v2:** estilo muda de pixel art 32 bits para **cartoon vetorial** muito próximo das referências enviadas (BattleBlock Theater, Heave Ho, Ultimate Chicken Horse, referência de gelo/explosões) — usuário.
- 2026-11-19 · **v2:** processo simplificado (4 marcos, 3 agentes, 10 skills, sem ferramentas antecipadas) por custo e demora — usuário.
- 2026-11-19 · v2: robôs inteiros na cor do jogador + acessórios cosméticos; cada mapa com o visual de uma referência; mapa 3 vira "Cais Noturno" para casar com a referência de gelo/água — Configurador.
- 2026-11-19 · v2: resolução 1920×1080, grade de 64 px; valores de movimento multiplicados por 4 em relação à v1 — Configurador.
- 2026-11-20 · Marco 1: Canteiro com vãos de 3 tiles e pilar de 1 tile (vão 4 + pilar 2 era difícil demais para a rota sem peças) — sessão principal.
- 2026-11-20 · Marreta só é gasta quando acerta uma peça rival (errar não consome) — sessão principal; testar jogando.
- 2026-11-20 · Símbolo acompanha a cor (azul ●, verde ▲, rosa ■, amarelo ◆), não o número do jogador — sessão principal.
- 2026-11-20 · Peças sem dono na esteira de escolha aparecem em cinza neutro — sessão principal.
- 2026-11-20 · Arte do Marco 1 feita na sessão principal (artistas interrompidos), gerada por script SVG→PNG em art/src/ — sessão principal.
- 2026-11-20 · Estilo v2 após feedback: traço de mão, tinta, blocos em massa (autotile), robôs com membros finos, arte em 3–4x renderizada pelo Chromium (tools/render_svg.js) e câmera que aproxima até 1,6x na corrida — usuário + sessão principal.
- 2026-11-20 · **Estilo final = imagens do usuário** (docs/referencias/ref5_usuario_cenario.png e ref6_usuario_robos.png): papel recortado sem contorno, textura de giz, céu pastel, caixotes com X; 4 modelos de robô (Lata, TV, Baixinho, Pescoção) escolhidos na entrada; cores P1–P4 = #4f86d9 #5cc45c #f06aa8 #f2c84b; espinhos e serra sem vermelho (como na referência); sem plateia; câmera até 1,9x — usuário.
- 2026-11-20 · Animação procedural: passada pela distância, inclinação, antena-mola, piscar, pulo/queda, parede, marretada em 3 tempos com estrelas e tremor (SHAKE_ON em main.gd), robô desmonta em peças ao ser eliminado, porta do elevador abre; marreta some da mão depois de usada; área de chegada = elevador inteiro (3 tiles) — sessão principal.
