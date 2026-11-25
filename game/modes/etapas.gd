extends Node2D
## CENAS DO MAPA (modo Derruba; manual docs/manuais/derruba/README.md). Um mapa tem 2..N cenas (etapaN no .lvl; conteúdo
## em data/mapas/<modo>/<mapa>.json). A TRANSIÇÃO não é por tempo: quando a DESTRUIÇÃO ELEGÍVEL da cena atual chega ao
## limiar (modos[derruba].destruicao.limiar = 90%) e existe próxima cena → AVISO ("A OBRA VAI CEDER!", tudo treme) →
## DESABA (a cena inteira cai em pedaços) → QUEDA (sem KO, sem controle, lenta; câmera desce junto) → CENA SEGUINTE
## (câmera, KO, área e nascimentos passam para ela). Dispara UMA vez por cena (trava no estado).
## DIRETOR ADAPTATIVO (proposta do usuário, 2026-11-25): compara o progresso com uma curva até alvo_s (sorteado por cena);
## se os jogadores quebram pouco, derruba peças sozinho (sirene + fita + cai) com mais frequência; se quebram muito, quase
## não age. Na última cena só a deterioração calma. Números: modos[derruba].destruicao; cinemática: demolicao.etapas.

var main: Node
var cfg: Dictionary            # cinemática da transição (demolicao.etapas)
var dcfg: Dictionary           # regra do modo (destruicao)
var etapa := 1                 # cena atual (ordem)
var n_cenas := 1
var state := "etapa"           # etapa · aviso · queda
var st_t := 0.0
var hole := Vector2.ZERO       # faixa x (px) do buraco por onde se cai da cena atual para a próxima
var ativo := true              # testes longos desligam diretor e transição
var t_cena := 0.0              # tempo na cena atual
var alvo := 90.0               # o diretor mira chegar ao limiar perto deste tempo (sorteado por cena)
var dir_t := 0.0               # tempo até a próxima decisão do diretor
var acoes := 0                 # peças derrubadas pelo diretor nesta cena (testes/medição)
var progresso := 0.0           # destruição elegível da cena atual (0..1)

func setup(m: Node) -> void:
	main = m
	cfg = m.demo.cfg["etapas"]
	dcfg = MapaReg.modo_cfg(m.game_mode).get("destruicao", {"limiar": 0.9, "alvo_s": [90, 90], "intervalo_s": [8, 40],
		"chance_calma": 0.25, "aviso_s": 2.5, "deficit_max": 0.3})
	n_cenas = 1
	while String(m.level.prop("etapa%d" % (n_cenas + 1), "")) != "":
		n_cenas += 1
	_nova_cena()

func _nova_cena() -> void:
	t_cena = 0.0
	acoes = 0
	var a: Array = dcfg["alvo_s"]
	alvo = main.rng.randf_range(float(a[0]), float(a[1]))
	dir_t = float(dcfg["intervalo_s"][1]) * 0.5
	var h := String(main.level.prop("buraco%d" % etapa, "")).split(",")
	if h.size() >= 2:
		hole = Vector2(float(h[0]) * 64.0, float(h[1]) * 64.0)
	elif tem_proxima():
		var an: Rect2 = main.level.etapa_rect(etapa + 1)
		hole = Vector2(an.position.x, an.end.x)

func limiar() -> float:
	return float(dcfg["limiar"])

func tem_proxima() -> bool:
	return etapa < n_cenas

func _ct():
	var ct = main.demo.canteiro
	return ct if ct != null and is_instance_valid(ct) else null

