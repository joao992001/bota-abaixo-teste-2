# BOTA-ABAIXO
## Proposta de reformulação conceitual do modo DERRUBA
**Versão:** 1.0 — documento para análise e validação pelo Claude  
**Data:** 25 de novembro de 2026  
**Situação:** proposta do usuário para validação; **não é autorização para modificar o jogo sem aprovação**.

> **Mensagem central ao Claude**  
> O objetivo é transformar o Derruba em um modo competitivo local, futuramente extensível ao online, cuja rejogabilidade seja sustentada por mapas com rotas condicionadas à destruição, seleções visuais de spells e modificações, recompensas de progressão e descobertas entre partidas. Leia as regras abaixo, confronte-as com o projeto real, identifique incompatibilidades e recomende uma migração segura. **Não implemente tudo de uma vez nem transforme hipóteses em decisões aprovadas.**

---

## 1. Finalidade e escopo

Este documento apresenta a mudança de visão aprovada conceitualmente pelo usuário após uma discussão aprofundada sobre a rejogabilidade. Em vez de priorizar novos modos ou distinguir mecanicamente todos os personagens, o projeto deverá explorar a profundidade de **um único modo principal: Derruba**. Os robôs, controles, ataques, esquivas, dano, knockback e mecanismos já existentes formam a base a preservar, salvo quando uma mudança for necessária e aprovada.

A estratégia de rejogabilidade passa a ter três fontes complementares:

1. **Variedade dentro de um mapa:** cenas diferentes, alcançadas por rotas definidas pela intensidade da destruição, sem obrigação de percorrê-las todas.
2. **Personalização da partida:** o anfitrião escolhe, com uma interface visual e por controle, o conjunto de spells e modificações/eventos que poderá ocorrer.
3. **Progressão persistente:** a conta desbloqueia spells, skins e modificações por uma gangorra de recompensas, e novos mapas por pontos de exploração; cenas internas de um mapa são descobertas ao visitá-las.

**Não é escopo deste documento:** reinventar o combate, produzir novos modos de jogo, implementar imediatamente o multiplayer online ou criar muitos mapas/spells novos antes da validação da arquitetura.

## 2. Hierarquia e vocabulário obrigatórios

**JOGO → MODO → MAPA → NÍVEL DE PROFUNDIDADE → CENA → ELEMENTOS.**

- **Jogo:** BOTA-ABAIXO.
- **Modo:** Derruba, com vitória por eliminação dos oponentes.
- **Mapa:** experiência temática escolhida no menu, com biblioteca de spells, eventos, mecanismos e cenas.
- **Nível de profundidade:** posição de progressão dentro do mapa; não é um mapa novo nem uma rodada independente.
- **Cena:** arena física jogável em um nível; um nível pode oferecer cenas alternativas.
- **Rota A/B:** destino alternativo na próxima profundidade, condicionado à destruição da cena atual.
- **Modificação/evento:** ocorrência selecionável do mapa que altera suas condições e/ou oferece acontecimentos; não substitui a regra universal de transição.
- **Desbloqueio de conta:** conteúdo adquirido permanentemente, distinto do conteúdo escolhido pelo anfitrião para uma partida.

Evitar trocar os termos *fase*, *mapa*, *nível* e *cena* ao documentar as regras, pois seu uso ambíguo provoca erros de implementação.

## 3. Fluxo de navegação da experiência

**JOGAR → MODOS → DERRUBA → MAPAS → SELEÇÃO DE SPELLS → SELEÇÃO DE MODIFICAÇÕES/EVENTOS → PERSONAGENS/SKINS → PARTIDA → RESULTADOS → REVANCHE / RECONFIGURAR / MENU PRINCIPAL.**

### 3.1. Seleção de mapa
- Exibir mapas disponíveis e bloqueados com artes e identificação visual.
- No online, somente os mapas desbloqueados na conta do **anfitrião** estarão disponíveis para seleção da sala.
- No multiplayer local, a conta responsável pela sessão determina os mapas disponíveis.
- Exibir o progresso para liberar novos mapas **no menu de seleção de mapas**, não no HUD de combate.

