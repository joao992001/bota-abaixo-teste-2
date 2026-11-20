extends Node
## Modo Festa · DEMOLIÇÃO: todos numa obra de caixotes sobre espinhos. A marreta quebra caixotes
## (inclusive o chão de quem está ao lado) e empurra robôs; pular na cabeça atordoa; caixote racha
## se alguém fica parado em cima; depois de um tempo, terremoto derruba blocos. Último em pé leva ⭐.
## Itens caem do céu em bolhas: dinamite (arremessa), martelão, capacete de aço (escudo), botas de mola.
## Números em data/modos.json ("demolicao").

var main: Node
var cfg: Dictionary
var t := 0.0                 # tempo da rodada (depois do VAI!)
var quake_t := 0.0
var quaking := false
var round_winner := -1
var banner := ""
var banner_t := 0.0
var items: Array = []        # {kind, pos, vy, landed, t}
var dynamites: Array = []    # {pos, vel, t, owner}
var booms: Array = []        # explosões desenhadas {pos, t}
var item_t := 4.0
var canvas: Node2D           # desenha itens, dinamites e explosões no mundo
var crumbling := false       # quebra por ter ficado parado em cima (culpa de quem estava em cima)
const ArenaFx := preload("res://modes/arena_fx.gd")
var fx: Node2D = null        # mecânicas da arena (plataformas, lama, bola, esteiras)
var arena := {}              # {id, nome, dica} da rodada atual
var last_arena := ""
var tnt_queue: Array = []
var go_played := false
var break_reason := ""       # por que o caixote que está quebrando agora quebrou (para a causa da queda)
var break_by := -1
var death_log: Array = []
var feed: Array = []         # avisos na tela: "P3 derrubou P1"
var net_hp := {}             # rede: Vector2i -> quedas que ainda aguenta    # {arena, t, victim, cause, by, round}    # TNT quebrado explode logo depois: {pos, t}

func setup(m: Node) -> void:
	main = m
	cfg = Data.read_json("data/modos.json")["demolicao"]

func c(key: String) -> float:
	return float(cfg[key])

func item_cfg(kind: String) -> Dictionary:
	return cfg["itens"][kind]

## Arena da rodada: a escolhida ou, no sorteio, uma diferente da anterior.
func pick_arena() -> Dictionary:
	var list: Array = cfg["arenas"]
	var choice: String = main.arena_choice
	if choice != "sorteio":
		for a in list:
			if a["id"] == choice:
				return a
	var opts := list.filter(func(a): return a["id"] != last_arena)
	return opts[main.rng.randi() % opts.size()]

## Nova rodada: arena nova, robôs nos spawns de acordo com o número de jogadores.
func start_round() -> void:
	arena = pick_arena()
	last_arena = arena["id"]
	main.load_arena(arena["id"])
	if fx != null and is_instance_valid(fx):
		fx.queue_free()
	fx = ArenaFx.new()
	main.world.add_child(fx)
	main.world.move_child(fx, 1)
	fx.setup(main, main.level)
	tnt_queue.clear()
	main.level.block_hp = int(c("block_hp"))
	for b in main.level.blocks.values():
		b["hp"] = main.level.block_hp
	main.level.block_broken.connect(_on_block_broken)
	if canvas == null or not is_instance_valid(canvas):
		canvas = Node2D.new()
		canvas.draw.connect(_draw_canvas)
		main.world.add_child(canvas)
	t = 0.0
	quake_t = 0.0
	quaking = false
	round_winner = -1
	items.clear()
	dynamites.clear()
	booms.clear()
	item_t = 4.0
	banner = String(arena["nome"]).to_upper()
	banner_t = 2.2
	go_played = false
	Audio.play("contagem")
	var n: int = main.players.size()
	var spots: Array = cfg["spawns_by_players"].get(str(n), [1, 2, 3, 4])
	main.start_run_at(spots)
	for r in main.robots:
		r.hammer_left = 999
		r.facing = 1 if r.position.x < 960 else -1

