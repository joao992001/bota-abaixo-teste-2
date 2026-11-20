extends Node
## Bots do Modo Festa (Demolição). Cada bot é um jogador com dispositivo virtual "botN": o cérebro
## escreve os botões em PlayerInput.virtual, então o robô do bot usa exatamente o mesmo controle dos humanos.
## Prioridades: fugir de dinamite > sair de caixote rachando > atacar de perto > arremessar dinamite >
## pegar item > ir até o rival (pulando buracos com segurança). Dificuldade em data/modos.json ("bots").

const LEVELS := ["facil", "medio", "dificil"]
const LEVEL_NAMES := ["fácil", "médio", "difícil"]
var main: Node
var cfg: Dictionary
var state := {}      # dev -> {think, cmd, jump_hold, pulse_hammer, pulse_item, last_pos, stuck}

func setup(m: Node) -> void:
	main = m
	cfg = Data.read_json("data/modos.json")["bots"]

func reset() -> void:
	state.clear()

func update(dt: float) -> void:
	for p in main.players:
		if not p.get("bot", false):
			continue
		var dev: String = p["dev"]
		var r = _robot_of(dev)
		if r == null or not r.alive or not r.active or main.state != main.S.RUN:
			PlayerInput.virtual[dev] = {}
			continue
		var st: Dictionary = state.get(dev, {"think": 0.0, "cmd": {}, "jump_hold": 0, "pulse_hammer": false, "pulse_item": false,
			"last_pos": r.position, "stuck": 0.0})
		state[dev] = st
		var lv: Dictionary = cfg[LEVELS[p.get("level", 1)]]
		st["think"] -= dt
		st["hammer_cd"] = st.get("hammer_cd", 0.0) - dt
		if st["think"] <= 0.0:
			st["think"] = float(lv["react_s"]) * main.rng.randf_range(0.8, 1.4)
			st["cmd"] = _decide(r, lv, st)
			if st["cmd"].get("jump", false) and st["jump_hold"] <= 0 and r.is_on_floor():
				st["jump_hold"] = st["cmd"].get("jump_frames", 14)
			st["pulse_hammer"] = st["cmd"].get("hammer", false)
			st["pulse_item"] = st["cmd"].get("item", false)
		var cmd: Dictionary = st["cmd"]
		if r.is_on_floor() and not cmd.get("distracted", false) and r.fall_reason == "distraído":
			r.fall_reason = ""
		# segurança a cada quadro (a decisão pode ter sido tomada no ar)
		if r.is_on_floor() and cmd.get("dir", 0) != 0 and not cmd.get("distracted", false):
			var chk := _safe(r, {"dir": cmd["dir"]}, lv, false)
			if chk.get("dir", 0) == 0:
				cmd = cmd.duplicate()
				cmd["dir"] = 0
			elif chk.get("jump", false) and (st["jump_hold"] <= 0 or PlayerInput.virtual.get(dev, {}).get("jump", false)):
				# ainda segurando o pulo anterior: solta 1 quadro para o novo pulo valer
				st["release"] = PlayerInput.virtual.get(dev, {}).get("jump", false)
				st["jump_hold"] = chk.get("jump_frames", 16)
				cmd = cmd.duplicate()
				cmd["jump_frames"] = st["jump_hold"]
				cmd["land"] = chk.get("land", Vector2i(-9, -9))
		# preso: querendo andar (depois da checagem de segurança) sem sair do lugar, ex.: degrau
		if r.position.distance_to(st["last_pos"]) < 1.0 and cmd.get("dir", 0) != 0:
			st["stuck"] += dt
		else:
			st["stuck"] = 0.0
		st["last_pos"] = r.position
		if st["stuck"] > 0.6 and r.is_on_floor():
			st["jump_hold"] = 14
			st["stuck"] = 0.0
		if OS.has_environment("BOT_DEBUG"):
			var was: bool = st.get("was_floor", true)
			if r.is_on_floor():
				st["floor_y"] = r.position.y
			if was and not r.is_on_floor():
				var rowd := int((float(st.get("floor_y", r.position.y)) + 2.0) / 64.0)
				var cl := ""
				for dc in range(-3, 4):
					cl += "#" if main.level.is_solid(Vector2i(int(r.position.x / 64.0) + dc, rowd)) else "."
				cl += " linha=%d" % rowd
				r.set_meta("takeoff", "x=%.0f col=%d vx=%.0f vy=%.0f chão[-3..3]=%s cmd=%s" % [r.position.x, int(r.position.x / 64.0), r.velocity.x, r.velocity.y, cl, str(cmd)])
			if was and not r.is_on_floor() and r.velocity.y >= 0.0 and r.last_hit > 2.0:
				var row := int((r.position.y + 2.0) / 64.0)
				var cells := ""
				for dc in range(-2, 3):
					cells += "#" if main.level.is_solid(Vector2i(int(r.position.x / 64.0) + dc, row)) else "."
				print("    SAIU DO CHÃO P%d x=%.0f vx=%.0f cmd=%s chão[-2..2]=%s stun=%.2f" % [r.pid + 1, r.position.x, r.velocity.x, str(cmd), cells, r.stun_t])
			st["was_floor"] = r.is_on_floor()
		var inp := {}
		var dir: int = cmd.get("dir", 0)
		if dir < 0:
			inp["left"] = true
		elif dir > 0:
			inp["right"] = true
		if cmd.get("down", false):
			inp["down"] = true
		var prev: Dictionary = PlayerInput.virtual.get(dev, {})
		if st.get("release", false):
			st["release"] = false   # solta agora; aperta no próximo quadro
		elif st["jump_hold"] > 0:
			inp["jump"] = not (prev.get("jump", false) and st["jump_hold"] == cmd.get("jump_frames", 14))
			st["jump_hold"] -= 1
		# marreta e item: um quadro apertado (borda), depois solta
		if st["pulse_hammer"] and not prev.get("hammer", false):
			inp["hammer"] = true
			st["pulse_hammer"] = false
		if st["pulse_item"] and not prev.get("item", false):
			inp["item"] = true
			st["pulse_item"] = false
		_recover(r, st, inp, prev, dt)
		PlayerInput.virtual[dev] = inp

