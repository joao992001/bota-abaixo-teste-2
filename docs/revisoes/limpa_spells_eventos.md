# Limpa de SPELLS e EVENTOS (modo Derruba) — anotações do usuário, NÃO EXECUTAR ainda

> Estado: **EXECUTADO em 2026-11-25** (o usuário pediu "pode executar"), exceto os itens marcados PENDENTE abaixo.
> Códigos novos: Ataque A01–A08, Controle C01–C05, Engenharia E01–E03, Transformação T01–T07 (tabela em
> `docs/manuais/derruba/spell.md`). Teste da limpa: `--so=limpa`. Quando
> executar, atualizar `docs/manuais/derruba/spell.md` / `evento.md`, o manifesto do mapa e a biblioteca do Canteiro.
> Lista de referência que o usuário viu: 26 spells (#1–26) e 15 eventos (#27–41).

## 0. Organização (antes de qualquer mudança de spell)
- Os códigos das spells não fazem sentido (S01, S02, S03, S05 e depois S17 no meio do Ataque…). **Reorganizar por
  classe** (Ataque, Controle, Engenharia, Transformação) e **numerar em sequência dentro de cada classe**, juntando
  as que são da mesma classe. Proposta técnica a apresentar antes: novo esquema de ids (ex.: A01…, C01…, E01…, T01…)
  com tabela de equivalência ids antigos → novos, migrando dados, código, testes, arte e manuais juntos.

## Feito
- Ids por classe; S18 Disco, S25 Ponte, S28 Escudo e G09 Drone REMOVIDOS (dados, código, testes).
- C02 Turboventilador mais forte (força 4200, vel 1100). C03 Gancho: alcance 12, passa por cima da plataforma ao chegar,
  salvamento automático caindo sem mirar. E02 Carga Remota: sempre arremessa e GRUDA no rival (senão na superfície).
  E03 Controle Remoto: vigas, andaimes, plataformas sobre estaca e as máquinas da cena. T03 Bola: acelera/freia/vira
  firme, pula ~2 tiles com tolerância e quique no ar. T02 Mecha: garfo 170×130 px e investida que pega quem encostar.
  A07 Marreta-Bumerangue: pose de prontidão com energia girando na ferramenta; voa a ferramenta do próprio robô (com a
  skin) girando com rastro; pegada com tranco e faíscas. T04 Propulsor: fogo sai da mochila (por modelo) e a ferramenta não
  cruza mais a cabeça no voo.
- G06 Entulho 7 caixas; G03 gravidade 0,38; G04 força 560 / raio 520; G10 Carga Especial = 1–3 ARMADURAS; armaduras com
  peso 7 nas caixas normais (DECIDIDO pela IA: "mais raras" — o usuário pode trocar para "só no evento").

## PENDENTE (precisa de proposta/aprovação)
- T06 Modo Soldador: jogabilidade própria (proposta enviada ao usuário).
- T07 Minirrobô: ideia "altera a estatura" (para mais ou para menos) — opcional.
- E01 Andaime Relâmpago: "talvez melhorar a lógica" — o usuário não definiu o quê.
- G11 Interdição de Área: "morno" — candidato a melhorar.

## 1. Spells — decisões do usuário
| # | Spell | Decisão | Detalhe |
|---|---|---|---|
| 7 | S18 Disco de Corte | **TIRAR** | "nunca vejo aparecendo" |
| 8 | S19 Marreta-Bumerangue | MANTER + **melhorar animação** | hoje não dá para perceber que o robô está equipado (visual na mão) e o arremesso precisa de animação melhor |
| 11 | S07 Turboventilador | MANTER + **mais forte** | "meio chatinho": aumentar a potência, jogar os inimigos mais longe |
| 12 | S08 Gancho de Arrasto | MANTER + **melhorias** | (a) mais alcance; (b) se agarra numa plataforma por baixo, ao chegar no limite o robô passa e sobe em cima dela; (c) uso automático caindo: acha a parede/borda mais próxima e agarra (salvamento) |
| 14 | S21 Laço de Energia | MANTER | está bom |
| 15 | S10 Andaime Relâmpago | MANTER | gosta; talvez melhorar algo na lógica (a definir) |
| 16 | S12 Carga Remota | MANTER + **mudar** | arremessar: se acertar um personagem, GRUDA nele; senão gruda no chão (depois detona no controle) |
| 19 | S28 Escudo de Solda | **TIRAR** | "o que eu mais odeio" |
| 17 | S25 Ponte Dobrável | **TIRAR / rever** | "não tá legal" |
| 18 | S27 Controle Remoto | MANTER + **ampliar** | gosta, mas deve abranger mais coisas (mais alvos/usos que só a viga pendurada) |
| 22 | S15 Bola de Demolição | MANTER + **melhorar controle** | hoje só vai para a frente e é difícil de controlar: melhorar o controle e **permitir pular** (a bola pula) |
| 21 | S14 Mecha Empilhadeira | MANTER + **rever uso** | "legalzinha", mas difícil de acertar o alvo: propor mudança que facilite (alcance/área/assistência de mira) |
| 20 | S13 Armadura Fornalha | MANTER | "muito boa" |
| 24 | S31 Modo Broca | MANTER | "muito bom" |
| 25 | S33 Modo Soldador | MANTER + **diferenciar** | parece uma Fornalha com eletricidade; precisa de jogabilidade própria (variar mais) |
| 26 | S34 Minirrobô Veloz | MANTER (ideia) | talvez virar "altera a estatura" — para menos OU para mais (gigante); está bom como está |
| 23 | S16 Propulsor Gambiarra | MANTER + **corrigir animação** | gosta; a animação está um pouco bugada |
| — | demais (#1–6, #9, #10, #13) | sem comentário = MANTER como estão | lista de spells encerrada pelo usuário em 2026-11-25 |

## 2. Eventos — decisões do usuário (2026-11-25)
| # | Evento | Decisão | Detalhe |
|---|---|---|---|
| 29 | G06 Entrega de Entulho | MANTER + **mais quantidade** | "muito simples": mais caixas/entulho |
| 30 | G10 Carga Especial | **MUDAR (grande)** | tem que ser especial de verdade: é o momento em que caem **ARMADURAS** (1, 2 ou 3). Junto: as armaduras (transformações) ficam **raras ou fora** das caixas normais, por serem as mais fortes — definir com o usuário (raridade maior × só no evento) |
| 31 | G12 Troca de Andaimes | MANTER | faz muito sentido com a fase |
| 32 | G13 Cabo Rompido | MANTER | faz muito sentido com a fase |
| 33 | V1 Concretagem | MANTER (o usuário não lembrava) | a grua passa com o balde e despeja concreto em 2 faixas marcadas; quem pisa fica lento e não pula alto |
| 34 | G03 Gravidade em Pane | MANTER + **efeito maior** | aumentar o efeito da gravidade |
| 35 | G04 Sobrecarga Magnética | MANTER + **puxar mais** | aumentar a força que puxa os robôs |
| 36 | G11 Interdição de Área | MANTER (morno) | "não ficou muito bom, mas também não é ruim" — candidato a melhorar |
| 37 | G14 Chuva de Rebites | MANTER | "gostei, é boa" |
| 38 | V2 Desmoronamento | MANTER | pedaços do Térreo despencam pelo poço em faixas marcadas na Fundação |
| 39 | V3 Enchente | MANTER | faz sentido com o mapa |
| 40 | G01 Sirene de Demolição | MANTER | "muito bom" — hoje é a ferramenta do diretor de destruição (sirene + fita → o trecho cede) |
| 41 | G09 Inspeção de Segurança | **TIRAR do jogo** | não gostou (já estava fora do Canteiro) → REPROVADO |
| 27, 28 | G02 Ventania, G05 Operação Guindaste | sem comentário = MANTER | |
