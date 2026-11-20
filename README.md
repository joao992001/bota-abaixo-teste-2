# Bota-Abaixo — pacote enxuto (v2)

Jogo de plataforma **competitivo, multiplayer local (2–4)**: robôs de demolição montam a obra uns dos outros com **peças que têm dono** (ajudam quem colocou, atrapalham os rivais) e depois correm até o elevador.

**v2 = jogável cedo + visual em primeiro lugar.** Estilo cartoon vetorial muito próximo das referências em `docs/referencias/` (BattleBlock Theater, Heave Ho, Ultimate Chicken Horse e a referência de gelo/explosões), com personagens e acessórios próprios.

## Como usar
1. Descompacte, entre na pasta e rode `git init && git add -A && git commit -m "inicio"`.
2. Abra o Claude Code na pasta e cole `PROMPT_INICIAL.md`.
3. A IA para em 4 marcos para você jogar e aprovar (`docs/plano.md`).

## Requisitos
Godot 4 estável, Python 3 com Pillow. Ajudam, se houver: `rsvg-convert`, Inkscape ou `cairosvg` (para ver os SVG como imagem). 2–4 controles para testar.

## O que mudou da v1
- Primeiro marco já é **jogável** (1 mapa, 4 peças, rodada completa) **e** traz a prancha de estilo final.
- 3 agentes (eram 13); 10 skills curtas (eram 30); sem schemas, contratos JSON, gates formais nem ferramentas construídas antes do jogo.
- Pixel art 32 bits → **cartoon vetorial** com contorno grosso, como nas referências. Personagens com **acessórios**.
