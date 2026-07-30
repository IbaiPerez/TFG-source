extends RefCounted
class_name BattleFrontSerializer

## Serializa los frentes de batalla activos.
##
## Las tropas asignadas a un frente NO están en `stats.troop_pool` (se
## sacan de él al asignar), por lo que su persistencia se resuelve aquí
## guardándolas como referencias por path al .tres de Troop.
##
## Los bonuses (cartas tácticas, eventos, edificios) se guardan tal cual
## como Dictionary, ya que su forma es de por sí libre.


## Campos escalares del frente, declarados UNA vez para las dos direcciones
## (§2.6.b). `KEEP` = si el save no lo trae, conservar el valor con el que nace el
## BattleFront (min_duration y threshold vienen de GameBalance, no de 0).
const PLAIN_FIELDS := {
	"marker": 0.0,
	"turns_elapsed": 0,
	"min_duration": SerializationUtils.KEEP,
	"threshold": SerializationUtils.KEEP,
}


## --- Serialización ------------------------------------------------------

static func to_dict(front:BattleFront) -> Dictionary:
	if front == null or front.is_resolved:
		return {}

	var d := SerializationUtils.pack(front, PLAIN_FIELDS)
	d.merge({
		"attacker_pos": _grid_pos_of(front.attacker_tile),
		"defender_pos": _grid_pos_of(front.defender_tile),
		"attacker_empire": front.attacker_empire.resource_path if front.attacker_empire else "",
		"defender_empire": front.defender_empire.resource_path if front.defender_empire else "",
		"attacker_troops": _serialize_troops(front.attacker_troops),
		"defender_troops": _serialize_troops(front.defender_troops),
		"attacker_bonuses": _sanitize_bonuses(front.attacker_bonuses),
		"defender_bonuses": _sanitize_bonuses(front.defender_bonuses),
	})
	return d


## --- Reconstrucción -----------------------------------------------------

## Crea un BattleFront a partir del dict, mirando los Tile/Empire en
## el contexto reconstruido (mapa por posición, empires por nombre).
##
## `tiles_by_pos` (Vector2 → Tile) se INYECTA en vez de leer `WorldMap.map_as_dict`
## (§2.6.c): así el serializador se puede probar con un puñado de casillas sueltas,
## sin montar un mundo entero ni depender del autoload. El llamante real le pasa el
## índice del mundo recién reconstruido.
##
## Devuelve null si las referencias no resuelven.
static func from_dict(data:Dictionary, empires_by_name:Dictionary,
		tiles_by_pos:Dictionary) -> BattleFront:
	if data.is_empty():
		return null

	var atk_pos:Array = data.get("attacker_pos", [])
	var def_pos:Array = data.get("defender_pos", [])
	if atk_pos.size() != 2 or def_pos.size() != 2:
		return null

	var atk_tile:Tile = tiles_by_pos.get(Vector2(atk_pos[0], atk_pos[1]))
	var def_tile:Tile = tiles_by_pos.get(Vector2(def_pos[0], def_pos[1]))
	if atk_tile == null or def_tile == null:
		return null

	var atk_emp:Empire = empires_by_name.get(data.get("attacker_empire", ""))
	var def_emp:Empire = empires_by_name.get(data.get("defender_empire", ""))
	if atk_emp == null or def_emp == null:
		return null

	var front := BattleFront.new(atk_tile, def_tile, atk_emp, def_emp)
	SerializationUtils.unpack(front, data, PLAIN_FIELDS)
	front.attacker_troops = _restore_troops(data.get("attacker_troops", []))
	front.defender_troops = _restore_troops(data.get("defender_troops", []))
	front.attacker_bonuses = _restore_bonuses(data.get("attacker_bonuses", []))
	front.defender_bonuses = _restore_bonuses(data.get("defender_bonuses", []))
	return front


## --- Helpers privados ---------------------------------------------------

static func _grid_pos_of(tile:Tile) -> Array:
	if tile == null or tile.pos_data == null:
		return []
	return [int(tile.pos_data.grid_position.x), int(tile.pos_data.grid_position.y)]


static func _serialize_troops(troops:Array[Troop]) -> Array:
	var out:Array = []
	for t in troops:
		out.append(SaveResourceRegistry.troop_key(t))
	return out


static func _restore_troops(keys:Array) -> Array[Troop]:
	var out:Array[Troop] = []
	for key in keys:
		var t:Troop = SaveResourceRegistry.load_troop(key)
		if t != null:
			out.append(t)
	return out


## Convierte cada bonus (TacticBonus o Dictionary) a un Dictionary JSON-safe.
## Los TacticBonus se serialerizan campo a campo; los Dictionaries legacy
## se sanitizan igual que antes (convirtiendo Resources a paths).
static func _sanitize_bonuses(bonuses:Array) -> Array:
	var out:Array = []
	for raw in bonuses:
		var clean:Dictionary = {}
		if raw is TacticBonus:
			var b := raw as TacticBonus
			clean["tactic_name"]              = b.tactic_name
			clean["troop_name"]               = b.troop_name
			clean["troop_type"]               = b.troop_type
			clean["troop_types"]              = b.troop_types.duplicate()
			clean["attack"]                   = b.attack
			clean["attack_percent"]           = b.attack_percent
			clean["attack_per_troop"]         = b.attack_per_troop
			clean["attack_percent_per_type"]  = b.attack_percent_per_type
			clean["attack_biome_modifier"]    = b.attack_biome_modifier
			clean["defense"]                  = b.defense
			clean["defense_percent"]          = b.defense_percent
			clean["defense_per_troop"]        = b.defense_per_troop
			clean["defense_percent_per_type"] = b.defense_percent_per_type
			clean["defense_biome_modifier"]   = b.defense_biome_modifier
			clean["duration"]                 = b.duration
		elif raw is Dictionary:
			var d := raw as Dictionary
			for key in d.keys():
				var v = d[key]
				if v is Resource:
					clean[key] = (v as Resource).resource_path
				else:
					clean[key] = v
		out.append(clean)
	return out


## Restaura los bonuses desde datos serializados como instancias TacticBonus.
static func _restore_bonuses(data:Array) -> Array:
	var out:Array = []
	for entry in data:
		if entry is Dictionary:
			out.append(TacticBonus.from_dict(entry as Dictionary))
	return out
