extends Node2D
## Ferramentas (itens de usar) da Demolição, com animação própria. Números em data/modos.json → demolicao.itens.
##   gancho      dispara um gancho com corda: prende no caixote e PUXA VOCÊ até lá; se pegar um rival, puxa ele.
##               ▲ segurado mira para cima.
##   furadeira   investida: avança furando caixotes e empurrando quem estiver na frente.
##   tábua       tábua de emergência embaixo dos pés (pregada na hora).
##   cola        bola de cola em arco; vira poça que deixa lento (e gruda em quem acertar).
##   chave       chave-bumerangue: vai girando, freia e volta para a mão.
##   mola        mola portátil: arremessada à frente, abre no chão e lança quem pisar.
##   ímã         (efeito com tempo) puxa os rivais por perto.
## Este nó fica no mundo, acima dos robôs; também desenha partículas (lascas, gotas, estrelas) e o "pop" de pegar item.

const T := 64
var main: Node
var demo: Node
var hooks: Array = []        # {owner, pos, dir, state, t, len, target}
var wrenches: Array = []     # {pos, vel, owner, t, hit, trail}
var glue_shots: Array = []   # {pos, vel, owner, trail}
var puddles: Array = []      # {rect, t, life}
var springs: Array = []      # {pos, vel, state, t, cd, squash, owner}
var drills: Array = []       # {owner, t, hit}
var planks: Array = []       # tábuas recém-pregadas: {cells, t}
var parts: Array = []        # partículas: {pos, vel, t, life, kind, col, size, rot, spin}
var pops: Array = []         # pegou item: {pos, kind, t, col}

func setup(m: Node, d: Node) -> void:
	main = m
	demo = d

func clear() -> void:
	for h in hooks:
		_end_zip(h)
	hooks.clear()
	wrenches.clear()
	glue_shots.clear()
	puddles.clear()
	springs.clear()
	drills.clear()
	planks.clear()
	parts.clear()
	pops.clear()

func cfgi(kind: String) -> Dictionary:
	return demo.item_cfg(kind)

# ---------------------------------------------------------------- usar
func use(r, kind: String) -> bool:
	var c: Vector2 = r.rect().get_center()
	var ci := cfgi(kind)
	match kind:
		"gancho":
			var aim := Vector2(r.facing, -0.42)
			if PlayerInput.held(r.pid, "up"):
				aim = Vector2(r.facing * 0.55, -1.0)
			elif PlayerInput.held(r.pid, "down"):
				aim = Vector2(r.facing, 0.0)
			hooks.append({"owner": r.pid, "pos": c + Vector2(r.facing * 18, -10), "dir": aim.normalized(), "state": "vai",
				"t": 0.0, "len": 0.0, "target": -1})
			Audio.play("gancho")
			r.vis.stretch()
		"furadeira":
			drills.append({"owner": r.pid, "t": 0.0, "hit": []})
			r.forced_t = float(ci["dash_s"])
			r.forced_vel = Vector2(r.facing * float(ci["vel"]), 0)
			r.var_jump = 0.0
			Audio.play("furadeira")
			main.shake(4.0)
		"tabua":
			var lv = main.level
			var row := int(r.position.y / 64.0) + (0 if r.is_on_floor() else 1)
			if r.is_on_floor():
				row = int((r.position.y + 2.0) / 64.0)   # no chão: prega à frente, na altura do chão
			var col := int(r.position.x / 64.0)
			var w := int(ci["largura"])
			var made: Array = []
			var cols: Array = []
			if r.is_on_floor():
				for k in range(1, w + 1):
					cols.append(col + r.facing * k)
			else:
				for dc in range(-(w / 2), w - w / 2):
					cols.append(col + dc)
			for cc in cols:
				var cell := Vector2i(cc, row)
				if lv.add_block(cell):
					made.append(cell)
			if made.is_empty():
				return false   # não coube: devolve o item
			planks.append({"cells": made, "t": 0.0})
			Audio.play("caixote_pancada", 1.2)
			for cell in made:
				main.dust(Vector2(cell.x * 64 + 32, cell.y * 64), 0.7)
		"cola":
			var th: Array = ci["throw"]
			glue_shots.append({"pos": c + Vector2(r.facing * 20, -16), "vel": Vector2(r.facing * float(th[0]) + r.velocity.x * 0.3, -float(th[1])),
				"owner": r.pid, "trail": []})
			Audio.play("arremesso", 0.9)
			r.vis.stretch()
		"chave":
			wrenches.append({"pos": c + Vector2(r.facing * 20, -6), "vel": Vector2(r.facing * float(ci["vel"]), 0), "owner": r.pid,
				"t": 0.0, "hit": [], "trail": []})
			Audio.play("chave")
			r.vis.stretch()
		"mola_portatil":
			springs.append({"pos": c + Vector2(r.facing * 16, -10), "vel": Vector2(r.facing * 330.0 + r.velocity.x * 0.3, -420.0),
				"state": "voa", "t": float(ci["duration_s"]), "cd": 0.0, "squash": 0.0, "owner": r.pid, "rot": 0.0})
			Audio.play("arremesso", 1.1)
	return true

