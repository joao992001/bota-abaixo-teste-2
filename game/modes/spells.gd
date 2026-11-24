extends Node2D
## SPELLS (Relatório 04): 1 slot por robô, caixa com a FAMÍLIA visível (a spell só aparece ao pegar), troca voluntária
## (segurar o botão de especial ~0,3 s sobre a caixa: o item antigo cai no chão para outro pegar), limpeza na eliminação,
## sorteio em 2 etapas (família → spell) com raridade e sem ajuda a quem perde. Números: data/modos.json → demolicao.spells.
## Etapa 1: S01 Punho Pneumático, S03 Canhão Criogênico, S06 Superímã, S10 Andaime Relâmpago, S11 Teleporte, S13 Armadura Fornalha.

const T := 64.0
const Kit := preload("res://ui/kit.gd")
const FAM_COR := {"ataque": Color("#f08a3d"), "controle": Color("#8a63d2"), "engenharia": Color("#f2c84b"), "transformacao": Color("#3fc1c9")}
const NOMES := {"S01": "PUNHO PNEUMÁTICO", "S03": "CANHÃO CRIOGÊNICO", "S06": "SUPERÍMÃ", "S10": "ANDAIME RELÂMPAGO",
	"S11": "TELEPORTE", "S13": "ARMADURA FORNALHA"}

var main: Node
var demo: Node
var cfg: Dictionary
var boxes: Array = []        # {fam, id, charges, pos, vy, t, land_t, block: {pid: s}, special}
var slot := {}               # pid -> {id, fam, charges, cd, prep, prep_len, fire, t, data}
var holds := {}              # pid -> {box, t}
var shots: Array = []        # S03 {pos, vel, owner, t}
var ice: Array = []          # S03 {rect, t, len}
var platforms: Array = []    # S10 {rect, body, t, len, owner, k}
var fists: Array = []        # S01 {owner, t, tip, hit: []}
var portals: Array = []      # S11 {a, b, t}
var pulses: Array = []       # S06 {pos, dir, t, repel}
var flames: Array = []       # S13 {owner, t}
var feedback: Array = []     # {pos, text, t}
var spawn_t := 0.0
var recent: Array = []
var draw_log: Array = []     # sorteios (testes): {fam, id}
var t := 0.0

func setup(m: Node, d: Node) -> void:
	main = m
	demo = d
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
			equip(best, b["id"], b["charges"])

# ---------------------------------------------------------------- slot
func equip(r, id: String, charges := -1) -> void:
	var s: Dictionary = sc(id)
	slot[r.pid] = {"id": id, "fam": s["familia"], "charges": int(s["cargas"]) if charges < 0 else charges, "cd": 0.0,
		"prep": -1.0, "prep_len": 0.0, "fire": -1.0, "t": -1.0, "data": {}}
	main.float_text(r.position + Vector2(0, -130), NOMES.get(id, id) + "!", FAM_COR[s["familia"]])
	Audio.play("item", 1.2)
	r.vis.s_sqy[0] = 1.18   # pulinho de alegria
	r.vis.s_sqx[0] = 0.86

## Elimina/limpa: fim de transformação, sem guardar nada para o respawn.
func clear(r) -> void:
	if slot.has(r.pid) and slot[r.pid]["id"] == "S13" and slot[r.pid]["t"] > 0.0:
		_end_armor(r, false)
	slot.erase(r.pid)
	holds.erase(r.pid)

func has_spell(r) -> bool:
	return slot.has(r.pid)

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
	# o antigo cai no chão (com as cargas que sobraram) e o dono não pega de volta na hora
	var drop := {"fam": old["fam"], "id": old["id"], "charges": old["charges"], "pos": r.position + Vector2(-r.facing * 50.0, -40.0),
		"vy": -260.0, "t": 0.0, "land_t": 9.0, "block": {r.pid: float(cfg["caixa"]["anti_recaptura_s"])}, "special": false}
	boxes.erase(b)
	boxes.append(drop)
	slot.erase(r.pid)
	equip(r, b["id"], b["charges"])
	Audio.play("alavanca", 1.2)

