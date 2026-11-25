---
name: audio
description: "Sons e música de Bota-Abaixo com tools/sfxforge.py: lista de efeitos por evento, variações, tom por jogador e mixagem para 4 jogadores. Use ao criar ou ajustar sons ou música."
---

# Áudio

**Leia antes `docs/manuais/audio.md`: desde 2026-11-25 o som vem de PACKS APROVADOS pelo usuário (`Audio.APROVADO`,
ids `ba_*`). O sfxforge abaixo foi reprovado; use-o só se o usuário pedir. Não troque sons fora do escopo do pack.**

Efeitos: `audio/sfx/*.json` → `python tools/sfxforge.py build` (acabamento automático: filtro, sala, volume por importância).
Música: `audio/music/*.json` (motor "compositor") → `python tools/musica.py`.

1. Nada de onda quadrada/serrote crua: use triangle/sine, ruído filtrado, camadas.
2. O que toca toda hora (passo, pulo, parede, marretada no ar, menu) fica BAIXO (lista QUIET); eliminação, explosão e vitória ficam altos (LOUD).
3. Sons repetidos com 3–4 variações; intervalo mínimo em `Audio.COOLDOWN`. Voz do robô: tom pelo campo `voz` do modelo (`assets/robo/modelos.json`).
6. Som novo: copie para `game/assets/audio/` e registre em `game/assets/audio/sons.json`.
4. Música: faixas longas (~1min20) com partes e respiro; nada de loop de 15 s.
5. Sem ouvir, confira pico, "brilho" (centroide) e espectrograma antes de integrar; mande uma amostra ao usuário.
