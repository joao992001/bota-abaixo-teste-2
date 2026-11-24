# Cartilha do MAPA — modo Derruba (PROPOSTA, aguardando aprovação)

> Estado: **conceito aprovado pelo usuário (2026-11-24)**: cena viva em 2 etapas, virada "a obra cede" (todos caem numa
> animação de queda e a luta continua embaixo), fundo muito mais animado e detalhado, MAIS mecanismos e eventos
> ESPECÍFICOS de cada fase, tudo catalogado por fase antes de construir. Números ainda em aprovação. Quando aprovado e
> aplicado ao Canteiro, vira o manual `mapa.md` (mesmo formato dos outros manuais). Esquema visual:
> `art/out/cartilha_mapa_derruba.png` (gerado por `art/src/cenarios/cartilha_mapa.py`).

## 1. Ideia central: a fase é uma CENA VIVA em ATOS
Jogar uma partida é assistir (e destruir) uma cena montada. A fase não é um "chão com plataformas": é um lugar que
**começa de um jeito, se transforma com a demolição e muda de lugar** no meio da luta, com começo, virada e clímax.

| Momento | O que o jogador sente | Na fase |
|---|---|---|
| **Abertura** (Ato 1) | "que lugar legal" — entende o palco em 3 s | palco completo, fundo vivo, mecanismos calmos |
| **Escalada** | a luta destrói o lugar | trechos caem, eventos, mecanismos acordam |
| **Virada** (transição) | "UAU" — cena de 2–3 s | o lugar cede/sobe/desce e leva todos para outra região |
| **Clímax** (Ato 2) | tudo mais perigoso | outra arte, palco menor/mais alto, mecanismo novo |

## 2. Anatomia da cena (5 camadas de profundidade)
| Camada | O que é | Regras |
|---|---|---|
| **C0 Céu / horizonte** | cor do céu, luz do horário, silhueta-assinatura da fase | rola bem devagar (paralaxe 0,1); pode mudar de horário entre os atos |
| **C1 Fundo distante vivo** | cidade, gruas girando, trem passando, pássaros, fumaça | sempre algo se mexendo; pouca saturação; nunca parecido com plataforma |
| **C2 Fundo próximo** | estruturas grandes NÃO jogáveis, máquinas trabalhando, robôs-operários NPC, placas | reage à luta (balança quando algo cai, luz pisca na explosão) |
| **C3 PALCO jogável** | tudo que colide, cai, quebra, machuca | o mais contrastado da tela; perigo sempre em amarelo/preto ou vermelho |
| **C4 Primeiro plano** | vigas, fitas, poeira, lâmpadas na frente da câmera | passa na frente; fica transparente quando um robô está atrás; nunca esconde perigo |

## 3. Elementos obrigatórios do PALCO (a cartilha)
Todo mapa do Derruba tem estes 8 elementos (a forma muda por tema; a função não):

| # | Elemento | Função | Regra de medida (proposta) |
|---|---|---|---|
| Z1 | **Núcleo** | lugar de luta garantido | ≥ 25% da largura; nunca cai no Ato 1 |
| Z2 | **Base demolível** | o chão muda com a luta | ≤ 60% do chão pode cair no Ato 1; cai em trechos, com aviso |
| Z3 | **Estruturas elevadas demolíveis** | altura, rotas e quedas | 2–4 peças (andaime, viga, passarela…); dá para alcançar com pulo duplo |
| Z4 | **Bordas e KO** | o perigo de sair | KO nos 4 lados, no mundo (nunca pela câmera); beira legível |
| Z5 | **Rotas de volta** | quem é arremessado pode voltar | ≥ 2 por lado (borda agarrável, cabo, escada, plataforma baixa) |
| Z6 | **Pontos de disputa** | onde nascem caixas e prêmios | 2 fixos (alto e baixo) + variáveis; nunca em cima de nascimento |
| Z7 | **Mecanismos / armadilhas da fase** | profundidade própria do mapa | **3–5 por etapa** (o usuário pediu mais); aviso visível; ritmo próprio; ver §5 |
| Z8 | **Vida de ambiente** | a cena respira | operários NPC, máquinas, luzes, animais; não colide, não confunde |

Nascimentos: 4 por ato, simétricos ou equivalentes, longe de Z7 e da base que cai.

## 4. Atos e transição
- **2 atos** por mapa (o 3º, curto, fica como opção para depois).
- **Gatilho da virada** (o que vier primeiro): ~60% da estrutura demolível caída **ou** ~90 s de rodada.
  Aviso de 3 s: sirene geral, a câmera recua, faixa "A OBRA VAI CEDER!".
- **Transição (2–3 s, cinematográfica):** ninguém é eliminado, todos ficam invulneráveis, a câmera fica travada no
  enquadramento da cena, o Amassômetro e as spells continuam. Os robôs chegam juntos ao Ato 2, cada um num nascimento do
  ato novo.
- **Ato 2:** mesmo tema, OUTRA região com outra arte e outra composição (§6), palco um pouco menor ou mais perigoso,
  1 mecanismo novo. Eventos continuam, com a lista própria do ato.
- **Rodada seguinte** começa de novo no Ato 1.