func update(dt: float) -> void:
	banner_t = maxf(banner_t - dt, 0.0)
	_update_fx(dt)
	if fx != null and is_instance_valid(fx):
		fx.update(dt, main.countdown <= 0.0)
	if not go_played and main.countdown <= 0.6:
		go_played = true
		Audio.play("vai")
		for r in main.robots:
			r.invuln = float(cfg["recuperacao"]["invuln_inicio_s"])
	if main.countdown > 0.0:
		return
	for q in tnt_queue:
		q["t"] -= dt
		if q["t"] <= 0.0:
			explode(q["pos"], 150.0)
	tnt_queue = tnt_queue.filter(func(q): return q["t"] > 0.0)
	t += dt
	var lv = main.level
	var alive: Array = main.robots.filter(func(r): return r.alive)
	# pisão na cabeça (o capacete bloqueia)
	for r in alive:
		r.stomp_immune = maxf(r.stomp_immune - dt, 0.0)
	for a in alive:
		if a.velocity.y <= 120.0 or a.stun_t > 0.0:
			continue
		for b in alive:
			if a == b or b.stomp_immune > 0.0 or b.invuln > 0.0:
				continue
			var head: float = b.rect().position.y
			if absf(a.position.y - head) < 16.0 and absf(a.position.x - b.position.x) < 38.0:
				a.velocity.y = -c("stomp_bounce")
				a.var_jump = 0.0
				Audio.play("pisao")
				var side := signf(a.position.x - b.position.x)
				if side == 0.0:
					side = float(a.facing)
				a.own_vx = side * c("stomp_side_push")   # sai de cima, não cai de novo na mesma cabeça
				a.vis.stretch()
				b.stomp_immune = c("stomp_immune_s")
				b.last_hit = 0.0
				b.last_cause = "pisão"
				b.last_attacker = a.pid
				b.hanging = false
				if not b.absorb():
					b.dmg += float(cfg["amassometro"]["pisao"]["dano"])
					b.stun_t = c("stun_stomp_s")
					Audio.voice("voz_ai", b.vis.model)
					Audio.play("tonto", 1.0, -4.0)
					b.vis.sq = Vector2(1.5, 0.55)
					main.float_text(b.position + Vector2(0, -110), "PISÃO!", main.player_color(a.pid))
				main.spark(b.position + Vector2(0, -70), 6)
				main.dust(b.position + Vector2(0, -60), 0.7)
				main.shake(4.0)
				break
	# caixote racha e cai se alguém fica parado em cima
	var stood := {}
	for r in alive:
		if r.is_on_floor():
			var cell := Vector2i(int(r.position.x / 64.0), int((r.position.y + 2.0) / 64.0))
			if lv.blocks.has(cell):
				stood[cell] = true
	for cell in lv.blocks.keys():
		var b: Dictionary = lv.blocks[cell]
		if stood.has(cell):
			b["load"] += dt
			if b["load"] >= c("crumble_break_s"):
				crumbling = true
				lv.break_block(cell)
				crumbling = false
				continue
			if b["load"] >= c("crumble_crack_s") and b["hp"] == lv.block_hp:
				b["hp"] = lv.block_hp - 1
				lv.queue_redraw()
		if b["warn"] > 0.0:
			b["warn"] -= dt
			if b["warn"] <= 0.0:
				break_reason = "terremoto"
				lv.break_block(cell)
				break_reason = ""
	# terremoto depois de um tempo: garante que a rodada acaba
	var quake_at := float(main.level.prop("terremoto", str(c("quake_start_s"))))
	if quake_at > 0.0 and t >= quake_at:
		if not quaking:
			quaking = true
			banner = "TERREMOTO!"
			banner_t = 1.6
			Audio.play("terremoto")
			main.shake(10.0)
		quake_t -= dt
		if quake_t <= 0.0 and lv.blocks.size() > 0:
			quake_t = c("quake_every_s")
			var keys: Array = lv.blocks.keys().filter(func(k): return lv.blocks[k]["warn"] <= 0.0)
			if keys.size() > 0:
				var k: Vector2i = keys[main.rng.randi() % keys.size()]
				lv.blocks[k]["warn"] = c("quake_warn_s")
				main.shake(2.0)
	_update_items(dt, alive)
	_update_dynamites(dt, alive)
	_update_water_and_nets(dt, alive)
	for f in feed:
		f["t"] += dt
	feed = feed.filter(func(f): return f["t"] < 4.5)
	# fim da rodada: sobrou 1 (ou ninguém)
	if main.end_delay < 0.0 and alive.size() <= 1 and main.robots.size() >= 2:
		round_winner = alive[0].pid if alive.size() == 1 else -1
		main.end_delay = 1.4
		if round_winner >= 0:
			alive[0].vis.expression = "vitoria"
			Audio.play("rodada_vence")
			Audio.voice("voz_eba", alive[0].vis.model)
			banner = "P%d  VENCEU A RODADA!" % (round_winner + 1)
		else:
			Audio.play("menu_negado")
			banner = "EMPATE!"
		banner_t = 3.0

