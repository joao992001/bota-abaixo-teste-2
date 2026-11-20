extends Node
## Entrada por jogador. O jogo pergunta sempre held/pressed(jogador, ação); nunca lê o dispositivo direto.
## Teclado A: WASD + Espaço (pular) + F/E (marreta). Teclado B: setas + Ctrl direito/Num0/L (pular) + . / Enter num./K (marreta).
## Sem Shift: no Windows, com NumLock ligado, as setas mandam um Shift "fantasma" (era a marreta sozinha).
## Teclas lidas por evento (_input), para separar Ctrl esquerdo/direito; "ctrl_r" = só o Ctrl direito.
## Controle (Xbox, PlayStation, Nintendo, genéricos — mapeamento SDL da Godot, por posição do botão):
##   analógico/direcional anda · botão de baixo (A / ✕) pula · esquerda (X / □), RB ou RT marreta ·
##   cima (Y / △), direita (B / ○), LB ou LT item · Start pausa/começa · B / ○ ou Select volta nos menus.
## Conectar/desconectar a qualquer hora: aviso na tela; se cair no meio da partida, o jogo pausa.

const ACTIONS := ["left", "right", "up", "down", "jump", "hammer", "item", "start", "back"]
const KEYMAP := {
	"kb_a": {"left": [KEY_A], "right": [KEY_D], "up": [KEY_W], "down": [KEY_S],
		"jump": [KEY_SPACE], "hammer": [KEY_F, KEY_E], "item": [KEY_G, KEY_Q], "start": [KEY_ENTER], "back": [KEY_BACKSPACE, KEY_ESCAPE]},
	"kb_b": {"left": [KEY_LEFT], "right": [KEY_RIGHT], "up": [KEY_UP], "down": [KEY_DOWN],
		"jump": ["ctrl_r", KEY_KP_0, KEY_L], "hammer": [KEY_PERIOD, KEY_SLASH, KEY_KP_ENTER, KEY_K], "item": [KEY_COMMA, KEY_J, KEY_KP_1], "start": [KEY_ENTER], "back": [KEY_DELETE]},
}

var slots: Array = []   # dispositivo de cada jogador (índice = jogador)
var virtual := {}       # dispositivos simulados (testes): nome -> {ação: bool}
var _cur := {}
var _prev := {}
var jump_frame := {}    # dispositivo -> quadro de física em que PULAR foi apertado
var aliases := {}       # dispositivo "gêmeo" ignorado -> dispositivo real (mesmo controle visto 2x no Windows)
const TWIN_FRAMES := 2
var _jb := {}           # controle -> {botão: apertado}, pelos eventos (além da leitura direta)
var _ja := {}           # controle -> {eixo: valor}, pelos eventos
var last_raw := {}      # controle -> último botão/eixo cru recebido (tela TESTAR CONTROLES)
var toasts: Array = []  # avisos de controle conectado/desconectado: {text, t, ok}
var vibration := true   # OPÇÕES: vibração dos controles
signal pad_changed(dev: String, connected: bool)

func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy)

func _on_joy(j: int, connected: bool) -> void:
	var dev := "joy%d" % j
	_log_pad(j, connected)
	var nm := pad_name(dev) if connected else "controle %d" % (j + 1)
	toasts.append({"text": ("Conectado: %s" if connected else "Desconectado: %s") % nm, "t": 0.0, "ok": connected, "dev": dev})
	if not connected:
		_cur.erase(dev)
		_prev.erase(dev)
		aliases.erase(dev)
		_jb.erase(j)
		_ja.erase(j)
	pad_changed.emit(dev, connected)

func _process(dt: float) -> void:
	for tt in toasts:
		tt["t"] += dt
	toasts = toasts.filter(func(tt): return tt["t"] < 4.0)

## Nome amigável do controle (o que a Godot/SDL informa, encurtado).
func pad_name(dev: String) -> String:
	if not dev.begins_with("joy"):
		return label(dev)
	var nm := Input.get_joy_name(int(dev.substr(3))).strip_edges()
	var fam: String = {"ps": "PlayStation", "nintendo": "Nintendo", "xbox": "Xbox"}.get(pad_type(dev), "")
	if nm == "":
		return fam if fam != "" else "controle %d" % (int(dev.substr(3)) + 1)
	if fam != "" and not (fam.to_lower() in nm.to_lower()):
		nm = "%s (%s)" % [fam, nm]   # ex.: "PlayStation (Wireless Controller)"
	return nm.substr(0, 34)

