extends Node2D
## MECANISMOS DA FASE (cartilha do mapa, Z7): armadilhas/máquinas próprias de cada fase, com aviso visível, ciclo legível
## e interação do jogador (marretar alavanca/botão/registro/trava). Cada TIPO é uma receita reaproveitável; a fase só lista
## quais usa, onde e em que etapa: data/modos.json → demolicao.mecanismos.<cena> (ex.: "fase1").
## A Inspeção (G09) pausa todos. Golpe da máquina = do ambiente (by -1), a não ser que um jogador a acione.
## Tipos: betoneira (concreto fresco), elevador (plataforma de cremalheira), esteira (leva para fora; botão inverte),
## tubos (marretar solta tubos rolando), serra (sobe da bancada em ciclo), bate_estaca (martela uma faixa),
## agua (alagamento; registro drena), vagonete (passa varrendo o piso), gerador (faísca; com água dá choque).

const T := 64.0
const INK := Color("#2a1a2e")
var main: Node
var list: Array = []          # instâncias {tipo, etapa, d (dados do data), s (estado)}
var tex := {}
var t := 0.0

func setup(m: Node) -> void:
	main = m
	var key := String(m.level.prop("cena", ""))
	var all: Dictionary = m.demo.cfg.get("mecanismos", {})
	for d in all.get(key, []):
		var inst := {"tipo": d["tipo"], "etapa": int(d.get("etapa", 1)), "d": d, "s": {}}
		list.append(inst)
		_prepara(inst)
	for n in ["m_betoneira", "m_esteira", "m_tubo", "m_serra", "m_bancada", "m_martelo", "m_vagonete", "m_gerador"]:
		tex[n] = Data.tex("%s/%s" % [key, n])

func _etapa() -> int:
	var et = main.demo.etapas
	return et.etapa if et != null and is_instance_valid(et) else 1

func _on(inst: Dictionary) -> bool:
	return inst["etapa"] == _etapa() and not inst["s"].get("gone", false)

func _v(a) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))

func _body(r: Rect2, layer := 1, oneway := false, animated := false) -> StaticBody2D:
	var b: StaticBody2D = AnimatableBody2D.new() if animated else StaticBody2D.new()
	if animated:
		b.sync_to_physics = false
	b.collision_layer = layer
	b.collision_mask = 0
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = r.size
	cs.shape = sh
	cs.position = r.get_center()
	cs.one_way_collision = oneway
	b.add_child(cs)
	add_child(b)
	return b

func _prepara(inst: Dictionary) -> void:
	var d: Dictionary = inst["d"]
	var s: Dictionary = inst["s"]
	s["t"] = float(d.get("fase_s", 0.0))
	match String(inst["tipo"]):
		"elevador":
			var base := _v(d["base"])
			s["y"] = base.y
			s["body"] = _body(Rect2(base.x, base.y, float(d["largura"]), 18), 2, true, true)
		"serra":
			var p := _v(d["pos"])
			s["plat"] = _body(Rect2(float(d["passarela"][0]), p.y, float(d["passarela"][1]) - float(d["passarela"][0]), 14), 2, true)
			s["k"] = 0.0
		"tubos":
			s["pile"] = 6
			s["rolling"] = []
			s["reload"] = 0.0
		"agua":
			s["h"] = 0.0
		"vagonete":
			s["x"] = -1.0

## Virada: os mecanismos da etapa que desabou somem (corpos fora; caem como entulho).
func desaba(etapa: int) -> void:
	for inst in list:
		if inst["etapa"] != etapa:
			continue
		var s: Dictionary = inst["s"]
		for k in ["body", "plat"]:
			if s.has(k) and is_instance_valid(s[k]):
				s[k].queue_free()
		s["gone"] = true
		var p = inst["d"].get("pos", inst["d"].get("base", null))
		if p != null:
			main.dust(_v(p), 1.4)

## Robôs vivos que estão nesta etapa.
func _robots() -> Array:
	return main.robots.filter(func(r): return r.alive)

