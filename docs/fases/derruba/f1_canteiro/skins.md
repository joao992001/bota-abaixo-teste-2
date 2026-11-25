# Skins originadas no Canteiro de Obras

Processo: `docs/manuais/skins.md`. Prancha: `art/out/prancha_skins_canteiro.png` (gerador `art/src/robos/skins_canteiro.py`:
camadas por cima do robô; mesma silhueta e hitbox; cor do jogador dominante; sem efeito de jogo).
Manifesto: `skins_originadas` = K1–K5 (arte aprovada). Recurso no jogo (seletor etc.): NÃO autorizado ainda.

| Id | Robô | Skin | O que muda | Estado |
|---|---|---|---|---|
| v1 (10 skins: adesivos, faixas, coletes laterais) | todos | — | camadas pequenas por cima | REPROVADO (2026-11-25): "mudanças muito sutis" |
| K1 | Marretão | Mestre de Obras | uniforme laranja refletivo no tronco, capacete grande na cor do jogador com lanterna, marreta zebrada | APROVADO — arte (2026-11-25) |
| K2 | Picareta | Topógrafo | colete limão, luneta de teodolito no olho, picareta-baliza vermelho/branco | APROVADO — arte (2026-11-25) |
| K3 | Chave | Soldador | avental de couro com tachas, máscara de solda grande na cor do jogador, chave de cobre | APROVADO — arte (2026-11-25) |
| K4 | Britadeira | Concreteiro | corpo coberto de cimento, capacete respingado, máscara de pó, britadeira suja | APROVADO — arte (2026-11-25) |
| K5 | Pá | Operador de Escavadeira | corpo de máquina nº 01 com zebra, cabine com santo-antônio e giroflex, pá-caçamba com dentes | APROVADO — arte (2026-11-25) |
Regra nova da v2 (APROVADA em 2026-11-25): o uniforme pode cobrir o tronco inteiro; a COR DO JOGADOR passa para o capacete/cabine
grande (e segue nos braços e pernas). Aplicação em movimento (2026-11-25): no jogo as skins só trocam texturas (`corpo_<robô>_<k#>_p<cor>.png`,
`ferramenta_<robô>_<k#>.png`, geradas por `python3 art/src/robos/skins_canteiro.py --jogo`); `robot_visual.skin = "k1"`.
Vitrines: `--elenco=DIR --skins` (13 poses) e `--equipa=DIR --skins` (armas, kits, armaduras) → AGUARDANDO_APROVAÇÃO.
Ainda sem menu: jogadores não escolhem skin (precisa de autorização).
