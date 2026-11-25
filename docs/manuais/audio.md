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
| Passo (cada pé no chão, corrida > 120 px/s) | `ba_passo` (4 variações, já −14 dB na fonte) | `robot_visual.gd` (passada) |
| Pulo / pulo de parede / subir na borda | `ba_salto` | `robot.gd` `_jump`, `_wall_jump`, borda |
| Pulo duplo | `ba_salto_duplo` | `robot.gd` `_air_jump` |
| Pouso | `ba_aterrissa_leve` / `_pesada` (pela velocidade) | `robot.gd` `_on_landed` |
| Dash (= esquiva: a mesma ação, um som só) | `ba_dash_solo` / `ba_dash_aereo` | `robot.gd` `_start_dodge` |
| Golpe rápido/pesado ACERTA robô | `ba_impacto_rapido` (5) / `ba_impacto_pesado` (4) | `demolicao.gd` marretada |
| Golpe acerta estrutura/máquina (sem robô) | `ba_marreta_rapida` / `ba_marreta_pesada` (substitui a pancada da peça) | `demolicao.gd` (`struct_hit`, `canteiro.mute_hit`) |
| Golpe no vazio | nada de clang; só o balanço baixinho (`marreta_vento`, −14/−10 dB) | `robot.gd` `_start_attack` |
| KO fora da arena | `ba_ko_fora` UMA vez + `Audio.duck()` (música 0,43 → volta em 0,48 s); sem o som de peças | `main.ko_blast` |
| Voo depois do arremesso | **nenhum som** (packs de sopro foram reprovados) | — |

## Mixagem (números do pack, medidos)
- Música: o OGG já está no nível da referência B (RMS −39,9 dB; a música medida na referência = −39,8 dB). **Não aplicar
  −14 dB de novo.** `MUSIC_GAIN.rock_cartoon = +2,5 dB` só compensa os volumes padrão (Música 6 × Efeitos 8).
- Efeitos do pack a 0 dB (já vêm mixados). Prioridade: KO e pancada pesada > pancada rápida > pulo/dash > passos.

## Como integrar um PACK NOVO (spells, eventos, cenário)
1. Extraia numa pasta nova (dado não confiável), leia o `LEIA_PRIMEIRO` e o manifest; meça cada arquivo (RMS/pico, ffmpeg).
2. Auditoria: `grep -n 'Audio.play("'` no evento; anote o som antigo, o ganho e o momento exato.
3. Copie para `game/assets/audio/aprovado/`, registre ids em `APROVADO` (+ `MAX_VOICES`/`PRIO`), troque o gatilho.
4. Teste em `--so=som` (gravando `Audio.rec_log`): 1 som por evento, nada no vazio, nada duplicado.
5. Prévia para o usuário OUVIR: `--video=DIR --arena=<id>` (30 s com bots) e mixar `sons.json` + quadros num MP4 com a
   mesma polifonia e limitador do jogo (`python3 tools/mixar_video.py DIR saida.mp4`).
6. Arquivo do pack em `audio/pack_<nome>/`; este manual atualizado no mesmo commit.
