extends Node2D
## SPELLS (Relatório 04): 1 slot por robô, caixa com a FAMÍLIA visível (a spell só aparece ao pegar), troca voluntária
## (segurar o botão de especial ~0,3 s sobre a caixa: o item antigo cai no chão para outro pegar), limpeza na eliminação,
## sorteio em 2 etapas (família → spell) com raridade e sem ajuda a quem perde. Números: data/modos.json → demolicao.spells.
## Etapa 1: S01 Punho Pneumático, S03 Canhão Criogênico, S06 Superímã, S10 Andaime Relâmpago, S11 Teleporte, S13 Armadura Fornalha.

const T := 64.0
const Kit := preload("res://ui/kit.gd")
const RobotVis := preload("res://player/robot_visual.gd")
const FAM_COR := {"ataque": Color("#f08a3d"), "controle": Color("#8a63d2"), "engenharia": Color("#f2c84b"), "transformacao": Color("#3fc1c9")}
const NOMES := {"S01": "PUNHO PNEUMÁTICO", "S03": "CANHÃO CRIOGÊNICO", "S06": "SUPERÍMÃ", "S10": "ANDAIME RELÂMPAGO",
	"S11": "TELEPORTE", "S13": "ARMADURA FORNALHA", "S02": "LASER DE CORTE", "S04": "MARRETA SÍSMICA", "S05": "REBITEIRA RICOCHETE",
	"S17": "BATE-ESTACA", "S18": "DISCO DE CORTE", "S19": "MARRETA-BUMERANGUE", "S20": "CANHÃO DE MOLAS"}

var main: Node
var demo: Node
var cfg: Dictionary
var boxes: Array = []        # {fam, id, charges, pos, vy, t, land_t, block: {pid: s}, special}
var slot := {}               # pid -> {id, fam, charges, cd, prep, prep_len, fire, t, data}
var holds := {}              # pid -> {box, t}
var shots: Array = []        # S03 {pos, vel, owner, t}
var frozen := {}             # S03: pid -> {len, age, shake, last_ax}
var shards: Array = []       # S03: lascas de gelo voando {pos, vel, rot, spin, t, size}
var platforms: Array = []    # S10 {rect, body, t, len, owner, k, from, leg}
var fists: Array = []        # S01 {owner, t, reach, dir, hit, wall}
var aims := {}               # S11: pid -> {pos, t, ok}
var teles: Array = []        # S11 {pid, a, b, t, moved}
var flames := {}             # S13: pid -> {k, hitcd: {oid: s}}
var bot_hold := {}           # bots "seguram" o botão por um tempo
var lasers: Array = []       # S02 {owner, t, a, b}
var scorch: Array = []       # S02 marcas de solda {pos, t}
var waves: Array = []        # S04 {owner, x0, y, l_end, r_end, t, hit}
var rivets: Array = []       # S05 {owner, pos, vel, bounces, t, hit, trail}
var piles: Array = []        # S17 {owner, x, floor_y, t, hit, done}
var discs: Array = []        # S18 {owner, pos, vel, phase, t, hit, rot, x0}
var hammers: Array = []      # S19 {owner, pos, vel, phase, t, hit, rot}
var springs: Array = []      # S20 {owner, pos, vel, t, sq}
var feedback: Array = []     # {pos, text, t}
var spawn_t := 0.0
var recent: Array = []
var draw_log: Array = []     # sorteios (testes): {fam, id}
var t := 0.0
var ghost: Node2D = null     # S11: silhueta holográfica no destino (desenhada com transparência)

func setup(m: Node, d: Node) -> void:
	main = m
	demo = d
	ghost = Node2D.new()
	ghost.draw.connect(_draw_ghost)
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.72, 0.6, 1.0, 0.6);
void fragment() {
	float scan = 0.55 + 0.45 * step(0.5, fract(FRAGCOORD.y / 5.0));
	COLOR = vec4(tint.rgb, COLOR.a * tint.a * scan);
}"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	ghost.material = mat
	add_child(ghost)
	cfg = d.cfg["spells"]
	var c: Dictionary = cfg["caixa"]
	spawn_t = main.rng.randf_range(float(c["primeira_s"][0]), float(c["primeira_s"][1]))

func sc(id: String) -> Dictionary:
	return cfg[id]

func pool() -> Array:
	return cfg["pools"].get(main.game_mode, cfg["pools"]["derruba"])

# ---------------------------------------------------------------- sorteio e caixas
## Sorteio em 2 etapas: família (peso) → spell da família (raridade, menos chance de repetir as últimas). Neutro para todos.
func pick() -> Dictionary:
	var fams := {}
	for id in pool():
		fams[sc(id)["familia"]] = true
	var tot := 0.0
	for f in fams:
		tot += float(cfg["familias"][f]["peso"])
	var r: float = main.rng.randf() * tot
	var fam: String = fams.keys()[0]
	for f in fams:
		r -= float(cfg["familias"][f]["peso"])
		if r <= 0.0:
			fam = f
			break
	var cand := []
	var wsum := 0.0
	for id in pool():
		if sc(id)["familia"] != fam:
			continue
		var w := float(cfg["raridade"][sc(id)["raridade"]]) * (0.35 if id in recent else 1.0)
		cand.append([id, w])
		wsum += w
	var x: float = main.rng.randf() * wsum
	var pick_id: String = cand[0][0]
	for cw in cand:
		x -= cw[1]
		if x <= 0.0:
			pick_id = cw[0]
			break
	recent.append(pick_id)
	if recent.size() > 3:
		recent.pop_front()
	draw_log.append({"fam": fam, "id": pick_id})
	return {"fam": fam, "id": pick_id}

## Pontos de caixa: parte FIXA (centro do núcleo, andaimes) e parte VARIÁVEL (qualquer trecho firme), só onde não vai cair.
func spawn_points() -> Array:
	var out := []
	var ct = demo.canteiro
	if ct != null and is_instance_valid(ct):
		for p in ct.parts:
			if p["fallen"] or p["warn_t"] > 0.0 or p["crit_t"] > 0.0 or p["state"] == 2:
				continue
			var r: Rect2 = p["rect"]
			var fixed: bool = p["nucleo"] or p["kind"] == "andaime"
			out.append({"pos": Vector2(r.get_center().x, r.position.y), "fixo": fixed})
			out.append({"pos": Vector2(main.rng.randf_range(r.position.x + 40, r.end.x - 40), r.position.y), "fixo": false})
		return out
	var lv = main.level
	var pr: Rect2 = demo.play_rect().grow(-96)
	for y in range(3, lv.rows - 1):
		for x in range(1, lv.cols - 1):
			var c := Vector2i(x, y)
			if lv.is_solid(c) and not lv.is_solid(c + Vector2i.UP) and not lv.is_solid(c + Vector2i(0, -2)) and not (lv.ch_at(c) in ["^", "I"]):
				var p := Vector2(x * T + 32, y * T)
				if pr.has_point(p):
					out.append({"pos": p, "fixo": false})
	return out

func spawn_box(at = null, special := false) -> void:
	var pts := spawn_points()
	if pts.is_empty() and at == null:
		return
	var p: Vector2
	if at != null:
		p = at
	else:
		var fixed := pts.filter(func(q): return q["fixo"])
		var src: Array = fixed if (not fixed.is_empty() and main.rng.randf() < 0.5) else pts
		p = src[main.rng.randi() % src.size()]["pos"]
	var k := pick()
	boxes.append({"fam": k["fam"], "id": k["id"], "charges": -1, "pos": Vector2(p.x, demo.play_rect().position.y - 60.0),
		"vy": 0.0, "t": 0.0, "land_t": 9.0, "block": {}, "special": special})
	Audio.play("item", 0.8, -6.0)

## Laboratório: caixa de uma spell escolhida caindo do céu em x.
func drop_box(id: String, at: Vector2, from_sky := true) -> void:
	boxes.append({"fam": sc(id)["familia"], "id": id, "charges": -1, "pos": Vector2(at.x, demo.play_rect().position.y - 60.0) if from_sky else at,
		"vy": 0.0, "t": 0.0, "land_t": 9.0, "block": {}, "special": false})

func _update_boxes(dt: float, alive: Array) -> void:
	var c: Dictionary = cfg["caixa"]
	spawn_t -= dt
	if spawn_t <= 0.0:
		spawn_t = main.rng.randf_range(float(c["intervalo_s"][0]), float(c["intervalo_s"][1]))
		if demo.items_on and boxes.size() < int(c["max_mapa"]):
			spawn_box()
	var lv = main.level
	for b in boxes:
		b["t"] += dt
		b["land_t"] += dt
		for pid in b["block"].keys():
			b["block"][pid] -= dt
			if b["block"][pid] <= 0.0:
				b["block"].erase(pid)
		var cell := Vector2i(int(b["pos"].x / T), int(floor((b["pos"].y + 30.0) / T)))
		if lv.is_solid(cell) and b["pos"].y + 30.0 >= cell.y * T and b["vy"] >= 0.0:
			if b["vy"] > 60.0:
				b["land_t"] = 0.0
				main.dust(Vector2(b["pos"].x, cell.y * T), 0.6)
				Audio.play("caixote_pancada", 1.3, -10.0)
			b["pos"].y = cell.y * T - 30.0
			b["vy"] = 0.0
		else:
			var vmax := 220.0 if b["special"] else 900.0   # cápsula especial desce de paraquedas
			b["vy"] = minf(b["vy"] + 1800.0 * dt, vmax)
			b["pos"].y += b["vy"] * dt
	var life := float(c["vida_s"])
	boxes = boxes.filter(func(b): return b["t"] < life and b["pos"].y < lv.rows * T + 200.0)
	# coleta por contato (slot vazio); o mais perto da caixa leva, só um por caixa
	for b in boxes.duplicate():
		var br := Rect2(b["pos"] - Vector2(34, 34), Vector2(68, 64))
		var best = null
		var bd := 1e9
		for r in alive:
			if slot.has(r.pid) or b["block"].has(r.pid) or not br.intersects(r.rect()):
				continue
			var d: float = r.rect().get_center().distance_to(b["pos"])
			if d < bd:
				bd = d
				best = r
		if best != null:
			boxes.erase(b)
			equip(best, b["id"], b["charges"], float(b.get("energy", -1.0)))

# ---------------------------------------------------------------- slot
func equip(r, id: String, charges := -1, energy := -1.0) -> void:
	var s: Dictionary = sc(id)
	slot[r.pid] = {"id": id, "fam": s["familia"], "charges": int(s["cargas"]) if charges < 0 else charges, "cd": 0.0,
		"prep": -1.0, "prep_len": 0.0, "fire": -1.0, "t": -1.0, "channel": false,
		"energy": energy if energy >= 0.0 else float(s.get("energia_s", s.get("combustivel_s", 0.0))), "data": {}}
	main.float_text(r.position + Vector2(0, -130), NOMES.get(id, id) + "!", FAM_COR[s["familia"]])
	Audio.play("item", 1.2)
	r.vis.s_sqy[0] = 1.18   # pulinho de alegria
	r.vis.s_sqx[0] = 0.86

## Elimina/limpa: fim de transformação, sem guardar nada para o respawn.
func clear(r) -> void:
	for h in hammers.duplicate():   # a marreta-bumerangue volta na hora
		if h["owner"] == r.pid:
			hammers.erase(h)
			r.hammer_out = false
	discs = discs.filter(func(d): return d["owner"] != r.pid)
	if slot.has(r.pid) and slot[r.pid]["id"] == "S13" and slot[r.pid]["t"] > 0.0:
		_end_armor(r, false)
	_stop_channel(r)
	slot.erase(r.pid)
	holds.erase(r.pid)
	aims.erase(r.pid)
	flames.erase(r.pid)
	r.spell_lock = false
	if is_instance_valid(r.vis):
		r.vis.visible = true

func has_spell(r) -> bool:
	return slot.has(r.pid)

func _is_bot(pid: int) -> bool:
	return pid < main.players.size() and main.players[pid].get("bot", false)

## Botão de especial está seguro? (bots seguram por um tempo fixo)
func held(r) -> bool:
	return PlayerInput.held(r.pid, "item") or float(bot_hold.get(r.pid, 0.0)) > 0.0

## Botão de especial apertado (borda). Em cima de uma caixa com o slot ocupado: começa a TROCA (segurar);
## soltar antes do tempo usa a spell atual (toque rápido continua valendo).
func press(r) -> void:
	if not slot.has(r.pid):
		return
	var b = _box_under(r)
	if b != null:
		holds[r.pid] = {"box": b, "t": 0.0}
		return
	use(r)

func _box_under(r):
	for b in boxes:
		if not b["block"].has(r.pid) and Rect2(b["pos"] - Vector2(34, 34), Vector2(68, 64)).intersects(r.rect()):
			return b
	return null

