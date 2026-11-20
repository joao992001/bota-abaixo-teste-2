---
name: estilo-visual
description: "Direção de arte de Bota-Abaixo: cartoon vetorial muito próximo das referências em docs/referencias/ (BattleBlock Theater, Heave Ho, Ultimate Chicken Horse e a referência de gelo/explosões), com contorno grosso, formas gordinhas, cores por mapa e comparação lado a lado. Use antes de criar ou revisar qualquer arte."
---

# Estilo visual

1. **Olhe as referências** (`docs/referencias/`) antes de desenhar. Leia `docs/estilo_visual.md`: lá está o que pegar de cada uma e onde usar.
2. **Regras que mais fazem diferença:** contorno escuro grosso (6 px em personagens, 5 px em blocos) · formas arredondadas e gordinhas · sombra de 1 tom + brilho branco chapado · primeiro plano saturado e fundo claro/dessaturado · blocos com bisel (topo claro, lateral escura).
3. **Comparação obrigatória:** para cada entrega, gere `art/out/comparacao_<item>.png` (referência à esquerda, nosso à direita, mesma altura) e escreva 3–5 diferenças de traço, forma, cor e efeito. Corrija e repita até 3 vezes.
4. **Em contexto:** teste numa tela 1920×1080 do mapa com 4 robôs e peças. Pergunte: o jogável salta do fundo? O perigo é óbvio? Dá para saber de quem é cada peça?
5. **Estilo sim, cópia não:** nada de personagens, emblemas, logotipos ou cenários exatos das referências.

## Como gerar e ver
SVG em `art/src/` (à mão ou por script Python). Para ver: `rsvg-convert`, Inkscape ou `cairosvg`, se existirem; senão, desenhe também com Pillow em 4× e reduza. Sempre **abra a imagem**.
