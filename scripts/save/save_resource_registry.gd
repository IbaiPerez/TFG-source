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
## Convenciones por tipo:
## - Card: clave = `card.id` (ya es exportado y único por carta).
## - Building: clave = `building.name`.
## - Troop: clave = `troop.name`.
##
## Los registros se construyen lazy escaneando los directorios
## res://resources/cards/, res://resources/buildings/ y
## res://resources/troops/ recursivamente.

const CARDS_DIR := "res://resources/cards/"
const BUILDINGS_DIR := "res://resources/buildings/"
const TROOPS_DIR := "res://resources/troops/"

static var _card_path_by_id:Dictionary = {}
static var _building_path_by_name:Dictionary = {}
static var _troop_path_by_name:Dictionary = {}
static var _initialized:bool = false


static func _ensure_init() -> void:
	if _initialized:
		return
	_initialized = true
	_scan_cards(CARDS_DIR)
	_scan_buildings(BUILDINGS_DIR)
	_scan_troops(TROOPS_DIR)


## Limpia el registro y fuerza un re-scan en el siguiente acceso.
## Útil para tests que añaden/borran .tres en runtime (raro).
static func reset() -> void:
	_card_path_by_id.clear()
	_building_path_by_name.clear()
	_troop_path_by_name.clear()
	_initialized = false


# --- Cards --------------------------------------------------------------

## Devuelve un identificador serializable para una card. Si la card tiene
## resource_path lo prefiere; si no, devuelve su `id` (que el registro
## puede resolver de vuelta a un .tres).
static func card_key(card:Card) -> String:
	if card == null:
		return ""
	if card.resource_path != "":
		return card.resource_path
	return card.id


## Carga una card desde su clave (path o id).
static func load_card(key:String) -> Card:
	if key == "":
		return null
	if ResourceLoader.exists(key):
		return load(key) as Card
	_ensure_init()
	var path:String = _card_path_by_id.get(key, "")
	if path == "":
		return null
	return load(path) as Card


# --- Buildings ----------------------------------------------------------

static func building_key(b:Building) -> String:
	if b == null:
		return ""
	if b.resource_path != "":
		return b.resource_path
	return b.name


static func load_building(key:String) -> Building:
	if key == "":
		return null
	if ResourceLoader.exists(key):
		return load(key) as Building
	_ensure_init()
	var path:String = _building_path_by_name.get(key, "")
	if path == "":
		return null
	return load(path) as Building


# --- Troops -------------------------------------------------------------

static func troop_key(t:Troop) -> String:
	if t == null:
		return ""
	if t.resource_path != "":
		return t.resource_path
	return t.name


static func load_troop(key:String) -> Troop:
	if key == "":
		return null
	if ResourceLoader.exists(key):
		return load(key) as Troop
	_ensure_init()
	var path:String = _troop_path_by_name.get(key, "")
	if path == "":
		return null
	return load(path) as Troop


# --- Scan helpers -------------------------------------------------------

static func _scan_cards(dir_path:String) -> void:
	_walk(dir_path, func(path:String):
		var res = load(path)
		if res is Card and (res as Card).id != "":
			_card_path_by_id[(res as Card).id] = path
	)


static func _scan_buildings(dir_path:String) -> void:
	_walk(dir_path, func(path:String):
		var res = load(path)
		if res is Building and (res as Building).name != "":
			_building_path_by_name[(res as Building).name] = path
	)


static func _scan_troops(dir_path:String) -> void:
	_walk(dir_path, func(path:String):
		var res = load(path)
		if res is Troop and (res as Troop).name != "":
			_troop_path_by_name[(res as Troop).name] = path
	)


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
