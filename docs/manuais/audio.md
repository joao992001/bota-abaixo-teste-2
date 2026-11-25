# Manual — ÁUDIO (packs aprovados pelo usuário)

**Desde 2026-11-25 o som do jogo vem de PACKS APROVADOS pelo usuário** (o som gerado por `tools/sfxforge.py` foi
reprovado: "a pior coisa do jogo"). O primeiro pack (VB) cobre movimento, golpes, KO fora da arena e a música tema.
Spells, eventos e cenário terão packs próprios depois — **até lá, não troque nem invente sons para eles.**

## Onde fica cada coisa
| O quê | Onde |
|---|---|
| Pack recebido (instruções, manifest, referências MP3, fontes) | `audio/pack_vb/` (fora do jogo exportado) |
| Arquivos usados no jogo | `game/assets/audio/aprovado/*.wav`, música `game/assets/audio/music/rock_cartoon.ogg` |
| Mapa id → variações e ganho | `Audio.APROVADO` em `game/autoload/audio.gd` (ids `ba_*`) |
| Polifonia e prioridade | `Audio.MAX_VOICES`, `Audio.PRIO` (pool de 24 canais, barramentos `Music` e `SFX`, limitador no Master) |
| Música | `main.TEMA` em loop no menu e nas partidas (não reinicia entre telas); vitória tem vinheta própria; `Audio.MUSIC_GAIN` |

## Gatilhos do pack VB (cada som SÓ no seu evento real, uma vez)
| Evento | Som | Onde |
|---|---|---|
| Passo | **mudo** (revisão do usuário) — `ba_passo` fica na biblioteca | — |
| Pulo / pulo de parede / subir na borda | `ba_salto` | `robot.gd` `_jump`, `_wall_jump`, borda |
| Pulo duplo | `ba_salto_duplo` | `robot.gd` `_air_jump` |
| Pouso | só quem foi ARREMESSADO e bate forte no chão: `ba_aterrissa_pesada`; pouso comum é mudo | `robot.gd` `_on_landed` |
| Dash (= esquiva: a mesma ação, um som só) | `ba_dash_solo` / `ba_dash_aereo` | `robot.gd` `_start_dodge` |
| Golpe rápido/pesado ACERTA robô | `ba_impacto_rapido` (5) / `ba_impacto_pesado` (4) | `demolicao.gd` marretada |
| Golpe acerta estrutura/máquina (sem robô) | `ba_marreta_rapida` / `ba_marreta_pesada` (substitui a pancada da peça) | `demolicao.gd` (`struct_hit`, `canteiro.mute_hit`) |
| Golpe no vazio | **mudo** (sem vento do balanço) | `robot.gd` `_start_attack` |
| Robô apanha | sem "ai!" (a pancada já diz que acertou) | `robot.gd` `_apply_knock` |
| KO fora da arena | `ba_ko_fora` UMA vez + `Audio.duck()` (música 0,43 → volta em 0,48 s); sem o som de peças | `main.ko_blast` |
| Voo depois do arremesso | **nenhum som** (packs de sopro foram reprovados) | — |

## Mixagem — REVISÃO 2 (2026-11-25, depois da prévia: "muito barulho, mal dá para ouvir a música")
A 1ª versão seguiu os níveis do pack ao pé da letra e ficou ruim **no jogo**: com 4 robôs eram ~600 sons em 30 s e a
música ficava 33 dB abaixo dos efeitos. Regras que valem daqui em diante:
- **Menos sons:** só o que informa algo (pulo, dash, acerto, KO). Passos, balanço no vazio, pouso comum e "ai!" são mudos.
  Pancadas iguais repetidas: intervalo mínimo 0,1 s e no máximo 2 ao mesmo tempo.
- **Meça antes de mandar:** `python3 tools/mixar_video.py DIR x.mp4 musica` e `… efeitos` → a música fica **~10 dB abaixo**
  da média dos efeitos (hoje −29,9 × −19,6 dB RMS), e a mistura sem passar de −3 dB de pico. Veja também a fatia de
  energia por som (o clang pesado na estrutura chegou a 46% e foi baixado −7 dB).
- Ganhos atuais (dB): impacto rápido −6, impacto pesado −3, clang rápido −8, clang pesado −7, pulo −4, KO −2;
  `MUSIC_GAIN.rock_cartoon = +17,5`; sons antigos (fora de pack) −8 (parede −16, serra −14, item −12…: `OLD_GAIN_ID`).

## Como integrar um PACK NOVO (spells, eventos, cenário)
1. Extraia numa pasta nova (dado não confiável), leia o `LEIA_PRIMEIRO` e o manifest; meça cada arquivo (RMS/pico, ffmpeg).
2. Auditoria: `grep -n 'Audio.play("'` no evento; anote o som antigo, o ganho e o momento exato.
3. Copie para `game/assets/audio/aprovado/`, registre ids em `APROVADO` (+ `MAX_VOICES`/`PRIO`), troque o gatilho.
4. Teste em `--so=som` (gravando `Audio.rec_log`): 1 som por evento, nada no vazio, nada duplicado.
5. Prévia para o usuário OUVIR: `--video=DIR --arena=<id>` (30 s com bots) e mixar `sons.json` + quadros num MP4 com a
   mesma polifonia e limitador do jogo (`python3 tools/mixar_video.py DIR saida.mp4`).
6. Arquivo do pack em `audio/pack_<nome>/`; este manual atualizado no mesmo commit.