func update(dt: float) -> void:
	t += dt
	if main.state != main.S.RUN or main.countdown > 0.0:
		queue_redraw()
		return
	var paused: bool = main.events != null and main.events.inspecao
	for inst in list:
		if not _on(inst):
			continue
		var s: Dictionary = inst["s"]
		if paused:
			continue
		s["t"] += dt
		match String(inst["tipo"]):
			"betoneira": _betoneira(inst, dt)
			"elevador": _elevador(inst, dt)
			"esteira": _esteira(inst, dt)
			"tubos": _tubos(inst, dt)
			"serra": _serra(inst, dt)
			"bate_estaca": _bate_estaca(inst, dt)
			"agua": _agua(inst, dt)
			"vagonete": _vagonete(inst, dt)
			"gerador": _gerador(inst, dt)
	queue_redraw()

# ---------------------------------------------------------------- tipos
func _betoneira(inst: Dictionary, dt: float) -> void:
	var d: Dictionary = inst["d"]
	var s: Dictionary = inst["s"]
	var cyc := float(d["ciclo_s"])
	if float(s.get("force", 0.0)) > 0.0:   # alavanca marretada: despeja já
		s["t"] = cyc - float(d["aviso_s"])
		s["force"] = 0.0
	var k: float = s["t"]
	if k >= cyc:
		s["t"] = 0.0
		s["fresh"] = float(d["fresco_s"])
		Audio.play("lama", 0.8, -2.0)
		if not s.get("told", false):
			s["told"] = true
			main.float_text(Vector2(float(d["faixa"][0] + d["faixa"][1]) / 2.0, float(d["chao"]) - 90), "CONCRETO FRESCO: GRUDA!", Color("#f2c84b"))
		main.dust(Vector2(float(d["faixa"][0] + d["faixa"][1]) / 2.0, float(d["chao"])), 1.0)
	s["fresh"] = maxf(float(s.get("fresh", 0.0)) - dt, 0.0)
	if float(s["fresh"]) > 0.0:
		var x0 := float(d["faixa"][0])
		var x1 := float(d["faixa"][1])
		for r in _robots():
			if r.is_on_floor() and r.position.x > x0 and r.position.x < x1 and absf(r.position.y - float(d["chao"])) < 12.0:
				r.env_slow = minf(r.env_slow, float(d["lentidao"]))
	if k > cyc - float(d["aviso_s"]) and fmod(k, 0.4) < dt:
		Audio.play("pistao_aviso", 1.3, -8.0)

func _elevador(inst: Dictionary, dt: float) -> void:
	var d: Dictionary = inst["d"]
	var s: Dictionary = inst["s"]
	var y0 := float(d["base"][1])
	var y1 := float(d["topo"])
	var w := float(d["espera_s"])
	var m := float(d["move_s"])
	var cyc := 2.0 * (w + m)
	var k := fmod(float(s["t"]), cyc)
	var y: float
	if k < w:
		y = y0
	elif k < w + m:
		y = lerpf(y0, y1, smoothstep(0.0, 1.0, (k - w) / m))
	elif k < 2.0 * w + m:
		y = y1
	else:
		y = lerpf(y1, y0, smoothstep(0.0, 1.0, (k - 2.0 * w - m) / m))
	s["y"] = y
	s["moving"] = absf(y - y0) > 0.5 and absf(y - y1) > 0.5
	s["warn"] = (k > w - 0.8 and k < w) or (k > 2.0 * w + m - 0.8 and k < 2.0 * w + m)
	var b = s["body"]
	if is_instance_valid(b):
		b.position = Vector2(0, y - y0)

func _esteira(inst: Dictionary, dt: float) -> void:
	var d: Dictionary = inst["d"]
	var s: Dictionary = inst["s"]
	var inv := float(d["inverte_s"])
	if float(s["t"]) >= inv:
		s["t"] = 0.0
		s["dir"] = -int(s.get("dir", int(d["dir"])))
		Audio.play("alavanca", 1.4, -6.0)
	var dir := int(s.get("dir", int(d["dir"])))
	s["blink"] = float(s["t"]) > inv - 1.2
	var x0 := float(d["x"][0])
	var x1 := float(d["x"][1])
	for r in _robots():
		if r.is_on_floor() and r.position.x > x0 and r.position.x < x1 and absf(r.position.y - float(d["chao"])) < 12.0:
			r.push_vx += dir * float(d["vel"])

