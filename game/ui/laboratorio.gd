extends Node
## LABORATÓRIO: sala de medição para calibrar movimento, combate e animação (menu principal ▸ LABORATÓRIO).
## - Sala própria (levels/laboratorio.lvl): régua no chão, degraus de 1 a 4 tiles, tábuas a 4 e 6 tiles, parede.
## - Medidores ao vivo do P1: estado, linha do tempo do golpe (preparo/ativo/recuperação), esquiva, arremesso,
##   altura e distância do último pulo, distância da esquiva e do último arremesso sofrido por qualquer robô.
## - Bonecos com comportamento (parado, anda, pula, golpe rápido, marretada, esquiva) e dano fixo.
## - Painel (START / Tab): ajusta AO VIVO os números de data/controller.json e data/modos.json; SALVAR grava em
##   user://laboratorio.json (vale no jogo todo, também nas partidas); COPIAR põe os valores na área de transferência;
##   PADRÃO volta aos valores dos arquivos.

const Kit := preload("res://ui/kit.gd")
const SAVE_PATH := "user://laboratorio.json"
const SLOWS := [1.0, 0.5, 0.25]
const DUMMY := ["parado", "anda", "pula", "golpe rápido", "marretada", "esquiva"]
const DUMMY_DMG := [0.0, 30.0, 60.0, 90.0, 120.0, 150.0, 200.0]
const VISIBLE_ROWS := 13
## [rótulo, fonte ("c" = controller.json, "m" = modos.json/demolicao), caminho, passo, mín, máx, casas]
const PARAMS := [
	["Corrida: velocidade máx", "c", ["max_run"], 16.0, 200.0, 1400.0, 0],
	["Pulo: velocidade", "c", ["jump_speed"], 20.0, 300.0, 1800.0, 0],
	["Pulo: tempo segurando (s)", "c", ["var_jump_time"], 0.01, 0.0, 0.5, 2],
	["Gravidade", "c", ["gravity"], 100.0, 1000.0, 9000.0, 0],
	["Pulo duplo: força", "m", ["recuperacao", "pulo_duplo"], 0.02, 0.2, 1.6, 2],
	["Rápido: preparo (s)", "c", ["ataque_rapido", "preparo"], 0.01, 0.0, 0.4, 2],
	["Rápido: ativo (s)", "c", ["ataque_rapido", "ativo"], 0.01, 0.01, 0.4, 2],
	["Rápido: recuperação (s)", "c", ["ataque_rapido", "recupera"], 0.01, 0.0, 0.6, 2],
	["Rápido: alcance (px)", "c", ["ataque_rapido", "alcance_px"], 2.0, 16.0, 160.0, 0],
	["Rápido: dano (%)", "m", ["amassometro", "rapido", "dano"], 1.0, 0.0, 50.0, 0],
	["Rápido: empurrão", "m", ["amassometro", "rapido", "kx"], 10.0, 0.0, 1600.0, 0],
	["Rápido: empurrão por %", "m", ["amassometro", "rapido", "kx_por"], 0.2, 0.0, 20.0, 1],
	["Pesada: preparo (s)", "c", ["ataque_pesado", "preparo"], 0.01, 0.0, 0.8, 2],
	["Pesada: ativo (s)", "c", ["ataque_pesado", "ativo"], 0.01, 0.01, 0.4, 2],
	["Pesada: recuperação acertou (s)", "c", ["ataque_pesado", "recupera_acerto"], 0.01, 0.0, 0.8, 2],
	["Pesada: recuperação errou (s)", "c", ["ataque_pesado", "recupera_erro"], 0.01, 0.0, 1.2, 2],
	["Pesada: recarga (s)", "c", ["ataque_pesado", "recarga"], 0.05, 0.0, 4.0, 2],
	["Pesada: recarga se cancelada (×)", "c", ["ataque_pesado", "recarga_cancelada"], 0.05, 0.0, 1.0, 2],
	["Pesada: lentidão no preparo (×)", "c", ["ataque_pesado", "mov_mult_preparo"], 0.05, 0.0, 1.0, 2],
	["Pesada: alcance (px)", "c", ["ataque_pesado", "alcance_px"], 2.0, 16.0, 200.0, 0],
	["Pesada: dano (%)", "m", ["amassometro", "pesado", "dano"], 1.0, 0.0, 60.0, 0],
	["Pesada: empurrão", "m", ["amassometro", "pesado", "kx"], 10.0, 0.0, 2000.0, 0],
	["Pesada: empurrão por %", "m", ["amassometro", "pesado", "kx_por"], 0.2, 0.0, 25.0, 1],
	["Pesada: altura do arremesso", "m", ["amassometro", "pesado", "ky"], 10.0, 0.0, 1500.0, 0],
	["Esquiva: velocidade", "c", ["esquiva", "vel"], 40.0, 200.0, 2400.0, 0],
	["Esquiva: duração (s)", "c", ["esquiva", "duracao"], 0.01, 0.04, 0.5, 2],
	["Esquiva: proteção (s)", "c", ["esquiva", "protecao"], 0.01, 0.0, 0.5, 2],
	["Esquiva: recarga (s)", "c", ["esquiva", "recarga"], 0.05, 0.0, 2.0, 2],
	["Arremesso: sem controle base (s)", "c", ["arremesso", "sem_controle_base"], 0.01, 0.0, 0.5, 2],
	["Arremesso: sem controle por % (s)", "c", ["arremesso", "sem_controle_por"], 0.0002, 0.0, 0.01, 4],
	["Arremesso: sem controle máx (s)", "c", ["arremesso", "sem_controle_max"], 0.02, 0.0, 1.5, 2],
	["Arremesso: retorno do controle (s)", "c", ["arremesso", "retorno_s"], 0.05, 0.0, 2.0, 2],
	["Arremesso: controle inicial", "c", ["arremesso", "controle_inicial"], 0.05, 0.0, 1.0, 2],
	["Hitstop: rápido (s)", "c", ["hitstop", "rapido"], 0.005, 0.0, 0.2, 3],
	["Hitstop: pesada (s)", "c", ["hitstop", "pesado"], 0.005, 0.0, 0.3, 3],
]

