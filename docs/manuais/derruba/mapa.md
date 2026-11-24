# Manual — criar uma FASE (mapa) do modo Derruba

Saiu da construção da **Fase 1 (Canteiro de Obras)**, em 2026-11-24 — siga a mesma ordem. As regras de desenho estão
na cartilha (`mapa_cartilha.md`); aqui está o **como fazer**. Exemplo completo e vivo: `docs/fases/derruba/f1_canteiro.md`.

## 0. Ordem obrigatória (cada passo aprovado pelo usuário antes do próximo)
1. **Catálogo** da fase (`docs/fases/derruba/fN_<nome>.md`) + esquema (`art/src/cenarios/fN_catalogo.py`).
2. **Prancha de arte** das etapas como "tela de jogo" (`art/src/cenarios/fN_prancha.py`).
3. **Código em 6 blocos**, cada um testado e commitado: A etapas/virada · B cena viva · C mecanismos · D demolições ·
   E eventos da fase · F manual/GIF/.exe.

## 1. Catálogo (antes de qualquer arte)
Copie a estrutura de `f1_canteiro.md`: regras de acaso × roteiro; por etapa: ficha (composição, paleta, horário,
assinatura, câmera, som), **E** estruturas, **D** demolições, **M** mecanismos (3–5 por etapa), **V** eventos (lista da
biblioteca + específicos), **A** fundo vivo (C0–C4); storyboard da virada. Gere o esquema (copie `fase1_catalogo.py`).

## 2. Prancha de arte
Copie `fase1_prancha.py`: cada etapa como tela de 2560×1408 (40×22 tiles) com o elenco em ação (usa
`art/src/robos/elenco.py` e as peças de `canteiro_derruba.py`). Abra, olhe, corrija sobreposições (placas atrás de
andaimes, máquina dentro de torre) antes de mandar.

## 3. Código (arquivos e o que mudar)
| Bloco | O que fazer | Onde |
|---|---|---|
| **A Etapas** | `.lvl` cresce para baixo (etapa 2 embaixo da 1, mesmo mundo); props `etapa1/etapa2` (col,linha,larg,alt), `etapa2_nome`, `buraco` (cols por onde se cai), nascimentos `1–4` (etapa 1) e `5–8` (etapa 2). Números da virada em `demolicao.etapas`. | `levels/<fase>.lvl`, `data/modos.json`, motor pronto em `modes/etapas.gd` + `level.area` |
| **B Cena viva** | Exporte as camadas PARADAS da prancha (céu, cidade, prédio, grua, fundo e palco da etapa 2) e as peças que MEXEM (nuvem, balde, operários…) com um `fN_jogo.py` (copie `fase1_jogo.py`) para `game/assets/<cena>/`. Prop `cena: <cena>` e `sem_arte_de: <linha>` (linhas desenhadas pela cena, não por caixote). A animação de cada fase vai em `modes/cena.gd` (hoje escrito para a fase1: generalize as listas de animados quando fizer a 2ª fase). | `art/src/cenarios/`, `game/modes/cena.gd` |
| **C Mecanismos** | Liste os da fase em `demolicao.mecanismos.<cena>` (tipo, etapa, posições em px, ciclo, `alvo` = onde a marretada aciona). Tipos prontos: betoneira, elevador, esteira, tubos, serra, bate_estaca, agua, vagonete, gerador. Tipo novo = uma função `_<tipo>` + desenho em `modes/mecanismos.gd`. Golpe = `mec_<nome>` no Amassômetro + `last_cause`. | `modes/mecanismos.gd`, `data/modos.json` |
| **D Demolições** | Peças da estrutura em `canteiro.gd → LAYOUTS` (cada peça tem `etapa`); tipos prontos: laje (com escora), andaime, viga, terreo, estaca (plataforma + pilar), grelha (abre KO), entulho. HP em `demolicao.canteiro`. A virada derruba só a etapa 1 (`collapse_all`). | `modes/canteiro.gd` |
| **E Eventos** | `demolicao.eventos.por_fase.<cena>` = lista por etapa (biblioteca G## + específicos V##). Evento novo: siga `evento.md`. | `modes/eventos.gd`, `data/modos.json` |
| **F Entrega** | Testes, vitrine `--fase=DIR` (bots lutando + virada), GIF, `.exe`, este manual atualizado. | `tests/driver.gd` |

## 4. Testes (só a parte mexida; bateria completa 1× no fim)
`--so=etapas` (virada: aviso, desaba, queda sem KO, chegada), `--so=mecanismos` (cada M e cada D), `--so=eventos`
(biblioteca + filtro por fase), `--so=canteiro`, `--so=lab`. Nos testes longos a virada fica desligada
(`demo_round` zera o cronômetro); só o teste de etapas a dispara.

## 5. Economia (o que aprendemos)
- **Não leia arquivos grandes inteiros** (`spells.gd`, `eventos.gd`, `driver.gd`, `robot_visual.gd`): use `grep -n` no
  ponto de encaixe e edite com substituição exata (âncora única).
- **Reaproveite**: arte sai da prancha aprovada (mesmas funções), mecanismos e demolições são tipos reaproveitáveis,
  eventos são biblioteca. Uma fase nova é sobretudo DADOS + arte.
- **Capturas**: uma vitrine por bloco, olhe 4–10 quadros-chave numa prancha (não o vídeo todo).
- **Commit por bloco**; atualize `docs/ESTADO.md` (Retomar aqui) no fim.

## 6. Lições da Fase 1
- Gravidade/vento dos eventos são zerados a cada quadro ANTES de qualquer saída antecipada (senão a queda acumula).
- Nome `_init` é reservado no GDScript (construtor): não use para funções próprias.
- Peças de outra etapa não podem aparecer em sorteios (caixas, ciclo G01, inspeção): filtre por `etapa`.
- Nada de pilar em cima de peça que quebra (o poço foi mudado de lugar).
- Na chegada da virada, quem ficou fora (ou em cima do teto) renasce embaixo.
- **Palco sempre sobre o vazio (pedido do usuário):** em toda etapa, cair do piso em qualquer ponto = KO, rápido. Nada de
  bordas pretas que matam, paredes até o teto ou poço com parede (o robô se agarrava na fresta). Vãos visíveis e abertos.
- **Cada máquina precisa fazer sentido onde está** (serra numa bancada no chão, não em cima de uma passarela solta; nada de
  esteira jogada num canto). Leia a composição como uma pessoa olhando a tela.
- **Câmera:** mola suave + zona morta; só antecipa arremesso forte; tremor pequeno (o ruído a cada quadro parecia lag).
- **Virada:** derrubar também os mecanismos da etapa; cada robô cai em arco até um ponto com PISO embaixo, sem controle.
- **Toda etapa precisa de saída para KO** em pelo menos 2 lados (a Fundação nasceu fechada pelas paredes até o teto e as
  rodadas de bots não acabavam): paredes da bacia param 6 linhas abaixo do teto (abertura lateral) + buraco em cima + poço.
  Confira com o teste `rodadas só de bots terminam` (`--so=bots`).
