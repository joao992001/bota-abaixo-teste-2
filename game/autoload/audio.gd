extends Node
## Som do jogo: efeitos (com variações sorteadas e leve variação de tom) e música em loop com transição suave.
## Sons gerados por tools/sfxforge.py a partir de audio/sfx/*.json e audio/music/*.json (índice em assets/audio/sons.json).
## Volumes 0..10 (OPÇÕES), salvos em user://opcoes.cfg junto com as outras opções.

var sfx_vol := 8
var music_vol := 6
var _index := {}
var _cache := {}
var _pool: Array = []
var _music: AudioStreamPlayer
var _music_name := ""
var _cooldown := {}          # evita o mesmo som empilhado no mesmo instante
## Intervalo mínimo entre repetições dos sons que disparam toda hora (o resto: 0,03 s).
const COOLDOWN := {"passo": 0.09, "parede": 0.15, "caixote_pancada": 0.06, "marreta_vento": 0.07, "bonk": 0.08,
	"item": 0.1, "locutor": 0.6, "aterrissa": 0.08, "lama": 0.2, "menu_mover": 0.04,
	"ba_passo": 0.1, "ba_aterrissa_leve": 0.08, "ba_aterrissa_pesada": 0.08, "ba_salto": 0.05, "ba_salto_duplo": 0.05,
	"ba_ko_fora": 0.12}
## PACK DE ÁUDIO APROVADO (VB, 2026-11-25): sons básicos de movimento, golpes e KO. Arquivos em assets/audio/aprovado/
## (fonte, referências e instruções em audio/pack_vb/). Cada id sorteia entre as variações. Ganhos em dB por id: os
## arquivos já vêm mixados como na referência aprovada (passos já reduzidos −14 dB na fonte: NÃO reduzir de novo).
const APROVADO := {
	"ba_passo": [["passo_metal_01", "passo_metal_02", "passo_metal_03", "passo_metal_04"], 0.0],
	"ba_salto": [["salto_01", "salto_02"], 0.0],
	"ba_salto_duplo": [["salto_duplo_01", "salto_duplo_02"], 0.0],
	"ba_aterrissa_leve": [["aterrissagem_leve"], 0.0],
	"ba_aterrissa_pesada": [["aterrissagem_pesada"], 0.0],
	"ba_dash_solo": [["dash_solo"], 0.0],
	"ba_dash_aereo": [["dash_aereo"], 0.0],
	"ba_esquiva_solo": [["esquiva_solo"], 0.0],
	"ba_esquiva_aerea": [["esquiva_aerea"], 0.0],
	"ba_marreta_rapida": [["marreta_rapida_metal"], 0.0],
	"ba_marreta_pesada": [["marreta_pesada_metal"], 0.0],
	"ba_impacto_rapido": [["impacto_robo_rapido_01", "impacto_robo_rapido_02", "impacto_robo_rapido_03", "impacto_robo_rapido_04", "impacto_robo_rapido_05"], 0.0],
	"ba_impacto_pesado": [["impacto_robo_pesado_01", "impacto_robo_pesado_02", "impacto_robo_pesado_03", "impacto_robo_pesado_04"], 0.0],
	"ba_ko_fora": [["explosao_fora_arena_padrao"], 0.0],
}
## Ganho próprio de cada música (dB). rock_cartoon: o OGG já vem no nível da referência B (−25,6 dB da fonte; NÃO
## aplicar −14 dB de novo); +2,5 dB compensa a diferença entre os volumes padrão de MÚSICA (6) e EFEITOS (8), para que
## nos volumes padrão a relação música × efeitos seja a da referência aprovada.
const MUSIC_GAIN := {"rock_cartoon": 2.5}
## Polifonia: no máximo N cópias do mesmo som ao mesmo tempo (a mais antiga é cortada) e prioridade quando faltam
## canais (explosão e pancada pesada > pancada rápida > pulo/dash > passos): o som de menor prioridade cede a vez.
const MAX_VOICES := {"ba_impacto_rapido": 3, "ba_impacto_pesado": 2, "ba_marreta_rapida": 2, "ba_marreta_pesada": 2,
	"ba_passo": 2, "ba_aterrissa_leve": 2, "ba_aterrissa_pesada": 2, "ba_salto": 2, "ba_salto_duplo": 2, "ba_ko_fora": 2}
const PRIO := {"ba_ko_fora": 3, "ba_impacto_pesado": 3, "ba_marreta_pesada": 3, "ba_impacto_rapido": 2, "ba_marreta_rapida": 2,
	"ba_passo": 0, "passo": 0}
## Abaixa a música rapidinho nas explosões de KO (referência: 0,43 linear, volta em 0,48 s).
const DUCK := [0.43, 0.48]
var _duck := 1.0
var _music_gain := 0.0
var _last_variant := {}     # não repete a mesma variação duas vezes seguidas
var rec_log = null           # capturas de vídeo: lista de {t, path, pitch, db}; null = não grava
var rec_time := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if FileAccess.file_exists("res://assets/audio/sons.json"):
		_index = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/sons.json"))
	for i in 24:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	# barramentos separados: Música e Efeitos (silenciar a música não silencia os efeitos)
	for bn in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bn) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bn)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	for q in _pool:
		q.bus = "SFX"
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	# carrega todos os efeitos já na abertura (o primeiro uso no meio da partida dava tranco)
	for k in _index.keys():
		var n: int = int(_index[k])
		if n == 0:
			_stream("res://assets/audio/sfx/%s.wav" % k)
		else:
			for i in range(1, n + 1):
				_stream("res://assets/audio/sfx/%s_%d.wav" % [k, i])
	for k in APROVADO.keys():
		for f in APROVADO[k][0]:
			_stream("res://assets/audio/aprovado/%s.wav" % f)
	# limitador no áudio principal: muitos sons juntos (explosão + marretadas) não estouram
	var lim := AudioEffectHardLimiter.new()
	lim.ceiling_db = -0.5
	AudioServer.add_bus_effect(0, lim)

