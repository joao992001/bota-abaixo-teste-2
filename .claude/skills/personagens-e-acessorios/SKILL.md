---
name: personagens-e-acessorios
description: "Robôs de Bota-Abaixo em papel e giz: os 8 modelos (só aparência), corpo na cor do jogador, rostos e expressões, marreta, partes para a animação por código. Use ao criar ou ajustar robôs ou expressões."
---

# Personagens (8 modelos de robô)

Não há personalização (Garagem, chapéus, padrões e ferramentas foram removidos em 2026-11-23). Cada jogador escolhe **um dos 8 modelos**
na entrada (▲▼); o corpo sai na **cor do jogador**. O modelo é **só aparência**: hitbox 48×72 e todos os números de jogo são iguais.

| Modelo | Silhueta | Jeito |
|---|---|---|
| Lata | cilindro médio | boca com língua |
| TV | cabeça de tela | rosto verde na tela |
| Baixinho | cabeça redonda grande, corpo curto | boca em "o", voz fina |
| Pescoção | cabeça numa mola | sorriso de lado, voz grave |
| Brutamontes | tronco largo em trapézio, cabeça pequena, braços grossos, mãos grandes | dentes cerrados, voz bem grave |
| Varapau | muito alto e fino, membros finos | cabeça pequena lá no alto |
| Barril | barril gordo com cintas, pernas curtas | torneirinha do lado |
| Bolha | cúpula de vidro sobre base em trapézio, núcleo que brilha | voz aguda |

## Onde mexer
- Arte: `art/src/robos/robos.py` (tabela `MODELS` + `body_svg`/`face_svg`/`antenna_svg`). Rodar `python3 art/src/robos/robos.py && cp art/out/game/robo/* game/assets/robo/`.
- A tabela vira `art/out/game/robo/modelos.json`, lido pela Godot: quadris, ombros, mãos, `top` (setinha P1), `limb_w` (grossura dos membros),
  `hand_s` (tamanho da luva), `hat` (onde o capacete do Rei da Obra assenta), `voz` (tom) e `danca` (comemoração).
- Montagem/animação: `game/player/robot_visual.gd` (braços e pernas desenhados por código). Tela das partes 128×128, pés em (64,120).

## Expressões
normal · piscar · esforço · susto · vitória · eliminado (olhos em X).

## Checagem
`godot --path game -- --robos=DIR` gera a prancha dos 8 (parado, comemoração, rostos). Os 8 lado a lado: dá para distinguir pela silhueta em 1 s?
