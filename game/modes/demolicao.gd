extends Node
## Modo Festa · DEMOLIÇÃO: todos numa obra de caixotes sobre espinhos. A marreta quebra caixotes
## (inclusive o chão de quem está ao lado) e empurra robôs; pular na cabeça atordoa; caixote racha
## se alguém fica parado em cima; depois de um tempo, terremoto derruba blocos. Último em pé leva ⭐.
## Números em data/modos.json ("demolicao").

var main: Node
var cfg: Dictionary
var t := 0.0                 # tempo da rodada (depois do VAI!)
var quake_t := 0.0
var quaking := false
var round_winner := -1
var banner := ""
var banner_t := 0.0

func setup(m: Node) -> void:
	main = m
	cfg = Data.read_json("data/modos.json")["demolicao"]

func c(key: String) -> float:
	return float(cfg[key])

## Nova rodada: arena nova, robôs nos spawns de acordo com o número de jogadores.
func start_round() -> void:
	main.load_arena("demolicao")
	main.level.block_hp = int(c("block_hp"))
	for b in main.level.blocks.values():
		b["hp"] = main.level.block_hp
	main.level.block_broken.connect(_on_block_broken)
	t = 0.0
	quake_t = 0.0
	quaking = false
	round_winner = -1
	banner = "DERRUBE OS OUTROS!"
	banner_t = 2.2
	var n: int = main.players.size()
	var spots: Array = cfg["spawns_by_players"].get(str(n), [1, 2, 3, 4])
	main.start_run_at(spots)
	for r in main.robots:
		r.hammer_left = 999
		r.facing = 1 if r.position.x < 960 else -1

func update(dt: float) -> void:
	banner_t = maxf(banner_t - dt, 0.0)
	if main.countdown > 0.0:
		return
	t += dt
	var lv = main.level
	var alive: Array = main.robots.filter(func(r): return r.alive)
	# pisão na cabeça
	for a in alive:
		if a.velocity.y <= 120.0 or a.stun_t > 0.0:
			continue
		for b in alive:
			if a == b:
				continue
			var head: float = b.rect().position.y
			if absf(a.position.y - head) < 16.0 and absf(a.position.x - b.position.x) < 38.0:
				a.velocity.y = -c("stomp_bounce")
				a.vis.stretch()
				b.stun_t = c("stun_stomp_s")
				b.vis.sq = Vector2(1.5, 0.55)
				main.spark(b.position + Vector2(0, -70), 6)
				main.dust(b.position + Vector2(0, -60), 0.7)
				main.shake(4.0)
				main.float_text(b.position + Vector2(0, -110), "PISÃO!", main.player_color(a.pid))
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
				lv.break_block(cell)
				continue
			if b["load"] >= c("crumble_crack_s") and b["hp"] == lv.block_hp:
				b["hp"] = lv.block_hp - 1
				lv.queue_redraw()
		# terremoto: blocos avisados tremem e caem
		if b["warn"] > 0.0:
			b["warn"] -= dt
			if b["warn"] <= 0.0:
				lv.break_block(cell)
	# terremoto depois de um tempo: garante que a rodada acaba
	if t >= c("quake_start_s"):
		if not quaking:
			quaking = true
			banner = "TERREMOTO!"
			banner_t = 1.6
			main.shake(10.0)
		quake_t -= dt
		if quake_t <= 0.0 and lv.blocks.size() > 0:
			quake_t = c("quake_every_s")
			var keys: Array = lv.blocks.keys().filter(func(k): return lv.blocks[k]["warn"] <= 0.0)
			if keys.size() > 0:
				var k: Vector2i = keys[main.rng.randi() % keys.size()]
				lv.blocks[k]["warn"] = c("quake_warn_s")
				main.shake(2.0)
	# fim da rodada: sobrou 1 (ou ninguém)
	if main.end_delay < 0.0 and alive.size() <= 1 and main.robots.size() >= 2:
		round_winner = alive[0].pid if alive.size() == 1 else -1
		main.end_delay = 1.4
		if round_winner >= 0:
			alive[0].vis.expression = "vitoria"
			banner = "P%d VENCEU A RODADA!" % (round_winner + 1)
		else:
			banner = "EMPATE!"
		banner_t = 3.0

## Marretada: empurra o robô à frente e quebra o caixote à frente (no corpo ou no chão).
## Segurando ▼, quebra o caixote embaixo de você mesmo.
func hammer(r) -> void:
	var reach := c("hammer_reach_px")
	var rr: Rect2 = r.rect()
	var hit := Rect2(rr.end.x if r.facing > 0 else rr.position.x - reach, rr.position.y, reach, rr.size.y)
	var hit_robot := false
	for o in main.robots:
		if o != r and o.alive and hit.intersects(o.rect()):
			o.knock(r.facing, c("knock_x"), c("knock_y"), c("stun_hit_s"))
			main.spark(o.rect().get_center(), 6)
			main.shake(5.0)
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
		targets.append(Vector2i(col, feet_row - 1))   # na altura do corpo
		targets.append(Vector2i(col, feet_row))       # no chão à frente (onde o rival pisa)
	for cell in targets:
		if lv.blocks.has(cell):
			var center := Vector2(cell * 64) + Vector2(32, 32)
			main.spark(center, 4)
			main.dust(center, 0.8)
			lv.damage(cell, 1)
			return

func _on_block_broken(cell: Vector2i) -> void:
	var center := Vector2(cell * 64) + Vector2(32, 32)
	main.dust(center)
	main.break_crate(center)

## Fim da rodada: estrela para o vencedor; partida acaba em rounds_to_win.
func end_round() -> bool:
	if round_winner >= 0:
		main.players[round_winner]["score"] += 1
	return round_winner >= 0 and main.players[round_winner]["score"] >= int(c("rounds_to_win"))