func update(dt: float) -> void:
	if main.state != main.S.RUN or main.countdown > 0.0:
		return
	var lv = main.level
	var ct = _ct()
	match state:
		"etapa":
			if not ativo:
				return
			t_cena += dt
			progresso = ct.progresso(etapa) if ct != null else 0.0
			if tem_proxima() and progresso >= limiar():
				_aviso()
				return
			_diretor(dt, ct)
		"aviso":
			st_t -= dt
			main.shake(1.5 + 4.0 * (1.0 - st_t / float(cfg["aviso_s"])))
			if fmod(st_t, 0.6) < dt:
				Audio.play("pistao_aviso", 0.7, -4.0)
			if st_t <= 0.0:
				_desaba()
		"queda":
			st_t += dt
			main.events.gravity_mult *= float(cfg["gravidade_queda"])
			var a2: Rect2 = lv.etapa_rect(etapa + 1)
			var landed := true
			for r in main.robots:
				if not r.alive:
					continue
				r.invuln = maxf(r.invuln, 0.5)
				r.velocity.y = minf(r.velocity.y, float(cfg["queda_vmax"]))   # queda lenta e legível (cena)
				# arco natural: a velocidade de lado calculada no desabamento leva cada um para dentro do buraco
				if r.position.y < a2.position.y + 120.0:
					var vx: float = r.get_meta("queda_vx", 0.0)
					var tx := clampf(r.position.x, hole.x + 60.0, hole.y - 60.0)
					if absf(tx - r.position.x) > 1.0 and r.position.y > a2.position.y - 220.0:
						vx = clampf((tx - r.position.x) * 4.0, -float(cfg["funil_vel"]), float(cfg["funil_vel"]))   # correção final suave
					r.push_vx = vx
				if not (r.is_on_floor() and a2.has_point(r.position)):
					landed = false
			if (landed and st_t > 0.5) or st_t >= float(cfg["queda_max_s"]):
				_chega()

## Diretor adaptativo: mais peças caindo sozinhas quando os jogadores quebram pouco; quase nada quando quebram muito.
func _diretor(dt: float, ct) -> void:
	if ct == null:
		return
	dir_t -= dt
	if dir_t > 0.0:
		return
	var iv: Array = dcfg["intervalo_s"]
	var deficit := limiar() * clampf(t_cena / maxf(alvo, 1.0), 0.0, 1.2) - progresso
	var age := false
	if tem_proxima() and deficit > 0.0:
		var k := clampf(deficit / float(dcfg["deficit_max"]), 0.0, 1.0)
		if t_cena > alvo:
			k = 1.0   # passou do alvo e ainda falta: urgência máxima (no fim falta pouca peça e cada uma pesa muito)
		dir_t = lerpf(float(iv[1]), float(iv[0]), k) * main.rng.randf_range(0.75, 1.25)
		age = true
	else:
		dir_t = float(iv[1]) * main.rng.randf_range(0.8, 1.2)
		age = main.rng.randf() < float(dcfg["chance_calma"])
	if age and ct.can_alert():
		ct.start_alert(float(dcfg["aviso_s"]))   # sirene + fita zebrada no trecho → ele cede
		acoes += 1

## Vitrines/vídeos: começa a transição já (se houver próxima cena).
func forcar() -> void:
	if state == "etapa" and tem_proxima():
		_aviso()

func _aviso() -> void:
	state = "aviso"
	st_t = float(cfg["aviso_s"])
	main.demo.banner = "A OBRA VAI CEDER!"
	main.demo.banner_t = st_t
	Audio.play("alarme", 0.8, 0.0)
	var ct = _ct()
	if ct != null:
		ct.warn_all(st_t, etapa)

