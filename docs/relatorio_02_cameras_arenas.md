# BOTA-ABAIXO — RELATÓRIO 02
## Modificações de câmera, arquitetura das arenas e demolição progressiva

**Destino:** Claude, responsável pela evolução do projeto Godot existente  
**Natureza:** especificação de alterações sobre o estado atual, não solicitação de recriação do jogo  
**Prioridade:** modo **Derruba** e arena-piloto **Canteiro de Obras**  
**Data de consolidação:** 23/11/2026  
**Situação:** decisões de direção de design aprovadas; valores técnicos e geometria final dependem de auditoria do projeto e testes

---

## 1. Objetivo da batelada

Modificar a experiência de câmera e a arquitetura do modo **Derruba** para uma proposta de **arena fighter 2D em vista lateral**, com distribuição de plataformas inspirada na **lógica de legibilidade e combate de Brawlhalla**, mas preservando a identidade original do **BOTA-ABAIXO**: robôs de demolição, obras, equipamentos industriais, estruturas interativas e arenas que se alteram fortemente durante a luta.

**Resultado desejado:** criar e validar **uma arena-piloto Canteiro de Obras**, cuja mecânica central seja **demolição progressiva da plataforma principal**, integrando eventos do próprio mapa e consequências das ações dos jogadores. O sistema deve conservar espaço para confronto, arremessos, recuperação aérea e leitura justa do combate.

**Não começar recriando o jogo.** Antes de editar qualquer script ou cena, identificar as implementações já existentes e modificar a base atual, preservando funcionalidades operantes, controles, multiplayer local, bots, identidade visual e outros modos.

## 2. Decisões aprovadas — consolidação

| Tema | Decisão homologada | Implicação prática |
|---|---|---|
| Câmera | Sistema **híbrido**, contextual | Arenas pequenas tendem a enquadramento estável; arenas maiores usam ajuste de posição e zoom. |
| Modo de corrida (Fuga/Corrida) | Câmera de **progressão**, referência funcional Ultimate Chicken Horse | Acompanhar percurso e participantes, sem prejudicar injustamente quem está atrás. |
| Arenas de combate | Câmera adaptativa que considera **todos os jogadores ativos** e os arremessos | Antecipar deslocamentos intensos e permitir leitura de rotas de recuperação. |
| Derruba: eliminação | **Por arremesso para fora dos limites da arena em qualquer direção** | Limites superior, inferior e laterais; não depender obrigatoriamente de espinhos. |
| Relação câmera/eliminação | Limites da arena **independentes do enquadramento** | Alteração de zoom nunca altera regras de KO. |
| Arquitetura base | Mais próxima de **Brawlhalla** | Plataforma principal central com plataformas secundárias para alturas, reposicionamento e recuperação. |
| Identidade dos mapas | Cada arena terá **geometria, mecanismos e transformações característicos** | Evitar mapas que mudam apenas de fundo/tema. |
| Transformabilidade | Mudanças **grandes e relevantes** durante a partida | Transformações devem afetar rotas, espaços e decisões, não só a decoração. |
| Gatilhos | **Mistura**: ações dos jogadores + eventos automáticos | Ataques, impactos e interações podem causar mudanças; mecanismos também operam por ciclos. |
| Persistência | **Mista** | Parte dos danos pode durar até o fim da rodada; outras alterações são temporárias/reversíveis. |
| Ritmo | **Cíclico** | Alternar períodos de estabilidade com períodos de atividade/transformação. |
| Plataforma central | **Parcialmente transformável** | Pode rachar, perder trechos, dividir-se ou mudar de altura, sem inviabilizar o combate. |
| Primeira arena | **Canteiro de Obras** | Base de validação antes de multiplicar mapas. |
| Mecânica protagonista da primeira arena | **Demolição progressiva** | A laje/plataforma central sofre degradação e colapso parcial com leitura antecipada. |

As referências a Brawlhalla, TowerFall e Ultimate Chicken Horse são **referências de funcionamento, câmera e geometria**, não autorização para copiar arte, mapas, personagens ou código de terceiros.

