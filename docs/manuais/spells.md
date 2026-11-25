# Manual geral — SPELLS (princípios de produção, todos os modos)

**Escopo:** como produzir qualquer spell. Regras do modo (classes, números, implementação) ficam no manual do modo:
Derruba → [`derruba/spell.md`](derruba/spell.md). Estados e aprovações: [`sistema_criacao.md`](sistema_criacao.md).

## Quem decide o quê
| Nível | Decide |
|---|---|
| **Modo** | as **classes** e seus papéis (Derruba: Ataque, Controle, Engenharia, Transformação — `modos[derruba].classes_spells`). Classe é funcional: nem toda spell causa dano. |
| **Mapa** | a **identidade** (a spell é pensada com a estética do mapa) e o **pool autorizado** (`spells_permitidas` no manifesto). Nunca cria classe. |
| **Spell** | mecanismo, controles, alcance, interação, feedback, contrajogo, arte e animação próprias. |
Reuso entre mapas: a lógica é compartilhada, mas a spell só aparece num mapa se estiver em `spells_permitidas` dele.

## Sequência (cada passo com aprovação do usuário onde indicado)
1. Função da spell na luta (por que o jogador quer pegá-la; contrajogo do rival).
2. Ficha: classe do modo, toque × segurar, mira, alcance, reação do rival, objeto/arma, mapa de origem e mapas autorizados.
3. **Arte estática** (prancha) → aprovação. 4. **Animação fluida em movimento** (GIF) → aprovação. A animação segue a
   natureza da spell (arma, projétil, transformação, construção…), não uma fórmula visual cega.
5. Jogabilidade + bots + limpeza total ao morrer/trocar. 6. Testes e vitrine. 7. Aprovação final.
8. Registrar: biblioteca do mapa de origem (`spells.md` do mapa: estado) + lições no manual do modo.

## Histórico
- 2026-11-25 — `APROVADO`: classes no modo, pool por mapa (antes: pool por modo, e outros modos herdavam o do Derruba).