func _tubos(inst: Dictionary, dt: float) -> void:
	var d: Dictionary = inst["d"]
	var s: Dictionary = inst["s"]
	var ch := float(d["chao"])
	if int(s["pile"]) == 0:
		s["reload"] = float(s["reload"]) - dt
		if float(s["reload"]) <= 0.0:
			s["pile"] = 6
			main.dust(_v(d["pos"]), 1.0)
	for tb in (s["rolling"] as Array).duplicate():
		tb["vx"] = move_toward(tb["vx"], 0.0, 40.0 * dt)
		tb["x"] += tb["vx"] * dt
		tb["rot"] += tb["vx"] * dt / 38.0
		var on_ground: bool = main.level.is_solid(Vector2i(int(tb["x"] / T), int((tb["y"] + 2.0) / T)))
		var ct = main.demo.canteiro
		if ct != null and is_instance_valid(ct):
			for p in ct.parts:
				if not p["fallen"] and p["rect"].has_point(Vector2(tb["x"], tb["y"] + 4.0)):
					on_ground = true
		if not on_ground:
			tb["vy"] += 2000.0 * dt
			tb["y"] += tb["vy"] * dt
		var hr := Rect2(tb["x"] - 36.0, tb["y"] - 72.0, 72.0, 72.0)
		for r in _robots():
			if r.rect().intersects(hr) and not tb["hit"].has(r.pid) and absf(tb["vx"]) > 80.0:
				tb["hit"][r.pid] = true
				r.take_hit(1 if tb["vx"] > 0.0 else -1, "mec_tubo", int(tb["by"]))
		if tb["y"] > main.level.area.end.y + 300.0 or absf(tb["vx"]) < 10.0 and on_ground:
			(s["rolling"] as Array).erase(tb)
			main.dust(Vector2(tb["x"], tb["y"]), 0.8)

func _serra(inst: Dictionary, dt: float) -> void:
	var d: Dictionary = inst["d"]
	var s: Dictionary = inst["s"]
	if s.get("broken", false):
		return
	var on_top := 0   # D6: 2 robôs pulando em cima partem a passarela
	for r in _robots():
		if r.is_on_floor() and r.position.x > float(d["passarela"][0]) and r.position.x < float(d["passarela"][1]) and absf(r.position.y - float(d["pos"][1])) < 10.0:
			on_top += 1
	if on_top >= 2:
		_break_walkway(inst)
		return
	var on := float(d["ligada_s"])
	var off := float(d["desligada_s"])
	var k := fmod(float(s["t"]), on + off)
	var up := k < on
	s["k"] = move_toward(float(s["k"]), 1.0 if up else 0.0, dt * 5.0)
	s["warn"] = k > on + off - 0.8
	if float(s["k"]) > 0.6:
		var p := _v(d["pos"])
		var hr := Rect2(p.x - 34.0, p.y - 70.0, 68.0, 70.0)
		s["cd"] = s.get("cd", {})
		for r in _robots():
			if r.rect().intersects(hr) and float(s["cd"].get(r.pid, 0.0)) <= t:
				s["cd"][r.pid] = t + 0.8
				r.take_hit(1 if r.position.x >= p.x else -1, "mec_serra", -1)
				main.spark(p + Vector2(0, -30), 8)
		if fmod(t, 0.25) < dt:
			Audio.play("serra", 1.2, -10.0)

## D6: a passarela parte no meio e a serra cai junto (fica quebrada até o fim da rodada).
func _break_walkway(inst: Dictionary) -> void:
	var s: Dictionary = inst["s"]
	s["broken"] = true
	s["fall"] = 0.0
	if is_instance_valid(s["plat"]):
		s["plat"].queue_free()
	var d: Dictionary = inst["d"]
	main.dust(_v(d["pos"]), 1.4)
	main.shake(6.0)
	Audio.play("caixote_quebra", 0.9, 0.0)
	main.float_text(_v(d["pos"]) + Vector2(0, -80), "PASSARELA PARTIU!", Color("#f2c84b"))

