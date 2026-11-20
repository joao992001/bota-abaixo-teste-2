extends Node2D
## Itens de usar (botão ITEM) da Demolição, com animação própria. Números em data/modos.json → demolicao.itens.
##   furadeira       investida: avança furando caixotes e empurrando quem estiver na frente.
##   cola            bola de cola em arco; vira poça que deixa lento (e gruda em quem acertar).
##   teletransporte  troca de lugar com o rival mais perto (manda ele para o seu perigo).
##   laser           carrega mostrando a mira e dispara um raio na linha toda: fura caixotes e arremessa.
##   vortice         bomba arremessada que vira um buraco negro: suga todo mundo e explode.
##   soprador        cone de vento à frente que empurra os rivais por alguns segundos.
##   congelador      tiro de gelo: o rival congela (indefeso, desliza); a próxima pancada estilhaça com empurrão extra.
##   ímã             (efeito com tempo) puxa os rivais por perto.
## Este nó fica no mundo, acima dos robôs: desenha os efeitos, partículas e o "pop" de pegar item.

const T := 64
var main: Node
var demo: Node
var glue_shots: Array = []   # {pos, vel, owner, trail}
var puddles: Array = []      # {rect, t, life, grow}
var drills: Array = []       # {owner, t, hit}
var teles: Array = []        # {a, b, t}
var lasers: Array = []       # {owner, t, dir, y, x0, x1, fired, hit}
var vortex_shots: Array = [] # {pos, vel, owner, rot}
var vortexes: Array = []     # {pos, t, owner}
var blowers: Array = []      # {owner, t}
var ice_shots: Array = []    # {pos, vel, owner, trail}
var parts: Array = []        # partículas: {pos, vel, t, life, kind, col, size, rot, spin}
var pops: Array = []         # pegou item: {pos, kind, t}
var anims := {}              # pid -> {kind, t, dur, fire}: o robô segura/arremessa o item (pose no desenho)
const HELD_TOOLS := ["furadeira", "laser", "soprador", "congelador"]

func setup(m: Node, d: Node) -> void:
	main = m
	demo = d

func clear() -> void:
	for arr in [glue_shots, puddles, drills, teles, lasers, vortex_shots, vortexes, blowers, ice_shots, parts, pops]:
		arr.clear()
	anims.clear()

## Pose de uso: {kind, k (0..1), fire (s desde o disparo, -1 antes)} ou {} se não está usando nada.
func using(pid: int) -> Dictionary:
	if not anims.has(pid):
		return {}
	var a: Dictionary = anims[pid]
	return {"kind": a["kind"], "k": clampf(a["t"] / a["dur"], 0.0, 1.0), "fire": a["t"] - a["fire"] if a["fire"] >= 0.0 else -1.0}

func _anim(pid: int, kind: String, dur: float, fire := -1.0) -> void:
	anims[pid] = {"kind": kind, "t": 0.0, "dur": dur, "fire": fire}

## Bico da ferramenta na mão (mundo): de onde sai o raio, o vento e o tiro de gelo.
func muzzle(r) -> Vector2:
	return r.position + Vector2(r.facing * 54.0, -44.0)

func cfgi(kind: String) -> Dictionary:
	return demo.item_cfg(kind)

func _robot(pid: int):
	return main.robots[pid] if pid >= 0 and pid < main.robots.size() else null

