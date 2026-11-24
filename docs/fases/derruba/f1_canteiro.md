# FASE 1 do Derruba — CANTEIRO DE OBRAS · Catálogo (PROPOSTA para aprovar antes de construir)

Segue a cartilha `docs/manuais/derruba/mapa_cartilha.md`. Duas etapas na mesma partida:
**Etapa 1 — TÉRREO DA OBRA** → virada **"A OBRA CEDE"** (todos caem) → **Etapa 2 — FUNDAÇÃO (subsolo)**.
Esquema visual: `art/out/fase1_canteiro_catalogo.png`. Códigos: **E** estrutura · **D** demolição · **M** mecanismo ·
**V** evento · **A** ambiente (fundo vivo). "Motor" = o que já existe no jogo e pode ser reaproveitado.

---
## ETAPA 1 — TÉRREO DA OBRA
**Ficha:** composição **Ponte** (palco largo, vãos embaixo) · mundo 40×22 tiles · manhã ensolarada · paleta céu
`#bfe9ef`, concreto `#d8ccb6`, madeira/laranja de obra `#c98a4b`/`#f08a3d` (+ amarelo/preto de perigo) ·
silhueta-assinatura: **a grua amarela gigante** com o contrapeso em cima do prédio em construção · câmera adaptativa
(margens atuais) · som: britadeira distante, bipes de ré, rádio da obra.

### Estruturas (E)
| Id | Estrutura | Papel na cartilha | Hoje |
|---|---|---|---|
| E1 | Núcleo: 2 trechos de laje sobre pilares | Z1 (nunca cai na Etapa 1) | existe |
| E2 | Laje em 4 trechos sobre escoras | Z2 base demolível | existe |
| E3 | Andaimes laterais (2) | Z3 alto + Z5 volta | existe |
| E4 | Vigas penduradas (5: 1 grande no meio, 2 baixas, 2 altas) | Z3 | existe |
| E5 | **Escoras** de madeira sob cada trecho | sustentam E2 (quebrar acelera a queda) | só desenho → vira peça |
| E6 | **Pilha de tubos** de concreto no canto do térreo | obstáculo + munição (D5) | novo |
| E7 | **Passarela de tábuas** entre andaime e viga baixa | Z3 rota alta frágil | novo |
| E8 | **Escada de marinheiro** nas laterais do núcleo | Z5 volta (agarrar e subir) | novo |
| E9 | Bordas agarráveis da laje | Z5 | existe |
| E10 | Pontos de caixa: centro do núcleo (baixo) e viga grande (alto) | Z6 | existe |

### Demolições (D)
| Id | O quê | Como quebra | O que sobra / consequência |
|---|---|---|---|
| D1 | Trecho de laje (E2) | íntegro → rachado → crítico (fita, treme) → cai de vez; marretada pesada, robô arremessado, G01 | pedaços com física; abre vão (KO por baixo) |
| D2 | Andaime (E3) | pesada nas pernas ou impacto forte; tomba **para fora** | tábuas voando; some a rota alta daquele lado |
| D3 | Viga pendurada (E4) | cabo rompe (G13, Controle Remoto S27) | cai e vira plataforma no chão; guindaste repõe |
| D4 | Escora (E5) | 2 pesadas | o trecho de cima vai direto para "crítico" (aviso de 1,5 s) |
| D5 | Pilha de tubos (E6) | 1 pesada solta os tubos | 3 tubos **rolam** para o lado do golpe (empurram quem estiver no caminho) |
| D6 | Passarela (E7) | qualquer golpe pesado ou 2 robôs pulando em cima | quebra no meio, as metades penduram |
| D7 | Caixotes / entulho (G06) | marretada | lascas |