func _robot_of(dev: String):
	var i: int = PlayerInput.slots.find(dev)
	if i < 0 or i >= main.robots.size():
		return null
	return main.robots[i]

func _decide(r, lv: Dictionary, st: Dictionary) -> Dictionary:
	var L = main.level
	var demo = main.demo
	var pos: Vector2 = r.position
	var center: Vector2 = r.rect().get_center()
	var row := int((pos.y + 2.0) / 64.0)
	var col := int(pos.x / 64.0)
	var cmd := {"dir": 0}
	if r.item == "tabua" and not r.is_on_floor() and r.velocity.y > 250.0 and pos.y > 64.0 * (L.rows - 5):
		cmd["item"] = true   # tábua de emergência caindo no buraco
	# 1) fugir de dinamite
	for d in demo.dynamites:
		if d["pos"].distance_to(center) < 220.0:
			cmd["dir"] = 1 if center.x >= d["pos"].x else -1
			cmd["jump"] = true
			return _safe(r, cmd, lv)
	# 1b) máquinas da arena (chama, pistão, serra, barril): sair de perto ou pular por cima
	var fx0 = demo.fx
	if fx0 != null and is_instance_valid(fx0):
		var hz: Vector2 = fx0.hazard_near(center, 110.0)
		if hz != Vector2.INF:
			cmd["dir"] = 1 if center.x >= hz.x else -1
			if hz.y > center.y - 10.0 and absf(hz.x - center.x) < 90.0:
				cmd["jump"] = true
			return _safe(r, cmd, lv)
		# alavanca ao alcance e rival em cima do alçapão: marreta a alavanca
		for lvr in fx0.levers:
			var lc: Vector2 = Vector2(lvr["cell"] * 64) + Vector2(32, 32)
			if absf(lc.x - pos.x) < 90.0 and absf(lc.y - center.y) < 60.0 and fx0.traps_open_t <= 0.0 and fx0.someone_on_traps(r):
				var want := 1 if lc.x > pos.x else -1
				if want != r.facing:
					cmd["dir"] = want
				elif st.get("hammer_cd", 0.0) <= 0.0:
					cmd["hammer"] = true
					st["hammer_cd"] = float(lv["hammer_cooldown_s"])
				return cmd
	# 2) caixote embaixo rachando / tremendo: sair dele
	var under := Vector2i(col, row)
	if r.is_on_floor() and L.blocks.has(under):
		var b: Dictionary = L.blocks[under]
		if b["warn"] > 0.0 or b["load"] > float(demo.cfg["crumble_crack_s"]) * 0.8:
			for dc in [1, -1, 2, -2, 3, -3]:
				var c2 := Vector2i(col + dc, row)
				if L.is_solid(c2) and not (L.blocks.has(c2) and L.blocks[c2]["warn"] > 0.0):
					cmd["dir"] = signi(dc)
					return _safe(r, cmd, lv)
	# 2b) maré de lama chegando: subir para o caixote mais alto alcançável
	var fx = demo.fx
	var climb: bool = fx != null and is_instance_valid(fx) and fx.goo_on and fx.goo_y - pos.y < 330.0
	if fx != null and is_instance_valid(fx) and fx.scroll_on and fx.scroll_dir == "cima" and pos.y > fx.scroll_center.y + 120.0:
		climb = true   # Torre: a câmera sobe, não pode ficar para trás
	if fx != null and is_instance_valid(fx) and fx.scroll_on and fx.scroll_dir != "cima" and pos.x < fx.scroll_center.x - 380.0:
		cmd["dir"] = 1   # Ponte: a câmera avança, segue em frente
		return _safe(r, cmd, lv)
	if climb and r.is_on_floor():
		var best := Vector2i(-1, -1)
		for dr in range(1, 5):
			for dc in range(-7, 8):
				var cc := Vector2i(col + dc, row - dr)
				if L.is_solid(cc) and not L.is_solid(cc + Vector2i.UP) and not L.is_solid(cc + Vector2i(0, -2)):
					if best.x < 0 or absi(dc) < absi(best.x - col):
						best = cc
			if best.x >= 0:
				break
		if best.x >= 0:
			var gx := best.x * 64 + 32 - pos.x
			cmd["dir"] = signi(int(gx)) if absf(gx) > 20.0 else 0
			if absf(gx) < 150.0:
				cmd["jump"] = true
				cmd["jump_frames"] = 16
			return _safe(r, cmd, lv)
	# alvo: rival mais perto
	var target = null
	var td := 1e9
	for o in main.robots:
		if o != r and o.alive and not o.finished:
			var dd: float = o.position.distance_to(pos)
			if dd < td:
				td = dd
				target = o
	if target == null:
		return cmd
	var dx: float = target.position.x - pos.x
	var dy: float = target.position.y - pos.y
	# 3) atacar de perto
	if absf(dx) < 78.0 and absf(dy) < 50.0:
		if signi(int(dx)) != r.facing and absf(dx) > 4.0:
			cmd["dir"] = signi(int(dx))   # vira para o rival
		if main.rng.randf() < float(lv["hammer_acc"]) and st.get("hammer_cd", 0.0) <= 0.0:
			cmd["hammer"] = true
			st["hammer_cd"] = float(lv["hammer_cooldown_s"])
		return _safe(r, cmd, lv)
	# 4) itens: cada um tem sua hora
	var use_ok: bool = main.rng.randf() < float(lv["use_items"])
	var it_ok := false
	match r.item:
		"gancho", "chave", "cola": it_ok = absf(dy) < 100.0 and absf(dx) > 120.0 and absf(dx) < 480.0
		"furadeira": it_ok = absf(dy) < 60.0 and absf(dx) < 220.0
		"mola_portatil": it_ok = r.is_on_floor() and dy < -200.0 and absf(dx) < 260.0
	if it_ok and use_ok:
		if signi(int(dx)) != r.facing:
			cmd["dir"] = signi(int(dx))
		else:
			cmd["item"] = true
		return cmd
	if r.item == "dinamite" and absf(dy) < 110.0 and absf(dx) > 140.0 and absf(dx) < 430.0 and use_ok:
		if signi(int(dx)) != r.facing:
			cmd["dir"] = signi(int(dx))
		else:
			cmd["item"] = true
		return cmd
	# 5) pegar item se estiver mais perto que o rival
	var goal: Vector2 = target.position
	for it in demo.items:
		if it["vy"] == 0.0 and it["pos"].distance_to(pos) < td * 1.2 and main.rng.randf() < float(lv["use_items"]):
			goal = it["pos"] + Vector2(0, 26)
			break
	# 6) rival logo abaixo: quebra o chão dele (se estiver ao lado) ou cai em cima (pisão)
	var gx := goal.x - pos.x
	if absf(gx) > 20.0:
		cmd["dir"] = signi(int(gx))
	if goal.y < pos.y - 90.0 and r.is_on_floor() and absf(gx) < 260.0:
		cmd["jump"] = true
		cmd["jump_frames"] = 16
	return _safe(r, cmd, lv)