func _update_holds(dt: float) -> void:
	for pid in holds.keys():
		var h: Dictionary = holds[pid]
		var r = main.robots[pid] if pid < main.robots.size() else null
		if r == null or not r.alive or not (h["box"] in boxes) or not Rect2(h["box"]["pos"] - Vector2(34, 34), Vector2(68, 64)).intersects(r.rect()):
			holds.erase(pid)
			continue
		if PlayerInput.held(pid, "item"):
			h["t"] += dt
			if h["t"] >= float(cfg["caixa"]["troca_s"]):
				_swap(r, h["box"])
				holds.erase(pid)
		else:
			holds.erase(pid)
			use(r)   # foi um toque: usa a spell

func _swap(r, b: Dictionary) -> void:
	var old: Dictionary = slot[r.pid]
	if old["id"] == "S13" and old["t"] > 0.0:
		_end_armor(r, false)   # troca encerra a transformação
	_stop_channel(r)
	aims.erase(r.pid)
	r.spell_lock = false
	# o antigo cai no chão (com as cargas/energia que sobraram) e o dono não pega de volta na hora
	var drop := {"fam": old["fam"], "id": old["id"], "charges": old["charges"], "energy": old["energy"],
		"pos": r.position + Vector2(-r.facing * 50.0, -40.0), "vy": -260.0, "t": 0.0, "land_t": 9.0,
		"block": {r.pid: float(cfg["caixa"]["anti_recaptura_s"])}, "special": false}
	boxes.erase(b)
	boxes.append(drop)
	slot.erase(r.pid)
	equip(r, b["id"], b["charges"], float(b.get("energy", -1.0)))
	Audio.play("alavanca", 1.2)

func _spend(r, s: Dictionary) -> void:
	s["charges"] -= 1
	if s["charges"] <= 0:
		s["empty_t"] = 0.35   # some do slot depois da animação de recolher

func _fail(r, text: String) -> void:
	feedback.append({"pos": r.position + Vector2(0, -120), "text": text, "t": 0.0})
	Audio.play("menu_negado", 1.0, -6.0)

## Mão da frente no mundo (de onde saem punho, tiro e ímã).
func hand(r) -> Vector2:
	return r.position + Vector2(r.facing * 32.0, -40.0)

# ---------------------------------------------------------------- usar
func use(r) -> void:
	var s: Dictionary = slot[r.pid]
	if s["cd"] > 0.0 or s["prep"] >= 0.0 or s.has("empty_t") or s["channel"]:
		return
	var c: Dictionary = sc(s["id"])
	match s["id"]:
		"S01", "S03", "S02", "S20":
			s["prep"] = 0.0
			s["prep_len"] = float(c["preparo"])
			Audio.play({"S01": "pistao_aviso", "S03": "gelo", "S02": "laser_carga", "S20": "pulo_mola"}[s["id"]], 1.3 if s["id"] != "S20" else 0.6, -4.0)
		"S04":   # só apoiado no chão (no ar avisa e não gasta)
			if not r.is_on_floor():
				_fail(r, "SÓ NO CHÃO")
				return
			s["prep"] = 0.0
			s["prep_len"] = float(c["preparo"])
			Audio.play("marreta_vento", 0.7, -2.0)
		"S05":
			_fire_rivet(r, s)
		"S17":
			_drop_pile(r, s)
		"S18":
			for d in discs:
				if d["owner"] == r.pid:
					return   # um disco por vez
			_throw_disc(r, s)
		"S19":
			if r.hammer_out:
				return
			_throw_hammer(r, s)
		"S06":   # segura: o ímã liga e vai gastando a barra
			s["channel"] = true
			if _is_bot(r.pid):
				bot_hold[r.pid] = s["energy"]
			Audio.play("ima", 0.8, 0.0)
		"S10":
			var pr := scaffold_rect(r)
			if not scaffold_ok(r, pr):
				_fail(r, "SEM ESPAÇO")
				return
			_build_scaffold(r, pr)
			s["fire"] = 0.0
			_spend(r, s)
		"S11":
			if _is_bot(r.pid):   # bot: vai direto para a frente (ou para cima, caindo)
				var dest = teleport_dest(r)
				if dest == null:
					return
				_teleport(r, dest)
				_spend(r, s)
				return
			s["channel"] = true   # segura: mira com o direcional, solta para ir
			var start: Vector2 = r.position + Vector2(r.facing * 3.0 * T, 0)
			aims[r.pid] = {"pos": start, "t": 0.0, "ok": _free_at(start)}
			r.spell_lock = true
			Audio.play("teleporte", 0.7, -8.0)
		"S13":
			if s["t"] < 0.0:
				_start_armor(r, s)
			else:
				s["channel"] = true   # segura: jato de fogo contínuo
				if _is_bot(r.pid):
					bot_hold[r.pid] = 0.9
				flames[r.pid] = flames.get(r.pid, {"k": 0.0, "hitcd": {}})

func _stop_channel(r) -> void:
	if not slot.has(r.pid):
		return
	var s: Dictionary = slot[r.pid]
	s["channel"] = false
	if s["id"] == "S06":
		r.spell_speed = 1.0
	elif s["id"] == "S13" and s["t"] > 0.0:
		r.spell_speed = float(sc("S13")["vel_mult"])

func _fire(r, s: Dictionary) -> void:
	var c: Dictionary = sc(s["id"])
	s["fire"] = 0.0
	s["cd"] = float(c.get("intervalo_s", 0.3))
	if s["id"] in ["S02", "S04", "S20"]:
		_fire2(r, s)
		return
	if s["id"] == "S01":
		# braço de tesoura estica numa linha reta até bater em parede; acerta todos os alinhados (1 vez cada)
		var h := hand(r)
		var maxd := float(c["alcance_tiles"]) * T
		var d := 0.0
		while d < maxd:
			var nx: Vector2 = h + Vector2(r.facing * (d + 12.0), 0)
			if main.level.is_solid(Vector2i(int(floor(nx.x / T)), int(floor(nx.y / T)))):
				break
			d += 12.0
		fists.append({"owner": r.pid, "t": 0.0, "reach": maxf(d, 40.0), "dir": r.facing, "hit": [], "wall": d < maxd - 12.0, "impact": -1.0})
		Audio.play("arremesso", 0.7, 2.0)
		Audio.play("pistao", 1.3, -2.0)
		r.own_vx -= r.facing * 160.0   # coice
		main.shake(4.0)
		_spend(r, s)
	elif s["id"] == "S03":
		shots.append({"pos": hand(r) + Vector2(r.facing * 20.0, 0), "vel": Vector2(r.facing * float(c["vel"]), 0), "owner": r.pid, "t": 0.0})
		Audio.play("gelo", 1.6, -2.0)
		r.own_vx -= r.facing * 140.0   # coice
		for k in 6:
			main.spark(hand(r) + Vector2(r.facing * 24.0, 0), 1)
		_spend(r, s)

## S10: onde o andaime vai aparecer. No chão: 2 tiles à frente, 2 tiles acima dos pés (degrau);
## no ar: logo embaixo dos pés (salvamento).
func scaffold_rect(r) -> Rect2:
	var w := float(sc("S10")["largura_tiles"]) * T
	if r.is_on_floor():
		var cx: float = r.position.x + r.facing * 2.4 * T
		return Rect2(cx - w / 2.0, r.position.y - 2.0 * T, w, 20)
	return Rect2(r.position.x - w / 2.0, r.position.y + 30.0, w, 20)

func scaffold_ok(r, pr: Rect2) -> bool:
	var ko: Rect2 = main.level.ko_rect()
	if ko.has_area() and not ko.grow(-96).encloses(pr):
		return false
	for x in range(int(floor(pr.position.x / T)), int(floor(pr.end.x / T)) + 1):
		if main.level.is_solid(Vector2i(x, int(floor((pr.position.y + 10.0) / T)))):
			return false
	for o in main.robots:
		if o.alive and o.rect().intersects(pr.grow(-4)):
			return false
	return true

## Altura das pernas do andaime: até o chão (máx. 3 tiles); sem chão, pernas curtas penduradas.
func _leg_len(pr: Rect2) -> float:
	var y0 := pr.position.y + 22.0
	for k in 48:
		var yy := y0 + k * 4.0
		var hit := false
		for xx in [pr.position.x + 26.0, pr.end.x - 26.0]:
			if main.level.is_solid(Vector2i(int(floor(xx / T)), int(floor(yy / T)))):
				hit = true
		if hit:
			return yy - y0
	return 34.0

func _build_scaffold(r, pr: Rect2) -> void:
	var c: Dictionary = sc("S10")
	for p in platforms.duplicate():
		if p["owner"] == r.pid:
			_remove_platform(p)   # 1 por jogador: o antigo dobra
	var body := StaticBody2D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shp := RectangleShape2D.new()
	shp.size = pr.size
	cs.shape = shp
	cs.position = pr.get_center()
	cs.one_way_collision = true
	body.add_child(cs)
	add_child(body)
	platforms.append({"rect": pr, "body": body, "t": float(c["duracao_s"]), "len": float(c["duracao_s"]), "owner": r.pid,
		"k": 0.0, "from": hand(r), "leg": _leg_len(pr), "landed": false})
	Audio.play("arremesso", 1.4, -4.0)

func _remove_platform(p: Dictionary) -> void:
	if is_instance_valid(p["body"]):
		p["body"].queue_free()
	platforms.erase(p)
	main.dust(p["rect"].get_center(), 0.7)

## S11 (bot / teste): destino à frente (ou ▲ para cima); tenta mais perto se o ponto estiver ocupado. null = nada livre.
func teleport_dest(r):
	var c: Dictionary = sc("S11")
	var up: bool = PlayerInput.held(r.pid, "up") or (not r.is_on_floor() and r.velocity.y > 200.0)
	for k in [0.7, 0.55, 0.4]:
		var d: float = float(c["alcance_tiles"]) * T * k
		var dest: Vector2 = r.position + (Vector2(0, -d) if up else Vector2(r.facing * d, 0))
		if _free_at(dest):
			return dest
	return null

func _free_at(feet: Vector2) -> bool:
	var ko: Rect2 = main.level.ko_rect()
	if ko.has_area() and not ko.grow(-128).has_point(feet):
		return false
	for xx in [feet.x - 22.0, feet.x + 22.0]:
		for yy in [feet.y - 4.0, feet.y - 36.0, feet.y - 68.0]:
			if main.level.is_solid(Vector2i(int(floor(xx / T)), int(floor(yy / T)))):
				return false
	return true

## Teletransporte: o robô vira um fio de luz, some, e se remonta no destino.
func _teleport(r, dest: Vector2) -> void:
	teles.append({"pid": r.pid, "a": r.position, "b": dest, "t": 0.0, "moved": false})
	r.spell_lock = true
	r.vis.s_sqx[0] = 0.15   # afina até virar um fio
	r.vis.s_sqy[0] = 1.5
	Audio.play("teleporte", 1.2, -1.0)

func _update_aims(dt: float) -> void:
	var c: Dictionary = sc("S11")
	for pid in aims.keys():
		var r = main.robots[pid]
		var a: Dictionary = aims[pid]
		a["t"] += dt
		var dir := Vector2(PlayerInput.axis_x(pid), 0)
		if PlayerInput.held(pid, "up"):
			dir.y -= 1.0
		if PlayerInput.held(pid, "down"):
			dir.y += 1.0
		if dir.length() > 0.2:
			a["pos"] += dir.normalized() * float(c["mira_vel"]) * dt
		var off: Vector2 = a["pos"] - r.position
		var maxd := float(c["alcance_tiles"]) * T
		if off.length() > maxd:
			a["pos"] = r.position + off.normalized() * maxd
		a["ok"] = _free_at(a["pos"])
		# mirando: o robô para (no ar, cai devagar)
		r.own_vx *= 0.8
		r.velocity.y = minf(r.velocity.y, 70.0)
		if not held(r) or a["t"] >= float(c["mira_max_s"]):
			aims.erase(pid)
			var s: Dictionary = slot[pid]
			s["channel"] = false
			if a["ok"]:
				_teleport(r, a["pos"])
				s["fire"] = 0.0
				_spend(r, s)
			else:
				r.spell_lock = false
				_fail(r, "DESTINO BLOQUEADO")

