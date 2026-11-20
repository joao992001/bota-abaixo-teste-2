---
name: audio
description: "Sons e música de Bota-Abaixo com tools/sfxforge.py: lista de efeitos por evento, variações, tom por jogador e mixagem para 4 jogadores. Use ao criar ou ajustar sons ou música."
---

# Áudio

Lista: passo, pulo, aterrissagem, parede, marretada, peça destruída, eliminação (sucata), mola, serra, esteira, bate-estaca, compensado, gancho, ventilador, dinamite (explosão), colocar peça, cursor, contagem 3-2-1, chegada, placar, vitória, música curta de obra.

1. `python tools/sfxforge.py new <modelo> <nome> --seed N` e ajuste; `python tools/sfxforge.py build`.
2. Sons repetidos com variações e leve variação de tom.
3. Tom por jogador nos sons do robô (P1 mais grave → P4 mais agudo).
4. Prioridade: eliminação e chegada sempre audíveis; música baixa.
5. Ouça (ou confira pico e duração lendo o WAV) antes de integrar.