## Pegou item: estouro de estrelas e o ícone cresce em cima do robô.
func pickup_fx(r, kind: String) -> void:
	var c: Vector2 = r.rect().get_center()
	pops.append({"pos": c + Vector2(0, -95), "kind": kind, "t": 0.0, "col": main.player_color(r.pid)})
	for k in 12:
		var a := k * TAU / 12.0
		_part(c, Vector2.from_angle(a) * randf_range(260, 420), 0.5, "estrela", Color("#fff4c8"), randf_range(5, 9))

# ---------------------------------------------------------------- atualizar
func update(dt: float, alive: Array) -> void:
	var lv = main.level
	_update_hooks(dt, alive)
	_update_drills(dt, alive)
	for p in planks:
		p["t"] += dt
	planks = planks.filter(func(p): return p["t"] < 0.6)
	# ímã: puxa os rivais por perto
	for r in alive:
		if r.fx_t["ima"] > 0.0:
			var ic := cfgi("ima")
			for o in alive:
				if o != r:
					var d: Vector2 = r.position - o.position
					if d.length() < float(ic["raio_px"]) and d.length() > 40.0:
						o.push_vx += signf(d.x) * float(ic["forca"]) * 0.16
						o.last_attacker = r.pid
						o.last_hit = minf(o.last_hit, 1.0)
						if Engine.get_physics_frames() % 6 == 0:
							_part(o.rect().get_center(), (r.rect().get_center() - o.rect().get_center()).normalized() * 380.0, 0.35, "faisca", Color("#ff6b7a"), 4.0)
	# cola voando
	for g in glue_shots:
		g["vel"].y += 1700.0 * dt
		g["pos"] += g["vel"] * dt
		g["trail"].push_front(g["pos"])
		if g["trail"].size() > 6:
			g["trail"].pop_back()
		var cell := Vector2i(int(floor(g["pos"].x / 64.0)), int(floor(g["pos"].y / 64.0)))
		var hit_r = null
		for o in alive:
			if o.pid != g["owner"] and o.rect().grow(8).has_point(g["pos"]):
				hit_r = o
		if (g["pos"].y > 0.0 and lv.is_solid(cell)) or hit_r != null:
			g["dead"] = true
			var row: int = cell.y if hit_r == null else int((hit_r.position.y + 2.0) / 64.0)
			var y := row
			while y < lv.rows and not lv.is_solid(Vector2i(cell.x, y)):
				y += 1
			var w := float(cfgi("cola")["largura"]) * 64.0
			var life := float(cfgi("cola")["duration_s"])
			puddles.append({"rect": Rect2(cell.x * 64 + 32 - w / 2.0, y * 64 - 14, w, 18), "t": life, "life": life, "grow": 0.0})
			Audio.play("cola")
			for k in 10:
				_part(g["pos"], Vector2(randf_range(-300, 300), randf_range(-420, -120)), 0.6, "gota", Color("#f5f3ea"), randf_range(5, 9))
			if hit_r != null:
				hit_r.glue_t = 2.0
				main.float_text(hit_r.position + Vector2(0, -110), "GRUDOU!", Color.WHITE)
	glue_shots = glue_shots.filter(func(g): return not g.get("dead", false) and g["pos"].y < lv.rows * 64.0 + 100.0)
	for p in puddles:
		p["t"] -= dt
		p["grow"] = minf(p["grow"] + dt * 6.0, 1.0)
		for o in alive:
			if o.rect().intersects(p["rect"]):
				if o.glue_t <= 0.0:
					Audio.play("cola", 1.3, -8.0)
				o.glue_t = 0.25
	puddles = puddles.filter(func(p): return p["t"] > 0.0)
	# chave-bumerangue
	for w in wrenches:
		w["t"] += dt
		var owner = main.robots[w["owner"]] if w["owner"] < main.robots.size() else null
		var back: bool = w["t"] > float(cfgi("chave")["volta_s"])
		if back and owner != null and owner.alive:
			var to: Vector2 = owner.rect().get_center() - w["pos"]
			w["vel"] = w["vel"].lerp(to.normalized() * float(cfgi("chave")["vel"]) * 1.15, 1.0 - exp(-dt * 6.0))
			if to.length() < 44.0:
				w["dead"] = true
				Audio.play("item", 1.4, -8.0)
		elif not back:
			w["vel"] *= 1.0 - dt * 1.6   # freia antes de voltar
		w["pos"] += w["vel"] * dt
		w["trail"].push_front(w["pos"])
		if w["trail"].size() > 5:
			w["trail"].pop_back()
		if Engine.get_physics_frames() % 10 == 0:
			Audio.play("chave", 1.2, -12.0)
		for o in alive:
			if o.pid != w["owner"] and not (o.pid in w["hit"]) and o.rect().grow(12).has_point(w["pos"]):
				w["hit"].append(o.pid)
				o.take_hit(1 if w["vel"].x >= 0.0 else -1, "marretada", w["owner"])
				Audio.play("bonk", 1.3)
				main.spark(w["pos"], 6)
				main.shake(4.0)
		if w["t"] > 2.6:
			w["dead"] = true
	wrenches = wrenches.filter(func(w): return not w.get("dead", false))
	# mola portátil: voa, abre no chão, lança quem pisa
	for sp in springs:
		sp["cd"] = maxf(sp["cd"] - dt, 0.0)
		sp["squash"] = maxf(sp["squash"] - dt * 3.5, 0.0)
		if sp["state"] == "voa":
			sp["vel"].y += 1700.0 * dt
			sp["rot"] += dt * 10.0 * signf(sp["vel"].x)
			var np: Vector2 = sp["pos"] + sp["vel"] * dt
			var below := Vector2i(int(floor(np.x / 64.0)), int(floor(np.y / 64.0)))
			var side := Vector2i(int(floor((np.x + signf(sp["vel"].x) * 14.0) / 64.0)), int(floor((np.y - 12.0) / 64.0)))
			if np.y > 0.0 and lv.is_solid(side):
				sp["vel"].x = -sp["vel"].x * 0.4
				np.x = sp["pos"].x
			if np.y > 0.0 and lv.is_solid(below) and sp["vel"].y > 0.0:
				np.y = below.y * 64.0
				sp["state"] = "chao"
				sp["squash"] = 1.0
				sp["rot"] = 0.0
				Audio.play("pulo_mola", 1.2)
				main.dust(np, 0.7)
			sp["pos"] = np
			if np.y > lv.rows * 64.0 + 80.0:
				sp["t"] = 0.0
			continue
		sp["t"] -= dt
		# o caixote embaixo quebrou: cai de novo
		if not lv.is_solid(Vector2i(int(floor(sp["pos"].x / 64.0)), int(floor((sp["pos"].y + 4.0) / 64.0)))):
			sp["state"] = "voa"
			sp["vel"] = Vector2.ZERO
			continue
		for o in alive:
			if sp["cd"] <= 0.0 and o.velocity.y >= 0.0 and absf(o.position.x - sp["pos"].x) < 34.0 and absf(o.position.y - sp["pos"].y) < 16.0:
				o.velocity.y = -float(cfgi("mola_portatil")["impulso"])
				o.var_jump = 0.0
				o.spring = true
				o.air_jumps = 1
				o.vis.stretch()
				sp["cd"] = 0.25
				sp["squash"] = 1.0
				Audio.play("pulo_mola", 0.9)
				main.float_text(sp["pos"] + Vector2(0, -60), "BOING!", Color("#5cc45c"))
				for k in 6:
					_part(sp["pos"], Vector2(randf_range(-200, 200), randf_range(-260, -80)), 0.4, "estrela", Color("#c8ffb0"), 6.0)
	springs = springs.filter(func(sp): return sp["t"] > 0.0)
	# partículas e pops
	for p in parts:
		p["t"] += dt
		p["vel"].y += (900.0 if p["kind"] in ["lasca", "gota"] else 0.0) * dt
		p["vel"] *= 1.0 - dt * (1.5 if p["kind"] in ["estrela", "faisca", "fumaca"] else 0.2)
		p["pos"] += p["vel"] * dt
		p["rot"] += p["spin"] * dt
	parts = parts.filter(func(p): return p["t"] < p["life"])
	for p in pops:
		p["t"] += dt
	pops = pops.filter(func(p): return p["t"] < 0.75)
	queue_redraw()