func _spend(r, s: Dictionary) -> void:
	s["charges"] -= 1
	if s["charges"] <= 0 and s["id"] != "S13":
		s["empty_t"] = 0.35   # some do slot depois da animação de recolher

func _fail(r, text: String) -> void:
	feedback.append({"pos": r.position + Vector2(0, -120), "text": text, "t": 0.0})
	Audio.play("menu_negado", 1.0, -6.0)

# ---------------------------------------------------------------- usar
func use(r) -> void:
	var s: Dictionary = slot[r.pid]
	if s["cd"] > 0.0 or s["prep"] >= 0.0 or s.has("empty_t"):
		return
	var c: Dictionary = sc(s["id"])
	match s["id"]:
		"S01", "S03":
			s["prep"] = 0.0
			s["prep_len"] = float(c["preparo"])
			Audio.play("pistao_aviso" if s["id"] == "S01" else "gelo", 1.3, -4.0)
		"S06":
			_magnet(r, s, PlayerInput.held(r.pid, "up"))
		"S10":
			var pr := scaffold_rect(r)
			if not scaffold_ok(r, pr):
				_fail(r, "SEM ESPAÇO")
				return
			_build_scaffold(r, pr)
			s["fire"] = 0.0
			_spend(r, s)
		"S11":
			var dest = teleport_dest(r)
			if dest == null:
				_fail(r, "DESTINO BLOQUEADO")
				return
			_teleport(r, dest)
			s["fire"] = 0.0
			_spend(r, s)
		"S13":
			if s["t"] < 0.0:
				_start_armor(r, s)
			else:
				_armor_fire(r, s)

func _fire(r, s: Dictionary) -> void:
	var c: Dictionary = sc(s["id"])
	s["fire"] = 0.0
	s["cd"] = float(c.get("intervalo_s", 0.3))
	var hand: Vector2 = r.position + Vector2(r.facing * 34.0, -40.0)
	if s["id"] == "S01":
		# punho estica numa faixa reta até bater em parede sólida; acerta todos os alinhados (1 vez cada)
		var tip := hand
		var maxd := float(c["alcance_tiles"]) * T
		var step := 12.0
		var d := 0.0
		while d < maxd:
			var nx: Vector2 = hand + Vector2(r.facing * (d + step), 0)
			if main.level.is_solid(Vector2i(int(floor(nx.x / T)), int(floor(nx.y / T)))):
				break
			d += step
			tip = nx
		fists.append({"owner": r.pid, "t": 0.0, "tip": tip, "from": hand, "dir": r.facing, "hit": []})
		Audio.play("arremesso", 0.7, 2.0)
		main.shake(5.0)
		_spend(r, s)
	elif s["id"] == "S03":
		shots.append({"pos": hand, "vel": Vector2(r.facing * float(c["vel"]), 0), "owner": r.pid, "t": 0.0})
		Audio.play("gelo", 1.6, -2.0)
		r.own_vx -= r.facing * 120.0   # coice
		_spend(r, s)

## S06: pulso do ímã (atrai; com ▲, repele) nos robôs à frente, com força que cai com a distância.
func _magnet(r, s: Dictionary, repel: bool) -> void:
	var c: Dictionary = sc("S06")
	s["fire"] = 0.0
	s["cd"] = float(c["intervalo_s"])
	var rng := float(c["alcance_tiles"]) * T
	var orig: Vector2 = r.rect().get_center()
	pulses.append({"pos": orig + Vector2(r.facing * 40.0, 0), "dir": r.facing, "t": 0.0, "repel": repel})
	Audio.play("ima", 0.9, -2.0)
	for o in main.robots:
		if o == r or not o.alive or o.invuln > 0.0 or o.guard_t > 0.0:
			continue
		var oc: Vector2 = o.rect().get_center()
		var dx: float = (oc.x - orig.x) * r.facing
		if dx < -24.0 or absf(oc.y - orig.y) > 110.0 or orig.distance_to(oc) > rng:
			continue
		var k := 1.0 - 0.5 * orig.distance_to(oc) / rng
		var f := float(c["forca"]) * k
		var toward := -signf(oc.x - orig.x) if not repel else signf(oc.x - orig.x)
		o.own_vx = toward * f
		o.velocity.y = minf(o.velocity.y, -float(c["levanta"]))
		o.recover_len = float(c["descontrole_s"])
		o.recover_t = o.recover_len
		o.last_hit = 0.0
		o.last_attacker = r.pid
		o.last_cause = "ímã"
		o.vis.hurt(0.3, int(toward))
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
	platforms.append({"rect": pr, "body": body, "t": float(c["duracao_s"]), "len": float(c["duracao_s"]), "owner": r.pid, "k": 0.0})
	Audio.play("alavanca", 1.5)
	main.dust(pr.get_center(), 0.8)

