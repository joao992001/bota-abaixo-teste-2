# BOTA-ABAIXO — Relatório de modificações do personagem e combate
**Destino:** Claude — implementação no projeto Godot atual  
**Escopo:** movimentação, ataques, esquiva, arremesso, recuperação aérea, animações e integração com regras já existentes  
**Natureza:** modificações incrementais sobre o projeto atual; **não** reconstruir o jogo do zero.

## 1. Objetivo e premissas

Atualizar o controlador e o sistema de combate dos robôs para torná-los mais expressivos, responsivos e interessantes em disputas entre 2–4 jogadores, preservando a identidade de jogo de festa competitivo: fácil de aprender, com domínio progressivo, habilidade e caos físico.

O projeto já possui movimentação de plataformas, marreta, Amassômetro, interações com elementos do cenário e modos distintos. **Antes de editar**, identificar no código quais dessas funcionalidades já estão implementadas, seus nomes reais, animações, comandos, sinais e dependências. Fazer alterações localizadas; conservar o que funciona e registrar qualquer divergência entre este relatório e a versão efetivamente encontrada.

**Não incluir nesta batelada:** redesenho de mapas, distribuição de plataformas, blast zones/novas regras de eliminação, câmera híbrida, eventos cíclicos da arena, novas estruturas destrutíveis, mudança de objetivos dos modos ou criação de um novo sistema geral de personagens. Essas decisões pertencem a outra etapa.

## 2. Mudança 01 — Separar o ataque atual em duas ações

**Situação a revisar:** a marreta atual concentra ataque aos oponentes e interação/destruição do cenário, ficando excessivamente responsável por tudo.

**Novo comportamento aprovado:**
- **Ataque rápido:** execução breve; usado para pressionar, interromper ações e aplicar empurrão/impacto menor. Prioridade: combate entre robôs. **Não deve ser a ferramenta padrão de destruição das estruturas.**
- **Marretada pesada:** ação distinta, mais comprometida, com preparação/execução/recuperação mais perceptíveis; impacto e arremesso superiores; mantém a responsabilidade principal pela interação destrutiva que a marreta atual já executa.
- Ambos alimentam/aproveitam o **Amassômetro** de acordo com as regras já existentes. A marretada deve ter maior potencial de arremesso, mas não eliminar automaticamente por atingir determinado percentual.
- O golpe pesado deve deixar uma abertura real quando erra ou é evitado; o rápido deve ser ágil, mas não dominante ou infinitamente encadeável.

**Implementar de maneira incremental:** rastrear a ação e hitbox da marreta existente, reutilizar os sistemas de dano, colisão e eventos; extrair responsabilidades em ataques separados; manter as interações destrutivas atuais associadas à ação pesada. Não substituir automaticamente o sistema por combos complexos ou ataques direcionais novos — essas opções não foram escolhidas.

**Comandos:** prever duas ações distintas e remapeáveis por jogador. Não presumir teclas/botões definitivos; respeitar os dispositivos e o mapeamento já adotados para multiplayer local.

## 3. Mudança 02 — Adicionar esquiva curta no chão e no ar

**Novo comportamento aprovado:**
- Esquiva/impulso curto, utilizável tanto em solo quanto em situação aérea, com direção determinada pela movimentação compatível com o controlador atual.
- Durante uma **janela muito curta** da esquiva, proteger contra **golpes de outros robôs**.
- **Não proteger** contra espinhos, explosões, prensas, quedas, perigos ambientais ou demais fontes do cenário. A esquiva não é invulnerabilidade universal.
- A esquiva tem tempo de recuperação/limitação de uso para impedir repetição contínua.
- No ar, permitir **uma utilização por período aéreo**. A disponibilidade aérea volta **somente ao pousar em superfície válida**. Tocar parede, receber golpe, passar tempo ou simplesmente começar a cair não restaura a carga.
- A ação pode servir para evitar um ataque ou ser guardada para recuperar-se após um arremesso. O jogador faz essa escolha.