# ---------------------------------------------------------------- usar
func use(r, kind: String) -> bool:
	var c: Vector2 = r.rect().get_center()
	var ci := cfgi(kind)
	match kind:
		"furadeira":
			_anim(r.pid, kind, float(ci["dash_s"]) + 0.1, 0.0)
			drills.append({"owner": r.pid, "t": 0.0, "hit": []})
			r.forced_t = float(ci["dash_s"])
			r.forced_vel = Vector2(r.facing * float(ci["vel"]), 0)
			r.var_jump = 0.0
			Audio.play("furadeira")
			main.shake(4.0)
		"cola":
			var th: Array = ci["throw"]
			_anim(r.pid, "arremesso", 0.28)
			glue_shots.append({"pos": c + Vector2(r.facing * 20, -16), "vel": Vector2(r.facing * float(th[0]) + r.velocity.x * 0.3, -float(th[1])),
				"owner": r.pid, "trail": []})
			Audio.play("arremesso", 0.9)
			r.vis.stretch()
		"teletransporte":
			var best = null
			var bd := 1e9
			for o in main.robots:
				if o != r and o.alive and not o.finished:
					var d: float = o.position.distance_to(r.position)
					if d < bd:
						bd = d
						best = o
			if best == null:
				return false
			teles.append({"a": r.pid, "b": best.pid, "t": 0.0})
			_anim(r.pid, "aponta", float(ci["demora_s"]) + 0.1)
			for rr in [r, best]:
				rr.forced_t = float(ci["demora_s"])
				rr.forced_vel = Vector2.ZERO
				rr.hanging = false
			Audio.play("teleporte")
		"laser":
			lasers.append({"owner": r.pid, "t": 0.0, "dir": r.facing, "fired": false, "hit": []})
			_anim(r.pid, kind, float(ci["carga_s"]) + float(ci["raio_s"]) + 0.15, float(ci["carga_s"]))
			r.forced_t = float(ci["carga_s"]) + float(ci["raio_s"])
			r.forced_vel = Vector2.ZERO
			Audio.play("laser_carga")
		"vortice":
			var th: Array = ci["throw"]
			_anim(r.pid, "arremesso", 0.28)
			vortex_shots.append({"pos": c + Vector2(r.facing * 20, -20), "vel": Vector2(r.facing * float(th[0]) + r.velocity.x * 0.3, -float(th[1])),
				"owner": r.pid, "rot": 0.0})
			Audio.play("arremesso", 0.8)
			r.vis.stretch()
		"soprador":
			blowers = blowers.filter(func(b): return b["owner"] != r.pid)
			blowers.append({"owner": r.pid, "t": 0.0})
			_anim(r.pid, kind, float(ci["duracao_s"]), 0.0)
			Audio.play("soprador")
		"congelador":
			_anim(r.pid, kind, 0.45, 0.12)
			ice_shots.append({"pos": muzzle(r), "vel": Vector2(r.facing * float(ci["vel"]), 0), "owner": r.pid, "trail": [], "wait": 0.12})
			Audio.play("gelo", 1.3)
			r.own_vx = -r.facing * 160.0
	return true

## Pegou item: estouro de estrelas e o ícone cresce em cima do robô.
func pickup_fx(r, kind: String) -> void:
	var c: Vector2 = r.rect().get_center()
	pops.append({"pos": c + Vector2(0, -95), "kind": kind, "t": 0.0})
	for k in 12:
		var a := k * TAU / 12.0
		_part(c, Vector2.from_angle(a) * randf_range(260, 420), 0.5, "estrela", Color("#fff4c8"), randf_range(5, 9))

## Gelo estilhaçou (pancada em quem estava congelado).
func shatter(pos: Vector2) -> void:
	Audio.play("gelo_quebra")
	for k in 16:
		_part(pos + Vector2(randf_range(-20, 20), randf_range(-30, 10)), Vector2(randf_range(-420, 420), randf_range(-520, -80)), 0.8, "lasca", Color("#cfeefc"), randf_range(6, 12))

# ---------------------------------------------------------------- atualizar
func update(dt: float, alive: Array) -> void:
	var lv = main.level
	_update_drills(dt, alive)
	_update_teles(dt)
	_update_lasers(dt, alive)
	_update_vortex(dt, alive)
	_update_blowers(dt, alive)
	_update_ice(dt, alive)
	for pid in anims.keys():
		anims[pid]["t"] += dt
		if anims[pid]["t"] >= anims[pid]["dur"]:
			anims.erase(pid)
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
	# partículas e pops
	for p in parts:
		p["t"] += dt
		p["vel"].y += (900.0 if p["kind"] in ["lasca", "gota"] else 0.0) * dt
		p["vel"] *= 1.0 - dt * (1.5 if p["kind"] in ["estrela", "faisca", "vento", "portal"] else 0.2)
		p["pos"] += p["vel"] * dt
		p["rot"] += p["spin"] * dt
	parts = parts.filter(func(p): return p["t"] < p["life"])
	for p in pops:
		p["t"] += dt
	pops = pops.filter(func(p): return p["t"] < 0.75)
	queue_redraw()

## Furadeira: enquanto a investida dura, fura caixotes à frente e empurra quem estiver no caminho.
func _update_drills(dt: float, alive: Array) -> void:
	var lv = main.level
	for d in drills:
		d["t"] += dt
		var r = _robot(d["owner"])
		if r == null or not r.alive or r.forced_t <= 0.0:
			d["dead"] = true
			if r != null and r.alive:
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

