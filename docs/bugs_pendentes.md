# Bugs e ajustes pendentes (lista do usuário)

Registrados conforme o usuário testa. Só corrigir quando ele disser que terminou de enviar (correção em lote).

| # | O que acontece | Onde | Situação |
|---|---|---|---|
| 1 | Cartões dos jogadores (vidas, % de dano) muito grandes e atrapalham a visão. Devem ir para o TOPO da tela, menores e mais discretos (provavelmente vale para todos os modos). | HUD da partida · Derruba (print do usuário) | **corrigido** |
| 2 | Depois de cair na água, o robô volta num lugar sem bloco (às vezes em cima do espinho) e perde várias vidas seguidas. Ao voltar, deve sempre procurar um ponto com bloco firme embaixo. | Derruba · arena com água (Canteiro) | **corrigido** |
| 3 | (Observação minha no print, confirmar) Dois jogadores com o mesmo robô da Garagem aparecem com o mesmo nome ("P1 Parafuso", "P2 Parafuso"). | Entrada / HUD | **corrigido** (o segundo vira "Parafuso 2") |
| 4 | Descrição da arena sai para fora do cartão ("Pegue o capacete no alto. Cuidado com a b…" cortado). Texto precisa caber (quebrar em 2 linhas ou diminuir). | Menu · Escolha a arena (Bola de Demolição; conferir todas) | **corrigido** |
| 5 | Letras completamente pretas, ilegíveis: a linha "BATATA-DINAMITE · Paiol de TNT" (texto escuro com contorno escuro). Conferir outros textos com o mesmo problema. | Menu · Ajustes da partida | **corrigido** |
| 6 | Rei da Obra: quando o capacete cai nos espinhos, fica lá e a rodada trava (ninguém consegue pegar). Capacete que cai em espinho/poço deve voltar (ex.: para o trono). | Rei da Obra | **corrigido** |
| 7 | Rei da Obra e Batata-Dinamite: mapas devem ser MAIORES (muito espaço para correr), SEM espinhos (ninguém morre caindo: corre para ficar mais tempo com o capacete / menos com a bomba) e com MUITA interação com o cenário (portas que abrem e fecham, alavancas, etc.). Refazer as arenas desses dois modos nessa linha. | Rei da Obra (Bola, Laje, Pirâmide) · Batata (Paiol, Galpão, Andaime) | **feito** (6 fases novas por modo, aprovadas) |
| 8 | Fuga: só a Torre em Ruínas ficou boa. Maré de Lama é simples e curta demais, sem graça. Ponte Quebradiça é confusa, a rolagem para o lado ficou estranha e o level design parece mal feito. Rolagem vertical ou lateral pode, mas com boa composição, direção de arte e level design. Mais mapas e mais variedade visual. | Fuga | **feito** (Fuga: Torre + 5 novas, aprovadas) |
| 9 | Variedade de visual (tema/"skin" da fase) em TODOS os modos: hoje Cidade à Noite só aparece na Fuga e no Rei, Galpão só na Batata etc. Cada modo deve ter a mesma quantidade de fases e os mesmos temas visuais; muda o layout (caixas, rolagem, espinhos ou não), não a falta de temas. Derruba: layouts e quantidade bons, mas pouca variedade de tema. | Todos os modos | **feito** (12 temas, 6 fases por modo) |
| 10 | Interações no cenário (alavanca, porta que abre e fecha etc.) quase não existem no jogo: criar novas para Rei da Obra e Batata (e onde couber). | Mecânicas de arena | **feito** (portas, alavancas, alçapões, trampolins, tubos, prensas, gangorras) |
| 11 | Itens por modo: os itens atuais (dano/empurrão) fazem sentido na Derruba, mas não na Batata, no Rei e na Fuga. Criar itens próprios de cada modo (ex.: Batata: arremessar a TNT sem acerto garantido; Rei: ficar intocável uns segundos e depois jogar todos longe; Fuga: itens de corrida/atrapalhar). | Itens · todos os modos | **feito** (8–9 itens por modo, aprovados) |

## Lote Canteiro (2026-11-24) — anotado; corrigir SÓ quando o usuário autorizar
| # | O que acontece | Onde | Situação |
|---|---|---|---|
| 12 | **Grave:** itens ("spells") atravessam a laje principal e não ficam em cima dela. Provável causa: o item procura chão pelos tiles, e a laje é montada por `modes/canteiro.gd` (não é tile). | Canteiro · itens | pendente |
| 13 | Fundo dá umas tremidas com a câmera adaptativa (paralaxe/zoom do fundo). | Canteiro · câmera/fundo | pendente |
| 14 | Mais plataformas no Canteiro, para ter mais lugares para ir. | Canteiro · layout | pendente (ideia) |
| 15 | Combate pouco dinâmico sem itens: colado no rival quase não acerta golpe; falta velocidade/fluidez entre golpes. | Combate | pendente (repensar) |
| 16 | Bots caem sozinhos com frequência em arena aberta (beira, trecho caindo, recuperação). | Bots · Canteiro | pendente |
| 17 | Refazer toda a árvore de itens ("spells") e os eventos do mapa, alinhados ao novo plano do jogo. | Itens · eventos | pendente (planejar junto) |