### Mecanismos (M) — 5 na Etapa 1
| Id | Mecanismo | Funcionamento | Aviso | Interação | Motor |
|---|---|---|---|---|---|
| M1 | **Betoneira** (térreo, esquerda) | o tambor gira; a cada ~14 s inclina e despeja **concreto fresco** numa faixa: quem pisa anda devagar e não pula alto por 3 s; endurece em 6 s | tambor acelera, bipe, faixa marcada | marretar a alavanca dispara o despejo na hora (armadilha) | novo (usa alçapão/alavanca como base) |
| M2 | **Elevador de obra** (cremalheira, direita) | plataforma sobe e desce do térreo até o andaime em ciclo | luz giratória + sirene curta antes de mexer | dá carona; para se algo bloquear (nunca esmaga); é rota de volta | plataformas móveis |
| M3 | **Esteira de entulho** (embaixo do andaime esquerdo) | carrega quem está em cima para fora da arena | setas piscando; inverte a cada ~7 s | marretar o botão inverte na hora | esteira `<` `>` |
| M4 | **Pilha de tubos** (E6/D5) | arma de cenário: rolam ao ser marretados | tubo balança quando alguém encosta | o jogador escolhe o lado | barris rolando |
| M5 | **Serra de bancada** (sobre a passarela E7) | a lâmina sobe da bancada em ciclo (2 s ligada / 4 s desligada) | ronco crescente + faíscas | Inspeção (G09) desliga; passar por cima embaixo da lâmina | serra |

### Eventos (V) — biblioteca → Etapa 1
G01 Sirene de Demolição · G05 Operação Guindaste · G06 Entrega de Entulho · G10 Carga Especial · G12 Troca de Andaimes ·
G13 Cabo Rompido · G02 Ventania · G09 Inspeção. **Específico novo:** **V1 Concretagem** — a grua passa com o balde e
despeja concreto em 2 faixas marcadas (combina com M1).

### Fundo vivo (A)
| Camada | Conteúdo e animação |
|---|---|
| C0 | céu de manhã, nuvens andando, **grua gigante** (assinatura) girando devagar o braço |
| C1 | prédio em construção com andares sendo montados (luzes de solda piscando), cidade ao longe, 2º guindaste, pássaros |
| C2 | robôs-operários carregando tábuas e empurrando carrinho de mão, caminhão betoneira entrando e saindo, placas "USE EPI", cerca de tapume com logo da obra; **reagem**: olham e se encolhem quando algo cai, poeira cai do prédio no tremor |
| C4 | fita zebrada e lâmpadas de obra no primeiro plano, vigas passando na frente |

---
## VIRADA — "A OBRA CEDE" (storyboard)
| Tempo | Tela |
|---|---|
| Gatilho | ~60% das estruturas demolíveis caídas **ou** ~90 s de rodada |
| −3,0 s | sirene geral, rachaduras correndo por TODA a laje (inclusive o núcleo), poeira caindo do teto, faixa **"A OBRA VAI CEDER!"**, a câmera recua |
| 0 s | o chão inteiro se parte em pedaços grandes |
| 0 → 2 s | **QUEDA:** a câmera desce junto; robôs caem girando entre pedaços de laje (dá para se mexer um pouco no ar); as camadas do Térreo sobem e saem, as da Fundação entram (lâmpadas penduradas passando na frente) |
| 2 s | pouso com nuvem de poeira e tremor; pedaços da laje caem por cima e viram plataformas inclinadas (continuidade!) |
| 2 → 3 s | invulneráveis; controle volta; faixa **"FUNDAÇÃO!"** |
Regras: ninguém é eliminado na queda; vidas, Amassômetro e spells continuam; quem estava eliminado nasce embaixo.
Implementação proposta: **o mesmo mundo, com a Fundação logo abaixo do Térreo** (a câmera desce de verdade e os pedaços
caem fisicamente), em vez de trocar de mapa.

---
## ETAPA 2 — FUNDAÇÃO (subsolo)
**Ficha:** composição **Bacia** (paredes altas, luta no fundo) · ~34×18 tiles · escuro com luz de lâmpadas e de cima
(o buraco da laje) · paleta concreto escuro `#5d6b7d`, ferrugem `#a8582e`, água `#4f86a8`, luz `#ffe7a8` ·
assinatura: **o buraco no teto** com o céu e a grua lá em cima · câmera mais fechada (palco menor = mais perigo) ·
som: goteiras, eco, bomba d'água.

