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
const Kit := preload("res://ui/kit.gd")
var fx: Node2D = null        # mecânicas da arena (plataformas, lama, bola, esteiras)
var arena := {}              # {id, nome, dica} da rodada atual
var last_arena := ""
var tnt_queue: Array = []
var go_played := false
var break_reason := ""       # por que o caixote que está quebrando agora quebrou (para a causa da queda)
var break_by := -1
var death_log: Array = []
var feed: Array = []         # avisos na tela: "P3 derrubou P1"
var net_hp := {}             # rede: Vector2i -> quedas que ainda aguenta
# ---- submodos (Último em Pé, Vidas, Placar de Demolição, Batata-Dinamite)
var sub := {}                # modo atual (data/modos.json → demolicao.modos): derruba, batata, rei, fuga
var lives := {}              # Derruba: pid -> vidas restantes
var lives_setting := 3       # AJUSTES (Derruba): vidas por rodada
var fuse_setting := 1        # AJUSTES (Batata): 0 curto, 1 normal, 2 longo
const FUSES := [[6, 10], [9, 15], [13, 20]]
# Rei da Obra
var king := -1               # quem está com o capacete de ouro (-1: no chão)
var crown_pos := Vector2.ZERO
var crown_vel := Vector2.ZERO
var crown_home := Vector2.ZERO
var king_time := {}          # pid -> segundos com o capacete
var crown_cd := {}           # pid -> espera para pegar de novo depois de perder
var king_hit := {}           # pid -> last_hit do quadro anterior (para perceber o golpe)
var king_setting := 0        # AJUSTES: 0 = 20 s, 1 = 30 s, 2 = 45 s
var king_grace := 0.0        # o rei acabou de pegar: protegido por um instante (a coroa não fica pulando de mão)
const KING_GOALS := [20, 30, 45]
var bomb_holder := -1        # Batata: quem está com a dinamite
var bomb_fuse := 0.0
var bomb_next := 0.0
var bomb_pass_cd := 0.0
var bomb_beep := 0.0
var items_on := true         # AJUSTES: itens ligados
var help_losers := true      # AJUSTES: quem está em último começa com capacete

## Modo de jogo da partida (derruba, batata, rei, fuga).
func rule() -> String:
	return String(sub.get("id", "derruba"))

func find_mode(id: String) -> Dictionary:
	for m in cfg["modos"]:
		if m["id"] == id:
			return m
	return cfg["modos"][0]

## Arenas do modo (na ordem do data/modos.json).
func mode_arenas(id: String) -> Array:
	var ids: Array = find_mode(id).get("arenas", [])
	var out := []
	for a in cfg["arenas"]:
		if a["id"] in ids:
			out.append(a)
	return out    # {arena, t, victim, cause, by, round}    # TNT quebrado explode logo depois: {pos, t}

func setup(m: Node) -> void:
	main = m
	cfg = Data.read_json("data/modos.json")["demolicao"]

func c(key: String) -> float:
	return float(cfg[key])

func item_cfg(kind: String) -> Dictionary:
	return cfg["itens"][kind]

## Arena da rodada: a escolhida ou, no sorteio, uma diferente da anterior.
func pick_arena() -> Dictionary:
	var list: Array = mode_arenas(main.game_mode)
	if list.is_empty():
		list = cfg["arenas"]
	var choice: String = main.arena_choice
	if choice == "oficina":
		return {"id": "oficina", "nome": "Oficina", "dica": "Teste à vontade: START abre o painel", "musica": "partida"}
	if choice != "sorteio":
		for a in cfg["arenas"]:   # arena escolhida (de qualquer modo: Oficina e testes podem pedir qualquer uma)
			if a["id"] == choice:
				return a
	var opts := list.filter(func(a): return a["id"] != last_arena)
	if opts.is_empty():
		opts = list
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
	sub = find_mode(main.game_mode)
	_reset_crown()
	lives.clear()
	for i in main.players.size():
		lives[i] = lives_setting if rule() == "derruba" else 1
	bomb_holder = -1
	bomb_next = 4.0
	bomb_pass_cd = 0.0
	items.clear()
	dynamites.clear()
	slings.clear()
	shocks.clear()
	ropes.clear()
	if tools == null or not is_instance_valid(tools):
		tools = Ferramentas.new()
		tools.setup(main, self)
		main.world.add_child(tools)
	main.world.move_child(tools, -1)   # por cima dos robôs
	tools.clear()
	booms.clear()
	item_t = 4.0
	banner = String(arena["nome"]).to_upper()
	banner_t = 2.2
	go_played = false
	Audio.play("contagem")
	var n: int = main.players.size()
	var spots: Array = cfg["spawns_by_players"].get(str(n), [1, 2, 3, 4])
	main.start_run_at(spots)
	main.events.reset_round()
	for r in main.robots:
		r.hammer_left = 999
		r.facing = 1 if r.position.x < 960 else -1
	# ajuda para quem está perdendo: o único em último começa com capacete de aço
	if help_losers and main.round_no > 1:
		var low := 99999
		var who := []
		for i in main.players.size():
			var sc: int = int(main.players[i]["score"])
			if sc < low:
				low = sc
				who = [i]
			elif sc == low:
				who.append(i)
		if who.size() == 1 and who.size() < main.players.size():
			main.robots[who[0]].shield = 1

