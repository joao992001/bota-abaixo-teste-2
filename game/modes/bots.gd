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
	if r.item == "teletransporte" and not r.is_on_floor() and r.velocity.y > 250.0 and pos.y > 64.0 * (L.rows - 5):
		cmd["item"] = true   # caindo no buraco: troca de lugar com alguém
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
	# 1b) itens próprios dos modos (estilingue, choque, laço, barreira, cola na Fuga)
	var mi := _mode_item(r, lv)
	if not mi.is_empty():
		return mi
	# 2) Batata-Dinamite: sem a bomba, foge de quem está com ela; com ela, persegue o mais perto (encostar passa)
	var bomb_on: bool = demo.rule() == "batata" and demo.bomb_holder >= 0 and demo.bomb_holder < main.robots.size()
	var holder = main.robots[demo.bomb_holder] if bomb_on else null
	if holder != null and holder != r and holder.alive and holder.position.distance_to(pos) < 380.0:
		cmd["dir"] = 1 if pos.x >= holder.position.x else -1
		if absf(holder.position.x - pos.x) < 170.0 and r.is_on_floor():
			cmd["jump"] = true
			cmd["jump_frames"] = 16
		return _safe(r, cmd, lv)
	# 2b) Rei da Obra: o rei foge de quem chega perto; os outros vão atrás do rei ou do capacete solto
	if demo.rule() == "rei":
		if demo.king == r.pid:
			var near = null
			var nd := 1e9
			for o in main.robots:
				if o != r and o.alive and o.position.distance_to(pos) < nd:
					nd = o.position.distance_to(pos)
					near = o
			if near != null and nd < 300.0:
				cmd["dir"] = 1 if pos.x >= near.position.x else -1
				if absf(near.position.x - pos.x) < 150.0 and r.is_on_floor():
					cmd["jump"] = true
					cmd["jump_frames"] = 16
				return _safe(r, cmd, lv)
			return cmd
		if demo.king < 0:
			return _climb(r, demo.crown_pos, lv)
		var kr = main.robots[demo.king]
		if kr.position.y < pos.y - 110.0:
			return _climb(r, kr.position, lv)   # o rei está lá em cima: sobe degrau por degrau
	# 2c) Fuga: corre para o elevador; só briga com quem estiver colado
	if demo.rule() == "fuga" and L.elevator_cell != Vector2i(-1, -1):
		var g: Rect2 = L.goal_rect
		var run := _climb(r, Vector2(g.get_center().x, g.end.y), lv)
		for o in main.robots:
			if o != r and o.alive and absf(o.position.x - pos.x) < 78.0 and absf(o.position.y - pos.y) < 50.0 \
					and signi(int(o.position.x - pos.x)) == r.facing and st.get("hammer_cd", 0.0) <= 0.0 \
					and main.rng.randf() < float(lv["hammer_acc"]) * 0.5:
				run["hammer"] = true   # marretada de passagem, sem parar de correr
				st["hammer_cd"] = float(lv["hammer_cooldown_s"]) * 1.5
		return run
	# alvo: rival mais perto (na Batata, ninguém vai atrás de quem está com a bomba; no Rei, todos vão no rei)
	var target = null
	var td := 1e9
	for o in main.robots:
		if o != r and o.alive and not o.finished and not (holder != null and o == holder and r != holder) \
				and (demo.rule() != "rei" or demo.king < 0 or o.pid == demo.king):
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
		"cola", "vortice": it_ok = absf(dy) < 100.0 and absf(dx) > 140.0 and absf(dx) < 480.0
		"laser", "congelador": it_ok = absf(dy) < 40.0 and absf(dx) > 90.0 and absf(dx) < 900.0
		"soprador": it_ok = absf(dy) < 80.0 and absf(dx) < 300.0
		"teletransporte": it_ok = main.rng.randf() < 0.04
		"furadeira": it_ok = absf(dy) < 60.0 and absf(dx) < 220.0
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