## Teletransporte: os dois somem num redemoinho e trocam de lugar.
func _update_teles(dt: float) -> void:
	var demora := float(cfgi("teletransporte")["demora_s"])
	for tp in teles:
		tp["t"] += dt
		var a = _robot(tp["a"])
		var b = _robot(tp["b"])
		if a == null or b == null or not a.alive or not b.alive:
			tp["dead"] = true
			if a != null:
				a.forced_t = 0.0
			if b != null:
				b.forced_t = 0.0
			continue
		if Engine.get_physics_frames() % 2 == 0:
			for rr in [a, b]:
				var ang := randf() * TAU
				_part(rr.rect().get_center() + Vector2.from_angle(ang) * 60.0, Vector2.from_angle(ang + PI * 0.6) * 260.0, 0.3, "portal", Color("#b48cff"), 5.0)
		if tp["t"] >= demora:
			var pa: Vector2 = a.position
			a.position = b.position
			b.position = pa
			for rr in [a, b]:
				rr.reset_physics_interpolation()
				rr.velocity = Vector2.ZERO
				rr.own_vx = 0.0
				rr.forced_t = 0.0
				rr.vis.stretch()
				main.spark(rr.rect().get_center(), 8)
			b.last_hit = 0.0
			b.last_cause = "teletransporte"
			b.last_attacker = a.pid
			main.float_text(b.position + Vector2(0, -110), "TROCOU!", main.player_color(a.pid))
			Audio.play("teleporte", 1.4)
			main.shake(5.0)
			tp["dead"] = true
	teles = teles.filter(func(tp): return not tp.get("dead", false))

func teleporting(pid: int) -> float:
	for tp in teles:
		if tp["a"] == pid or tp["b"] == pid:
			return tp["t"] / float(cfgi("teletransporte")["demora_s"])
	return -1.0

## Laser: carrega (mira piscando) e dispara um raio pela linha inteira, até uma parede fixa.
func _update_lasers(dt: float, alive: Array) -> void:
	var lc := cfgi("laser")
	var lv = main.level
	for l in lasers:
		l["t"] += dt
		var r = _robot(l["owner"])
		if r == null or not r.alive:
			l["dead"] = true
			continue
		var dir: int = l["dir"]
		var y: float = r.position.y - 44.0
		var x0: float = r.position.x + dir * 54.0
		var x := x0
		while x > 0.0 and x < lv.cols * T:
			var cell := Vector2i(int(floor(x / T)), int(floor(y / T)))
			if lv.is_solid(cell) and not lv.blocks.has(cell):
				break
			x += dir * 16.0
		l["y"] = y
		l["x0"] = x0
		l["x1"] = x
		if not l["fired"] and l["t"] >= float(lc["carga_s"]):
			l["fired"] = true
			Audio.play("laser")
			main.shake(10.0)
			var h := float(lc["altura_px"])
			var beam := Rect2(minf(x0, x), y - h / 2.0, absf(x - x0), h)
			demo.break_by = r.pid
			demo.break_reason = "laser"
			for cell in lv.blocks.keys():
				if beam.intersects(Rect2(Vector2(cell * T), Vector2(T, T))):
					lv.break_block(cell)
					for k in 4:
						_part(Vector2(cell * T) + Vector2(32, 32), Vector2(randf_range(-200, 200), randf_range(-380, -80)), 0.6, "lasca", Color("#c8995f"), 7.0)
			demo.break_reason = ""
			demo.break_by = -1
			for o in alive:
				if o != r and beam.intersects(o.rect()):
					o.take_hit(dir, "laser", r.pid)
					main.spark(o.rect().get_center(), 12)
			r.own_vx = -dir * float(lc["recuo"])
		if l["t"] >= float(lc["carga_s"]) + float(lc["raio_s"]):
			l["dead"] = true
			r.forced_t = 0.0
			r.own_vx = -dir * float(lc["recuo"])
	lasers = lasers.filter(func(l): return not l.get("dead", false))