func _remove_platform(p: Dictionary) -> void:
	if is_instance_valid(p["body"]):
		p["body"].queue_free()
	platforms.erase(p)
	main.dust(p["rect"].get_center(), 0.7)

## S11: destino à frente (ou ▲ para cima); tenta mais perto se o ponto estiver ocupado. null = nenhum lugar livre.
func teleport_dest(r):
	var c: Dictionary = sc("S11")
	var up := PlayerInput.held(r.pid, "up")
	for k in [1.0, 0.75, 0.5]:
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

func _teleport(r, dest: Vector2) -> void:
	var c: Dictionary = sc("S11")
	portals.append({"a": r.position + Vector2(0, -36), "b": dest + Vector2(0, -36), "t": 0.0})
	for k in 8:
		main.spark(r.position + Vector2(randf_range(-20, 20), randf_range(-70, -10)), 1)
	r.position = dest
	r.reset_physics_interpolation()
	r.velocity = Vector2(0, minf(r.velocity.y, 0.0) * 0.3)
	r.own_vx = 0.0
	r.atk_cd = maxf(r.atk_cd, float(c["recupera_s"]))
	r.vis.s_sqx[0] = 0.4   # reaparece "se montando": estica e assenta
	r.vis.s_sqy[0] = 1.5
	Audio.play("teleporte", 1.1, -2.0)

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

func _armor_fire(r, s: Dictionary) -> void:
	var c: Dictionary = sc("S13")
	if s["charges"] <= 0:
		_fail(r, "SEM CARVÃO")
		return
	s["fire"] = 0.0
	s["cd"] = float(c["intervalo_s"])
	s["charges"] -= 1
	flames.append({"owner": r.pid, "t": 0.0, "dir": r.facing})
	Audio.play("chama", 0.9, 0.0)
	var reach := float(c["fogo_alcance_tiles"]) * T
	var rr: Rect2 = r.rect()
	var cone := Rect2(rr.get_center().x if r.facing > 0 else rr.get_center().x - reach, rr.position.y - 8.0, reach, rr.size.y + 8.0)
	for o in main.robots:
		if o != r and o.alive and cone.intersects(o.rect()):
			o.take_hit(r.facing, "spell_fogo", r.pid)

func _end_armor(r, natural: bool) -> void:
	r.spell_speed = 1.0
	r.spell_push = 1.0
	if slot.has(r.pid):
		slot[r.pid]["t"] = -1.0
	# as placas voam (a armadura desmonta)
	var parts := [{"tex": [Data.tex("spells/s13_frente")], "rect": Rect2(-36, -31, 72, 62), "mod": Color.WHITE},
		{"tex": [Data.tex("spells/s13_costas")], "rect": Rect2(-36, -31, 72, 62), "mod": Color.WHITE}]
	var dbr: Node2D = main.Debris.new()
	dbr.setup(parts, r.position + Vector2(0, -20), r.facing, Vector2(0, -200))
	main.world.add_child(dbr)
	main.dust(r.position + Vector2(0, -30), 1.2)
	Audio.play("caixote_quebra", 1.2, -2.0)
	if natural:
		slot.erase(r.pid)

