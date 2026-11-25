# Manual — PERIGOS e MECANISMOS no modo Derruba (implementação)

Princípios gerais: [`../perigos_mecanismos.md`](../perigos_mecanismos.md). Nascem na **fotografia conceitual de cada cena**.

## Onde fica cada coisa
| O quê | Onde |
|---|---|
| Instâncias (tipo, posição em px, ciclo, `alvo` = onde a marretada aciona) | manifesto do mapa → `cenas[].mecanismos` (a cena dá a "etapa") |
| Comportamento e desenho de cada TIPO | `game/modes/mecanismos.gd` → `_<tipo>()` + bloco no `_draw()` |
| Golpe no robô | `r.take_hit(dir, "mec_<nome>", -1)` + `amassometro.mec_<nome>` + nome em `last_cause` |
| Arte | gerador da fase (`art/src/cenarios/fN_jogo.py`) → `game/assets/<arte>/m_<tipo>.png` |
| Desabar na transição | `mecanismos.desaba(n)` (todos da cena n caem) |
| Teste | `--so=mecanismos` (cada M e cada D) |

**Tipos prontos (reutilizáveis):** betoneira, elevador, esteira, tubos, serra (bancada), bate_estaca (torre apoiada no
piso), agua (lâmina + cachoeiras + jorros), vagonete, gerador. Tipo novo = função + desenho + teste.

## Passo a passo
1. Ficha (função, aviso, dano, interação/marretada, estados, segurança) a partir da fotografia da cena aprovada.
2. Arte detalhada → aprovação; animação (ciclo, aviso, ação) → aprovação.
3. Instância no manifesto da cena; código do tipo (se novo); teste em `mecanismos_test`.
4. Checklist do `mapa.md` §5 (apoio físico, nada no ar, legível em 1 s, não fecha rota nem nascimento).
5. Registrar estado na biblioteca do mapa (`perigos_mecanismos.md` do mapa).

## Lições (do Canteiro)
- Máquina inteira apoiada no piso (bate-estaca: esteira + cabine + mastro; antes era um trilho saindo pela tela).
- Água se comporta como líquido (transborda em cachoeiras, jorra do teto, cai na plataforma de baixo).
- Esteira largada num canto e serra numa passarela solta foram reprovadas: cada máquina faz sentido onde está.
- Drone (G09) travava e era inútil: elemento sem função de jogo sai da fase.
