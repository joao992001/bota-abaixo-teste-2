---
name: criar-fase
description: "Criar uma FASE nova do modo Derruba (mapa como cena viva em etapas): catálogo → prancha de arte → código em 6 blocos (etapas/virada, fundo animado, mecanismos, demolições, eventos da fase, entrega). Use quando o usuário pedir uma fase/mapa/arena nova ou para refazer uma fase."
---

# Criar fase (Derruba) — siga o manual

1. Leia **só** `docs/manuais/derruba/mapa.md` (passo a passo) e `docs/manuais/derruba/mapa_cartilha.md` (regras).
   Exemplo pronto: `docs/fases/derruba/f1_canteiro.md` (catálogo) e os geradores `art/src/cenarios/fase1_*.py`.
2. Ordem fixa, cada passo aprovado pelo usuário: **catálogo** (copie f1_canteiro.md) → **prancha de arte** (copie
   fase1_prancha.py) → **código em blocos A–F**, teste só o bloco (`--so=etapas|mecanismos|eventos|canteiro`) e commit
   por bloco; bateria completa 1× no fim; GIF da vitrine `--fase=DIR`; `.exe`.
3. Uma fase nova é sobretudo **dados** (`.lvl` com etapas, `demolicao.mecanismos/<cena>`, `demolicao.eventos.por_fase`,
   `demolicao.canteiro` LAYOUTS) + **arte** exportada da prancha. Código novo só para tipo novo de mecanismo/peça/evento.
4. Economia: não leia arquivos grandes inteiros — `grep -n` no ponto de encaixe e substituição exata. Atualize o manual
   com as lições novas e o "Retomar aqui" de `docs/ESTADO.md`.
