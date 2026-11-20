---
name: controle-do-robo
description: "Movimento e sensação do robô de Bota-Abaixo: corrida, pulo variável (sustain), coyote, buffer, parede, marreta, squash/stretch e valores de data/controller.json. Use ao programar ou ajustar o controle do robô."
---

# Controle do robô

## Pulo (evite o erro clássico)
`sustain`: ao pular, `vy = -jump_speed`; **enquanto o botão está segurado e `var_jump_time` não acabou, a velocidade de subida é mantida**; soltar encerra. Depois, gravidade normal, com metade da gravidade perto do ápice se o botão estiver segurado. Com estes números, o pulo máximo fica em ~3,5 tiles. (Implementar "impulso e corte ao soltar" com os mesmos números dá um pulo 4× menor.)

## Ordem por frame
input → timers (coyote, buffer, pulo, parede, marreta) → forças de peças (esteira, ventilador) → velocidade horizontal (aceleração no chão; `air_mult` no ar) → pulo / pulo de parede → sustain → gravidade e queda máxima → mover e colidir → contatos (perigo, mola, elevador) → animação.

Pode usar `CharacterBody2D.move_and_slide()` com a velocidade calculada assim. Colisão com peças sempre considerando o jogador (P01 é one-way só para o dono).

## Sensação
- Responder no mesmo frame; animação nunca atrasa o input.
- Coyote e buffer de 0,1 s; queda mais rápida que a subida; parede com deslize lento.
- Squash ao aterrissar (1,25 × 0,8) e stretch ao pular (0,8 × 1,25), por código, sem mexer na hitbox.
- Poeira no pulo e na aterrissagem; som curto.

## Como ajustar
Mude `data/controller.json`, jogue 1 minuto com 2 jogadores e compare. Se o usuário reclamar ("pesado", "flutua"), ofereça 2–3 variações para ele escolher.