func _update_teles(dt: float) -> void:
	for e in teles:
		e["t"] += dt
		var r = main.robots[e["pid"]]
		r.velocity = Vector2.ZERO
		r.own_vx = 0.0
		if e["t"] >= 0.07 and not e["moved"]:
			e["moved"] = true
			r.position = e["b"]
			r.reset_physics_interpolation()
			r.vis.visible = false
			for k in 8:
				main.spark(e["a"] + Vector2(randf_range(-14, 14), randf_range(-80, 0)), 1)
		if e["t"] >= 0.15 and not r.vis.visible:
			r.vis.visible = true
			r.vis.s_sqx[0] = 0.2   # se remonta: fio que engorda e assenta na mola
			r.vis.s_sqy[0] = 1.55
			main.dust(e["b"], 0.6)
		if e["t"] >= 0.26:
			r.spell_lock = false
			r.atk_cd = maxf(r.atk_cd, float(sc("S11")["recupera_s"]))
	teles = teles.filter(func(e): return e["t"] < 0.26)

# ---------------------------------------------------------------- S03: congelado
func freeze(o, by: int) -> void:
	var c: Dictionary = sc("S03")
	o.frozen_t = float(c["congela_s"])
	o.hanging = false
	o.own_vx *= 0.25
	o.last_attacker = by
	o.last_hit = 0.0
	o.last_cause = "congelado"
	frozen[o.pid] = {"len": o.frozen_t, "age": 0.0, "shake": 0.0, "last_ax": 0}
	main.float_text(o.position + Vector2(0, -120), "CONGELOU!", Color("#8fd3f0"))
	Audio.play("gelo", 0.8, 2.0)

## O gelo estilhaça (soltou sozinho, agitou até quebrar ou levou pancada).
func shatter(o) -> void:
	var c: Vector2 = o.rect().get_center()
	Audio.play("gelo_quebra")
	for k in 18:
		var a := randf_range(-PI, 0.0)
		shards.append({"pos": c + Vector2(randf_range(-24, 24), randf_range(-36, 30)), "vel": Vector2.from_angle(a) * randf_range(180, 520) + Vector2(0, -80),
			"rot": randf() * TAU, "spin": randf_range(-14, 14), "t": 0.0, "size": randf_range(6, 15)})
	frozen.erase(o.pid)
	o.frozen_t = 0.0

func _update_frozen(dt: float) -> void:
	var c: Dictionary = sc("S03")
	for o in main.robots:
		if o.frozen_t <= 0.0:
			if frozen.has(o.pid):
				frozen.erase(o.pid)
			continue
		if not o.alive:
			o.frozen_t = 0.0
			continue
		if not frozen.has(o.pid):
			frozen[o.pid] = {"len": o.frozen_t, "age": 0.0, "shake": 0.0, "last_ax": 0}
		var f: Dictionary = frozen[o.pid]
		f["age"] += dt
		f["shake"] = maxf(f["shake"] - dt * 6.0, 0.0)
		# agitar o direcional (esquerda ↔ direita) ou apertar pulo quebra o gelo mais rápido
		var ax := PlayerInput.axis_x(o.pid)
		var sg := 0 if absf(ax) < 0.5 else int(signf(ax))
		var mash: bool = (sg != 0 and sg != f["last_ax"]) or PlayerInput.pressed(o.pid, "jump")
		if sg != 0:
			f["last_ax"] = sg
		if _is_bot(o.pid) and main.rng.randf() < 0.12:
			mash = true
		if mash:
			o.frozen_t -= float(c["agitar_reduz_s"])
			f["shake"] = 1.0
			Audio.play("gelo", 1.8 + main.rng.randf() * 0.3, -14.0)
		o.frozen_t -= dt
		o.stun_t = maxf(o.stun_t, 0.05)   # preso no gelo: sem controle (desliza e cai)
		if o.frozen_t <= 0.0:
			shatter(o)
	for sh in shards:
		sh["t"] += dt
		sh["vel"].y += 1500.0 * dt
		sh["pos"] += sh["vel"] * dt
		sh["rot"] += sh["spin"] * dt
	shards = shards.filter(func(sh): return sh["t"] < 0.9)

# ---------------------------------------------------------------- S06 Superímã (segurar)
func _update_magnet(r, s: Dictionary, dt: float) -> void:
	var c: Dictionary = sc("S06")
	if not held(r) or s["energy"] <= 0.0:
		_stop_channel(r)
		if s["energy"] <= 0.0:
			s["empty_t"] = 0.35
			Audio.play("ima", 1.6, -4.0)
		return
	s["energy"] -= dt
	r.spell_speed = float(c["dono_vel_mult"])
	var orig := hand(r) + Vector2(r.facing * 30.0, 0)
	var rng := float(c["alcance_tiles"]) * T
	for o in main.robots:
		if o == r or not o.alive or o.invuln > 0.0 or o.guard_t > 0.0 or o.god:
			continue
		var oc: Vector2 = o.rect().get_center()
		var d: Vector2 = orig - oc
		if (oc.x - r.position.x) * r.facing < -20.0 or absf(d.y) > 2.5 * T or d.length() > rng:
			continue
		var k := 1.0 - 0.45 * d.length() / rng
		if absf(d.x) < 40.0:
			o.own_vx = 0.0   # grudou no ímã
		else:
			o.own_vx = move_toward(o.own_vx, signf(d.x) * float(c["vel_max"]) * k, float(c["forca"]) * dt)
		o.velocity.y = move_toward(o.velocity.y, clampf(d.y * 5.0, -380.0, 380.0), float(c["forca"]) * 0.7 * dt)
		o.stun_t = maxf(o.stun_t, 0.08)
		o.hanging = false
		o.last_hit = 0.0
		o.last_attacker = r.pid
		o.last_cause = "superímã"

# ---------------------------------------------------------------- S13 Armadura Fornalha
func _start_armor(r, s: Dictionary) -> void:
	var c: Dictionary = sc("S13")
	s["t"] = float(c["duracao_s"])
	s["data"]["assemble"] = 0.0
	r.spell_speed = float(c["vel_mult"])
	r.spell_push = float(c["empurrao_mult"])
	main.shake(6.0)
	Audio.play("caixote_pancada", 0.6, 2.0)
	main.float_text(r.position + Vector2(0, -150), "BLINDADO!", FAM_COR["transformacao"])

func _update_flame(r, s: Dictionary, dt: float) -> void:
	var c: Dictionary = sc("S13")
	var fl: Dictionary = flames.get(r.pid, {"k": 0.0, "hitcd": {}})
	flames[r.pid] = fl
	var on: bool = s["channel"] and held(r) and s["energy"] > 0.0
	if s["channel"] and not on:
		_stop_channel(r)
	fl["k"] = move_toward(fl["k"], 1.0 if on else 0.0, dt * (8.0 if on else 5.0))
	if not on:
		if fl["k"] <= 0.0:
			flames.erase(r.pid)
		return
	s["energy"] -= dt
	r.spell_speed = float(c["vel_mult"]) * 0.55
	if fmod(t, 0.12) < dt:
		Audio.play("chama", 0.8 + main.rng.randf() * 0.2, -4.0)
	for oid in fl["hitcd"].keys():
		fl["hitcd"][oid] -= dt
	var reach: float = float(c["fogo_alcance_tiles"]) * T * fl["k"]
	var o0: Vector2 = r.position + Vector2(r.facing * 26.0, -46.0)
	var band := Rect2(o0.x if r.facing > 0 else o0.x - reach, o0.y - 26.0, reach, 52.0)
	for o in main.robots:
		if o != r and o.alive and band.intersects(o.rect()) and float(fl["hitcd"].get(o.pid, 0.0)) <= 0.0:
			fl["hitcd"][o.pid] = float(c["fogo_tick_s"])
			o.take_hit(r.facing, "spell_fogo", r.pid)
	if s["energy"] <= 0.0:
		_explode_armor(r)

## Acabou o carvão (ou o tempo): a fornalha explode, empurra quem está perto e as placas voam.
func _explode_armor(r) -> void:
	var c: Dictionary = sc("S13")
	var ctr: Vector2 = r.rect().get_center()
	demo.booms.append({"pos": ctr, "t": 0.0})
	main.impact_fx(ctr, 0, 1.4)
	main.shake(12.0)
	Audio.play("explosao", 1.1, 0.0)
	for o in main.robots:
		if o != r and o.alive and o.rect().get_center().distance_to(ctr) < float(c["explosao_raio_tiles"]) * T:
			o.take_hit(1 if o.position.x >= r.position.x else -1, "spell_explosao", r.pid)
	_end_armor(r, true)

func _end_armor(r, natural: bool) -> void:
	r.spell_speed = 1.0
	r.spell_push = 1.0
	flames.erase(r.pid)
	if slot.has(r.pid):
		slot[r.pid]["t"] = -1.0
		slot[r.pid]["channel"] = false
	# as placas voam (a armadura desmonta)
	var parts := [{"tex": [Data.tex("spells/s13_frente")], "rect": Rect2(-36, -31, 72, 62), "mod": Color.WHITE},
		{"tex": [Data.tex("spells/s13_costas")], "rect": Rect2(-36, -31, 72, 62), "mod": Color.WHITE}]
	var dbr: Node2D = main.Debris.new()
	dbr.setup(parts, r.position + Vector2(0, -20), r.facing, Vector2(0, -320))
	main.world.add_child(dbr)
	main.dust(r.position + Vector2(0, -30), 1.2)
	Audio.play("caixote_quebra", 1.2, -2.0)
	if natural:
		slot.erase(r.pid)

# ---------------------------------------------------------------- quadro a quadro
func update(dt: float, alive: Array) -> void:
	t += dt
	for pid in bot_hold.keys():
		bot_hold[pid] -= dt
		if bot_hold[pid] <= 0.0:
			bot_hold.erase(pid)
	_update_boxes(dt, alive)
	_update_holds(dt)
	_update_aims(dt)
	_update_teles(dt)
	_update_frozen(dt)
	for r in main.robots:
		if not slot.has(r.pid):
			continue
		if not r.alive:
			clear(r)
			continue
		var s: Dictionary = slot[r.pid]
		s["cd"] = maxf(s["cd"] - dt, 0.0)
		if s["fire"] >= 0.0:
			s["fire"] += dt
		if s.has("empty_t"):
			s["empty_t"] -= dt
			if s["empty_t"] <= 0.0:
				slot.erase(r.pid)
				continue
		if s["prep"] >= 0.0:
			s["prep"] += dt
			if r.stun_t > 0.0:
				s["prep"] = -1.0   # levou golpe na preparação: cancela (sem gastar carga)
			elif s["prep"] >= s["prep_len"]:
				s["prep"] = -1.0
				_fire(r, s)
		if s["id"] == "S06" and s["channel"]:
			_update_magnet(r, s, dt)
		if s["id"] == "S13" and s["t"] > 0.0:
			s["data"]["assemble"] = minf(float(s["data"].get("assemble", 0.0)) + dt / 0.35, 1.0)
			_update_flame(r, s, dt)
			if slot.has(r.pid) and s["t"] > 0.0:
				s["t"] -= dt
				if s["t"] <= 0.0:
					_explode_armor(r)
	_update_fists(dt)
	_update_shots(dt)
	_update_attack2(dt)
	for p in platforms.duplicate():
		p["t"] -= dt
		p["k"] = minf(p["k"] + dt / 0.32, 1.0)
		if p["k"] >= 0.35 and not p["landed"]:
			p["landed"] = true
			main.dust(p["rect"].get_center() + Vector2(0, 10), 0.9)
			Audio.play("alavanca", 1.5)
			Audio.play("caixote_pancada", 1.4, -6.0)
		if p["t"] <= 0.0:
			_remove_platform(p)
	for e in feedback:
		e["t"] += dt
	feedback = feedback.filter(func(e): return e["t"] < 1.0)
	queue_redraw()
	if ghost != null:
		ghost.queue_redraw()

## Punho: sai rápido com passada do ponto (mola), segura um instante e recolhe.
const FIST_OUT := 0.09
const FIST_HOLD := 0.08
const FIST_BACK := 0.16

func fist_ext(f: Dictionary) -> float:
	var tt: float = f["t"]
	if tt < FIST_OUT:
		var u := tt / FIST_OUT
		return 1.0 + 2.70158 * pow(u - 1.0, 3) + 1.70158 * pow(u - 1.0, 2)   # ease-out-back (passa e volta)
	if tt < FIST_OUT + FIST_HOLD:
		return 1.0
	var v := clampf((tt - FIST_OUT - FIST_HOLD) / FIST_BACK, 0.0, 1.0)
	return 1.0 - v * v