# ---------------------------------------------------------------- itens
func _update_items(dt: float, alive: Array) -> void:
	var ic: Dictionary = cfg["itens"]
	item_t -= dt
	if item_t <= 0.0:
		var span: Array = ic["spawn_every_s"]
		item_t = main.rng.randf_range(float(span[0]), float(span[1]))
		if items.size() < int(ic["max_on_map"]):
			spawn_item(ic["kinds"][main.rng.randi() % ic["kinds"].size()])
	var lv = main.level
	for it in items:
		it["t"] += dt
		var cell := Vector2i(int(it["pos"].x / 64.0), int(floor((it["pos"].y + 26.0) / 64.0)))
		var plat = fx.platform_at(it["pos"] + Vector2(0, 26)) if fx != null and is_instance_valid(fx) else null
		if plat != null and it["vy"] >= 0.0:
			# pousou numa plataforma que se move: anda junto
			var pp: Vector2 = plat["body"].position
			if it.get("plat") == plat:
				it["pos"].x += pp.x - it["plat_x"]
			it["plat"] = plat
			it["plat_x"] = pp.x
			it["pos"].y = pp.y - 26.0
			it["vy"] = 0.0
		elif lv.extra_solid.is_valid() and lv.extra_solid.call(cell):
			it["plat"] = null
			it["vy"] = minf(it["vy"] + 900.0 * dt, 420.0)
			it["pos"].y += it["vy"] * dt
		elif lv.is_solid(cell) and it["pos"].y + 26.0 >= cell.y * 64.0:
			it["pos"].y = cell.y * 64.0 - 26.0
			it["vy"] = 0.0
		else:
			it["vy"] = minf(it["vy"] + 900.0 * dt, 420.0)
			it["pos"].y += it["vy"] * dt
		for r in alive:
			if r.rect().grow(6).has_point(it["pos"]):
				give(r, it["kind"])
				it["t"] = 999.0
				break
	items = items.filter(func(it): return it["t"] < float(ic["lifetime_s"]) and it["pos"].y < 1100.0)

## Item cai do céu numa coluna que ainda tem caixote.
func spawn_item(kind: String, col := -1) -> void:
	var lv = main.level
	if col < 0:
		var cols := []
		for cell in lv.blocks.keys():
			if not (cell.x in cols):
				cols.append(cell.x)
		if cols.is_empty():
			return
		col = cols[main.rng.randi() % cols.size()]
	items.append({"kind": kind, "pos": Vector2(col * 64 + 32, 70), "vy": 0.0, "t": 0.0})   # abaixo do teto invisível

