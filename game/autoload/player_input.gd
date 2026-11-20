extends Node
## Entrada por jogador. O jogo pergunta sempre held/pressed(jogador, ação); nunca lê o dispositivo direto.
## Teclado A: WASD + Espaço (pular) + F/E (marreta). Teclado B: setas + Ctrl direito/Num0/L (pular) + . / Enter num./K (marreta).
## Sem Shift: no Windows, com NumLock ligado, as setas mandam um Shift "fantasma" (era a marreta sozinha).
## Teclas lidas por evento (_input), para separar Ctrl esquerdo/direito; "ctrl_r" = só o Ctrl direito.
## Controle: analógico/direcional + A (pular) + X/B/RB (marreta) + Start. Enter/Start começa a partida.

const ACTIONS := ["left", "right", "up", "down", "jump", "hammer", "start", "back"]
const KEYMAP := {
	"kb_a": {"left": [KEY_A], "right": [KEY_D], "up": [KEY_W], "down": [KEY_S],
		"jump": [KEY_SPACE], "hammer": [KEY_F, KEY_E], "start": [KEY_ENTER], "back": [KEY_BACKSPACE]},
	"kb_b": {"left": [KEY_LEFT], "right": [KEY_RIGHT], "up": [KEY_UP], "down": [KEY_DOWN],
		"jump": ["ctrl_r", KEY_KP_0, KEY_L], "hammer": [KEY_PERIOD, KEY_SLASH, KEY_KP_ENTER, KEY_K], "start": [KEY_ENTER], "back": [KEY_DELETE]},
}

var slots: Array = []   # dispositivo de cada jogador (índice = jogador)
var virtual := {}       # dispositivos simulados (testes): nome -> {ação: bool}
var _cur := {}
var _prev := {}
var jump_frame := {}    # dispositivo -> quadro de física em que PULAR foi apertado
var aliases := {}       # dispositivo "gêmeo" ignorado -> dispositivo real (mesmo controle visto 2x no Windows)
const TWIN_FRAMES := 2

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
		var x := Input.get_joy_axis(j, JOY_AXIS_LEFT_X)
		var y := Input.get_joy_axis(j, JOY_AXIS_LEFT_Y)
		s["left"] = x < -0.45 or Input.is_joy_button_pressed(j, JOY_BUTTON_DPAD_LEFT)
		s["right"] = x > 0.45 or Input.is_joy_button_pressed(j, JOY_BUTTON_DPAD_RIGHT)
		s["up"] = y < -0.45 or Input.is_joy_button_pressed(j, JOY_BUTTON_DPAD_UP)
		s["down"] = y > 0.45 or Input.is_joy_button_pressed(j, JOY_BUTTON_DPAD_DOWN)
		s["jump"] = Input.is_joy_button_pressed(j, JOY_BUTTON_A)
		s["hammer"] = Input.is_joy_button_pressed(j, JOY_BUTTON_X) or Input.is_joy_button_pressed(j, JOY_BUTTON_B) \
			or Input.is_joy_button_pressed(j, JOY_BUTTON_RIGHT_SHOULDER)
		s["start"] = Input.is_joy_button_pressed(j, JOY_BUTTON_START)
		s["back"] = Input.is_joy_button_pressed(j, JOY_BUTTON_BACK)
	return s

var _keys := {}   # "tecla:posição" -> apertada (posição separa Ctrl/Shift esquerdo e direito)

func _input(e: InputEvent) -> void:
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
	if dev.begins_with("joy"):
		var nm := Input.get_joy_name(int(dev.substr(3)))
		return "controle %d: %s" % [int(dev.substr(3)) + 1, nm.substr(0, 22)]
	return dev

func dev_held(dev: String, a: String) -> bool:
	return _cur.get(dev, {}).get(a, false)

func dev_pressed(dev: String, a: String) -> bool:
	return dev_held(dev, a) and not _prev.get(dev, {}).get(a, false)

func held(p: int, a: String) -> bool:
	return p < slots.size() and dev_held(slots[p], a)

func pressed(p: int, a: String) -> bool:
	return p < slots.size() and dev_pressed(slots[p], a)

func axis_x(p: int) -> float:
	return float(held(p, "right")) - float(held(p, "left"))