var main: Node
var open := false
var sel := 0
var scroll := 0
var slow_i := 0
var god := false
var dummy_i := 0
var dummy_dmg_i := 0
var defaults := {}            # valores dos arquivos (PADRÃO)
var t := 0.0
var frame := 0
var msg := ""
var msg_t := 0.0
# medições
var jump := {"on": false, "y0": 0.0, "x0": 0.0, "top": 0.0}
var last_jump := ""
var dodge := {"on": false, "p0": Vector2.ZERO}
var last_dodge := ""
var flights := {}             # robô -> {p0, top, dmg}
var last_flight := ""
var last_atk := {}            # último golpe do P1 (para a linha do tempo continuar na tela)

func setup(m: Node) -> void:
	main = m

func rows() -> Array:
	var out := ["boneco", "comportamento", "dano_boneco", "lento", "hitbox", "invencivel", "zerar", "salvar", "copiar", "padrao", "voltar", "sair"]
	for i in PARAMS.size():
		out.append("num%d" % i)
	return out

# ---------------------------------------------------------------- valores
func _src(p: Array) -> Dictionary:
	return Data.ctrl if p[1] == "c" else main.demo.cfg

func get_value(p: Array) -> float:
	var d = _src(p)
	for k in p[2]:
		d = d[k]
	return float(d)

func set_value(p: Array, v: float) -> void:
	var d: Dictionary = _src(p)
	var path: Array = p[2]
	for i in path.size() - 1:
		d = d[path[i]]
	d[path[-1]] = clampf(v, float(p[4]), float(p[5]))

func _key(p: Array) -> String:
	return String(p[1]) + ":" + "/".join(p[2])

## Lê os valores de fábrica (arquivos) e aplica os ajustes salvos, se houver (chamado ao abrir o jogo).
func load_saved() -> void:
	var c0: Dictionary = Data.read_json("data/controller.json")
	var m0: Dictionary = Data.read_json("data/modos.json")["demolicao"]
	for p in PARAMS:
		var d = c0 if p[1] == "c" else m0
		for k in p[2]:
			d = d[k]
		defaults[_key(p)] = float(d)
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var saved = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not (saved is Dictionary):
		return
	for p in PARAMS:
		if saved.has(_key(p)):
			set_value(p, float(saved[_key(p)]))

