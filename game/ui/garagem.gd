extends RefCounted
## GARAGEM: monta e guarda até 8 robôs (modelo, 2 cores, padrão, chapéu, rosto, ferramenta, comemoração).
## Salva em user://garagem.cfg. Na tela de entrada, ▲▼ escolhe entre os robôs de fábrica e os da Garagem.

const Kit := preload("res://ui/kit.gd")
const RobotVis := preload("res://player/robot_visual.gd")
const SLOTS := 8
const NOMES := ["Parafuso", "Faísca", "Tijolinho", "Marretinha", "Zé Graxa", "Ferrugem", "Britadeira", "Rebite",
	"Betoneira", "Cimento", "Porca", "Trinca", "Entulho", "Prumo", "Andaime", "Viga", "Furadinho", "Caçamba",
	"Chapisco", "Sucata"]
const ROWS := ["ROBÔ", "NOME", "MODELO", "COR", "COR 2", "PADRÃO", "CHAPÉU", "ROSTO", "FERRAMENTA", "COMEMORAÇÃO", "SORTEAR", "VOLTAR"]
const DARK := Color("#1f3a40")

var main: Node
var path := "user://garagem.cfg"
var robots: Array = []
var slot := 0
var row := 0
var t := 0.0
var cheer_t := 0.0     # depois de mudar algo, o robô comemora um pouquinho
var _rng := RandomNumberGenerator.new()

func setup(m: Node) -> void:
	main = m
	if "--autotest" in OS.get_cmdline_user_args():
		path = "user://garagem_teste.cfg"   # os testes não mexem na Garagem de verdade
	load_all()

## Robôs iniciais (variados, para a Garagem nunca estar vazia).
func starter(k: int) -> Dictionary:
	var sk := Data.default_skin(k, k % 4)
	sk["nome"] = NOMES[k]
	sk["cor"] = [4, 7, 6, 12, 5, 13, 10, 8][k]
	sk["cor2"] = [9, 8, 3, 14, 3, 9, 4, 3][k]
	sk["padrao"] = [1, 0, 2, 3, 4, 0, 1, 2][k]
	sk["chapeu"] = [1, 2, 9, 3, 5, 10, 7, 12][k]
	sk["rosto"] = [0, 1, 0, 3, 0, 5, 2, 4][k]
	sk["ferramenta"] = [0, 2, 3, 1, 5, 4, 0, 1][k]
	sk["danca"] = k % Data.DANCAS.size()
	return sk

func load_all() -> void:
	robots.clear()
	var cf := ConfigFile.new()
	var saved: Array = []
	if cf.load(path) == OK:
		saved = cf.get_value("garagem", "robos", [])
	for k in SLOTS:
		var sk := starter(k)
		if k < saved.size() and saved[k] is Dictionary:
			for key in sk:
				if saved[k].has(key):
					sk[key] = saved[k][key]
		robots.append(sk)

func save_all() -> void:
	var cf := ConfigFile.new()
	cf.set_value("garagem", "robos", robots)
	cf.save(path)

func open() -> void:
	row = 0
	cheer_t = 0.0
	main.state = main.S.GARAGEM

## Quantos valores tem cada linha editável, e qual chave da aparência ela muda.
func _field(r: int) -> Array:
	match ROWS[r]:
		"MODELO": return ["model", Data.MODELS.size()]
		"COR": return ["cor", Data.PALETA.size()]
		"COR 2": return ["cor2", Data.PALETA.size()]
		"PADRÃO": return ["padrao", Data.PADROES.size()]
		"CHAPÉU": return ["chapeu", Data.ACCS.size()]
		"ROSTO": return ["rosto", Data.ROSTOS.size()]
		"FERRAMENTA": return ["ferramenta", Data.FERRAMENTAS.size()]
		"COMEMORAÇÃO": return ["danca", Data.DANCAS.size()]
	return []

func randomize_robot(sk: Dictionary) -> void:
	_rng.randomize()
	sk["model"] = _rng.randi() % Data.MODELS.size()
	sk["cor"] = _rng.randi() % Data.PALETA.size()
	sk["cor2"] = _rng.randi() % Data.PALETA.size()
	if sk["cor2"] == sk["cor"]:
		sk["cor2"] = (sk["cor"] + 8) % Data.PALETA.size()
	sk["padrao"] = _rng.randi() % Data.PADROES.size()
	sk["chapeu"] = _rng.randi() % Data.ACCS.size()
	sk["rosto"] = _rng.randi() % Data.ROSTOS.size() if _rng.randf() < 0.6 else 0
	sk["ferramenta"] = _rng.randi() % Data.FERRAMENTAS.size()
	sk["danca"] = _rng.randi() % Data.DANCAS.size()

func update(dt: float) -> void:
	t += dt
	cheer_t = maxf(cheer_t - dt, 0.0)
	var m = main.menus
	row = posmod(row + m.move_v(), ROWS.size())
	var h: int = m.move_h()
	var ok: bool = m.confirm()
	var sk: Dictionary = robots[slot]
	var changed := false
	match ROWS[row]:
		"ROBÔ":
			if h != 0:
				slot = posmod(slot + h, SLOTS)
				cheer_t = 0.0
		"NOME":
			if h != 0 or ok:
				var i := NOMES.find(sk["nome"])
				sk["nome"] = NOMES[posmod(i + (h if h != 0 else 1), NOMES.size())]
				changed = true
		"SORTEAR":
			if ok or h != 0:
				randomize_robot(sk)
				changed = true
				Audio.play("caixote_pancada")
		"VOLTAR":
			if ok:
				_leave()
				return
		_:
			var f := _field(row)
			if h != 0 or ok:
				sk[f[0]] = posmod(int(sk[f[0]]) + (h if h != 0 else 1), int(f[1]))
				changed = true
				if f[0] == "model":
					Audio.voice("voz_oi", sk["model"])
	if changed:
		cheer_t = 1.2
		save_all()
	if m.pressed("back"):
		_leave()

