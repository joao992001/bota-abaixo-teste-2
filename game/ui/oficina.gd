extends Node
## OFICINA: ambiente de testes de mecânicas e objetos (menu principal ▸ OFICINA).
## Arena-mostruário (levels/oficina.lvl) ou qualquer arena, respawn infinito, rodada sem fim.
## START / Enter / Tab abre o painel (o jogo pausa); ▲▼ escolhe, ◄► muda, PULAR confirma.
## Outro controle pode entrar a qualquer hora apertando PULAR.

const Kit := preload("res://ui/kit.gd")
var main: Node
var open := false
var sel := 0
var item_i := 0
var drop_i := 0
var event_i := 0
var arena_i := 0
var god := false
var slow := false

const ROWS := ["dar", "soltar", "evento", "arena", "recarregar", "boneco", "bot", "invencivel", "zerar", "lento", "hitbox", "voltar", "sair"]

func setup(m: Node) -> void:
	main = m

func kinds() -> Array:
	return main.demo.cfg["itens"]["kinds"]

func arenas() -> Array:
	var out: Array = [{"id": "oficina", "nome": "Oficina"}]
	out.append_array(main.demo.cfg["arenas"])
	return out

func events() -> Array:
	return main.events.cfg["lista"]

## Entra na Oficina com o dispositivo que confirmou no menu.
func start(dev: String) -> void:
	main.players.clear()
	PlayerInput.slots.clear()
	main.mode = "demolicao"
	main.sandbox = true
	main.add_player(dev)
	main.arena_choice = "oficina"
	main.submode_choice = "ultimo"
	main.event_level = 1
	main.events.manual = true
	main.demo.items_on = false
	main.demo.cfg["rounds_to_win"] = 999
	arena_i = 0
	open = false
	god = false
	slow = false
	main.start_match()
	main.demo.banner = "OFICINA DE TESTES"
	main.demo.banner_t = 2.0

func stop() -> void:
	open = false
	god = false
	slow = false
	Engine.time_scale = 1.0
	main.debug = false
	main.events.manual = false

func toggle() -> void:
	open = not open
	main.paused = open
	Audio.play("menu_ok" if open else "menu_voltar")

func update() -> void:
	var m = main.menus
	sel = posmod(sel + m.move_v(), ROWS.size())
	var h: int = m.move_h()
	var ok: bool = m.confirm()
	if m.pressed("back") or _pressed_start():
		toggle()
		return
	match ROWS[sel]:
		"dar":
			item_i = posmod(item_i + h, kinds().size())
			if ok and main.robots.size() > 0:
				main.demo.give(main.robots[0], kinds()[item_i])
				toggle()
		"soltar":
			drop_i = posmod(drop_i + h, kinds().size())
			if ok:
				var r = main.robots[0] if main.robots.size() > 0 else null
				var col: int = int(r.position.x / 64.0) + (2 * r.facing) if r != null else 14
				main.demo.spawn_item(kinds()[drop_i], clampi(col, 1, main.level.cols - 2))
				toggle()
		"evento":
			event_i = posmod(event_i + h, events().size())
			if ok:
				main.events.trigger(events()[event_i])
				toggle()
		"arena":
			arena_i = posmod(arena_i + h, arenas().size())
			if ok:
				main.arena_choice = arenas()[arena_i]["id"]
				main._demo_next_round()
				main.demo.items_on = false
				toggle()
		"recarregar":
			if ok:
				main._demo_next_round()   # caixotes, TNT e máquinas voltam ao início
				main.demo.items_on = false
				toggle()
		"boneco":
			if h > 0 or ok:
				main.sandbox_add("boneco")
			elif h < 0:
				main.sandbox_remove("boneco")
		"bot":
			if h > 0 or ok:
				main.sandbox_add("bot")
			elif h < 0:
				main.sandbox_remove("bot")
		"invencivel":
			if h != 0 or ok:
				god = not god
		"zerar":
			if ok:
				for r in main.robots:
					r.dmg = 0.0
				Audio.play("item")
		"lento":
			if h != 0 or ok:
				slow = not slow
				Engine.time_scale = 0.3 if slow else 1.0
		"hitbox":
			if h != 0 or ok:
				main.debug = not main.debug
		"voltar":
			if ok:
				toggle()
		"sair":
			if ok:
				main.go_menu()