func values() -> Dictionary:
	var out := {}
	for p in PARAMS:
		out[_key(p)] = get_value(p)
	return out

func changed_count() -> int:
	var n := 0
	for p in PARAMS:
		if absf(get_value(p) - float(defaults.get(_key(p), get_value(p)))) > 0.00001:
			n += 1
	return n

# ---------------------------------------------------------------- entrar / sair
func start(dev: String) -> void:
	main.players.clear()
	PlayerInput.slots.clear()
	main.mode = "demolicao"
	main.sandbox = true
	main.lab_mode = true
	main.add_player(dev)
	main.arena_choice = "laboratorio"
	main.game_mode = "derruba"
	main.event_level = 0
	main.events.manual = true
	main.demo.items_on = false
	main.demo.cfg["rounds_to_win"] = 999
	open = false
	god = false
	slow_i = 0
	sel = 0
	scroll = 0
	main.start_match()
	main.sandbox_add("boneco")
	if main.robots.size() > 1:
		main.robots[1].position = Vector2(15 * 64 + 32, 12 * 64)
	main.demo.banner = "LABORATÓRIO"
	main.demo.banner_t = 2.0

func stop() -> void:
	open = false
	god = false
	slow_i = 0
	Engine.time_scale = 1.0
	main.debug = false
	main.events.manual = false
	main.lab_mode = false

func toggle() -> void:
	open = not open
	main.paused = open
	Audio.play("menu_ok" if open else "menu_voltar")

func _say(s: String) -> void:
	msg = s
	msg_t = 2.0

# ---------------------------------------------------------------- painel
func update() -> void:
	var m = main.menus
	var rs := rows()
	sel = posmod(sel + m.move_v(), rs.size())
	scroll = clampi(scroll, sel - VISIBLE_ROWS + 1, sel)
	var h: int = m.move_h()
	var ok: bool = m.confirm()
	if m.pressed("back") or _pressed_start():
		toggle()
		return
	var row: String = rs[sel]
	if row.begins_with("num"):
		var p: Array = PARAMS[int(row.substr(3))]
		if h != 0:
			var fast := 5.0 if PlayerInput.held(0, "heavy") or Input.is_key_pressed(KEY_SHIFT) else 1.0
			set_value(p, snappedf(get_value(p) + h * float(p[3]) * fast, float(p[3])))
			Audio.play("menu_mover", 1.0 + 0.1 * h)
		return
	match row:
		"boneco":
			if h > 0 or ok:
				main.sandbox_add("boneco")
			elif h < 0:
				main.sandbox_remove("boneco")
		"comportamento":
			dummy_i = posmod(dummy_i + h + (1 if ok else 0), DUMMY.size())
		"dano_boneco":
			dummy_dmg_i = posmod(dummy_dmg_i + h + (1 if ok else 0), DUMMY_DMG.size())
		"lento":
			if h != 0 or ok:
				slow_i = posmod(slow_i + (h if h != 0 else 1), SLOWS.size())
				Engine.time_scale = SLOWS[slow_i]
		"hitbox":
			if h != 0 or ok:
				main.debug = not main.debug
		"invencivel":
			if h != 0 or ok:
				god = not god
		"zerar":
			if ok:
				for r in main.robots:
					r.dmg = 0.0
				Audio.play("item")
		"salvar":
			if ok:
				var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
				if f != null:
					f.store_string(JSON.stringify(values(), " "))
					f.close()
					_say("SALVO: vale no jogo todo (%d ajustes)" % changed_count())
					Audio.play("item")
		"copiar":
			if ok:
				DisplayServer.clipboard_set(JSON.stringify(values(), " "))
				_say("VALORES COPIADOS: cole na conversa com o Claude")
				Audio.play("item")
		"padrao":
			if ok:
				for p in PARAMS:
					set_value(p, float(defaults.get(_key(p), get_value(p))))
				if FileAccess.file_exists(SAVE_PATH):
					DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
				_say("VALORES DE FÁBRICA")
				Audio.play("menu_voltar")
		"voltar":
			if ok:
				toggle()
		"sair":
			if ok:
				main.go_menu()

