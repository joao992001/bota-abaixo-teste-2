class_name MapaReg
extends RefCounted
## RESOLUÇÃO modo → mapa → cena (fonte única do conteúdo autorizado de cada mapa).
## - Modo (data/modos.json → demolicao.modos[<modo>]): regras, CLASSES de spell, destruição.
## - Mapa (data/mapas/<modo>/<mapa>.json): spells autorizadas, eventos, cenas ordenadas; por cena: eventos, instâncias de
##   mecanismos/perigos, estruturas (fixas × destrutíveis) e próxima cena. Geometria das cenas fica no .lvl (etapaN…).
## - Mapa-ferramenta (data/mapas/ferramentas.json: laboratório e arenas de teste): TODAS as spells/eventos do modo, explícito.
## - Mapa sem manifesto e que não é ferramenta: NENHUMA spell e NENHUM evento (sem herança silenciosa entre modos).
## Manual: docs/manuais/derruba/README.md · biblioteca humana: docs/fases/<modo>/<mapa>/README.md

static var _cache := {}
static var _avisos := {}

static func modo_cfg(mode_id: String) -> Dictionary:
	for m in Data.read_json("data/modos.json")["demolicao"]["modos"]:
		if m["id"] == mode_id:
			return m
	return {}

static func ferramentas() -> Dictionary:
	if not _cache.has("_ferr"):
		_cache["_ferr"] = Data.read_json("data/mapas/ferramentas.json").get("mapas", {})
	return _cache["_ferr"]

static func eh_ferramenta(map_id: String) -> bool:
	return ferramentas().has(map_id)

## Manifesto do mapa (vazio se não houver). Lido uma vez.
static func manifesto(mode_id: String, map_id: String) -> Dictionary:
	var k := mode_id + "/" + map_id
	if not _cache.has(k):
		var rel := "data/mapas/%s/%s.json" % [mode_id, map_id]
		var m = null
		for base in ["res://", Data.root_dir + "/"]:
			if FileAccess.file_exists(base + rel):
				m = JSON.parse_string(FileAccess.get_file_as_string(base + rel))
				break
		_cache[k] = m if m is Dictionary else {}
		if not _cache[k].is_empty():
			for e in validar(_cache[k]):
				push_warning("Mapa %s: %s" % [k, e])
	return _cache[k]

static func _avisa(chave: String, msg: String) -> void:
	if not _avisos.has(chave):
		_avisos[chave] = true
		push_warning(msg)

## Spells autorizadas no mapa (pool do sorteio).
static func spells(mode_id: String, map_id: String, pool_modo: Array) -> Array:
	var m := manifesto(mode_id, map_id)
	if not m.is_empty():
		return m.get("spells_permitidas", [])
	if eh_ferramenta(map_id):
		return pool_modo
	_avisa("sp" + mode_id + map_id, "Mapa '%s' (modo %s) sem manifesto: nenhuma spell autorizada." % [map_id, mode_id])
	return []

## Eventos autorizados na cena n (1, 2, …). null = mapa-ferramenta (toda a biblioteca, exceto específicos V#).
static func eventos(mode_id: String, map_id: String, n: int):
	var c := cena(mode_id, map_id, n)
	if not c.is_empty():
		return c.get("eventos", [])
	if eh_ferramenta(map_id):
		return null
	return []

static func cenas(mode_id: String, map_id: String) -> Array:
	return manifesto(mode_id, map_id).get("cenas", [])

## Cena pela ordem (1 = primeira). {} se não existir.
static func cena(mode_id: String, map_id: String, n: int) -> Dictionary:
	for c in cenas(mode_id, map_id):
		if int(c["ordem"]) == n:
			return c
	return {}

static func tem_proxima(mode_id: String, map_id: String, n: int) -> bool:
	var c := cena(mode_id, map_id, n)
	return not c.is_empty() and c.get("proxima") != null and not cena(mode_id, map_id, n + 1).is_empty()

## Instâncias de mecanismos/perigos de todas as cenas, cada uma com "etapa" = ordem da cena.
static func mecanismos(mode_id: String, map_id: String) -> Array:
	var out := []
	for c in cenas(mode_id, map_id):
		for d in c.get("mecanismos", []):
			var d2: Dictionary = d.duplicate(true)
			d2["etapa"] = int(c["ordem"])
			out.append(d2)
	return out

## Erros de integridade do manifesto (vazio = ok).
static func validar(m: Dictionary) -> Array:
	var err := []
	var mode_id := String(m.get("mode_id", ""))
	var mc := modo_cfg(mode_id)
	if mc.is_empty():
		err.append("modo inexistente: " + mode_id)
		return err
	var sp: Dictionary = Data.read_json("data/modos.json")["demolicao"]["spells"]
	var classes: Dictionary = mc.get("classes_spells", {})
	var lista: Array = m.get("spells_permitidas", [])
	if lista.is_empty():
		err.append("spells_permitidas vazia")
	for id in lista:
		if not sp.has(id):
			err.append("spell inexistente: " + str(id))
		elif not classes.has(String(sp[id]["familia"])):
			err.append("spell %s com classe '%s' fora das classes do modo" % [id, sp[id]["familia"]])
	var lib := {}
	for e in Data.read_json("data/modos.json")["demolicao"]["eventos"]["lista"]:
		lib[e["id"] if e is Dictionary else e] = true
	var ids := {}
	var ordens := {}
	var cs: Array = m.get("cenas", [])
	if cs.size() < 2 and mode_id == "derruba":
		err.append("mapa do Derruba precisa de pelo menos 2 cenas")
	for c in cs:
		if ids.has(c["id"]):
			err.append("cena repetida: " + str(c["id"]))
		ids[c["id"]] = int(c["ordem"])
		ordens[int(c["ordem"])] = true
		for e in c.get("eventos", []):
			if not e in m.get("eventos_permitidos", []):
				err.append("cena %s: evento %s fora de eventos_permitidos do mapa" % [c["id"], e])
			if not lib.has(e):
				err.append("cena %s: evento inexistente na biblioteca: %s" % [c["id"], e])
		for d in c.get("mecanismos", []):
			if not (d.has("pos") or d.has("x") or d.has("base")):
				err.append("cena %s: mecanismo %s sem posição" % [c["id"], d.get("id", "?")])
	for c in cs:
		var nx = c.get("proxima")
		if nx != null:
			if not ids.has(nx):
				err.append("cena %s: próxima inexistente %s" % [c["id"], nx])
			elif ids[nx] != int(c["ordem"]) + 1:
				err.append("cena %s: próxima %s fora de ordem (ciclo ou salto)" % [c["id"], nx])
	for k in ordens.size():
		if not ordens.has(k + 1):
			err.append("ordens das cenas não são 1..N")
			break
	return err
