# Biblioteca do mapa — FASE 1 do Derruba: CANTEIRO DE OBRAS

| Campo | Valor |
|---|---|
| Estado | `APROVADO` (fase fechada pelo usuário em 2026-11-25) · migrada para a arquitetura modular em 2026-11-25 |
| Modo | Derruba (regras: `docs/manuais/derruba/README.md`) |
| `map_id` | `canteiro_obras` · arte `fase1` |
| Manifesto (código lê) | `data/mapas/derruba/canteiro_obras.json` — **fonte única** de spells, eventos, mecanismos e estruturas por cena |
| Geometria | `levels/canteiro_obras.lvl` (`etapa1`, `etapa2`, `ko1`, `ko2`, `buraco1`, nascimentos 1–8) |
| Arte | `art/src/cenarios/fase1_catalogo.py`, `fase1_prancha.py`, `fase1_jogo.py` → `game/assets/fase1/`; animação `game/modes/cena.gd` |
| Catálogo original (histórico, conceito aprovado em 2026-11-24) | [`../f1_canteiro.md`](../f1_canteiro.md) |

**Conceito:** demolição de um prédio em obra. A luta começa no **Térreo** (laje sobre escoras, andaimes, vigas penduradas,
grua gigante ao fundo) e, quando a obra está 90% destruída, **a obra cede**: todos caem pelo poço até a **Fundação**
(subsolo escuro, 3 lajes sobre o vazio, bate-estaca, água).

| Cena | Arquivo | Próxima |
|---|---|---|
| 1 · Térreo (`terreo`) | [`cenas/terreo.md`](cenas/terreo.md) | Fundação, aos 90% de destruição |
| 2 · Fundação (`fundacao`) | [`cenas/fundacao.md`](cenas/fundacao.md) | — (última) |

Inventários: [`eventos.md`](eventos.md) · [`perigos_mecanismos.md`](perigos_mecanismos.md) · [`spells.md`](spells.md) ·
[`skins.md`](skins.md) · decisões, lições e testes: [`decisoes_testes.md`](decisoes_testes.md).
