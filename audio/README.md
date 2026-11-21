Sons e música por síntese (sem samples, sem IA). Precisa de numpy e scipy (só para gerar).
- Efeitos: `python tools/sfxforge.py build` → `game/assets/audio/sfx/*.wav` + `sons.json`. Cada JSON em `audio/sfx/`
  descreve um som; o build aplica o acabamento (tira o chiado agudo, sala leve, volume por importância:
  listas QUIET/SOFT/LOUD no topo de `tools/sfxforge.py`).
- Músicas: `python tools/musica.py [nome]` → `game/assets/audio/music/*.wav` (estéreo 32 kHz, ~1min20, loop sem emenda).
  Cada JSON em `audio/music/` dá tom, escala, andamento, partes (A/B/C) e instrumentos; o compositor escreve as notas.
- No jogo os WAV são comprimidos em QOA (project.godot → importer_defaults).