func update(dt: float) -> void:
	banner_t = maxf(banner_t - dt, 0.0)
	_update_fx(dt)
	main.events.update(dt)
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
			if a == b or b.stomp_immune > 0.0 or b.invuln > 0.0 or b.god:
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
					PlayerInput.vibrate(b.pid, 0.6, 0.3, 0.18)
					PlayerInput.vibrate(a.pid, 0.25, 0.0, 0.06)
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
		if r.is_on_floor() and rule() != "rei":   # no Rei da Obra o chão não racha por ficar parado (rodada longa)
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
	if rule() in ["batata", "rei", "fuga"] or main.sandbox:
		quake_at = 0.0   # a dinamite / o relógio do rei já garantem o fim da rodada
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
	tools.update(dt, alive)
	_update_water_and_nets(dt, alive)
	for f in feed:
		f["t"] += dt
	feed = feed.filter(func(f): return f["t"] < 4.5)
	_update_bomb(dt, alive)
	_update_mode_items(dt)
	var king_won := _update_king(dt, alive)
	# fim da rodada: sobrou 1 (ou ninguém)
	var over: bool = alive.size() <= 1 and main.robots.size() >= 2 and not main.sandbox
	if rule() == "rei":
		over = king_won >= 0 and not main.sandbox
		if over:
			alive = [main.robots[king_won]]
	if rule() == "fuga":
		for rf in main.robots:
			if rf.finished:   # chegou ao elevador: vence na hora
				over = true
				alive = [rf]
				break
	if main.end_delay < 0.0 and over:
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
		if items_on and items.size() < int(ic["max_on_map"]):
			var kinds: Array = sub.get("itens_lista", ic["kinds"])   # cada modo tem os seus itens
			spawn_item(kinds[main.rng.randi() % kinds.size()])
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
			it["vy"] = minf(it["vy"] + 900.0 * dt, 260.0)   # desce de paraquedas
			it["pos"].y += it["vy"] * dt
		elif lv.is_solid(cell) and it["pos"].y + 26.0 >= cell.y * 64.0:
			if it["vy"] > 0.0:
				it["land_t"] = 0.0
				main.dust(Vector2(it["pos"].x, cell.y * 64.0), 0.5)
				Audio.play("item", 0.7, -14.0)
			it["pos"].y = cell.y * 64.0 - 26.0
			it["vy"] = 0.0
			it["land_t"] = it.get("land_t", 9.0) + dt
		else:
			it["vy"] = minf(it["vy"] + 900.0 * dt, 260.0)   # desce de paraquedas
			it["pos"].y += it["vy"] * dt
		for r in alive:
			if r.rect().grow(6).has_point(it["pos"]):
				give(r, it["kind"])
				it["t"] = 999.0
				break
	items = items.filter(func(it): return it["t"] < float(ic["lifetime_s"]) and it["pos"].y < main.level.rows * 64.0 + 100.0)

## Parte do mapa em jogo: a tela, nos mapas com câmera que rola; senão, o mapa inteiro.
func play_rect() -> Rect2:
	if fx != null and is_instance_valid(fx) and fx.scroll_on:
		return Rect2(fx.scroll_center - Vector2(960, 512), Vector2(1920, 1024))
	return Rect2(0, 0, main.level.cols * 64.0, main.level.rows * 64.0)

## Item cai do céu numa coluna que ainda tem caixote (dentro da tela).
func spawn_item(kind: String, col := -1) -> void:
	var lv = main.level
	var pr := play_rect()
	if col < 0:
		var cols := []
		for cell in lv.blocks.keys():
			var cp := Vector2(cell * 64) + Vector2(32, 32)
			if pr.grow(-64).has_point(cp) and not (cell.x in cols):
				cols.append(cell.x)
		if cols.is_empty():
			return
		col = cols[main.rng.randi() % cols.size()]
	items.append({"kind": kind, "pos": Vector2(col * 64 + 32, maxf(70.0, pr.position.y + 70.0)), "vy": 0.0, "t": 0.0})   # abaixo do teto invisível

