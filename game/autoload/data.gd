extends Node
## Dados do jogo lidos de ../data/*.json e ../levels/*.lvl (nunca números fixos no código).

const COLORS := [Color("#4f86d9"), Color("#5cc45c"), Color("#f06aa8"), Color("#f2c84b")]
const TEXT_COLORS := [Color("#3a6cc0"), Color("#3c9a46"), Color("#e0508f"), Color("#d9a521")]  # placar sobre fundo claro
const MODELS := ["lata", "tv", "baixinho", "pescocao"]
const MODEL_NAMES := ["Lata", "TV", "Baixinho", "Pescoção"]
const COLOR_NAMES := ["Azul", "Verde", "Rosa", "Amarelo"]
const DANGER := Color("#d42035")
const INK := Color("#2a1a2e")
const TILE := 64
const ARENA_Y := 56
const ACCS := ["", "capacete", "bone", "gorro"]
const ACC_NAMES := ["sem chapéu", "capacete", "boné", "gorro"]

var ctrl: Dictionary
var scoring: Dictionary
var pieces := {}
var root_dir := ""
var robot_meta := {}   # art/out/game/robo/modelos.json: quadris, ombros, mãos, chapéu por modelo

func _ready() -> void:
	root_dir = ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	ctrl = read_json("data/controller.json")
	scoring = read_json("data/scoring.json")
	if FileAccess.file_exists("res://assets/robo/modelos.json"):
		robot_meta = JSON.parse_string(FileAccess.get_file_as_string("res://assets/robo/modelos.json"))
	for p in read_json("data/pieces.json")["pecas"]:
		pieces[p["id"]] = p
	var t0 := Time.get_ticks_msec()
	var n := preload_all()
	print("Bota-Abaixo: %d imagens carregadas em %d ms" % [n, Time.get_ticks_msec() - t0])

func read_text(rel: String) -> String:
	for base in ["res://", root_dir + "/"]:
		if FileAccess.file_exists(base + rel):
			return FileAccess.get_file_as_string(base + rel)
	push_error("Arquivo não encontrado: " + rel)
	return ""

func read_json(rel: String):
	return JSON.parse_string(read_text(rel))

var _tex := {}

## Textura de art/out/game copiada para res://assets (PNGs em 2x). null se não existir.
func tex(path: String) -> Texture2D:
	if not _tex.has(path):
		var full := "res://assets/%s.png" % path
		_tex[path] = load(full) if ResourceLoader.exists(full) else null
	return _tex[path]

## Carrega todas as imagens de assets/ de uma vez (ao abrir o jogo): sem trancos no meio da partida
## quando aparece uma arena, item ou máquina pela primeira vez. Funciona também no jogo exportado (.import).
func preload_all(dir := "res://assets") -> int:
	var n := 0
	var d := DirAccess.open(dir)
	if d == null:
		return 0
	for sub in d.get_directories():
		n += preload_all(dir.path_join(sub))
	var seen := {}
	for f in d.get_files():
		var name := f.trim_suffix(".import").trim_suffix(".remap")
		if not name.ends_with(".png") or seen.has(name):
			continue
		seen[name] = true
		var rel := dir.path_join(name).trim_prefix("res://assets/").trim_suffix(".png")
		if tex(rel) != null:
			n += 1
	return n

func piece_ids(milestone: int, implemented: Array) -> Array:
	var out := []
	for id in pieces:
		if int(pieces[id]["marco"]) <= milestone and id in implemented:
			out.append(id)
	out.sort()
	return out
