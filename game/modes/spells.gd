extends Node2D
## SPELLS (Relatório 04): 1 slot por robô, caixa com a FAMÍLIA visível (a spell só aparece ao pegar), troca voluntária
## (segurar o botão de especial ~0,3 s sobre a caixa: o item antigo cai no chão para outro pegar), limpeza na eliminação,
## sorteio em 2 etapas (família → spell) com raridade e sem ajuda a quem perde. Números: data/modos.json → demolicao.spells.
## PADRÃO (lições aprovadas pelo usuário): ver docs/ESTADO.md → "PADRÃO DAS SPELLS".
## Etapa 1: S01 Punho Pneumático, S03 Canhão Criogênico, S06 Superímã, S10 Andaime Relâmpago, S11 Teleporte, S13 Armadura Fornalha.

const T := 64.0
const Kit := preload("res://ui/kit.gd")
const RobotVis := preload("res://player/robot_visual.gd")
const FAM_COR := {"ataque": Color("#f08a3d"), "controle": Color("#8a63d2"), "engenharia": Color("#f2c84b"), "transformacao": Color("#3fc1c9")}
const NOMES := {"S01": "PUNHO PNEUMÁTICO", "S03": "CANHÃO CRIOGÊNICO", "S06": "SUPERÍMÃ", "S10": "ANDAIME RELÂMPAGO",
	"S11": "TELEPORTE", "S13": "ARMADURA FORNALHA", "S02": "LASER DE CORTE", "S04": "MARRETA SÍSMICA", "S05": "REBITEIRA RICOCHETE",
	"S17": "BATE-ESTACA", "S18": "DISCO DE CORTE", "S19": "MARRETA-BUMERANGUE", "S20": "CANHÃO DE MOLAS",
	"S07": "TURBOVENTILADOR", "S08": "GANCHO DE ARRASTO", "S21": "LAÇO DE ENERGIA", "S12": "CARGA REMOTA",
	"S25": "PONTE DOBRÁVEL", "S27": "CONTROLE REMOTO", "S28": "ESCUDO DE SOLDA"}

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
var rocks: Array = []        # S04 pedrinhas voando {pos, vel, t, rot, size}
var tings: Array = []        # S05 brilho de ricochete / boca da rebiteira {pos, t, big}
var pile_aims := {}          # S17: pid -> {x, t} (segura para mirar onde a estaca cai)
var hooks: Array = []        # S08 {owner, pos, vel, phase, t, anchor, dir}
var lassos: Array = []       # S21 tiro {owner, pos, vel, t}
var tethers: Array = []      # S21 {a, b, t}
var snaps: Array = []        # S21 elástico estalando ao soltar {a, b, t}
var charges_placed: Array = []   # S12 {owner, pos, t, armed}
var bridges: Array = []      # S25 {rect, body, t, len, k, owner, dir, x0, y}
var drops: Array = []        # S27 {part, owner, t, hit}
var shields: Array = []      # S28 {rect, t, hp, k, owner, flash}
var ext_v := {}              # empurrão externo suave por robô (vento, elástico): pid -> Vector2, aplicado via push_vx
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
	hooks = hooks.filter(func(h): return h["owner"] != r.pid)
	charges_placed = charges_placed.filter(func(c): return c["owner"] != r.pid)
	if slot.has(r.pid) and slot[r.pid]["id"] == "S13" and slot[r.pid]["t"] > 0.0:
		_end_armor(r, false)
	_stop_channel(r)
	slot.erase(r.pid)
	holds.erase(r.pid)
	aims.erase(r.pid)
	pile_aims.erase(r.pid)
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
## Bico da arma no mundo (mesma conta do desenho em robot_visual: mão mirando + bico − pega, na escala da arma).
func muzzle(r, id: String) -> Vector2:
	var spec: Array = RobotVis.SPELL_TOOLS[id]
	var tx := Data.tex("spells/" + spec[0])
	var dsz := Vector2(tx.get_width(), tx.get_height()) / 2.0
	var a := aim_local(r)
	var loc: Vector2 = RobotVis.SHOULDER + Vector2.from_angle(a) * RobotVis.ARM + ((spec[3] - spec[2]) * spec[1] / dsz).rotated(a)
	return r.position + Vector2(r.facing * loc.x, loc.y)

# ---------------------------------------------------------------- mira em 8 direções (padrão de todas as armas)
## Direção da mira agora: ▲/▼ (▼ só no ar) somam com ◄►; sem nada, para a frente. Bots miram no rival mais perto.
func aim_vec(r) -> Vector2:
	if _is_bot(r.pid):
		return _bot_aim(r)
	var up := PlayerInput.held(r.pid, "up")
	var dn: bool = PlayerInput.held(r.pid, "down") and not r.is_on_floor()
	var ax := PlayerInput.axis_x(r.pid)
	var sx := 0 if absf(ax) < 0.4 else int(signf(ax))
	var vy := -1 if up else (1 if dn else 0)
	if vy == 0:
		return Vector2(sx if sx != 0 else r.facing, 0)
	if sx == 0:
		return Vector2(0, vy)
	return Vector2(sx, vy).normalized()

func _bot_aim(r) -> Vector2:
	var best = null
	var bd := 1e9
	for o in main.robots:
		if o != r and o.alive:
			var d: float = o.position.distance_to(r.position)
			if d < bd:
				bd = d
				best = o
	if best == null:
		return Vector2(r.facing, 0)
	var v: Vector2 = best.rect().get_center() - r.rect().get_center()
	var ang := snappedf(v.angle(), PI / 4.0)
	var out := Vector2.from_angle(ang).round()
	if out.y > 0.0 and r.is_on_floor():
		out = Vector2(signf(v.x) if v.x != 0.0 else r.facing, 0)
	return out.normalized() if out != Vector2.ZERO else Vector2(r.facing, 0)

## Mira guardada na spell (atualiza no preparo; gira aos poucos nas de segurar). Vira o robô para o lado da mira.
func _set_aim(r, s: Dictionary, v: Vector2, turn := -1.0, dt := 0.0) -> void:
	var cur: Vector2 = s.get("aim", Vector2(r.facing, 0))
	if turn > 0.0:
		var a := cur.angle()
		v = Vector2.from_angle(rotate_toward(a, v.angle(), turn * dt))
	s["aim"] = v
	if absf(v.x) > 0.1:
		r.facing = int(signf(v.x))

## Ângulo da mira no espaço do robô (0 = frente, −π/2 = cima, π/2 = baixo).
func aim_local(r) -> float:
	if not slot.has(r.pid):
		return 0.0
	var v: Vector2 = slot[r.pid].get("aim", Vector2(r.facing, 0))
	return atan2(v.y, v.x * r.facing) if absf(v.x) > 0.01 else atan2(v.y, 0.0)

func aim_dir(r) -> Vector2:
	var a := aim_local(r)
	return Vector2(r.facing * cos(a), sin(a))

## Sólido de verdade (para tiros e feixes): paredes, chão, blocos e a laje do Canteiro. Plataformas vazadas
## (andaimes, vigas, tábuas, ponte, andaime relâmpago) NÃO param tiros.
const HARD_CH := ["#", "o", "I", "d", "T", "<", ">", "F", "f", "P", "B", "a", "D", "J"]
func _hard_at(p: Vector2) -> bool:
	var lv = main.level
	var c := Vector2i(int(floor(p.x / T)), int(floor(p.y / T)))
	if (c.x < 0 or c.y < 0 or c.x >= lv.cols or c.y >= lv.rows):
		return not lv.props.has("ko")
	if lv.ch_at(c) in HARD_CH:
		return true
	var ct = demo.canteiro
	if ct != null and is_instance_valid(ct):
		for pt in ct.parts:
			if pt["kind"] == "laje" and not pt["fallen"] and pt["rect"].has_point(p):
				return true
	return false

## Onde a garra do gancho/carga grudam: sólido de verdade OU qualquer plataforma (é assim que se sobe).
func _grab_at(p: Vector2) -> bool:
	if _hard_at(p) or _solid_at(p) or main.level.ch_at(Vector2i(int(floor(p.x / T)), int(floor(p.y / T)))) == "=":
		return true
	for pl in platforms:
		if pl["rect"].grow(4).has_point(p):
			return true
	for br in bridges:
		if br["rect"].grow(4).has_point(p):
			return true
	return false

## Segmento a→b encosta no retângulo (com folga rad)?
func _seg_rect(a: Vector2, b: Vector2, rr: Rect2, rad: float) -> bool:
	var g := rr.grow(rad)
	var n := maxi(int(a.distance_to(b) / 10.0), 1)
	for i in n + 1:
		if g.has_point(a.lerp(b, float(i) / n)):
			return true
	return false

func hand(r) -> Vector2:
	return r.position + Vector2(r.facing * 32.0, -40.0)

