extends Node
## Som do jogo: efeitos (com variações sorteadas e leve variação de tom) e música em loop com transição suave.
## Sons gerados por tools/sfxforge.py a partir de audio/sfx/*.json e audio/music/*.json (índice em assets/audio/sons.json).
## Volumes 0..10 (OPÇÕES), salvos em user://opcoes.cfg junto com as outras opções.

const VOICE_PITCH := {"lata": 1.0, "tv": 1.18, "baixinho": 1.4, "pescocao": 0.78}
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
	"item": 0.1, "locutor": 0.6, "aterrissa": 0.08, "lama": 0.2, "menu_mover": 0.04}
var rec_log = null           # capturas de vídeo: lista de {t, path, pitch, db}; null = não grava
var rec_time := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if FileAccess.file_exists("res://assets/audio/sons.json"):
		_index = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/sons.json"))
	for i in 16:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	add_child(_music)
	# carrega todos os efeitos já na abertura (o primeiro uso no meio da partida dava tranco)
	for k in _index.keys():
		var n: int = int(_index[k])
		if n == 0:
			_stream("res://assets/audio/sfx/%s.wav" % k)
		else:
			for i in range(1, n + 1):
				_stream("res://assets/audio/sfx/%s_%d.wav" % [k, i])
	# limitador no áudio principal: muitos sons juntos (explosão + marretadas) não estouram
	var lim := AudioEffectHardLimiter.new()
	lim.ceiling_db = -0.5
	AudioServer.add_bus_effect(0, lim)

func _process(dt: float) -> void:
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
	if not _index.has(sfx) or sfx_vol <= 0 or _cooldown.has(sfx):
		return
	_cooldown[sfx] = COOLDOWN.get(sfx, 0.03)
	var n: int = int(_index[sfx])
	var path := "res://assets/audio/sfx/%s.wav" % sfx if n == 0 else "res://assets/audio/sfx/%s_%d.wav" % [sfx, randi_range(1, n)]
	var st := _stream(path)
	if st == null:
		return
	var p: AudioStreamPlayer = null
	for q in _pool:
		if not q.playing:
			p = q
			break
	if p == null:
		p = _pool[0]
		_pool.push_back(_pool.pop_front())   # rouba o mais antigo
	p.stream = st
	p.pitch_scale = pitch * randf_range(0.97, 1.03)
	p.volume_db = _db(sfx_vol) + vol
	p.play()
	if rec_log != null:
		rec_log.append({"t": rec_time, "path": path, "pitch": p.pitch_scale, "db": p.volume_db})

## Voz do robô: o tom depende do modelo (Baixinho fininho, Pescoção grave).
func voice(sfx: String, model: int) -> void:
	play(sfx, VOICE_PITCH.get(Data.MODELS[clampi(model, 0, 3)], 1.0))

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
		_music.volume_db = _db(music_vol)
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
		_music.volume_db = _db(music_vol)