## Bomba de vórtice: voa em arco; onde cai vira um buraco negro que suga e depois explode.
func _update_vortex(dt: float, alive: Array) -> void:
	var vc := cfgi("vortice")
	var lv = main.level
	for v in vortex_shots:
		v["vel"].y += 1700.0 * dt
		v["pos"] += v["vel"] * dt
		v["rot"] += dt * 12.0
		var cell := Vector2i(int(floor(v["pos"].x / 64.0)), int(floor(v["pos"].y / 64.0)))
		var hit: bool = v["pos"].y > 0.0 and lv.is_solid(cell)
		for o in alive:
			if o.pid != v["owner"] and o.rect().grow(8).has_point(v["pos"]):
				hit = true
		if hit or v["pos"].y > lv.rows * 64.0 - 30.0:
			v["dead"] = true
			vortexes.append({"pos": v["pos"] + Vector2(0, -30), "t": 0.0, "owner": v["owner"]})
			Audio.play("vortice")
	vortex_shots = vortex_shots.filter(func(v): return not v.get("dead", false))
	for v in vortexes:
		v["t"] += dt
		var rad := float(vc["raio_px"])
		for o in alive:
			var d: Vector2 = v["pos"] - o.rect().get_center()
			if d.length() < rad and d.length() > 20.0:
				var k := 1.0 - d.length() / rad
				o.push_vx += signf(d.x) * float(vc["forca"]) * 0.16 * (0.4 + k)
				o.velocity.y = move_toward(o.velocity.y, signf(d.y) * 420.0, 2600.0 * dt * k)
				if o.pid != v["owner"]:
					o.last_attacker = v["owner"]
					o.last_hit = minf(o.last_hit, 1.0)
					o.last_cause = "vórtice"
		if Engine.get_physics_frames() % 2 == 0:
			var ang := randf() * TAU
			_part(v["pos"] + Vector2.from_angle(ang) * rad * 0.7, Vector2.from_angle(ang + PI * 0.85) * 520.0, 0.45, "portal", Color("#7a5fb3"), 6.0)
		if v["t"] >= float(vc["duracao_s"]):
			v["dead"] = true
			demo.explode(v["pos"], float(vc["explosao_px"]), int(v["owner"]))
	vortexes = vortexes.filter(func(v): return not v.get("dead", false))

## Soprador: cone de vento à frente do dono, empurra quem estiver dentro.
func _update_blowers(dt: float, alive: Array) -> void:
	var sc := cfgi("soprador")
	for b in blowers:
		b["t"] += dt
		var r = _robot(b["owner"])
		if r == null or not r.alive or b["t"] >= float(sc["duracao_s"]):
			b["dead"] = true
			continue
		var c: Vector2 = muzzle(r)
		var reach := float(sc["alcance_px"])
		for o in alive:
			if o == r:
				continue
			var d: Vector2 = o.rect().get_center() - c
			if d.x * r.facing > 0.0 and absf(d.x) < reach and absf(d.y) < float(sc["largura_px"]) * (0.4 + 0.6 * absf(d.x) / reach):
				var k := 1.0 - absf(d.x) / reach * 0.5
				o.push_vx += r.facing * float(sc["forca"]) * k
				if not o.is_on_floor():
					o.velocity.y = minf(o.velocity.y, 120.0)
				o.last_attacker = r.pid
				o.last_hit = minf(o.last_hit, 1.0)
				o.last_cause = "soprador"
		if Engine.get_physics_frames() % 2 == 0:
			_part(c + Vector2(r.facing * 6.0, randf_range(-12, 12)), Vector2(r.facing * randf_range(700, 1000), randf_range(-120, 120)), 0.4, "vento", Color(1, 1, 1, 0.8), 3.0)
		if Engine.get_physics_frames() % 24 == 0:
			Audio.play("soprador", 1.0, -6.0)
	blowers = blowers.filter(func(b): return not b.get("dead", false))

func blowing(pid: int) -> bool:
	for b in blowers:
		if b["owner"] == pid:
			return true
	return false