# ---------------------------------------------------------------- quadro a quadro
func update(dt: float, alive: Array) -> void:
	t += dt
	_update_boxes(dt, alive)
	_update_holds(dt)
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
		if s["id"] == "S13" and s["t"] > 0.0:
			s["data"]["assemble"] = minf(float(s["data"].get("assemble", 0.0)) + dt / 0.35, 1.0)
			s["t"] -= dt
			if s["t"] <= 0.0:
				_end_armor(r, true)
	_update_fists(dt)
	_update_shots(dt)
	for i in ice:
		i["t"] -= dt
	ice = ice.filter(func(i): return i["t"] > 0.0)
	for p in platforms.duplicate():
		p["t"] -= dt
		p["k"] = minf(p["k"] + dt / 0.25, 1.0)
		if p["t"] <= 0.0:
			_remove_platform(p)
	for a in [portals, pulses, flames, feedback]:
		for e in a:
			e["t"] += dt
	portals = portals.filter(func(e): return e["t"] < 0.4)
	pulses = pulses.filter(func(e): return e["t"] < 0.45)
	flames = flames.filter(func(e): return e["t"] < 0.35)
	feedback = feedback.filter(func(e): return e["t"] < 1.0)
	queue_redraw()

func _update_fists(dt: float) -> void:
	for f in fists:
		f["t"] += dt
		var ext := clampf(f["t"] / 0.1, 0.0, 1.0)
		var tip: Vector2 = f["from"].lerp(f["tip"], ext)
		var band := Rect2(minf(f["from"].x, tip.x), tip.y - 26.0, absf(tip.x - f["from"].x) + 24.0, 52.0)
		for o in main.robots:
			if o.pid == f["owner"] or not o.alive or o.pid in f["hit"]:
				continue
			if band.intersects(o.rect()):
				f["hit"].append(o.pid)
				if o.take_hit(int(f["dir"]), "spell_punho", f["owner"]):
					main.impact_fx(o.rect().get_center(), int(f["dir"]), 1.0)
					o.hitstop = 0.08
		if ext >= 1.0 and not f.get("wall", false):
			f["wall"] = true
			var ct = demo.canteiro
			if ct != null and is_instance_valid(ct):
				for p in ct.parts:
					if not p["fallen"] and p["state"] >= 1 and p["rect"].grow(8).has_point(f["tip"] + Vector2(int(f["dir"]) * 10.0, 0)):
						ct.damage(p, 1, f["tip"])   # rompe só peça já fragilizada
			main.spark(f["tip"], 4)
	fists = fists.filter(func(f): return f["t"] < 0.35)

func _update_shots(dt: float) -> void:
	var c: Dictionary = sc("S03")
	for s in shots:
		s["t"] += dt
		s["pos"] += s["vel"] * dt
		var hit = null
		for o in main.robots:
			if o.pid != s["owner"] and o.alive and o.rect().grow(6).has_point(s["pos"]):
				hit = o
				break
		var wall: bool = main.level.is_solid(Vector2i(int(floor(s["pos"].x / T)), int(floor(s["pos"].y / T))))
		if hit != null:
			if hit.take_hit(int(signf(s["vel"].x)), "spell_gelo", s["owner"]):
				hit.slow_t = float(c["lento_s"])
			_ice_at(hit.position)
			s["dead"] = true
		elif wall or s["t"] > float(c["alcance_tiles"]) * T / float(c["vel"]):
			_ice_at(s["pos"])
			s["dead"] = true
		if s.get("dead", false):
			for k in 6:
				main.spark(s["pos"], 1)
			Audio.play("gelo", 1.2, -6.0)
	shots = shots.filter(func(s): return not s.get("dead", false))

## Faixa de gelo no chão embaixo de um ponto (procura o chão até 4 tiles abaixo).
func _ice_at(p: Vector2) -> void:
	var c: Dictionary = sc("S03")
	for k in 5:
		var cell := Vector2i(int(floor(p.x / T)), int(floor(p.y / T)) + k)
		if main.level.is_solid(cell):
			var w := float(c["gelo_tiles"]) * T
			ice.append({"rect": Rect2(p.x - w / 2.0, cell.y * T - 10.0, w, 16.0), "t": float(c["gelo_s"]), "len": float(c["gelo_s"])})
			return

## Aderência no chão (gelo escorrega): o robô multiplica a aceleração por isto.
func grip_at(r) -> float:
	for i in ice:
		if i["rect"].grow_individual(0, 6, 0, 6).has_point(r.position):
			return float(sc("S03")["gelo_aderencia"])
	return 1.0