## Gancho: vai em linha reta; prende no caixote (puxa o dono) ou no rival (puxa o rival); senão volta.
func _update_hooks(dt: float, alive: Array) -> void:
	var lv = main.level
	var gc := cfgi("gancho")
	for h in hooks:
		h["t"] += dt
		var owner = main.robots[h["owner"]] if h["owner"] < main.robots.size() else null
		if owner == null or not owner.alive:
			if owner != null:
				_end_zip(h)
			h["dead"] = true
			continue
		var hand: Vector2 = owner.rect().get_center() + Vector2(owner.facing * 14, -10)
		match h["state"]:
			"vai":
				var step := float(gc["vel"]) * dt
				for _s in 4:
					h["pos"] += h["dir"] * step / 4.0
					h["len"] += step / 4.0
					for o in alive:
						if o != owner and o.rect().grow(6).has_point(h["pos"]):
							h["state"] = "rival"
							h["target"] = o.pid
							h["t"] = 0.0
							if o.invuln <= 0.0 and not o.absorb():
								o.last_hit = 0.0
								o.last_cause = "gancho"
								o.last_attacker = owner.pid
								o.hanging = false
								o.stun_t = maxf(o.stun_t, 0.5)
								Audio.voice("voz_ai", o.vis.model)
								main.float_text(o.position + Vector2(0, -110), "FISGADO!", main.player_color(owner.pid))
							Audio.play("bonk", 1.5)
							break
					if h["state"] != "vai":
						break
					var cell := Vector2i(int(floor(h["pos"].x / 64.0)), int(floor(h["pos"].y / 64.0)))
					if h["pos"].y > 0.0 and lv.is_solid(cell) and lv.ch_at(cell) != "I":
						h["state"] = "preso"
						h["t"] = 0.0
						h["cell"] = cell
						Audio.play("alavanca", 1.4)
						main.spark(h["pos"], 5)
						owner.hanging = false
						# com espaço em cima: leva o robô até em cima do caixote (atravessa o caminho)
						if not lv.is_solid(cell + Vector2i.UP) and not lv.is_solid(cell + Vector2i(0, -2)) and cell.y >= 2:
							h["feet"] = Vector2(cell.x * 64.0 + 32.0, cell.y * 64.0 - 1.0)
							h["mask"] = owner.collision_mask
							owner.collision_mask = 0
						break
				if h["state"] == "vai" and h["len"] >= float(gc["alcance_px"]):
					h["state"] = "volta"
			"preso":
				# puxa o dono até o ponto (zíper); PULAR solta com impulso
				var to: Vector2 = h["pos"] - owner.rect().get_center()
				var near := 44.0
				if h.has("feet"):
					to = h["feet"] - owner.position
					near = 18.0
					if not lv.is_solid(h["cell"]):
						h.erase("feet")   # o caixote quebrou no caminho
						_end_zip(h)
						h["state"] = "volta"
						continue
				var done: bool = to.length() < near or h["t"] > 0.9 or (h["t"] > 0.12 and not h.has("feet") and owner.get_real_velocity().length() < 60.0)
				if PlayerInput.pressed(owner.pid, "jump") and h["t"] > 0.05:
					done = true
				if done:
					var landed_top: bool = h.has("feet") and to.length() < near
					if landed_top:
						owner.position = h["feet"]
					_end_zip(h)
					owner.velocity.y = -260.0 if landed_top else -620.0
					owner.own_vx = owner.facing * (120.0 if landed_top else 260.0)
					owner.air_jumps = 1
					if landed_top:
						main.dust(owner.position, 0.8)
						owner.vis.land()
					h["state"] = "volta"
				else:
					owner.forced_t = 0.05
					owner.forced_vel = to.normalized() * float(gc["puxa_vel"])
					owner.facing = 1 if to.x >= 0.0 else -1
			"rival":
				var o = main.robots[h["target"]]
				if not o.alive or h["t"] > 0.35:
					h["state"] = "volta"
				else:
					var d: Vector2 = hand - o.rect().get_center()
					if d.length() > 70.0:
						o.forced_t = 0.05
						o.forced_vel = d.normalized() * float(gc["puxa"])
					else:
						h["state"] = "volta"
					h["pos"] = o.rect().get_center()
			"volta":
				var back: Vector2 = hand - h["pos"]
				if back.length() < 40.0:
					h["dead"] = true
				else:
					h["pos"] += back.normalized() * minf(float(gc["vel"]) * 1.2 * dt, back.length())
		h["hand"] = hand
	hooks = hooks.filter(func(h): return not h.get("dead", false))

