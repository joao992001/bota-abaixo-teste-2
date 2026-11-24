# Manual — criar um PERSONAGEM (robô jogável)

Vale para o jogo todo. Referência viva: o elenco de 5 (Marretão, Picareta, Chave, Britadeira, Pá), aprovado em 2026-11-24.

## 1. O que todo robô TEM que ter (requisitos do usuário)
- **Humanoide**: tronco, cabeça, 2 braços com 2 mãos, 2 pernas. Nada de veículo (a "Garra" com esteiras foi vetada:
  os robôs seguram armas das spells e vestem as armaduras das transformações).
- **De perfil**, olhando para onde anda (os antigos "olhavam para a câmera" — reprovado).
- **Ferramenta de demolição própria**, segurada com **as duas mãos** (bater com uma mão foi reprovado).
- **Silhueta diferente** dos outros, legível no tamanho real (1x, ~80–95 px de altura; o baixinho pode ter ~70).
- **Animações básicas próprias** e bem diferentes: golpe rápido, golpe pesado, esquiva (chão e ar). Spells e
  transformações são iguais para todos (não precisam de versão por robô).
- **Regras iguais**: hitbox 48×72, tempos, alcance e dano iguais para todos. O visual nunca muda o jogo.
- Corpo na **cor do jogador** (4 cores) + 6 expressões + 3 estágios de amassado + um acessório que balança (antena,
  giroflex, lâmpada…).

## 2. Onde fica cada coisa
| O quê | Arquivo |
|---|---|
| Desenho, esqueleto, poses e exportação (fonte única) | `art/src/robos/elenco.py` |
| Prancha para aprovar | `art/out/prancha_elenco5.png` (gerada pelo mesmo script) |
| Texturas do jogo + dados | `art/out/game/robo/` → copiar para `game/assets/robo/` (`corpo_<id>_p1..4`, `rosto_<id>_<expr>`, `antena_<id>`, `dano1..3_<id>`, `ferramenta_<id>`, `modelos.json`) |
| Lista de robôs | `game/autoload/data.gd` → `MODELS` (ids) e `MODEL_NAMES` |
| Animação | `game/player/robot_visual.gd` → `current_pose()` (mistura quadros) e `draw_robot()` (monta) |
| Teste | `game/tests/driver.gd` → `robos_test` (`--so=robos`) |
| Vitrines | `--elenco=DIR [--so-elenco=0+3]` (jogo, de perto) e `--robos=DIR` (prancha do motor: parado, dança, rostos) |
| Peças comuns (luva, bota, parafuso) | `art/src/robos/robos.py` (não gera mais robôs) |

## 3. Passo a passo
### Passo 1 — Conceito (aprovar antes de animar)
1. Em `elenco.py`, escreva as funções do robô (unidades = px de jogo, pés na origem, virado para +x, y para baixo):
   - `t_<id>(c, e)` tronco (origem no quadril);
   - `h_<id>(c, e, L)` cabeça em **camadas**: `"base"` (forma), `"face"` (rosto, troca com a expressão),
     `"acc"` (acessório que balança), `"all"` (prancha). Use `face_eye()` e `mouth()` — já tratam as expressões
     `normal, piscar, esforco, susto, vitoria, eliminado` e as da prancha (`ataque, forca, grito, esquiva`);
   - `tool_<id>()` ferramenta deitada: origem na **pegada da frente**, +x para a cabeça da ferramenta.
2. Cadastre em `CHARS`: `hip_h`, `head_at`, ombros `sh_b/sh_f`, quadris `hip_b/hip_f`, braço `(a, b, largura)`,
   perna `(a, b, largura)`, `knee` (+1 normal, −1 joelho para trás), bota, `hand`, `grips` (pegada da frente e de trás no cabo;
   ferramenta em T usa pegadas perpendiculares, como a britadeira).
3. Escreva as **5 poses da prancha** em `POSES[id]`: `parado`, `rapido`, `pesado_prep`, `pesado_golpe`, `esquiva`.
   Cada pose: `tool=(x, y, ângulo)` da pegada da frente (ângulo SVG: 0 = frente, −90 = para cima), `lean` (graus,
   + = para a frente), `dy` (agacha +, sobe −), `feet=[trás, frente]`, `face`, efeitos `fx`/`fx_b` (arco, linhas, poeira,
   onda, estrela, faíscas, vibra, pedras), e `spin`/`spin_c` se gira.
4. `python3 art/src/robos/elenco.py` → abra `art/out/prancha_elenco5.png`, compare com os outros e **mande para o usuário
   aprovar** (silhueta, ferramenta, cada golpe e a esquiva). Ajuste até aprovar.