## Segurança: olha à frente o quanto o robô anda até a próxima decisão; não entra em buraco sem chão
## alcançável do outro lado (pula vãos, inclusive de 1 caixote, e paredes).
func _safe(r, cmd: Dictionary, lv: Dictionary, may_distract := true) -> Dictionary:
	var L = main.level
	var dir: int = cmd.get("dir", 0)
	if dir == 0 or not r.is_on_floor():
		return cmd
	var row := int((r.position.y + 2.0) / 64.0)
	var look := 30.0 + float(Data.ctrl["max_run"]) * float(lv["react_s"]) * 1.4
	var k := 6.0
	while k <= look:
		var cx := int(floor((r.position.x + dir * (24.0 + k)) / 64.0))
		if L.is_solid(Vector2i(cx, row - 1)):
			cmd["jump"] = true
			return cmd
		var ok: bool = L.is_solid(Vector2i(cx, row)) and not (L.blocks.has(Vector2i(cx, row)) and L.blocks[Vector2i(cx, row)]["warn"] > 0.0)
		if not ok:
			if absf(r.velocity.x) > 120.0 and signf(r.velocity.x) != float(dir):
				# ainda deslizando para o outro lado: espera virar antes de pular
				cmd.erase("jump")
				return cmd
			if k > 40.0:
				# vão ainda longe: continua andando; para só se não houver onde pousar e já estiver perto de frear
				var land_far := _landing(cx - dir, row, dir)
				if land_far == Vector2i(-1, -1) and k < 90.0:
					cmd["dir"] = 0
					cmd.erase("jump")
				return cmd
			if may_distract and absf(r.velocity.x) > 300.0 and signf(r.velocity.x) == float(dir) and main.rng.randf() > float(lv["safety"]):
				cmd["distracted"] = true
				r.fall_reason = "distraído"
				return cmd   # bot fácil às vezes se distrai
			var land := _landing(cx - dir, row, dir)
			if land == Vector2i(-1, -1):
				cmd["dir"] = 0
				cmd.erase("jump")
			else:
				cmd["jump"] = true
				cmd["jump_frames"] = 16
				cmd["land"] = land
			return cmd
		k += 14.0
	return cmd

