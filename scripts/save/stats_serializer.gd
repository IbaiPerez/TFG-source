extends RefCounted
class_name StatsSerializer

## Serializa y reconstruye un Stats para el sistema de save.
##
## Cubre:
## - Recursos de partida (gold, food, gold_per_turn).
## - Configuración (cards_per_turn, event_chance, possible_buildings).
## - Pilas de cartas (deck, draw, discard, played) preservando el ORDEN
##   exacto, vital para no romper la baraja al cargar.
## - Pool de tropas reclutadas.
## - Pools de cartas desbloqueadas (general + tienda exclusiva).
## - Estado de progreso (turn_number, total_purges_done, used_unique_events).
##
## NO cubre: el `empire` (se restaura desde el snapshot global) ni los
## modifiers activos (van por su propio serializador en ModifierSerializer).


## --- Serialización ------------------------------------------------------

static func to_dict(stats:Stats) -> Dictionary:
	if stats == null:
		return {}
	return {
		"template_path": stats.resource_path,
		"total_gold": stats.total_gold,
		"gold_per_turn": stats.gold_per_turn,
		"food": stats.food,
		"cards_per_turn": stats.cards_per_turn,
		"event_chance": stats.event_chance,
		"turn_number": stats.turn_number,
		"total_purges_done": stats.total_purges_done,
		"used_unique_events": stats.used_unique_events.duplicate(),
		"possible_buildings": _serialize_buildings(stats.possible_buildings),
		"deck": _serialize_card_pile(stats.deck),
		"draw_pile": _serialize_card_pile(stats.draw_pile),
		"discard_pile": _serialize_card_pile(stats.discard_pile),
		"played_pile": _serialize_card_pile(stats.played_pile),
		"troop_pool": _serialize_troops(stats.troop_pool),
		"types_ever_recruited": _serialize_types_ever_recruited(stats.types_ever_recruited),
		"unlocked_card_pool": _serialize_unlocked_pool(stats.unlocked_card_pool),
		"shop_exclusive_pool": _serialize_unlocked_pool(stats.shop_exclusive_pool),
	}


## --- Reconstrucción -----------------------------------------------------

## Crea una instancia fresca de Stats a partir del template indicado en el
## save y le aplica todos los campos serializados.
static func from_dict(data:Dictionary, empire:Empire) -> Stats:
	if data.is_empty():
		return null

	var template_path:String = data.get("template_path", "")
	var stats:Stats
	if template_path != "" and ResourceLoader.exists(template_path):
		var template:Stats = load(template_path) as Stats
		stats = template.create_instance() as Stats
	else:
		stats = Stats.new()

	stats.empire = empire
	stats.total_gold = int(data.get("total_gold", 0))
	stats.gold_per_turn = int(data.get("gold_per_turn", 0))
	stats.food = int(data.get("food", 0))
	stats.cards_per_turn = int(data.get("cards_per_turn", stats.cards_per_turn))
	stats.event_chance = float(data.get("event_chance", stats.event_chance))
	stats.turn_number = int(data.get("turn_number", 0))
	stats.total_purges_done = int(data.get("total_purges_done", 0))

	stats.used_unique_events.clear()
	for ev in data.get("used_unique_events", []):
		stats.used_unique_events.append(String(ev))

	# possible_buildings: cargar referencias usando el registry (los buildings
	# pueden venir como path o como nombre).
	var pb:Array[Building] = []
	for key in data.get("possible_buildings", []):
		var b:Building = SaveResourceRegistry.load_building(key)
		if b != null:
			pb.append(b)
	stats.possible_buildings = pb

	# Pilas de cartas (orden literal preservado).
	stats.deck = _restore_card_pile(data.get("deck", []), stats)
	stats.draw_pile = _restore_card_pile(data.get("draw_pile", []), stats)
	stats.discard_pile = _restore_card_pile(data.get("discard_pile", []), stats)
	stats.played_pile = _restore_card_pile(data.get("played_pile", []), stats)

	# Tropas
	stats.troop_pool.clear()
	for entry in data.get("troop_pool", []):
		var troop:Troop = SaveResourceRegistry.load_troop(entry)
		if troop != null:
			stats.troop_pool.append(troop)

	# Contador historico de tipos reclutados. Saves antiguos no lo traen,
	# default a {}: el jugador pierde el historial pero la partida sigue
	# siendo jugable (las tacticas se desbloquearan cuando vuelva a
	# reclutar despues de cargar).
	stats.types_ever_recruited = _restore_types_ever_recruited(
		data.get("types_ever_recruited", {}))

	# Pools desbloqueables
	stats.unlocked_card_pool = _restore_unlocked_pool(data.get("unlocked_card_pool", []))
	stats.shop_exclusive_pool = _restore_unlocked_pool(data.get("shop_exclusive_pool", []))

	return stats