## 3. Regras para o sistema de câmera

### 3.1. Câmera de combate híbrida

- **Mapas pequenos:** câmera predominantemente fixa/estável. Pode fazer ajustes discretos, mas deve evitar zoom e movimentação desnecessários.
- **Mapas maiores:** câmera adaptativa com limites próprios de zoom, deslocamento suave e enquadramento que considere os jogadores ativos na mesma partida local.
- Não privilegiar o líder, o jogador central ou apenas um dos personagens; a câmera compartilhada precisa ser **competitivamente justa para 2 a 4 pessoas**.
- A adaptação não deve acontecer somente depois que um personagem já saiu da área visível: **arremessos intensos devem disparar antecipação de enquadramento**, levando em conta a velocidade e a direção do lançamento.
- Priorizar a **legibilidade dos personagens, da geometria jogável e das oportunidades de recuperação**. Cenários decorativos não devem determinar o zoom.
- Evitar movimentações nervosas, tremores prolongados e alternâncias bruscas de escala. Um impacto forte pode receber uma reação pontual sem desorientar o restante da partida.
- Quando um enquadramento amplo tornar os personagens pequenos demais, usar uma solução visual complementar para posições fora de tela **se necessário e somente após teste**. Os indicadores ainda não têm especificação visual aprovada.
- A visibilidade dos espinhos **não** é requisito. A eliminação não exige espinhos na base da arena.

### 3.2. Câmera de corrida

- Preservar o modo **Corrida/Fuga** como uma experiência de progressão por percurso.
- Avaliar câmera que acompanha o avanço da fase e considera a dispersão dos corredores, em vez de forçar enquadramento de arena fixa.
- Não migrar a câmera do Derruba indiscriminadamente para a Corrida; os objetivos de enquadramento são diferentes.
- Antes de alterar regras de saída da tela, respawn, vitória ou eliminação na Corrida, **identificar e preservar o comportamento atual**; alterações nessas regras não foram aprovadas nesta conversa.

### 3.3. Requisitos de justiça e verificações

- Arremesso lateral, vertical ou diagonal: a câmera precisa dar ao jogador atingido condição visual de tentar retornar, enquanto conserva orientação espacial para os demais.
- Mudança de plataforma: a câmera deve permitir identificar com antecedência razoável a região que mudará.
- Aplicar limites de deslocamento/zoom coerentes com a geometria jogável, não com decoração de fundo.
- Se houver comportamento impossível de enquadrar com boa legibilidade, demonstrar o caso em teste e propor alternativas, sem inventar uma solução definitiva silenciosamente.

## 4. Eliminação do Derruba: zonas de KO independentes

A condição de derrota no **Derruba** deixa de depender obrigatoriamente de uma superfície de espinhos embaixo da fase.

- Definir **limites de eliminação no mundo do jogo** em todas as direções: esquerda, direita, acima e abaixo da arena, conforme a geometria de cada mapa.
- O personagem é eliminado ao cruzar um limite válido, **não** ao sair do retângulo que a câmera mostra naquele instante.
- Preservar a possibilidade de recuperação perto das bordas; as margens de arremesso/recuperação devem ser testadas com a movimentação e a esquiva aérea definidas no **Relatório 01 — Personagem e Combate**.
- Espinhos, máquinas perigosas e outros hazards podem continuar existindo como **elementos opcionais e característicos de mapas**, sem serem obrigatórios na parte inferior de toda arena.
- Ajustar HUD e feedback de eliminação somente quando necessário; preservar o funcionamento de vidas, contagem da rodada e fim de partida implementado no projeto.
- **Não alterar automaticamente** as condições de vitória dos modos Batata-Dinamite, Rei da Obra ou Corrida.

## 5. Linguagem arquitetônica das arenas

### 5.1. Estrutura de combate