## Primeiro chão onde dá para aterrissar à frente (até 4 colunas, de 2 acima a 5 abaixo).
func _landing(col: int, row: int, dir: int) -> Vector2i:
	var L = main.level
	for dc in range(1, 5):
		var c := col + dir * dc
		for r2 in range(maxi(row - 2, 1), mini(row + 6, L.rows - 1)):   # só dentro do mapa (fora conta como sólido)
			if L.is_solid(Vector2i(c, r2)) and not L.is_solid(Vector2i(c, r2 - 1)) and not L.is_solid(Vector2i(c, r2 - 2)):
				if not (L.blocks.has(Vector2i(c, r2)) and L.blocks[Vector2i(c, r2)]["warn"] > 0.0):
					return Vector2i(c, r2)
	return Vector2i(-1, -1)

## Recuperação: pendurado na borda → sobe; caindo sobre o vazio → vai para o chão mais próximo e usa o pulo duplo.
func _recover(r, st: Dictionary, inp: Dictionary, prev: Dictionary, dt: float) -> void:
	if r.hanging:
		st["hang_t"] = st.get("hang_t", 0.0) + dt
		inp.erase("left")
		inp.erase("right")
		inp["right" if r.hang_dir > 0 else "left"] = true
		if st["hang_t"] > 0.25:
			inp["jump"] = not prev.get("jump", false)
		return
	st["hang_t"] = 0.0
	if r.is_on_floor() or r.velocity.y < 60.0 or r.stun_t > 0.0:
		return
	var L = main.level
	var col := int(r.position.x / 64.0)
	var row := int((r.position.y + 2.0) / 64.0)
	for k in range(0, 7):
		if L.is_solid(Vector2i(col, row + k)) and L.ch_at(Vector2i(col, row + k)) != "I":
			return   # tem chão embaixo
	var best := Vector2i(-1, -1)
	var bd := 1e9
	for dc in range(-7, 8):
		for dr in range(-3, 5):
			var c := Vector2i(col + dc, row + dr)
			if L.is_solid(c) and L.ch_at(c) != "I" and not L.is_solid(c + Vector2i.UP):
				var d := absf(dc) * 1.0 + maxf(dr, 0) * 0.3
				if d < bd:
					bd = d
					best = c
	if best.x < 0:
		return
	var gx: float = best.x * 64 + 32 - r.position.x
	inp.erase("left")
	inp.erase("right")
	if absf(gx) > 12.0:
		inp["right" if gx > 0 else "left"] = true
	if r.air_jumps > 0 and best.y <= row + 1:
		inp["jump"] = not prev.get("jump", false)