## Para o desenho do robô (robot_visual): arma na mão, preparação, disparo, armadura.
func flags(r) -> Dictionary:
	if not slot.has(r.pid):
		return {}
	var s: Dictionary = slot[r.pid]
	var out := {"spell": s["id"], "fire": s["fire"], "prep": (s["prep"] / maxf(s["prep_len"], 0.01)) if s["prep"] >= 0.0 else -1.0}
	if s["id"] == "S13":
		out["armor"] = s["t"] > 0.0
		out["assemble"] = float(s["data"].get("assemble", 0.0))
		out["armor_end"] = clampf(1.0 - s["t"] / 1.2, 0.0, 1.0) if s["t"] > 0.0 else 0.0
	for f in fists:
		if f["owner"] == r.pid:
			out["fist"] = clampf(f["t"] / 0.1, 0.0, 1.0) * (1.0 - clampf((f["t"] - 0.15) / 0.2, 0.0, 1.0))
			out["fist_len"] = absf(f["tip"].x - f["from"].x)
	if s.has("empty_t"):
		out["fading"] = true
	return out

## HUD: {id, fam, charges, frac} do jogador (ou vazio).
func hud_info(pid: int) -> Dictionary:
	if not slot.has(pid):
		return {}
	var s: Dictionary = slot[pid]
	var frac := 1.0
	if s["id"] == "S13" and s["t"] > 0.0:
		frac = s["t"] / float(sc("S13")["duracao_s"])
	return {"id": s["id"], "fam": s["fam"], "charges": s["charges"], "frac": frac, "nome": NOMES.get(s["id"], s["id"])}