## Bots usando os itens de Batata, Rei e Fuga. Vazio = nada a fazer agora.
func _mode_item(r, lv: Dictionary) -> Dictionary:
	var demo = main.demo
	if r.item not in ["estilingue", "choque", "laco", "barreira", "cola", "relogio", "gancho"] or main.rng.randf() > float(lv["use_items"]):
		return {}
	if r.item == "relogio":
		var demo0 = main.demo
		if demo0.bomb_holder >= 0 and (demo0.bomb_holder != r.pid or demo0.bomb_fuse < 4.0):
			return {"dir": 0, "item": true}
		return {}
	if r.item == "gancho":
		return {"dir": 0, "item": true} if r.is_on_floor() else {}
	if r.item == "cola" and demo.rule() != "fuga":
		return {}
	var pos: Vector2 = r.position
	for o in main.robots:
		if o == r or not o.alive or o.finished:
			continue
		var dx: float = o.position.x - pos.x
		var dy: float = o.position.y - pos.y
		var ok := false
		var face := signi(int(dx))
		match r.item:
			"estilingue": ok = r.pid == demo.bomb_holder and absf(dx) > 120.0 and absf(dx) < 560.0 and absf(dy) < 70.0
			"choque": ok = absf(dx) < 220.0 and absf(dy) < 120.0
			"laco": ok = absf(dx) > 90.0 and absf(dx) < 420.0 and absf(dy) < 60.0 and (demo.king < 0 or o.pid == demo.king)
			"barreira":   # alguém vindo atrás: larga o muro entre vocês
				ok = absf(dx) < 360.0 and absf(dy) < 90.0
				face = -signi(int(dx))
			"cola": ok = absf(dx) > 140.0 and absf(dx) < 480.0 and absf(dy) < 90.0
		if ok:
			if face != 0 and face != r.facing and r.item not in ["choque"]:
				return {"dir": face}
			return {"dir": 0, "item": true}
	return {}

## Caminho até o objetivo: distância (em pulos) de cada degrau até o degrau do objetivo, calculada de trás
## para a frente e guardada enquanto o objetivo não muda de célula. Devolve o próximo degrau (ou -1).
var _nav := {"lv": null, "goal": Vector2i(-99, -99), "dist": {}, "t": 0.0}

func _standable(L, c: Vector2i) -> bool:
	var ch: String = L.ch_at(c)
	return (L.is_solid(c) or ch == "=") and ch != "I" and not L.is_solid(c + Vector2i.UP) and not L.is_solid(c + Vector2i(0, -2))

func _reach(L, a: Vector2i, b: Vector2i) -> bool:
	var dx := absi(b.x - a.x)
	var up := a.y - b.y
	var hmax := 6 if L.ch_at(a) == "J" else 3
	if up > hmax or dx > (3 if up > 0 else 5):
		return false
	var sx := signi(b.x - a.x)
	if up > 0:   # sobe na coluna de saída e depois atravessa na altura de chegada
		for y in range(b.y - 2, a.y):
			if L.is_solid(Vector2i(a.x, y)):
				return false
		for x in range(a.x, b.x + sx, sx if sx != 0 else 1):
			if L.is_solid(Vector2i(x, b.y - 1)) or L.is_solid(Vector2i(x, b.y - 2)):
				return false
		return true
	for x in range(a.x, b.x + sx, sx if sx != 0 else 1):   # atravessa na altura de saída e depois cai
		if L.is_solid(Vector2i(x, a.y - 1)):
			return false
	for y in range(a.y - 1, b.y):
		if L.is_solid(Vector2i(b.x, y)):
			return false
	return true

func _goal_cell(L, goal: Vector2) -> Vector2i:
	var gx := int(goal.x / 64.0)
	var gy := int((goal.y + 2.0) / 64.0)
	for k in 4:
		if _standable(L, Vector2i(gx, gy + k)):
			return Vector2i(gx, gy + k)
	return Vector2i(-1, -1)