func give(r, kind: String) -> void:
	match kind:
		"dinamite": r.item = "dinamite"
		"martelao": r.fx_t["martelao"] = float(item_cfg("martelao")["duration_s"])
		"mola": r.fx_t["mola"] = float(item_cfg("mola")["duration_s"])
		"capacete": r.shield = int(item_cfg("capacete")["hits"])
	Audio.play("martelao" if kind == "martelao" else "item")
	var names := {"dinamite": "DINAMITE!", "martelao": "MARTELÃO!", "mola": "BOTAS DE MOLA!", "capacete": "CAPACETE!"}
	main.float_text(r.position + Vector2(0, -110), names[kind], main.player_color(r.pid))
	main.spark(r.rect().get_center(), 5)

## Botão de item: arremessa a dinamite guardada.
func use_item(r) -> void:
	if r.item == "dinamite":
		r.item = ""
		Audio.play("arremesso")
		var th: Array = item_cfg("dinamite")["throw"]
		dynamites.append({"pos": r.rect().get_center() + Vector2(r.facing * 20, -20),
			"vel": Vector2(r.facing * float(th[0]) + r.velocity.x * 0.3, -float(th[1])), "t": 0.0, "owner": r.pid})
		r.vis.stretch()

func _update_dynamites(dt: float, alive: Array) -> void:
	var dc := item_cfg("dinamite")
	var lv = main.level
	for d in dynamites:
		d["t"] += dt
		d["vel"].y += 1800.0 * dt
		d["pos"] += d["vel"] * dt
		var hit: bool = d["t"] >= float(dc["fuse_s"]) or d["pos"].y > 1000.0
		if lv.is_solid(Vector2i(int(d["pos"].x / 64.0), int(d["pos"].y / 64.0))):
			hit = true
		for r in alive:
			if r.pid != d["owner"] and r.rect().grow(10).has_point(d["pos"]):
				hit = true
		if hit:
			explode(d["pos"])
			d["t"] = 999.0
	dynamites = dynamites.filter(func(d): return d["t"] < 999.0)

## Explosão: destrói caixotes no raio e lança os robôs para longe (TNT tem raio maior).
func explode(pos: Vector2, rad := -1.0) -> void:
	var dc := item_cfg("dinamite")
	if rad < 0.0:
		rad = float(dc["radius_px"])
	var lv = main.level
	for cell in lv.blocks.keys():
		if (Vector2(cell * 64) + Vector2(32, 32)).distance_to(pos) < rad:
			break_reason = "explosão"
			lv.damage(cell, int(dc["block_damage"]))
			break_reason = ""
	for r in main.robots:
		if r.alive and r.rect().get_center().distance_to(pos) < rad + 30.0:
			var dir := 1 if r.rect().get_center().x >= pos.x else -1
			r.take_hit(dir, "explosao", -1)
	booms.append({"pos": pos, "t": 0.0})
	Audio.play("explosao")
	main.spark(pos, 10)
	main.dust(pos, 1.6)
	main.shake(12.0)

func _update_fx(dt: float) -> void:
	for b in booms:
		b["t"] += dt
	booms = booms.filter(func(b): return b["t"] < 0.6)
	if canvas != null and is_instance_valid(canvas):
		canvas.queue_redraw()