func _update_fists(dt: float) -> void:
	for f in fists:
		f["t"] += dt
		var r = main.robots[f["owner"]]
		var from := hand(r)
		var ext := minf(fist_ext(f), 1.0)
		var tip: Vector2 = from + Vector2(f["dir"] * f["reach"] * ext, 0)
		if f["t"] <= FIST_OUT + FIST_HOLD:
			var band := Rect2(minf(from.x, tip.x), tip.y - 28.0, absf(tip.x - from.x) + 28.0, 56.0)
			for o in main.robots:
				if o.pid == f["owner"] or not o.alive or o.pid in f["hit"]:
					continue
				if band.intersects(o.rect()):
					f["hit"].append(o.pid)
					if o.take_hit(int(f["dir"]), "spell_punho", f["owner"]):
						main.impact_fx(o.rect().get_center(), int(f["dir"]), 1.0)
						o.hitstop = 0.08
						r.hitstop = 0.06
						f["impact"] = 0.0
		if f["impact"] >= 0.0:
			f["impact"] += dt
		if f["t"] >= FIST_OUT and not f.get("done", false):
			f["done"] = true
			if f["wall"]:
				f["impact"] = 0.0
				main.spark(tip, 5)
				Audio.play("bonk", 0.8, -2.0)
				var ct = demo.canteiro
				if ct != null and is_instance_valid(ct):
					for p in ct.parts:
						if not p["fallen"] and p["state"] >= 1 and p["rect"].grow(8).has_point(tip + Vector2(int(f["dir"]) * 14.0, 0)):
							ct.damage(p, 1, tip)   # rompe só peça já fragilizada
	fists = fists.filter(func(f): return f["t"] < FIST_OUT + FIST_HOLD + FIST_BACK)

func _update_shots(dt: float) -> void:
	var c: Dictionary = sc("S03")
	for s in shots:
		s["t"] += dt
		s["pos"] += s["vel"] * dt
		var hit = null
		for o in main.robots:
			if o.pid != s["owner"] and o.alive and o.invuln <= 0.0 and not o.god and o.rect().grow(6).has_point(s["pos"]):
				hit = o
				break
		var wall: bool = main.level.is_solid(Vector2i(int(floor(s["pos"].x / T)), int(floor(s["pos"].y / T))))
		if hit != null:
			var was_frozen: bool = hit.frozen_t > 0.0
			if hit.take_hit(int(signf(s["vel"].x)), "spell_gelo", s["owner"]) and not was_frozen:
				freeze(hit, s["owner"])
			s["dead"] = true
		elif wall or s["t"] > float(c["alcance_tiles"]) * T / float(c["vel"]):
			s["dead"] = true
		if s.get("dead", false):
			for k in 8:
				shards.append({"pos": s["pos"], "vel": Vector2(-signf(s["vel"].x) * randf_range(60, 320), randf_range(-380, -60)),
					"rot": randf() * TAU, "spin": randf_range(-14, 14), "t": 0.2, "size": randf_range(4, 9)})
			Audio.play("gelo", 1.2, -6.0)
	shots = shots.filter(func(s): return not s.get("dead", false))

## Para o desenho do robô (robot_visual): arma na mão, preparação, disparo, canal (segurando), armadura.
func flags(r) -> Dictionary:
	if not slot.has(r.pid):
		return {}
	var s: Dictionary = slot[r.pid]
	var out := {"spell": s["id"], "fire": s["fire"], "prep": (s["prep"] / maxf(s["prep_len"], 0.01)) if s["prep"] >= 0.0 else -1.0,
		"channel": s["channel"]}
	if s["id"] == "S13":
		out["armor"] = s["t"] > 0.0
		out["assemble"] = float(s["data"].get("assemble", 0.0))
		var low: float = minf(s["t"], s["energy"] * 2.0)
		out["armor_end"] = clampf(1.0 - low / 1.2, 0.0, 1.0) if s["t"] > 0.0 else 0.0
		out["flame"] = float(flames.get(r.pid, {}).get("k", 0.0))
	for f in fists:
		if f["owner"] == r.pid:
			out["fist"] = minf(fist_ext(f), 1.0)
	if s.has("empty_t"):
		out["fading"] = true
	return out

## HUD: {id, fam, charges, frac} do jogador (ou vazio). frac = barra de energia/duração.
func hud_info(pid: int) -> Dictionary:
	if not slot.has(pid):
		return {}
	var s: Dictionary = slot[pid]
	var frac := 1.0
	if s["id"] == "S06":
		frac = s["energy"] / float(sc("S06")["energia_s"])
	elif s["id"] == "S13" and s["t"] > 0.0:
		frac = s["energy"] / float(sc("S13")["combustivel_s"])
	return {"id": s["id"], "fam": s["fam"], "charges": s["charges"] if not s["id"] in ["S06"] else 0, "frac": clampf(frac, 0.0, 1.0),
		"nome": NOMES.get(s["id"], s["id"])}

# ---------------------------------------------------------------- desenho (mundo)
const INK := Color("#2a1a2e")
const ICE := Color(0.74, 0.92, 1.0)
const ICE_D := Color("#5aa9d6")

func _draw() -> void:
	for p in platforms:
		_draw_scaffold(p)
	_draw_boxes()
	# prévia do andaime (holograma) para quem tem a spell
	for r in main.robots:
		if r.alive and slot.has(r.pid) and slot[r.pid]["id"] == "S10" and not slot[r.pid].has("empty_t"):
			var pr := scaffold_rect(r)
			var ok := scaffold_ok(r, pr)
			_draw_scaffold_shape(pr, 1.0, _leg_len(pr), Color(0.45, 0.92, 1.0, 0.38 + 0.1 * sin(t * 6.0)) if ok else Color(1, 0.35, 0.35, 0.4), true)
	_draw_holds()
	_draw_magnets()
	_draw_flames()
	_draw_fists()
	_draw_attack2()
	_draw_shots()
	for r in main.robots:
		if frozen.has(r.pid) and r.alive and r.frozen_t > 0.0:
			_draw_ice(r, frozen[r.pid])
	for sh in shards:
		var a: float = 1.0 - sh["t"] / 0.9
		draw_set_transform(sh["pos"], sh["rot"])
		var z: float = sh["size"]
		var tri := PackedVector2Array([Vector2(-z, -z * 0.4), Vector2(z, -z * 0.2), Vector2(-z * 0.1, z * 0.7)])
		draw_colored_polygon(tri, Color(ICE, a))
		draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color(1, 1, 1, a), 1.6, true)
		draw_set_transform(Vector2.ZERO)
	_draw_teleports()
	_draw_bars()
	for e in feedback:
		var a: float = 1.0 - e["t"]
		Kit.text(self, e["pos"] + Vector2(-160, -e["t"] * 30.0), e["text"], 26, Color(1, 0.4, 0.4, a), HORIZONTAL_ALIGNMENT_CENTER, 320, 6, Color(0.16, 0.1, 0.18, a))

## Caixas: quicam ao pousar, flutuam, brilham com a cor da família; a especial desce de paraquedas.
func _draw_boxes() -> void:
	for b in boxes:
		var life: float = float(cfg["caixa"]["vida_s"]) - b["t"]
		if life < 3.0 and fmod(t, 0.3) < 0.12:
			continue
		var land: float = b["land_t"]
		var sq := 1.0
		if land < 0.35:
			sq = 1.0 + sin(land / 0.35 * PI * 2.0) * 0.2 * (1.0 - land / 0.35)
		var p: Vector2 = b["pos"] + Vector2(0, sin(t * 3.0 + b["pos"].x) * 3.0 if b["vy"] == 0.0 else 0.0)
		var col: Color = FAM_COR[b["fam"]]
		var pulse := 0.5 + 0.5 * sin(t * 4.0 + b["pos"].x)
		draw_circle(p, 46.0 + pulse * 6.0, Color(col.r, col.g, col.b, 0.18))
		if b["special"] and b["vy"] > 0.0:
			draw_texture_rect(Data.tex("spells/g10_capsula"), Rect2(p + Vector2(-64, -150), Vector2(128, 160)), false)
		else:
			draw_set_transform(p, sin(t * 2.0 + b["pos"].x) * 0.05, Vector2(2.0 - sq, sq))
			draw_texture_rect(Data.tex("spells/caixa_" + b["fam"]), Rect2(-40, -40, 80, 80), false)
			draw_set_transform(Vector2.ZERO)
		var sa: float = t * 2.0 + b["pos"].x
		var sp: Vector2 = p + Vector2.from_angle(sa) * 46.0
		draw_line(sp - Vector2(4, 0), sp + Vector2(4, 0), Color("#fff4c8"), 2.0, true)
		draw_line(sp - Vector2(0, 4), sp + Vector2(0, 4), Color("#fff4c8"), 2.0, true)

## Troca segurando: anel verde enchendo sobre a cabeça.
func _draw_holds() -> void:
	for pid in holds:
		var h: Dictionary = holds[pid]
		var r = main.robots[pid]
		var k := clampf(h["t"] / float(cfg["caixa"]["troca_s"]), 0.0, 1.0)
		var c: Vector2 = r.position + Vector2(0, -150)
		draw_arc(c, 22.0, 0, TAU, 28, Color(0.85, 0.87, 0.9, 0.9), 7.0, true)
		draw_arc(c, 22.0, -PI / 2.0, -PI / 2.0 + TAU * k, 28, Color("#5cc45c"), 7.0, true)
		draw_texture_rect(Data.tex("spells/icone_" + h["box"]["fam"]), Rect2(c - Vector2(13, 13), Vector2(26, 26)), false)

## Barrinha de energia sobre a cabeça enquanto segura (ímã, jato da fornalha).
func _draw_bars() -> void:
	for r in main.robots:
		if not r.alive or not slot.has(r.pid):
			continue
		var s: Dictionary = slot[r.pid]
		var show: bool = s["channel"] or (s["id"] == "S13" and s["t"] > 0.0)
		if not show or s["id"] == "S11":
			continue
		var full := float(sc(s["id"]).get("energia_s", sc(s["id"]).get("combustivel_s", 1.0)))
		var k := clampf(s["energy"] / full, 0.0, 1.0)
		var bx := Rect2(r.position + Vector2(-34, -126), Vector2(68, 12))
		draw_rect(bx.grow(3), INK)
		draw_rect(bx, Color(1, 1, 1, 0.85))
		var col: Color = FAM_COR[s["fam"]] if k > 0.25 or fmod(t, 0.2) < 0.1 else Color("#ff5a5a")
		draw_rect(Rect2(bx.position, Vector2(bx.size.x * k, bx.size.y)), col)
		draw_rect(Rect2(bx.position, Vector2(bx.size.x * k, 4)), Color(1, 1, 1, 0.45))

# ---------------------------------------------------------------- S01 braço de tesoura + luva
func _draw_fists() -> void:
	for f in fists:
		var r = main.robots[f["owner"]]
		var d := float(f["dir"])
		var from := hand(r)
		var ext := fist_ext(f)
		var L: float = maxf(f["reach"] * ext, 6.0)
		var n := 9
		var w := L / n
		var bar := sqrt(pow(f["reach"] / n, 2) + 22.0 * 22.0)   # barra de tamanho fixo: esticado ainda mostra o X, recolhido abre
		var hh := sqrt(maxf(bar * bar - w * w, 9.0)) / 2.0
		var pts_top := []
		var pts_bot := []
		for i in n + 1:
			var x := from.x + d * w * i
			pts_top.append(Vector2(x, from.y - hh))
			pts_bot.append(Vector2(x, from.y + hh))
		# barras (contorno escuro + metal), cruzando em X
		for pass_i in 2:
			for i in n:
				var a: Vector2 = pts_top[i]
				var b: Vector2 = pts_bot[i + 1]
				var c: Vector2 = pts_bot[i]
				var e: Vector2 = pts_top[i + 1]
				if pass_i == 0:
					draw_line(a, b, INK, 8.0, true)
					draw_line(c, e, INK, 8.0, true)
				else:
					draw_line(a, b, Color("#b9c3cc"), 4.0, true)
					draw_line(c, e, Color("#8e9aa6"), 4.0, true)
		for i in n + 1:   # pinos
			draw_circle(pts_top[i], 3.2, Color("#f2c84b"))
			draw_circle(pts_bot[i], 3.2, Color("#f2c84b"))
			if i < n:
				draw_circle(Vector2(from.x + d * w * (i + 0.5), from.y), 2.6, Color("#f2c84b"))
		# luva: estica na saída, achata no impacto
		var tip := Vector2(from.x + d * L, from.y)
		var sq := Vector2(1.0, 1.0)
		if f["t"] < FIST_OUT:
			sq = Vector2(1.25, 0.85)
		if f["impact"] >= 0.0 and f["impact"] < 0.12:
			var u: float = f["impact"] / 0.12
			sq = Vector2(0.7 + 0.3 * u, 1.3 - 0.3 * u)
		draw_set_transform(tip, 0.0, Vector2(d * sq.x, sq.y))
		draw_texture_rect(Data.tex("spells/s01_luva"), Rect2(-8, -26, 62, 50), false)
		draw_set_transform(Vector2.ZERO)
		# linhas de velocidade na saída
		if f["t"] < FIST_OUT + 0.04:
			for k in 4:
				var yy := from.y - 22.0 + k * 15.0
				draw_line(Vector2(tip.x - d * (40.0 + k * 9.0), yy), Vector2(tip.x - d * (110.0 + k * 14.0), yy), Color(1, 1, 1, 0.85), 3.0, true)
		# estrela de impacto
		if f["impact"] >= 0.0 and f["impact"] < 0.16:
			var u: float = f["impact"] / 0.16
			var c := tip + Vector2(d * 50.0, 0)
			var star := PackedVector2Array()
			for k in 16:
				var rad := (34.0 if k % 2 == 0 else 14.0) * (0.6 + 0.6 * u)
				star.append(c + Vector2.from_angle(k * TAU / 16.0 + 0.2) * rad)
			draw_colored_polygon(star, Color(1, 0.95, 0.6, 1.0 - u))
	# preparo: luva espiando no cano tremendo + vapor
	for r in main.robots:
		if not slot.has(r.pid) or slot[r.pid]["id"] != "S01" or slot[r.pid]["prep"] < 0.0:
			continue
		var k: float = slot[r.pid]["prep"] / maxf(slot[r.pid]["prep_len"], 0.01)
		var h := hand(r) + Vector2(r.facing * (6.0 - 8.0 * k), 0) + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 2.0 * k
		draw_set_transform(h, 0.0, Vector2(r.facing * 0.75, 0.75))
		draw_texture_rect(Data.tex("spells/s01_luva"), Rect2(-8, -26, 62, 50), false)
		draw_set_transform(Vector2.ZERO)
		for j in 3:
			var u := fposmod(t * 3.0 + j * 0.33, 1.0)
			draw_circle(h + Vector2(-r.facing * (10.0 + 6.0 * j), -12.0 - u * 26.0), 4.0 + u * 7.0, Color(1, 1, 1, 0.55 * (1.0 - u) * k))