**Cuidados de implementação:** manter estados de esquiva, janela de proteção contra ataques de jogadores, recuperação e carga aérea explícitos; não confundir essa proteção com flags globais de invulnerabilidade do personagem. Definir a compatibilidade com salto, ataque, colisões, dano e movimentos já existentes sem criar travamentos de estado. A esquiva não deve atravessar geometria sólida nem anular riscos ambientais.

## 4. Mudança 03 — Reformular a reação a impactos e arremessos

**Novo comportamento aprovado:** o combate deve enfatizar arremessos físicos, não longos períodos de atordoamento. Um golpe aplica impulso/knockback e pode causar perda breve de controle; em seguida, o robô gradualmente recupera a capacidade de orientar seu movimento no ar.

- Preservar e integrar o **Amassômetro**: quanto maior o dano acumulado, maior o potencial de arremesso e, consequentemente, mais difícil a recuperação. Não transformar isso num sistema de HP zerável sem nova aprovação.
- Diferenciar a reação ao ataque rápido (menor deslocamento/comprometimento) e à marretada pesada (impacto mais significativo).
- Após um arremesso, permitir **correção aérea gradual pelos direcionais**, sem cancelar imediatamente todo o impulso recebido.
- Se o robô ainda tiver sua esquiva aérea, permitir usá-la durante a tentativa de recuperação. Essa esquiva **consome a mesma utilização aérea** da defesa comum; não criar uma esquiva extra exclusiva para recuperação.
- Evitar atordoamento longo, combos automáticos e sequências em que o atingido perde totalmente a possibilidade de reação.
- Não permitir que correção aérea ou esquiva anulem consistentemente o risco de um arremesso forte.

**Integração com estados:** conferir a precedência de impacto, knockback, ataque, esquiva, salto, aterrissagem e eventual morte/KO já existente. A transição de atingido para recuperação aérea deve funcionar sem congelar controles nem causar teletransporte ou mudança brusca injustificada de velocidade.

## 5. Mudança 04 — Animações e feedback visual necessários

**Não presumir que os sprites ou animações abaixo já existem.** Primeiro listar as animações atuais, aproveitar as compatíveis e apontar os assets ausentes. Caso faltem sprites, criar estados/fallbacks visuais provisórios e entregar especificações claras dos novos quadros; não substituir a arte aprovada por sprites genéricos nem declarar animação finalizada sem asset real.

| Prioridade | Ação / estado | Animação ou feedback esperado |
|---|---|---|
| Alta | Ataque rápido | Golpe curto, leitura imediata, retorno rápido à movimentação |
| Alta | Marretada pesada | Preparação visível, impacto forte, recuperação claramente legível |
| Alta | Esquiva terrestre | Impulso/deslizamento curto, silhueta e direção perceptíveis |
| Alta | Esquiva aérea | Variação aérea distinguível, sem confundir com salto normal |
| Alta | Recebimento de golpe | Reação compatível com a intensidade do impacto |
| Alta | Arremessado | Pose de lançamento/rotação controlada, com leitura da direção |
| Alta | Recuperação aérea | Transição visível do descontrole parcial para o controle aéreo |
| Média | Pouso após arremesso | Breve absorção do impacto, sem atrasos que prejudiquem o comando |
| Média | Efeitos de combate | Efeitos leves no ataque rápido; impacto mais enfático no pesado; indicação sutil da janela de esquiva e do acerto |

**Regras visuais:** sincronizar hitboxes com o momento real do golpe; manter leitura clara dos robôs em escala de arena; conservar a estética, paleta, skins e personalizações existentes; não exigir animações distintas por skin quando o rig/sprite base for compartilhável. Não introduzir longas transições visuais que atrasem comandos além das regras de combate.

## 6. Etapas de trabalho solicitadas ao Claude

