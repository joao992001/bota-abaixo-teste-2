---
name: controle-do-robo
description: "Movimento e sensação do robô de Bota-Abaixo: corrida, pulo variável (sustain), pulo duplo, coyote, buffer, parede e borda com aderência, golpe/marreta, pisão, squash/stretch e valores de data/controller.json e data/modos.json. Use ao programar ou ajustar movimento, combate ou animação do robô."
---

# Controle do robô

Código: `game/player/robot.gd` (física) e `game/player/robot_visual.gd` (animação). Números: `data/controller.json` (corrida,
pulo, gravidade, parede, marreta, hitbox 48×72) e `data/modos.json` → `demolicao` (golpe `knock_*`, `stun_*`, pisão `stomp_*`,
`aderencia`, `amassometro`, `recuperacao`).

## Pulo (evite o erro clássico)
`sustain`: ao pular, `vy = -jump_speed`; **enquanto segura e `var_jump_time` não acabou, a subida é mantida**; soltar encerra.
Depois gravidade normal, metade perto do ápice se segurar. ("Impulso e corte ao soltar" com os mesmos números dá pulo 4× menor.)
Pulo duplo: `air_jumps` (recarrega no chão, parede e borda). Coyote e buffer em `controller.json`.

## Sensação
- Responder no mesmo quadro; animação nunca atrasa o input; hitbox nunca muda com a animação.
- Squash ao aterrissar, stretch ao pular, poeira e som curto.
- Parede e borda: aderência limitada com medidor acima da cabeça.

## Como ajustar
Mude os JSON, jogue 1 minuto com 2 jogadores (ou use a OFICINA: câmera lenta, hitbox) e compare. Se o usuário reclamar
("pesado", "flutua"), ofereça 2–3 variações. Testes de parede/controle: `-- --autotest --so=parede,controle_real`.