# ---------------------------------------------------------------- S03 tiro e bloco de gelo
func _draw_shots() -> void:
	for r in main.robots:   # carga: flocos convergindo para o bico
		if slot.has(r.pid) and slot[r.pid]["id"] == "S03" and slot[r.pid]["prep"] >= 0.0:
			var k: float = slot[r.pid]["prep"] / maxf(slot[r.pid]["prep_len"], 0.01)
			var m := hand(r) + Vector2(r.facing * 30.0, 0)
			for j in 8:
				var a := j * TAU / 8.0 + t * 3.0
				var rad := 40.0 * (1.0 - k)
				_flake(m + Vector2.from_angle(a) * rad, 4.0, t * 4.0 + j)
			draw_circle(m, 6.0 + 10.0 * k, Color(ICE, 0.5 + 0.3 * k))
			draw_circle(m, 3.0 + 5.0 * k, Color(1, 1, 1, 0.9))
	for s in shots:
		var d := signf(s["vel"].x)
		# rastro de névoa e flocos
		for k in 6:
			var q: Vector2 = s["pos"] - Vector2(d * (18.0 + k * 13.0), sin(s["t"] * 30.0 + k) * 3.0)
			draw_circle(q, 11.0 - k * 1.4, Color(0.85, 0.96, 1.0, 0.55 - k * 0.08))
		for k in 3:
			_flake(s["pos"] - Vector2(d * (30.0 + k * 26.0), (k - 1) * 12.0), 4.0, s["t"] * 10.0 + k)
		# lança de cristal (girando no próprio eixo: brilho correndo)
		draw_set_transform(s["pos"], 0.0, Vector2(d, 1))
		var spear := PackedVector2Array([Vector2(26, 0), Vector2(4, -11), Vector2(-20, -7), Vector2(-14, 0), Vector2(-20, 7), Vector2(4, 11)])
		draw_colored_polygon(spear, ICE_D)
		draw_colored_polygon(PackedVector2Array([Vector2(22, 0), Vector2(4, -8), Vector2(-14, -4), Vector2(-8, 0)]), ICE)
		draw_colored_polygon(PackedVector2Array([Vector2(22, 0), Vector2(-8, 0), Vector2(-14, 4), Vector2(4, 8)]), Color(0.62, 0.86, 0.97))
		var gl := fposmod(s["t"] * 6.0, 1.0)
		draw_line(Vector2(-14 + 30 * gl, -4), Vector2(-6 + 30 * gl, -6), Color(1, 1, 1, 0.9), 2.5, true)
		draw_polyline(PackedVector2Array([spear[0], spear[1], spear[2], spear[3], spear[4], spear[5], spear[0]]), Color("#2a5a80"), 2.0, true)
		draw_set_transform(Vector2.ZERO)

func _flake(p: Vector2, z: float, rot: float) -> void:
	for k in 3:
		var a := rot + k * PI / 3.0
		draw_line(p - Vector2.from_angle(a) * z, p + Vector2.from_angle(a) * z, Color(1, 1, 1, 0.9), 1.6, true)

## Bloco de gelo facetado em volta do robô: cresce de baixo, treme quando o jogador agita, racha até quebrar.
func _draw_ice(r, f: Dictionary) -> void:
	var rr: Rect2 = r.rect().grow_individual(14, 16, 14, 4)
	var grow := clampf(f["age"] / 0.14, 0.0, 1.0)
	var top := rr.end.y - rr.size.y * grow
	var sh: Vector2 = Vector2(sin(t * 70.0), cos(t * 63.0)) * 3.0 * f["shake"]
	var seed := float(r.pid) * 1.7
	var j := func(i: int) -> float: return sin(seed + i * 2.3) * 5.0
	var x0: float = rr.position.x + sh.x
	var x1: float = rr.end.x + sh.x
	var y1 := rr.end.y
	var poly := PackedVector2Array([Vector2(x0 + j.call(0), y1), Vector2(x0 - 4 + j.call(1), lerpf(y1, top, 0.45)), Vector2(x0 + 6 + j.call(2), top + 6),
		Vector2(lerpf(x0, x1, 0.4) + j.call(3), top - 4 + j.call(4)), Vector2(x1 - 8 + j.call(5), top + 2), Vector2(x1 + 4 + j.call(6), lerpf(y1, top, 0.5)), Vector2(x1 + j.call(7), y1)])
	draw_colored_polygon(poly, Color(ICE, 0.55))
	# faces internas (luz de cima à esquerda) e reflexos
	var mid := Vector2(lerpf(x0, x1, 0.45), lerpf(top, y1, 0.42))
	draw_colored_polygon(PackedVector2Array([poly[1], poly[2], poly[3], mid]), Color(1, 1, 1, 0.22))
	draw_colored_polygon(PackedVector2Array([poly[4], poly[5], poly[6], mid]), Color(0.35, 0.65, 0.88, 0.2))
	draw_line(poly[2] + Vector2(6, 8), poly[2] + Vector2(14, 34), Color(1, 1, 1, 0.85), 4.0, true)
	draw_line(poly[2] + Vector2(16, 6), poly[2] + Vector2(20, 16), Color(1, 1, 1, 0.7), 3.0, true)
	var outline := poly.duplicate()
	outline.append(poly[0])
	draw_polyline(outline, ICE_D, 3.5, true)
	# geada na base
	for i in 5:
		var bx := lerpf(x0, x1, (i + 0.5) / 5.0)
		draw_colored_polygon(PackedVector2Array([Vector2(bx - 9, y1), Vector2(bx, y1 - 10 - sin(seed + i) * 4.0), Vector2(bx + 9, y1)]), Color(1, 1, 1, 0.75))
	# rachaduras: aparecem com o tempo e com a agitação
	var k := 1.0 - clampf(r.frozen_t / maxf(f["len"], 0.01), 0.0, 1.0)
	var cracks := [[Vector2(0.55, 0.0), Vector2(0.45, 0.3), Vector2(0.62, 0.5), Vector2(0.5, 0.75)],
		[Vector2(0.0, 0.4), Vector2(0.25, 0.48), Vector2(0.32, 0.7)], [Vector2(1.0, 0.3), Vector2(0.78, 0.42), Vector2(0.72, 0.62), Vector2(0.85, 0.9)]]
	for ci in cracks.size():
		if k < 0.25 + ci * 0.22:
			continue
		var line := PackedVector2Array()
		for q in cracks[ci]:
			line.append(Vector2(lerpf(x0, x1, q.x), lerpf(top, y1, q.y)))
		draw_polyline(line, Color(1, 1, 1, 0.95), 2.4, true)
	# dica de agitar (jogador humano)
	if not _is_bot(r.pid) and f["age"] > 0.3:
		var a := 0.6 + 0.4 * sin(t * 10.0)
		var c := Vector2(rr.get_center().x, top - 30.0)
		var wob := sin(t * 18.0) * 8.0
		Kit.text(self, c + Vector2(-60 + wob, 0), "◄ ►", 26, Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER, 120, 6, Color(0.16, 0.1, 0.18, a))

# ---------------------------------------------------------------- S06 campo do ímã (buraco negro)
func _draw_magnets() -> void:
	for r in main.robots:
		if not r.alive or not slot.has(r.pid) or slot[r.pid]["id"] != "S06" or not slot[r.pid]["channel"]:
			continue
		var d := float(r.facing)
		var o := hand(r) + Vector2(d * 30.0, 0)
		var rng := float(sc("S06")["alcance_tiles"]) * T
		# redemoinho: anéis achatados girando e encolhendo para dentro do polo
		for i in 4:
			var u := fposmod(t * 1.8 + i * 0.25, 1.0)
			var rad := 110.0 * (1.0 - u) + 18.0
			var a0 := t * 9.0 + i * 1.3
			draw_set_transform(o, 0.0, Vector2(1.0, 0.55))
			draw_arc(Vector2.ZERO, rad, a0, a0 + 4.2, 24, Color(0.85, 0.29, 0.35, 0.75 * u), 3.0, true)
			draw_set_transform(Vector2.ZERO)
		# riscos de sucção vindo de longe (só para a frente) e parafusinhos voando para o polo
		for i in 16:
			var u := fposmod(t * 2.2 + i * 0.137, 1.0)
			var ang := (float(i) / 15.0 - 0.5) * 1.5
			var far := rng * (1.0 - u)
			var q := o + Vector2(d * cos(ang), sin(ang) * 0.6) * far
			var q2 := o + Vector2(d * cos(ang), sin(ang) * 0.6) * (far + 26.0 + 30.0 * (1.0 - u))
			draw_line(q, q2, Color(1, 1, 1, 0.75 * u), 2.0, true)
			if i % 4 == 0:
				draw_circle(q, 3.0, Color("#9aa4ae"))
		# núcleo: anel escuro pulsando com borda vermelha
		var pz := 16.0 + 3.0 * sin(t * 20.0)
		draw_circle(o, pz + 6.0, Color(0.85, 0.29, 0.35, 0.35))
		draw_circle(o, pz, Color(0.16, 0.1, 0.18, 0.85))
		draw_arc(o, pz, 0, TAU, 20, Color("#ff8a96"), 2.5, true)
		# faísquinhas nos robôs presos
		for v in main.robots:
			if v != r and v.alive and v.last_cause == "superímã" and v.last_hit < 0.1:
				var c: Vector2 = v.rect().get_center()
				for k in 2:
					var a0 := t * 12.0 + k * PI
					draw_arc(c, 34.0, a0, a0 + 1.0, 6, Color(1, 0.9, 0.5, 0.9), 2.5, true)