### 3.2. Seleção de spells
- Tela **animada, lúdica, legível e operável por controle**, sem dependência de textos extensos.
- Mosaico de quadrados/cartas com ícones; classes distinguidas preferencialmente por cores e legendas discretas, **sem obrigatoriedade de abas**.
- Spell desbloqueada: ícone reconhecível; spell bloqueada: interrogação, silhueta ou cadeado.
- Ao pressionar confirmar sobre uma spell, alternar **acesa/selecionada** ↔ **apagada/não selecionada**.
- Oferecer opção **Aleatório**; quantidade máxima de escolhas e regras de composição ainda devem ser especificadas.
- A seleção não equipa simultaneamente os robôs: define o **conjunto permitido para sorteio/caixas durante a partida**, preservando o funcionamento de spells já existente.
- Uma spell pessoalmente bloqueada para o convidado pode aparecer na partida se o anfitrião a tiver desbloqueado e habilitado; isso não a desbloqueia permanentemente na conta do convidado.

### 3.3. Seleção de modificações/eventos
- Segunda tela visual, no mesmo padrão de seleção por mosaico.
- Permitir **escolha manual**, **aleatório** e **nenhum evento opcional**.
- Mostrar itens bloqueados e desbloqueados. O anfitrião configura somente elementos desbloqueados na sua conta e compatíveis com o mapa.
- Alguns eventos alteram regras/condições ambientais (ex.: baixa gravidade) e outros criam acontecimentos; ambos podem afetar indiretamente a destruição.
- **Não confundir eventos opcionais com mecanismos essenciais de uma cena**: a opção 'nenhum' não pode invalidar a geometria, as transições ou a jogabilidade.
- Eventos e spells **não são gatilhos independentes de mudança de cena** na proposta atual. Sua influência é indireta: podem aumentar ou reduzir o dano estrutural alcançado dentro do tempo.

### 3.4. Personagens e skins
- Depois das configurações do mapa, cada participante escolhe seu robô e sua skin.
- Robôs mantêm a base de gameplay estabelecida, sem introduzir diferenças mecânicas como parte desta proposta.
- **Skins constituem exceção à autoridade do anfitrião:** no online, cada jogador pode usar qualquer skin que tenha desbloqueado na **própria conta**, independentemente do inventário do anfitrião.
- Incluir opção de preparar/repetir configuração para que a revanche não exija percorrer novamente todas as telas.

## 4. Organização de mapas e cenas

### 4.1. Estrutura desejada
- Trabalhar, em princípio, com mapas de **quatro ou seis cenas possíveis**.
- Mapas de quatro cenas: objetivo de **até dois níveis de profundidade**.
- Mapas de seis cenas: objetivo de **até três níveis de profundidade**.
- As transições avançam **somente para o próximo nível**, nunca livremente da primeira para a última cena.
- Em cada transição, o jogador alcança **uma entre duas rotas possíveis**, A ou B, de acordo com a destruição.
- Não é obrigatório mudar de nível em toda partida. O combate pode terminar na cena inicial ou intermediária.
- A cena final não contém transições adicionais; continua até que exista um vencedor.
- A configuração de início em uma cena previamente descoberta foi discutida como **opção avançada**, mas não deve ser inserida no fluxo principal sem nova validação.

### 4.2. Importante incompatibilidade matemática — validar antes de codificar

**Quatro cenas totais + dois níveis + exatamente dois destinos a partir de uma única cena inicial não fecham naturalmente uma distribuição de quatro cenas distintas**: 1 cena inicial + 2 alternativas finais = 3 cenas. A estrutura de seis cenas pode comportar uma cena inicial, duas intermediárias e três finais, desde que algumas rotas compartilhem destino.

O Claude deve apresentar **alternativas explícitas de grafo** que mantenham o propósito de quatro e seis cenas sem introduzir saltos ou uma terceira rota não autorizada. O usuário precisará aprovar a topologia antes de alterar o manifesto e os arquivos `.lvl`.

### 4.3. Canteiro de Obras
- O mapa existente possui atualmente duas cenas: **Térreo da Obra → Fundação**.
- O usuário prevê **adicionar duas cenas** para adequá-lo à proposta de quatro cenas.
- O conceito, a estética, a destruição, os mecanismos e as transições cinematográficas já aprovados devem ser preservados sempre que compatíveis.
- As duas cenas adicionais deverão receber fichas, layouts, artes conceituais, catálogo de estruturas, transições, biblioteca de eventos/spells e testes antes de serem implementadas.
- A integração entre duas cenas antigas e duas novas **depende primeiro da decisão sobre a topologia de quatro cenas**.

## 5. Regra universal de transição de cenas

**O tempo determina QUANDO verificar. O percentual de destruição determina PARA QUAL ROTA avançar.**