- Uma **plataforma principal reconhecível**, geralmente central, como ponto predominante de confronto.
- **Plataformas secundárias** que acrescentem altura, rotas de recuperação, reposicionamento e possibilidades táticas.
- Respiro lateral e superior suficiente para que arremessos e recuperações façam sentido.
- Geometria de colisão clara e compreensível; o jogador deve distinguir rapidamente superfícies jogáveis, obstáculos, regiões móveis e estruturas decorativas.
- Identidade visual própria do BOTA-ABAIXO: lajes, ferragens, andaimes, guindastes, máquinas, concreto e instalações industriais, sem poluir a leitura da arena.

### 5.2. Diversidade entre mapas

- Cada arena futura deve combinar **geometria, mecanismos e transformações próprios**. Não criar apenas versões cosméticas de um mesmo layout.
- Cada arena deve ter **um conceito mecânico predominante**, evitando sobrecarregar todos os mapas com todos os sistemas.
- A primeira implementação deve focar **somente** no Canteiro de Obras. Outras ideias de fábrica, ferro-velho, eletroímã ou elevadores permanecem possibilidades para fases futuras.

## 6. Arena-piloto: Canteiro de Obras

### 6.1. Identidade e layout inicial (direção, não dimensões finais)

- **Ambiente:** obra/demolição industrial estilizada no universo visual atual do jogo.
- **Núcleo:** laje central relativamente larga e facilmente identificável.
- **Apoios:** andaimes/plataformas secundárias em alturas e posições que favoreçam movimento e recuperação.
- **Elementos cênicos:** equipamentos de obra ao fundo e estruturas com leitura visual coerente com sua função.
- **Mecânica protagonista homologada:** **demolição progressiva da laje central**.

Não fixar quantidade exata de plataformas, dimensões ou tempos antes de medir as capacidades reais dos robôs, o tamanho útil da tela e a geometria atual do projeto. O desenho inicial apresentado em conversa é conceitual, não uma planta obrigatória.

### 6.2. Funcionamento desejado da demolição progressiva

A laje/plataforma central deve poder sofrer **danos por segmentos ou partes identificáveis**, com estados visuais perceptíveis e consequências geométricas reais.

**Sequência comportamental de referência:**

1. **Estrutura íntegra:** superfície estável para iniciar e concentrar o combate.
2. **Dano ou gatilho:** impactos/ações permitidas dos jogadores, ou evento automático, começam a comprometer uma região da estrutura.
3. **Aviso legível:** rachaduras, deformação, som, vibração ou sinal equivalente comunicam a aproximação da mudança. A solução artística exata ainda depende dos assets existentes.
4. **Mudança de estado:** um trecho pode desabar, deixar uma abertura, alterar altura ou dividir a superfície.
5. **Nova configuração de combate:** a arena segue jogável, mas exige outras decisões de posicionamento e recuperação.
6. **Continuidade da rodada:** parte das mudanças pode permanecer até o fim; outras alterações, em elementos secundários, podem ser cíclicas ou reversíveis.

**Regras de qualidade:**

- Evitar colapso integral da única superfície viável sem alternativas de combate e recuperação.
- Evitar perda instantânea e imprevisível da plataforma sob um personagem sem qualquer indicação.
- Garantir que mudanças de colisão acompanhem os sinais e a animação do cenário, sem colisões invisíveis ou plataformas fantasmas.
- Projetar os estados da laje para serem legíveis mesmo quando a câmera se adapta.
- Não permitir que o cenário transforme a rodada em um conjunto de saltos impossíveis ou situações de eliminação inevitável por erro da câmera/geometria.
- A intensidade da demolição deve alterar o combate significativamente, **sem convertê-lo em uma corrida de plataforma**.

### 6.3. Ciclos e gatilhos

- Intercalar **períodos de relativa estabilidade** com **ciclos de atividade/transformação**.
- Permitir, quando coerente com a implementação atual, que ações dos jogadores provoquem ou acelerem a mudança de partes da laje.
- Permitir também eventos automáticos do mapa, com indicação perceptível e tempo de reação compatível com a velocidade dos robôs.
- **Não decidir ainda** qual equipamento específico opera os ciclos da arena, nem inventar uma lista de eventos aleatórios. O guindaste, elevadores e andaimes móveis são ideias secundárias discutidas, **não mecânicas protagonistas aprovadas**.
- **Não decidir ainda** probabilidades, intervalos, forças, HP estrutural, tamanho de cada segmento ou quantidade de ciclos: extrair uma proposta da base existente e submeter à calibração.

