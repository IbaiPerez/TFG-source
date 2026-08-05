extends RefCounted
class_name AIRealStateBuilder

## Construye el snapshot (AIRealState) leyendo el mundo vivo.
##
## Está separado del snapshot porque son dos responsabilidades distintas: allí
## vive QUÉ es un estado y cómo se clona; aquí, cómo se vuelca el juego real a
## esa forma. Solo esta mitad conoce WorldMap, Tile, Stats y AITurnContext.
##
## BARRERA DE INFORMACIÓN — es la regla que hace honesto al MCTS: los datos del
## rival se leen SOLO de fuentes públicas, el mapa (observable) para casillas y
## edificios y la AIEmpirePublicView para oro/gpt/comida/tamaño de mano. Nunca
## se toca rival.stats.draw_pile/discard_pile/hand — la mano del rival se
## determiniza aparte, a partir del mazo conocido.

## Construye el snapshot inicial desde el AITurnContext del turno real.
##
## Barrera de información: los datos del rival se leen SOLO de
## fuentes públicas — el mapa (WorldMap, observable) para tiles/edificios y la
## AIEmpirePublicView para oro/gpt/comida/hand_size. NUNCA se accede a
## rival.stats.draw_pile/discard_pile/hand: la mano del rival se determiniza
## en F3 a partir de known_deck.
static func from_context(ctx: AITurnContext) -> AIRealState:
	var s := AIRealState.new()
	var stats: Stats = ctx.stats
	var world: Array = WorldMap.map
	var index_of := build_tile_index(world)
	s.total_map_tiles = world.size()

	var own_empire: Empire = stats.empire if stats != null else null
	var rival_view: AIEmpirePublicView = null
	if ctx.world_view != null:
		rival_view = ctx.world_view.get_rival_view()
	var rival_empire: Empire = rival_view.empire if rival_view != null else null

	_snapshot_tiles(s, world, index_of, own_empire, rival_empire)
	_snapshot_own_empire(s, ctx, stats, own_empire)
	_snapshot_rival_public(s, rival_view, rival_empire)
	_snapshot_fronts(s, ctx, index_of, own_empire, rival_empire)
	return s


## Mapeo `Tile → id` estable (posición en WorldMap.map).
##
## Lo comparten from_context y AIController (que lo guarda en `ctx.tile_index`), y
## eso NO es casual: ambos deben producir EXACTAMENTE los mismos ids, porque las
## jugadas del snapshot se casan con las opciones reales comparando ese id. Tener un
## solo constructor elimina la posibilidad de que diverjan.
static func build_tile_index(world: Array) -> Dictionary:
	var index_of := {}
	for i in range(world.size()):
		index_of[world[i]] = i
	return index_of


## Casillas del mapa: geografía, edificios, propietario relativo y adyacencia por id.
static func _snapshot_tiles(s: AIRealState, world: Array, index_of: Dictionary,
		own_empire: Empire, rival_empire: Empire) -> void:
	for i in range(world.size()):
		var tile: Tile = world[i]
		var snap := AIRealState.TileSnap.new()
		snap.id = i
		snap.biome = tile.mesh_data.type if tile.mesh_data != null else 0
		if tile.natural_resource != null:
			snap.natural_resource = tile.natural_resource
			snap.resource_gold = tile.natural_resource.gold_produced
			snap.resource_food = tile.natural_resource.food_produced
		if tile.location != null:
			snap.location_type = tile.location.type
			snap.max_buildings = tile.location.max_building
			snap.food_consumption = tile.location.food_consumption
		snap.buildings = tile.buildings.duplicate()
		if tile.controller == own_empire and own_empire != null:
			snap.owner = AIRealState.OWNER_SELF
		elif tile.controller == rival_empire and rival_empire != null:
			snap.owner = AIRealState.OWNER_RIVAL
		else:
			snap.owner = AIRealState.OWNER_NONE
		var nbrs: Array[int] = []
		for nb in tile.neighbors:
			if nb != null and index_of.has(nb):
				nbrs.append(index_of[nb])
		snap.neighbor_ids = nbrs
		s.tiles[i] = snap