Uma transição só é avaliada quando a luta ainda está em andamento e a cena tem um próximo nível.

| Situação na verificação | Comportamento |
|---|---|
| Destruição elegível **abaixo de 50%** | Permanecer na mesma cena; nova verificação após **30 s**. Repetir se necessário. |
| Destruição **≥ 50% e < 90%** | Executar a transição para **Rota A** (menor destruição). |
| Destruição **≥ 90%** | Executar a transição para **Rota B** (maior destruição). |
| Todos os rivais eliminados antes da verificação | A partida termina; **não há transição obrigatória**. |
| Cena no último nível | Nenhuma transição; a partida continua até o vencedor. |

- **Primeira verificação de referência: 90 segundos**, contados desde o ingresso na cena. Cada cena pode ter tempo configurável, levando em conta tamanho da arena, estruturas elegíveis e resistentes, ritmo e mecanismos. Os 90 s são padrão inicial, não valor fixo universal.
- As verificações adicionais ocorrem em intervalos de **30 segundos**, enquanto o percentual permanecer abaixo de 50% e a partida não terminar.
- Se chegar a 90% antes da primeira verificação, a transição **não acontece antecipadamente**; aguarda-se a verificação, salvo novo ajuste aprovado.
- A contagem é interna e **não há cronômetro no HUD**.
- A nova cena reinicia a contagem de tempo e a sua própria medição de destruição.
- A destruição usa apenas elementos **elegíveis**, excluindo base fixa/indestrutível. A fórmula de peso por HP atualmente adotada deve ser auditada antes da migração.
- O modo Derruba continua decidido por **eliminação (KO)**; chegar ao nível seguinte nunca é condição para vencer.
- As transições devem preservar a sensação física de deslocamento, desabamento e câmera conforme a identidade da cena; não devem ser teletransportes arbitrários.

### 5.1. Conflito com a lógica atual — prioridade de auditoria

Atualmente o projeto documenta uma transição automática ao atingir 90% de destruição e um **diretor adaptativo que pode causar demolição espontânea**. Isso **não equivale** à proposta nova, que avalia 50/90% no relógio e usa o resultado da destruição como escolha de rota.

O Claude deverá examinar se a deterioração automática compromete o princípio de que a rota é influenciada pelo **mérito/comportamento destrutivo dos jogadores**. Não remover o diretor às cegas: apresentar alternativas (desativação no novo modo, contagem diferenciada de dano induzido, regulação conservadora, etc.) com consequências de gameplay.

## 6. HUD do combate — decisão restritiva

**Durante a partida, a interface deve mostrar apenas:**
1. Os retratos dos jogadores e seus percentuais de dano, já presentes no HUD existente.
2. **Um manômetro circular central no topo** indicando, em tempo real, o percentual de destruição da **cena atual**.

**Não exibir durante o combate:** cronômetro das verificações, barra de gangorra/recompensa, barra de exploração, medidores de desbloqueio, objetivos de missão ou novos painéis persistentes.

O manômetro possuirá **seis zonas cromáticas gradativas**, do verde intenso ao vermelho intenso: três bandas do lado de menor destruição e três do lado de maior destruição. Agulha analógica/circular, resposta clara ao aumento de dano estrutural; atualização/reinicialização na troca de cena. Limites cromáticos e escalas devem ser testados, preservando legibilidade e acessibilidade.

## 7. Gangorra de recompensas persistentes

### 7.1. Conceito
- Cada conta possui **um medidor bipolar único**, inicialmente centrado.
- Na extremidade verde há **uma recompensa surpresa identificada apenas pela categoria**; na extremidade vermelha, outra recompensa, também misteriosa.
- Categorias elegíveis: **skin, spell, modificação/evento de mapa**. **Mapas não participam** deste sorteio.
- A agulha avança em uma direção e pode recuar por resultados contrários. Não são duas barras independentes.
- Ao alcançar um dos extremos, revelar uma recompensa ainda bloqueada daquela categoria, gravá-la permanentemente na conta e gerar novas opções conforme regras a validar.
- O resultado pertence à conta; online, cada usuário possui sua própria gangorra e pode estar buscando prêmio diferente na mesma partida. Localmente, pertence à conta que iniciou a sessão.

### 7.2. Seis faixas e contribuições — parâmetros provisórios

