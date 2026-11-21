# Dossiê de fases

Problemas que o usuário encontra jogando. Corrigir em lotes pequenos; cada lote termina com um executável (zip).

## Princípios de level design (checar antes de mexer)
Referências de gênero: Super Smash Bros./Brawlhalla (arenas de derrubar), Ultimate Chicken Horse e Heave Ho (party), BattleBlock Theater, Celeste/Super Meat Boy (corrida da Fuga).
1. **Leitura em 1 s:** cada fase tem 1 ideia principal, visível logo de cara; perigo sempre com cor/forma de perigo.
2. **Arena (Derruba/Batata/Rei):** um centro disputado, laterais de fuga e loops (sempre dá para dar a volta). Nada de becos sem saída longos.
3. **Ritmo vertical:** degraus de 3 tiles (pulo ~3,9); vãos de até 4; trampolim = 6. Nada que exija pulo perfeito.
4. **Interação perto do efeito:** alavanca ao lado do que controla e visível de onde se vê o efeito; poucas por fase.
5. **Tudo apoiado:** estruturas presas ao chão, a paredes ou a vigas; nada flutuando sem motivo.
6. **Spawns justos:** mesma distância do objetivo (trono, bomba, elevador) para todos.
7. **Fuga:** trechos curtos, cada um ensinando uma coisa, depois combinando; sempre um caminho seguro e um arriscado mais rápido; nunca um trecho onde a câmera alcança sem chance.

## Lista (o usuário vai mandando)
| # | Fase / modo | Problema | Lote | Situação |
|---|---|---|---|---|
| 1 | Derruba, Batata e Rei (todas) | Zoom perto demais, pior com menos jogadores. Ideal: a arena inteira na tela, como no print (Esteiras com 4). | 1 | pendente |
| 2 | Derruba, Batata e Rei | Rodízio de fases durante a partida, como em Gang Beasts (cada rodada numa fase diferente, sem voltar ao menu). | 1 | pendente |
| 3 | Batata (Obra de Concreto) e Rei (Trono do Canteiro) | Prints mostram a câmera cortando a arena: aplicar o item 1 (arena inteira na tela). |  1 | pendente |
| 4 | Batata · Obra de Concreto | Alavanca do topo fica trancada na "casa de máquinas" (paredes dos dois lados, sem entrada): impossível ativar. Abrir uma entrada ou mudar a alavanca de lugar. | 1 | pendente |
| 5 | Batata · Obra de Concreto | Não dá para quebrar nada (caixotes não quebram?). Conferir se a marreta quebra caixote na Batata; se não, decidir: quebrar ou trocar caixote por bloco fixo para não enganar. | 1 | pendente |
| 6 | Batata (todas) | Pavio da dinamite curto demais: aumentar o tempo em todas as fases. | 1 | pendente |
| 7 | Batata · Galerias da Mina | No alto da rocha não dá para descer: a saída é por tábua de mão única (só sobe) e o robô fica preso lá em cima. Trocar por buraco aberto/descida, ou permitir descer da tábua (▼ + pular) em todo o jogo. Conferir os outros poços com tábua. | 1 | pendente |
| 8 | Batata · Prédio Velho | Pilhas e paredes de caixote demais: passa-se o tempo todo quebrando bloco em vez de correr/fugir. Batata precisa de fluxo livre: tirar as paredes de caixote do caminho, deixar só caixotes opcionais. | 1 | pendente |
| 9 | Batata · Palafitas | Fase confusa e sem dinâmica; gangorras inúteis (só pontes que inclinam). Repensar: casas como cômodos com saídas claras e loops; gangorra só se tiver efeito (catapulta: pular numa ponta lança quem está na outra). | 1 | pendente |
| 10 | Batata · Telhados (e outras) | Com itens ligados, nenhum item aparece. Investigar o spawn de itens (lugar de queda nas fases 44×24 / telhados altos? lista do modo?) e testar em todas as 24 fases. | 1 | pendente |
| 11 | Batata e Rei (geral) | Mais dinâmica: eventos no mapa com mais frequência (portas/alçapões que mudam sozinhos, chuva de caixas etc.) e itens caindo mais vezes. É o que dá graça ao modo. | 1 | pendente |
| 12 | Itens novos (todos os modos) | Patins, relógio, escudo, estilingue, choque, laço, barreira, gancho sem animação/efeito no nível dos itens antigos (ferramenta na mão, partículas, som, brilho no robô). Dar a cada um efeito visual de uso e de "ligado" no mesmo padrão (Ferramentas/tools.use). | 1 | pendente |