const ITEM_NAMES := {"dinamite": "TNT!", "martelao": "MARTELÃO!", "mola": "BOTAS DE MOLA!", "capacete": "CAPACETE!",
	"ima": "ÍMÃ!", "furadeira": "FURADEIRA!", "cola": "COLA!", "foguete": "BOTA-FOGUETE!",
	"teletransporte": "TELETRANSPORTE!", "laser": "RAIO LASER!", "vortice": "BOMBA DE VÓRTICE!", "soprador": "SOPRADOR!",
	"congelador": "RAIO CONGELANTE!", "estilingue": "ESTILINGUE!", "patins": "PATINS!", "escudo": "ESCUDO DE BORRACHA!",
	"choque": "ONDA DE CHOQUE!", "laco": "LAÇO!", "barreira": "BARREIRA!"}
const USABLE := ["dinamite", "furadeira", "cola", "teletransporte", "laser", "vortice", "soprador", "congelador",
	"estilingue", "choque", "laco", "barreira"]
var slings: Array = []       # Batata: dinamite arremessada com o estilingue {pos, vel, t, owner}
var shocks: Array = []       # Rei: onda de choque carregando {pid, t}
var ropes: Array = []        # laço desenhado {a, b, t}
const Ferramentas := preload("res://modes/ferramentas.gd")
var tools: Node2D = null     # furadeira, cola, teletransporte, laser, vórtice, soprador, congelador, ímã (modes/ferramentas.gd)

func give(r, kind: String) -> void:
	if not ITEM_NAMES.has(kind):
		push_warning("item desconhecido: %s" % kind)
		return
	match kind:
		"martelao", "mola", "ima", "foguete", "patins", "escudo": r.fx_t[kind] = float(item_cfg(kind)["duration_s"])
		"capacete": r.shield = int(item_cfg("capacete")["hits"])
		_: r.item = kind
	Audio.play({"martelao": "martelao", "ima": "ima", "foguete": "foguete"}.get(kind, "item"))
	var names := ITEM_NAMES
	main.float_text(r.position + Vector2(0, -110), names.get(kind, kind), main.player_color(r.pid))
	main.spark(r.rect().get_center(), 5)
	tools.pickup_fx(r, kind)

## Botão de item: usa o item guardado.
func use_item(r) -> void:
	var kind: String = r.item
	if kind in ["estilingue", "choque", "laco", "barreira"]:
		if _use_mode_item(r, kind):
			r.item = ""
		else:
			Audio.play("menu_negado", 1.0, -6.0)
		return
	if kind != "" and kind != "dinamite":
		r.item = ""
		if not tools.use(r, kind):
			r.item = kind   # não deu para usar aqui (ex.: tábua sem espaço): continua com ele
			Audio.play("menu_negado", 1.0, -6.0)
		return
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
		var hit: bool = d["t"] >= float(dc["fuse_s"]) or d["pos"].y > main.level.rows * 64.0 - 24.0
		if d["pos"].y > 0.0 and lv.is_solid(Vector2i(int(d["pos"].x / 64.0), int(d["pos"].y / 64.0))):
			hit = true
		for r in alive:
			if r.pid != d["owner"] and r.rect().grow(10).has_point(d["pos"]):
				hit = true
		if hit:
			explode(d["pos"], -1.0, int(d.get("owner", -1)))
			d["t"] = 999.0
	dynamites = dynamites.filter(func(d): return d["t"] < 999.0)