| Faixa de resultado | Movimento sugerido no medidor (-100 a +100) |
|---|---:|
| Verde intenso — destruição muito baixa | **−75** |
| Verde claro — destruição baixa | **−35** |
| Amarelo — destruição moderada baixa | **−15** |
| Laranja — destruição moderada alta | **+15** |
| Vermelho claro — destruição alta | **+35** |
| Vermelho intenso — destruição muito alta | **+75** |

**Essas contribuições surgiram como exemplos, e os intervalos percentuais de destruição por cor ainda NÃO foram aprovados.** É necessário calibrar a probabilidade de ocorrência real das seis faixas, evitando que uma direção seja muito mais difícil de alcançar.

A apuração acontece nas conclusões válidas de cenas e/ou no término da partida; **a definição exata do que constitui uma apuração válida, especialmente em KO precoce e cenas finais, permanece pendente**. Não decidir por suposição. O conceito essencial aprovado é a gangorra com progressão/punição em sentidos opostos.

### 7.3. Apresentação
- **Nada da gangorra no HUD de combate.**
- Na tela de resultados, **logo abaixo do vencedor**, apresentar uma animação da agulha sendo puxada para o lado correspondente, com seu progresso antes/depois.
- Se houver desbloqueio, revelar a categoria e o item, com destaque visual e marcador **NEW**; gravar o resultado na conta adequada.
- Duas recompensas simultâneas ficam conhecidas **por categoria**, mas seus conteúdos exatos permanecem ocultos.
- Premiações engraçadas por desempenho (ex.: maior demolição, mais golpes) são um elemento comemorativo possível, **não substituem** as recompensas persistentes.

## 8. Desbloqueio de novos mapas — Projetos de Demolição

**Sistema separado da gangorra.** A conta acumula pontos de exploração, que eventualmente permitem desbloquear **um novo mapa à escolha**; não há sorteio de mapas.

| Resultado | Crédito inicial de referência |
|---|---:|
| Partida válida concluída | **+1 ponto** |
| Cena inédita realmente visitada pela conta | **+2 pontos adicionais**, uma vez por cena |
| Revisitou cena conhecida | Sem bônus de descoberta |

O usuário aprovou o **princípio** e o padrão visual de créditos +1/+2. A quantidade exigida para um desbloqueio (por exemplo, 6 pontos), a economia entre mapas e regras antifarming ainda dependem de balanceamento.

- Progressão **por conta**: no online todos acumulam individualmente, mesmo convidados em mapa do anfitrião ainda bloqueado em suas contas.
- O mapa não se desbloqueia automaticamente ao entrar numa sala alheia: os pontos são utilizados pela própria conta posteriormente.
- As **cenas internas** são descobertas ao visitá-las; isso é diferente de adquirir um novo **mapa**.
- Mostrar essa barra **na seleção de mapas** e **abaixo da gangorra na tela de resultados**; jamais como HUD permanente de combate.

## 9. Regras de multiplayer e inventários

| Conteúdo ou capacidade | Online — quem decide? | Local — quem decide? |
|---|---|---|
| Mapa disponível na sala | **Desbloqueios do anfitrião** | Conta responsável pela sessão |
| Spells oferecidas no mapa | **Biblioteca e desbloqueios do anfitrião** + compatibilidade | Conta responsável + compatibilidade |
| Modificações/eventos opcionais | **Desbloqueios e seleção do anfitrião** + compatibilidade | Conta responsável + compatibilidade |
| Regras da sala | **Anfitrião** | Conta responsável |
| Robô e skin | **Cada participante**, skin da própria conta | Jogadores escolhem robô; skins da conta responsável, salvo futuro suporte a perfis locais |
| Gangorra e progresso de exploração | **Individual por conta** | Conta responsável pela sessão |

Convidados podem utilizar spells ativas no conjunto definido pelo anfitrião, mesmo sem possuí-las em seus inventários pessoais. A utilização temporária **não é desbloqueio definitivo**. Skins são a exceção: a personalização cosmética individual via conta é permitida a cada participante.

**O online permanece como visão e contrato conceitual para evolução futura.** O arquivo `CLAUDE.md` atualmente proíbe adicionar online sem autorização. Não iniciar implementação de rede, autenticação ou sincronização agora. O Claude deve indicar o que precisa ser preparado no desenho dos dados sem antecipar essas funcionalidades.

## 10. Tela de resultados e ciclo de revanche

A sequência proposta é:

