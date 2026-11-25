---
name: criar-fase
description: "Criar uma FASE nova do modo Derruba (mapa como cena viva em etapas): catálogo → prancha de arte → código em 6 blocos (etapas/virada, fundo animado, mecanismos, demolições, eventos da fase, entrega). Use quando o usuário pedir uma fase/mapa/arena nova ou para refazer uma fase."
---

# Criar fase (Derruba) — siga o manual

1. Leia **só** `docs/manuais/derruba/mapa.md` (método VALIDADO: ordem com aprovações, blocos, CHECKLIST do §5 e
   registro de erros do §7) e `docs/manuais/derruba/mapa_cartilha.md` (regras de desenho).
   Exemplo pronto: `docs/fases/derruba/f1_canteiro.md` (catálogo) e os geradores `art/src/cenarios/fase1_*.py`.
2. Ordem fixa, cada passo aprovado pelo usuário: **catálogo** (copie f1_canteiro.md) → **prancha de arte** (copie
   fase1_prancha.py) → **código em blocos A–F**, teste só o bloco (`--so=etapas|mecanismos|eventos|canteiro`) e commit
   por bloco; bateria completa 1× no fim; GIF da vitrine `--fase=DIR`; `.exe`.
3. Uma fase nova é sobretudo **dados** (`.lvl` com etapas, `demolicao.mecanismos/<cena>`, `demolicao.eventos.por_fase`,
   `demolicao.canteiro` LAYOUTS) + **arte** exportada da prancha. Código novo só para tipo novo de mecanismo/peça/evento.
4. **Antes de mandar qualquer imagem ou build ao usuário, passe o checklist do §5** (cada objeto se apoia em algo e
   serve para algo; nada em paralaxe que precise casar com o mundo; cair = KO em qualquer ponto; virada com câmera
   descendo junto). Erro novo reprovado pelo usuário → linha nova no §7 no mesmo commit.
5. Economia: não leia arquivos grandes inteiros — `grep -n` no ponto de encaixe e substituição exata. Atualize o manual
   com as lições novas e o "Retomar aqui" de `docs/ESTADO.md`.