func _pressed_start() -> bool:
	for i in main.players.size():
		if not main.players[i].get("bot", false) and not main.players[i].get("boneco", false) and PlayerInput.pressed(i, "start"):
			return true
	return false

# ---------------------------------------------------------------- a cada quadro (jogo rodando)
func tick() -> void:
	t += 1.0 / 60.0
	frame += 1
	msg_t = maxf(msg_t - 1.0 / 60.0, 0.0)
	var human = null
	for i in main.robots.size():
		var r = main.robots[i]
		var is_dummy: bool = i < main.players.size() and main.players[i].get("boneco", false)
		r.god = god and not is_dummy and not main.players[i].get("bot", false)
		if is_dummy:
			_drive_dummy(i, r)
		elif human == null:
			human = r
		_measure_flight(r)
	if human != null:
		_measure_player(human)

func _drive_dummy(i: int, r) -> void:
	var dev: String = main.players[i]["dev"]
	var inp := {}
	var target = main.robots[0] if main.robots.size() > 0 else null
	var cyc := frame % 120
	match DUMMY[dummy_i]:
		"anda":
			inp["right" if (frame / 90) % 2 == 0 else "left"] = true
		"pula":
			if frame % 75 < 14:
				inp["jump"] = true
		"golpe rápido":
			if cyc % 55 == 0:
				inp["hammer"] = true
		"marretada":
			if cyc == 0:
				inp["heavy"] = true
		"esquiva":
			if frame % 70 == 0:
				inp["dodge"] = true
				inp["right" if (frame / 70) % 2 == 0 else "left"] = true
	if DUMMY[dummy_i] in ["golpe rápido", "marretada"] and target != null and r.atk == "" and r.is_on_floor():
		r.facing = 1 if target.position.x >= r.position.x else -1   # vira para o P1
	PlayerInput.virtual[dev] = inp
	# dano fixo: volta ao valor escolhido depois de pousar quieto
	if r.is_on_floor() and r.stun_t <= 0.0 and r.recover_t <= 0.0 and r.last_hit > 1.0:
		r.dmg = DUMMY_DMG[dummy_dmg_i]

func _measure_player(r) -> void:
	var on_floor: bool = r.is_on_floor()
	if not on_floor and not jump["on"] and r.velocity.y < -100.0 and r.dodge_t <= 0.0:
		jump = {"on": true, "y0": r.position.y, "x0": r.position.x, "top": r.position.y}
	if jump["on"]:
		jump["top"] = minf(jump["top"], r.position.y)
		if on_floor or r.hanging:
			jump["on"] = false
			last_jump = "%.2f tiles de altura · %.1f tiles de distância" % [(jump["y0"] - jump["top"]) / 64.0, absf(r.position.x - jump["x0"]) / 64.0]
	if r.dodge_t > 0.0 and not dodge["on"]:
		dodge = {"on": true, "p0": r.position}
	elif r.dodge_t <= 0.0 and dodge["on"]:
		dodge["on"] = false
		last_dodge = "%.0f px (%.1f tiles)" % [r.position.distance_to(dodge["p0"]), r.position.distance_to(dodge["p0"]) / 64.0]
	if r.atk != "":
		last_atk = {"kind": r.atk, "t": r.atk_t, "landed": r.atk_landed, "hit": r.atk_hit}

func _measure_flight(r) -> void:
	if r.stun_t > 0.0 and not flights.has(r):
		flights[r] = {"p0": r.position, "top": r.position.y, "dmg": r.dmg}
	if flights.has(r):
		var fl: Dictionary = flights[r]
		fl["top"] = minf(fl["top"], r.position.y)
		if r.stun_t <= 0.0 and (r.is_on_floor() or r.hanging or not r.alive):
			var d: float = absf(r.position.x - fl["p0"].x) / 64.0
			var hgt: float = (fl["p0"].y - fl["top"]) / 64.0
			last_flight = "P%d com %d%%: %.1f tiles de distância · %.1f de altura" % [r.pid + 1, int(fl["dmg"]), d, hgt]
			flights.erase(r)