## Família do controle, pelo nome: muda só os desenhos dos botões (a posição é a mesma).
func pad_type(dev: String) -> String:
	if not dev.begins_with("joy"):
		return ""
	return type_from_name(Input.get_joy_name(int(dev.substr(3))))

static func type_from_name(nm: String) -> String:
	var n := nm.to_lower().strip_edges()
	for k in ["xbox", "xinput", "x-box", "microsoft"]:
		if k in n:
			return "xbox"
	if n == "wireless controller":
		return "ps"   # DualShock 4 no Windows aparece só assim
	for k in ["dualsense", "dualshock", "ps5", "ps4", "ps3", "playstation", "sony"]:
		if k in n:
			return "ps"
	for k in ["nintendo", "switch", "pro controller", "joy-con", "joycon"]:
		if k in n:
			return "nintendo"
	for k in ["xbox", "xinput", "x-box", "microsoft"]:
		if k in n:
			return "xbox"
	return "generico"

## Família que aparece nas dicas da tela: a do primeiro controle conectado (Xbox se não houver).
func main_pad_type() -> String:
	for j in Input.get_connected_joypads():
		return type_from_name(Input.get_joy_name(j))
	return "xbox"

## Vibra o controle do jogador (se for controle e a opção estiver ligada).
func vibrate(p: int, weak: float, strong: float, dur: float) -> void:
	if not vibration or p < 0 or p >= slots.size():
		return
	var dev: String = slots[p]
	if dev.begins_with("joy"):
		Input.start_joy_vibration(int(dev.substr(3)), clampf(weak, 0.0, 1.0), clampf(strong, 0.0, 1.0), dur)

func _physics_process(_dt: float) -> void:
	for dev in all_devices():
		_prev[dev] = _cur.get(dev, {})
		_cur[dev] = _read(dev)
		if dev_pressed(dev, "jump"):
			jump_frame[dev] = Engine.get_physics_frames()

func all_devices() -> Array:
	var list: Array = ["kb_a", "kb_b"]
	for j in Input.get_connected_joypads():
		list.append("joy%d" % j)
	list.append_array(virtual.keys())
	return list

func _read(dev: String) -> Dictionary:
	var s := {}
	if virtual.has(dev):
		for a in ACTIONS:
			s[a] = bool(virtual[dev].get(a, false))
	elif KEYMAP.has(dev):
		for a in ACTIONS:
			s[a] = false
			for k in KEYMAP[dev][a]:
				if key_down(k):
					s[a] = true
	elif dev.begins_with("joy"):
		var j := int(dev.substr(3))
		var x := jaxis(j, JOY_AXIS_LEFT_X)
		var y := jaxis(j, JOY_AXIS_LEFT_Y)
		s["left"] = x < -0.45 or jbtn(j, JOY_BUTTON_DPAD_LEFT)
		s["right"] = x > 0.45 or jbtn(j, JOY_BUTTON_DPAD_RIGHT)
		s["up"] = y < -0.45 or jbtn(j, JOY_BUTTON_DPAD_UP)
		s["down"] = y > 0.45 or jbtn(j, JOY_BUTTON_DPAD_DOWN)
		s["jump"] = jbtn(j, JOY_BUTTON_A)
		s["hammer"] = jbtn(j, JOY_BUTTON_X) or jbtn(j, JOY_BUTTON_RIGHT_SHOULDER) or jaxis(j, JOY_AXIS_TRIGGER_RIGHT) > 0.5
		s["item"] = jbtn(j, JOY_BUTTON_Y) or jbtn(j, JOY_BUTTON_B) or jbtn(j, JOY_BUTTON_LEFT_SHOULDER) or jaxis(j, JOY_AXIS_TRIGGER_LEFT) > 0.5
		s["start"] = jbtn(j, JOY_BUTTON_START)
		s["back"] = jbtn(j, JOY_BUTTON_BACK) or jbtn(j, JOY_BUTTON_B)
	return s

var _keys := {}   # "tecla:posição" -> apertada (posição separa Ctrl/Shift esquerdo e direito)

## Botão do controle: leitura direta OU o último evento recebido (qualquer um dos dois basta).
func jbtn(j: int, b: int) -> bool:
	return Input.is_joy_button_pressed(j, b) or bool(_jb.get(j, {}).get(b, false))