func _draw_canvas() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for it in items:
		var life: float = float(cfg["itens"]["lifetime_s"]) - it["t"]
		if life < 3.0 and fmod(now, 0.3) < 0.12:
			continue   # pisca antes de sumir
		var p: Vector2 = it["pos"] + Vector2(0, sin(now * 4.0 + it["pos"].x) * 3.0)
		canvas.draw_circle(p, 27, Color(1, 1, 1, 0.55))
		canvas.draw_arc(p, 27, 0, TAU, 32, Color(1, 1, 1, 0.9), 2.5, true)
		canvas.draw_texture_rect(Data.tex("itens/" + it["kind"]), Rect2(p - Vector2(22, 22), Vector2(44, 44)), false)
	for d in dynamites:
		canvas.draw_set_transform(d["pos"], d["t"] * 9.0)
		canvas.draw_texture_rect(Data.tex("itens/dinamite"), Rect2(-16, -16, 32, 32), false)
		canvas.draw_set_transform(Vector2.ZERO)
		if fmod(now, 0.16) < 0.08:
			canvas.draw_circle(d["pos"] + Vector2(10, -16).rotated(d["t"] * 9.0), 5, Color("#fff4c8"))
	# explosão cartoon: bolas amarelas/laranja e fumaça escura em camadas (ref. de explosões)
	for b in booms:
		var k: float = b["t"] / 0.6
		var p: Vector2 = b["pos"]
		var r := 40.0 + 110.0 * sqrt(k)
		var a := 1.0 - k
		for i in 7:
			var ang := i * TAU / 7.0 + 0.4
			canvas.draw_circle(p + Vector2.from_angle(ang) * r * 0.55, r * 0.5, Color(0.25, 0.22, 0.27, 0.55 * a))
		for i in 6:
			var ang := i * TAU / 6.0
			canvas.draw_circle(p + Vector2.from_angle(ang) * r * 0.35, r * 0.42, Color(1.0, 0.55, 0.15, a))
		canvas.draw_circle(p, r * 0.45, Color(1.0, 0.85, 0.25, a))

# ---------------------------------------------------------------- marreta
## Marretada: empurra o robô à frente e quebra o caixote à frente (no corpo ou no chão).
## Segurando ▼, quebra o caixote embaixo de você mesmo. Martelão: 1 golpe quebra, empurra mais.
func hammer(r) -> void:
	var big: bool = r.fx_t["martelao"] > 0.0
	var reach := c("hammer_reach_px") * (1.3 if big else 1.0)
	var mult := float(item_cfg("martelao")["knock_mult"]) if big else 1.0
	var rr: Rect2 = r.rect()
	var hit := Rect2(rr.end.x if r.facing > 0 else rr.position.x - reach, rr.position.y, reach, rr.size.y)
	var hit_robot := false
	for o in main.robots:
		if o != r and o.alive and hit.intersects(o.rect()):
			o.take_hit(r.facing, "martelao" if big else "marretada", r.pid)
			Audio.play("bonk", 1.0 / mult)
			main.spark(o.rect().get_center(), 6)
			main.shake(5.0 * mult)
			hit_robot = true
	if hit_robot:
		return
	var lv = main.level
	var feet_row := int((r.position.y + 2.0) / 64.0)
	var targets: Array = []
	if PlayerInput.held(r.pid, "down"):
		targets.append(Vector2i(int(r.position.x / 64.0), feet_row))
	else:
		var fx: float = (rr.end.x + 20.0) if r.facing > 0 else (rr.position.x - 20.0)
		var col := int(floor(fx / 64.0))
		targets.append(Vector2i(col, feet_row - 1))
		targets.append(Vector2i(col, feet_row))
	for cell in targets:
		if lv.blocks.has(cell):
			var center := Vector2(cell * 64) + Vector2(32, 32)
			main.spark(center, 4)
			main.dust(center, 0.8)
			Audio.play("caixote_pancada", 0.85 if big else 1.0)
			break_reason = "chão marretado"
			break_by = r.pid
			lv.damage(cell, int(item_cfg("martelao")["block_damage"]) if big else 1)
			break_reason = ""
			break_by = -1
			return