## Congelador: tiro de gelo reto; quem leva fica preso num bloco de gelo.
func _update_ice(dt: float, alive: Array) -> void:
	var cc := cfgi("congelador")
	var lv = main.level
	for s in ice_shots:
		if s.get("wait", 0.0) > 0.0:
			s["wait"] -= dt
			var o0 = _robot(s["owner"])
			if o0 != null:
				s["pos"] = muzzle(o0)
			if s["wait"] > 0.0:
				continue
			main.spark(s["pos"], 4)
		s["pos"] += s["vel"] * dt
		s["trail"].push_front(s["pos"])
		if s["trail"].size() > 7:
			s["trail"].pop_back()
		var cell := Vector2i(int(floor(s["pos"].x / 64.0)), int(floor(s["pos"].y / 64.0)))
		if lv.is_solid(cell) or s["pos"].x < 0.0 or s["pos"].x > lv.cols * 64.0:
			s["dead"] = true
			for k in 6:
				_part(s["pos"], Vector2(randf_range(-200, 200), randf_range(-300, 0)), 0.5, "lasca", Color("#cfeefc"), 6.0)
			continue
		for o in alive:
			if o.pid != s["owner"] and o.rect().grow(6).has_point(s["pos"]) and o.invuln <= 0.0 and not o.god:
				s["dead"] = true
				o.frozen_t = float(cc["gelo_s"])
				o.stun_t = maxf(o.stun_t, float(cc["gelo_s"]))
				o.hanging = false
				o.last_attacker = s["owner"]
				o.last_hit = 0.0
				o.last_cause = "congelado"
				Audio.play("gelo")
				main.float_text(o.position + Vector2(0, -110), "CONGELOU!", Color("#8fd3f0"))
				break
	ice_shots = ice_shots.filter(func(s): return not s.get("dead", false))

func _part(pos: Vector2, vel: Vector2, life: float, kind: String, col: Color, size: float) -> void:
	if parts.size() > 300:
		return
	parts.append({"pos": pos, "vel": vel, "t": 0.0, "life": life, "kind": kind, "col": col, "size": size,
		"rot": randf() * TAU, "spin": randf_range(-14, 14)})

## O robô está furando agora? (o desenho mostra a furadeira à frente)
func drilling(pid: int) -> bool:
	for d in drills:
		if d["owner"] == pid:
			return true
	return false

func charging(pid: int) -> bool:
	for l in lasers:
		if l["owner"] == pid:
			return true
	return false