# ---------------------------------------------------------------- S13 jato da fornalha
func _draw_flames() -> void:
	for pid in flames:
		var fl: Dictionary = flames[pid]
		var r = main.robots[pid]
		var k: float = fl["k"]
		if k <= 0.01 or not r.alive:
			continue
		var d := float(r.facing)
		var reach := float(sc("S13")["fogo_alcance_tiles"]) * T * k
		var o: Vector2 = r.position + Vector2(d * 26.0, -46.0)
		# jato reto e contido: tubo de fogo com bordas tremendo, núcleo claro, fumaça na ponta
		var layers := [[Color(0.86, 0.3, 0.14), 24.0], [Color(1.0, 0.6, 0.2), 17.0], [Color(1.0, 0.88, 0.45), 10.0], [Color(1.0, 0.98, 0.86), 4.5]]
		for li in layers.size():
			var col: Color = layers[li][0]
			var w0: float = layers[li][1]
			var top := PackedVector2Array()
			var bot := PackedVector2Array()
			var n := 16
			var len := reach * (1.0 - li * 0.08)
			for i in n + 1:
				var u := float(i) / n
				var w := w0 * (0.55 + 0.45 * sin(minf(u * 1.4, 1.0) * PI * 0.5)) * (1.0 - 0.35 * pow(u, 3))
				var fl1 := sin(u * 22.0 - t * 48.0 + li) * 3.5 * u
				var fl2 := sin(u * 19.0 - t * 41.0 + li * 2.0) * 3.5 * u
				top.append(o + Vector2(d * len * u, -w - fl1))
				bot.append(o + Vector2(d * len * u, w + fl2))
			var poly := top.duplicate()
			poly.append(o + Vector2(d * (len + 10.0 - li * 3.0), sin(t * 30.0) * 3.0))
			bot.reverse()
			poly.append_array(bot)
			draw_colored_polygon(poly, Color(col, minf(k * 1.5, 1.0)))
		for j in 6:   # brasas
			var u := fposmod(t * 2.2 + j * 0.17, 1.0)
			var q := o + Vector2(d * reach * (0.3 + 0.8 * u), sin(j * 2.1 + t * 6.0) * 18.0 - 14.0 * u)
			draw_circle(q, 2.6, Color(1, 0.85, 0.4, (1.0 - u) * k))
		draw_circle(o + Vector2(d * (reach + 16.0), -10.0), 12.0 + 6.0 * sin(t * 9.0), Color(0.35, 0.3, 0.32, 0.3 * k))
		# boca da fornalha brilhando
		draw_circle(o, 9.0, Color(1.0, 0.9, 0.5, 0.9 * k))

# ---------------------------------------------------------------- S10 andaime relâmpago
func _ease_back(u: float) -> float:
	return 1.0 + 2.70158 * pow(u - 1.0, 3) + 1.70158 * pow(u - 1.0, 2)

func _draw_scaffold(p: Dictionary) -> void:
	var pr: Rect2 = p["rect"]
	var k: float = p["k"]
	if k < 0.35:   # a trouxa voa da mão até o lugar
		var u := k / 0.35
		var q: Vector2 = Vector2(p["from"]).lerp(pr.get_center(), u) + Vector2(0, -sin(u * PI) * 50.0)
		draw_set_transform(q, u * TAU * 1.5, Vector2.ONE)
		draw_texture_rect(Data.tex("spells/s10_trouxa"), Rect2(-24, -16, 48, 32), false)
		draw_set_transform(Vector2.ZERO)
		return
	var open := _ease_back(clampf((k - 0.35) / 0.65, 0.0, 1.0))
	var fold_t := 0.35
	if p["t"] < fold_t:   # dobra no fim
		open = clampf(p["t"] / fold_t, 0.0, 1.0)
	var mod := Color.WHITE
	if p["t"] < 1.2 and p["t"] >= fold_t and fmod(t, 0.2) < 0.1:
		mod = Color(1, 0.7, 0.6)   # piscando: vai dobrar
	var wob := sin(t * 40.0) * 1.5 if p["t"] < 1.2 else 0.0
	_draw_scaffold_shape(Rect2(pr.position + Vector2(wob, 0), pr.size), open, p["leg"], mod, false)

## Andaime: tábua central fixa + duas abas que deslizam para os lados, pernas tubulares que giram para baixo.
func _draw_scaffold_shape(pr: Rect2, open: float, leg: float, mod: Color, holo: bool) -> void:
	var tex := Data.tex("spells/s10_tabua")
	var cx := pr.get_center().x
	var y := pr.position.y
	var w := pr.size.x
	var th := 24.0
	var side := w / 3.0
	var slide := side * clampf(open, 0.0, 1.15)
	# pernas (A): giram de deitadas (0) para em pé (1)
	var ang := (1.0 - clampf(open, 0.0, 1.1)) * (PI / 2.0)
	var tube := Color("#71829a") if not holo else mod
	var dark := INK if not holo else Color(mod, mod.a * 0.6)
	for sx in [-1.0, 1.0]:
		var hip := Vector2(cx + sx * (side * 0.5 + slide * 0.55), y + th)
		var dirv := Vector2(sin(ang) * sx, cos(ang))
		var foot := hip + dirv * leg
		var spread := Vector2(dirv.y, -dirv.x) * 12.0
		for q in [hip - spread * 0.4, hip + spread * 0.4]:
			draw_line(q, foot + (q - hip) * 2.2, dark, 9.0, true)
		for q in [hip - spread * 0.4, hip + spread * 0.4]:
			draw_line(q, foot + (q - hip) * 2.2, tube.lightened(0.1) if not holo else mod, 5.0, true)
		if leg > 40.0:   # travessa em X
			var m1 := hip.lerp(foot, 0.3)
			var m2 := hip.lerp(foot, 0.75)
			draw_line(m1 - spread * 0.7, m2 + spread * 1.6, dark, 5.0, true)
			draw_line(m1 + spread * 0.7, m2 - spread * 1.6, dark, 5.0, true)
			draw_line(m1 - spread * 0.7, m2 + spread * 1.6, tube, 2.5, true)
			draw_line(m1 + spread * 0.7, m2 - spread * 1.6, tube, 2.5, true)
		if not holo:
			draw_rect(Rect2(foot + (-spread) * 2.4 - Vector2(4, 3), Vector2(absf(spread.x) * 4.8 + 8, 6)), Color("#4a5566"))
			draw_circle(hip, 5.0, Color("#f2c84b"))
			draw_circle(hip, 2.0, INK)
	# tábua: miolo + abas deslizando (pedaços da textura)
	var tw := float(tex.get_width())
	var thh := float(tex.get_height())
	var src_side := Rect2(0, 0, tw / 3.0, thh)
	var src_mid := Rect2(tw / 3.0, 0, tw / 3.0, thh)
	var src_r := Rect2(tw * 2.0 / 3.0, 0, tw / 3.0, thh)
	draw_texture_rect_region(tex, Rect2(cx - side / 2.0 - slide, y, side, th), src_side, mod)
	draw_texture_rect_region(tex, Rect2(cx + side / 2.0 + slide - side, y, side, th), src_r, mod)
	draw_texture_rect_region(tex, Rect2(cx - side / 2.0, y, side, th), src_mid, mod)

# ---------------------------------------------------------------- S11 mira e teletransporte
func _draw_teleports() -> void:
	var col := Color("#b59cff")
	for pid in aims:
		var a: Dictionary = aims[pid]
		var r = main.robots[pid]
		var c: Color = col if a["ok"] else Color("#ff6a6a")
		# linha pontilhada em arco do robô até o destino
		var p0: Vector2 = r.position + Vector2(0, -40)
		var p1: Vector2 = a["pos"] + Vector2(0, -40)
		var n := 12
		for i in n:
			var u := (i + fposmod(t * 3.0, 1.0)) / n
			var q := p0.lerp(p1, u) + Vector2(0, -sin(u * PI) * 40.0)
			draw_circle(q, 3.0, Color(c, 0.85))
		# anel no chão do destino
		draw_set_transform(a["pos"], 0.0, Vector2(1.0, 0.3))
		draw_arc(Vector2.ZERO, 34.0 + 4.0 * sin(t * 8.0), 0, TAU, 24, Color(c, 0.9), 4.0, true)
		draw_set_transform(Vector2.ZERO)
	for e in teles:
		var tt: float = e["t"]
		# saída: coluna de luz afinando até virar fio; chegada: fio engorda e some
		if tt < 0.12:
			var u := tt / 0.12
			_beam(e["a"], 30.0 * (1.0 - u) + 2.0, 1.0 - u * 0.3, col)
		if tt > 0.05 and tt < 0.16:   # risco de luz ligando os dois pontos
			var u := (tt - 0.05) / 0.11
			var a0: Vector2 = e["a"] + Vector2(0, -40)
			var b0: Vector2 = e["b"] + Vector2(0, -40)
			draw_line(a0.lerp(b0, maxf(u - 0.4, 0.0)), a0.lerp(b0, minf(u * 1.4, 1.0)), Color(1, 1, 1, 0.9), 6.0, true)
			draw_line(a0.lerp(b0, maxf(u - 0.4, 0.0)), a0.lerp(b0, minf(u * 1.4, 1.0)), Color(col, 0.8), 12.0, true)
		if tt > 0.09:
			var u := clampf((tt - 0.09) / 0.17, 0.0, 1.0)
			_beam(e["b"], 4.0 + 34.0 * sin(u * PI * 0.5), 1.0 - u, col)
			for k in 6:   # anéis subindo
				var v := fposmod(u + k / 6.0, 1.0)
				draw_set_transform(e["b"] + Vector2(0, -v * 90.0), 0.0, Vector2(1.0, 0.3))
				draw_arc(Vector2.ZERO, 26.0, 0, TAU, 16, Color(col, (1.0 - u) * 0.8), 3.0, true)
				draw_set_transform(Vector2.ZERO)

func _beam(feet: Vector2, w: float, a: float, col: Color) -> void:
	draw_rect(Rect2(feet + Vector2(-w / 2.0 - 6.0, -110), Vector2(w + 12.0, 110)), Color(col, 0.35 * a))
	draw_rect(Rect2(feet + Vector2(-w / 2.0, -104), Vector2(w, 104)), Color(1, 1, 1, 0.85 * a))
	draw_set_transform(feet, 0.0, Vector2(1.0, 0.3))
	draw_circle(Vector2.ZERO, w + 18.0, Color(col, 0.5 * a))
	draw_set_transform(Vector2.ZERO)

## Silhueta holográfica do robô no destino (o nó "ghost" tem transparência própria).
func _draw_ghost() -> void:
	for pid in aims:
		var a: Dictionary = aims[pid]
		var r = main.robots[pid]
		ghost.material.set_shader_parameter("tint", Color(0.72, 0.6, 1.0, 0.65) if a["ok"] else Color(1.0, 0.4, 0.4, 0.6))
		var pose: Dictionary = RobotVis.idle_pose(t)
		var off := Vector2(0, sin(t * 6.0) * 3.0)
		RobotVis.draw_robot(ghost, r.vis.look(), pose, Transform2D(0.0, Vector2(r.facing, 1.0), 0.0, a["pos"] + off))

# ================================================================ ETAPA 2: ataque
func _hit(o, owner: int, dir: int, kind: String) -> bool:
	if o.pid == owner or not o.alive:
		return false
	var ok: bool = o.take_hit(dir, kind, owner)
	if ok:
		main.impact_fx(o.rect().get_center(), dir, 0.8)
	return ok

func _solid_at(p: Vector2) -> bool:
	return main.level.is_solid(Vector2i(int(floor(p.x / T)), int(floor(p.y / T))))

## Chão sob x a partir de y (procura até n tiles abaixo). -1 = sem chão.
func _floor_below(x: float, y: float, n := 8) -> float:
	var cy := int(floor(y / T))
	for k in n:
		if main.level.is_solid(Vector2i(int(floor(x / T)), cy + k)):
			return (cy + k) * T
	return -1.0

## Disparos com preparo: laser (S02), marreta sísmica (S04), canhão de molas (S20).
func _fire2(r, s: Dictionary) -> void:
	var c: Dictionary = sc(s["id"])
	match s["id"]:
		"S02":   # feixe instantâneo até a parede, atravessa robôs (1 acerto cada)
			var a := hand(r) + Vector2(r.facing * 40.0, 0)
			var b := a
			var maxd := float(c["alcance_tiles"]) * T
			var d := 0.0
			while d < maxd and not _solid_at(a + Vector2(r.facing * (d + 8.0), 0)):
				d += 8.0
			b = a + Vector2(r.facing * d, 0)
			lasers.append({"owner": r.pid, "t": 0.0, "a": a, "b": b})
			var band := Rect2(minf(a.x, b.x), a.y - 12.0, absf(b.x - a.x), 24.0)
			for o in main.robots:
				if band.intersects(o.rect()):
					_hit(o, r.pid, r.facing, "spell_laser")
			if d < maxd:
				scorch.append({"pos": b, "t": 0.0})
			Audio.play("laser", 1.0, 0.0)
			main.shake(3.0)
			r.own_vx -= r.facing * 90.0
			_spend(r, s)
		"S04":   # onda pela superfície contínua, para em buracos e paredes
			if not r.is_on_floor():
				_fail(r, "SÓ NO CHÃO")
				s["cd"] = 0.0
				return
			var y: float = r.position.y
			var maxd := float(c["alcance_tiles"]) * T
			var ends := []
			for dir in [-1.0, 1.0]:
				var x: float = r.position.x
				var dd := 0.0
				while dd < maxd:
					var nx: float = r.position.x + dir * (dd + 16.0)
					if not _solid_at(Vector2(nx, y + 8.0)) or _solid_at(Vector2(nx, y - 24.0)):
						break
					dd += 16.0
				ends.append(r.position.x + dir * dd)
			waves.append({"owner": r.pid, "x0": r.position.x, "y": y, "l_end": ends[0], "r_end": ends[1], "t": 0.0, "hit": []})
			main.shake(10.0)
			Audio.play("terremoto", 1.3, 0.0)
			Audio.play("martelao", 0.8, 0.0)
			main.dust(r.position + Vector2(r.facing * 40.0, 0), 1.4)
			_spend(r, s)
		"S20":   # mola saltitante: primeiro robô leva o BOING
			springs.append({"owner": r.pid, "pos": hand(r) + Vector2(r.facing * 50.0, 0), "vel": Vector2(r.facing * float(c["vel"]), -float(c["subida"])),
				"t": 0.0, "sq": 0.0})
			Audio.play("pulo_mola", 1.3, 2.0)
			r.own_vx -= r.facing * 260.0
			main.shake(4.0)
			_spend(r, s)