## Imperio propio: acceso COMPLETO (economía, mazo real, tropas, desbloqueos).
static func _snapshot_own_empire(s: AIRealState, ctx: AITurnContext, stats: Stats,
		own_empire: Empire) -> void:
	if stats == null:
		return
	s.own.gold = stats.total_gold
	s.own.gold_per_turn = stats.gold_per_turn
	s.own.food = stats.food
	s.own.cards_per_turn = stats.cards_per_turn
	s.own.hand = ctx.drawn_cards.duplicate()
	var deck: Array[Card] = []
	if stats.draw_pile != null:
		deck.append_array(stats.draw_pile.cards)
	if stats.discard_pile != null:
		deck.append_array(stats.discard_pile.cards)
	s.own.deck = deck
	s.own.troop_pool = stats.troop_pool.duplicate()
	if own_empire != null:
		s.own.combat_multiplier = own_empire.combat_multiplier
	s.own.modifiers = _read_economic_modifiers(ctx)
	# Estado de eventos/desbloqueos.
	s.own.used_unique_events = stats.used_unique_events.duplicate()
	s.own.types_ever_recruited = stats.types_ever_recruited.duplicate(true)
	s.own.unlocked_card_pool = stats.unlocked_card_pool.duplicate()
	s.own.possible_buildings = stats.possible_buildings.duplicate()
	s.own.available_events = stats.available_events
	s.own.category_weights = stats.category_weights
	s.own.event_chance = stats.event_chance
	s.own.shop_exclusive_pool = stats.shop_exclusive_pool.duplicate()
	s.own.total_purges_done = stats.total_purges_done
	s.turn_number = stats.turn_number


## Rival: SOLO información pública (barrera de información). Su mano se
## determiniza aparte en F3; aquí queda vacía a propósito.
static func _snapshot_rival_public(s: AIRealState, rival_view: AIEmpirePublicView,
		rival_empire: Empire) -> void:
	if rival_view == null:
		return
	s.rival.gold = rival_view.total_gold
	s.rival.gold_per_turn = rival_view.gold_per_turn
	s.rival.food = rival_view.food
	s.rival.cards_per_turn = rival_view.hand_size
	s.rival.hand = []   # determinizada en F3
	s.rival.deck = rival_view.known_deck.duplicate()
	if rival_empire != null:
		s.rival.combat_multiplier = rival_empire.combat_multiplier


## Frentes activos: información pública (son visibles en el mapa).
static func _snapshot_fronts(s: AIRealState, ctx: AITurnContext, index_of: Dictionary,
		own_empire: Empire, rival_empire: Empire) -> void:
	for front in ctx.get_front_registry().get_active_instances():
		if front == null or front.is_resolved:
			continue
		var fs := AIRealState.FrontSnap.new()
		fs.attacker_owner = _owner_of_empire(front.attacker_empire, own_empire, rival_empire)
		fs.defender_owner = _owner_of_empire(front.defender_empire, own_empire, rival_empire)
		fs.attacker_tile_id = index_of.get(front.attacker_tile, -1)
		fs.defender_tile_id = index_of.get(front.defender_tile, -1)
		fs.attacker_troops = front.attacker_troops.duplicate()
		fs.defender_troops = front.defender_troops.duplicate()
		for raw in front.attacker_bonuses:
			fs.attacker_bonuses.append(_as_tactic_bonus(raw))
		for raw in front.defender_bonuses:
			fs.defender_bonuses.append(_as_tactic_bonus(raw))
		fs.marker = front.marker
		fs.turns_elapsed = front.turns_elapsed
		fs.threshold = front.threshold
		fs.min_duration = front.min_duration
		s.fronts.append(fs)


## Lee los modificadores económicos PROPIOS del ModifierManager del controller
## y devuelve copias. Solo se modelan StatModifier y BuildCostModifier
## (los que afectan a la economía/coste de construcción); el resto del estado de
## modifiers — CardReturn, GoldOnCard — no toca la economía por turno. La
## habilidad de imperio entra aquí gratis porque se aplica como estos modifiers.
static func _read_economic_modifiers(ctx: AITurnContext) -> Array[Modifier]:
	var result: Array[Modifier] = []
	if ctx.controller == null or not (&"modifier_manager" in ctx.controller):
		return result
	var mm = ctx.controller.modifier_manager
	if mm == null:
		return result
	for mod in mm.active_modifiers:
		if mod is StatModifier or mod is BuildCostModifier:
			var dup = mod.duplicate_modifier()
			if dup != null:
				result.append(dup)
	return result


## Clasifica un Empire en AIRealState.OWNER_SELF / AIRealState.OWNER_RIVAL / AIRealState.OWNER_NONE.
static func _owner_of_empire(empire: Empire, own_empire: Empire,
		rival_empire: Empire) -> int:
	if empire != null and empire == own_empire:
		return AIRealState.OWNER_SELF
	if empire != null and empire == rival_empire:
		return AIRealState.OWNER_RIVAL
	return AIRealState.OWNER_NONE


## Normaliza un bonus de frente (TacticBonus o Dictionary legacy) a TacticBonus.
static func _as_tactic_bonus(raw: Variant) -> TacticBonus:
	if raw is TacticBonus:
		return (raw as TacticBonus).duplicate() as TacticBonus
	return TacticBonus.from_dict(raw as Dictionary)


## Copia profunda barata: comparte los campos inmutables de cada AIRealState.TileSnap y