func _bate_estaca(inst: Dictionary, dt: float) -> void:
	var d: Dictionary = inst["d"]
	var s: Dictionary = inst["s"]
	var cyc := float(d["ciclo_s"])
	var k := fmod(float(s["t"]), cyc)
	var aviso := float(d["aviso_s"])
	var top := float(d["topo"])
	var floor_y := float(d["chao"])
	var hy: float = top
	var phase := "sobe"
	if k < cyc - aviso - 0.15:
		hy = lerpf(floor_y - 90.0, top, clampf(k / 1.0, 0.0, 1.0))
	elif k < cyc - 0.15:
		hy = top + sin(t * 60.0) * 3.0
		phase = "aviso"
	else:
		hy = lerpf(top, floor_y - 90.0, (k - (cyc - 0.15)) / 0.15)
		phase = "bate"
	if phase == "bate" and s.get("last", "") != "bate":
		s["hit"] = {}
	if phase != "bate" and s.get("last", "") == "bate":
		main.shake(6.0)
		Audio.play("pistao", 0.6, 0.0)
		main.dust(Vector2(float(d["x"]), floor_y), 1.6)
		var ct = main.demo.canteiro   # cada batida trinca a grelha do poço embaixo (abre sozinha depois de algumas)
		if ct != null and is_instance_valid(ct):
			for p in ct.parts:
				if p["kind"] == "grelha" and not p["fallen"] and p["rect"].has_point(Vector2(float(d["x"]), p["rect"].get_center().y)):
					ct.damage(p, 1, Vector2(float(d["x"]), floor_y))
	s["last"] = phase
	s["y"] = hy
	s["phase"] = phase
	if phase == "bate":
		var hr := Rect2(float(d["x"]) - 60.0, hy, 120.0, floor_y - hy)
		for r in _robots():
			if r.rect().intersects(hr) and not s["hit"].has(r.pid):
				s["hit"][r.pid] = true
				r.take_hit(1 if r.position.x >= float(d["x"]) else -1, "mec_estaca", -1)

func _agua(inst: Dictionary, dt: float) -> void:
	var d: Dictionary = inst["d"]
	var s: Dictionary = inst["s"]
	var cyc := float(d["ciclo_s"])
	if float(s.get("enchente", 0.0)) > 0.0:   # V3 Enchente: a bomba falha e a água sobe bem alto
		s["enchente"] = float(s["enchente"]) - dt
		s["h"] = move_toward(float(s["h"]), float(d["altura"]) * float(s.get("enchente_mult", 2.4)), float(d["altura"]) * dt)
		var top0 := float(d["chao"]) - float(s["h"])
		for r in _robots():
			if r.position.x > float(d["x"][0]) and r.position.x < float(d["x"][1]) and r.position.y > top0:
				r.env_slow = minf(r.env_slow, float(d["lentidao"]))
		return
	if float(s.get("dreno", 0.0)) > 0.0:
		s["dreno"] = float(s["dreno"]) - dt
		s["h"] = move_toward(float(s["h"]), 0.0, float(d["altura"]) / 1.0 * dt)
		return
	var k := fmod(float(s["t"]), cyc)
	var sobe := float(d["sobe_s"])
	var fica := float(d["fica_s"])
	var target := 0.0
	if k < sobe:
		target = float(d["altura"]) * k / sobe
	elif k < sobe + fica:
		target = float(d["altura"])
	elif k < 2.0 * sobe + fica:
		target = float(d["altura"]) * (1.0 - (k - sobe - fica) / sobe)
	s["h"] = target
	var top := float(d["chao"]) - float(s["h"])
	if float(s["h"]) > 8.0:
		for r in _robots():
			if r.position.x > float(d["x"][0]) and r.position.x < float(d["x"][1]) and r.position.y > top:
				r.env_slow = minf(r.env_slow, float(d["lentidao"]))

