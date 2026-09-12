extends RefCounted
class_name SaveResourceRegistry

## Registro de recursos serializables por una clave estable independiente
## de `resource_path`.
##
## Necesario porque `Resource.duplicate()` en Godot 4 borra el
## `resource_path` de la copia. Las cartas en las pilas (`stats.draw_pile`
## etc.) y los buildings construidos en tiles son siempre duplicados, por
## lo que su path queda vacío y no se pueden serializar usando el path
## directo.
##
## La clave es `resource_path` si el recurso lo conserva; si no, el campo
## identificador de su tipo: `id` para Card, `name` para Building y Troop.
## El índice de cada tipo se construye lazy escaneando su directorio.

const CARDS_DIR := "res://resources/cards/"
const BUILDINGS_DIR := "res://resources/buildings/"
const TROOPS_DIR := "res://resources/troops/"

## Directorio → { clave → path }, uno por tipo para que un id de carta y un
## nombre de edificio no puedan pisarse.
static var _path_by_key:Dictionary = {}


static func _index(dir:String, field:String) -> Dictionary:
	if not _path_by_key.has(dir):
		var index := {}
		_walk(dir, func(path:String):
			var res = load(path)
			var key = res.get(field) if res != null else null
			if key is String and key != "":
				index[key] = path
		)
		_path_by_key[dir] = index
	return _path_by_key[dir]


## Clave serializable de un recurso: su path si lo tiene, si no su identificador.
static func _key(res:Resource, field:String) -> String:
	if res == null:
		return ""
	if res.resource_path != "":
		return res.resource_path
	return str(res.get(field))


## Carga un recurso desde su clave (path o identificador).
static func _load(key:String, dir:String, field:String) -> Resource:
	if key == "":
		return null
	if ResourceLoader.exists(key):
		return load(key)
	var path:String = _index(dir, field).get(key, "")
	return load(path) if path != "" else null


static func card_key(card:Card) -> String:
	return _key(card, "id")


static func load_card(key:String) -> Card:
	return _load(key, CARDS_DIR, "id") as Card


static func building_key(b:Building) -> String:
	return _key(b, "name")


static func load_building(key:String) -> Building:
	return _load(key, BUILDINGS_DIR, "name") as Building


static func troop_key(t:Troop) -> String:
	return _key(t, "name")


static func load_troop(key:String) -> Troop:
	return _load(key, TROOPS_DIR, "name") as Troop


## Recorre recursivamente un directorio aplicando `callback(absolute_path)`
## a cada `.tres` encontrado.
static func _walk(dir_path:String, callback:Callable) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if dir.current_is_dir():
			if f != "." and f != "..":
				_walk(dir_path + f + "/", callback)
		elif f.ends_with(".tres"):
			callback.call(dir_path + f)
		f = dir.get_next()
	dir.list_dir_end()