func _process(dt: float) -> void:
	if _duck < 1.0:
		_duck = minf(_duck + dt * (1.0 - DUCK[0]) / DUCK[1], 1.0)
		_apply_music_vol()
	for k in _cooldown.keys():
		_cooldown[k] -= dt
		if _cooldown[k] <= 0.0:
			_cooldown.erase(k)

func _db(v: int) -> float:
	return -80.0 if v <= 0 else linear_to_db(v / 10.0)

func _stream(path: String) -> AudioStream:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]

## Toca um efeito. pitch: tom (vozes por modelo, jogador); vol: ajuste em dB.
func play(sfx: String, pitch := 1.0, vol := 0.0) -> void:
	if (not _index.has(sfx) and not APROVADO.has(sfx)) or sfx_vol <= 0 or _cooldown.has(sfx):
		return
	_cooldown[sfx] = COOLDOWN.get(sfx, 0.03)
	var path: String
	if APROVADO.has(sfx):   # pack aprovado: variação sorteada sem repetir a anterior; tom quase original
		var fs: Array = APROVADO[sfx][0]
		var i := randi_range(0, fs.size() - 1)
		if fs.size() > 1 and i == int(_last_variant.get(sfx, -1)):
			i = (i + 1) % fs.size()
		_last_variant[sfx] = i
		path = "res://assets/audio/aprovado/%s.wav" % fs[i]
		vol += float(APROVADO[sfx][1])
	else:
		var n: int = int(_index[sfx])
		path = "res://assets/audio/sfx/%s.wav" % sfx if n == 0 else "res://assets/audio/sfx/%s_%d.wav" % [sfx, randi_range(1, n)]
	var st := _stream(path)
	if st == null:
		return
	var p: AudioStreamPlayer = null
	var prio := int(PRIO.get(sfx, 1))
	var same: Array = _pool.filter(func(q): return q.playing and q.get_meta("sfx", "") == sfx)
	if same.size() >= int(MAX_VOICES.get(sfx, 99)):
		same.sort_custom(func(a, b): return int(a.get_meta("t0", 0)) < int(b.get_meta("t0", 0)))
		p = same[0]   # corta a cópia mais antiga do mesmo som
	if p == null:
		for q in _pool:
			if not q.playing:
				p = q
				break
	if p == null:   # sem canal livre: cede o de menor prioridade (e mais antigo); se todos valem mais, não toca
		var best = null
		for q in _pool:
			var k := [int(q.get_meta("prio", 1)), int(q.get_meta("t0", 0))]
			if best == null or k[0] < best[0] or (k[0] == best[0] and k[1] < best[1]):
				best = [k[0], k[1], q]
		if best[0] > prio:
			return
		p = best[2]
	p.set_meta("sfx", sfx)
	p.set_meta("prio", prio)
	p.set_meta("t0", Time.get_ticks_msec())
	p.stream = st
	p.pitch_scale = pitch * randf_range(0.97, 1.03)
	p.volume_db = _db(sfx_vol) + vol
	p.play()
	if rec_log != null:
		rec_log.append({"t": rec_time, "path": path, "pitch": p.pitch_scale, "db": p.volume_db})

## Voz do robô: o tom depende do modelo (Baixinho fininho, Brutamontes grave): campo "voz" de modelos.json.
func voice(sfx: String, model: int) -> void:
	play(sfx, float(Data.model_meta(model).get("voz", 1.0)))

## Música em loop; troca com transição suave. "" para silenciar.
func music(name: String, loop := true) -> void:
	if name == _music_name:
		return
	_music_name = name
	var tw := create_tween()
	if _music.playing:
		tw.tween_property(_music, "volume_db", -40.0, 0.35)
	tw.tween_callback(func():
		if name == "":
			_music.stop()
			return
		var path := "res://assets/audio/music/%s.ogg" % name
		if not ResourceLoader.exists(path):
			path = "res://assets/audio/music/%s.wav" % name
		var st := _stream(path)
		if st is AudioStreamOggVorbis:
			st.loop = loop   # músicas em OGG (10x menores que WAV)
		elif st is AudioStreamWAV:
			st.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
			st.loop_begin = 0
			st.loop_end = int(st.get_length() * st.mix_rate)
		_music.stream = st
		_music_gain = float(MUSIC_GAIN.get(name, 0.0))
		_apply_music_vol()
		_music.play()
		if rec_log != null:
			rec_log.append({"t": rec_time + 0.35, "path": path, "pitch": 1.0, "db": _music.volume_db, "music": true}))

## Música mais rápida na tensão (terremoto, relógio acabando, morte súbita). 1.0 = normal.
var _tempo := 1.0
func music_tempo(k: float, dt: float) -> void:
	_tempo = move_toward(_tempo, k, dt * 0.25)
	_music.pitch_scale = _tempo

func set_volumes(m: int, s: int) -> void:
	music_vol = clampi(m, 0, 10)
	sfx_vol = clampi(s, 0, 10)
	if _music.playing:
		_apply_music_vol()

func _apply_music_vol() -> void:
	_music.volume_db = _db(music_vol) + _music_gain + linear_to_db(_duck)

## Abaixa a música por um instante (explosão de KO); os efeitos não mudam.
func duck() -> void:
	_duck = DUCK[0]
	if rec_log != null:
		rec_log.append({"t": rec_time, "duck": true})
	if _music.playing:
		_apply_music_vol()