func _leave() -> void:
	save_all()
	main.state = main.S.MENU

func _value_text(r: int, sk: Dictionary) -> String:
	match ROWS[r]:
		"ROBÔ": return "%d de %d" % [slot + 1, SLOTS]
		"NOME": return sk["nome"]
		"MODELO": return Data.MODEL_NAMES[sk["model"]]
		"PADRÃO": return Data.PADRAO_NAMES[sk["padrao"]]
		"CHAPÉU": return Data.ACC_NAMES[sk["chapeu"]]
		"ROSTO": return Data.ROSTO_NAMES[sk["rosto"]]
		"FERRAMENTA": return Data.FERRAMENTA_NAMES[sk["ferramenta"]]
		"COMEMORAÇÃO": return Data.DANCAS[sk["danca"]]
	return ""

func look_of(sk: Dictionary, color_idx := 0) -> Dictionary:
	return {"color": color_idx, "model": sk["model"], "acc": sk["chapeu"], "skin": sk}

func draw(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(0, 0, 1920, 1080), Color(0.1, 0.3, 0.35, 0.35))
	Kit.ribbon(ci, Rect2(560, 30, 800, 128), "GARAGEM", 60)
	var sk: Dictionary = robots[slot]
	# vitrine: o robô grande, girando a comemoração quando muda algo ou na linha COMEMORAÇÃO
	var card := Rect2(110, 170, 760, 700)
	Kit.paper(ci, card)
	ci.draw_rect(Rect2(card.position + Vector2(20, card.size.y - 150), Vector2(card.size.x - 40, 12)), Color("#d8c9a8"))
	var dancing: bool = cheer_t > 0.0 or ROWS[row] == "COMEMORAÇÃO"
	var pose: Dictionary = RobotVis.victory_pose(t, sk["danca"]) if dancing else RobotVis.idle_pose(t)
	RobotVis.draw_robot(ci, look_of(sk), pose, Transform2D(0.0, Vector2(4.6, 4.6), 0.0, card.position + Vector2(card.size.x / 2.0, card.size.y - 146)))
	ci.draw_set_transform(Vector2.ZERO)
	Kit.text(ci, Vector2(card.position.x, card.end.y - 92), sk["nome"], 56, DARK, HORIZONTAL_ALIGNMENT_CENTER, card.size.x)
	# os 8 robôs guardados, em miniatura
	for k in SLOTS:
		var c := Vector2(150 + k * 92, 1000)
		if k == slot:
			ci.draw_circle(c + Vector2(0, -34), 44, Color("#f2c84b"))
		ci.draw_circle(c + Vector2(0, -34), 40, Color(1, 1, 1, 0.7))
		RobotVis.draw_robot(ci, look_of(robots[k]), RobotVis.idle_pose(t + k * 0.7), Transform2D(0.0, Vector2(0.75, 0.75), 0.0, c))
		ci.draw_set_transform(Vector2.ZERO)
	# linhas de ajuste
	for r in ROWS.size():
		var rr := Rect2(960, 180 + r * 72, 860, 60)
		var on: bool = r == row
		if on:
			Kit.paper(ci, rr.grow(6), Color("#f2c84b"))
		Kit.paper(ci, rr)
		var col := Color("#1f3a40") if on else Color("#2c4a52")
		var simple: bool = ROWS[r] in ["SORTEAR", "VOLTAR"]
		if simple:
			Kit.text(ci, Vector2(rr.position.x, rr.position.y + 44), ROWS[r] + ("  ★" if ROWS[r] == "SORTEAR" else ""), 34, col, HORIZONTAL_ALIGNMENT_CENTER, rr.size.x)
			continue
		Kit.text(ci, Vector2(rr.position.x + 24, rr.position.y + 44), ROWS[r], 30, col)
		var vx := rr.position.x + 330
		Kit.text(ci, Vector2(vx, rr.position.y + 44), "◄", 30, col if on else Color(col, 0.35))
		Kit.text(ci, Vector2(rr.end.x - 50, rr.position.y + 44), "►", 30, col if on else Color(col, 0.35))
		if ROWS[r] in ["COR", "COR 2"]:
			var key := "cor" if ROWS[r] == "COR" else "cor2"
			for d in range(-3, 4):
				var ci2 := posmod(int(sk[key]) + d, Data.PALETA.size())
				var sc := Vector2(vx + 265 + d * 52, rr.get_center().y)
				var rad := 22.0 if d == 0 else 15.0
				ci.draw_circle(sc, rad + 3.0, Data.INK)
				ci.draw_circle(sc, rad, Color(Data.PALETA[ci2], 1.0 if d == 0 else 0.6))
		else:
			Kit.text(ci, Vector2(vx + 40, rr.position.y + 44), _value_text(r, sk), 32, col, HORIZONTAL_ALIGNMENT_CENTER, 420)
	Kit.text(ci, Vector2(0, 1066), "▲▼ escolher  ·  ◄► mudar  ·  VOLTAR sai (salva sozinho)", 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 1920, 7)
