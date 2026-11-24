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

## Golpes, esquiva e arremesso (2026-11-24)
- `atk` = "rapido"/"pesado" com fases preparo → ativo → recuperação; o impacto (`main.try_attack` → `demo.attack`) acontece
  **no fim do preparo**, sincronizado com a animação. Só a pesada quebra caixote/chão/barril; as duas passam TNT e derrubam o rei.
- Pesada: recarga própria (`heavy_cd`); cancelável no preparo pela esquiva do próprio jogador (finta) ou por golpe do rival
  (INTERROMPIDO!), pagando `recarga_cancelada` × recarga. O golpe rápido nunca espera a recarga da pesada.
- Esquiva: `dodge_t`, `guard_t` (protege só de golpe/pisão de robô; nunca de cenário), `air_dodge` (1 por período no ar, volta só
  ao pousar). Não atravessa geometria (usa `move_and_slide`).
- Arremesso: `stun_t` = sem controle (curto, cresce com o dano); depois `recover_t` devolve o controle aos poucos; `hitstop`
  congela atacante e atingido por alguns centésimos.

## Sensação
- Responder no mesmo quadro; animação nunca atrasa o input; hitbox nunca muda com a animação.
- Squash ao aterrissar, stretch ao pular, poeira e som curto.
- Parede e borda: aderência limitada com medidor acima da cabeça.

## Como ajustar
Mude os JSON, jogue 1 minuto com 2 jogadores (ou use o LABORATÓRIO: câmera lenta, hitbox, números ao vivo) e compare. Se o usuário reclamar
("pesado", "flutua"), ofereça 2–3 variações. Testes de parede/controle: `-- --autotest --so=parede,controle_real`.