1. Mostrar o **vencedor**, mantendo a celebração/totem e eventuais títulos cômicos individuais.
2. Abaixo, animar a **gangorra de recompensas** com o delta gerado pela partida e eventual revelação do item.
3. Abaixo, apresentar **Projetos de Demolição**: pontuação da partida (+1), cenas inéditas (+2 cada) e progresso acumulado para o próximo mapa.
4. Oferecer **Jogar novamente** (mesmo mapa e mesmas configurações), **Modificar configurações** (voltar às seleções de spells/eventos do mesmo mapa) e **Menu principal**.

A experiência deve ser visual, rápida, navegável por controle e legível para 2–4 jogadores na mesma tela; a entrega de resultados individuais online deve respeitar as contas separadas.

## 11. Inventário de impacto esperado no projeto existente

Esta seção registra **pontos de inspeção**, não declara que os arquivos já implementam a proposta. Conferência de leitura realizada no repositório público de testes em 25/11/2026.

| Área | Referências atuais para auditoria | Mudança esperada |
|---|---|---|
| Regras e supervisão | `CLAUDE.md`, `docs/ESTADO.md`, `docs/GDD.md`, `docs/decisoes.md` | Registrar nova visão, remover contradições de status por processo de aprovação |
| Manual geral e Derruba | `docs/manuais/README.md`, `docs/manuais/sistema_criacao.md`, `docs/manuais/derruba/README.md`, `docs/manuais/derruba/mapa.md`, `mapa_cartilha.md` | Novo método de criação de mapas com níveis, rotas e verificações por tempo |
| Biblioteca do Canteiro | `docs/fases/derruba/f1_canteiro/`, `data/mapas/derruba/canteiro_obras.json`, `levels/canteiro_obras.lvl` | Evolução de duas cenas para quatro, após aprovar topologia e artes |
| Orquestração de cenas | `game/modes/etapas.gd`, `game/modes/mapa.gd`, `game/modes/cena.gd` | Passar de próxima cena linear/limiar único para destinos A/B validados por tempo |
| Estruturas/dano | `game/modes/canteiro.gd`, `game/modes/demolicao.gd` | Medição por cena, impactos do diretor e elegibilidade |
| Spells/eventos | `game/modes/spells.gd`, `game/modes/eventos.gd`, `data/modos.json`, manifestos por mapa | Separar biblioteca compatível, inventário desbloqueado e conjunto da sala |
| UI, navegação e HUD | Identificar cenas e scripts reais no projeto Godot | Novas telas visuais; manômetro central; resultados animados; revanche |
| Dados persistentes | Identificar save/configuração existente ou ausência | Gangorra, itens desbloqueados, cenas visitadas, pontos/mapas liberados e configurações anteriores |
| Testes | `game/tests/driver.gd` e testes do modo | Regressão de KOs, transições, persistência, seleção e cenários-limite |

### 11.1. Divergências já observadas
- A documentação atual indica **transição imediata aos 90%**, em vez da avaliação aos 90 s e prorrogações de 30 s.
- O código atual usa **progressão sequencial**, ao passo que a proposta pede rotas condicionais A/B.
- O diretor adaptativo atual pode fazer estruturas caírem sozinho; isso pode interferir na leitura de mérito dos jogadores.
- Existem arquivos de documentação com referência histórica a transição cronometrada; auditar estados e atualizar sem perder rastreabilidade.
- O online está explicitamente fora de escopo no `CLAUDE.md` existente; manter apenas especificação futura até uma autorização independente.

## 12. Regras de migração e preservação

1. **Repositório de trabalho:** `joao992001/bota-abaixo-teste-2`. **Não modificar:** `joao992001/bota-abaixo` (base estável).
2. A primeira entrega do Claude deve ser **somente de análise de viabilidade**, sem alteração de manuais e código, até o usuário aprovar a proposta revisada.
3. Após essa aprovação, abrir etapa/branch de **estruturação documental no GitHub**: atualizar hierarquia, manuais, biblioteca, esquema de manifesto, checklist e estado do projeto, preservando histórico (`APROVADO`, `PROPOSTO`, `SUBSTITUÍDO` etc.).
4. Depois da estruturação, elaborar plano conceitual detalhado das mudanças: wireframes de telas/HUD, grafos de quatro/seis cenas, dados de persistência e storyboard de transições. **Submeter para aprovação** antes do código grande.
5. Só então modificar a lógica existente de forma incremental, com commits coerentes, testes específicos e regressão final. Evitar migração total em uma única etapa.
6. Toda mudança visual significativa exige prancha/conceito e aprovação do usuário. **Não reconstruir do zero** componentes aprovados sem necessidade.
7. Preservar arte, áudio, física e fluxo de combate existentes sempre que possível; documentar toda incompatibilidade.
8. Não declarar implementação concluída sem testes. Se não houver acesso à Godot, reportar o que não foi verificado.