## 4b. Eventos são DA FASE
Os eventos globais (G01–G14) viram uma **biblioteca**: cada fase escolhe, por etapa, quais eventos da biblioteca usa e
cria os seus **eventos específicos** (ex.: Concretagem no Térreo, Enchente na Fundação). A lista por etapa fica no
catálogo da fase.

## 4c. Catálogo da fase (obrigatório antes de construir)
Cada fase tem um documento `docs/fases/derruba/fN_<nome>.md` com, **para cada etapa**: ficha (composição, paleta,
horário, assinatura, câmera, som), catálogo de **estruturas (E)**, de **demolições (D)**, de **mecanismos (M)**, de
**eventos (V)** e do **fundo vivo (A, camadas C0–C4)**, mais o **storyboard da virada**. Exemplo: `f1_canteiro.md`.
Ordem de trabalho: catálogo aprovado → prancha de arte aprovada → código.

## 5. Mecanismos e armadilhas (Z7)
- São **da fase** (diferentes dos eventos globais, que valem para todas): cada mapa tem os seus.
- Sempre **avisam** (luz, som, peça se mexendo) antes de machucar; têm **ritmo legível** (ciclo fixo ou gatilho claro).
- **Interagem**: o jogador pode acionar, travar ou aproveitar (marretada, Controle Remoto S27, arremessar alguém contra).
- Golpe do mecanismo é do ambiente (`by = -1`), a não ser que um jogador o acione (aí o crédito é de quem acionou).
- Nunca decidem um KO sozinhos sem chance de reação; a Inspeção (G09) os pausa.

## 6. Composições (além do tema)
Cada ato escolhe uma composição — é o que faz dois mapas do mesmo tamanho jogarem diferente:
| Composição | Desenho | Sensação |
|---|---|---|
| **Ponte** | palco largo com vãos embaixo | empurrar para o buraco |
| **Torre** | vertical, andares | subir, cair de andar em andar |
| **Bacia (U)** | bordas altas, meio baixo | luta concentrada no fundo |
| **Ilhas** | 3–4 plataformas soltas | pulos, controle de espaço |
| **Plataforma em movimento** | o palco anda (elevador, guindaste, esteira) | correr contra o cenário |

Regra: Ato 1 e Ato 2 do mesmo mapa usam **composições diferentes**.

## 7. Direção de arte (padrão comum, flexível por mapa)
- Papel e giz em tudo; **cada mapa** tem: paleta de 3 cores próprias + cores fixas de perigo (amarelo/preto zebrado,
  vermelho), uma **silhueta-assinatura** no horizonte e um **horário/clima** por ato.
- Legibilidade: palco (C3) mais escuro/contrastado e mais saturado que o fundo; fundo com menos detalhe nos tons do palco.
- Riqueza: peças do palco com 3+ variações (sujeira, rachadura, remendo, placas); props em C2/C4 que contam a história do
  lugar; nada de superfície lisa grande.
- Som de ambiente por ato (máquinas, vento, sirenes distantes).

## 8. Ficha de mapa (preencher antes de desenhar)
```
Nome / tema / silhueta-assinatura / paleta (3 cores) / horário Ato 1 → Ato 2
Ato 1: composição · Z1..Z8 (quais peças) · mecanismos (2–3) · nascimentos · pontos de disputa
Virada: gatilho · cena da transição (o que acontece na tela)
Ato 2: composição · Z1..Z8 · mecanismo novo · nascimentos
Eventos: quais funcionam em cada ato · câmera (margens/zoom por ato) · som de ambiente
```

## 9. Exemplo: CANTEIRO DE OBRAS refeito com a cartilha — ESCOLHIDA A VIRADA A (catálogo completo em `docs/fases/derruba/f1_canteiro.md`)
**Ato 1 — Térreo da obra (composição Ponte):** o palco de hoje (laje em trechos, núcleo, andaimes, vigas penduradas)
+ fundo vivo: cidade ao longe, 2 gruas girando, betoneira girando, robôs-operários carregando tábuas, caminhão de entrega.
Mecanismos: **betoneira** que gira e despeja concreto (chão que gruda por alguns segundos) e **elevador de obra** de
cremalheira (sobe e desce no ritmo; dá carona ou esmaga contra a viga se você bobear).

**Virada — duas opções:**
- **A) "A obra cede" → Ato 2 SUBSOLO / FUNDAÇÃO (composição Bacia):** a laje inteira desaba numa cena de poeira; todos
  caem para a fundação: escura, estacas, canos, lâmpadas penduradas, água no fundo. Mecanismo novo: **bate-estaca gigante**
  que martela em ciclo.
- **B) "Subiu a laje" → Ato 2 COBERTURA (composição Ilhas):** a grua iça o núcleo com todo mundo em cima até o topo do
  prédio: céu de fim de tarde, vento, vigas soltas, outdoor. Mecanismo novo: **contrapeso da grua** que passa varrendo.

## 10. Próximos passos (depois da aprovação)
1. Você aprova/ajusta esta cartilha (números, 2 atos, gatilho) e escolhe A ou B para o Canteiro.
2. Prancha visual do Canteiro nos 2 atos (camadas C0–C4, Z1–Z8, mecanismos) para aprovar antes do código.
3. Código: sistema de atos e transição (genérico, serve para todo mapa), camadas de fundo vivo, mecanismos do Canteiro.
4. Com o Canteiro aprovado jogando, esta cartilha vira o manual `mapa.md`.