## 7. Integração com o combate já definido

Este relatório **complementa**, mas **não substitui**, o relatório anterior de **Personagem e Combate**.

- Ataque rápido e marretada pesada são funções separadas de combate (decisão anterior). A forma exata como cada um causa dano estrutural **ainda requer calibração**; não implementar como regra definitiva que ambos quebram tudo.
- Manter **Amassômetro**, arremessos graduados e recuperação aérea; verificar se as novas plataformas e as blast zones funcionam com esses comportamentos.
- Considerar que a esquiva aérea é limitada e só retorna após pouso válido. A arena não pode exigir múltiplas esquivas sucessivas no ar como requisito de sobrevivência.
- Os objetos e poderes já existentes devem ser inspecionados antes de integrar novas interações com a laje. **Não inventar interações de pickup sem teste e aprovação.**
- Preservar controles, colisões, animações e jogabilidade dos quatro modos, salvo ajustes estritamente necessários e justificados.

## 8. Plano de implementação solicitado ao Claude

### Etapa 0 — Auditoria do projeto atual

1. Inspecionar estrutura do projeto, versão do Godot, cenas, modos, scripts de câmera, eliminação, controle de personagens, física, plataformas e objetos destrutíveis.
2. Registrar o que **já existe**, o que pode ser **reutilizado**, o que deve ser **alterado** e eventuais incompatibilidades com este relatório.
3. Identificar dimensões efetivas, escalas, limites atuais, velocidades e alcance de recuperação, sem presumir valores.
4. Apresentar um plano breve de arquivos/cenas e riscos. Se uma decisão técnica contradisser uma regra já consolidada, sinalizar antes de substituir comportamentos silenciosamente.

### Etapa 1 — Base do sistema de câmera

1. Organizar a câmera por **perfil de modo/arena**, reaproveitando a implementação atual quando possível.
2. Configurar câmera estável para arenas compactas e adaptativa para as maiores.
3. Implementar enquadramento compartilhado considerando participantes ativos e antecipação de arremessos fortes.
4. Definir limites de zoom/posição configuráveis e testar legibilidade para 2, 3 e 4 robôs.
5. Preservar o comportamento funcional da câmera da Corrida; adaptar somente o necessário, sem mudar regras da modalidade.

### Etapa 2 — KO fora dos limites da arena

1. Criar ou parametrizar zonas de eliminação em quatro direções **no mundo**, desacopladas da câmera.
2. Integrar às regras atuais do Derruba (vida, respawn, contagem e vitória).
3. Remover a **obrigatoriedade** dos espinhos inferiores; não apagar assets e hazards existentes sem necessidade.
4. Testar arremessos laterais, superiores e inferiores, inclusive com mudanças bruscas de zoom.

### Etapa 3 — Arena-piloto Canteiro de Obras

1. Construir/ajustar **uma arena** de plataforma principal + secundárias usando a linguagem visual já homologada.
2. Modularizar a laje central para suportar deterioração e **colapso parcial**.
3. Incluir estados gráficos e sinais de aviso, com atualização consistente das colisões.
4. Implementar gatilhos iniciais ligados ao combate e um ciclo ambiental controlado, de forma simples e configurável; não incluir todos os mecanismos imaginados de uma vez.
5. Garantir configurações alternativas ainda jogáveis após cada etapa de deterioração.
6. Testar câmera, arremesso, recuperação, geometria e duração da partida após a transformação.

### Etapa 4 — Balanceamento e entrega

1. Comparar a arena no estado íntegro e transformado, observando se continua divertido lutar e não apenas fugir.
2. Ajustar números com base em testes de verdade, sem arbitrariamente fixá-los a partir deste texto.
3. Validar multiplayer local, bots, sobreposição de personagens, eliminação e reinício de rodada.
4. Documentar quais decisões foram implementadas, quais ficaram experimentais e quais dependem de assets ou aprovação humana.
5. Entregar projeto executável/abrível no Godot, com instruções de teste e relação exata dos arquivos modificados.