# ---------------------------------------------------------------- usar
func use(r) -> void:
	var s: Dictionary = slot[r.pid]
	if s["cd"] > 0.0 or s["prep"] >= 0.0 or s.has("empty_t") or s["channel"]:
		return
	var c: Dictionary = sc(s["id"])
	_set_aim(r, s, aim_vec(r))
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
			if _is_bot(r.pid):
				_drop_pile(r, s, r.position.x + r.facing * float(c["distancia_tiles"]) * T)
			else:   # segura: marca no chão anda com o direcional; solta: a estaca desce lá
				s["channel"] = true
				pile_aims[r.pid] = {"x": r.position.x + r.facing * float(c["distancia_tiles"]) * T, "t": 0.0}
				r.spell_lock = true
				Audio.play("alarme", 1.8, -12.0)
		"S18":
			for d in discs:
				if d["owner"] == r.pid:
					return   # um disco por vez
			_throw_disc(r, s)
		"S19":
			if r.hammer_out:
				return
			_throw_hammer(r, s)
		"S07":   # segura: sopra enquanto a barra dura
			s["channel"] = true
			if _is_bot(r.pid):
				bot_hold[r.pid] = 1.2
			Audio.play("ventilador", 1.0, -2.0)
		"S08":
			_fire_hook(r, s)
		"S21":
			_fire_lasso(r, s)
		"S12":
			_use_charge(r, s)
		"S25":
			var br := bridge_rect(r)
			if not bridge_ok(r, br):
				_fail(r, "SEM VÃO" if r.is_on_floor() else "SÓ NO CHÃO")
				return
			_build_bridge(r, br)
			s["fire"] = 0.0
			_spend(r, s)
		"S27":
			var tg = remote_target(r)
			if tg == null:
				_fail(r, "SEM MÁQUINA")
				return
			_remote_drop(r, tg)
			s["fire"] = 0.0
			_spend(r, s)
		"S28":
			var roof: bool = aim_vec(r).y < -0.5
			var sr := shield_rect(r) if not roof else Rect2(r.position.x - 72.0, r.position.y - 158.0, 144.0, 28.0)
			if sr.size.x <= 0.0:
				_fail(r, "SÓ NO CHÃO")
				return
			shields.append({"rect": sr, "t": 0.0, "hp": int(c["resistencia"]), "k": 0.0, "owner": r.pid, "flash": 0.0, "roof": roof})
			s["fire"] = 0.0
			Audio.play("laser_carga", 1.6, -4.0)
			_spend(r, s)
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
		var h := muzzle(r, "S01")
		var dv := aim_dir(r)
		var maxd := float(c["alcance_tiles"]) * T
		var d := 0.0
		while d < maxd:
			var nx: Vector2 = h + dv * (d + 12.0)
			if _hard_at(nx) or shield_block(nx, r.pid, false):
				break
			d += 12.0
		fists.append({"owner": r.pid, "t": 0.0, "reach": maxf(d, 40.0), "dir": r.facing, "dirv": dv, "hit": [], "wall": d < maxd - 12.0, "impact": -1.0})
		Audio.play("arremesso", 0.7, 2.0)
		Audio.play("pistao", 1.3, -2.0)
		r.own_vx -= dv.x * 160.0   # coice
		if dv.y > 0.5 and not r.is_on_floor():
			r.velocity.y = minf(r.velocity.y, -180.0)   # socão para baixo no ar dá um pulinho
		main.shake(4.0)
		_spend(r, s)
	elif s["id"] == "S03":
		var dv3 := aim_dir(r)
		shots.append({"pos": muzzle(r, "S03"), "vel": dv3 * float(c["vel"]), "owner": r.pid, "t": 0.0})
		Audio.play("gelo", 1.6, -2.0)
		r.own_vx -= dv3.x * 140.0   # coice
		for k in 6:
			main.spark(muzzle(r, "S03"), 1)
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
	var orig := muzzle(r, "S06")
	var rng := float(c["alcance_tiles"]) * T
	for o in main.robots:
		if o == r or not o.alive or o.invuln > 0.0 or o.guard_t > 0.0 or o.god:
			continue
		var oc: Vector2 = o.rect().get_center()
		var d: Vector2 = orig - oc
		var ad := aim_dir(r)
		var along: float = (oc - orig).dot(ad)
		var side: float = absf((oc - orig).dot(ad.orthogonal()))
		if along < -30.0 or along > rng or side > 2.0 * T + along * 0.3:
			continue   # fora do cone (gira com a mira: puxa de cima, de baixo, na diagonal)
		var k := 1.0 - 0.45 * d.length() / rng
		if d.length() < 44.0:
			o.own_vx = 0.0   # grudou no ímã
			o.velocity.y = 0.0
		else:
			var pull := d.normalized() * float(c["vel_max"]) * k
			o.own_vx = move_toward(o.own_vx, pull.x, float(c["forca"]) * dt)
			o.velocity.y = move_toward(o.velocity.y, pull.y if absf(pull.y) > 60.0 else clampf(d.y * 5.0, -380.0, 380.0), float(c["forca"]) * 0.8 * dt)
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
	var ad := aim_dir(r)
	for o in main.robots:
		if o != r and o.alive and _seg_rect(o0, o0 + ad * reach, o.rect(), 20.0) and float(fl["hitcd"].get(o.pid, 0.0)) <= 0.0:
			fl["hitcd"][o.pid] = float(c["fogo_tick_s"])
			_hit_dir(o, r.pid, ad, "spell_fogo")
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
	_update_pile_aims(dt)
	for r in main.robots:   # S27: ▲ troca qual viga fica na mira
		if r.alive and slot.has(r.pid) and slot[r.pid]["id"] == "S27" and PlayerInput.pressed(r.pid, "up"):
			slot[r.pid]["data"]["tgt_i"] = int(slot[r.pid]["data"].get("tgt_i", 0)) + 1
			Audio.play("menu_mover", 1.4, -6.0)
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
			_set_aim(r, s, aim_vec(r))
			if r.stun_t > 0.0:
				s["prep"] = -1.0   # levou golpe na preparação: cancela (sem gastar carga)
			elif s["prep"] >= s["prep_len"]:
				s["prep"] = -1.0
				_fire(r, s)
		if s["channel"] and s["id"] in ["S06", "S07"] or (s["id"] == "S13" and flames.has(r.pid) and s["channel"]):
			_set_aim(r, s, aim_vec(r), 7.0, dt)
		if s["id"] == "S06" and s["channel"]:
			_update_magnet(r, s, dt)
		if s["id"] == "S07" and s["channel"]:
			_update_fan(r, s, dt)
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
	_update_etapa3(dt)
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
		var from := muzzle(r, "S01")
		var ext := minf(fist_ext(f), 1.0)
		var tip: Vector2 = from + f["dirv"] * f["reach"] * ext
		if f["t"] <= FIST_OUT + FIST_HOLD:
			for o in main.robots:
				if o.pid == f["owner"] or not o.alive or o.pid in f["hit"]:
					continue
				if _seg_rect(from, tip, o.rect(), 22.0):
					f["hit"].append(o.pid)
					if _hit_dir(o, f["owner"], f["dirv"], "spell_punho"):
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
						if not p["fallen"] and p["state"] >= 1 and p["rect"].grow(8).has_point(tip + f["dirv"] * 14.0):
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
		var wall: bool = _hard_at(s["pos"]) or shield_block(s["pos"], s["owner"])
		if hit != null:
			var was_frozen: bool = hit.frozen_t > 0.0
			var gx := int(signf(s["vel"].x)) if absf(s["vel"].x) > 1.0 else 1
			if hit.take_hit(gx, "spell_gelo", s["owner"]) and not was_frozen:
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
		"channel": s["channel"], "aim_a": aim_local(r)}
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
	if s["id"] == "S12":
		out["placed"] = charges_placed.any(func(c): return c["owner"] == r.pid)
	return out

