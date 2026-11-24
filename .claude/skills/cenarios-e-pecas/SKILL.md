---
name: cenarios-e-pecas
description: "Cenários e efeitos de Bota-Abaixo em papel e giz: 12 temas de arena (blocos, tábuas, fundo animado), máquinas do cenário (ventilador, chama, pistão, alçapão, esteira, serra…), ícones de itens e efeitos (poeira, explosão, faísca). Use para qualquer arte de cenário, máquina, item ou efeito."
---

# Cenários, máquinas, itens e efeitos

## Onde fica
- **Temas** (12; `tema:` no `.lvl`): `art/src/cenarios/temas.py` + `temas_obra.py`, `temas_metal.py`, `temas_natureza.py` →
  `game/assets/temas/<tema>/` (blocos, tábuas, fundo). Fundo animado: `game/level/background.gd`.
- **Peças do cenário/máquinas:** `art/src/cenarios/canteiro.py` e `arenas.py` → `game/assets/cenario/`; comportamento em
  `game/modes/arena_fx.gd`; caracteres do mapa em `levels/README.md`.
- **Itens (ícones e ferramentas na mão):** `art/src/efeitos/itens.py` → `game/assets/itens/`.
- **Prévias das arenas no menu:** `game/assets/ui/arena_<id>.png` (capturadas do jogo com `-- --arenas=DIR`).

## Regras
- Blocos em módulos de 64 px que encaixam sem emenda (teste um bloco 6×3 e um "L").
- Fundo em camadas, mais claro e menos saturado que o jogável.
- Máquina perigosa sempre avisa antes (pisca, faísca, som) e usa o vermelho de perigo; o resto nunca usa esse vermelho.
- Efeitos: poeira arredondada, estrelinhas, explosão cartoon amarela/laranja com fumaça escura. Animados por código na Godot.

## Checagem
Captura dentro do jogo com 4 robôs (`-- --espiar=DIR,arena,modo,segundos` ou `--arenas=DIR`): perigo óbvio? jogável salta do fundo?