### Passo 2 — Quadros que só o jogo usa
Em `EXTRA[id]`, mais 8 quadros: `corre` (ferramenta carregada, ex.: no ombro), `ar`, `rapido_prep`, `rapido2_prep`,
`rapido2` (variação que alterna com o rápido e fecha o combo), `cima`, `baixo`, `esquiva_ar`.
- Golpe de **estocada** (picareta, pá, chave, britadeira): no `rapido_prep` a ferramenta continua **apontando para a frente**
  (só a mão recua). Se apontar para trás, a mistura faz um giro por cima que não é estocada.
- Golpe de **arco** (marreta): preparo para trás/cima, golpe para a frente — o motor gira pela frente/por cima.

Em `GAME[id]`: `k` (escala no jogo), `tk` (escala da ferramenta; a marreta do Marretão é 1,18 para ficar grande),
`voz`, `danca` (0–3, comemoração), `hand_r`, `foot`, `acc` (ponto do acessório na cabeça), `torso_d` (contorno do tronco,
recorta os amassados) e `especial` (ver Passo 4). Em `TOOL_BOX[id]`, a caixa da ferramenta deitada.

### Passo 3 — Exportar e ligar no jogo
1. `python3 art/src/robos/elenco.py` (gera prancha + texturas + `modelos.json` com geometria, `tool`, `tool_grip`,
   `grip2`, `reach`, `especial` e os 13 quadros) → `cp art/out/game/robo/* game/assets/robo/` → `--import`.
2. Adicione o id em `Data.MODELS` e o nome em `Data.MODEL_NAMES` (mesma ordem de `CHARS`).
3. Pronto: a entrada (▲▼), o HUD, os retratos, a comemoração, o desmontar na eliminação, o dano visual e as spells já leem
   tudo de `modelos.json`.

### Passo 4 — Animação (o que o motor faz e o que você pode acrescentar)
`current_pose()` mistura os quadros no **ritmo do controle** (`data/controller.json`):
- base: `parado` → `corre` (pela velocidade) → `ar` (no ar), com passada, respiração e molas;
- golpe rápido: alterna `rapido_prep/rapido` e `rapido2_prep/rapido2`; ▲ = `cima`, ▼ no ar = `baixo`; 3º do combo = `rapido2`;
- golpe pesado: `pesado_prep` (antecipação com tremor e brilho) → `pesado_golpe`; errou = ferramenta cravada;
- esquiva: `esquiva` (chão) / `esquiva_ar`.
- **Regra de ouro do impacto:** o golpe ACERTA no fim do preparo (é aí que a hitbox liga e entra o hitstop). Então a
  descida começa **dentro** do preparo: no impacto a ferramenta já está a ~60–65% do golpe; o "ativo" só termina o
  movimento. (Antes o impacto mostrava a ferramenta parada lá atrás — reprovado.)
- `especial` (em `GAME`): `pesado: "giro"` (gira 360°), `"monta"` (sobe na ferramenta — use `dy` negativo e pés nos
  pedais no `pesado_prep`); `esquiva: "mortal"` (mortal para trás), `"salto"` (apoia na ferramenta e salta),
  `"pulinho"`, `"carrinho"`, `"escudo"`. Especial novo = um `match` novo em `current_pose()` (mantenha curto e documente aqui).
- As duas mãos: `draw_robot()` põe a mão de trás em `grip2` girado com a ferramenta. A mão de trás só solta quando o robô
  apanha, se pendura, escala parede, voa ou usa spell (`two_hand = false`).

### Passo 5 — Conferir e entregar
1. `--so=robos` (confere 5→N robôs, texturas, 13 quadros e ferramenta; ajuste o número esperado).
2. `--elenco=DIR --so-elenco=<índice>` → monte uma **prancha de quadros-chave** (parado, corrida, 3 rápidos, preparo e
   impacto do pesado, esquiva chão e ar) e olhe de perto: ferramenta nas duas mãos, impacto no alvo, nada atravessando a cabeça.
3. `--robos=DIR` (telas paradas: entrada, comemoração, rostos).
4. GIF do robô + `.exe` + relatório curto. Atualize este manual se algo novo foi aprovado.

## 4. Lições (reprovado → regra)
- Robô de frente para a câmera e martelinho numa mão → **perfil + duas mãos + ferramenta grande**.
- Veículo no elenco → **sempre humanoide**.
- Impacto com a ferramenta atrasada → **descida dentro do preparo** (Passo 4).
- Golpes iguais entre robôs → cada um com preparo, golpe e esquiva **de silhueta diferente** (arco × estocada × giro × pulo).
