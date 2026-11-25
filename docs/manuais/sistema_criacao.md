# Sistema de criação — regras transversais (vale para todo o jogo)

## 1. Hierarquia: quem é dono de quê
| Nível | Define | Exemplos | Onde mora |
|---|---|---|---|
| **Jogo** | personagens, controles, padrões de qualidade, fluxo universal, áudio comum, processo de skins | 5 robôs humanoides; marreta/esquiva; papel e giz | `data/controller.json`, `art/src/robos/`, manuais da raiz |
| **Modo** | objetivo, vitória, regras, **classes de spell**, regras de destruição/transição, bibliotecas de comportamentos reutilizáveis | Derruba: Ataque, Controle, Engenharia, Transformação; cenas por 90% de destruição | `data/modos.json` → `demolicao.modos[<modo>]` + `demolicao.spells`/`eventos` (bibliotecas) |
| **Mapa** | conceito, direção visual, cenas, **spells autorizadas**, eventos autorizados, perigos/mecanismos, skins originadas | Canteiro de Obras (Térreo → Fundação) | `data/mapas/<modo>/<mapa>.json` + `docs/fases/<modo>/<mapa>/` + `levels/<mapa>.lvl` |
| **Nível** | profundidade dentro do mapa (Derruba v2: 2 níveis no mapa de 3 cenas, 3 no de 7) — não é mapa novo nem rodada | 1 = Início; 2 = Moderada/Total | `cenas[].nivel` (manifesto v2) |
| **Cena** | região jogável: arquitetura (base fixa × destrutível), eventos da cena, instâncias de perigos/mecanismos, próxima cena | Térreo, Fundação | `cenas[]` do manifesto + `etapaN`/`koN`/`buracoN` no `.lvl` |
| **Elemento** | spell, evento, perigo/mecanismo, skin: especificação, arte, animação, testes e aprovação individuais | T01 Armadura Fornalha, V3 Enchente, M6 Bate-estaca | manual do tipo + biblioteca do mapa |

Personagens **não pertencem** a modos nem a mapas. Classes de spell são do **modo** (o mapa nunca cria classe). Skins têm
**origem no mapa** (nunca no modo).

## 2. Quatro conceitos que não se misturam
- **Definição técnica** — o comportamento reutilizável (código + números). Ex.: tipo `bate_estaca` em `mecanismos.gd`.
- **Origem artística** — o mapa que inspirou o elemento. Ex.: T01 nasceu no Canteiro.
- **Autorização** — a lista explícita de mapas (e cenas) onde pode aparecer. Ex.: `spells_permitidas`, `cenas[].eventos`.
- **Instância** — posição, parâmetros e estado naquela cena. Ex.: `cenas[1].mecanismos[M6] = {x: 1440, …}`.
Um elemento **não aparece** num mapa só porque existe na biblioteca: precisa estar autorizado no manifesto. Mapa sem
manifesto não recebe spells nem eventos (só os mapas-ferramenta de `data/mapas/ferramentas.json` recebem tudo, explícito).

## 3. Estados (use exatamente estes nomes nas bibliotecas e manuais)
`PROPOSTO` → `AGUARDANDO_APROVAÇÃO` → `APROVADO` → `EM_IMPLEMENTAÇÃO` → `TESTADO` · e `REPROVADO`, `SUBSTITUÍDO`.
- **Aprovação artística ≠ teste técnico.** Só o usuário aprova arte, animação e design; a IA nunca declara aprovação por ele.
- **REPROVADO** não é pedido para refazer igual: fica registrado com o motivo para nunca voltar.
- **SUBSTITUÍDO** guarda a regra antiga com data e o que a substituiu (histórico rastreável, sem duas regras vigentes).
- Toda mudança aprovada atualiza o manual do tipo E a biblioteca do mapa, com data, motivo e impacto.

## 4. Fluxo universal de qualquer elemento
1. Descobrir a **função** (o que muda na luta, por que o jogador age).
2. **Ficha** curta: mecanismo, controles, alcance, aviso/feedback, contrajogo, segurança, onde é autorizado.
3. **Arte estática** para aprovação (prancha). 4. **Animação em movimento** para aprovação (GIF/vídeo).
5. Implementar a jogabilidade. 6. **Testes** automáticos + vitrine. 7. Aprovação final do usuário.
8. Registrar na biblioteca do mapa (estado) e as lições no manual.
Exceção importante: **perigos/mecanismos e eventos de um mapa nascem no desenho das cenas** (fotografia conceitual),
não depois; spells são mais independentes (classe do modo + estética do mapa).

## 5. Estrutura obrigatória de um manual
objetivo e escopo · quando usar · dependências e entradas · entregas · sequência de criação · pontos de aprovação · como
implementar (arquivos) · como testar · problemas conhecidos/lições · exemplos aprovados · histórico de decisões.

## 6. Histórico deste sistema
- 2026-11-25 — `APROVADO`: reorganização modular (hierarquia jogo/modo/mapa/cena/elemento, autorização por mapa,
  manifesto por mapa, estados). Origem: especificação do usuário "migração modular V1".