# ---------------------------------------------------------------- desenho
func _draw() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	_draw_puddles(now)
	# cola voando (com rastro de pingos)
	for g in glue_shots:
		var tr: Array = g["trail"]
		for i in tr.size():
			draw_circle(tr[i], 9.0 - i * 1.2, Color(0.97, 0.96, 0.9, 0.7 - i * 0.1))
		draw_circle(g["pos"], 11, Color("#f5f3ea"))
		draw_circle(g["pos"] + Vector2(-3, -4), 4, Color.WHITE)
	# blocos de gelo em quem está congelado
	for r in main.robots:
		if r.alive and r.frozen_t > 0.0:
			var rr: Rect2 = r.rect().grow(10)
			var a := clampf(r.frozen_t / 0.3, 0.0, 1.0)
			var wob := sin(now * 40.0) * 2.0 if r.frozen_t < 0.4 else 0.0
			rr.position.x += wob
			draw_rect(rr, Color(0.72, 0.9, 1.0, 0.55 * a))
			draw_rect(rr, Color(1, 1, 1, 0.9 * a), false, 3.0)
			draw_line(rr.position + Vector2(8, 10), rr.position + Vector2(20, 30), Color(1, 1, 1, 0.9 * a), 3.0)
			draw_line(rr.position + Vector2(12, 8), rr.position + Vector2(18, 16), Color(1, 1, 1, 0.7 * a), 2.0)
			if r.frozen_t < 0.5:   # rachando antes de soltar
				draw_polyline(PackedVector2Array([rr.position + Vector2(rr.size.x * 0.6, 0), rr.position + Vector2(rr.size.x * 0.4, rr.size.y * 0.4), rr.position + Vector2(rr.size.x * 0.7, rr.size.y * 0.7)]), Color(1, 1, 1, a), 2.0)
	# tiros de gelo
	for s in ice_shots:
		var tr: Array = s["trail"]
		for i in tr.size():
			draw_circle(tr[i], 8.0 - i, Color(0.72, 0.9, 1.0, 0.6 - i * 0.08))
		draw_set_transform(s["pos"], now * 10.0)
		for k in 3:
			draw_line(Vector2.from_angle(k * PI / 3.0) * -12.0, Vector2.from_angle(k * PI / 3.0) * 12.0, Color.WHITE, 3.0, true)
		draw_set_transform(Vector2.ZERO)
		draw_circle(s["pos"], 6, Color("#8fd3f0"))
	# teletransporte: anel girando e o robô sumindo
	for tp in teles:
		var k: float = clampf(tp["t"] / float(cfgi("teletransporte")["demora_s"]), 0.0, 1.0)
		for pid in [tp["a"], tp["b"]]:
			var r = _robot(pid)
			if r == null:
				continue
			var c: Vector2 = r.rect().get_center()
			for i in 3:
				var rad := 50.0 * (1.0 - k) + 10.0 + i * 8.0
				draw_arc(c, rad, now * 12.0 + i * 2.0, now * 12.0 + i * 2.0 + 4.0, 20, Color(0.7, 0.55, 1.0, 0.9), 4.0, true)
			draw_circle(c, 30.0 * k, Color(0.16, 0.09, 0.31, 0.6))
		var a = _robot(tp["a"])
		var b = _robot(tp["b"])
		if a != null and b != null:
			var p0: Vector2 = a.rect().get_center()
			var p1: Vector2 = b.rect().get_center()
			var mid := (p0 + p1) / 2.0 + Vector2(0, -80)
			var pts := PackedVector2Array()
			for i in 17:
				var u := i / 16.0
				pts.append(p0.lerp(mid, u).lerp(mid.lerp(p1, u), u))
			for i in 16:
				if (i + int(now * 20.0)) % 2 == 0:
					draw_line(pts[i], pts[i + 1], Color(0.7, 0.55, 1.0, 0.8), 3.0, true)
	# laser: mira piscando na carga, raio grosso no disparo
	var lc := cfgi("laser")
	for l in lasers:
		if not l.has("y"):
			continue
		var y: float = l["y"]
		var x0: float = l["x0"]
		var x1: float = l["x1"]
		if not l["fired"]:
			var k: float = l["t"] / float(lc["carga_s"])
			if fmod(now, 0.1) < 0.06:
				draw_line(Vector2(x0, y), Vector2(x1, y), Color(1, 0.2, 0.3, 0.4 + 0.5 * k), 2.0 + 2.0 * k)
			draw_circle(Vector2(x0, y), 6.0 + 14.0 * k, Color(1, 0.3, 0.4, 0.5 + 0.4 * k))
			draw_circle(Vector2(x0, y), 4.0 + 6.0 * k, Color.WHITE)
		else:
			var f: float = 1.0 - (l["t"] - float(lc["carga_s"])) / float(lc["raio_s"])
			var h: float = float(lc["altura_px"]) * (0.4 + 0.6 * f)
			draw_rect(Rect2(minf(x0, x1), y - h / 2.0, absf(x1 - x0), h), Color(1.0, 0.25, 0.35, 0.85 * f))
			draw_rect(Rect2(minf(x0, x1), y - h / 4.0, absf(x1 - x0), h / 2.0), Color(1.0, 0.85, 0.9, f))
			draw_circle(Vector2(x1, y), h * 0.8, Color(1, 0.6, 0.4, f))
	# bomba de vórtice voando e buracos negros
	for v in vortex_shots:
		draw_set_transform(v["pos"], v["rot"])
		draw_texture_rect(Data.tex("itens/vortice"), Rect2(-20, -20, 40, 40), false)
		draw_set_transform(Vector2.ZERO)
	var vc := cfgi("vortice")
	for v in vortexes:
		var k: float = v["t"] / float(vc["duracao_s"])
		var p: Vector2 = v["pos"]
		var rad := float(vc["raio_px"])
		draw_circle(p, rad * (0.15 + 0.1 * sin(now * 8.0)), Color(0.12, 0.08, 0.2, 0.25))
		for arm in 4:
			var pts := PackedVector2Array()
			for i in 18:
				var u := i / 17.0
				var ang: float = arm * TAU / 4.0 + u * 4.0 - now * 6.0
				pts.append(p + Vector2.from_angle(ang) * (12.0 + u * rad * 0.55))
			draw_polyline(pts, Color(0.55, 0.4, 0.9, 0.7 * (1.0 - k * 0.3)), 4.0, true)
		draw_circle(p, 30.0 + 8.0 * sin(now * 20.0) + 20.0 * k, Color("#1c1830"))
		draw_arc(p, 34.0 + 20.0 * k, 0, TAU, 32, Color(0.7, 0.55, 1.0, 0.9), 3.0, true)
		if k > 0.75 and fmod(now, 0.12) < 0.06:
			draw_circle(p, 50.0 + 20.0 * k, Color(1, 1, 1, 0.3))
	# soprador: cone de vento listrado na frente do dono
	var sc := cfgi("soprador")
	for b in blowers:
		var r = _robot(b["owner"])
		if r == null:
			continue
		var c: Vector2 = muzzle(r)
		var reach := float(sc["alcance_px"])
		var wid := float(sc["largura_px"])
		var cone := PackedVector2Array([c + Vector2(0, -8), c + Vector2(r.facing * reach, -wid), c + Vector2(r.facing * reach, wid), c + Vector2(0, 8)])
		draw_colored_polygon(cone, Color(1, 1, 1, 0.12))
		for i in 6:
			var u := fposmod(now * 2.5 + i / 6.0, 1.0)
			var x: float = c.x + r.facing * (10.0 + u * reach)
			var hh := 10.0 + u * wid * 0.9
			draw_arc(Vector2(x, c.y), hh, -0.9 if r.facing > 0 else PI - 0.9, 0.9 if r.facing > 0 else PI + 0.9, 10, Color(1, 1, 1, 0.6 * (1.0 - u)), 3.0, true)
	# furadeira em ação: linhas de velocidade atrás do robô (a furadeira está na mão dele)
	for d in drills:
		var r = _robot(d["owner"])
		if r == null:
			continue
		for k in 3:
			var yy: float = r.position.y - 60.0 + k * 22.0
			draw_line(Vector2(r.position.x - r.facing * 40.0, yy), Vector2(r.position.x - r.facing * (80.0 + k * 20.0), yy), Color(1, 1, 1, 0.6), 3.0, true)
	_draw_parts()
	# pegou item: ícone cresce, gira um pouco e some, com anel
	for p in pops:
		var k: float = p["t"] / 0.75
		var sc2 := 0.6 + 0.5 * sin(minf(k * 3.0, 1.0) * PI * 0.5) - 0.3 * k
		var pos: Vector2 = p["pos"] + Vector2(0, -50.0 * k)
		draw_arc(p["pos"], 20.0 + 90.0 * k, 0, TAU, 32, Color(1, 1, 1, 0.8 * (1.0 - k)), 6.0 * (1.0 - k) + 1.0, true)
		draw_set_transform(pos, sin(k * 12.0) * 0.2 * (1.0 - k), Vector2(sc2, sc2))
		draw_texture_rect(Data.tex("itens/" + String(p["kind"])), Rect2(-28, -28, 56, 56), false, Color(1, 1, 1, clampf((1.0 - k) * 2.0, 0.0, 1.0)))
		draw_set_transform(Vector2.ZERO)