func jaxis(j: int, a: int) -> float:
	var p := Input.get_joy_axis(j, a)
	var ev: float = _ja.get(j, {}).get(a, 0.0)
	return p if absf(p) >= absf(ev) else ev

## Relatório para diagnóstico (user://controles.txt): nome, GUID, se a Godot reconhece o mapeamento.
func _log_pad(j: int, connected: bool) -> void:
	var f := FileAccess.open("user://controles.txt", FileAccess.READ_WRITE if FileAccess.file_exists("user://controles.txt") else FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line("%s  controle %d %s  nome=\"%s\"  guid=%s  reconhecido=%s  info=%s" % [Time.get_datetime_string_from_system(), j,
		"CONECTOU" if connected else "DESCONECTOU", Input.get_joy_name(j), Input.get_joy_guid(j), Input.is_joy_known(j), str(Input.get_joy_info(j))])
	f.close()

func _input(e: InputEvent) -> void:
	if e is InputEventJoypadButton:
		if not _jb.has(e.device):
			_jb[e.device] = {}
		_jb[e.device][e.button_index] = e.pressed
		if e.pressed:
			last_raw[e.device] = "botão %d" % e.button_index
	elif e is InputEventJoypadMotion:
		if not _ja.has(e.device):
			_ja[e.device] = {}
		_ja[e.device][e.axis] = e.axis_value if absf(e.axis_value) > 0.2 else 0.0
		if absf(e.axis_value) > 0.5:
			last_raw[e.device] = "eixo %d: %+.2f" % [e.axis, e.axis_value]
	if e is InputEventKey and not e.echo:
		var k: int = e.physical_keycode if e.physical_keycode != 0 else e.keycode
		_keys["%d:%d" % [k, e.location]] = e.pressed

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_keys.clear()   # janela perdeu o foco: nenhuma tecla fica "presa"

func key_down(k) -> bool:
	if k is String:
		match k:
			"ctrl_r": return _keys.get("%d:%d" % [KEY_CTRL, KEY_LOCATION_RIGHT], false)
		return false
	for loc in [KEY_LOCATION_UNSPECIFIED, KEY_LOCATION_LEFT, KEY_LOCATION_RIGHT]:
		if _keys.get("%d:%d" % [k, loc], false):
			return true
	return false

func is_keyboard(dev: String) -> bool:
	return KEYMAP.has(dev)

## Outro controle já em uso que apertou PULAR no mesmo instante (é o mesmo controle físico aparecendo 2x).
func twin_of(dev: String) -> String:
	if is_keyboard(dev) or not jump_frame.has(dev):
		return ""
	for other in slots:
		if other != dev and not is_keyboard(other) and jump_frame.has(other):
			if absi(int(jump_frame[other]) - int(jump_frame[dev])) <= TWIN_FRAMES:
				return other
	return ""

func label(dev: String) -> String:
	match dev:
		"kb_a": return "teclado A"
		"kb_b": return "teclado B"
	if dev.begins_with("bot"):
		return "BOT"
	if dev.begins_with("boneco"):
		return "BONECO DE TREINO"
	if dev.begins_with("joy"):
		var nm := Input.get_joy_name(int(dev.substr(3)))
		return "controle %d: %s" % [int(dev.substr(3)) + 1, nm.substr(0, 22)]
	if dev.begins_with("v"):
		return "controle virtual"
	return dev

func dev_held(dev: String, a: String) -> bool:
	return _cur.get(dev, {}).get(a, false)

func dev_pressed(dev: String, a: String) -> bool:
	return dev_held(dev, a) and not _prev.get(dev, {}).get(a, false)

func held(p: int, a: String) -> bool:
	if p >= slots.size():
		return false
	if dev_held(slots[p], a):
		return true
	for tw in aliases:
		if aliases[tw] == slots[p] and dev_held(tw, a):
			return true
	return false

func pressed(p: int, a: String) -> bool:
	if p >= slots.size():
		return false
	if dev_pressed(slots[p], a):
		return true
	for tw in aliases:
		if aliases[tw] == slots[p] and dev_pressed(tw, a):
			return true
	return false

## Controle que a Godot reconhece (mapeamento conhecido) — preferido quando o Windows mostra o mesmo controle 2x.
func is_known(dev: String) -> bool:
	return dev.begins_with("joy") and Input.is_joy_known(int(dev.substr(3)))

func axis_x(p: int) -> float:
	return float(held(p, "right")) - float(held(p, "left"))
