# Decisões, lições e testes — Canteiro de Obras

## Decisões (estado · data · motivo)
- `APROVADO` 2026-11-24 — 2 cenas no mesmo mundo, virada "a obra cede" (queda cinematográfica, sem KO).
- `REPROVADO` 2026-11-24 — esteira (M3), passarela (E7/D6), Fundação em bacia com paredes, grelha/poço: composição sem sentido ou injusta.
- `APROVADO` 2026-11-25 — Fundação como 3 lajes sobre o vazio; bate-estaca com torre; água em cachoeiras; placas/lâmpadas presas.
- `REPROVADO` 2026-11-25 — drone G09 na fase.
- `SUBSTITUÍDO` 2026-11-25 — virada cronometrada (90 s) → 90% de destruição + diretor adaptativo (regra do modo).
- `SUBSTITUÍDO` 2026-11-25 — G01 como evento sorteado → ferramenta do diretor.

- `APROVADO` 2026-11-25 (reformulação v2) — mapa de **3 cenas**: Térreo → Fundação (Rota Total) | cena nova (Rota Moderada).
- `SUBSTITUÍDO` 2026-11-25 (v2) — transição imediata aos 90% + diretor adaptativo; G01 Sirene volta como evento selecionável.

## Lições
Registro completo de erros da Fase 1: `docs/manuais/derruba/mapa.md` §7 (processo, composição, palco, transição, técnico).
Migração 2026-11-25: números do JSON chegam como decimais (2.0) — `2 in [2.0]` é falso no GDScript; converta para int ao ler
listas de índices (o núcleo deixou de ser base fixa até isso ser corrigido).

## Testes da fase
`--so=mapa` (manifesto e resolução) · `--so=etapas` (90%, base fixa, origens de dano, limiar, queda, última cena) ·
`--so=diretor` · `--so=mecanismos` · `--so=eventos` · `--so=canteiro` · vitrine `--fase=DIR` · vídeo `--video=DIR --arena=canteiro_obras --virada=9`.