func _draw_puddles(now: float) -> void:
	for p in puddles:
		var r: Rect2 = p["rect"]
		var a := clampf(p["t"] / 0.6, 0.0, 1.0)
		var w: float = r.size.x * (0.4 + 0.6 * p["grow"])
		var cx := r.get_center().x
		var y := r.position.y + 10.0
		var pts := PackedVector2Array()
		for k in 17:
			var u := k / 16.0
			pts.append(Vector2(cx - w / 2.0 + w * u, y - 6.0 - sin(u * PI) * 6.0 - sin(now * 3.0 + k) * 1.5))
		pts.append(Vector2(cx + w / 2.0, y + 6.0))
		pts.append(Vector2(cx - w / 2.0, y + 6.0))
		draw_colored_polygon(pts, Color(0.97, 0.96, 0.9, a))
		draw_line(Vector2(cx - w * 0.3, y - 9.0), Vector2(cx + w * 0.1, y - 11.0), Color(1, 1, 1, a), 3.0, true)
		for k in 3:
			var bx := cx - w * 0.3 + k * w * 0.3
			var bub := fposmod(now * 0.8 + k * 0.37, 1.0)
			draw_arc(Vector2(bx, y - 6.0 - bub * 6.0), 3.0 + bub * 3.0, 0, TAU, 12, Color(0.85, 0.84, 0.78, a * (1.0 - bub)), 1.5, true)
			draw_rect(Rect2(bx - 2.0, y + 6.0, 4.0, 4.0 + 5.0 * fposmod(now + k * 0.5, 1.0)), Color(0.97, 0.96, 0.9, a))

func _draw_parts() -> void:
	for p in parts:
		var a: float = 1.0 - p["t"] / p["life"]
		var c: Color = p["col"]
		c.a *= a
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
			"portal":
				draw_circle(pos, s * a, c)
			_:
				draw_line(pos, pos - p["vel"] * 0.03, c, s * 0.6, true)
