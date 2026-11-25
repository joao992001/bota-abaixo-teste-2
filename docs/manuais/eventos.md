# Manual geral — EVENTOS ESPECIAIS (princípios de produção, todos os modos)

**Escopo:** como produzir qualquer evento. Implementação e regras do Derruba: [`derruba/evento.md`](derruba/evento.md).

## Origem arquitetônica
O evento nasce do **mapa e das cenas** (o que a arquitetura permite acontecer: guindaste, poço, gerador, buraco no teto…).
Depois do conceito visual das cenas aprovado, cada evento tem produção individual. Um evento que depende de um elemento
físico só pode ser autorizado em cenas que **têm** esse elemento (pré-requisito no código em `eligible()` e autorização no
manifesto em `cenas[].eventos`). Eventos **não surgem automaticamente** em qualquer mapa.

## Ficha obrigatória
finalidade na luta (motivo claro para o jogador agir) · pré-condições ambientais · cenas autorizadas · disparo ·
**aviso/telegráfo** (onde e quando) · fase ativa · encerramento (o que persiste, o que é restaurado) · conflitos com outros
eventos · segurança (nascimentos, rota única, densidade) · integração com a destruição da cena.

## Evento × deterioração espontânea
Não misturar: a **deterioração espontânea** é regra do modo (Derruba: o diretor da destruição, `derruba/README.md`); um
**evento especial** é um acontecimento com nome, aviso e fase própria.

## Sequência
ficha → arte (peças) para aprovação → animação (aviso/ativo/fim) para aprovação → código → testes (inclusive "não vaza
para outra cena/mapa") → aprovação final → registrar estado na biblioteca do mapa e lições no manual do modo.

## Histórico
- 2026-11-25 — `APROVADO`: eventos autorizados por mapa E cena no manifesto (antes: lista `por_fase` em `modos.json`, e
  mapa sem lista recebia toda a biblioteca).