1. **Auditar o estado real:** localizar scripts, máquina de estados, cenas de robô, entradas de controle, hitboxes, lógica do Amassômetro, animações atuais e dependências dos quatro modos. Listar o que existe e como será preservado.
2. **Separar os ataques:** extrair ataque rápido e pesado a partir do sistema atual, conservando a função destrutiva da marreta pesada e integrando Amassômetro, colisões e eventos atuais.
3. **Implementar esquiva:** solo/ar, janela específica de defesa contra ataques de jogadores, restrições ambientais, recuperação e controle da única esquiva aérea por período no ar.
4. **Ajustar arremesso e recuperação:** impulso físico, controle aéreo gradual, possível uso da esquiva aérea remanescente e progressão de força pelo Amassômetro.
5. **Integrar animações e feedback:** conectar estados e hitboxes; aproveitar assets existentes; listar o que faltar e aplicar placeholders discretos apenas quando necessário.
6. **Revisar integração:** confirmar que botões funcionam para múltiplos jogadores locais e que bots, golpes, objetos e objetivos dos modos não foram quebrados.
7. **Testar e reportar:** executar projeto, registrar problemas corrigidos, arquivos alterados, parametrizações ajustáveis, limitações e resultados dos cenários de teste.

## 7. Regressões que devem ser evitadas

- **Derruba:** manter o objetivo e as regras de eliminação *atualmente implementados nesta batelada*. A proposta futura de eliminação pelos limites da arena será tratada com mapas/câmera, em outra entrega.
- **Batata-Dinamite/Pique TNT:** preservar transferência de bomba, temporizadores e interações de contato/golpe; mapear explicitamente como o golpe atual se relacionava à bomba antes de substituí-lo.
- **Rei da Obra:** preservar derrubada/transferência do capacete por golpes, temporização de pontuação e demais estados do portador.
- **Fuga/Corrida:** preservar física de movimento, funcionamento do percurso e condição de vitória; não alterar a câmera nesta etapa.
- **Todos os modos:** não quebrar entrada de controles 2–4 jogadores, suporte a bots, personalizações cosméticas, colisões com o cenário, marreta e comportamento de objetos existentes.

## 8. Cenários mínimos de aceitação

- O ataque rápido acerta o adversário e produz reação menor; não atua como ferramenta normal para quebrar estruturas.
- A marretada pesada tem preparação e recuperação perceptíveis, empurra mais e preserva a interação destrutiva que já funcionava.
- Ataques e arremessos continuam coerentes com o Amassômetro acumulado.
- A esquiva funciona no chão e no ar, evita golpes de robôs no intervalo de proteção e **não** neutraliza perigos ambientais.
- Após usar esquiva aérea, não é possível repetir no mesmo período aéreo, mesmo recebendo um golpe; uma aterrissagem válida a restaura.
- Um robô arremessado pode corrigir parcialmente a rota com direcionais e usar a esquiva aérea se ainda disponível; nenhuma dessas ações cancela automaticamente o risco do golpe.
- Não há congelamento de controles, loop de animação, falha de colisão, duplicidade de hitbox ou interrupção indevida de estados.
- Os quatro modos seguem jogáveis com múltiplos jogadores e bots; efeitos específicos da marreta original permanecem operacionais.

## 9. Parâmetros a calibrar — não homologados numericamente

**Ainda não foram aprovados valores exatos** para força dos ataques, duração dos golpes, janela de esquiva, velocidade/distância de esquiva, tempo de recuperação, graus de controle aéreo, fórmula do Amassômetro ou limites de knockback. Expor esses parâmetros para ajuste no Godot, propor valores iniciais coerentes com a movimentação atual e documentá-los para testes. Não apresentar valores experimentais como decisões finais.

**Entrega esperada:** alterações reais no projeto existente, relação dos arquivos editados, resumo técnico do que foi alterado, lista de animações disponíveis/faltantes, controles resultantes, parâmetros editáveis, testes efetuados e pendências. Priorizar um jogo jogável, fluido e compatível com o estado atual em vez de refatoração ampla sem necessidade.