# ---------------------------------------------------------------- desenho
func _label(row: String) -> String:
	if row.begins_with("num"):
		var p: Array = PARAMS[int(row.substr(3))]
		var v := get_value(p)
		var dv := float(defaults.get(_key(p), v))
		var star := "  •" if absf(v - dv) > 0.00001 else ""
		return "%s:  ◄ %s ►%s" % [p[0], String.num(v, int(p[6])), star]
	match row:
		"boneco": return "BONECO DE TREINO:  ◄ − / + ►  (%d)" % _count("boneco")
		"comportamento": return "BONECO FAZ:  ◄ %s ►" % String(DUMMY[dummy_i]).to_upper()
		"dano_boneco": return "DANO DO BONECO:  ◄ %d%% ►" % int(DUMMY_DMG[dummy_dmg_i])
		"lento": return "VELOCIDADE DO JOGO:  ◄ %s ►" % ["1×", "½×", "¼×"][slow_i]
		"hitbox": return "HITBOX:  %s" % ("SIM" if main.debug else "NÃO")
		"invencivel": return "INVENCÍVEL:  %s" % ("SIM" if god else "NÃO")
		"zerar": return "ZERAR DANO DE TODOS"
		"salvar": return "SALVAR AJUSTES (valem no jogo todo)"
		"copiar": return "COPIAR VALORES (para mandar ao Claude)"
		"padrao": return "VOLTAR AOS VALORES DE FÁBRICA"
		"voltar": return "VOLTAR AO JOGO"
		"sair": return "SAIR DO LABORATÓRIO"
	return row

func _count(kind: String) -> int:
	var n := 0
	for p in main.players:
		if p.get(kind, false):
			n += 1
	return n

func draw(ci: CanvasItem) -> void:
	if open:
		_draw_panel(ci)
		return
	_draw_meters(ci)
	if msg_t > 0.0:
		Kit.sticker(ci, Vector2(960, 1000), msg, 30, Color("#3c9a46"))

func _draw_panel(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(0, 0, 1920, 1080), Color(0.1, 0.25, 0.3, 0.35))
	var r := Rect2(40, 110, 1000, 950)
	Kit.paper(ci, r)
	Kit.ribbon(ci, Rect2(200, 40, 680, 110), "LABORATÓRIO", 54)
	var rs := rows()
	for k in VISIBLE_ROWS:
		var i := scroll + k
		if i >= rs.size():
			break
		var y := r.position.y + 92 + k * 64
		var on := i == sel
		if rs[i] == "num0":
			Kit.text(ci, Vector2(r.position.x + 60, y - 50), "AJUSTES AO VIVO  (◄► muda · segure Y/Shift: 5×  · • = diferente da fábrica)", 20, Color("#8a5a2a"))
		if on:
			ci.draw_rect(Rect2(r.position.x + 30, y - 44, r.size.x - 60, 60), Color(0.95, 0.78, 0.29, 0.55))
		Kit.text(ci, Vector2(r.position.x + 60, y), _label(rs[i]), 28, Color("#2a1a2e") if on else Color("#3e5a62"))
	# barra de rolagem
	var frac := float(scroll) / maxf(rs.size() - VISIBLE_ROWS, 1)
	ci.draw_rect(Rect2(r.end.x - 26, r.position.y + 40, 8, r.size.y - 80), Color(0, 0, 0, 0.1))
	ci.draw_rect(Rect2(r.end.x - 26, r.position.y + 40 + frac * (r.size.y - 160), 8, 80), Color("#8a5a2a"))
	Kit.text(ci, Vector2(0, 1066), "▲▼ escolher  ·  ◄► mudar  ·  PULAR confirmar  ·  START / TAB / ESC fecha", 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 1920, 7)