func _pressed_start() -> bool:
	for i in main.players.size():
		if not main.players[i].get("bot", false) and PlayerInput.pressed(i, "start"):
			return true
	return false

## Durante o jogo na Oficina: invencibilidade dos jogadores humanos.
func tick() -> void:
	for i in main.robots.size():
		var r = main.robots[i]
		r.god = god and i < main.players.size() and not main.players[i].get("bot", false) and not main.players[i].get("boneco", false)

func _label(row: String) -> String:
	match row:
		"dar": return "DAR ITEM:  ◄ %s ►" % _item_name(kinds()[item_i])
		"soltar": return "SOLTAR DO CÉU:  ◄ %s ►" % _item_name(kinds()[drop_i])
		"evento": return "EVENTO AGORA:  ◄ %s ►" % String(events()[event_i]["nome"]).to_upper()
		"arena": return "ARENA:  ◄ %s ►" % String(arenas()[arena_i]["nome"]).to_upper()
		"recarregar": return "RECARREGAR ARENA (repõe caixotes e TNT)"
		"boneco": return "BONECO DE TREINO:  ◄ − / + ►  (%d)" % _count("boneco")
		"bot": return "BOT:  ◄ − / + ►  (%d)" % _count("bot")
		"invencivel": return "INVENCÍVEL:  %s" % ("SIM" if god else "NÃO")
		"zerar": return "ZERAR DANO DE TODOS"
		"lento": return "CÂMERA LENTA:  %s" % ("SIM" if slow else "NÃO")
		"hitbox": return "HITBOX E INFO:  %s" % ("SIM" if main.debug else "NÃO")
		"voltar": return "VOLTAR AO JOGO"
		"sair": return "SAIR DA OFICINA"
	return row

func _item_name(k: String) -> String:
	return String(main.demo.ITEM_NAMES.get(k, k)).trim_suffix("!")

func _count(kind: String) -> int:
	var n := 0
	for p in main.players:
		if p.get(kind, false):
			n += 1
	return n

func draw(ci: CanvasItem) -> void:
	if not open:
		Kit.sticker(ci, Vector2(24, 1050), "OFICINA  ·  START / TAB: painel", 26, Color("#1f3a40"), HORIZONTAL_ALIGNMENT_LEFT)
		if god:
			Kit.sticker(ci, Vector2(24, 1010), "INVENCÍVEL", 24, Color("#3c9a46"), HORIZONTAL_ALIGNMENT_LEFT)
		return
	ci.draw_rect(Rect2(0, 0, 1920, 1080), Color(0.1, 0.25, 0.3, 0.35))
	var r := Rect2(40, 110, 860, 950)
	Kit.paper(ci, r)
	Kit.ribbon(ci, Rect2(150, 40, 640, 110), "OFICINA", 54)
	for i in ROWS.size():
		var y := r.position.y + 92 + i * 65
		var on := i == sel
		if on:
			ci.draw_rect(Rect2(r.position.x + 30, y - 44, r.size.x - 60, 60), Color(0.95, 0.78, 0.29, 0.55))
		Kit.text(ci, Vector2(r.position.x + 60, y), _label(ROWS[i]), 30, Color("#1f3a40") if on else Color("#3e5a62"))
		if ROWS[i] in ["dar", "soltar"]:
			var k: String = kinds()[item_i if ROWS[i] == "dar" else drop_i]
			ci.draw_texture_rect(Data.tex("itens/" + k), Rect2(r.end.x - 110, y - 46, 56, 56), false)
	Kit.text(ci, Vector2(0, 1066), "▲▼ escolher  ·  ◄► mudar  ·  PULAR confirmar  ·  START / TAB / ESC fecha", 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 1920, 7)
