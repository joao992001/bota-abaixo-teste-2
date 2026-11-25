---
name: criar-fase
description: "Criar uma FASE (mapa) nova do modo Derruba, ou refazer uma: biblioteca do mapa + fotografia conceitual de cada cena (≥ 2 cenas, com perigos/mecanismos) → manifesto data/mapas/derruba/<mapa>.json → código em blocos A–F → transição por 90% de destruição. Use quando o usuário pedir fase/mapa/arena nova do Derruba (mesmo que ele já traga parte do conceito, eventos, spells ou estilo)."
---

# Criar fase (Derruba) — siga os manuais

**Só para o modo Derruba.** A Fase 1 (Canteiro) foi feita neste molde e toda fase nova do Derruba segue o mesmo molde.

1. Leia, nesta ordem: `docs/manuais/README.md` (índice) → `docs/manuais/derruba/README.md` (regras do modo: cenas ≥ 2,
   base fixa × destrutível, 90% + diretor adaptativo, autorização por mapa/cena) → `docs/manuais/derruba/mapa.md`
   (método VALIDADO: ordem com aprovações, blocos A–F, CHECKLIST §5, registro de erros §7) → `mapa_cartilha.md`.
   Exemplo vivo: `docs/fases/derruba/f1_canteiro/` + `data/mapas/derruba/canteiro_obras.json` + `art/src/cenarios/fase1_*.py`.
2. **Separe o que o usuário JÁ definiu** (conceito, cenas, eventos, spells, estilo) → registre como `APROVADO` na
   biblioteca e não reabra; proponha só o que falta, marcado `PROPOSTO`. Nunca invente conteúdo como aprovado.
3. Ordem fixa: biblioteca (copie `docs/fases/derruba/_modelo/` → `fN_<nome>/`) → **fotografia de cada cena** com perigos e
   mecanismos posicionados (aprovação) → manifesto + `.lvl` (`--so=mapa` valida) → blocos A–F, teste e commit por bloco →
   bateria completa 1× → GIF da transição `--fase=DIR` → `.exe`.
4. Uma fase nova é sobretudo **dados** (manifesto + `.lvl`) + **arte**. Código novo só para tipo novo de mecanismo,
   estrutura ou evento (manuais `derruba/perigos_mecanismos.md`, `derruba/evento.md`).
5. **Antes de mandar imagem ou build, passe o checklist do `mapa.md` §5.** Erro novo reprovado → linha no §7 + decisão na
   biblioteca do mapa, no mesmo commit. Atualize "Retomar aqui" de `docs/ESTADO.md`.
6. Economia: não leia arquivos grandes inteiros — `grep -n` no ponto de encaixe e substituição exata.