## Medidores do P1 (canto esquerdo) e resultados das medições (embaixo).
func _draw_meters(ci: CanvasItem) -> void:
	if main.robots.is_empty():
		return
	var r = main.robots[0]
	var c: Dictionary = Data.ctrl
	var box := Rect2(20, 110, 560, 394)
	ci.draw_rect(box, Color(1, 1, 1, 0.82))
	ci.draw_rect(box, Color("#2a1a2e"), false, 3.0)
	var x := box.position.x + 20
	var y := box.position.y + 42
	Kit.text(ci, Vector2(x, y), "LABORATÓRIO · P1  ·  START: painel", 24, Color("#2a1a2e"))
	y += 40
	Kit.text(ci, Vector2(x, y), "Estado: " + _state(r), 26, Color("#3c4a8a"))
	y += 22
	# linha do tempo do golpe: preparo (amarelo) · ativo (vermelho) · recuperação (cinza)
	var a: Dictionary = last_atk
	if not a.is_empty():
		var ac: Dictionary = c["ataque_rapido"] if a["kind"] == "rapido" else c["ataque_pesado"]
		var rec := float(ac["recupera"]) if a["kind"] == "rapido" else (float(ac["recupera_acerto"]) if a["landed"] else float(ac["recupera_erro"]))
		var segs := [[float(ac["preparo"]), Color("#f2c84b")], [float(ac["ativo"]), Color("#d42035")], [rec, Color("#9aa4ae")]]
		var total := 0.0
		for s in segs:
			total += s[0]
		var bw := 380.0
		var bx := x + 140.0
		Kit.text(ci, Vector2(x, y + 22), "RÁPIDO" if a["kind"] == "rapido" else "PESADA", 20, Color("#2a1a2e"))
		var px := bx
		for s in segs:
			var w: float = bw * s[0] / maxf(total, 0.001)
			ci.draw_rect(Rect2(px, y + 4, w, 22), s[1])
			px += w
		var cur: float = float(r.atk_t) if r.atk != "" else total
		ci.draw_rect(Rect2(bx + bw * clampf(cur / maxf(total, 0.001), 0.0, 1.0) - 2, y, 4, 30), Color("#2a1a2e"))
		Kit.text(ci, Vector2(bx, y + 50), "%d + %d + %d quadros%s" % [roundi(segs[0][0] * 60), roundi(segs[1][0] * 60), roundi(rec * 60), ("  · acertou" if a["landed"] else "  · errou")], 18, Color("#3e5a62"))
	y += 74
	_bar(ci, Vector2(x, y), "Sem controle", r.stun_t / maxf(float(c["arremesso"]["sem_controle_max"]), 0.01), Color("#d42035"))
	_bar(ci, Vector2(x, y + 34), "Recuperando", r.recover_t / maxf(r.recover_len, 0.01), Color("#f2a23a"))
	_bar(ci, Vector2(x, y + 68), "Proteção", r.guard_t / maxf(float(c["esquiva"]["protecao"]), 0.01), Color("#5cc45c"))
	_bar(ci, Vector2(x, y + 102), "Recarga esquiva", r.dodge_cd / maxf(float(c["esquiva"]["recarga"]), 0.01), Color("#4f86d9"))
	_bar(ci, Vector2(x, y + 136), "Recarga pesada", r.heavy_cd / maxf(float(c["ataque_pesado"]["recarga"]), 0.01), Color("#8a63d2"))
	y += 184
	Kit.text(ci, Vector2(x, y), "Esquiva no ar: %s   Pulo duplo: %s   Dano: %d%%" % ["●" if r.air_dodge > 0 else "○", "●" if r.air_jumps > 0 else "○", int(r.dmg)], 22, Color("#2a1a2e"))
	# entradas apertadas
	var keys := [["◄", "left"], ["►", "right"], ["▲", "up"], ["▼", "down"], ["PULO", "jump"], ["GOLPE", "hammer"], ["PESADA", "heavy"], ["ESQUIVA", "dodge"]]
	var kx := 20.0
	for k in keys:
		var on: bool = PlayerInput.held(0, k[1])
		var w: float = 34.0 + 13.0 * String(k[0]).length()
		var kr := Rect2(kx, 516, w, 40)
		ci.draw_rect(kr, Color("#f2c84b") if on else Color(1, 1, 1, 0.6))
		ci.draw_rect(kr, Color("#2a1a2e"), false, 2.0)
		Kit.text(ci, Vector2(kr.position.x, kr.position.y + 29), k[0], 20, Color("#2a1a2e"), HORIZONTAL_ALIGNMENT_CENTER, w)
		kx += w + 6.0
	# resultados
	var lines := []
	if last_jump != "":
		lines.append("Último pulo: " + last_jump)
	if last_dodge != "":
		lines.append("Última esquiva: " + last_dodge)
	if last_flight != "":
		lines.append("Último arremesso: " + last_flight)
	lines.append("Boneco: %s · %d%%   ·   velocidade %s   ·   %d ajuste(s) fora da fábrica" % [DUMMY[dummy_i], int(DUMMY_DMG[dummy_dmg_i]), ["1×", "½×", "¼×"][slow_i], changed_count()])
	for i in lines.size():
		Kit.sticker(ci, Vector2(20, 614 + i * 44), lines[i], 24, Color("#2a1a2e"), HORIZONTAL_ALIGNMENT_LEFT)

