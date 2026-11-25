# Manual — SKINS (processo documentado; recurso FUTURO, não implementar ainda)

**Estado do recurso:** `PROPOSTO` como sistema. **Não** criar skins, seletor, loja, desbloqueio ou menu sem nova
autorização do usuário. O elenco implementado tem **5 robôs** ("15 robôs" é perspectiva, não quantidade implementada).

## Regras aprovadas (2026-11-25)
1. Personagens continuam **globais**. A **origem e a direção visual** de uma skin pertencem ao **MAPA** (nunca ao modo).
   Ex.: uma skin temática de um mapa "Hollywood" seria concebida na biblioteca desse mapa, sem criar personagem novo.
2. Skin **não altera** hitbox, dano, mobilidade nem equilíbrio. Zero efeito de jogo.
3. Preserva a **identidade e a silhueta** do robô e a **legibilidade da cor do jogador** (P1–P4).
4. Compatível com ataques, ferramenta, armas, spells, armaduras/transformações, expressões e dano visual.
5. Duas aprovações: **arte** (prancha estática) e **aplicação em movimento** (GIF com as 13 poses e spells).

## Quando for autorizado: onde registrar
- Biblioteca do mapa de origem: `docs/fases/<modo>/<mapa>/skins.md` (id, robô, conceito, estado, compatibilidade).
- Manifesto do mapa: `skins_originadas` (ids). A implementação (camadas de arte por modelo em `art/src/robos/`) será
  especificada aqui quando o usuário aprovar o sistema.