## Explosão: destrói caixotes no raio e lança os robôs para longe (TNT tem raio maior).
func explode(pos: Vector2, rad := -1.0, by := -1) -> void:
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
			r.take_hit(dir, "explosao", by if by != r.pid else -1)
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
	for sl in slings:
		canvas.draw_texture_rect(Data.tex("itens/dinamite"), Rect2(sl["pos"] - Vector2(18, 18), Vector2(36, 36)), false)
	for rp in ropes:
		canvas.draw_line(rp["a"], rp["b"], Color("#b07a3d"), 4.0, true)
		canvas.draw_arc(rp["b"], 12.0, 0, TAU, 14, Color("#b07a3d"), 3.0, true)
	for sh in shocks:
		if sh["pid"] < main.robots.size():
			var cc: Vector2 = main.robots[sh["pid"]].rect().get_center()
			var k: float = 1.0 - sh["t"] / float(item_cfg("choque")["espera_s"])
			canvas.draw_arc(cc, 30.0 + k * 40.0, 0, TAU, 32, Color(1.0, 0.85, 0.3, 0.4 + 0.5 * k), 4.0 + k * 4.0, true)
	for r in main.robots:
		if r.alive and r.fx_t["escudo"] > 0.0:
			canvas.draw_arc(r.rect().get_center(), 50.0, 0, TAU, 32, Color(0.35, 0.6, 1.0, 0.6), 4.0, true)
	if rule() == "rei":
		var cp := crown_pos
		var glow := 0.5 + 0.5 * sin(now * 6.0)
		canvas.draw_circle(cp, 40.0 + glow * 8.0, Color(1.0, 0.85, 0.3, 0.18 + glow * 0.12))
		if king < 0:
			cp.y += sin(now * 3.0) * 4.0 - 26.0
			canvas.draw_line(cp + Vector2(0, 30), Vector2(cp.x, crown_pos.y), Color(1, 0.9, 0.5, 0.4), 3.0)
		canvas.draw_texture_rect(Data.tex("itens/capacete"), Rect2(cp - Vector2(30, 30), Vector2(60, 60)), false, Color(1.0, 0.82, 0.25))
		for k in 3:
			var a2 := now * 2.0 + k * TAU / 3.0
			var sp := cp + Vector2(cos(a2) * 36.0, sin(a2) * 14.0 - 18.0)
			canvas.draw_circle(sp, 3.0, Color(1, 1, 0.8, 0.9))
	for it in items:
		var life: float = float(cfg["itens"]["lifetime_s"]) - it["t"]
		if life < 3.0 and fmod(now, 0.3) < 0.12:
			continue   # pisca antes de sumir
		var falling: bool = it["vy"] > 0.0
		var land: float = it.get("land_t", 9.0)
		var sq := 1.0
		if land < 0.35:   # quique ao pousar
			sq = 1.0 + sin(land / 0.35 * PI * 2.0) * 0.18 * (1.0 - land / 0.35)
		var p: Vector2 = it["pos"] + Vector2(0, (sin(now * 4.0 + it["pos"].x) * 4.0) if not falling else 0.0)
		if falling:
			# paraquedas de pano listrado
			var sway := sin(now * 3.0 + it["pos"].x) * 0.18
			canvas.draw_set_transform(p, sway)
			var dome := PackedVector2Array()
			for k in 13:
				dome.append(Vector2(cos(PI + k * PI / 12.0) * 42.0, -78.0 + sin(PI + k * PI / 12.0) * 26.0))
			dome.append(Vector2(42, -78))
			canvas.draw_colored_polygon(dome, Color("#f06aa8"))
			for k in [3, 6, 9]:
				var x := cos(PI + k * PI / 12.0) * 42.0
				canvas.draw_line(Vector2(x * 0.3, -104), Vector2(x, -78), Color("#fff7ee"), 6.0)
			for x in [-40.0, 0.0, 40.0]:
				canvas.draw_line(Vector2(x, -78), Vector2(0, -24), Color("#5a4632"), 1.6, true)
			canvas.draw_set_transform(Vector2.ZERO)
		# bolha com brilho, anel pulsando e estrelinha girando
		var pulse := 0.5 + 0.5 * sin(now * 5.0 + it["pos"].x)
		canvas.draw_set_transform(p, 0.0, Vector2(2.0 - sq, sq))
		canvas.draw_circle(Vector2.ZERO, 30, Color(1, 1, 1, 0.5))
		canvas.draw_arc(Vector2.ZERO, 30, 0, TAU, 32, Color(1, 1, 1, 0.95), 3.0, true)
		canvas.draw_arc(Vector2.ZERO, 34.0 + pulse * 6.0, 0, TAU, 32, Color(1, 0.96, 0.78, 0.5 * (1.0 - pulse)), 3.0, true)
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var ic: float = 1.0 + 0.08 * sin(now * 6.0 + it["pos"].x)
		canvas.draw_set_transform(p, sin(now * 2.5 + it["pos"].x) * 0.15, Vector2(ic * (2.0 - sq), ic * sq))
		canvas.draw_texture_rect(Data.tex("itens/" + it["kind"]), Rect2(-24, -24, 48, 48), false)
		canvas.draw_set_transform(Vector2.ZERO)
		canvas.draw_arc(p + Vector2(-10, -12), 12, PI * 1.05, PI * 1.45, 8, Color(1, 1, 1, 0.9), 3.0, true)
		var sp_ang: float = now * 2.0 + it["pos"].x
		var sp: Vector2 = p + Vector2.from_angle(sp_ang) * 34.0
		var s4 := 4.0 + 2.0 * sin(now * 9.0)
		canvas.draw_line(sp - Vector2(s4, 0), sp + Vector2(s4, 0), Color("#fff4c8"), 2.0, true)
		canvas.draw_line(sp - Vector2(0, s4), sp + Vector2(0, s4), Color("#fff4c8"), 2.0, true)
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
	# Batata-Dinamite: a dinamite acesa em cima da cabeça de quem está com ela + pavio
	if rule() == "batata" and bomb_holder >= 0 and bomb_holder < main.robots.size():
		var h = main.robots[bomb_holder]
		if h.alive:
			var hp: Vector2 = h.position + Vector2(0, -122 + sin(now * 10.0) * 3.0)
			var shake := Vector2(sin(now * 60.0), cos(now * 53.0)) * clampf(3.0 - bomb_fuse, 0.0, 3.0)
			canvas.draw_set_transform(hp + shake, sin(now * 6.0) * 0.25, Vector2(1.5, 1.5))
			canvas.draw_texture_rect(Data.tex("itens/dinamite"), Rect2(-16, -16, 32, 32), false)
			canvas.draw_set_transform(Vector2.ZERO)
			if fmod(now, 0.2) < 0.1:
				canvas.draw_circle(hp + shake + Vector2(14, -24), 7, Color("#fff4c8"))
			var col := Color("#d42035") if bomb_fuse < 3.0 else Color("#2a1a2e")
			Kit.text(canvas, hp + Vector2(-60, -34), "%d" % ceili(bomb_fuse), 34, col, HORIZONTAL_ALIGNMENT_CENTER, 120, 8, Color("#fff7ee"))

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
			PlayerInput.vibrate(r.pid, 0.3, 0.0, 0.07)   # quem acertou sente o golpe
			pass_bomb(r.pid, o.pid)
			Audio.play("bonk", 1.0 / mult)
			main.spark(o.rect().get_center(), 6)
			main.shake(5.0 * mult)
			hit_robot = true
	if fx != null and is_instance_valid(fx) and fx.hammer_hit(r, hit.grow(8)):
		hit_robot = true   # alavanca ou barril
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
	var pr := play_rect().grow_individual(-128, -192, -192, -64)
	for y in range(3, lv.rows - 1):
		for x in range(1, lv.cols - 1):
			var c := Vector2i(x, y)
			if lv.is_solid(c) and lv.ch_at(c) != "I" and not lv.is_solid(c + Vector2i.UP) and not lv.is_solid(c + Vector2i(0, -2)):
				var p := Vector2(x * 64 + 32, y * 64)
				if not pr.has_point(p) or not _firm(lv, c) or not (_firm(lv, c + Vector2i.LEFT) or _firm(lv, c + Vector2i.RIGHT)):
					continue   # só volta em bloco firme, com chão ao lado (nada de caixote solto rachando)
				var danger := false
				for h in lv.hazard_rects:
					if h.grow(96).has_point(p):
						danger = true
				if danger:
					continue
				if fx != null and is_instance_valid(fx) and fx.goo_on and p.y > fx.goo_y - 96.0:
					continue
				var dmin := 1e9
				for o in main.robots:
					if o != r and o.alive:
						dmin = minf(dmin, o.position.distance_to(p))
				dmin += main.rng.randf_range(0, 200)
				if rule() == "fuga":
					# Fuga: volta no ponto mais atrasado da tela (perde terreno, mas não sai)
					dmin = (-p.x if lv.cols > lv.rows * 2 else p.y) + main.rng.randf_range(0, 40)
				if dmin > best_d:
					best_d = dmin
					best = c
	if best.x < 0:
		# não sobrou chão firme: o guindaste traz um caixote novo e o robô volta em cima dele
		var spot: Vector2 = crown_home if rule() == "rei" else lv.spawns.get(r.pid % 4 + 1, Vector2(lv.cols * 32.0, 256.0))
		var cell := Vector2i(int(spot.x / 64.0), int(spot.y / 64.0))
		if not lv.is_solid(cell):
			lv.add_block(cell)
			if lv.blocks.has(cell):
				lv.blocks[cell]["hp"] = lv.block_hp
			main.dust(Vector2(cell * 64) + Vector2(32, 32), 1.0)
		r.position = Vector2(cell.x * 64 + 32, cell.y * 64 - 220)
		r.reset_physics_interpolation()
		r.velocity = Vector2.ZERO
		r.own_vx = 0.0
		r.stun_t = 0.0
		r.hanging = false
		r.invuln = float(cfg["recuperacao"]["invuln_volta_s"])
		r.drop_t = 1.0
		return
	r.position = Vector2(best.x * 64 + 32, best.y * 64 - 220)
	r.reset_physics_interpolation()
	r.velocity = Vector2.ZERO
	r.own_vx = 0.0
	r.stun_t = 0.0
	r.hanging = false
	r.invuln = float(cfg["recuperacao"]["invuln_volta_s"])
	r.drop_t = 1.0

