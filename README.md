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

## Rodar (Marco 1)
- Jogar: `godot --path game` (Godot 4.7.1). **Teclado A:** WASD, Espaço pula, F golpe rápido, R marretada pesada, Shift esq. (ou C) esquiva, G item · **Teclado B:** setas, Ctrl dir. pula, ponto (.) golpe rápido, barra (/) pesada, 0 do numérico (ou O) esquiva, vírgula item · **Controle** (Xbox, PlayStation, Nintendo, genérico; USB ou Bluetooth): A/✕ pula, X/□ golpe rápido, Y/△ marretada pesada, RB/RT esquiva, LB/LT item, B/○ volta, Start pausa. Tudo remapeável em OPÇÕES ▸ CONFIGURAR CONTROLE. Na entrada, Y/△ adiciona bot.
- LABORATÓRIO (menu principal): sala de medição para calibrar o combate. Régua no chão, degraus de 1 a 4 tiles, tábuas a 4 e 6 tiles; medidores ao vivo (estado, linha do tempo do golpe em quadros, esquiva, arremesso, altura/distância do pulo e do arremesso); bonecos que ficam parados, andam, pulam, dão golpe rápido, marretada ou esquivam, com dano fixo; velocidade 1×/½×/¼×. START/Tab abre o painel com 32 números ajustáveis ao vivo; SALVAR grava em `user://laboratorio.json` (vale no jogo todo), COPIAR põe os valores na área de transferência, PADRÃO volta aos arquivos.
- OFICINA (menu principal): ambiente de testes com todas as máquinas, respawn infinito; START/Tab abre o painel (dar item, soltar item, evento agora, trocar/recarregar arena, boneco de treino, bot, invencível, zerar dano, câmera lenta, hitbox). Outro controle entra apertando PULAR.
- Demolição: JOGAR → DEMOLIÇÃO → submodo (Último em Pé, Vidas, Placar, Batata-Dinamite) → arena (11 + sorteio) → AJUSTES (★ para vencer, frequência e escolha de eventos, itens, ajuda para quem perde) → entrada.
- Gerar o jogo para Windows (sem Godot): use a MESMA versão da Godot do editor (4.7.1; a partir da 4.5 os controles usam SDL3 e o DualShock/DualSense funciona — exportado na 4.3 o controle não respondia). No Linux: `GODOT=/caminho/godot-4.7.1 tools/exportar.sh`; no Windows: `exportar_windows.bat`. Saída: `tools/exportar.sh` → `out/Instalar-Bota-Abaixo.exe` (instalador) e `out/build/windows/Bota-Abaixo.exe` (arquivo único). Precisa dos modelos de exportação da Godot 4.3 e do makensis. O mesmo build em Linux roda a bateria de testes: `out/build/linux/Bota-Abaixo.x86_64 --headless --fixed-fps 60 -- --autotest`.
- Teste automático: `godot --headless --path game --fixed-fps 60 -- --autotest` (só uma parte: `-- --autotest --so=maquinas,itens_novos,eventos`)
- Medir ritmo com bots: `godot --headless --path game --fixed-fps 60 -- --stats=4 [--sub=vidas] [--so-arenas=torre,ponte]` (grava `user://stats.json`)
- Regerar arte: `python3 art/src/robos/robos.py && python3 art/src/cenarios/canteiro.py && python3 art/src/cenarios/arenas.py && python3 art/src/efeitos/itens.py && cp -r art/out/game/* game/assets/` (usa Node + Playwright/Chromium)
- Sons e música: edite `audio/sfx/*.json` e `audio/music/*.json`, depois `python3 tools/sfxforge.py build && cp out/audio/sfx/*.wav game/assets/audio/sfx/ && cp out/audio/music/*.wav game/assets/audio/music/` (sons novos: atualize `game/assets/audio/sons.json`).