func _vagonete(inst: Dictionary, dt: float) -> void:
	var d: Dictionary = inst["d"]
	var s: Dictionary = inst["s"]
	var cyc := float(d["ciclo_s"])
	var k := fmod(float(s["t"]), cyc)
	var x0 := float(d["x"][0])
	var x1 := float(d["x"][1])
	var dur := (x1 - x0) / float(d["vel"])
	var start := cyc - dur
	s["warn"] = k > start - float(d["aviso_s"]) and k < start
	if k >= start:
		var u := (k - start) / dur
		var dir := 1 if int(floor(float(s["t"]) / cyc)) % 2 == 0 else -1
		s["dir"] = dir
		s["x"] = lerpf(x0, x1, u) if dir > 0 else lerpf(x1, x0, u)
		if fmod(t, 0.3) < dt:
			Audio.play("barril", 0.7, -8.0)
		var hr := Rect2(float(s["x"]) - 80.0, float(d["chao"]) - 100.0, 160.0, 100.0)
		s["hit"] = s.get("hit", {})
		for r in _robots():
			if r.rect().intersects(hr) and float(s["hit"].get(r.pid, 0.0)) <= t:
				s["hit"][r.pid] = t + 1.0
				r.take_hit(dir, "mec_vagonete", -1)
	else:
		s["x"] = -1.0
		if s["warn"] and fmod(t, 0.5) < dt:
			Audio.play("alarme", 1.6, -8.0)

func _gerador(inst: Dictionary, dt: float) -> void:
	var d: Dictionary = inst["d"]
	var s: Dictionary = inst["s"]
	if float(s.get("off", 0.0)) > 0.0:
		s["off"] = float(s["off"]) - dt
		s["spark"] = false
		return
	var cyc := float(d["ciclo_s"])
	var k := fmod(float(s["t"]), cyc)
	s["spark"] = k > cyc - float(d["faisca_s"])
	if s["spark"]:
		if fmod(t, 0.15) < dt:
			main.spark(_v(d["cabo"]), 3)
		var agua = _find("agua")
		if agua != null and float(agua["s"]["h"]) > 20.0:   # água alta + faísca = choque em quem está na água
			var ad: Dictionary = agua["d"]
			var top := float(ad["chao"]) - float(agua["s"]["h"])
			s["hit"] = s.get("hit", {})
			for r in _robots():
				if r.position.y > top and r.position.x > float(ad["x"][0]) and r.position.x < float(ad["x"][1]) and float(s["hit"].get(r.pid, 0.0)) <= t:
					s["hit"][r.pid] = t + 1.2
					r.take_hit(0, "mec_choque", -1)
					main.spark(r.position + Vector2(0, -30), 6)

func _find(tipo: String):
	for inst in list:
		if inst["tipo"] == tipo and _on(inst):
			return inst
	return null

## Marretada nos controles: alavanca da betoneira (despeja), botão da esteira (inverte), pilha de tubos (solta),
## registro (drena a água), gerador (desliga), trava do bate-estaca (segura uma batida).
func hammer_hit(hit: Rect2, heavy: bool, by := -1) -> bool:
	for inst in list:
		if not _on(inst):
			continue
		var d: Dictionary = inst["d"]
		var s: Dictionary = inst["s"]
		if not d.has("alvo"):
			continue
		var a: Array = d["alvo"]
		var ar := Rect2(float(a[0]), float(a[1]), float(a[2]), float(a[3]))
		if not ar.intersects(hit):
			continue
		main.spark(ar.get_center(), 5)
		Audio.play("chave", 0.9, -2.0)
		match String(inst["tipo"]):
			"betoneira":
				s["force"] = 1.0
			"esteira":
				s["t"] = float(d["inverte_s"])
			"tubos":
				if not heavy or int(s["pile"]) == 0:
					return true
				var dir := 1 if by < 0 or main.robots[by].position.x < ar.get_center().x else -1
				for k in 3:
					(s["rolling"] as Array).append({"x": ar.get_center().x + dir * k * 40.0, "y": float(d["chao"]), "vx": dir * (520.0 - k * 60.0), "vy": 0.0,
						"rot": 0.0, "hit": {}, "by": by})
				s["pile"] = 0
				s["reload"] = float(d["recarga_s"])
				Audio.play("barril", 0.8, 0.0)
				main.shake(5.0)
			"agua":
				s["dreno"] = float(d["dreno_s"])
			"gerador":
				s["off"] = float(d["desliga_s"])
				main.float_text(ar.get_center() + Vector2(0, -60), "DESLIGOU", Color("#9ff7c8"))
			"bate_estaca":
				s["t"] = float(s["t"]) - 2.0
		return true
	for inst in list:   # D6: marretada pesada na passarela
		if inst["tipo"] == "serra" and _on(inst) and heavy and not inst["s"].get("broken", false):
			var d2: Dictionary = inst["d"]
			var pr := Rect2(float(d2["passarela"][0]), float(d2["pos"][1]) - 10.0, float(d2["passarela"][1]) - float(d2["passarela"][0]), 34.0)
			if pr.intersects(hit):
				_break_walkway(inst)
				return true
	return false

