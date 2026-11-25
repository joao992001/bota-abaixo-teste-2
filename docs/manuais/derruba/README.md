# Modo DERRUBA — regras do modo e acesso aos manuais

**Objetivo do modo:** tirar os rivais da arena (KO ao cair do palco ou sair da zona); cada robô tem vidas
(`lives_setting`); vence quem sobra. Dano acumulado no Amassômetro (%) aumenta o arremesso. Motor: `game/modes/demolicao.gd`.

## Regras do modo (valem para TODO mapa do Derruba)
| Tema | Regra | Dados / código |
|---|---|---|
| **Classes de spell** | Ataque, Controle, Engenharia, Transformação (pesos do sorteio). O mapa não cria classe. | `data/modos.json` → `demolicao.modos[derruba].classes_spells` · `spells.gd` `classes()` |
| **Spells por mapa** | o manifesto do mapa lista as autorizadas (`spells_permitidas`); sorteio = classe (peso) → spell (raridade) | `MapaReg.spells()` |
| **Cenas** | todo mapa tem **≥ 2 cenas** (admite N), em ordem, no mesmo mundo (a próxima cena fica embaixo/ao lado) | manifesto `cenas[]` + `.lvl` `etapaN`, `koN`, `buracoN`, nascimentos 4·(N−1)+1…4·N |
| **Base fixa × destrutível** | cada cena tem estrutura **fixa** (nunca leva dano, nunca conta) e **destrutíveis** | manifesto `cenas[].estruturas` + `base_fixa` |
| **Origens de dano** | ações dos jogadores (marretada pesada, robô arremessado), spells, mecanismos, eventos e a deterioração espontânea | tudo passa por `canteiro.damage()` |
| **Transição** | ao chegar a **90% da destruição elegível** da cena, havendo próxima: aviso "A OBRA VAI CEDER!" → desaba → queda lenta (sem KO, sem controle, câmera desce junto) → próxima cena. Uma vez por cena. Sem cronômetro. | `modos[derruba].destruicao` · `modes/etapas.gd` · cinemática `demolicao.etapas` |
| **Medida dos 90%** | soma(peso × HP perdido) / soma(peso) das peças destrutíveis da cena; caída = 100%; peso = largura em tiles (laje ×2); fora: base fixa, pedaços gerados (entulho), outras cenas, decoração. Calculada do estado (nada conta 2×) | `canteiro.progresso(n)` |
| **Diretor adaptativo** (proposta do usuário, `APROVADO` 2026-11-25) | mede o ritmo: se os jogadores quebram pouco, derruba peças sozinho (sirene + fita zebrada → cai) para chegar aos 90% perto de um alvo sorteado (75–120 s); se quebram muito, quase não age. Nem toda rodada precisa virar. Sem barra no HUD (surpresa). | `etapas._diretor()` · `destruicao.alvo_s/intervalo_s/chance_calma/deficit_max` |
| **Última cena** | não tem transição; só deterioração calma | `MapaReg.tem_proxima()` |
| **Eventos** | autorizados por mapa e por cena; até 2 juntos (conflitos); aviso → ativo → fim | manifesto `cenas[].eventos` · `eventos.gd` |
| **Perigos/mecanismos** | instâncias por cena no manifesto, presas à arquitetura | `cenas[].mecanismos` · `mecanismos.gd` |
| **KO** | cair do piso em qualquer ponto = KO rápido; saída para KO em ≥ 2 lados por cena | `.lvl` `koN` |

## Manuais do modo
- **Fase (mapa):** [`mapa.md`](mapa.md) — método VALIDADO (obrigatório) · regras de desenho: [`mapa_cartilha.md`](mapa_cartilha.md)
- **Spell:** [`spell.md`](spell.md) · **Evento:** [`evento.md`](evento.md) · **Perigos/mecanismos:** [`perigos_mecanismos.md`](perigos_mecanismos.md)
- Bibliotecas dos mapas: `docs/fases/derruba/` (Fase 1: [`f1_canteiro/`](../../fases/derruba/f1_canteiro/README.md); modelo: `_modelo/`)

## Histórico de decisões do modo
- 2026-11-25 — `SUBSTITUÍDO`: transição **cronometrada** (90 s, `etapas.virada_s`) → transição por **90% de destruição** +
  diretor adaptativo. A cinematografia aprovada (aviso, desabamento, queda lenta, câmera descendo junto) foi mantida.
- 2026-11-25 — `SUBSTITUÍDO`: no Canteiro, o "ciclo da obra" (evento G01 Sirene: sirene + fita → um trecho cai) deixou de
  ser evento sorteado e virou a **ferramenta do diretor** (deterioração espontânea). G01 continua na biblioteca de eventos.
- 2026-11-25 — `APROVADO`: classes de spell no modo; spells/eventos/mecanismos autorizados no manifesto do mapa;
  sem herança silenciosa de spells/eventos entre modos (só mapas-ferramenta recebem tudo, explícito).
