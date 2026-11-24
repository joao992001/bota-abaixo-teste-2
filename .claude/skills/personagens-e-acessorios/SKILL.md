---
name: personagens-e-acessorios
description: "Robôs de Bota-Abaixo (elenco de 5, humanoides, de perfil, ferramenta própria nas duas mãos e golpes/esquiva próprios), papel e giz, gerados por art/src/robos/elenco.py. Use ao criar ou ajustar robôs, expressões, ferramentas ou as animações básicas deles."
---

# Personagens — siga o manual

**Leia e siga `docs/manuais/personagem.md`** (passo a passo oficial, aprovado pelo usuário em 2026-11-24).

Resumo: elenco de 5 — Marretão (marreta), Picareta, Chave (chave inglesa), Britadeira, Pá. Sempre humanoide, de perfil,
ferramenta nas DUAS mãos, silhueta e golpes (rápido, pesado, esquiva) diferentes; regras e hitbox 48×72 iguais para todos.
Fonte única: `art/src/robos/elenco.py` (prancha para aprovar + texturas + `modelos.json` com 13 quadros-chave por robô);
animação em `game/player/robot_visual.gd` (`current_pose`). O golpe acerta no fim do preparo: a descida começa dentro do
preparo. Vitrines: `--elenco=DIR`, `--robos=DIR`. Teste: `--so=robos`.
