extends Node
## Dados do jogo lidos de ../data/*.json e ../levels/*.lvl (nunca números fixos no código).

const COLORS := [Color("#2f8ff0"), Color("#5fd35f"), Color("#ff6fb5"), Color("#ffd23f")]
const COLOR_NAMES := ["Azul", "Verde", "Rosa", "Amarelo"]
const DANGER := Color("#d42035")
const INK := Color("#2a1a2e")
const TILE := 64
const ARENA_Y := 56

var ctrl: Dictionary
var scoring: Dictionary
var pieces := {}
var root_dir := ""

func _ready() -> void:
	root_dir = ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	ctrl = read_json("data/controller.json")
	scoring = read_json("data/scoring.json")
	for p in read_json("data/pieces.json")["pecas"]:
		pieces[p["id"]] = p

func read_text(rel: String) -> String:
	for base in ["res://", root_dir + "/"]:
		if FileAccess.file_exists(base + rel):
			return FileAccess.get_file_as_string(base + rel)
	push_error("Arquivo não encontrado: " + rel)
	return ""

func read_json(rel: String):
	return JSON.parse_string(read_text(rel))

func piece_ids(milestone: int, implemented: Array) -> Array:
	var out := []
	for id in pieces:
		if int(pieces[id]["marco"]) <= milestone and id in implemented:
			out.append(id)
	out.sort()
	return out
