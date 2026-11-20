---
name: godot
description: "Projeto Godot 4 de Bota-Abaixo: configuração 1920x1080, estrutura de cenas, carregar mapas .lvl, importar arte SVG, animação cut-out dos robôs com AnimationPlayer e debug. Use ao criar o projeto, importar arte ou montar animações."
---

# Godot

## Configuração
- Janela 1920×1080; `stretch/mode = canvas_items`, `aspect = keep`; 60 ticks de física.
- Câmera fixa mostrando a arena 1920×1024 + faixa de placar de 56 px no topo.
- Autoloads: `PlayerInput`, `Round`, `Scoring`, `Audio`.

## Estrutura sugerida
`game/player/` (robô, controle, animação) · `game/pieces/` (base + uma por peça) · `game/level/` (carregador de .lvl, arena) · `game/ui/` (entrada, esteira, cursores, placar, vitória) · `game/assets/` (arte e sons importados).

## Mapas
`level_loader.gd` lê `../levels/<id>.lvl`, cria colisões por tile e aplica o tema visual (blocos do mapa). Não monte mapas à mão no editor.

## Arte
- SVG importa direto como textura; ajuste a escala de import para a nitidez certa a 1080p.
- **Robô cut-out:** partes separadas (corpo, olhos, pupilas, boca, braços, mãos, pés, marreta, acessório) como `Sprite2D` filhos de um esqueleto simples; `AnimationPlayer` com idle, corrida, pulo, queda, aterrissagem, parede, marretada, eliminação, vitória. Cor do jogador por `modulate` no corpo ou por versões coloridas do SVG.
- Acessório: nó filho do ponto da cabeça; acompanha o squash/stretch.

## Debug (tecla F1)
Pular rodada, colocar qualquer peça como qualquer jogador, mostrar hitboxes, câmera lenta.

## Testar
Rode o projeto e jogue. Sem tela disponível: `godot --headless --path game --quit` só confere se abre sem erros; diga isso claramente.
