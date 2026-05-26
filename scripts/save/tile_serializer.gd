extends RefCounted
class_name TileSerializer

## Serializa y reconstruye Tiles para el sistema de save.
##
## Estrategia:
## - Guardamos por tile **todo el estado** (mesh_data, natural_resource, pos,
##   biome flags). NO confiamos en regenerar desde la seed porque la
##   selección de natural_resource y la colocación inicial de empires
##   usan el RNG global y no son deterministas.
## - Las referencias a recursos (.tres) se serializan como `resource_path`.
## - Los buildings se vuelcan al cargar via `apply_buildings_pending()`,
##   que se llama después de tener los empires y stats reconstruidos.

const TILE_SCRIPT := preload("uid://dasqw0u0jgxcf")
const HEX_TILE_COLLIDER := preload("uid://4061dgx0wwr5")


## --- Serialización ------------------------------------------------------

static func to_dict(tile:Tile) -> Dictionary:
	var d := {
		"pos": [int(tile.pos_data.grid_position.x), int(tile.pos_data.grid_position.y)],
		"world_position": [tile.position.x, tile.position.y, tile.position.z],
		"mesh_data": _path_of(tile.mesh_data),
		"natural_resource": _path_of(tile.natural_resource),
		"biome": tile.biome,
		"location": _path_of(tile.location),
		"controller": tile.controller.name if tile.controller else "",
		"buffer": tile.pos_data.buffer if tile.pos_data else false,
		"water": tile.pos_data.water if tile.pos_data else false,
		"mountain": tile.pos_data.mountain if tile.pos_data else false,
		"buildings": _serialize_buildings(tile.buildings),
		"province_name": tile.province_name,
	}
	return d


static func _serialize_buildings(buildings:Array[Building]) -> Array:
	var out:Array = []
	for b in buildings:
		# `tile.build()` hace `building.duplicate(true)`, lo que borra el
		# resource_path. Usamos el registry para resolver por nombre.
		out.append(SaveResourceRegistry.building_key(b))
	return out


## --- Reconstrucción -----------------------------------------------------

## Crea instancias de Tile a partir de los dicts serializados y las añade
## como hijos de `tile_parent`. Devuelve un Array[Tile] tipado.
##
## Replica lo esencial de `TileFactory.init_tile()` pero leyendo de los
## datos serializados en vez de calcularlos con noise+RNG.
static func rebuild_tiles(tiles_data:Array, tile_parent:Node3D,
		_settings:GenerationSettings) -> Array[Tile]:
	var result:Array[Tile] = []
	for entry in tiles_data:
		var tile := _build_one(entry, tile_parent)
		if tile != null:
			result.append(tile)
	return result


static func _build_one(entry:Dictionary, tile_parent:Node3D) -> Tile:
	var mesh_data:TileMeshData = _load_or_null(entry.get("mesh_data", "")) as TileMeshData
	if mesh_data == null:
		push_warning("[TileSerializer] mesh_data inválido en entrada %s" % entry)
		return null

	var node:Node = mesh_data.mesh.instantiate()
	node.set_script(TILE_SCRIPT)
	var tile := node as Tile
	if tile == null:
		return null

	tile.mesh_data = mesh_data

	# Collider (igual que TileFactory.init_tile).
	var col:Node = HEX_TILE_COLLIDER.instantiate()
	tile.add_child(col)
	col.position = Vector3.ZERO

	if not tile.is_in_group("tiles"):
		tile.add_to_group("tiles")

	# pos_data
	var pos_data := PositionData.new()
	pos_data.grid_position = Vector2(entry["pos"][0], entry["pos"][1])
	var wp:Array = entry.get("world_position", [0.0, 0.0, 0.0])
	pos_data.world_position = Vector3(wp[0], wp[1], wp[2])
	pos_data.buffer = bool(entry.get("buffer", false))
	pos_data.water = bool(entry.get("water", false))
	pos_data.mountain = bool(entry.get("mountain", false))
	tile.pos_data = pos_data
	tile.position = pos_data.world_position

	# biome (string usado en algunas comprobaciones).
	tile.biome = entry.get("biome", Tile.biome_type.find_key(mesh_data.type))

	# Natural resource.
	var nr_path:String = entry.get("natural_resource", "")
	if nr_path != "":
		tile.natural_resource = _load_or_null(nr_path) as NaturalResource

	# Location type.
	var loc_path:String = entry.get("location", "")
	if loc_path != "":
		tile.location = _load_or_null(loc_path) as LocationType

	tile_parent.add_child(tile)
	tile.set_parameters()

	# Nombre de provincia: si viene del savegame lo usamos directamente;
	# si no (savegame antiguo sin el campo), lo regeneramos.
	var saved_name: String = entry.get("province_name", "")
	if saved_name != "":
		tile.province_name = saved_name
	else:
		tile.province_name = ProvinceNameGenerator.generate(tile.biome, tile.pos_data.grid_position)

	return tile


## Aplica los buildings serializados a un tile que ya existe.
##
## Importante: NO usa `tile.build()` porque ese flujo descuenta el coste
## de construcción de las stats. Aquí simplemente reconstruimos el estado.
## Los efectos no se aplican aquí — se aplican en una fase posterior una
## vez que los EmpireController/Stats están enlazados.
static func apply_buildings_pending(tile:Tile, building_keys:Array) -> void:
	tile.buildings.clear()
	for key in building_keys:
		var template:Building = SaveResourceRegistry.load_building(key)
		if template == null:
			continue
		var instance:Building = template.duplicate(true)
		tile.buildings.append(instance)
	tile.recalculate_modifiers()


## Aplica los efectos de los buildings de un tile sobre las stats del
## controlador. Pensado para llamarse cuando ya tenemos los EmpireController
## creados y enlazados.
##
## Como los efectos pueden ser de varios tipos (gold-on-card, modifiers,
## etc.), su `apply_effect(tile, stats)` es la fuente de verdad.
static func apply_building_effects_for_tile(tile:Tile, stats:Stats) -> void:
	for b in tile.buildings:
		for e in b.effects:
			e.apply_effect(tile, stats)


## --- Utilidades ---------------------------------------------------------

static func _path_of(resource:Resource) -> String:
	if resource == null:
		return ""
	return resource.resource_path


static func _load_or_null(path:String) -> Resource:
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path)