## --- Pilas de cartas ----------------------------------------------------

static func _serialize_card_pile(pile:CardPile) -> Array:
	if pile == null:
		return []
	var out:Array = []
	for card in pile.cards:
		# Usamos `SaveResourceRegistry.card_key` porque las cartas en pilas
		# son duplicados de los .tres y `Resource.duplicate()` borra el
		# resource_path. El registry resuelve por `card.id` cuando el path
		# está vacío.
		out.append(SaveResourceRegistry.card_key(card))
	return out


## Crea una CardPile a partir de una lista de claves (paths o ids). Las
## BuildCard se sincronizan con `stats.possible_buildings` para mantener
## consistencia (mismo flujo que `Stats._sync_build_cards`).
static func _restore_card_pile(keys:Array, stats:Stats) -> CardPile:
	var pile := CardPile.new()
	for key in keys:
		var template:Card = SaveResourceRegistry.load_card(key)
		if template == null:
			continue
		var card:Card = template.duplicate(true)
		stats.sync_card_buildings(card)
		pile.add_card(card)
	return pile


## --- Tropas y pools de desbloqueo --------------------------------------

static func _serialize_troops(troops:Array[Troop]) -> Array:
	var out:Array = []
	for t in troops:
		out.append(SaveResourceRegistry.troop_key(t))
	return out


## Convierte el Dictionary {int → int} a {String → int} para que JSON
## preserve las claves enteras (JSON solo soporta claves de tipo string).
static func _serialize_types_ever_recruited(counter:Dictionary) -> Dictionary:
	var out:Dictionary = {}
	for key in counter:
		out[str(int(key))] = int(counter[key])
	return out


static func _restore_types_ever_recruited(data:Dictionary) -> Dictionary:
	var out:Dictionary = {}
	for key in data:
		# `key` viene como String desde JSON; lo convertimos al int de
		# Troop.TroopType. Saltamos entradas mal formadas en lugar de
		# crashear: un save corrupto que pierde el historial es mejor
		# que un save que no carga.
		if not (key is String or key is int):
			continue
		var type_int:int = int(str(key))
		out[type_int] = int(data[key])
	return out


static func _serialize_unlocked_pool(pool:Array[UnlockedCardEntry]) -> Array:
	var out:Array = []
	for entry in pool:
		out.append({
			"card": SaveResourceRegistry.card_key(entry.card),
			"base_weight": entry.base_weight,
			"weight_per_turn": entry.weight_per_turn,
			"min_weight": entry.min_weight,
		})
	return out


static func _restore_unlocked_pool(data:Array) -> Array[UnlockedCardEntry]:
	var out:Array[UnlockedCardEntry] = []
	for entry in data:
		var card:Card = SaveResourceRegistry.load_card(entry.get("card", ""))
		if card == null:
			continue
		var unlocked := UnlockedCardEntry.new(
			card,
			float(entry.get("base_weight", 5.0)),
			float(entry.get("weight_per_turn", 0.0)),
			float(entry.get("min_weight", 1.0)),
		)
		out.append(unlocked)
	return out


## --- Utilidades ---------------------------------------------------------

static func _serialize_buildings(buildings:Array[Building]) -> Array:
	var out:Array = []
	for b in buildings:
		out.append(SaveResourceRegistry.building_key(b))
	return out


static func _paths_of(resources:Array) -> Array:
	var out:Array = []
	for r in resources:
		out.append(_path_of(r))
	return out


static func _path_of(resource:Resource) -> String:
	if resource == null:
		return ""
	return resource.resource_path


static func _load_or_null(path:String) -> Resource:
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path)