## Chão firme para voltar: sólido fixo, ou caixote inteiro, sem aviso de queda e sem estar rachando.
func _firm(lv, c: Vector2i) -> bool:
	if not lv.is_solid(c) or lv.ch_at(c) in ["I", "T"]:
		return false
	if lv.blocks.has(c):
		var b: Dictionary = lv.blocks[c]
		return b["warn"] <= 0.0 and b["hp"] >= lv.block_hp and b["load"] < 0.5
	return true

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

## Alguém caiu (by = quem derrubou, -1 se ninguém).
func on_knockout(by: int, victim: int) -> void:
	if victim == bomb_holder:
		bomb_holder = -1
		bomb_next = 1.5

## Antes de eliminar: na Derruba, quem ainda tem vida volta pelo guindaste. true = não elimina.
func intercept_kill(r) -> bool:
	if main.sandbox:
		Audio.play("eliminado", 1.2, -4.0)
		main.dust(r.position + Vector2(0, -30), 1.2)
		r.dmg = 0.0
		respawn(r)
		return true   # na Oficina ninguém sai
	if rule() == "fuga":
		if r.caught:
			return false   # a tela (ou a lama) pegou: está fora
		main.float_text(r.position + Vector2(0, -90), "VOLTOU LÁ ATRÁS!", main.player_color(r.pid))
	elif rule() == "rei":
		if r.pid == king:
			_drop_crown(Vector2.ZERO, true)   # caiu com o capacete: ele volta para o trono
	elif rule() != "derruba":
		return false
	else:
		lives[r.pid] = lives.get(r.pid, 1) - 1
		if lives[r.pid] <= 0:
			return false
		main.float_text(r.position + Vector2(0, -90), "-1 VIDA", main.player_color(r.pid))
	Audio.play("eliminado", 1.2, -4.0)
	main.dust(r.position + Vector2(0, -30), 1.2)
	r.dmg = 0.0
	r.item = ""
	respawn(r)
	return true