## 13. Pontos que o Claude deverá validar, não inventar

**P1 — Topologia:** como cumprir exatamente quatro cenas/dois níveis e seis cenas/três níveis com apenas duas rotas por transição?

**P2 — Economia de tempo:** como calibrar o tempo inicial de cada cena (90 s de referência) e as prorrogações fixas de 30 s de acordo com o tamanho e a resistência das estruturas?

**P3 — Diretor adaptativo:** como evitar que destruição automática determine a rota em vez das escolhas dos jogadores?

**P4 — Seis faixas da gangorra:** quais intervalos percentuais oferecem simetria real e leitura intuitiva? Os deltas 75/35/15 são apenas exemplos.

**P5 — Unidade de recompensa:** a gangorra deve receber contribuição ao terminar cada cena, ao terminar cada partida, ou em combinação cuidadosamente definida? Como tratar KO precoce e cena final?

**P6 — Economia da progressão:** pontos exigidos por mapa, regras de repetição, recompensas esgotadas, duplicatas, mudança de categoria e comportamento da barra quando ultrapassar 100.

**P7 — Metas de seleção:** quantidade de spells/eventos que o anfitrião pode habilitar, mínimos/máximos, compatibilidade, aleatório e casos sem eventos opcionais.

**P8 — Interface:** encontrar os scripts/cenas reais existentes, preservar HUD de dano e posicionar corretamente o novo manômetro; definir fluxo de controle e experiência de revanche.

**P9 — Save e online futuro:** persistência robusta hoje, sem assumir que a funcionalidade de contas/rede já existe; delinear contrato conceitual sem implementá-la.

**P10 — Primeiro mapa:** validar o plano de expansão do Canteiro de duas para quatro cenas sem invalidar as duas já aprovadas.

## 14. Entregáveis esperados do Claude, por etapa

### Etapa A — AGORA: análise e validação, sem editar o repositório

Entregar:

1. **Parecer**: APROVÁVEL / APROVÁVEL COM AJUSTES / NÃO RECOMENDADO, fundamentado em gameplay e no código real.
2. **Matriz de impacto** por sistema e arquivo: situação atual comprovada, alteração requerida e risco de regressão.
3. **Lista de contradições**, especialmente topologia de quatro cenas, diretor adaptativo e pontuação das recompensas.
4. **Alternativas objetivas** para pendências: não mascarar decisões de design como detalhes de implementação.
5. **Plano de migração por gates** com dependências, testes e evidências; sem codificar nesta etapa.
6. **Perguntas de decisão ao usuário**, somente quando realmente necessárias.

### Etapa B — SOMENTE APÓS APROVAÇÃO: estruturação no GitHub

Registrar e versionar os manuais, decisões, grafos/manifestos conceituais e plano de testes no repositório de testes. O objetivo é deixar o projeto pronto para a mudança, **sem apresentar a documentação como funcionalidade já implementada**.

### Etapa C — APÓS ESTRUTURAÇÃO: detalhamento conceitual

Preparar telas, HUD, storyboard de transições, contrato de persistência e expansão do Canteiro, com arte/pranchas para aprovação.

### Etapa D — APÓS APROVAÇÃO ESPECÍFICA: implementação incremental

Implementar e testar a migração da lógica de cenas, configuração pré-partida, persistência, recompensas e UI, mantendo o Derruba jogável ao fim de cada incremento. Documentar evidências e não alterar o repositório estável.

---

## Solicitação final ao Claude

**Analise esta proposta como uma mudança conceitual relevante de um projeto existente, e não como um pedido genérico para criar recursos.** Confirme no código e nos manuais atuais tudo o que já existe. Preserve as decisões aprovadas que não estão sendo substituídas. Diferencie claramente *aprovado pelo usuário*, *parâmetro provisório* e *ponto pendente*. Não adicione modos, missões, telas persistentes de HUD ou funções online não autorizadas. Primeiro entregue a validação e uma proposta de migração; aguarde a aprovação antes de escrever alterações estruturais ou de gameplay no GitHub.

**Repositório para inspeção:** https://github.com/joao992001/bota-abaixo-teste-2  
**Repositório estável — NÃO ALTERAR:** https://github.com/joao992001/bota-abaixo