func _bar(ci: CanvasItem, p: Vector2, label: String, k: float, col: Color) -> void:
	Kit.text(ci, p + Vector2(0, 20), label, 20, Color("#2a1a2e"))
	var r := Rect2(p.x + 190, p.y + 2, 320, 20)
	ci.draw_rect(r, Color(0, 0, 0, 0.08))
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(k, 0.0, 1.0), r.size.y)), col)
	ci.draw_rect(r, Color("#2a1a2e"), false, 2.0)

func _state(r) -> String:
	if r.hitstop > 0.0:
		return "IMPACTO (hitstop)"
	if r.stun_t > 0.0:
		return "ARREMESSADO (sem controle)"
	if r.dodge_t > 0.0:
		return "ESQUIVA%s" % (" · PROTEGIDO" if r.guard_t > 0.0 else "")
	if r.atk != "":
		var ac: Dictionary = Data.ctrl["ataque_rapido"] if r.atk == "rapido" else Data.ctrl["ataque_pesado"]
		var ph := "PREPARO" if not r.atk_hit else ("ATIVO" if r.atk_t < float(ac["preparo"]) + float(ac["ativo"]) else "RECUPERAÇÃO")
		return "%s · %s" % ["GOLPE RÁPIDO" if r.atk == "rapido" else "MARRETADA PESADA", ph]
	if r.recover_t > 0.0 and not r.is_on_floor():
		return "RECUPERANDO O CONTROLE"
	if r.hanging:
		return "NA BORDA"
	if r.wall_sliding:
		return "NA PAREDE"
	if not r.is_on_floor():
		return "NO AR (subindo)" if r.velocity.y < 0.0 else "NO AR (caindo)"
	if absf(r.velocity.x) > 40.0:
		return "CORRENDO"
	return "PARADO"

## Régua no mundo: marcas a cada tile no chão e alturas de 1 a 7 tiles na parede da esquerda.
func draw_world(ci: CanvasItem) -> void:
	if main.level == null:
		return
	var floor_y := 13 * 64.0
	var ink := Color(0.16, 0.1, 0.18, 0.75)
	for col in range(1, 29):
		var xx := col * 64.0
		var big := col % 5 == 0
		ci.draw_line(Vector2(xx, floor_y - (16.0 if big else 8.0)), Vector2(xx, floor_y), ink, 3.0 if big else 2.0)
		if big:
			Kit.text(ci, Vector2(xx - 30, floor_y + 34), str(col), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 60, 5, Kit.INK)
	for h in range(1, 8):
		var yy := floor_y - h * 64.0
		var x0 := 5 * 64.0
		for k in range(0, 21):
			var sx := x0 + k * 64.0
			ci.draw_line(Vector2(sx, yy), Vector2(sx + 24.0, yy), Color(0.16, 0.1, 0.18, 0.13), 2.0)
		Kit.text(ci, Vector2(x0 - 58, yy + 8), "%d" % h, 20, Color(0.16, 0.1, 0.18, 0.6), HORIZONTAL_ALIGNMENT_RIGHT, 50)