# ---------------------------------------------------------------- desenho
func _draw() -> void:
	var v: Rect2 = main.view_rect().grow(300)
	for inst in list:
		if not _on(inst):
			continue
		var d: Dictionary = inst["d"]
		var s: Dictionary = inst["s"]
		match String(inst["tipo"]):
			"betoneira":
				var p := _v(d["pos"])
				var aviso: bool = float(s["t"]) > float(d["ciclo_s"]) - float(d["aviso_s"])
				var spin := t * (6.0 if aviso else 2.0)
				draw_texture_rect(tex["m_betoneira"], Rect2(p + Vector2(-70, -160), Vector2(330, 170)), false)
				# alavanca brilha quando alguém chega perto (dá para acionar a armadilha)
				var lv := Rect2(float(d["alvo"][0]), float(d["alvo"][1]), float(d["alvo"][2]), float(d["alvo"][3]))
				for r in _robots():
					if r.position.distance_to(lv.get_center()) < 140.0:
						draw_arc(lv.get_center(), 30.0 + 3.0 * sin(t * 8.0), 0, TAU, 20, Color(1, 0.9, 0.4, 0.8), 4.0, true)
						break
				var pour := float(s.get("fresh", 0.0)) > float(d["fresco_s"]) - 0.9
				if pour:   # jato de concreto saindo da bica
					var bx := p + Vector2(140, -66)
					var fx := Vector2(float(d["faixa"][0] + d["faixa"][1]) / 2.0, float(d["chao"]) - 10)
					draw_line(bx, fx, Color("#b9b2a6"), 18.0, true)
					draw_line(bx, fx, Color("#d6d0c4"), 8.0, true)
				for k in 3:   # listras do tambor correndo (tambor girando)
					var u := fposmod(spin * 0.15 + k / 3.0, 1.0)
					draw_line(p + Vector2(-40 + u * 90, -140 + u * 30), p + Vector2(-50 + u * 90, -60), Color(1, 0.82, 0.54, 0.8), 6.0, true)
				var f := float(s.get("fresh", 0.0))
				var x0 := float(d["faixa"][0])
				var x1 := float(d["faixa"][1])
				var ch := float(d["chao"])
				if f > 0.0:
					var al := minf(f, 1.0)
					draw_rect(Rect2(x0, ch - 12, x1 - x0, 14), Color(0.72, 0.7, 0.66, al))
					draw_line(Vector2(x0 + 10, ch - 9), Vector2(x1 - 10, ch - 9), Color(1, 1, 1, 0.5 * al), 3.0)
					for k in 4:   # bolhas do concreto fresco
						var bxx := x0 + 20.0 + fmod(k * 37.0 + t * 9.0, x1 - x0 - 40.0)
						draw_circle(Vector2(bxx, ch - 12 - fmod(t * 6.0 + k, 1.0) * 4.0), 3.0, Color(0.9, 0.88, 0.84, al))
				if float(s["t"]) > float(d["ciclo_s"]) - float(d["aviso_s"]) and fmod(t, 0.3) < 0.15:
					draw_rect(Rect2(x0, ch - 4, x1 - x0, 6), Color("#f2c84b"))
			"elevador":
				var x := float(d["base"][0])
				var w := float(d["largura"])
				var y: float = s["y"]
				var mast := float(d["mastro"])
				draw_rect(Rect2(mast - 10, float(d["topo"]) - 60, 20, float(d["base"][1]) - float(d["topo"]) + 60), Color("#8d98a4"))
				for yy in range(int(float(d["topo"]) - 50), int(float(d["base"][1])), 24):
					draw_line(Vector2(mast - 10, yy), Vector2(mast + 10, yy + 12), Color("#6b7783"), 3.0)
				draw_rect(Rect2(x, y, w, 18), Color("#f2c84b"))
				draw_rect(Rect2(x, y + 18, w, 6), INK)
				draw_polyline(PackedVector2Array([Vector2(x, y), Vector2(x, y - 70), Vector2(x + w, y - 70), Vector2(x + w, y)]), Color("#6b7783"), 5.0)
				for k in 4:
					draw_line(Vector2(x + 10 + k * w / 4.0, y - 66), Vector2(x + 10 + k * w / 4.0, y), Color("#6b7783"), 2.0)
				var on: bool = s.get("warn", false) or s.get("moving", false)
				draw_circle(Vector2(x + w / 2.0, y - 82), 9.0, Color("#f08a3d") if on and fmod(t, 0.4) < 0.25 else Color("#8a4a2a"))
			"esteira":
				var x0 := float(d["x"][0])
				var x1 := float(d["x"][1])
				var ch := float(d["chao"])
				var dir := int(s.get("dir", int(d["dir"])))
				# a esteira fica PARADA no lugar (antes ela era espelhada a cada inversão e parecia pular); só as setas andam
				draw_texture_rect(tex["m_esteira"], Rect2(x0 - 8, ch - 66, 300, 70), false)
				var blink: bool = s.get("blink", false) and fmod(t, 0.3) < 0.15
				var sc := fposmod(t * float(d["vel"]) * 0.25 * dir, 40.0)
				var x := x0 + sc
				while x < x0 + 230.0:
					var ax := x
					var tip := Vector2(ax + dir * 8.0, ch - 17)
					draw_colored_polygon(PackedVector2Array([tip, Vector2(ax - dir * 8.0, ch - 24), Vector2(ax - dir * 8.0, ch - 10)]), Color("#ffffff") if blink else Color("#f2c84b"))
					x += 40.0
			"tubos":
				var p := _v(d["pos"])
				var spots := [Vector2(0, 0), Vector2(78, 0), Vector2(156, 0), Vector2(39, -66), Vector2(117, -66), Vector2(78, -132)]
				for k in int(s["pile"]):
					draw_texture_rect(tex["m_tubo"], Rect2(p + spots[k] - Vector2(42, 80), Vector2(84, 84)), false)
				for tb in s["rolling"]:
					draw_set_transform(Vector2(tb["x"], tb["y"] - 38.0), tb["rot"], Vector2.ONE)
					draw_texture_rect(tex["m_tubo"], Rect2(-42, -42, 84, 84), false)
					draw_set_transform(Vector2.ZERO)
			"serra":
				var p := _v(d["pos"])
				var x0 := float(d["passarela"][0])
				var x1 := float(d["passarela"][1])
				if s.get("broken", false):   # metades penduradas + serra caída lá embaixo
					s["fall"] = minf(float(s.get("fall", 0.0)) + 0.016, 1.0)
					var mid := (x0 + x1) / 2.0
					draw_set_transform(Vector2(x0, p.y), 0.9, Vector2.ONE)
					draw_rect(Rect2(0, 0, mid - x0, 14), Color("#d9a05e"))
					draw_set_transform(Vector2(x1, p.y), PI - 0.9, Vector2.ONE)
					draw_rect(Rect2(0, -14, x1 - mid, 14), Color("#d9a05e"))
					draw_set_transform(Vector2.ZERO)
					continue
				for x in range(int(x0), int(x1), 40):
					draw_rect(Rect2(x, p.y, 38, 14), Color("#d9a05e"))
				draw_line(Vector2(x0, p.y - 30), Vector2(x1, p.y - 30), Color("#f2c84b"), 4.0)
				var k := float(s["k"])
				draw_set_transform(p + Vector2(0, -12 - 34 * k), t * 30.0 * k, Vector2.ONE)
				draw_texture_rect(tex["m_serra"], Rect2(-38, -38, 76, 76), false)
				draw_set_transform(Vector2.ZERO)
				draw_texture_rect(tex["m_bancada"], Rect2(p + Vector2(-55, -34), Vector2(110, 40)), false)
				if s.get("warn", false) and fmod(t, 0.2) < 0.1:
					draw_circle(p + Vector2(48, -30), 6.0, Color("#d94a3a"))
			"bate_estaca":
				var x := float(d["x"])
				var top := float(d["topo"]) - 300.0
				var hy: float = s.get("y", float(d["topo"]))
				draw_rect(Rect2(x - 22, top, 44, hy - top + 10), Color("#e7b941"))
				for yy in range(int(top), int(hy), 40):
					draw_line(Vector2(x - 22, yy), Vector2(x + 22, yy + 40), Color("#c49a2a"), 4.0)
				draw_texture_rect(tex["m_martelo"], Rect2(x - 70, hy, 140, 110), false)
				var ch := float(d["chao"])
				var warn: bool = s.get("phase", "") == "aviso"
				draw_rect(Rect2(x - 70, ch - 6, 140, 8), Color(0.85, 0.29, 0.23, 0.9 if warn and fmod(t, 0.2) < 0.1 else 0.5))
			"agua":
				var h: float = s["h"]
				if h > 1.0:
					var x0 := float(d["x"][0])
					var x1 := float(d["x"][1])
					var ch := float(d["chao"])
					draw_rect(Rect2(x0, ch - h, x1 - x0, h), Color(0.31, 0.53, 0.66, 0.5))
					for x in range(int(x0) + 40, int(x1), 160):
						var wy := ch - h + sin(t * 3.0 + x * 0.02) * 3.0
						draw_polyline(PackedVector2Array([Vector2(x, wy), Vector2(x + 20, wy - 5), Vector2(x + 40, wy), Vector2(x + 60, wy - 5), Vector2(x + 80, wy)]), Color(0.75, 0.91, 0.94, 0.8), 3.0, true)
			"vagonete":
				var x0 := float(d["x"][0])
				var x1 := float(d["x"][1])
				var ch := float(d["chao"])
				draw_line(Vector2(x0, ch - 4), Vector2(x1, ch - 4), Color("#3a3a46"), 5.0)
				if float(s["x"]) >= 0.0:
					draw_set_transform(Vector2(s["x"], ch - 110), 0.0, Vector2(int(s.get("dir", 1)), 1))
					draw_texture_rect(tex["m_vagonete"], Rect2(-85, 0, 170, 110), false)
					draw_colored_polygon(PackedVector2Array([Vector2(80, 36), Vector2(260, 0), Vector2(260, 80)]), Color(1, 0.96, 0.78, 0.2))
					draw_set_transform(Vector2.ZERO)
				elif s.get("warn", false):
					var side := x0 if int(floor(float(s["t"]) / float(d["ciclo_s"]))) % 2 == 0 else x1
					draw_circle(Vector2(side, ch - 60), 12.0 + 4.0 * sin(t * 20.0), Color(1, 0.85, 0.3, 0.8))
			"gerador":
				var p := _v(d["pos"])
				draw_texture_rect(tex["m_gerador"], Rect2(p - Vector2(85, 130), Vector2(170, 130)), false, Color(0.6, 0.6, 0.6) if float(s.get("off", 0.0)) > 0.0 else Color.WHITE)
				var cb := _v(d["cabo"])
				draw_polyline(PackedVector2Array([p + Vector2(80, -70), p.lerp(cb, 0.5) + Vector2(0, 60), cb]), INK, 6.0, true)
				if s.get("spark", false):
					for k in 4:
						var a := randf() * TAU
						draw_line(cb, cb + Vector2.from_angle(a) * randf_range(10, 26), Color("#ffd36b"), 3.0, true)