## S05: rebite em linha (▲/▼ inclinam 45°), ricocheteia até 2 vezes perdendo força.
func _fire_rivet(r, s: Dictionary) -> void:
	var c: Dictionary = sc("S05")
	if s["cd"] > 0.0:
		return
	var dirv := Vector2(r.facing, 0)
	if PlayerInput.held(r.pid, "up"):
		dirv = Vector2(r.facing, -1).normalized()
	elif PlayerInput.held(r.pid, "down") and not r.is_on_floor():
		dirv = Vector2(r.facing, 1).normalized()
	rivets.append({"owner": r.pid, "pos": hand(r) + Vector2(r.facing * 40.0, 0), "vel": dirv * float(c["vel"]), "bounces": 0, "t": 0.0, "hit": [], "trail": []})
	s["cd"] = float(c["intervalo_s"])
	s["fire"] = 0.0
	Audio.play("chave", 1.6, -2.0)
	r.own_vx -= r.facing * 50.0
	_spend(r, s)

## S17: marca uma faixa à frente (no chão) e a estaca desce lá depois do aviso.
func _drop_pile(r, s: Dictionary) -> void:
	var c: Dictionary = sc("S17")
	var x: float = r.position.x + r.facing * float(c["distancia_tiles"]) * T
	var fy := _floor_below(x, r.position.y - 2.0 * T, 9)
	if fy < 0.0:
		fy = r.position.y + 2.0 * T
	piles.append({"owner": r.pid, "x": x, "floor_y": fy, "t": 0.0, "hit": [], "done": false})
	s["fire"] = 0.0
	Audio.play("alarme", 1.4, -6.0)
	_spend(r, s)

func _throw_disc(r, s: Dictionary) -> void:
	var c: Dictionary = sc("S18")
	discs.append({"owner": r.pid, "pos": hand(r) + Vector2(r.facing * 30.0, 0), "vel": Vector2(r.facing * float(c["vel"]), 0), "phase": "ida",
		"t": 0.0, "hit": [], "rot": 0.0, "x0": r.position.x})
	s["fire"] = 0.0
	Audio.play("serra", 1.2, -2.0)
	_spend(r, s)

func _throw_hammer(r, s: Dictionary) -> void:
	var c: Dictionary = sc("S19")
	hammers.append({"owner": r.pid, "pos": hand(r) + Vector2(0, -10), "vel": Vector2(r.facing * float(c["vel"]), -180.0), "phase": "ida",
		"t": 0.0, "hit": [], "rot": 0.0, "dir": r.facing})
	r.hammer_out = true
	s["fire"] = 0.0
	Audio.play("marreta_vento", 1.0, 0.0)
	_spend(r, s)

func _update_attack2(dt: float) -> void:
	# S02 feixe e marcas de solda
	for e in lasers:
		e["t"] += dt
	lasers = lasers.filter(func(e): return e["t"] < 0.22)
	for e in scorch:
		e["t"] += dt
	scorch = scorch.filter(func(e): return e["t"] < 2.5)
	# S04 onda: a frente anda nas duas direções e acerta quem está apoiado no mesmo trecho
	var c4: Dictionary = sc("S04")
	for w in waves:
		w["t"] += dt
		var front: float = w["t"] * float(c4["vel"])
		for o in main.robots:
			if o.pid == w["owner"] or not o.alive or o.pid in w["hit"] or not o.is_on_floor():
				continue
			if absf(o.position.y - w["y"]) > 6.0:
				continue
			var dx: float = o.position.x - w["x0"]
			var lim: float = (w["r_end"] - w["x0"]) if dx >= 0.0 else (w["x0"] - w["l_end"])
			if absf(dx) <= minf(front, lim) + 20.0 and absf(dx) >= minf(front, lim) - 60.0:
				w["hit"].append(o.pid)
				_hit(o, w["owner"], 1 if dx >= 0.0 else -1, "spell_sismo")
		if fmod(w["t"], 0.05) < dt:
			for dir in [-1.0, 1.0]:
				var lim2: float = (w["r_end"] - w["x0"]) if dir > 0.0 else (w["x0"] - w["l_end"])
				if front < lim2:
					main.dust(Vector2(w["x0"] + dir * front, w["y"]), 0.5)
	waves = waves.filter(func(w): return w["t"] < 0.9)
	# S05 rebites
	var c5: Dictionary = sc("S05")
	for rv in rivets:
		rv["t"] += dt
		rv["trail"].push_front(rv["pos"])
		if rv["trail"].size() > 6:
			rv["trail"].pop_back()
		var np: Vector2 = rv["pos"] + rv["vel"] * dt
		if _solid_at(np):
			if rv["bounces"] >= int(c5["ricochetes"]):
				rv["dead"] = true
			else:
				# reflete no eixo que bateu
				var hx := _solid_at(Vector2(np.x, rv["pos"].y))
				var hy := _solid_at(Vector2(rv["pos"].x, np.y))
				if hx or not hy:
					rv["vel"].x = -rv["vel"].x
				if hy:
					rv["vel"].y = -rv["vel"].y
				rv["vel"] *= float(c5["perda"])
				rv["bounces"] += 1
				rv["hit"].clear()
				Audio.play("chave", 2.0 + rv["bounces"] * 0.3, -6.0)
			main.spark(rv["pos"], 4)
		else:
			rv["pos"] = np
		for o in main.robots:
			if o.pid != rv["owner"] and o.alive and not (o.pid in rv["hit"]) and o.rect().grow(4).has_point(rv["pos"]):
				rv["hit"].append(o.pid)
				_hit(o, rv["owner"], int(signf(rv["vel"].x)), "spell_rebite")
				rv["dead"] = true
		if rv["t"] > float(c5["vida_s"]):
			rv["dead"] = true
	rivets = rivets.filter(func(rv): return not rv.get("dead", false))
	# S17 estaca: aviso → desce rápido → lança para cima → sobe
	var c17: Dictionary = sc("S17")
	var mark: float = float(c17["marca_s"])
	for p in piles:
		p["t"] += dt
		if p["t"] >= mark + 0.08 and not p["done"]:
			p["done"] = true
			var hw := float(c17["largura_tiles"]) * T / 2.0
			var col := Rect2(p["x"] - hw, p["floor_y"] - 6.0 * T, hw * 2.0, 6.0 * T)
			for o in main.robots:
				if o.alive and col.intersects(o.rect()):
					_hit(o, p["owner"], 1 if o.position.x >= p["x"] else -1, "spell_estaca")
			main.shake(12.0)
			Audio.play("pistao", 0.7, 2.0)
			Audio.play("caixote_pancada", 0.6, 0.0)
			main.dust(Vector2(p["x"], p["floor_y"]), 1.5)
			var ct = demo.canteiro
			if ct != null and is_instance_valid(ct):
				for pt in ct.parts:
					if not pt["fallen"] and pt["rect"].has_point(Vector2(p["x"], p["floor_y"] + 8.0)):
						ct.damage(pt, 1, Vector2(p["x"], p["floor_y"]))   # deforma peça vulnerável
	piles = piles.filter(func(p): return p["t"] < mark + 0.9)
	# S18 disco: rola pelo chão, bate e volta voando para a mão
	var c18: Dictionary = sc("S18")
	for d in discs:
		d["t"] += dt
		var owner = main.robots[d["owner"]]
		d["rot"] += dt * 30.0 * signf(d["vel"].x if d["vel"].x != 0.0 else 1.0)
		if d["phase"] == "ida":
			d["vel"].y = minf(d["vel"].y + 1800.0 * dt, 900.0)
			var np: Vector2 = d["pos"] + d["vel"] * dt
			if _solid_at(np + Vector2(0, 22)):   # rolando no chão
				np.y = floor((np.y + 22.0) / T) * T - 22.0
				d["vel"].y = 0.0
				if fmod(d["t"], 0.04) < dt:
					main.spark(np + Vector2(-signf(d["vel"].x) * 10.0, 20.0), 1)
			if _solid_at(np + Vector2(signf(d["vel"].x) * 24.0, 0)) or absf(np.x - d["x0"]) > float(c18["alcance_tiles"]) * T or d["t"] > float(c18["max_s"]) * 0.6:
				d["phase"] = "volta"
				d["hit"].clear()
				main.spark(np, 4)
				Audio.play("serra", 1.5, -4.0)
			else:
				d["pos"] = np
		else:
			var to: Vector2 = hand(owner) - d["pos"]
			d["pos"] += to.normalized() * minf(float(c18["volta_vel"]) * dt, to.length())
			if to.length() < 30.0 or d["t"] > float(c18["max_s"]) or not owner.alive:
				d["dead"] = true
				Audio.play("chave", 1.0, -4.0)
		for o in main.robots:
			if o.pid != d["owner"] and o.alive and not (o.pid in d["hit"]) and o.rect().grow(6).has_point(d["pos"]):
				d["hit"].append(o.pid)
				_hit(o, d["owner"], int(signf(o.position.x - d["pos"].x)) if o.position.x != d["pos"].x else 1, "spell_disco")
	discs = discs.filter(func(d): return not d.get("dead", false))
	# S19 marreta-bumerangue: freia na ida, volta acelerando para o dono (atravessa tudo: retorno garantido)
	var c19: Dictionary = sc("S19")
	for h in hammers:
		h["t"] += dt
		var owner = main.robots[h["owner"]]
		h["rot"] += dt * 22.0 * h["dir"]
		if h["phase"] == "ida":
			var dec := float(c19["vel"]) * float(c19["vel"]) / (2.0 * float(c19["alcance_tiles"]) * T)
			h["vel"].x = move_toward(h["vel"].x, 0.0, dec * dt)
			h["vel"].y += 400.0 * dt
			h["pos"] += h["vel"] * dt
			if absf(h["vel"].x) < 40.0:
				h["phase"] = "volta"
				h["hit"].clear()
				Audio.play("marreta_vento", 1.3, -2.0)
		else:
			var to: Vector2 = hand(owner) - h["pos"]
			var sp := minf(float(c19["vel"]) * minf(h["t"], 1.6), 1400.0)
			h["pos"] += to.normalized() * minf(sp * dt, to.length())
			if to.length() < 28.0 or h["t"] > float(c19["max_s"]) or not owner.alive:
				h["dead"] = true
				owner.hammer_out = false
				owner.vis.s_sqx[0] = 1.15   # encaixa na mão
				Audio.play("chave", 0.8, 0.0)
		for o in main.robots:
			if o.pid != h["owner"] and o.alive and not (o.pid in h["hit"]) and o.rect().grow(10).has_point(h["pos"]):
				h["hit"].append(o.pid)
				_hit(o, h["owner"], int(signf(o.position.x - owner.position.x)) if o.position.x != owner.position.x else 1, "spell_bumerangue")
	hammers = hammers.filter(func(h): return not h.get("dead", false))
	# S20 mola saltitante
	var c20: Dictionary = sc("S20")
	for m in springs:
		m["t"] += dt
		m["sq"] = maxf(m["sq"] - dt * 5.0, 0.0)
		m["vel"].y += 1500.0 * dt
		var np: Vector2 = m["pos"] + m["vel"] * dt
		if _solid_at(np + Vector2(0, 14)) and m["vel"].y > 0.0:
			m["vel"].y = -absf(m["vel"].y) * float(c20["quique"])
			m["sq"] = 1.0
			Audio.play("pulo_mola", 1.6, -8.0)
			np = m["pos"]
		if _solid_at(np + Vector2(signf(m["vel"].x) * 16.0, 0)):
			m["dead"] = true   # obstáculo consome o tiro
			main.dust(np, 0.6)
		m["pos"] = np
		for o in main.robots:
			if o.pid != m["owner"] and o.alive and o.rect().grow(8).has_point(m["pos"]):
				if _hit(o, m["owner"], int(signf(m["vel"].x)), "spell_mola"):
					main.float_text(o.position + Vector2(0, -120), "BOING!", Color("#ff8a6a"))
					o.vis.s_sqx[0] = 0.5
					o.vis.s_sqy[0] = 1.5
					Audio.play("pulo_mola", 0.7, 4.0)
				m["dead"] = true
				break
		if m["t"] > float(c20["vida_s"]):
			m["dead"] = true
	springs = springs.filter(func(m): return not m.get("dead", false))