## HUD: {id, fam, charges, frac} do jogador (ou vazio). frac = barra de energia/duração.
func hud_info(pid: int) -> Dictionary:
	if not slot.has(pid):
		return {}
	var s: Dictionary = slot[pid]
	var frac := 1.0
	if s["id"] in ["S06", "S07"]:
		frac = s["energy"] / float(sc(s["id"])["energia_s"])
	elif s["id"] == "S13" and s["t"] > 0.0:
		frac = s["energy"] / float(sc("S13")["combustivel_s"])
	return {"id": s["id"], "fam": s["fam"], "charges": s["charges"] if not s["id"] in ["S06", "S07"] else 0, "frac": clampf(frac, 0.0, 1.0),
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
	_draw_etapa3()
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
		if not show or s["id"] in ["S11", "S17"]:
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
		# tudo desenhado no "quadro do braço": x = direção da mira (8 direções); para a esquerda espelha em y
		var r = main.robots[f["owner"]]
		var dv: Vector2 = f["dirv"]
		var base := Transform2D(dv.angle(), Vector2(1.0, -1.0 if dv.x < -0.1 else 1.0), 0.0, muzzle(r, "S01"))
		var ext := fist_ext(f)
		var L: float = maxf(f["reach"] * ext, 6.0)
		var n := 9
		var w := L / n
		var bar := sqrt(pow(f["reach"] / n, 2) + 22.0 * 22.0)   # barra de tamanho fixo: esticado ainda mostra o X, recolhido abre
		var hh := sqrt(maxf(bar * bar - w * w, 9.0)) / 2.0
		draw_set_transform_matrix(base)
		for pass_i in 2:   # barras em X (contorno escuro + metal)
			for i in n:
				var a := Vector2(w * i, -hh)
				var b := Vector2(w * (i + 1), hh)
				var c := Vector2(w * i, hh)
				var e := Vector2(w * (i + 1), -hh)
				if pass_i == 0:
					draw_line(a, b, INK, 8.0, true)
					draw_line(c, e, INK, 8.0, true)
				else:
					draw_line(a, b, Color("#b9c3cc"), 4.0, true)
					draw_line(c, e, Color("#8e9aa6"), 4.0, true)
		for i in n + 1:   # pinos
			draw_circle(Vector2(w * i, -hh), 3.2, Color("#f2c84b"))
			draw_circle(Vector2(w * i, hh), 3.2, Color("#f2c84b"))
			if i < n:
				draw_circle(Vector2(w * (i + 0.5), 0), 2.6, Color("#f2c84b"))
		if f["t"] < FIST_OUT + 0.04:   # linhas de velocidade
			for k in 4:
				var yy := -22.0 + k * 15.0
				draw_line(Vector2(L - 40.0 - k * 9.0, yy), Vector2(L - 110.0 - k * 14.0, yy), Color(1, 1, 1, 0.85), 3.0, true)
		if f["impact"] >= 0.0 and f["impact"] < 0.16:   # estrela de impacto
			var u: float = f["impact"] / 0.16
			var star := PackedVector2Array()
			for k in 16:
				var rad := (34.0 if k % 2 == 0 else 14.0) * (0.6 + 0.6 * u)
				star.append(Vector2(L + 50.0, 0) + Vector2.from_angle(k * TAU / 16.0 + 0.2) * rad)
			draw_colored_polygon(star, Color(1, 0.95, 0.6, 1.0 - u))
		# luva: estica na saída, achata no impacto
		var sq := Vector2(1.0, 1.0)
		if f["t"] < FIST_OUT:
			sq = Vector2(1.25, 0.85)
		if f["impact"] >= 0.0 and f["impact"] < 0.12:
			var u2: float = f["impact"] / 0.12
			sq = Vector2(0.7 + 0.3 * u2, 1.3 - 0.3 * u2)
		draw_set_transform_matrix(base * Transform2D(0.0, sq, 0.0, Vector2(L, 0)))
		draw_texture_rect(Data.tex("spells/s01_luva"), Rect2(-8, -26, 62, 50), false)
		draw_set_transform(Vector2.ZERO)
	# preparo: luva espiando no cano tremendo + vapor
	for r in main.robots:
		if not slot.has(r.pid) or slot[r.pid]["id"] != "S01" or slot[r.pid]["prep"] < 0.0:
			continue
		var k: float = slot[r.pid]["prep"] / maxf(slot[r.pid]["prep_len"], 0.01)
		var dvp := aim_dir(r)
		var h := muzzle(r, "S01") + dvp * (6.0 - 8.0 * k) + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 2.0 * k
		draw_set_transform(h, dvp.angle(), Vector2(0.75, -0.75 if dvp.x < -0.1 else 0.75))
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
			var m := muzzle(r, "S03")
			for j in 8:
				var a := j * TAU / 8.0 + t * 3.0
				var rad := 40.0 * (1.0 - k)
				_flake(m + Vector2.from_angle(a) * rad, 4.0, t * 4.0 + j)
			draw_circle(m, 6.0 + 10.0 * k, Color(ICE, 0.5 + 0.3 * k))
			draw_circle(m, 3.0 + 5.0 * k, Color(1, 1, 1, 0.9))
	for s in shots:
		var dv: Vector2 = s["vel"].normalized()
		var nv := dv.orthogonal()
		# rastro de névoa e flocos (atrás, na linha do tiro)
		for k in 6:
			var q: Vector2 = s["pos"] - dv * (18.0 + k * 13.0) + nv * sin(s["t"] * 30.0 + k) * 3.0
			draw_circle(q, 11.0 - k * 1.4, Color(0.85, 0.96, 1.0, 0.55 - k * 0.08))
		for k in 3:
			_flake(s["pos"] - dv * (30.0 + k * 26.0) + nv * (k - 1) * 12.0, 4.0, s["t"] * 10.0 + k)
		# lança de cristal apontada para onde vai
		draw_set_transform(s["pos"], dv.angle(), Vector2(1, -1 if dv.x < -0.1 else 1))
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
		var ow := muzzle(r, "S06")
		var adw := aim_dir(r)
		var base := Transform2D(adw.angle(), Vector2(1.0, -1.0 if adw.x < -0.1 else 1.0), 0.0, ow)
		var d := 1.0
		var o := Vector2.ZERO
		var rng := float(sc("S06")["alcance_tiles"]) * T
		# redemoinho: anéis achatados girando e encolhendo para dentro do polo (no quadro da mira)
		for i in 4:
			var u := fposmod(t * 1.8 + i * 0.25, 1.0)
			var rad := 110.0 * (1.0 - u) + 18.0
			var a0 := t * 9.0 + i * 1.3
			draw_set_transform_matrix(base * Transform2D(0.0, Vector2(0.55, 1.0), 0.0, Vector2.ZERO))
			draw_arc(Vector2.ZERO, rad, a0, a0 + 4.2, 24, Color(0.85, 0.29, 0.35, 0.75 * u), 3.0, true)
		draw_set_transform_matrix(base)
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
		draw_set_transform(Vector2.ZERO)
		o = ow
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
		var reach := float(sc("S13")["fogo_alcance_tiles"]) * T * k
		var ow: Vector2 = r.position + Vector2(r.facing * 26.0, -46.0)
		var adw := aim_dir(r)
		draw_set_transform(ow, adw.angle(), Vector2(1.0, -1.0 if adw.x < -0.1 else 1.0))   # quadro do jato
		var d := 1.0
		var o := Vector2.ZERO
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
		draw_set_transform(Vector2.ZERO)

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

## Golpe com direção da mira: lateral pelo sinal; mirado para cima joga mais alto, para baixo crava para baixo.
func _hit_dir(o, owner: int, dirv: Vector2, kind: String) -> bool:
	var dx := int(signf(dirv.x)) if absf(dirv.x) > 0.1 else (1 if o.position.x >= main.robots[owner].position.x else -1)
	var ok := _hit(o, owner, dx, kind)
	if ok:
		if dirv.y < -0.5:
			o.velocity.y -= 260.0
		elif dirv.y > 0.5:
			o.velocity.y = maxf(o.velocity.y, 620.0)
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
			var a := muzzle(r, "S02")
			var dv := aim_dir(r)
			var maxd := float(c["alcance_tiles"]) * T
			var d := 0.0
			while d < maxd and not _hard_at(a + dv * (d + 8.0)) and not shield_block(a + dv * (d + 8.0), r.pid, false):
				d += 8.0
			var b := a + dv * d
			shield_block(b + dv * 8.0, r.pid)
			lasers.append({"owner": r.pid, "t": 0.0, "a": a, "b": b})
			for o in main.robots:
				if o.pid != r.pid and _seg_rect(a, b, o.rect(), 10.0):
					_hit_dir(o, r.pid, dv, "spell_laser")
			if d < maxd:
				scorch.append({"pos": b, "t": 0.0})
			Audio.play("laser", 1.0, 0.0)
			main.shake(3.0)
			r.own_vx -= dv.x * 90.0
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
			# 3 ângulos: reto (quica no chão), ▲ arco alto (pega quem está em cima), ▼ no ar (desce na diagonal)
			var av := aim_dir(r)
			var v20 := Vector2(r.facing * float(c["vel"]), -float(c["subida"]))
			if av.y < -0.3:
				v20 = Vector2(r.facing * float(c["vel"]) * 0.55, -float(c["subida"]) * 2.6)
			elif av.y > 0.3:
				v20 = Vector2(r.facing * float(c["vel"]) * 0.6, 420.0)
			springs.append({"owner": r.pid, "pos": muzzle(r, "S20"), "vel": v20, "t": 0.0, "sq": 0.0})
			Audio.play("pulo_mola", 1.3, 2.0)
			r.own_vx -= r.facing * 260.0
			main.shake(4.0)
			_spend(r, s)

## S05: rebite em linha (▲/▼ inclinam 45°), ricocheteia até 2 vezes perdendo força.
func _fire_rivet(r, s: Dictionary) -> void:
	var c: Dictionary = sc("S05")
	if s["cd"] > 0.0:
		return
	var dirv := aim_dir(r)
	rivets.append({"owner": r.pid, "pos": muzzle(r, "S05"), "vel": dirv * float(c["vel"]), "bounces": 0, "t": 0.0, "hit": [], "trail": []})
	s["cd"] = float(c["intervalo_s"])
	s["fire"] = 0.0
	Audio.play("chave", 1.6, -2.0)
	Audio.play("pistao", 1.9, -10.0)
	tings.append({"pos": muzzle(r, "S05"), "t": 0.0, "big": true})
	r.own_vx -= r.facing * 50.0
	_spend(r, s)

## S17: marca uma faixa à frente (no chão) e a estaca desce lá depois do aviso.
func _pile_floor(r, x: float) -> float:
	var fy := _floor_below(x, r.position.y - 2.0 * T, 9)
	return fy if fy >= 0.0 else r.position.y + 2.0 * T

func _update_pile_aims(dt: float) -> void:
	var c: Dictionary = sc("S17")
	for pid in pile_aims.keys():
		var r = main.robots[pid]
		var a: Dictionary = pile_aims[pid]
		a["t"] += dt
		a["x"] += PlayerInput.axis_x(pid) * float(c["mira_vel"]) * dt
		var off: float = a["x"] - r.position.x
		var maxd := float(c["mira_alcance_tiles"]) * T
		a["x"] = r.position.x + clampf(off, -maxd, maxd)
		if absf(a["x"] - r.position.x) > 20.0:
			r.facing = int(signf(a["x"] - r.position.x))
		r.own_vx *= 0.8
		if not held(r) or a["t"] >= float(c["mira_max_s"]):
			pile_aims.erase(pid)
			r.spell_lock = false
			var s: Dictionary = slot[pid]
			s["channel"] = false
			_drop_pile(r, s, a["x"])

func _drop_pile(r, s: Dictionary, x: float) -> void:
	var c: Dictionary = sc("S17")
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
	var dh := aim_vec(r)
	var vh: Vector2 = dh * float(c["vel"]) + (Vector2(0, -180.0) if absf(dh.y) < 0.1 else Vector2.ZERO)
	hammers.append({"owner": r.pid, "pos": hand(r) + Vector2(0, -10), "vel": vh, "phase": "ida",
		"t": 0.0, "hit": [], "rot": 0.0, "dir": r.facing})
	r.hammer_out = true
	s["fire"] = 0.0
	Audio.play("marreta_vento", 1.0, 0.0)
	_spend(r, s)

func _update_attack2(dt: float) -> void:
	# S02 feixe e marcas de solda
	for e in lasers:
		e["t"] += dt
	lasers = lasers.filter(func(e): return e["t"] < 0.34)
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
		if fmod(w["t"], 0.04) < dt:
			for dir in [-1.0, 1.0]:
				var lim2: float = (w["r_end"] - w["x0"]) if dir > 0.0 else (w["x0"] - w["l_end"])
				if front < lim2:
					var fx: float = w["x0"] + dir * front
					main.dust(Vector2(fx - dir * 20.0, w["y"]), 0.7)
					for j in 2:
						rocks.append({"pos": Vector2(fx + randf_range(-10, 10), w["y"] - 4.0), "vel": Vector2(dir * randf_range(40, 220), randf_range(-520, -260)),
							"t": 0.0, "rot": randf() * TAU, "size": randf_range(4, 9)})
	waves = waves.filter(func(w): return w["t"] < 1.1)
	for rk in rocks:
		rk["t"] += dt
		rk["vel"].y += 1700.0 * dt
		rk["pos"] += rk["vel"] * dt
		rk["rot"] += dt * 10.0
	rocks = rocks.filter(func(rk): return rk["t"] < 0.8)
	# S05 rebites
	var c5: Dictionary = sc("S05")
	for rv in rivets:
		rv["t"] += dt
		rv["trail"].push_front(rv["pos"])
		if rv["trail"].size() > 6:
			rv["trail"].pop_back()
		var np: Vector2 = rv["pos"] + rv["vel"] * dt
		if shield_block(np, rv["owner"]):
			rv["dead"] = true
		if _hard_at(np):
			if rv["bounces"] >= int(c5["ricochetes"]):
				rv["dead"] = true
			else:
				# reflete no eixo que bateu
				var hx := _hard_at(Vector2(np.x, rv["pos"].y))
				var hy := _hard_at(Vector2(rv["pos"].x, np.y))
				if hx or not hy:
					rv["vel"].x = -rv["vel"].x
				if hy:
					rv["vel"].y = -rv["vel"].y
				rv["vel"] *= float(c5["perda"])
				rv["bounces"] += 1
				rv["hit"].clear()
				Audio.play("chave", 2.0 + rv["bounces"] * 0.3, -6.0)
				tings.append({"pos": rv["pos"], "t": 0.0, "big": false})
			main.spark(rv["pos"], 4)
		else:
			rv["pos"] = np
		for o in main.robots:
			if o.pid != rv["owner"] and o.alive and not (o.pid in rv["hit"]) and o.rect().grow(4).has_point(rv["pos"]):
				rv["hit"].append(o.pid)
				_hit_dir(o, rv["owner"], rv["vel"].normalized(), "spell_rebite")
				rv["dead"] = true
		if rv["t"] > float(c5["vida_s"]):
			rv["dead"] = true
	rivets = rivets.filter(func(rv): return not rv.get("dead", false))
	for e in tings:
		e["t"] += dt
	tings = tings.filter(func(e): return e["t"] < 0.18)
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
			if _solid_at(np + Vector2(signf(d["vel"].x) * 24.0, 0)) or shield_block(np, d["owner"]) or absf(np.x - d["x0"]) > float(c18["alcance_tiles"]) * T or d["t"] > float(c18["max_s"]) * 0.6:
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
			h["vel"] = h["vel"].move_toward(Vector2.ZERO, dec * dt)
			h["vel"].y += 260.0 * dt
			h["pos"] += h["vel"] * dt
			if h["vel"].length() < 60.0:
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
		if (_hard_at(np + Vector2(0, 14)) or (_solid_at(np + Vector2(0, 14)) and not _solid_at(m["pos"] + Vector2(0, 14)))) and m["vel"].y > 0.0:
			m["vel"].y = -absf(m["vel"].y) * float(c20["quique"])
			m["sq"] = 1.0
			Audio.play("pulo_mola", 1.6, -8.0)
			np = m["pos"]
		if _hard_at(np + Vector2(signf(m["vel"].x) * 16.0, 0)) or shield_block(np, m["owner"]):
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
				var a := muzzle(r, "S02")
				var dv := aim_dir(r)
				var maxd := float(sc("S02")["alcance_tiles"]) * T
				var d := 0.0
				while d < maxd and not _hard_at(a + dv * (d + 8.0)):
					d += 8.0
				var n := int(d / 22.0)
				for i in n:
					var q0: Vector2 = a + dv * (i * 22.0 + fposmod(t * 120.0, 22.0))
					draw_line(q0, q0 + dv * 11.0, Color(1, 0.25, 0.2, 0.35 + 0.5 * k), 2.0, true)
				draw_circle(a, 5.0 + 9.0 * k, Color(1, 0.4, 0.25, 0.4 + 0.4 * k))
				draw_circle(a, 3.0 + 4.0 * k, Color(1, 0.95, 0.8, 0.9))
			"S04":
				pass
			"S20":   # mola comprimindo: anéis apertando na boca
				var m := muzzle(r, "S20")
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
		draw_set_transform(grip, ang * r.facing, Vector2(r.facing, 1.0))
		draw_texture_rect(Data.tex("spells/s04_marreta"), Rect2(-28, -105, 56, 112), false)
		draw_set_transform(Vector2.ZERO)
		var head := grip + Vector2(0, -90.0).rotated(ang * r.facing)
		draw_circle(head, 18.0 + 14.0 * glow, Color(1, 0.85, 0.4, 0.35 * glow))
	# S02 feixe: dispara da lente até a parede em 0,04 s; tubo de luz com borda tremendo, anéis correndo, clarão na
	# boca e na parede; depois afina de cima para baixo e deixa calor
	for e in lasers:
		var tt: float = e["t"]
		var a: Vector2 = e["a"]
		var full: Vector2 = e["b"]
		var dirv: Vector2 = (full - a).normalized() if full.distance_to(a) > 1.0 else Vector2.RIGHT
		var ang := dirv.angle()
		var reach := clampf(tt / 0.04, 0.0, 1.0)
		var Lfull := a.distance_to(full)
		var L := Lfull * reach
		var b: Vector2 = a + dirv * L
		var thin := clampf((tt - 0.12) / 0.22, 0.0, 1.0)
		var w := 15.0 * (1.0 - thin * thin)
		if w > 0.5:
			var n := maxi(int(L / 18.0), 2)
			draw_set_transform(a, ang)   # quadro do feixe: x ao longo do tiro
			for layer in [[w + 7.0, Color(0.16, 0.1, 0.18, 0.85)], [w + 3.0, Color(0.92, 0.18, 0.16)], [w * 0.7, Color(1, 0.55, 0.25)], [w * 0.34, Color(1, 0.97, 0.85)]]:
				var hw: float = layer[0] / 2.0
				var poly := PackedVector2Array()
				for i in n + 1:
					poly.append(Vector2(L * i / n, -hw - sin(i * 1.7 + tt * 90.0) * hw * 0.18))
				for i in range(n, -1, -1):
					poly.append(Vector2(L * i / n, hw + sin(i * 2.1 + tt * 80.0) * hw * 0.18))
				draw_colored_polygon(poly, layer[1])
			for k in 4:   # anéis de energia correndo pelo feixe
				var u := fposmod(tt * 7.0 + k * 0.25, 1.0)
				draw_set_transform(a + dirv * L * u, ang, Vector2(0.35, 1.0))
				draw_arc(Vector2.ZERO, w * 0.9, 0, TAU, 14, Color(1, 0.95, 0.75, 0.8 * (1.0 - thin)), 2.0, true)
			draw_set_transform(Vector2.ZERO)
		# clarão na lente
		var fl := (1.0 - clampf(tt / 0.2, 0.0, 1.0))
		if fl > 0.0:
			var star := PackedVector2Array()
			for k in 12:
				star.append(a + Vector2.from_angle(k * TAU / 12.0 + tt * 6.0) * ((26.0 if k % 2 == 0 else 10.0) * fl))
			draw_colored_polygon(star, Color(1, 0.9, 0.6, fl))
			draw_circle(a, 8.0 * fl, Color.WHITE)
		# impacto: bola incandescente + faíscas em leque voltando
		if reach >= 1.0 and w > 0.5:
			draw_circle(b, w * 1.3, Color(1, 0.55, 0.25, 0.9))
			draw_circle(b, w * 0.7, Color(1, 0.97, 0.85))
			for k in 6:
				var sa := ang + PI + (k - 2.5) * 0.35
				var ln := 14.0 + fposmod(tt * 80.0 + k * 7.0, 22.0)
				draw_line(b + Vector2.from_angle(sa) * 6.0, b + Vector2.from_angle(sa) * ln, Color(1, 0.85, 0.4, 0.9), 2.0, true)
		# calor subindo depois que o feixe some
		if thin > 0.0:
			for k in 5:
				var q: Vector2 = a + dirv * Lfull * (k + 0.5) / 5.0
				draw_line(q + Vector2(0, -4.0 - thin * 20.0), q + Vector2(sin(tt * 30.0 + k) * 4.0, -14.0 - thin * 30.0), Color(1, 1, 1, 0.35 * (1.0 - thin)), 2.0, true)
	for e in scorch:   # mancha de solda: branca → laranja → escura
		var u: float = e["t"] / 2.5
		var col := Color(1, 0.95, 0.7).lerp(Color(1, 0.45, 0.15), minf(u * 4.0, 1.0)).lerp(Color(0.2, 0.15, 0.15), clampf(u * 2.0 - 0.5, 0.0, 1.0))
		draw_circle(e["pos"], 9.0, Color(col, 1.0 - u))
		if u < 0.4 and fmod(t, 0.08) < 0.04:
			main.spark(e["pos"], 1)
	# S04 tremor: anel de choque no impacto, placas do piso levantando em sequência atrás da frente da onda,
	# rachadura incandescente que esfria, pedrinhas voando
	var c4: Dictionary = sc("S04")
	for w in waves:
		var front: float = w["t"] * float(c4["vel"])
		var fade := clampf(1.0 - (w["t"] - 0.6) / 0.5, 0.0, 1.0)
		var y: float = w["y"]
		var x0: float = w["x0"]
		if w["t"] < 0.3:   # anel de choque
			var u: float = w["t"] / 0.3
			draw_set_transform(Vector2(x0, y), 0.0, Vector2(1.0, 0.32))
			draw_arc(Vector2.ZERO, 30.0 + 150.0 * u, PI, TAU, 24, Color(1, 0.95, 0.75, 1.0 - u), 8.0 * (1.0 - u) + 2.0, true)
			draw_set_transform(Vector2.ZERO)
			draw_circle(Vector2(x0, y - 10.0), 34.0 * (1.0 - u), Color(1, 0.8, 0.4, 0.6 * (1.0 - u)))
		for dir in [-1.0, 1.0]:
			var lim: float = (w["r_end"] - x0) if dir > 0.0 else (x0 - w["l_end"])
			# rachadura: zigue-zague grosso que vai de laranja vivo a escuro
			var f := minf(front, lim)
			var crack := PackedVector2Array()
			var n := int(f / 12.0)
			for i in n + 1:
				crack.append(Vector2(x0 + dir * i * 12.0, y + 2.0 + (5.0 if i % 2 == 0 else -1.0) + sin(i * 3.1) * 2.0))
			if crack.size() > 1:
				var hot := clampf(1.0 - w["t"] / 0.7, 0.0, 1.0)
				draw_polyline(crack, Color(0.16, 0.1, 0.18, 0.8 * fade), 7.0, true)
				draw_polyline(crack, Color(1, 0.5, 0.15, fade * (0.3 + 0.7 * hot)), 4.0, true)
				draw_polyline(crack, Color(1, 0.95, 0.7, fade * hot), 1.6, true)
			# placas do piso (20 px) levantando quando a onda passa e caindo de volta
			var slabs := int(lim / 20.0)
			for i in slabs:
				var dist := i * 20.0 + 10.0
				var u := (front - dist) / 90.0
				if u <= 0.0 or u >= 1.0:
					continue
				var amp := 18.0 * (1.0 - 0.4 * dist / maxf(lim, 1.0))
				var lift := sin(u * PI) * amp
				var tilt: float = sin(u * PI) * 0.22 * dir * (1.0 if i % 2 == 0 else -0.6)
				var cx: float = x0 + dir * dist
				draw_rect(Rect2(cx - 10.0, y, 20.0, 8.0), Color(0.16, 0.1, 0.18, 0.55))   # vão escuro embaixo
				draw_set_transform(Vector2(cx, y - lift), tilt)
				draw_rect(Rect2(-11, -2, 22, 14), INK)
				draw_rect(Rect2(-9.5, -0.5, 19, 11), Color("#cdbfa6"))
				draw_rect(Rect2(-9.5, -0.5, 19, 3), Color("#e6dcc8"))
				draw_set_transform(Vector2.ZERO)
			if front >= lim and fade > 0.0:   # a onda bateu numa borda/junta: estalo
				draw_circle(Vector2(x0 + dir * lim, y - 6.0), 10.0 * fade, Color(1, 0.85, 0.4, fade))
	for rk in rocks:
		var a: float = 1.0 - rk["t"] / 0.8
		draw_set_transform(rk["pos"], rk["rot"])
		var z: float = rk["size"]
		draw_colored_polygon(PackedVector2Array([Vector2(-z, -z * 0.6), Vector2(z * 0.8, -z), Vector2(z, z * 0.5), Vector2(-z * 0.4, z)]), Color(0.55, 0.48, 0.42, a))
		draw_set_transform(Vector2.ZERO)
	# S05 rebites: rastro claro, rebite grande (cabeça abaulada dourada + haste de aço) apontando para onde vai
	for rv in rivets:
		var tr: Array = rv["trail"]
		if tr.size() > 1:
			var line := PackedVector2Array([rv["pos"]])
			line.append_array(PackedVector2Array(tr))
			draw_polyline(line, Color(1, 0.85, 0.4, 0.45), 9.0, true)
			draw_polyline(line, Color(1, 1, 0.9, 0.9), 3.5, true)
		draw_set_transform(rv["pos"], rv["vel"].angle())
		draw_rect(Rect2(-16, -4.5, 16, 9), INK)
		draw_rect(Rect2(-15, -3, 14, 6), Color("#c9d1d8"))
		draw_circle(Vector2(2, 0), 9.0, INK)
		draw_circle(Vector2(2, 0), 7.5, Color("#f2c84b"))
		draw_circle(Vector2(4, -2.5), 2.5, Color(1, 1, 1, 0.85))
		draw_set_transform(Vector2.ZERO)
	for e in tings:   # estrelinha no ricochete / sopro de ar na boca
		var u: float = e["t"] / 0.18
		var rad := (26.0 if e["big"] else 18.0) * (0.5 + u)
		var star := PackedVector2Array()
		for k in 8:
			star.append(e["pos"] + Vector2.from_angle(k * TAU / 8.0 + 0.4) * (rad if k % 2 == 0 else rad * 0.35))
		draw_colored_polygon(star, Color(1, 0.95, 0.7, 1.0 - u))
		if e["big"]:
			draw_arc(e["pos"], rad * 1.2, 0, TAU, 14, Color(1, 1, 1, 0.6 * (1.0 - u)), 2.0, true)
	# S17 mira: marca andando no chão + coluna tracejada
	var c17a: Dictionary = sc("S17")
	for pid in pile_aims:
		var a17: Dictionary = pile_aims[pid]
		var r17 = main.robots[pid]
		var fy17 := _pile_floor(r17, a17["x"])
		var hw17 := float(c17a["largura_tiles"]) * T / 2.0
		draw_rect(Rect2(a17["x"] - hw17, fy17 - 5.5 * T, hw17 * 2.0, 5.5 * T), Color(1, 0.9, 0.3, 0.1))
		for i in 4:
			var xx: float = a17["x"] - hw17 + i * hw17 * 0.5
			draw_colored_polygon(PackedVector2Array([Vector2(xx, fy17 - 4), Vector2(xx + hw17 * 0.25, fy17 - 4), Vector2(xx + hw17 * 0.5, fy17 + 4), Vector2(xx + hw17 * 0.25, fy17 + 4)]), Color(0.95, 0.78, 0.29, 0.9))
		var ay := fy17 - 5.5 * T + 20.0 + absf(sin(t * 6.0)) * 12.0
		draw_colored_polygon(PackedVector2Array([Vector2(a17["x"] - 18, ay), Vector2(a17["x"] + 18, ay), Vector2(a17["x"], ay + 22)]), Color("#f2c84b"))
		draw_polyline(PackedVector2Array([Vector2(a17["x"] - 18, ay), Vector2(a17["x"] + 18, ay), Vector2(a17["x"], ay + 22), Vector2(a17["x"] - 18, ay)]), INK, 3.0, true)
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

# ================================================================ ETAPA 3: controle e engenharia
## S28: algum escudo de solda (de outro jogador ou o próprio) está em p? Se `dmg`, ele leva o golpe (pisca, racha).
func shield_block(p: Vector2, owner: int, dmg := true) -> bool:
	for sh in shields:
		if sh["k"] >= 0.6 and sh["rect"].grow(2).has_point(p):
			if dmg:
				sh["hp"] -= 1
				sh["flash"] = 1.0
				main.spark(p, 5)
				Audio.play("chave", 0.7, -2.0)
			return true
	return false

func shield_rect(r) -> Rect2:
	var x: float = r.position.x + r.facing * 62.0
	var fy := _floor_below(x, r.position.y - 40.0, 3)
	if fy < 0.0 or not r.is_on_floor():
		return Rect2()
	return Rect2(x - 22.0, fy - 132.0, 44.0, 132.0)   # 3 painéis de 40 + topo zebrado

## S07: cone de vento à frente; empurra (sem tirar o controle); o dono anda devagar e sente o recuo.
func _update_fan(r, s: Dictionary, dt: float) -> void:
	var c: Dictionary = sc("S07")
	if not held(r) or s["energy"] <= 0.0:
		s["channel"] = false
		r.spell_speed = 1.0
		if s["energy"] <= 0.0:
			s["empty_t"] = 0.35
			Audio.play("ventilador", 1.5, -6.0)
		return
	s["energy"] -= dt
	r.spell_speed = float(c["dono_vel_mult"])
	r.own_vx -= aim_dir(r).x * float(c["recuo"]) * dt * 3.0
	var o0 := muzzle(r, "S07")
	var ad := aim_dir(r)
	var rng := float(c["alcance_tiles"]) * T
	for o in main.robots:
		if o == r or not o.alive or o.invuln > 0.0 or o.god:
			continue
		var oc: Vector2 = o.rect().get_center()
		var dx: float = (oc - o0).dot(ad)
		var side: float = absf((oc - o0).dot(ad.orthogonal()))
		if dx < -10.0 or dx > rng or side > 40.0 + dx * 0.35:
			continue
		var k := 1.0 - 0.5 * dx / rng
		var ev: Vector2 = ext_v.get(o.pid, Vector2.ZERO)
		ev.x = move_toward(ev.x, ad.x * float(c["vel_max"]) * k, float(c["forca"]) * k * dt * 2.0)
		ext_v[o.pid] = ev
		if absf(ad.y) > 0.3:   # soprando para cima levanta; para baixo, empurra para o chão
			o.velocity.y = move_toward(o.velocity.y, ad.y * float(c["vel_max"]) * 1.1 * k, float(c["forca"]) * 1.4 * k * dt)
			o.hanging = false
		o.last_hit = 0.0
		o.last_attacker = r.pid
		o.last_cause = "turboventilador"
	if fmod(t, 0.25) < dt:
		Audio.play("ventilador", 1.1, -8.0)

## S08: garra com corrente (▲ inclina 45°). Parede/plataforma: puxa o dono até lá. Rival: tranco curto para perto.
func _fire_hook(r, s: Dictionary) -> void:
	for h in hooks:
		if h["owner"] == r.pid:
			return
	var c: Dictionary = sc("S08")
	var dirv := aim_dir(r)
	hooks.append({"owner": r.pid, "pos": muzzle(r, "S08"), "vel": dirv * float(c["vel"]), "phase": "ida", "t": 0.0, "anchor": Vector2.ZERO, "dir": dirv})
	s["fire"] = 0.0
	Audio.play("gancho", 1.0, 0.0)
	r.own_vx -= dirv.x * 80.0
	_spend(r, s)

func _fire_lasso(r, s: Dictionary) -> void:
	var c: Dictionary = sc("S21")
	var dl := aim_dir(r)
	lassos.append({"owner": r.pid, "pos": muzzle(r, "S21"), "vel": dl * float(c["vel"]), "t": 0.0})
	s["fire"] = 0.0
	Audio.play("arremesso", 1.4, -2.0)
	_spend(r, s)

## S12: 1º toque instala a carga nos pés (pisca na cor do dono); depois de armada, o próximo toque detona.
func _use_charge(r, s: Dictionary) -> void:
	for ch in charges_placed:
		if ch["owner"] == r.pid:
			if ch["armed"]:
				_detonate(ch)
				_spend(r, s)
			else:
				_fail(r, "ARMANDO…")
			return
	var av := aim_vec(r)
	if absf(av.y) > 0.3:   # com ▲/▼: arremessa e gruda na primeira superfície (parede, teto, plataforma)
		charges_placed.append({"owner": r.pid, "pos": hand(r), "t": 0.0, "armed": false, "drop": 1.0, "flying": true,
			"vel": av * 760.0 + Vector2(r.facing * 120.0, -120.0), "rot": 0.0})
		Audio.play("arremesso", 1.2, -2.0)
		s["fire"] = 0.0
		return
	var fy := _floor_below(r.position.x, r.position.y - 20.0, 3)
	var pos := Vector2(r.position.x, fy if fy >= 0.0 else r.position.y)
	charges_placed.append({"owner": r.pid, "pos": pos, "t": 0.0, "armed": false, "drop": 0.0})
	s["fire"] = 0.0
	Audio.play("alavanca", 1.3, -2.0)

func _detonate(ch: Dictionary) -> void:
	var c: Dictionary = sc("S12")
	var p: Vector2 = ch["pos"] + Vector2(0, -16)
	charges_placed.erase(ch)
	demo.booms.append({"pos": p, "t": 0.0})
	main.impact_fx(p, 0, 1.6)
	main.shake(14.0)
	Audio.play("explosao", 1.0, 2.0)
	for k in 10:
		rocks.append({"pos": p + Vector2(randf_range(-20, 20), 0), "vel": Vector2(randf_range(-380, 380), randf_range(-700, -300)), "t": 0.0, "rot": randf() * TAU, "size": randf_range(5, 10)})
	var rad := float(c["raio_tiles"]) * T
	for o in main.robots:
		if o.alive and o.pid != ch["owner"] and o.rect().get_center().distance_to(p) < rad:
			_hit(o, ch["owner"], 1 if o.position.x >= p.x else -1, "spell_carga")
	var ct = demo.canteiro
	if ct != null and is_instance_valid(ct):
		for pt in ct.parts:
			if not pt["fallen"] and pt["rect"].grow(rad * 0.5).has_point(p):
				ct.damage(pt, int(c["dano_estrutura"]), p)

## S25: ponte no nível dos pés, saindo da frente do robô por cima do vão.
## Altura exata do chão sob o robô (a ponte encosta nela sem degrau, mesmo logo depois de pousar).
func _floor_y(r) -> float:
	var fy := _floor_below(r.position.x, r.position.y - 8.0, 2)
	return fy if fy >= 0.0 and absf(fy - r.position.y) < 12.0 else r.position.y

func bridge_rect(r) -> Rect2:
	var L := float(sc("S25")["comprimento_tiles"]) * T
	var x0: float = r.position.x
	return Rect2(x0 if r.facing > 0 else x0 - L, _floor_y(r), L, 24.0)

## Com ▲ a ponte vira RAMPA (sobe 28°) para alcançar a plataforma de cima.
const RAMP := 0.49
func ramp_mode(r) -> bool:
	return not _is_bot(r.pid) and aim_vec(r).y < -0.5

func bridge_ok(r, br: Rect2) -> bool:
	if not r.is_on_floor():
		return false
	if ramp_mode(r):
		var L := float(sc("S25")["comprimento_tiles"]) * T
		var dv := Vector2(r.facing * cos(RAMP), -sin(RAMP))
		var st := Vector2(r.position.x + r.facing * 20.0, r.position.y)
		for i in range(1, int(L / 16.0) + 1):
			var q := st + dv * i * 16.0
			if _hard_at(q + Vector2(0, -6)) or _hard_at(q + Vector2(0, -60)):
				return false
		return true
	var air := 0
	var n := int(br.size.x / 16.0)
	for i in n:
		var p := Vector2(br.position.x + 8.0 + i * 16.0, br.position.y + 6.0)
		if _solid_at(p + Vector2(0, -12)):
			return false   # parede no caminho
		if not _solid_at(p):
			air += 1
	return air >= 2   # precisa ter algum vão à frente

func _build_bridge(r, br: Rect2) -> void:
	var c: Dictionary = sc("S25")
	var sl := RAMP if ramp_mode(r) else 0.0
	var body := StaticBody2D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shp := RectangleShape2D.new()
	shp.size = br.size
	cs.shape = shp
	cs.position = br.get_center()
	if sl > 0.0:
		var L := br.size.x
		var st := Vector2(r.position.x + r.facing * 20.0, _floor_y(r))
		var rot: float = -sl * r.facing
		cs.rotation = rot
		cs.position = st + Vector2(r.facing * cos(sl), -sin(sl)) * L / 2.0 + Vector2(0, 8).rotated(rot)
	cs.one_way_collision = true
	body.add_child(cs)
	add_child(body)
	bridges.append({"rect": br, "body": body, "t": float(c["duracao_s"]), "len": float(c["duracao_s"]), "k": 0.0, "owner": r.pid,
		"dir": r.facing, "x0": r.position.x + (r.facing * 20.0 if sl > 0.0 else 0.0), "y": _floor_y(r), "slope": sl})
	Audio.play("alavanca", 1.0, 0.0)

## S27: viga pendurada mais perto, à frente, ao alcance (a do guindaste do Canteiro). null = nenhuma.
func remote_target(r):
	var ct = demo.canteiro
	if ct == null or not is_instance_valid(ct):
		return null
	var cands := []
	var maxd := float(sc("S27")["alcance_tiles"]) * T
	for p in ct.parts:
		if p["kind"] != "viga" or p["fallen"] or p["crit_t"] > 0.0:
			continue
		var d: float = p["rect"].get_center().distance_to(r.position)
		if d < maxd:
			cands.append([d, p])
	if cands.is_empty():
		return null
	cands.sort_custom(func(a, b): return a[0] < b[0])
	var i := 0
	if slot.has(r.pid):
		i = int(slot[r.pid]["data"].get("tgt_i", 0))
	return cands[posmod(i, cands.size())][1]

func _remote_drop(r, p: Dictionary) -> void:
	p["hp"] = 0
	p["state"] = 2
	p["crit_t"] = 0.35   # o cabo estala e a viga despenca
	drops.append({"part": p, "owner": r.pid, "t": 0.0, "hit": []})
	Audio.play("alarme", 1.2, -2.0)
	Audio.play("gancho", 0.6, 0.0)

func _update_etapa3(dt: float) -> void:
	# empurrões externos (vento/elástico): somam na velocidade do robô sem brigar com o controle; somem aos poucos
	for pid in ext_v.keys():
		var ev: Vector2 = ext_v[pid]
		if pid < main.robots.size() and main.robots[pid].alive:
			main.robots[pid].push_vx += ev.x
		ev = ev.move_toward(Vector2.ZERO, 900.0 * dt)
		if ev.length() < 1.0:
			ext_v.erase(pid)
		else:
			ext_v[pid] = ev
	var c8: Dictionary = sc("S08")
	for h in hooks:
		h["t"] += dt
		h["snap"] = maxf(float(h.get("snap", 0.0)) - dt * 5.0, 0.0)
		var owner = main.robots[h["owner"]]
		var mz := muzzle(owner, "S08") if slot.has(h["owner"]) and slot[h["owner"]]["id"] == "S08" else hand(owner)
		match h["phase"]:
			"ida":
				var np: Vector2 = h["pos"] + h["vel"] * dt
				# puxa QUASE TUDO: robô, caixa de spell, bomba; estrutura puxa o dono
				var grabbed := false
				for o in main.robots:
					if o.pid != h["owner"] and o.alive and o.rect().grow(10).has_point(np):
						h["phase"] = "reboque"
						h["what"] = o
						grabbed = true
						_hit(o, h["owner"], -1 if o.position.x > owner.position.x else 1, "spell_gancho")
						break
				if not grabbed:
					for bx in boxes:
						if bx["pos"].distance_to(np) < 40.0:
							h["phase"] = "caixa"
							h["what"] = bx
							grabbed = true
							break
				if not grabbed:
					for ch in charges_placed:
						if ch["pos"].distance_to(np) < 34.0:
							h["phase"] = "bomba"
							h["what"] = ch
							grabbed = true
							break
				if grabbed:
					h["snap"] = 1.0
					h["t"] = 0.0
					Audio.play("chave", 0.8, 0.0)
					main.spark(np, 4)
				elif _grab_at(np) or shield_block(np, h["owner"], false):
					h["phase"] = "puxa"
					h["anchor"] = h["pos"]
					h["t"] = 0.0
					h["snap"] = 1.0
					owner.spell_lock = true
					Audio.play("chave", 0.9, 0.0)
					main.spark(h["pos"], 5)
				elif h["pos"].distance_to(mz) > float(c8["alcance_tiles"]) * T:
					h["phase"] = "volta"
				else:
					h["pos"] = np
			"puxa":   # o dono voa até a garra
				var to: Vector2 = h["anchor"] - owner.rect().get_center()
				owner.velocity = to.normalized() * float(c8["puxa_vel"])
				owner.own_vx = owner.velocity.x
				owner.hanging = false
				if to.length() < 48.0 or h["t"] > float(c8["puxa_max_s"]) or not owner.alive:
					owner.spell_lock = false
					owner.velocity = Vector2(owner.velocity.x * 0.3, -420.0)   # chega com um pulinho para subir
					owner.own_vx = owner.velocity.x
					h["dead"] = true
			"reboque":   # o rival vem arrastado até o dono (sem controle) e solta na frente dele
				var o = h["what"]
				var to2: Vector2 = mz - o.rect().get_center()
				h["pos"] = o.rect().get_center()
				if not o.alive or to2.length() < 64.0 or h["t"] > 0.9:
					o.velocity *= 0.3
					o.own_vx *= 0.3
					h["dead"] = true
				else:
					o.velocity = to2.normalized() * float(c8["puxa_vel"]) * 0.9
					o.own_vx = o.velocity.x
					o.stun_t = maxf(o.stun_t, 0.1)
					o.hanging = false
			"caixa", "bomba":   # caixas e bombas vêm voando para a mão
				var it: Dictionary = h["what"]
				var to3: Vector2 = mz - it["pos"]
				it["pos"] += to3.normalized() * minf(1300.0 * dt, to3.length())
				if it.has("vy"):
					it["vy"] = 0.0
				h["pos"] = it["pos"]
				if to3.length() < 30.0 or h["t"] > 1.2:
					if it.has("vy"):
						it["pos"] = owner.position + Vector2(owner.facing * 30.0, -30.0)
					h["dead"] = true
			"volta":
				var to4: Vector2 = mz - h["pos"]
				h["pos"] += to4.normalized() * minf(1800.0 * dt, to4.length())
				if to4.length() < 20.0:
					h["dead"] = true
	hooks = hooks.filter(func(h): return not h.get("dead", false))
	# S21 laço: tiro → elástico entre os dois
	var c21: Dictionary = sc("S21")
	for l in lassos:
		l["t"] += dt
		l["pos"] += l["vel"] * dt   # esfera de energia: voa reto
		for o in main.robots:
			if o.pid != l["owner"] and o.alive and o.invuln <= 0.0 and o.rect().grow(8).has_point(l["pos"]):
				tethers.append({"a": l["owner"], "b": o.pid, "t": 0.0})
				tings.append({"pos": l["pos"], "t": 0.0, "big": true})
				o.vis.s_sqx[0] = 0.8
				o.vis.s_sqy[0] = 1.15
				l["dead"] = true
				main.float_text(o.position + Vector2(0, -120), "PRESO!", Color("#3fc1c9"))
				Audio.play("pulo_mola", 1.4, -2.0)
				break
		if _hard_at(l["pos"]) or shield_block(l["pos"], l["owner"]) or l["t"] > float(c21["alcance_tiles"]) * T / float(c21["vel"]):
			l["dead"] = true
	lassos = lassos.filter(func(l): return not l.get("dead", false))
	for e in tethers:
		e["t"] += dt
		var a = main.robots[e["a"]]
		var b = main.robots[e["b"]]
		if not a.alive or not b.alive or e["t"] > float(c21["duracao_s"]):
			e["dead"] = true
			snaps.append({"a": a.rect().get_center(), "b": b.rect().get_center(), "t": 0.0})
			Audio.play("pulo_mola", 2.0, -6.0)
			continue
		var d: Vector2 = b.rect().get_center() - a.rect().get_center()
		var over: float = d.length() - float(c21["folga_tiles"]) * T
		if over > 0.0:   # esticou: puxa os DOIS um para o outro (ninguém controla o outro)
			var k := clampf(over / T, 0.0, 2.0)
			var u := d.normalized()
			for pair in [[a, u], [b, -u]]:
				var rob = pair[0]
				var dirv: Vector2 = pair[1]
				var ev: Vector2 = ext_v.get(rob.pid, Vector2.ZERO)
				ev.x = move_toward(ev.x, dirv.x * 560.0 * k, float(c21["forca"]) * dt)
				ext_v[rob.pid] = ev
				rob.velocity.y = move_toward(rob.velocity.y, dirv.y * 400.0 * k, float(c21["forca"]) * 0.6 * dt)
	tethers = tethers.filter(func(e): return not e.get("dead", false))
	for e in snaps:
		e["t"] += dt
	snaps = snaps.filter(func(e): return e["t"] < 0.18)
	# S12 cargas
	var c12: Dictionary = sc("S12")
	for ch in charges_placed.duplicate():
		if ch.get("flying", false):
			ch["vel"].y += 1400.0 * dt
			ch["rot"] += dt * 12.0
			var np: Vector2 = ch["pos"] + ch["vel"] * dt
			if _grab_at(np):
				ch["flying"] = false
				ch["t"] = 0.0
				ch["rot"] = 0.0
				Audio.play("alavanca", 1.6, -4.0)
				main.spark(np, 3)
			else:
				ch["pos"] = np
				if ch["pos"].y > main.level.rows * T + 300.0:
					ch["flying"] = false   # caiu no abismo: explode lá embaixo quando der o tempo
			continue
		ch["t"] += dt
		ch["drop"] = minf(ch["drop"] + dt / 0.2, 1.0)
		if not ch["armed"] and ch["t"] >= float(c12["arma_s"]):
			ch["armed"] = true
			Audio.play("alarme", 1.8, -8.0)
		var beep := 0.6 if ch["t"] < float(c12["auto_s"]) - 3.0 else 0.15
		if fmod(ch["t"], beep) < dt:
			Audio.play("menu_mover", 2.0, -10.0)
		if ch["t"] >= float(c12["auto_s"]):
			var ow: int = ch["owner"]
			_detonate(ch)
			if slot.has(ow) and slot[ow]["id"] == "S12":
				_spend(main.robots[ow], slot[ow])
	# S25 pontes
	for br in bridges.duplicate():
		br["t"] -= dt
		br["k"] = minf(br["k"] + dt / 0.36, 1.0)
		if br["t"] <= 0.0:
			if is_instance_valid(br["body"]):
				br["body"].queue_free()
			bridges.erase(br)
			Audio.play("alavanca", 0.8, -4.0)
	# S27 viga despencando: acerta quem estiver embaixo
	for e in drops:
		e["t"] += dt
		var p: Dictionary = e["part"]
		if p["fallen"]:
			var col := Rect2(p["rect"].position.x, p["rect"].position.y, p["rect"].size.x, 5.0 * T)
			for o in main.robots:
				if o.alive and not (o.pid in e["hit"]) and col.intersects(o.rect()) and e["t"] < 1.4:
					e["hit"].append(o.pid)
					var dx := 1 if o.position.x >= p["rect"].get_center().x else -1
					o.take_hit(dx, "spell_viga", e["owner"]) if o.pid != e["owner"] else null
	drops = drops.filter(func(e): return e["t"] < 1.6)
	# S28 escudos
	var c28: Dictionary = sc("S28")
	for sh in shields.duplicate():
		sh["t"] += dt
		var k_before: float = sh["k"]
		sh["k"] = minf(sh["k"] + dt / 0.5, 1.0)
		for i in 3:   # cada painel que encaixa faz "clanc" e solta faísca de solda
			if k_before < (i + 0.7) / 3.0 and sh["k"] >= (i + 0.7) / 3.0:
				Audio.play("caixote_pancada", 1.5 + i * 0.1, -6.0)
				main.spark(_panel_rect(sh, i).get_center(), 6)
		sh["flash"] = maxf(sh["flash"] - dt * 5.0, 0.0)
		if sh["k"] < 1.0 and fmod(sh["t"], 0.04) < dt:
			var ow2 = main.robots[sh["owner"]]
			main.spark(hand(ow2) + Vector2(ow2.facing * 10.0, 0), 1)
		if sh["hp"] <= 0 or sh["t"] >= float(c28["duracao_s"]):
			shields.erase(sh)
			for i in 3:   # os painéis caem soltos
				var pr2 := _panel_rect(sh, i)
				var parts := [{"tex": [Data.tex("spells/s28_painel")], "rect": Rect2(-pr2.size / 2.0, pr2.size), "mod": Color.WHITE}]
				var dbr: Node2D = main.Debris.new()
				dbr.setup(parts, pr2.get_center(), 1 if i % 2 == 0 else -1, Vector2((i - 1) * 120.0, -220.0 - i * 60.0))
				main.world.add_child(dbr)
			Audio.play("caixote_quebra", 1.4, -2.0)

# ---------------------------------------------------------------- desenho da Etapa 3
func _draw_etapa3() -> void:
	# S07 vento: riscos correndo no cone, poeira e hélice borrada
	for r in main.robots:
		if not r.alive or not slot.has(r.pid) or slot[r.pid]["id"] != "S07" or not slot[r.pid]["channel"]:
			continue
		var ow := muzzle(r, "S07")
		var adw := aim_dir(r)
		var rng := float(sc("S07")["alcance_tiles"]) * T
		if fmod(t, 0.06) < 0.02:
			var gp := ow + adw * randf_range(60, rng)
			main.dust(Vector2(gp.x, r.position.y) if absf(adw.y) < 0.3 else gp, 0.4)
		# tudo no quadro do vento (x = direção da mira)
		draw_set_transform(ow, adw.angle(), Vector2(1.0, -1.0 if adw.x < -0.1 else 1.0))
		var o := Vector2.ZERO
		var d := 1.0
		# cone de ar claro + rajadas em espiral (contorno escuro fino para ler sobre qualquer fundo) + poeira
		var cone := PackedVector2Array([o + Vector2(0, -16), o + Vector2(d * rng, -40.0 - rng * 0.35), o + Vector2(d * rng, 40.0 + rng * 0.35), o + Vector2(0, 16)])
		draw_colored_polygon(cone, Color(1, 1, 1, 0.12))
		for i in 9:
			var u := fposmod(t * 2.2 + i * 0.111, 1.0)
			var dx := rng * u
			var spread := 26.0 + dx * 0.3
			var yy := o.y + sin(i * 2.3) * spread
			var x0 := o.x + d * dx
			var pts := PackedVector2Array()
			for j in 9:   # risco ondulado que termina num caracol
				var v := float(j) / 8.0
				if v < 0.7:
					pts.append(Vector2(x0 + d * v * 70.0, yy + sin(v * 7.0 + t * 10.0) * 4.0))
				else:
					var ca := (v - 0.7) / 0.3 * PI * 1.5
					pts.append(Vector2(x0 + d * (49.0 + sin(ca) * 10.0), yy - 10.0 + cos(ca) * 10.0))
			var al := sin(u * PI)
			draw_polyline(pts, Color(0.16, 0.1, 0.18, 0.35 * al), 6.0, true)
			draw_polyline(pts, Color(1, 1, 1, 0.95 * al), 3.0, true)
		for i in 4:   # anéis de pressão correndo no cone
			var u := fposmod(t * 2.8 + i * 0.25, 1.0)
			var dx := rng * u
			var hh := 22.0 + dx * 0.33
			draw_set_transform(ow + adw * dx, adw.angle(), Vector2(0.28, 1.0))
			draw_arc(Vector2.ZERO, hh, 0, TAU, 20, Color(1, 1, 1, 0.55 * (1.0 - u)), 3.0, true)
		draw_set_transform(ow, adw.angle(), Vector2(1.0, -1.0 if adw.x < -0.1 else 1.0))
		for i in 7:   # sucata e folhas voando junto
			var u := fposmod(t * 1.9 + i * 0.143, 1.0)
			var q := Vector2(rng * u, sin(i * 2.7 + t * 5.0) * (18.0 + rng * u * 0.25))
			draw_set_transform(ow + (q.rotated(adw.angle()) if adw.x >= -0.1 else Vector2(q.x, -q.y).rotated(adw.angle())), t * 12.0 + i)
			if i % 2 == 0:
				draw_rect(Rect2(-4, -2, 8, 4), Color(0.6, 0.65, 0.7, 1.0 - u))
			else:
				draw_colored_polygon(PackedVector2Array([Vector2(-5, 0), Vector2(0, -3), Vector2(5, 0), Vector2(0, 3)]), Color(0.55, 0.75, 0.35, 1.0 - u))
		draw_set_transform(ow, adw.angle(), Vector2(1.0, -1.0 if adw.x < -0.1 else 1.0))
		# hélice: disco borrado + 3 pás girando rápido (vistas de lado: achatadas)
		draw_set_transform_matrix(Transform2D(adw.angle(), Vector2(1.0, -1.0 if adw.x < -0.1 else 1.0), 0.0, ow) * Transform2D(0.0, Vector2(0.3, 1.0), 0.0, Vector2(-10, 0)))
		draw_circle(Vector2.ZERO, 18.0, Color(1, 1, 1, 0.25))
		for k in 3:
			var ba := t * 45.0 + k * TAU / 3.0
			draw_line(Vector2.ZERO, Vector2.from_angle(ba) * 17.0, Color(0.85, 0.9, 0.95, 0.85), 5.0, true)
		draw_set_transform(Vector2.ZERO)
		if fmod(t, 0.1) < 0.02:   # o dono escorrega para trás: poeira nos pés
			main.dust(r.position + Vector2(-r.facing * 10.0, 0), 0.35)
		for v in main.robots:   # quem está no vento tremula
			if v != r and v.alive and v.last_cause == "turboventilador" and v.last_hit < 0.05:
				v.vis.s_sqx[0] = 1.0 + randf_range(-0.06, 0.06)
				v.vis.s_sqy[0] = 1.0 + randf_range(-0.05, 0.05)
	# S08 corrente de elos (ovais alternados, com barriga enquanto sai) + garra de 3 dentes que abre em voo e fecha ao pegar
	for h in hooks:
		var owner = main.robots[h["owner"]]
		var a := muzzle(owner, "S08") if slot.has(h["owner"]) and slot[h["owner"]]["id"] == "S08" else hand(owner)
		var b: Vector2 = h["pos"]
		var L := a.distance_to(b)
		var dirv := (b - a).normalized() if L > 1.0 else Vector2(owner.facing, 0)
		var sag := 18.0 if h["phase"] == "ida" else (sin(t * 60.0) * 2.0 if h["phase"] in ["puxa", "reboque", "caixa", "bomba"] else 8.0)
		var n := maxi(int(L / 11.0), 1)
		for i in n:
			var u := (i + 0.5) / n
			var q := a.lerp(b, u) + Vector2(0, sin(u * PI) * sag)
			var ang := dirv.angle()
			if i % 2 == 0:
				draw_set_transform(q, ang)
				draw_arc(Vector2.ZERO, 6.5, 0, TAU, 12, INK, 4.5, true)
				draw_set_transform(q, ang, Vector2(1.0, 0.6))
				draw_arc(Vector2.ZERO, 6.5, 0, TAU, 12, Color("#c9d1d8"), 2.4, true)
			else:
				draw_set_transform(q, ang, Vector2(1.0, 0.35))
				draw_arc(Vector2.ZERO, 6.5, 0, TAU, 12, INK, 4.0, true)
				draw_arc(Vector2.ZERO, 6.5, 0, TAU, 12, Color("#8e9aa6"), 2.0, true)
		draw_set_transform(Vector2.ZERO)
		var open: float = 0.75 if h["phase"] == "ida" or h["phase"] == "volta" else 0.12
		var hang := dirv.angle()
		draw_set_transform(b, hang, Vector2(1.0 + 0.3 * h.get("snap", 0.0), 1.0))
		for k in 3:   # dentes curvos
			var side := float(k - 1)
			var spread := side * open * 0.9
			var tip := Vector2(22, 0).rotated(spread) + Vector2(0, side * 4.0)
			var mid := Vector2(10, side * 8.0 * open + side * 2.0)
			var hook := tip + Vector2(-6, -side * 6.0) if k != 1 else tip + Vector2(2, 0)
			for pass_i in 2:
				var w := 7.0 if pass_i == 0 else 3.5
				var col := INK if pass_i == 0 else Color("#e0e6ea")
				draw_polyline(PackedVector2Array([Vector2.ZERO, mid, tip, hook]), col, w, true)
		draw_circle(Vector2.ZERO, 8.0, INK)
		draw_circle(Vector2.ZERO, 6.0, Color("#8a63d2"))
		draw_circle(Vector2(-2, -2), 2.0, Color(1, 1, 1, 0.7))
		draw_set_transform(Vector2.ZERO)
		if h.get("snap", 0.0) > 0.0:   # estalo ao fechar
			var u: float = 1.0 - h["snap"]
			draw_arc(b, 14.0 + 22.0 * u, 0, TAU, 16, Color(1, 1, 1, 1.0 - u), 3.0, true)
	# S21 laço de energia: esfera elétrica com rastro; acertou → algema de energia em cada robô e um raio entre eles
	# (frouxo: ondula; esticado: mais grosso, mais claro e estalando); soltou → descarga nas duas pontas
	var c21: Dictionary = sc("S21")
	for l in lassos:
		var p: Vector2 = l["pos"]
		var dv: Vector2 = l["vel"].normalized()
		for k in 5:   # rastro elétrico
			draw_circle(p - dv * (10.0 + k * 10.0), 9.0 - k * 1.5, Color(0.25, 0.76, 0.79, 0.45 - k * 0.08))
		_draw_bolt(p - dv * 54.0, p, 0.3, 4.0, l["t"])
		draw_circle(p, 15.0, Color(0.54, 0.39, 0.82, 0.35))
		draw_circle(p, 11.0, Color("#3fc1c9"))
		draw_circle(p, 6.5, Color("#bff6ff"))
		draw_circle(p, 3.0, Color.WHITE)
		for k in 3:   # arquinhos estalando em volta
			var a0 := t * 9.0 + k * TAU / 3.0
			_draw_bolt(p + Vector2.from_angle(a0) * 8.0, p + Vector2.from_angle(a0 + 0.6) * 20.0, 0.0, 3.0, t + k)
	for e in tethers:
		var ra = main.robots[e["a"]]
		var rb = main.robots[e["b"]]
		var pa: Vector2 = ra.rect().get_center()
		var pb: Vector2 = rb.rect().get_center()
		var folga := float(c21["folga_tiles"]) * T
		var dist := pa.distance_to(pb)
		var stretch := clampf((dist - folga) / (2.0 * T), 0.0, 1.0)
		var left: float = float(c21["duracao_s"]) - e["t"]
		var flick := 0.55 if left < 0.8 and fmod(t, 0.16) < 0.08 else 1.0
		var slack := maxf(folga - dist, 0.0) * 0.35
		_draw_bolt(pa, pb, stretch, slack, e["t"], flick)
		for q in [pa, pb]:   # algema de energia: anel achatado girando + nós de faísca
			draw_set_transform(q, 0.0, Vector2(1.0, 0.45))
			draw_arc(Vector2.ZERO, 30.0, 0, TAU, 24, Color(0.25, 0.76, 0.79, 0.5 * flick), 7.0, true)
			draw_arc(Vector2.ZERO, 30.0, 0, TAU, 24, Color(0.75, 0.96, 1.0, 0.9 * flick), 2.5, true)
			draw_set_transform(Vector2.ZERO)
			for k in 3:
				var a1 := t * (6.0 + stretch * 6.0) + k * TAU / 3.0
				draw_circle(q + Vector2(cos(a1) * 30.0, sin(a1) * 13.5), 3.5, Color(1, 1, 1, flick))
	for e in snaps:   # soltou: descarga nas pontas
		var u: float = e["t"] / 0.18
		for q in [e["a"], e["b"]]:
			draw_circle(q, 10.0 + 30.0 * u, Color(0.75, 0.96, 1.0, 0.8 * (1.0 - u)))
			for k in 5:
				var a2 := k * TAU / 5.0 + u
				_draw_bolt(q, q + Vector2.from_angle(a2) * (16.0 + 26.0 * u), 0.0, 4.0, t + k, 1.0 - u)
	# S12 cargas: cai e gruda, luz pisca na cor do dono (mais rápido perto de explodir), círculo de alcance quando armada
	var c12: Dictionary = sc("S12")
	var ctex := Data.tex("spells/s12_carga")
	for ch in charges_placed:
		var p: Vector2 = ch["pos"]
		var drop: float = ch["drop"]
		var sq := 1.0 + 0.25 * sin(drop * PI) if drop < 1.0 else 1.0
		draw_set_transform(p + Vector2(0, -24.0 * (1.0 - drop)), float(ch.get("rot", 0.0)), Vector2(sq, 2.0 - sq))
		draw_texture_rect(ctex, Rect2(-24, -36, 48, 36), false)
		draw_set_transform(Vector2.ZERO)
		var beep := 0.6 if ch["t"] < float(c12["auto_s"]) - 3.0 else 0.15
		var on := fmod(ch["t"], beep) < beep * 0.4
		var pc: Color = main.player_color(ch["owner"])
		if on:
			draw_circle(p + Vector2(15, -21), 7.0, Color(pc, 0.9))
			draw_circle(p + Vector2(15, -21), 3.0, Color.WHITE)
		if ch["armed"]:
			draw_set_transform(p, 0.0, Vector2(1.0, 0.3))
			draw_arc(Vector2.ZERO, float(c12["raio_tiles"]) * T, 0, TAU, 40, Color(pc, 0.35 + (0.3 if on else 0.0)), 4.0, true)
			draw_set_transform(Vector2.ZERO)
	# S25 pontes: painéis desdobrando um a um a partir da beirada; piscam e dobram de volta
	var ptex := Data.tex("spells/s25_tabua")
	for br in bridges:
		_draw_bridge(br["x0"], br["y"], br["dir"], br["k"], br["t"], Color.WHITE, br.get("slope", 0.0))
	for r in main.robots:   # prévia para quem tem a spell
		if r.alive and slot.has(r.pid) and slot[r.pid]["id"] == "S25" and not slot[r.pid].has("empty_t"):
			var br2 := bridge_rect(r)
			var ok := bridge_ok(r, br2)
			_draw_bridge(r.position.x + (r.facing * 20.0 if ramp_mode(r) else 0.0), _floor_y(r), r.facing, 1.0, 9.0, Color(0.45, 0.92, 1.0, 0.4) if ok else Color(1, 0.35, 0.35, 0.35), RAMP if ramp_mode(r) else 0.0)
	# S27 mira na viga mais perto (retícula) para quem tem o controle
	for r in main.robots:
		if r.alive and slot.has(r.pid) and slot[r.pid]["id"] == "S27" and not slot[r.pid].has("empty_t"):
			# todas as vigas que dá para soltar ganham um receptor piscando no cabo (fica claro onde a spell funciona)
			var ct2 = demo.canteiro
			if ct2 != null and is_instance_valid(ct2):
				for pv in ct2.parts:
					if pv["kind"] == "viga" and not pv["fallen"] and pv["crit_t"] <= 0.0:
						var top: Vector2 = Vector2(pv["rect"].get_center().x, pv["rect"].position.y - 30.0)
						draw_rect(Rect2(top - Vector2(10, 8), Vector2(20, 16)), INK)
						draw_rect(Rect2(top - Vector2(8, 6), Vector2(16, 12)), Color("#f2c84b"))
						draw_circle(top + Vector2(0, -1), 3.5, Color("#d94a3a") if fmod(t, 0.6) < 0.3 else Color("#5a2a20"))
						draw_line(top + Vector2(6, -8), top + Vector2(10, -18), INK, 2.0, true)
			var tg = remote_target(r)
			if tg != null:
				var c: Vector2 = tg["rect"].get_center()
				Kit.text(self, c + Vector2(-90, -62), "ESPECIAL: soltar  ·  ▲: outra", 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 180, 5, INK)
				var rad := 40.0 + 6.0 * sin(t * 8.0)
				draw_arc(c, rad, 0, TAU, 24, Color("#d94a3a"), 3.0, true)
				for k in 4:
					var a := k * PI / 2.0 + t
					draw_line(c + Vector2.from_angle(a) * (rad - 10.0), c + Vector2.from_angle(a) * (rad + 10.0), Color("#d94a3a"), 3.0, true)
	for e in drops:   # cabo estalando
		var p: Dictionary = e["part"]
		if not p["fallen"] and e["t"] < 0.35:
			var top: Vector2 = Vector2(p["rect"].get_center().x, p["rect"].position.y)
			draw_line(top, top + Vector2(0, -60), Color(1, 0.85, 0.4), 3.0, true)
			for k in 3:
				main.spark(top + Vector2(0, -20 - k * 12), 1)
	# S28 muro de solda: 3 painéis encaixam um por um (de baixo para cima; no teto, do meio para os lados) com
	# cordão de solda incandescente que esfria; maçarico do dono soltando faíscas; amassa e racha ao levar tiro
	var wtex := Data.tex("spells/s28_painel")
	var ttex := Data.tex("spells/s28_topo")
	for sh in shields:
		var k: float = sh["k"]
		var left: float = float(sc("S28")["duracao_s"]) - sh["t"]
		var mod := Color(1, 1, 1).lerp(Color(1.8, 1.6, 1.4), sh["flash"])
		if left < 1.0 and fmod(t, 0.2) < 0.1:
			mod.a = 0.55
		var shake: Vector2 = Vector2(sin(t * 90.0), 0) * 3.0 * sh["flash"]
		var dmg := int(sc("S28")["resistencia"]) - int(sh["hp"])
		for i in 3:
			var u := clampf(k * 3.0 - i, 0.0, 1.0)   # 0 → 1 enquanto este painel desce/encaixa
			if u <= 0.0:
				continue
			var pr := _panel_rect(sh, i)
			var drop := (1.0 - _ease_back(u)) * (-34.0 if not sh.get("roof", false) else 0.0)
			var wscale := 1.0 if not sh.get("roof", false) else _ease_back(u)
			var rr := Rect2(pr.position + Vector2(pr.size.x * (1.0 - wscale) / 2.0, drop) + shake, Vector2(pr.size.x * wscale, pr.size.y))
			draw_texture_rect(wtex, rr, false, mod)
			if dmg > i:   # rachado
				draw_polyline(PackedVector2Array([rr.position + Vector2(6, rr.size.y * 0.3), rr.get_center() + Vector2(-2, 4), rr.end - Vector2(8, rr.size.y * 0.25)]), INK, 2.5, true)
			# cordão de solda até o painel de baixo: branco → laranja → cinza
			var heat := clampf(1.0 - (sh["t"] - (i + 0.7) / 3.0 * 0.5) / 1.2, 0.0, 1.0) if u >= 0.7 else 0.0
			var seam_a := Vector2(rr.position.x + 3, rr.end.y) if not sh.get("roof", false) else Vector2(rr.position.x, rr.position.y + 3)
			var seam_b := Vector2(rr.end.x - 3, rr.end.y) if not sh.get("roof", false) else Vector2(rr.position.x, rr.end.y - 3)
			var sc_col := Color(0.42, 0.45, 0.5).lerp(Color(1, 0.55, 0.2), heat).lerp(Color(1, 0.97, 0.85), maxf(heat - 0.6, 0.0) * 2.5)
			draw_line(seam_a, seam_b, sc_col, 4.0, true)
		if not sh.get("roof", false) and k >= 1.0:
			var top: Rect2 = sh["rect"]
			draw_texture_rect(ttex, Rect2(top.position + shake + Vector2(-2, 0), Vector2(top.size.x + 4, 14)), false, mod)
		if k < 1.0:   # maçarico do dono: chama azul e jorro de faíscas até o painel que está encaixando
			var ow = main.robots[sh["owner"]]
			var tip: Vector2 = hand(ow) + Vector2(ow.facing * 14.0, 0)
			var tgt := _panel_rect(sh, mini(int(k * 3.0), 2)).get_center()
			draw_circle(tip, 6.0, Color(0.55, 0.85, 1.0, 0.9))
			draw_circle(tip, 3.0, Color.WHITE)
			for j in 6:
				var v := fposmod(t * 6.0 + j * 0.17, 1.0)
				var q := tip.lerp(tgt, v) + Vector2(sin(j * 3.1 + t * 20.0), cos(j * 2.3 + t * 17.0)) * 10.0 * v
				draw_circle(q, 2.2, Color(1, 0.85, 0.4, 1.0 - v))

## Painel i (0 = base) do muro de solda (ou do teto: 0 = meio, 1 e 2 = lados).
func _panel_rect(sh: Dictionary, i: int) -> Rect2:
	var r: Rect2 = sh["rect"]
	if sh.get("roof", false):
		var w := r.size.x / 3.0
		var order := [1, 0, 2]
		return Rect2(r.position.x + order[i] * w, r.position.y, w, r.size.y)
	return Rect2(r.position.x, r.end.y - (i + 1) * 40.0, r.size.x, 40.0)

## Raio de energia de a até b: zigue-zague que muda a cada 1/20 s, com brilho largo ciano e miolo branco.
## stretch 0..1 (esticado: mais grosso/claro, puxa para o magenta), slack = barriga para baixo, alpha = piscar.
func _draw_bolt(a: Vector2, b: Vector2, stretch: float, slack: float, seed_t: float, alpha := 1.0) -> void:
	var n := maxi(int(a.distance_to(b) / 16.0), 3)
	var nrm := (b - a).normalized().orthogonal()
	var frame := int(t * 20.0)
	var pts := PackedVector2Array()
	for i in n + 1:
		var u := float(i) / n
		var bell := sin(u * PI)
		var jit := 0.0 if i == 0 or i == n else sin(float(frame) * 12.9898 + i * 78.233 + seed_t * 3.1) * (7.0 + 5.0 * stretch)
		pts.append(a.lerp(b, u) + Vector2(0, bell * slack + sin(u * 9.0 + t * 8.0) * slack * 0.15) + nrm * jit)
	var glow := Color(0.25, 0.76, 0.79).lerp(Color(0.85, 0.35, 0.85), stretch * 0.6)
	draw_polyline(pts, Color(glow, 0.35 * alpha), 14.0 + 6.0 * stretch, true)
	draw_polyline(pts, Color(glow, 0.9 * alpha), 5.0 + 2.0 * stretch, true)
	draw_polyline(pts, Color(1, 1, 1, alpha), 2.0, true)

## Ponte: N painéis presos em dobradiça; cada um gira de "em pé" para deitado em sequência (k 0→1); dobra no fim.
func _draw_bridge(x0: float, y: float, dir: float, k: float, left: float, mod: Color, slope := 0.0) -> void:
	var tex := Data.tex("spells/s25_tabua")
	var n := int(float(sc("S25")["comprimento_tiles"]))
	var open := k
	if left < 0.4:
		open = clampf(left / 0.4, 0.0, 1.0)
	var m := mod
	if left < 1.4 and left >= 0.4 and fmod(t, 0.2) < 0.1:
		m = Color(mod.r, mod.g * 0.7, mod.b * 0.6, mod.a)
	var hinge := Vector2(x0, y)
	for i in n:
		var u := clampf(open * n - i, 0.0, 1.0)
		if u <= 0.0:
			break
		var a := lerpf(PI / 2.0, slope, u)   # em pé (dobrado para cima) → deitado (ou na inclinação da rampa)
		var xa := Vector2(dir * cos(a), -sin(a))
		var ya := Vector2(-xa.y, xa.x) * dir
		draw_set_transform_matrix(Transform2D(xa, ya, hinge))
		draw_texture_rect(tex, Rect2(0, -2, 64, 20), false, m)
		draw_set_transform(Vector2.ZERO)
		hinge += xa * 64.0
