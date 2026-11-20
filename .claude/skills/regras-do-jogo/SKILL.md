---
name: regras-do-jogo
description: "Regras de Bota-Abaixo: rodada (escolha, construção, corrida, placar), peças com dono de data/pieces.json, marreta e pontuação de data/scoring.json. Use ao implementar, mudar ou ajustar regras, peças ou pontuação."
---

# Regras do jogo

## Máquina de estados da rodada
`ENTRADA → ESCOLHA (10 s) → CONSTRUÇÃO (20 s) → CORRIDA (60 s) → PLACAR (5 s) → próxima rodada ou VITÓRIA`. Tempos em `data/scoring.json`.

- **Escolha:** esteira com `jogadores + 2` peças sorteadas (só as liberadas no marco atual: campo `marco`); quem tem menos pontos escolhe primeiro.
- **Construção:** um cursor por jogador, grade de 64 px; não pode sobre sólido, outra peça ou célula `x` (exceto a dinamite P12). Peça não colocada no tempo é perdida.
- **Corrida:** todos saem juntos; tocar perigo rival = eliminado; chegar ao `E` registra a ordem. Robôs não colidem entre si.
- **Placar:** aplica `data/scoring.json`.

## Peças com dono
- Toda consulta passa o jogador: `is_solid_for(player)`, `is_hazard_for(player)`, `force_for(player)`. Isso é o coração do jogo.
- Nunca eliminam o dono. Para o dono são neutras ou dão vantagem.
- Visual: faixa e ícone na cor do dono; estado "dono" e "rival" diferentes (a serra recolhe os dentes para o dono).
- Uma classe base `Piece` + uma cena por peça; números em `data/pieces.json`.

## Marreta
1 uso por rodada; destrói uma peça rival encostada à frente; não afeta peças próprias nem o mapa; a animação não trava o movimento.

## Teste rápido de cada peça
Com o debug, coloque a peça como P1, jogue com P1 e com P2 e confira: dono como descrito em "para_o_dono", rival como em "para_rivais". Anote o que diverge.