## 9. Checklist de aceitação

- [ ] O projeto atual é preservado e abre normalmente no Godot.
- [ ] A câmera não altera o local real onde ocorre a eliminação.
- [ ] O Derruba aceita eliminação pelas bordas **esquerda, direita, superior e inferior**.
- [ ] Nenhum mapa do Derruba exige obrigatoriamente espinhos inferiores para funcionar.
- [ ] Arenas compactas têm câmera suficientemente estável.
- [ ] Arenas maiores ajustam enquadramento para vários robôs e antecipam arremessos intensos.
- [ ] A câmera não abandona injustamente um jogador lançado para longe nem perde a legibilidade dos demais.
- [ ] O Canteiro de Obras possui uma área central de confronto e plataformas secundárias úteis.
- [ ] A demolição parcial tem aviso perceptível, estados claros e colisão compatível.
- [ ] A arena permanece lutável depois das alterações estruturais.
- [ ] Há períodos de estabilidade e períodos de transformação perceptíveis.
- [ ] Ao menos um gatilho vindo dos jogadores e um gatilho/ciclo do ambiente foram exercitados no protótipo (sem extrapolar para dezenas de mecanismos).
- [ ] Arremessos, correções aéreas e esquiva disponíveis no build não são prejudicados injustamente pelo mapa.
- [ ] Multiplayer local, bots e reinício de partidas funcionam sem regressões aparentes.
- [ ] Os modos não focalizados não tiveram suas regras alteradas inadvertidamente.
- [ ] A entrega inclui uma relação de arquivos alterados, parâmetros expostos e roteiro de testes reproduzível.

## 10. O que NÃO foi aprovado nesta etapa

As seguintes ideias **não são requisitos fechados** e não devem ser interpretadas como autorização para implementar automaticamente:

- Quantidade definitiva de arenas, número e dimensão exata de plataformas ou posições fixas de spawn.
- Valores de zoom, velocidade de câmera, antecipação, duração de ciclos, dano estrutural ou pontos de KO.
- Guindaste como mecanismo protagonista do mapa-piloto; esteiras, eletroímãs, elevadores e demais máquinas como obrigatórios.
- Destruição completa e irreversível de toda a plataforma central.
- Aparência definitiva dos indicadores de fora de tela, rachaduras, partículas, animações e sons.
- Mudança nas condições de vitória de Batata-Dinamite, Rei da Obra e Corrida.
- Novas armas, combos, modos, personagens ou alteração geral do controle do robô; estes assuntos pertencem ao trabalho anterior ou a etapas futuras.
- Copiar layouts ou recursos de jogos comerciais citados como referência.

## 11. Formato de resposta esperado do Claude

Entregar, ao final, um resumo objetivo organizado em:

1. **Estado anterior identificado** (câmera, mapas, KO e objetos destrutíveis).
2. **Mudanças efetivamente implementadas** (com arquivo/cena e função afetada).
3. **Configurações expostas para balanceamento** (parâmetros e onde alterá-los).
4. **Testes realizados e resultado de cada um** (principalmente 2–4 jogadores e bots).
5. **Pendências e comportamentos ainda experimentais**, sem apresentar hipótese como mecânica aprovada.
6. **Como abrir, executar e verificar** a arena Canteiro de Obras e os casos de arremesso/KO.

---

### Instrução final para o Claude

> Trabalhe **sobre a versão atual do BOTA-ABAIXO**, com mudanças incrementais, evitando refatorações amplas sem necessidade. Priorize primeiro a câmera compartilhada justa e o KO independente da tela; depois, a arena-piloto Canteiro de Obras com demolição progressiva e ciclos legíveis. Preserve os modos, a jogabilidade, os bots e o multiplayer local. Não trate hipóteses e valores técnicos ainda não definidos como decisões de design aprovadas. Ao final, demonstre o que mudou e como testar.
