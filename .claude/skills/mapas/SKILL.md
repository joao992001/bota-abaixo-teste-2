---
name: mapas
description: "Desenho das arenas de Bota-Abaixo em levels/*.lvl, por modo (Derruba, Batata-Dinamite, Rei da Obra, Fuga): pontos quentes, bordas e poços, justiça entre spawns, faixa reservada ao HUD, variedade. Use ao criar ou ajustar mapas."
---

# Mapas

Cada arena pertence a um modo (`data/modos.json` → `demolicao.modos[].arenas`). O mapa tem que servir à regra do modo.

## Regras gerais
1. **Spawns justos:** espelhados (ou equivalentes) e longe de perigo; ninguém nasce já na borda.
2. **2–3 pontos quentes:** lugares por onde todos passam (centro, ponte estreita, topo). É ali que a briga acontece.
3. **Faixa do HUD:** as linhas 14–15 (y ≥ 952 px na tela) ficam embaixo dos cartões dos jogadores. Só poço, espinho, lama ou água ali; nada jogável.
4. **Nada mata "do nada":** perigo sempre visível e com aviso (ciclo de máquina, faísca, alavanca).
5. **Variedade:** cada arena com uma ideia própria (algo que se move, que empurra, que cai…).

## Por modo
- **Derruba** (vidas, dano %): plataformas abertas com bordas e poços dos lados; dá para voltar pulando (pulo duplo) se não apanhou muito. Caixotes que quebram mudam o palco ao longo da rodada.
- **Batata-Dinamite:** fechada, SEM poço (só a bomba elimina); voltas e atalhos para fugir em círculo.
- **Rei da Obra:** um "trono" no alto e vários caminhos até ele; quem está lá fica exposto.
- **Fuga:** mapa maior que a tela com `rolagem:`; rota clara para frente/cima e obstáculos que separam os jogadores.

Formato: `levels/README.md`. Depois de editar, rode partidas de bots (`-- --stats=N --sub=<modo> --so-arenas=<ids>`) e veja duração, quedas sozinho × derrubadas; capture com `-- --arenas=DIR`.