func _end_zip(h: Dictionary) -> void:
	if h.get("owner", -1) < main.robots.size():
		var o = main.robots[h["owner"]]
		o.forced_t = 0.0
		if h.has("mask"):
			o.collision_mask = h["mask"]   # volta a colidir
			h.erase("mask")

## Furadeira: enquanto a investida dura, fura caixotes à frente e empurra quem estiver no caminho.
func _update_drills(dt: float, alive: Array) -> void:
	var lv = main.level
	for d in drills:
		d["t"] += dt
		var r = main.robots[d["owner"]]
		if not r.alive or r.forced_t <= 0.0:
			d["dead"] = true
			if r.alive:
				r.own_vx = r.facing * 240.0
			continue
		var tip: float = r.position.x + r.facing * 46.0
		demo.break_by = r.pid
		demo.break_reason = "furadeira"
		for yy in [r.position.y - 64.0, r.position.y - 36.0, r.position.y - 8.0]:
			var cell := Vector2i(int(floor(tip / 64.0)), int(floor(yy / 64.0)))
			if lv.blocks.has(cell):
				lv.break_block(cell)
				for k in 6:
					_part(Vector2(cell * 64) + Vector2(32, 32), Vector2(-r.facing * randf_range(80, 320), randf_range(-380, -60)), 0.7, "lasca", Color("#c8995f"), randf_range(5, 10))
		demo.break_reason = ""
		demo.break_by = -1
		var zone := Rect2(tip - 26.0 + r.facing * 6.0, r.position.y - 72.0, 52.0, 72.0)
		for o in alive:
			if o != r and not (o.pid in d["hit"]) and zone.intersects(o.rect()):
				d["hit"].append(o.pid)
				o.take_hit(r.facing, "furadeira", r.pid)
				main.spark(o.rect().get_center(), 10)
				main.shake(7.0)
		if Engine.get_physics_frames() % 2 == 0:
			_part(Vector2(tip, r.position.y - 36.0), Vector2(-r.facing * randf_range(100, 300), randf_range(-200, 100)), 0.35, "faisca", Color("#fff4c8"), 4.0)
		main.shake(1.5)
	drills = drills.filter(func(d): return not d.get("dead", false))