## Água: não mata; volta do alto com dano extra. Rede: quica e rasga depois de algumas quedas.
func _update_water_and_nets(dt: float, alive: Array) -> void:
	var lv = main.level
	for r in alive:
		for w in lv.water_rects:
			if w.has_point(r.position + Vector2(0, -10)):
				r.dmg += float(cfg["amassometro"]["agua"]["dano"])
				Audio.play("lama", 0.6)
				main.dust(r.position, 1.4)
				main.float_text(r.position + Vector2(0, -80), "TCHIBUM! +%d%%" % int(cfg["amassometro"]["agua"]["dano"]), Color("#4f86d9"))
				respawn(r)
				break
		if r.velocity.y > 150.0:
			var cell := Vector2i(int(r.position.x / 64.0), int((r.position.y - 4.0) / 64.0))
			if lv.ch_at(cell) == "n" and r.position.y >= cell.y * 64.0 + 8.0 and r.position.y - r.velocity.y * dt <= cell.y * 64.0 + 14.0:
				r.velocity.y = -minf(r.velocity.y * 0.85 + 300.0, float(cfg["rede"]["quica"]))
				r.air_jumps = 1
				Audio.play("pulo_mola", 0.8)
				var hp: int = net_hp.get(cell, int(cfg["rede"]["aguenta"])) - 1
				net_hp[cell] = hp
				if hp <= 0:
					for dx in range(-1, 2):
						var nc := cell + Vector2i(dx, 0)
						if lv.ch_at(nc) == "n":
							lv.set_cell_char(nc, ".")
					main.dust(r.position, 1.2)
					main.float_text(r.position + Vector2(0, -80), "RASGOU!", Color.WHITE)

## Volta pendurado no guindaste num lugar livre longe dos outros, invulnerável por um tempo.
func respawn(r) -> void:
	var lv = main.level
	var best := Vector2i(-1, -1)
	var best_d := -1.0
	for y in range(3, lv.rows - 1):
		for x in range(1, lv.cols - 1):
			var c := Vector2i(x, y)
			if lv.is_solid(c) and lv.ch_at(c) != "I" and not lv.is_solid(c + Vector2i.UP) and not lv.is_solid(c + Vector2i(0, -2)):
				var p := Vector2(x * 64 + 32, y * 64)
				var dmin := 1e9
				for o in main.robots:
					if o != r and o.alive:
						dmin = minf(dmin, o.position.distance_to(p))
				dmin += main.rng.randf_range(0, 200)
				if dmin > best_d:
					best_d = dmin
					best = c
	if best.x < 0:
		return
	r.position = Vector2(best.x * 64 + 32, best.y * 64 - 220)
	r.reset_physics_interpolation()
	r.velocity = Vector2.ZERO
	r.own_vx = 0.0
	r.stun_t = 0.0
	r.hanging = false
	r.invuln = float(cfg["recuperacao"]["invuln_volta_s"])
	r.drop_t = 1.0

func _on_block_broken(cell: Vector2i, kind: String) -> void:
	var center := Vector2(cell * 64) + Vector2(32, 32)
	if break_by >= 0 and break_by < main.players.size():
		main.players[break_by]["stats"]["caixotes"] += 1
	Audio.play("caixote_quebra")
	if kind == "tnt":
		tnt_queue.append({"pos": center, "t": 0.18})   # explode logo depois (dá para ver a reação em cadeia)
	# quem estava em cima caiu por golpe/explosão/terremoto (não "sozinho"), a não ser que tenha ficado parado
	for r in main.robots:
		if r.alive and absf(r.position.x - center.x) < 56.0 and absf(r.position.y - cell.y * 64.0) < 6.0:
			if crumbling:
				r.fall_reason = "ficou parado"
				r.last_cause = "ficou parado"
			else:
				r.last_hit = 0.0
				r.last_cause = break_reason if break_reason != "" else "chão quebrado"
				r.last_attacker = break_by
	main.dust(center)
	main.break_crate(center)

## Alguém caiu (by = quem derrubou, -1 se ninguém). Os submodos usam isto.
func on_knockout(_by: int, _victim: int) -> void:
	pass

## Fim da rodada: estrela para o vencedor; partida acaba em rounds_to_win.
func end_round() -> bool:
	if round_winner >= 0:
		main.players[round_winner]["score"] += 1
	return round_winner >= 0 and main.players[round_winner]["score"] >= int(c("rounds_to_win"))