## Rei da Obra: capacete de ouro no trono ("K" no mapa; sem K, no alto do centro).
func _reset_crown() -> void:
	king = -1
	king_time.clear()
	crown_cd.clear()
	king_hit.clear()
	var lv = main.level
	crown_home = (lv.throne if lv.throne != Vector2.INF else Vector2(lv.cols * 32.0, 3 * 64.0)) + Vector2(0, -4)
	crown_pos = crown_home
	crown_vel = Vector2.ZERO

func king_goal() -> float:
	return float(KING_GOALS[clampi(king_setting, 0, KING_GOALS.size() - 1)])

## O rei perde o capacete: ele voa (ou volta para o trono, se o rei caiu no poço).
func _drop_crown(vel: Vector2, home := false) -> void:
	if king >= 0 and king < main.robots.size():
		var kr = main.robots[king]
		kr.speed_k = 1.0
		crown_cd[king] = 1.0
		crown_pos = kr.rect().get_center() + Vector2(0, -40)
	king = -1
	crown_vel = vel
	if home:
		crown_pos = crown_home
		crown_vel = Vector2.ZERO
	Audio.play("bonk", 0.8)

## Devolve o vencedor quando alguém junta os segundos; senão -1.
func _update_king(dt: float, alive: Array) -> int:
	if rule() != "rei" or main.countdown > 0.0:
		return -1
	for k in crown_cd.keys():
		crown_cd[k] = maxf(crown_cd[k] - dt, 0.0)
	if king >= 0:
		var kr = main.robots[king]
		if not kr.alive:
			_drop_crown(Vector2.ZERO, true)
			return -1
		king_grace = maxf(king_grace - dt, 0.0)
		# levou golpe (marretada, pisão, explosão): o capacete voa para longe do golpe
		if king_grace <= 0.0 and kr.last_hit < float(king_hit.get(king, 99.0)) and kr.last_hit < 0.1:
			var away: float = -1.0 if kr.velocity.x < 0.0 else 1.0
			_drop_crown(Vector2(away * 260.0, -620.0))
			main.float_text(kr.position + Vector2(0, -110), "PERDEU A COROA!", main.player_color(kr.pid))
			return -1
		king_hit[king] = kr.last_hit
		kr.speed_k = float(sub.get("lento", 0.85))
		var before: float = king_time.get(king, 0.0)
		king_time[king] = before + dt
		if int(before) != int(king_time[king]) and int(king_time[king]) >= int(king_goal()) - 5:
			Audio.play("contagem", 1.2)
		crown_pos = kr.rect().get_center() + Vector2(0, -70)
		if king_time[king] >= king_goal():
			return king
		return -1
	# capacete solto: cai até o chão; quem encostar pega
	var lv = main.level
	crown_vel.y = minf(crown_vel.y + 1800.0 * dt, 900.0)
	crown_vel.x = move_toward(crown_vel.x, 0.0, 200.0 * dt)
	var np := crown_pos + crown_vel * dt
	var below := Vector2i(int(np.x / 64.0), int((np.y + 4.0) / 64.0))
	if crown_vel.y > 0.0 and lv.is_solid(below) and lv.ch_at(below) != "I":
		np.y = below.y * 64.0 - 4.0
		crown_vel = Vector2.ZERO
	if lv.is_solid(Vector2i(int(np.x / 64.0), int((np.y - 10.0) / 64.0))):
		crown_vel.x = -crown_vel.x * 0.5
		np.x = crown_pos.x
	crown_pos = np
	# caiu em espinho, água, lama ou no fundo do mapa: volta para o trono (senão ninguém consegue pegar)
	var here := Vector2i(int(crown_pos.x / 64.0), int((crown_pos.y + 8.0) / 64.0))
	var bad: bool = lv.ch_at(here) in ["^", "w"] or crown_pos.y >= (lv.rows - 1) * 64.0 - 2.0 \
		or crown_pos.x < 0.0 or crown_pos.x > lv.cols * 64.0
	for h in lv.hazard_rects:
		if h.grow(6).has_point(crown_pos):
			bad = true
	if fx != null and is_instance_valid(fx) and fx.goo_on and crown_pos.y > fx.goo_y - 10.0:
		bad = true
	if bad:
		crown_pos = crown_home
		crown_vel = Vector2.ZERO
		main.dust(crown_home, 0.8)
	for r in alive:
		if crown_cd.get(r.pid, 0.0) <= 0.0 and r.rect().grow(10).has_point(crown_pos):
			king = r.pid
			king_hit[king] = r.last_hit
			king_grace = float(sub.get("protecao_s", 1.2))
			banner = "P%d  É O REI DA OBRA!" % (r.pid + 1)
			banner_t = 1.4
			Audio.play("item")
			break
	return -1