func _part(pos: Vector2, vel: Vector2, life: float, kind: String, col: Color, size: float) -> void:
	if parts.size() > 260:
		return
	parts.append({"pos": pos, "vel": vel, "t": 0.0, "life": life, "kind": kind, "col": col, "size": size,
		"rot": randf() * TAU, "spin": randf_range(-14, 14)})

## O robô está furando agora? (o desenho mostra a furadeira à frente)
func drilling(pid: int) -> bool:
	for d in drills:
		if d["owner"] == pid:
			return true
	return false

# ---------------------------------------------------------------- desenho
func _draw() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	# poças de cola: gosma brilhante com bolhas e pingos
	for p in puddles:
		var r: Rect2 = p["rect"]
		var a := clampf(p["t"] / 0.6, 0.0, 1.0)
		var w: float = r.size.x * (0.4 + 0.6 * p["grow"])
		var cx := r.get_center().x
		var y := r.position.y + 10.0
		var pts := PackedVector2Array()
		for k in 17:
			var u := k / 16.0
			var x := cx - w / 2.0 + w * u
			pts.append(Vector2(x, y - 6.0 - sin(u * PI) * 6.0 - sin(now * 3.0 + k) * 1.5))
		pts.append(Vector2(cx + w / 2.0, y + 6.0))
		pts.append(Vector2(cx - w / 2.0, y + 6.0))
		draw_colored_polygon(pts, Color(0.97, 0.96, 0.9, a))
		draw_line(Vector2(cx - w * 0.3, y - 9.0), Vector2(cx + w * 0.1, y - 11.0), Color(1, 1, 1, a), 3.0, true)
		for k in 3:
			var bx := cx - w * 0.3 + k * w * 0.3
			var bub := fposmod(now * 0.8 + k * 0.37, 1.0)
			draw_arc(Vector2(bx, y - 6.0 - bub * 6.0), 3.0 + bub * 3.0, 0, TAU, 12, Color(0.85, 0.84, 0.78, a * (1.0 - bub)), 1.5, true)
			draw_rect(Rect2(bx - 2.0, y + 6.0, 4.0, 4.0 + 5.0 * fposmod(now + k * 0.5, 1.0)), Color(0.97, 0.96, 0.9, a))
	# tábuas pregadas: brilho e "pop"
	for p in planks:
		var k: float = p["t"] / 0.6
		for cell in p["cells"]:
			var cr := Rect2(Vector2(cell * 64), Vector2(64, 64)).grow(10.0 * (1.0 - k))
			draw_rect(cr, Color(1, 1, 1, 0.6 * (1.0 - k)), false, 4.0)
			if k < 0.3:
				draw_circle(Vector2(cell * 64) + Vector2(12, 12), 6, Color("#fff4c8"))
				draw_circle(Vector2(cell * 64) + Vector2(52, 12), 6, Color("#fff4c8"))
	# molas portáteis
	for sp in springs:
		if sp["state"] == "chao" and sp["t"] < 2.0 and fmod(now, 0.3) < 0.12:
			continue
		var sq: float = 1.0 - 0.5 * sp["squash"] if sp["cd"] <= 0.0 else 1.0 + 0.6 * sp["squash"]
		var p: Vector2 = sp["pos"]
		if sp["state"] == "voa":
			draw_set_transform(p, sp["rot"], Vector2(0.8, 0.8))
			draw_texture_rect(Data.tex("itens/mola_portatil"), Rect2(-24, -24, 48, 48), false)
		else:
			draw_set_transform(p, 0.0, Vector2(1.0 + 0.25 * sp["squash"], sq))
			draw_texture_rect(Data.tex("itens/mola_portatil"), Rect2(-30, -60, 60, 60), false)
		draw_set_transform(Vector2.ZERO)
	# cola voando (com rastro de pingos)
	for g in glue_shots:
		var tr: Array = g["trail"]
		for i in tr.size():
			draw_circle(tr[i], 9.0 - i * 1.2, Color(0.97, 0.96, 0.9, 0.7 - i * 0.1))
		draw_circle(g["pos"], 11, Color("#f5f3ea"))
		draw_circle(g["pos"] + Vector2(-3, -4), 4, Color.WHITE)
	# chave-bumerangue girando, com fantasmas
	for w in wrenches:
		var tr: Array = w["trail"]
		for i in range(tr.size() - 1, 0, -1):
			draw_set_transform(tr[i], (w["t"] - i * 0.016) * 22.0)
			draw_texture_rect(Data.tex("itens/chave"), Rect2(-22, -22, 44, 44), false, Color(1, 1, 1, 0.35 - i * 0.06))
		draw_set_transform(w["pos"], w["t"] * 22.0)
		draw_texture_rect(Data.tex("itens/chave"), Rect2(-24, -24, 48, 48), false)
		draw_set_transform(Vector2.ZERO)
		draw_arc(w["pos"], 30, w["t"] * 22.0, w["t"] * 22.0 + 2.0, 10, Color(1, 1, 1, 0.6), 3.0, true)
	# gancho: corda ondulada + cabeça de gancho
	for h in hooks:
		var a: Vector2 = h.get("hand", h["pos"])
		var b: Vector2 = h["pos"]
		var n := 14
		var slack := 10.0 if h["state"] == "vai" else (2.0 if h["state"] in ["preso", "rival"] else 6.0)
		var pts := PackedVector2Array()
		var perp := (b - a).orthogonal().normalized()
		for i in n + 1:
			var u := float(i) / n
			pts.append(a.lerp(b, u) + perp * sin(u * PI * 3.0 + now * 30.0) * slack * sin(u * PI))
		draw_polyline(pts, Color("#8a6a47"), 5.0, true)
		draw_polyline(pts, Color("#c9a26a"), 2.5, true)
		var ang: float = (b - a).angle()
		draw_set_transform(b, ang + PI / 4.0)
		draw_texture_rect(Data.tex("itens/gancho"), Rect2(-20, -20, 40, 40), false)
		draw_set_transform(Vector2.ZERO)
		if h["state"] == "preso":
			draw_arc(b, 16.0 + 6.0 * sin(now * 20.0), 0, TAU, 16, Color("#fff4c8"), 3.0, true)
	# furadeira em ação: broca girando à frente do robô
	for d in drills:
		var r = main.robots[d["owner"]]
		var tip: Vector2 = r.position + Vector2(r.facing * 44.0, -40.0)
		draw_set_transform(tip, 0.0, Vector2(r.facing, 1.0) * 1.3)
		draw_texture_rect(Data.tex("itens/furadeira"), Rect2(-34, -22, 52, 48), false)
		var spin := now * 60.0
		var cone := PackedVector2Array([Vector2(18, -10), Vector2(52, 0), Vector2(18, 10)])
		draw_colored_polygon(cone, Color("#c9d1d8"))
		for k in 4:
			var u := fposmod(spin * 0.1 + k * 0.25, 1.0)
			var x := lerpf(18.0, 50.0, u)
			var hh := lerpf(10.0, 1.0, u)
			draw_line(Vector2(x, -hh), Vector2(x + 6.0, hh), Color("#6a7682"), 2.0, true)
		draw_set_transform(Vector2.ZERO)
		for k in 3:   # linhas de velocidade
			var yy: float = r.position.y - 60.0 + k * 22.0
			draw_line(Vector2(r.position.x - r.facing * 40.0, yy), Vector2(r.position.x - r.facing * (80.0 + k * 20.0), yy), Color(1, 1, 1, 0.6), 3.0, true)
	# partículas
	for p in parts:
		var a: float = 1.0 - p["t"] / p["life"]
		var c: Color = p["col"]
		c.a = a
		var pos: Vector2 = p["pos"]
		var s: float = p["size"]
		match p["kind"]:
			"lasca":
				draw_set_transform(pos, p["rot"])
				draw_rect(Rect2(-s / 2.0, -s / 4.0, s, s / 2.0), c)
				draw_set_transform(Vector2.ZERO)
			"gota":
				draw_circle(pos, s * 0.6, c)
			"estrela":
				draw_set_transform(pos, p["rot"], Vector2(a, a))
				var star := PackedVector2Array()
				for k in 10:
					star.append(Vector2.from_angle(k * TAU / 10.0 - PI / 2.0) * (s if k % 2 == 0 else s * 0.45))
				draw_colored_polygon(star, c)
				draw_set_transform(Vector2.ZERO)
			_:
				draw_line(pos, pos - p["vel"] * 0.03, c, s * 0.6, true)
	# pegou item: ícone cresce, gira um pouco e some, com anel
	for p in pops:
		var k: float = p["t"] / 0.75
		var sc := 0.6 + 0.5 * sin(minf(k * 3.0, 1.0) * PI * 0.5) - 0.3 * k
		var pos: Vector2 = p["pos"] + Vector2(0, -50.0 * k)
		draw_arc(p["pos"], 20.0 + 90.0 * k, 0, TAU, 32, Color(1, 1, 1, 0.8 * (1.0 - k)), 6.0 * (1.0 - k) + 1.0, true)
		draw_set_transform(pos, sin(k * 12.0) * 0.2 * (1.0 - k), Vector2(sc, sc))
		draw_texture_rect(Data.tex("itens/" + String(p["kind"])), Rect2(-28, -28, 56, 56), false, Color(1, 1, 1, clampf((1.0 - k) * 2.0, 0.0, 1.0)))
		draw_set_transform(Vector2.ZERO)
