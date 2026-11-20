extends Node
## Entrada por jogador. O jogo pergunta sempre held/pressed(jogador, ação); nunca lê o dispositivo direto.
## Teclado A: WASD + Espaço (pular) + Shift/F (marreta). Teclado B: setas + Ctrl/L/Num0 (pular) + Enter num./K (marreta).
## Controle: analógico/direcional + A (pular) + X/B/RB (marreta) + Start. Enter/Start começa a partida.

const ACTIONS := ["left", "right", "up", "down", "jump", "hammer", "start"]
const KEYMAP := {
	"kb_a": {"left": [KEY_A], "right": [KEY_D], "up": [KEY_W], "down": [KEY_S],
		"jump": [KEY_SPACE], "hammer": [KEY_SHIFT, KEY_F], "start": [KEY_ENTER]},
	"kb_b": {"left": [KEY_LEFT], "right": [KEY_RIGHT], "up": [KEY_UP], "down": [KEY_DOWN],
		"jump": [KEY_CTRL, KEY_KP_0, KEY_L], "hammer": [KEY_KP_ENTER, KEY_K], "start": [KEY_ENTER]},
}

var slots: Array = []   # dispositivo de cada jogador (índice = jogador)
var virtual := {}       # dispositivos simulados (testes): nome -> {ação: bool}
var _cur := {}
var _prev := {}

func _physics_process(_dt: float) -> void:
	for dev in all_devices():
		_prev[dev] = _cur.get(dev, {})
		_cur[dev] = _read(dev)

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
				if Input.is_physical_key_pressed(k):
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
	return s

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