# ---------------------------------------------------------------- desenho da Etapa 2
func _draw_attack2() -> void:
	# S02: linha de mira fina tracejada durante o preparo; lente esquentando
	for r in main.robots:
		if not r.alive or not slot.has(r.pid):
			continue
		var s: Dictionary = slot[r.pid]
		if s["prep"] < 0.0:
			continue
		var k: float = s["prep"] / maxf(s["prep_len"], 0.01)
		match s["id"]:
			"S02":
				var a := hand(r) + Vector2(r.facing * 40.0, 0)
				var maxd := float(sc("S02")["alcance_tiles"]) * T
				var d := 0.0
				while d < maxd and not _solid_at(a + Vector2(r.facing * (d + 8.0), 0)):
					d += 8.0
				var n := int(d / 22.0)
				for i in n:
					var x0: float = a.x + r.facing * (i * 22.0 + fposmod(t * 120.0, 22.0))
					draw_line(Vector2(x0, a.y), Vector2(x0 + r.facing * 11.0, a.y), Color(1, 0.25, 0.2, 0.35 + 0.5 * k), 2.0, true)
				draw_circle(a, 5.0 + 9.0 * k, Color(1, 0.4, 0.25, 0.4 + 0.4 * k))
				draw_circle(a, 3.0 + 4.0 * k, Color(1, 0.95, 0.8, 0.9))
			"S04":
				pass
			"S20":   # mola comprimindo: anéis apertando na boca
				var m := hand(r) + Vector2(r.facing * 50.0, 0)
				var a0 := -PI / 2.0 if r.facing > 0 else PI / 2.0
				for j in 3:
					draw_arc(m, 14.0 + j * 6.0 - 6.0 * k, a0, a0 + PI, 10, Color(1, 1, 1, 0.5 * k), 2.0, true)
	# S04 marreta gigante dourada: ergue por cima da cabeça (para trás) e crava à frente
	for r in main.robots:
		if not r.alive or not slot.has(r.pid) or slot[r.pid]["id"] != "S04":
			continue
		var s4: Dictionary = slot[r.pid]
		var ang := 0.0
		var glow := 0.0
		if s4["prep"] >= 0.0:
			var k: float = s4["prep"] / maxf(s4["prep_len"], 0.01)
			ang = lerpf(0.3, -1.05, ease(k, 0.35))
			glow = k
		elif s4["fire"] >= 0.0 and s4["fire"] < 0.34:
			ang = lerpf(-1.05, 2.0, clampf(s4["fire"] / 0.05, 0.0, 1.0))
			glow = 1.0 - s4["fire"] / 0.34
		else:
			continue
		var grip: Vector2 = r.position + Vector2(r.facing * 14.0, -54.0)
		var tex := Data.tex("robo/marreta")
		var hsc := 0.62
		draw_set_transform(grip, ang * r.facing, Vector2(hsc * r.facing, hsc))
		draw_texture(tex, -Vector2(128, 224), Color(1.0, 0.86, 0.45))
		draw_set_transform(Vector2.ZERO)
		var head := grip + Vector2(0, -114.0).rotated(ang * r.facing)
		draw_circle(head, 18.0 + 14.0 * glow, Color(1, 0.85, 0.4, 0.35 * glow))
	# S02 feixe: contorno escuro, halo vermelho, miolo branco; some afinando
	for e in lasers:
		var u: float = e["t"] / 0.22
		var w := 18.0 * (1.0 - u * 0.8)
		draw_line(e["a"], e["b"], Color(0.16, 0.1, 0.18, 0.9 * (1.0 - u)), w + 6.0, true)
		draw_line(e["a"], e["b"], Color(1, 0.3, 0.2, 1.0 - u), w, true)
		draw_line(e["a"], e["b"], Color(1, 0.75, 0.4, 1.0 - u), w * 0.55, true)
		draw_line(e["a"], e["b"], Color(1, 1, 0.95, 1.0 - u), w * 0.25, true)
		draw_circle(e["b"], w, Color(1, 0.8, 0.4, 1.0 - u))
	for e in scorch:   # mancha de solda: branca → laranja → escura
		var u: float = e["t"] / 2.5
		var col := Color(1, 0.95, 0.7).lerp(Color(1, 0.45, 0.15), minf(u * 4.0, 1.0)).lerp(Color(0.2, 0.15, 0.15), clampf(u * 2.0 - 0.5, 0.0, 1.0))
		draw_circle(e["pos"], 9.0, Color(col, 1.0 - u))
		if u < 0.4 and fmod(t, 0.08) < 0.04:
			main.spark(e["pos"], 1)
	# S04 onda: rachadura brilhante correndo na laje + calombo
	var c4: Dictionary = sc("S04")
	for w in waves:
		var front: float = w["t"] * float(c4["vel"])
		var fade := clampf(1.0 - (w["t"] - 0.5) / 0.4, 0.0, 1.0)
		for dir in [-1.0, 1.0]:
			var lim: float = (w["r_end"] - w["x0"]) if dir > 0.0 else (w["x0"] - w["l_end"])
			var f := minf(front, lim)
			var pts := PackedVector2Array()
			var n := int(f / 14.0)
			for i in n + 1:
				var x: float = w["x0"] + dir * i * 14.0
				pts.append(Vector2(x, w["y"] + 3.0 + (4.0 if i % 2 == 0 else -2.0)))
			if pts.size() > 1:
				draw_polyline(pts, Color(1, 0.6, 0.2, fade), 6.0, true)
				draw_polyline(pts, Color(1, 0.95, 0.7, fade), 2.5, true)
			if front < lim:   # calombo da onda + pedrinhas pulando
				var fx: float = w["x0"] + dir * front
				draw_colored_polygon(PackedVector2Array([Vector2(fx - 26, w["y"]), Vector2(fx, w["y"] - 16), Vector2(fx + 26, w["y"])]), Color("#c9b49a"))
				for j in 3:
					draw_rect(Rect2(Vector2(fx - dir * (10 + j * 12), w["y"] - 18 - j * 8 - sin(t * 30 + j) * 6), Vector2(7, 6)), Color("#8a7a6a"))
			elif fade > 0.0:   # parou na borda/junta: faísca
				draw_circle(Vector2(w["x0"] + dir * lim, w["y"]), 8.0 * fade, Color(1, 0.85, 0.4, fade))
	# S05 rebites
	for rv in rivets:
		var tr: Array = rv["trail"]
		for i in tr.size():
			draw_circle(tr[i], 4.0 - i * 0.5, Color(1, 0.85, 0.4, 0.6 - i * 0.1))
		draw_set_transform(rv["pos"], rv["vel"].angle())
		draw_rect(Rect2(-12, -3, 14, 6), Color("#9aa4ae"))
		draw_circle(Vector2(4, 0), 6.0, Color("#c9d1d8"))
		draw_arc(Vector2(4, 0), 6.0, -PI / 2.0, PI / 2.0, 8, INK, 2.0, true)
		draw_set_transform(Vector2.ZERO)
	# S17 bate-estaca: sombra listrada no chão, pistão no alto, queda com achatamento, sobe
	var c17: Dictionary = sc("S17")
	var mark := float(c17["marca_s"])
	var tex17 := Data.tex("spells/s17_estaca")
	for p in piles:
		var hw := float(c17["largura_tiles"]) * T / 2.0
		var fy: float = p["floor_y"]
		var x: float = p["x"]
		var tt: float = p["t"]
		var top_y := fy - 5.5 * T
		if tt < mark + 0.08:
			var k := clampf(tt / mark, 0.0, 1.0)
			# faixa de aviso (zebrada) piscando mais rápido no fim
			var blink := fmod(t, 0.2 - 0.12 * k) < (0.1 - 0.06 * k)
			draw_set_transform(Vector2(x, fy), 0.0, Vector2(1.0, 0.25))
			draw_circle(Vector2.ZERO, hw * (0.6 + 0.4 * k), Color(0.16, 0.1, 0.18, 0.25 + 0.3 * k))
			draw_set_transform(Vector2.ZERO)
			for i in 4:
				var xx := x - hw + i * hw * 0.5
				draw_colored_polygon(PackedVector2Array([Vector2(xx, fy - 4), Vector2(xx + hw * 0.25, fy - 4), Vector2(xx + hw * 0.5, fy + 4), Vector2(xx + hw * 0.25, fy + 4)]), Color(0.95, 0.78, 0.29, 0.9 if blink else 0.5))
			draw_rect(Rect2(x - hw, fy - 5.5 * T, hw * 2.0, 5.5 * T), Color(1, 0.9, 0.3, 0.07 + 0.08 * k))
		# estaca: desce de cima; na queda estica, no impacto achata, depois sobe
		var drop := 0.0
		if tt < mark:
			drop = 0.0
		elif tt < mark + 0.08:
			drop = (tt - mark) / 0.08
		elif tt < mark + 0.45:
			drop = 1.0
		else:
			drop = 1.0 - (tt - mark - 0.45) / 0.45
		var pile_len := 40.0 + (fy - top_y - 40.0) * drop
		var sq := 1.0
		if tt >= mark + 0.08 and tt < mark + 0.2:
			sq = 1.0 + 0.3 * (1.0 - (tt - mark - 0.08) / 0.12)
		var a := clampf((mark + 0.9 - tt) / 0.2, 0.0, 1.0)
		var mod := Color(1, 1, 1, a)
		# caixa do pistão (região de cima da textura) e a estaca esticada (região do meio) + ponta
		draw_texture_rect_region(tex17, Rect2(x - 32, top_y - 50, 64, 50), Rect2(0, 0, 128, 96), mod)
		draw_texture_rect_region(tex17, Rect2(x - 16 * sq, top_y, 32 * sq, pile_len - 26), Rect2(32, 92, 64, 236), mod)
		draw_texture_rect_region(tex17, Rect2(x - 22 * sq, top_y + pile_len - 26, 44 * sq, 26), Rect2(20, 324, 88, 60), mod)
	# S18 disco girando com faíscas e rastro de serra
	var dtex := Data.tex("spells/s18_disco")
	for d in discs:
		for i in 3:
			var q: Vector2 = d["pos"] - d["vel"].normalized() * (12.0 + i * 12.0) if d["phase"] == "ida" else d["pos"]
			draw_arc(q, 20.0, d["rot"] + i, d["rot"] + i + 1.4, 8, Color(1, 1, 1, 0.4 - i * 0.12), 3.0, true)
		draw_set_transform(d["pos"], d["rot"])
		draw_texture_rect(dtex, Rect2(-22, -22, 44, 44), false)
		draw_set_transform(Vector2.ZERO)
	# S19 marreta girando com arco de rastro
	var htex := Data.tex("robo/marreta")
	for h in hammers:
		for i in 4:
			var aa: float = h["rot"] - i * 0.35 * h["dir"]
			draw_set_transform(h["pos"], aa, Vector2(0.55, 0.55))
			draw_texture(htex, -Vector2(128, 128), Color(1, 1, 1, 0.18 - i * 0.04))
		draw_set_transform(h["pos"], h["rot"], Vector2(0.55, 0.55))
		draw_texture(htex, -Vector2(128, 128))
		draw_set_transform(Vector2.ZERO)
		draw_arc(h["pos"], 46.0, h["rot"], h["rot"] + 1.6 * h["dir"], 12, Color(1, 1, 1, 0.5), 4.0, true)
	# S20 mola saltitante: espiral + para-choque vermelho, achata no quique
	for m in springs:
		var d := signf(m["vel"].x)
		var sq: float = m["sq"]
		draw_set_transform(m["pos"], 0.0, Vector2(1.0 + 0.3 * sq, 1.0 - 0.35 * sq))
		var pts := PackedVector2Array()
		for i in 13:
			pts.append(Vector2(-d * (18.0 - i * 2.4), (-9.0 if i % 2 == 0 else 9.0)))
		draw_polyline(pts, INK, 5.0, true)
		draw_polyline(pts, Color("#c9d1d8"), 2.5, true)
		draw_circle(Vector2(d * 14.0, 0), 12.0, INK)
		draw_circle(Vector2(d * 14.0, 0), 10.0, Color("#e8503a"))
		draw_circle(Vector2(d * 11.0, -4.0), 3.0, Color(1, 1, 1, 0.8))
		draw_set_transform(Vector2.ZERO)