# ---------------------------------------------------------------- desenho (mundo)
func _draw() -> void:
	# gelo
	for i in ice:
		var a := clampf(i["t"] / 0.6, 0.0, 1.0)
		var r: Rect2 = i["rect"]
		draw_texture_rect(Data.tex("spells/s03_gelo"), Rect2(r.position + Vector2(0, -4), Vector2(r.size.x, 24)), false, Color(1, 1, 1, 0.9 * a))
	# andaimes relâmpago (abre desdobrando, pisca antes de dobrar)
	for p in platforms:
		var r: Rect2 = p["rect"]
		var blink: bool = p["t"] < 1.0 and fmod(t, 0.2) < 0.1
		var k: float = p["k"]
		var w: float = r.size.x * (0.3 + 0.7 * k)
		var rr := Rect2(r.get_center().x - w / 2.0, r.position.y, w, 56.0 * (0.5 + 0.5 * k))
		draw_texture_rect(Data.tex("spells/s10_andaime"), rr, false, Color(1, 1, 1, 0.45 if blink else 1.0))
	# caixas: quicam ao pousar, flutuam, brilham com a cor da família; a especial desce de paraquedas
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
		# estrelinha girando
		var sa: float = t * 2.0 + b["pos"].x
		var sp: Vector2 = p + Vector2.from_angle(sa) * 46.0
		draw_line(sp - Vector2(4, 0), sp + Vector2(4, 0), Color("#fff4c8"), 2.0, true)
		draw_line(sp - Vector2(0, 4), sp + Vector2(0, 4), Color("#fff4c8"), 2.0, true)
	# prévias (holograma): andaime e destino do teleporte, só para quem tem a spell
	for r in main.robots:
		if not r.alive or not slot.has(r.pid):
			continue
		var s: Dictionary = slot[r.pid]
		if s["id"] == "S10":
			var pr := scaffold_rect(r)
			var ok := scaffold_ok(r, pr)
			draw_texture_rect(Data.tex("spells/s10_holo"), Rect2(pr.position, Vector2(pr.size.x, 56)), false, Color(1, 1, 1, 0.75) if ok else Color(1, 0.35, 0.35, 0.6))
		elif s["id"] == "S11":
			var dest = teleport_dest(r)
			if dest != null:
				var gc := Color(0.25, 0.76, 0.79, 0.35 + 0.15 * sin(t * 8.0))
				draw_rect(Rect2(dest + Vector2(-26, -76), Vector2(52, 76)), gc)
				draw_set_transform(dest + Vector2(0, -36), t * 2.0, Vector2(0.6, 0.6))
				draw_texture_rect(Data.tex("spells/s11_portal"), Rect2(-40, -40, 80, 80), false, Color(1, 1, 1, 0.5))
				draw_set_transform(Vector2.ZERO)
	# troca segurando: anel verde enchendo sobre a cabeça
	for pid in holds:
		var h: Dictionary = holds[pid]
		var r = main.robots[pid]
		var k := clampf(h["t"] / float(cfg["caixa"]["troca_s"]), 0.0, 1.0)
		var c: Vector2 = r.position + Vector2(0, -150)
		draw_arc(c, 22.0, 0, TAU, 28, Color(0.85, 0.87, 0.9, 0.9), 7.0, true)
		draw_arc(c, 22.0, -PI / 2.0, -PI / 2.0 + TAU * k, 28, Color("#5cc45c"), 7.0, true)
		draw_texture_rect(Data.tex("spells/icone_" + h["box"]["fam"]), Rect2(c - Vector2(13, 13), Vector2(26, 26)), false)
	# punhos esticando (o tubo vira um braço sanfonado até a luva)
	for f in fists:
		var ext := clampf(f["t"] / 0.1, 0.0, 1.0) * (1.0 - clampf((f["t"] - 0.15) / 0.2, 0.0, 1.0))
		var from: Vector2 = f["from"]
		var tip: Vector2 = from.lerp(f["tip"], ext)
		# sanfona: zigue-zague grosso (contorno escuro + miolo laranja), dobras mais apertadas perto do robô
		var n := maxi(int(absf(tip.x - from.x) / 11.0), 2)
		var top := PackedVector2Array()
		var bot := PackedVector2Array()
		for k in n + 1:
			var u := float(k) / n
			var x: float = lerpf(from.x, tip.x, u)
			var hh := (11.0 if k % 2 == 0 else 6.0) + 3.0 * u
			top.append(Vector2(x, from.y - hh))
			bot.append(Vector2(x, from.y + hh))
		var poly := top.duplicate()
		bot.reverse()
		poly.append_array(bot)
		draw_colored_polygon(poly, Color("#2a1a2e"))
		var inner := PackedVector2Array()
		for q in top:
			inner.append(q + Vector2(0, 2.5))
		for q in bot:
			inner.append(q - Vector2(0, 2.5))
		draw_colored_polygon(inner, Color("#d9622b"))
		for k in range(1, n, 2):
			var x: float = lerpf(from.x, tip.x, float(k) / n)
			draw_line(Vector2(x, from.y - 5), Vector2(x, from.y + 5), Color("#9e3f17"), 2.0)
		draw_set_transform(tip, 0.0, Vector2(float(f["dir"]), 1.0))
		draw_texture_rect(Data.tex("spells/s01_luva"), Rect2(-10, -25, 50, 40), false)
		draw_set_transform(Vector2.ZERO)
		if ext > 0.6:
			for k in 3:
				draw_line(tip + Vector2(-float(f["dir"]) * (30 + k * 18), -14 + k * 14), tip + Vector2(-float(f["dir"]) * (70 + k * 18), -14 + k * 14), Color(1, 1, 1, 0.8 * ext), 3.0)
	# tiros de gelo (cristal girando com rastro)
	for s in shots:
		for k in 4:
			draw_circle(s["pos"] - s["vel"].normalized() * (12.0 + k * 10.0), 9.0 - k * 2.0, Color(0.62, 0.89, 0.96, 0.5 - k * 0.1))
		draw_set_transform(s["pos"], s["t"] * 14.0)
		draw_texture_rect(Data.tex("spells/s03_projetil"), Rect2(-20, -20, 40, 40), false)
		draw_set_transform(Vector2.ZERO)
	# pulsos do ímã (ondas que saem ou entram)
	for e in pulses:
		var k: float = e["t"] / 0.45
		var col := Color(0.85, 0.29, 0.35)
		for j in 4:
			var kk := fposmod(k * 1.6 + j * 0.25, 1.0)
			var rad := (24.0 + 120.0 * kk) if e["repel"] else (144.0 - 120.0 * kk)
			var a0 := -0.7 if e["dir"] > 0 else PI - 0.7
			draw_arc(e["pos"], rad, a0, a0 + 1.4, 14, Color(col, 0.75 * (1.0 - k) * (1.0 - kk * 0.5)), 3.0, true)
		# faíscas puxadas (ou empurradas) pela força
		for j in 6:
			var u := fposmod(k * 2.0 + j * 0.17, 1.0)
			var dd: float = (1.0 - u) * 150.0 if not e["repel"] else u * 150.0
			var ang := (j - 2.5) * 0.18
			var q: Vector2 = e["pos"] + Vector2(e["dir"] * cos(ang), sin(ang)) * dd
			draw_line(q, q + Vector2(e["dir"] * (-8.0 if not e["repel"] else 8.0), 0), Color(1, 0.9, 0.6, 1.0 - k), 2.0, true)
	# portais do teleporte (abre na saída e na chegada)
	for e in portals:
		var k: float = e["t"] / 0.4
		var s := sin(PI * k) * 1.1
		for at in [e["a"], e["b"]]:
			draw_set_transform(at, e["t"] * 9.0, Vector2(s, s))
			draw_texture_rect(Data.tex("spells/s11_portal"), Rect2(-40, -40, 80, 80), false)
			draw_set_transform(Vector2.ZERO)
		var n := 6
		for j in n:
			var q: Vector2 = e["a"].lerp(e["b"], clampf(k * 1.4 - j * 0.08, 0.0, 1.0))
			draw_circle(q + Vector2(0, sin(j * 2.0) * 10.0), 4.0, Color("#c9d1d8"))
	# fogo da armadura (cone de chamas cartoon)
	for e in flames:
		var r = main.robots[e["owner"]]
		var k: float = e["t"] / 0.35
		var grow := minf(k * 4.0, 1.0)
		var reach := float(sc("S13")["fogo_alcance_tiles"]) * T * (0.35 + 0.65 * grow)
		var o: Vector2 = r.position + Vector2(e["dir"] * 30.0, -40.0)
		var a := clampf((1.0 - k) * 1.6, 0.0, 1.0)
		var d := float(e["dir"])
		# 3 camadas de chama com línguas onduladas (laranja → amarelo → quase branco)
		var layers := [[Color(0.91, 0.36, 0.17), 1.0, 30.0], [Color(1.0, 0.66, 0.24), 0.8, 21.0], [Color(1.0, 0.93, 0.66), 0.55, 11.0]]
		for L in layers:
			var len: float = reach * float(L[1])
			var w: float = L[2]
			var pts := PackedVector2Array()
			var n := 9
			for i in n + 1:   # borda de cima, com línguas
				var u := float(i) / n
				var bulge := sin(u * PI) * w * (1.0 - 0.35 * u)
				var lick := sin(u * 18.0 - t * 40.0 + float(e["owner"])) * 5.0 * u
				pts.append(o + Vector2(d * len * u, -bulge - lick))
			pts.append(o + Vector2(d * (len + 14.0), sin(t * 30.0) * 4.0))   # ponta
			for i in range(n, -1, -1):
				var u := float(i) / n
				var bulge := sin(u * PI) * w * (1.0 - 0.35 * u)
				var lick := sin(u * 16.0 - t * 36.0 + 1.7) * 5.0 * u
				pts.append(o + Vector2(d * len * u, bulge + lick))
			draw_colored_polygon(pts, Color(L[0], a))
		# fagulhas e fumaça saindo da ponta
		for j in 5:
			var u := fposmod(k * 2.5 + j * 0.21, 1.0)
			var q: Vector2 = o + Vector2(d * reach * (0.6 + 0.5 * u), -18.0 * u + sin(j * 2.3) * 14.0)
			draw_circle(q, 2.5, Color(1, 0.85, 0.4, a * (1.0 - u)))
		draw_circle(o + Vector2(d * reach * 1.05, -24.0 * k), 10.0 + 14.0 * k, Color(0.35, 0.3, 0.32, 0.35 * (1.0 - k)))
	for e in feedback:
		var a: float = 1.0 - e["t"]
		Kit.text(self, e["pos"] + Vector2(-160, -e["t"] * 30.0), e["text"], 26, Color(1, 0.4, 0.4, a), HORIZONTAL_ALIGNMENT_CENTER, 320, 6, Color(0.16, 0.1, 0.18, a))