func _nav_step(from: Vector2i, goal: Vector2) -> Vector2i:
	var L = main.level
	var g := _goal_cell(L, goal)
	if g.x < 0 or not _standable(L, from):
		return Vector2i(-1, -1)
	var now := Time.get_ticks_msec() / 1000.0
	if _nav["lv"] != L or (_nav["goal"] != g and now - float(_nav["t"]) > 0.5):
		var ok := {}
		for y in range(1, L.rows):
			for x in range(1, L.cols - 1):
				if _standable(L, Vector2i(x, y)):
					ok[Vector2i(x, y)] = true
		var dist := {g: 0}
		var queue: Array = [g]
		var qi := 0
		while qi < queue.size():
			var b: Vector2i = queue[qi]
			qi += 1
			for y in range(b.y - 8, b.y + 7):   # quem chega em b: até 6 abaixo (trampolim) ou caindo de até 8 acima
				for x in range(b.x - 5, b.x + 6):
					var a := Vector2i(x, y)
					if ok.has(a) and not dist.has(a) and _reach(L, a, b):
						dist[a] = int(dist[b]) + 1
						queue.append(a)
		_nav = {"lv": L, "goal": g, "dist": dist, "t": now}
	var d: Dictionary = _nav["dist"]
	if not d.has(from) or int(d[from]) == 0:
		return Vector2i(-1, -1)
	var best := Vector2i(-1, -1)
	var bk := 1e9
	for y in range(from.y - 6, from.y + 9):
		for x in range(from.x - 5, from.x + 6):
			var c := Vector2i(x, y)
			if c != from and d.has(c) and _reach(L, from, c):
				var k := float(d[c]) * 100.0 + absi(x - from.x)
				if k < bk:
					bk = k
					best = c
	return best

## Subir até um objetivo no alto: escolhe um degrau (chão com espaço em cima, 1–3 linhas acima e perto)
## que aproxime do objetivo; tábuas dão para atravessar por baixo, blocos sólidos ele pega pela lateral.
func _climb(r, goal: Vector2, lv: Dictionary) -> Dictionary:
	var L = main.level
	var pos: Vector2 = r.position
	var cmd := {"dir": 0}
	var row := int((pos.y + 2.0) / 64.0)
	var col := int(pos.x / 64.0)
	var tx := goal.x
	var nav := _nav_step(Vector2i(col, row), goal)
	if nav.x >= 0 and nav.y >= row:
		# o caminho segue pelo mesmo andar ou desce: anda até lá (cai da beirada se preciso)
		var ndx := nav.x * 64 + 32 - pos.x
		cmd["dir"] = signi(int(ndx)) if absf(ndx) > 12.0 else 0
		var rs := _safe(r, cmd, lv)
		if cmd["dir"] != 0 and rs.get("dir", 0) == 0:
			rs["dir"] = cmd["dir"]   # o próximo degrau do caminho é chão: segue (e cai, se for para baixo)
			if nav.y == row and not _standable(L, Vector2i(col + int(cmd["dir"]), row)) and r.is_on_floor():
				rs["jump"] = true    # vão no mesmo andar: pula
				rs["jump_frames"] = 16
		return rs
	if goal.y < pos.y - 90.0 or nav.x >= 0:
		var best := nav
		var bs := 1e9
		for dy in range(1, 4 if nav.x < 0 else 1):
			var y := row - dy
			for x in range(col - 5, col + 6):
				var c := Vector2i(x, y)
				var standable: bool = (L.is_solid(c) or L.ch_at(c) == "=") and L.ch_at(c) != "I" \
					and not L.is_solid(c + Vector2i.UP) and not L.is_solid(c + Vector2i(0, -2))
				if not standable:
					continue
				var sc := Vector2(x * 64 + 32, y * 64).distance_to(goal) + absf(x - col) * 24.0
				if sc < bs:
					bs = sc
					best = c
		if best.x >= 0:
			tx = best.x * 64 + 32
			var dx := tx - pos.x
			var solid_step: bool = L.is_solid(best)
			if solid_step and absf(dx) < 50.0:
				cmd["dir"] = -1 if dx >= 0.0 else 1   # embaixo de um bloco: sai para o lado antes de pular
				return _safe(r, cmd, lv)
			cmd["dir"] = signi(int(dx)) if absf(dx) > 12.0 else 0
			if r.is_on_floor() and absf(dx) < (140.0 if solid_step else 110.0):
				cmd["jump"] = true
				cmd["jump_frames"] = 18
			var want: int = cmd["dir"]
			var res := _safe(r, cmd, lv)
			if want != 0 and res.get("dir", 0) == 0 and r.is_on_floor() and absf(dx) < 300.0:
				# a segurança parou na beirada, mas o degrau está em cima e perto: pula para ele
				res["dir"] = want
				res["jump"] = true
				res["jump_frames"] = 18
			return res
	var gx := tx - pos.x
	if absf(gx) > 16.0:
		cmd["dir"] = signi(int(gx))
	if goal.y < pos.y - 70.0 and r.is_on_floor() and absf(gx) < 120.0:
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