## Batata-Dinamite (pavio, passar com a marreta, explosão).
func _update_bomb(dt: float, alive: Array) -> void:
	if rule() != "batata":
		return
	bomb_pass_cd = maxf(bomb_pass_cd - dt, 0.0)
	if bomb_holder < 0:
		bomb_next -= dt
		if bomb_next <= 0.0 and alive.size() > 1:
			var r = alive[main.rng.randi() % alive.size()]
			var pv: Array = FUSES[clampi(fuse_setting, 0, FUSES.size() - 1)]
			bomb_holder = r.pid
			bomb_fuse = main.rng.randf_range(float(pv[0]), float(pv[1]))
			banner = "P%d  ESTÁ COM A DINAMITE!" % (r.pid + 1)
			banner_t = 1.6
			Audio.play("arremesso")
		return
	var holder = main.robots[bomb_holder]
	if not holder.alive:
		bomb_holder = -1
		bomb_next = 1.5
		return
	# encostar no rival também passa a dinamite (com uma folguinha para não voltar na hora)
	if bomb_pass_cd <= 0.0:
		var hr: Rect2 = holder.rect()
		for o in alive:
			if o != holder and o.invuln <= 0.0 and hr.intersects(o.rect()):
				pass_bomb(holder.pid, o.pid)
				break
	bomb_fuse -= dt
	bomb_beep -= dt
	if bomb_beep <= 0.0:
		bomb_beep = clampf(bomb_fuse / 6.0, 0.12, 1.0)
		Audio.play("contagem", 1.0 + clampf(3.0 - bomb_fuse, 0.0, 3.0) * 0.15, -6.0)
	if bomb_fuse <= 0.0:
		var pos: Vector2 = holder.rect().get_center()
		holder.last_cause = "dinamite"
		holder.last_attacker = -1
		holder.last_hit = 0.0
		bomb_holder = -1
		bomb_next = 2.5
		explode(pos, float(sub["raio"]))
		main.kill(holder, -1, null)

