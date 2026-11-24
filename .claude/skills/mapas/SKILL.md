---
name: mapas
description: "Arenas de Bota-Abaixo em levels/*.lvl por modo (Derruba, Batata-Dinamite, Rei da Obra, Fuga): formato, câmera/rolagem, pontos quentes, spawns justos, máquinas, faixa do HUD e como medir com bots. Use ao criar, remover ou ajustar fases."
---

# Mapas

> **Reforma em andamento (2026-11-23):** o usuário quer retirar as fases atuais e criar um **modelo de fase padrão**, com câmera
> e regras próprias por modo, **depois** da reforma de movimento/combate. Veja `docs/ESTADO.md` ("Retomar aqui") antes de mexer.

## Onde fica
- Mapas em texto: `levels/<id>.lvl` (formato e todos os caracteres/chaves em `levels/README.md`); a Godot lê direto
  (`game/level/level.gd`). Lista por modo, nome, dica e música: `data/modos.json` → `demolicao.modos[].arenas` e `demolicao.arenas`.
- Geradores antigos: `tools/mapas/` (gerar.py, variedade.py, fuga2.py). Prévia no menu: `game/assets/ui/arena_<id>.png`.

## Regras gerais
1. **Spawns justos:** espelhados ou equivalentes, longe de perigo.
2. **2–3 pontos quentes** por onde todos passam.
3. **Nada mata "do nada":** perigo visível e com aviso.
4. **Uma ideia por arena** (algo que move, empurra, cai, abre).
5. **Medidas vêm do robô:** pulo, pulo duplo, alcance do golpe e aderência na parede (`data/controller.json`, `modos.json`)
   definem distâncias de vãos e alturas. Mudou o movimento → revise as fases.

## Por modo (regra atual)
Derruba: palco aberto com bordas e poços · Batata: fechada, sem poço, voltas para fugir · Rei: trono exposto com vários caminhos ·
Fuga: maior que a tela com `rolagem:` e rota clara.

## Medir
`-- --stats=N --sub=<modo> --so-arenas=<ids>` (duração, quedas × derrubadas) · captura `-- --arenas=DIR` · bots: `modes/bots.gd`.
