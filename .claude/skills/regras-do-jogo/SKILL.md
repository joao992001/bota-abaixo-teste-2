---
name: regras-do-jogo
description: "Regras de Bota-Abaixo: os 4 modos (Derruba, Batata-Dinamite, Rei da Obra, Fuga), rodada e placar, golpe/marreta, dano % (Amassômetro), itens por modo e eventos, tudo lido de data/modos.json. Use ao implementar, mudar ou ajustar regras, modos, itens ou pontuação."
---

# Regras do jogo

Fluxo: Menu → Modo → Arena do modo → Ajustes → Entrada (2–4, bots) → rodadas → placar → vitória (★ para vencer).

## Onde fica
- **Números e listas:** `data/modos.json` → `demolicao` (`modos[]` com `id`, `arenas`, `itens_lista`; `itens`, `eventos`,
  `amassometro`, `aderencia`, `recuperacao`, golpe `knock_x/knock_y`, `stun_*`, `stomp_*`…). Nunca números fixos no código.
- **Código:** `game/modes/demolicao.gd` (regras dos 4 modos, rodada, placar) · `modes/ferramentas.gd` (itens) ·
  `modes/eventos.gd` (9 eventos) · `modes/arena_fx.gd` (máquinas do cenário) · `modes/bots.gd` (bots sabem cada modo) ·
  `main.gd` (estados, entrada, partida).

## Os modos
- **Derruba:** vidas 1–5 e dano %; quanto mais dano, mais longe o golpe joga. Cai fora = perde vida.
- **Batata-Dinamite:** quem está com a TNT quando o pavio acaba sai; encostar ou marretar passa a bomba. Arena sem poço.
- **Rei da Obra:** segure o capacete de ouro (`K`) por X s; golpe derruba o rei; 1,2 s de proteção após pegar.
- **Fuga:** a tela/lama persegue; cair só atrasa; pego pela tela sai; chegar ao elevador `E` vence.

## Regras de ouro
- Toda regra nova entra em `modos.json` com nome claro e entra nos **Ajustes** se o jogador precisar mudar.
- Cada modo tem os próprios itens (`itens_lista`); item de dano é da Derruba.
- Mudou regra → atualize os bots (`bots.gd`) e um teste em `game/tests/driver.gd`; rode `-- --autotest --so=<parte>`.
- Medir ritmo: `-- --stats=4 [--sub=<modo>] [--so-arenas=a,b]`.

**Spells e eventos do Derruba:** antes de criar ou mudar um, leia o manual — `docs/manuais/derruba/spell.md` e
`docs/manuais/derruba/evento.md` (passo a passo oficial, com o que foi aprovado e reprovado).