## Itens próprios dos modos (Batata, Rei, Fuga). true = usou.
func _use_mode_item(r, kind: String) -> bool:
	var c: Vector2 = r.rect().get_center()
	match kind:
		"estilingue":   # só serve com a dinamite na mão: arremessa (se errar, ela volta para você)
			if r.pid != bomb_holder:
				return false
			var v: Array = item_cfg("estilingue")["vel"]
			slings.append({"pos": c + Vector2(r.facing * 24, -10), "vel": Vector2(r.facing * float(v[0]), -float(v[1])), "t": 0.0, "owner": r.pid})
			Audio.play("arremesso", 1.2)
			r.vis.stretch()
			return true
		"choque":   # fica intocável um instante e depois joga todo mundo longe
			var wait := float(item_cfg("choque")["espera_s"])
			r.invuln = wait + 0.2
			if king == r.pid:
				king_grace = wait + 0.2
			shocks.append({"pid": r.pid, "t": wait})
			Audio.play("laser_carga", 0.8)
			return true
		"laco":   # puxa o primeiro rival à frente; se for o rei, o capacete vem voando
			var reach := float(item_cfg("laco")["alcance_px"])
			var best = null
			var bd := 1e9
			for o in main.robots:
				if o != r and o.alive:
					var oc: Vector2 = o.rect().get_center()
					var dx: float = (oc.x - c.x) * r.facing
					if dx > 0.0 and dx < reach and absf(oc.y - c.y) < 80.0 and dx < bd:
						bd = dx
						best = o
			var tip: Vector2 = c + Vector2(r.facing * (bd if best != null else reach), 0)
			ropes.append({"a": c, "b": tip, "t": 0.0})
			Audio.play("gancho")
			if best != null:
				if best.pid == king:
					_drop_crown(((c - best.rect().get_center()).normalized() * 560.0) + Vector2(0, -420))
				best.knock(-r.facing, 620.0, 260.0, 0.45)
			return true
		"barreira":   # muro de 2 caixotes atrás de você
			var lv = main.level
			var bx := int((r.position.x - r.facing * 100.0) / 64.0)
			var by := int((r.position.y - 4.0) / 64.0)
			var made := false
			for k in int(item_cfg("barreira")["altura"]):
				if lv.add_block(Vector2i(bx, by - k)):
					lv.blocks[Vector2i(bx, by - k)]["hp"] = lv.block_hp
					made = true
			if made:
				main.dust(Vector2(bx * 64 + 32, by * 64), 1.0)
				Audio.play("caixote_pancada", 0.8)
			return made
	return false

## Estilingue de TNT voando, onda de choque carregando, laço desenhado.
func _update_mode_items(dt: float) -> void:
	for sl in slings:
		sl["t"] += dt
		sl["vel"].y += 1500.0 * dt
		sl["pos"] += sl["vel"] * dt
		for o in main.robots:
			if o.alive and o.pid != sl["owner"] and o.rect().grow(8).has_point(sl["pos"]) and o.fx_t["escudo"] <= 0.0:
				bomb_holder = o.pid
				bomb_pass_cd = 0.8
				main.float_text(o.position + Vector2(0, -110), "TOMA!", main.player_color(sl["owner"]))
				Audio.play("bonk")
				sl["dead"] = true
				break
		var cell := Vector2i(int(sl["pos"].x / 64.0), int(sl["pos"].y / 64.0))
		if not sl.get("dead", false) and (sl["t"] > 1.4 or main.level.is_solid(cell)):
			sl["dead"] = true
			if sl["owner"] < main.robots.size() and main.robots[sl["owner"]].alive:
				main.float_text(main.robots[sl["owner"]].position + Vector2(0, -110), "ERROU!", main.player_color(sl["owner"]))
	slings = slings.filter(func(x): return not x.get("dead", false))
	for sh in shocks:
		sh["t"] -= dt
		if sh["t"] <= 0.0 and sh["pid"] < main.robots.size():
			var me = main.robots[sh["pid"]]
			var c0: Vector2 = me.rect().get_center()
			var rad := float(item_cfg("choque")["raio_px"])
			for o in main.robots:
				if o != me and o.alive and o.rect().get_center().distance_to(c0) < rad:
					o.take_hit(1 if o.rect().get_center().x >= c0.x else -1, "choque", me.pid)
			booms.append({"pos": c0, "t": 0.0})
			main.shake(10.0)
			Audio.play("explosao", 1.3, -4.0)
	shocks = shocks.filter(func(x): return x["t"] > 0.0)
	for rp in ropes:
		rp["t"] += dt
	ropes = ropes.filter(func(x): return x["t"] < 0.3)

## Batata: a marretada passa a dinamite para quem levou o golpe.
func pass_bomb(from_pid: int, to_pid: int) -> void:
	if rule() != "batata" or from_pid != bomb_holder or bomb_pass_cd > 0.0:
		return
	if to_pid < main.robots.size() and main.robots[to_pid].fx_t["escudo"] > 0.0:
		main.float_text(main.robots[to_pid].position + Vector2(0, -110), "ESCUDO!", main.player_color(to_pid))
		bomb_pass_cd = 0.4
		return
	bomb_holder = to_pid
	bomb_pass_cd = 0.8
	main.float_text(main.robots[to_pid].position + Vector2(0, -110), "TOMA!", main.player_color(from_pid))
	Audio.play("arremesso", 1.3)

## Fim da rodada: estrela para o vencedor; partida acaba em rounds_to_win.
func end_round() -> bool:
	if round_winner >= 0:
		main.players[round_winner]["score"] += 1
	return round_winner >= 0 and main.players[round_winner]["score"] >= int(c("rounds_to_win"))