### Estruturas (E)
| Id | Estrutura | Papel |
|---|---|---|
| E11 | Piso da fundação (centro) | Z1 (nunca cai) |
| E12 | **Grelha do poço de drenagem** no meio do piso | Z2: demolível → abre um **buraco de KO** no centro |
| E13 | **Blocos de fundação** (degraus nas laterais) | Z3 alturas |
| E14 | **Estacas** de concreto (3) sustentando plataformas altas | Z3; demolíveis (D9) |
| E15 | **Vigas baldrame** (plataformas médias) | Z3 |
| E16 | Pedaços da laje do Térreo (caídos na virada) | plataformas inclinadas temporárias |
| E17 | Paredes de contenção com bordas agarráveis + escadas de marinheiro | Z5 volta |
| E18 | Pontos de caixa: centro do piso e plataforma alta | Z6 |
KO: em cima (acima das paredes, voando para fora pelo buraco), nas laterais acima das paredes e **no poço** quando aberto.

### Demolições (D)
| Id | O quê | Como | Consequência |
|---|---|---|---|
| D8 | Grelha do poço (E12) | 3 pesadas | abre o buraco de KO no centro (com fita e aviso antes de abrir) |
| D9 | Estaca (E14) | 2 pesadas | a plataforma de cima **inclina** e depois cai |
| D10 | Paredes de contenção | robô arremessado forte | pedaços soltam e viram degraus novos |
| D11 | Lâmpadas penduradas | golpe | caem e apagam um trecho por alguns segundos (só o fundo escurece; palco continua legível) |
| D12 | Pedaços da laje (E16) | marretada | se partem |

### Mecanismos (M) — 4 na Etapa 2
| Id | Mecanismo | Funcionamento | Aviso | Interação | Motor |
|---|---|---|---|---|---|
| M6 | **Bate-estaca gigante** | martela uma faixa em ciclo (esmaga e empurra para baixo) | sombra + o martelo sobe tremendo | marretar a trava segura uma batida | pistão |
| M7 | **Alagamento** | a água sobe no fundo da bacia em ciclo (anda devagar dentro; não mata) e baixa | goteiras aumentam, marca de nível na parede | marretar o **registro da bomba** drena na hora | maré (lama) adaptada |
| M8 | **Vagonete no trilho** | passa varrendo o piso de um lado a outro | buzina + farol | dá para pular em cima e pegar carona | serra no trilho / bola |
| M9 | **Gerador com cabos** | os cabos faíscam em ciclo; se a água (M7) estiver alta, a água dá choque leve | faísca + zumbido | marretar o gerador desliga por 8 s | chama (ciclo) |

### Eventos (V) — biblioteca → Etapa 2
G14 Chuva de Rebites (cai pelo buraco do teto) · G04 Sobrecarga Magnética (do gerador) · G06 Entrega de Entulho
(despejado pelo buraco) · G10 Carga Especial · G03 Gravidade em Pane · G11 Interdição. **Específicos novos:**
**V2 Desmoronamento** — pedaços do Térreo despencam pelo buraco em faixas marcadas · **V3 Enchente** — a bomba falha e a
água (M7) sobe alta por alguns segundos.

### Fundo vivo (A)
| Camada | Conteúdo e animação |
|---|---|
| C0 | o **buraco no teto** com o céu e a grua lá em cima; poeira caindo em feixes de luz |
| C1 | túneis e galerias escuras, canos grossos, lanternas de robôs-operários lá longe |
| C2 | robôs-mineradores com capacete de lanterna, ratos-robô correndo, bombas d'água pulsando, placas "PERIGO: ALAGAMENTO" |
| C4 | lâmpadas penduradas balançando na frente da câmera, gotas caindo, cabos |

---
## O que precisa ser aprovado
1. As listas de cada catálogo (estruturas, demolições, mecanismos, eventos e fundo) das duas etapas: tirar, trocar ou
   acrescentar.
2. Os números iniciais: virada com 60% caído ou 90 s; 5 mecanismos na Etapa 1 e 4 na Etapa 2.
3. A forma de construir: Fundação no mesmo mundo, embaixo do Térreo.
Depois disso: **prancha de arte** das duas etapas (fundo detalhado + palco + mecanismos) e só então o código.