## A cena inteira desaba: começa a queda para a próxima.
func _desaba() -> void:
	var lv = main.level
	state = "queda"
	st_t = 0.0
	var ct = _ct()
	if ct != null:
		ct.collapse_all(etapa)
	main.events.stop_all()
	lv.ko_off = true
	lv.area = lv.etapa_rect(etapa).merge(lv.etapa_rect(etapa + 1))
	main.shake(18.0)
	Audio.play("terremoto", 1.0, 2.0)
	Audio.play("explosao", 0.6, -2.0)
	var a2: Rect2 = lv.etapa_rect(etapa + 1)
	var g: float = float(Data.ctrl["gravity"]) * float(cfg["gravidade_queda"])
	var vivos: Array = main.robots.filter(func(r): return r.alive)
	for i in vivos.size():
		var r = vivos[i]
		r.hanging = false
		r.invuln = maxf(r.invuln, 1.0)
		r.spell_lock = true   # sem controle durante a queda (cena)
		# cada um cai num ponto diferente do buraco, no tempo que leva para chegar ao teto
		var tx: float = lerpf(hole.x + 140.0, hole.y - 140.0, (i + 0.5) / maxf(vivos.size(), 1.0))
		if absf(r.position.x - tx) < 200.0:
			tx = clampf(r.position.x, hole.x + 100.0, hole.y - 100.0)
		tx = _over_floor(tx, a2)   # cai sempre em cima de piso (nunca num vão)
		var dy: float = maxf(a2.position.y - r.position.y, 120.0)
		var vm := float(cfg["queda_vmax"])
		var d1 := vm * vm / (2.0 * maxf(g, 1.0))   # acelera até a velocidade limite e depois cai constante
		var tf := sqrt(2.0 * dy / maxf(g, 1.0)) if dy <= d1 else vm / maxf(g, 1.0) + (dy - d1) / vm
		r.set_meta("queda_vx", clampf((tx - r.position.x) / tf, -float(cfg["funil_vel"]), float(cfg["funil_vel"])))
		r.velocity.y = minf(r.velocity.y, -180.0)   # pulinho de susto antes de cair
	var mc = main.demo.mecs
	if mc != null and is_instance_valid(mc):
		mc.desaba(etapa)
	var sp = main.demo.spells
	if sp != null and is_instance_valid(sp):
		for r in vivos:   # voo (jetpack) e transformações acabam: ninguém escapa da queda
			var sid: String = sp.flags(r).get("spell", "")
			if sid in ["T04", "T01", "T02", "T03", "T05", "T06", "T07"]:
				sp.clear(r)
		for b in sp.boxes:   # caixas da cena que caiu vão pelo buraco (nunca ficam em cima do teto da próxima)
			b["pos"].x = _over_floor(clampf(b["pos"].x, hole.x + 80.0, hole.y - 80.0), a2)
			b["vy"] = 0.0

## x mais perto de tx que tem piso embaixo na cena a2 (os vãos entre as lajes são KO).
func _over_floor(tx: float, a2: Rect2) -> float:
	var lv = main.level
	for k in 24:
		for sg in [1, -1]:
			var x: float = tx + sg * k * 32.0
			var c := int(floor(x / 64.0))
			for row in range(int(a2.position.y / 64.0) + 4, int(a2.end.y / 64.0)):
				if lv.is_solid(Vector2i(c, row)) and lv.is_solid(Vector2i(c - 1, row)) and lv.is_solid(Vector2i(c + 1, row)):
					return x
	return tx

## Todos pousaram na cena seguinte: câmera, KO e área de jogo passam para ela.
func _chega() -> void:
	var lv = main.level
	state = "etapa"
	etapa += 1
	lv.etapa_n = etapa
	lv.area = lv.etapa_rect(etapa)
	lv.ko_off = false
	var cn := MapaReg.cena(main.game_mode, lv.id, etapa)
	main.demo.banner = String(cn.get("nome", "CENA %d" % etapa)).to_upper() + "!"
	main.demo.banner_t = 2.0
	main.shake(10.0)
	Audio.play("caixote_quebra", 0.6, 0.0)
	_nova_cena()
	for r in main.robots:
		r.spell_lock = false
		if r.has_meta("queda_vx"):
			r.remove_meta("queda_vx")
		if r.alive:
			r.invuln = maxf(r.invuln, float(cfg["invuln_chegada_s"]))
			main.dust(r.position, 1.2)
			if not lv.area.grow(64).has_point(r.position) or r.position.y < lv.area.position.y + 140.0:   # ficou fora ou em cima do teto: nasce embaixo
				main.demo.respawn(r)

## Nascimento na cena atual (nascimentos 1–4 na cena 1, 5–8 na cena 2, 9–12 na 3…).
func spawn_index(i: int) -> int:
	return i + 4 * (etapa - 1)
