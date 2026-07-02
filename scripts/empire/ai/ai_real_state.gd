extends RefCounted
class_name AIRealState

## Snapshot RICO y clonable del estado real del juego para la búsqueda MCTS
## (Fase C v2 — sustituye al AIGameState escalar de v1).
##
## A diferencia de AIGameState (que colapsaba todo a magnitudes escalares:
## own_tiles, own_gpt…), este estado conserva la estructura POR-TILE: qué
## casilla tiene cada recurso, quién la controla, qué edificios tiene y a qué
## casillas es adyacente. Esto permite que el árbol MCTS ramifique sobre
## colocaciones CONCRETAS (colonizar la tile A vs la B) y que cada colocación
## produzca consecuencias futuras reales (su producción, los edificios que
## habilita, los frentes que abre). Ver _ai_docs/PLAN_MCTS_ESTADO_REAL.md §2.
##
## Datos puros: sin nodos de escena, sin señales, sin el singleton BattleFront.
## Los Building/Card/Troop/NaturalResource son recursos read-only compartidos
## (no se clonan: solo se copian las referencias, igual que en AIGameState).
##
## ALCANCE F1 (esta entrega): tiles + economía base (sin modificadores, sin
## tropas, sin frentes, sin habilidad de imperio). Los campos fronts/troop_pool
## existen pero quedan vacíos hasta F2/F2.5.


# ── Identificadores de propietario ───────────────────────────────────────────
const OWNER_NONE: int = 0   ## Casilla sin colonizar
const OWNER_SELF: int = 1   ## IA que ejecuta la búsqueda
const OWNER_RIVAL: int = 2  ## Oponente (información pública)


## Snapshot de una casilla. Mezcla campos inmutables durante la partida
## (id, bioma, recurso, adyacencia) con mutables (owner, location, edificios).
## clone() copia los mutables y comparte por referencia los inmutables.
class TileSnap:
	# ── Inmutables (compartidos entre clones) ────────────────────────────────
	var id: int                       ## Índice estable en WorldMap.map
	var biome: int                    ## Tile.biome_type
	var resource_gold: int            ## natural_resource.gold_produced (0 si no hay)
	var resource_food: int            ## natural_resource.food_produced
	var natural_resource: NaturalResource  ## ref para filtros de can_build
	var neighbor_ids: Array[int]      ## adyacencia (fija durante la partida)

	# ── Mutables (copiados en clone) ─────────────────────────────────────────
	var owner: int = OWNER_NONE
	var location_type: int = Tile.location_type.Uncolonized
	var max_buildings: int = 0
	var food_consumption: int = 0
	var buildings: Array[Building] = []  ## refs a recursos del catálogo

	## Oro que produce esta casilla (espejo de Tile.recalculate_modifiers).
	func gold_production() -> int:
		var g := resource_gold
		for b in buildings:
			g += b.gold_produced
		return g

	## Comida neta que produce esta casilla (espejo de Tile.recalculate_modifiers):
	## natural_food − food_consumption + Σ(building.food_produced) + bonus porcentual
	## sobre el food natural.
	func food_production() -> int:
		var f := resource_food - food_consumption
		var pct := 0.0
		for b in buildings:
			f += b.food_produced
			pct += b.food_percent_bonus
		if pct != 0.0:
			f += int(resource_food * pct / 100.0)
		return f

	## True si esta casilla puede construir `building` (espejo de Tile.can_build,
	## comparando location por valor de enum en lugar de por referencia al recurso).
	func can_build(building: Building) -> bool:
		if buildings.size() >= max_buildings:
			return false
		for b in buildings:
			if b.name == building.name:
				return false
		if building.required_natural_resource != null \
				and natural_resource != building.required_natural_resource:
			return false
		if not building.allowed_location_type.is_empty():
			var fits := false
			for allowed in building.allowed_location_type:
				if allowed.type == location_type:
					fits = true
					break
			if not fits:
				return false
		if not building.allowed_biomes.is_empty() and biome not in building.allowed_biomes:
			return false
		return true

	func clone() -> TileSnap:
		var t := TileSnap.new()
		# Inmutables: compartir por referencia (no se mutan nunca).
		t.id = id
		t.biome = biome
		t.resource_gold = resource_gold
		t.resource_food = resource_food
		t.natural_resource = natural_resource
		t.neighbor_ids = neighbor_ids
		# Mutables: copiar.
		t.owner = owner
		t.location_type = location_type
		t.max_buildings = max_buildings
		t.food_consumption = food_consumption
		t.buildings = buildings.duplicate()
		return t


## Snapshot del estado de un imperio (recursos, mano, mazo, tropas).
## Para el rival, `hand` se rellena por determinización (SO-ISMCTS, F3) y los
## campos provienen solo de información pública (AIEmpirePublicView).
class EmpireSnap:
	var gold: int = 0
	var gold_per_turn: int = 0
	var food: int = 0
	var cards_per_turn: int = 2
	var hand: Array[Card] = []
	var deck: Array[Card] = []
	var troop_pool: Array[Troop] = []   ## tropas NO asignadas a frentes (F2)
	## Penalización de combate por déficit económico (Empire.combat_multiplier).
	## La recalcula recompute_economy desde el déficit gpt/food (F2). Rango [0.1, 1.0].
	var combat_multiplier: float = 1.0
	## Modificadores económicos activos (StatModifier/BuildCostModifier), incluida
	## la habilidad de imperio (F2.5a). Son copias propias con su `duration`, que
	## advance_turn decrementa y expira. Solo se modelan los PROPIOS: los del rival
	## son ocultos (su efecto ya está integrado en su gpt público).
	var modifiers: Array[Modifier] = []

	# ── Estado de eventos/desbloqueos (F2.5b) ────────────────────────────────
	## Eventos únicos ya disparados (espejo de stats.used_unique_events).
	var used_unique_events: Array[String] = []
	## Contador histórico de tropas reclutadas por tipo (Troop.TroopType → int),
	## para HasRecruitedTroopOfTypeCondition (espejo de stats.types_ever_recruited).
	var types_ever_recruited: Dictionary = {}
	## Pool de cartas desbloqueadas con peso dinámico (espejo de
	## stats.unlocked_card_pool). Lo amplía AddToCardPoolEffect; lo lee
	## AddRandomPoolCardEffect.
	var unlocked_card_pool: Array[UnlockedCardEntry] = []
	## Edificios construibles (espejo de stats.possible_buildings). Lo amplían los
	## eventos de desbloqueo (UnlockBuildingEffect) y gobierna las opciones de
	## BuildCard en la enumeración de acciones (F3).
	var possible_buildings: Array[Building] = []
	## Configuración de eventos (refs read-only compartidas, no se clonan).
	var available_events: Array[TurnEvent] = []
	var category_weights: EventCategoryWeights = null
	var event_chance: float = 0.0   ## fallback legacy si category_weights es null

	# ── Estado de tienda (F2.5c) ─────────────────────────────────────────────
	## Cartas exclusivas de tienda (espejo de stats.shop_exclusive_pool). Junto a
	## unlocked_card_pool forman el pool de la tienda (get_full_shop_pool).
	var shop_exclusive_pool: Array[UnlockedCardEntry] = []
	## Purgas hechas en toda la partida (espejo de stats.total_purges_done). Escala
	## el coste de purga (ShopGenerator._get_purge_cost).
	var total_purges_done: int = 0

	func clone() -> EmpireSnap:
		var e := EmpireSnap.new()
		e.gold = gold
		e.gold_per_turn = gold_per_turn
		e.food = food
		e.cards_per_turn = cards_per_turn
		e.hand = hand.duplicate()
		e.deck = deck.duplicate()
		e.troop_pool = troop_pool.duplicate()
		e.combat_multiplier = combat_multiplier
		# Duplicar los modifiers: su `duration` se muta al tickear → cada clon
		# necesita instancias propias para no afectar a sus hermanos.
		for m in modifiers:
			var dup := m.duplicate_modifier()
			if dup != null:
				e.modifiers.append(dup)
		# Estado de eventos: copiar los contenedores mutables (sus elementos son
		# refs read-only). La config de eventos se comparte por referencia.
		e.used_unique_events = used_unique_events.duplicate()
		e.types_ever_recruited = types_ever_recruited.duplicate(true)
		e.unlocked_card_pool = unlocked_card_pool.duplicate()
		e.possible_buildings = possible_buildings.duplicate()
		e.available_events = available_events
		e.category_weights = category_weights
		e.event_chance = event_chance
		e.shop_exclusive_pool = shop_exclusive_pool.duplicate()
		e.total_purges_done = total_purges_done
		return e


## Snapshot de un frente de batalla activo (F2). Datos puros espejo de
## BattleFront: tiles enfrentadas, tropas comprometidas por bando, bonuses
## tácticos, marcador y umbral. La resolución (tick) vive en AIRealSimulator
## porque necesita el estado global (biomas/edificios de las tiles, combat
## multiplier de los imperios). Reusa las constantes de umbral de BattleFront.
class FrontSnap:
	var attacker_owner: int = OWNER_NONE
	var defender_owner: int = OWNER_NONE
	var attacker_tile_id: int = -1
	var defender_tile_id: int = -1
	var attacker_troops: Array[Troop] = []
	var defender_troops: Array[Troop] = []
	var attacker_bonuses: Array[TacticBonus] = []
	var defender_bonuses: Array[TacticBonus] = []
	var marker: float = 0.0
	var turns_elapsed: int = 0
	var threshold: float = 10.0
	var min_duration: int = 3
	var is_resolved: bool = false

	## Umbral efectivo del turno actual (espejo de BattleFront.get_current_threshold):
	## decae linealmente de `threshold` a BattleFront.MIN_THRESHOLD en
	## BattleFront.THRESHOLD_DECAY_TURNS turnos.
	func current_threshold() -> float:
		if BattleFront.THRESHOLD_DECAY_TURNS <= 0 or threshold <= BattleFront.MIN_THRESHOLD:
			return threshold
		var t := clampf(float(turns_elapsed) / float(BattleFront.THRESHOLD_DECAY_TURNS), 0.0, 1.0)
		return lerpf(threshold, BattleFront.MIN_THRESHOLD, t)

	## True si este frente involucra al imperio `p_owner` (como atacante o defensor).
	func involves(p_owner: int) -> bool:
		return attacker_owner == p_owner or defender_owner == p_owner

	## Devuelve el bando (BattleFront.Side.ATTACKER/BattleFront.Side.DEFENDER) desde el que participa `p_owner`,
	## o BattleFront.Side.NONE si no participa.
	func side_of(p_owner: int) -> BattleFront.Side:
		if attacker_owner == p_owner:
			return BattleFront.Side.ATTACKER
		if defender_owner == p_owner:
			return BattleFront.Side.DEFENDER
		return BattleFront.Side.NONE

	func clone() -> FrontSnap:
		var f := FrontSnap.new()
		f.attacker_owner = attacker_owner
		f.defender_owner = defender_owner
		f.attacker_tile_id = attacker_tile_id
		f.defender_tile_id = defender_tile_id
		f.attacker_troops = attacker_troops.duplicate()
		f.defender_troops = defender_troops.duplicate()
		# Los bonuses se mutan (duration--) → duplicar las instancias para que
		# el tick de un clon no afecte a sus hermanos.
		for b in attacker_bonuses:
			f.attacker_bonuses.append(b.duplicate() as TacticBonus)
		for b in defender_bonuses:
			f.defender_bonuses.append(b.duplicate() as TacticBonus)
		f.marker = marker
		f.turns_elapsed = turns_elapsed
		f.threshold = threshold
		f.min_duration = min_duration
		f.is_resolved = is_resolved
		return f


# ── Estado de alto nivel ─────────────────────────────────────────────────────
var own: EmpireSnap = EmpireSnap.new()
var rival: EmpireSnap = EmpireSnap.new()
var tiles: Dictionary = {}          ## id -> TileSnap
var fronts: Array = []              ## Array[FrontSnap] — F2
var turn_number: int = 0
var total_map_tiles: int = 0


## Construye el snapshot inicial desde el AITurnContext del turno real.
##
## Barrera de información (PLAN §3.5): los datos del rival se leen SOLO de
## fuentes públicas — el mapa (WorldMap, observable) para tiles/edificios y la
## AIEmpirePublicView para oro/gpt/comida/hand_size. NUNCA se accede a
## rival.stats.draw_pile/discard_pile/hand: la mano del rival se determiniza
## en F3 a partir de known_deck.
static func from_context(ctx: AITurnContext) -> AIRealState:
	var s := AIRealState.new()
	var stats: Stats = ctx.stats

	# Mapeo Tile -> id estable (índice en WorldMap.map).
	var index_of := {}
	var world: Array = WorldMap.map
	for i in range(world.size()):
		index_of[world[i]] = i
	s.total_map_tiles = world.size()

	var own_empire: Empire = stats.empire if stats != null else null
	var rival_view: AIEmpirePublicView = null
	if ctx.world_view != null:
		rival_view = ctx.world_view.get_rival_view()
	var rival_empire: Empire = rival_view.empire if rival_view != null else null

	# ── Tiles ────────────────────────────────────────────────────────────────
	for i in range(world.size()):
		var tile: Tile = world[i]
		var snap := TileSnap.new()
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
			snap.owner = OWNER_SELF
		elif tile.controller == rival_empire and rival_empire != null:
			snap.owner = OWNER_RIVAL
		else:
			snap.owner = OWNER_NONE
		var nbrs: Array[int] = []
		for nb in tile.neighbors:
			if nb != null and index_of.has(nb):
				nbrs.append(index_of[nb])
		snap.neighbor_ids = nbrs
		s.tiles[i] = snap

	# ── Imperio propio (acceso completo) ─────────────────────────────────────
	if stats != null:
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
		# Estado de eventos/desbloqueos (F2.5b).
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

	# ── Rival (solo información pública) ──────────────────────────────────────
	if rival_view != null:
		s.rival.gold = rival_view.total_gold
		s.rival.gold_per_turn = rival_view.gold_per_turn
		s.rival.food = rival_view.food
		s.rival.cards_per_turn = rival_view.hand_size
		s.rival.hand = []   # determinizada en F3
		s.rival.deck = rival_view.known_deck.duplicate()
		if rival_empire != null:
			s.rival.combat_multiplier = rival_empire.combat_multiplier

	# ── Frentes activos (información pública: visibles en el mapa) ────────────
	for front in BattleFront.get_active_instances():
		if front == null or front.is_resolved:
			continue
		var fs := FrontSnap.new()
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

	return s


## Lee los modificadores económicos PROPIOS del ModifierManager del controller
## y devuelve copias (F2.5a). Solo se modelan StatModifier y BuildCostModifier
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


## Clasifica un Empire en OWNER_SELF / OWNER_RIVAL / OWNER_NONE.
static func _owner_of_empire(empire: Empire, own_empire: Empire,
		rival_empire: Empire) -> int:
	if empire != null and empire == own_empire:
		return OWNER_SELF
	if empire != null and empire == rival_empire:
		return OWNER_RIVAL
	return OWNER_NONE


## Normaliza un bonus de frente (TacticBonus o Dictionary legacy) a TacticBonus.
static func _as_tactic_bonus(raw: Variant) -> TacticBonus:
	if raw is TacticBonus:
		return (raw as TacticBonus).duplicate() as TacticBonus
	return TacticBonus.from_dict(raw as Dictionary)


## Copia profunda barata: comparte los campos inmutables de cada TileSnap y
## copia solo los mutables. O(tiles + cartas de mano/mazo).
func clone() -> AIRealState:
	var c := AIRealState.new()
	c.own = own.clone()
	c.rival = rival.clone()
	c.turn_number = turn_number
	c.total_map_tiles = total_map_tiles
	# Copy-on-write: el clon COMPARTE los TileSnap por referencia (copia barata
	# del diccionario). AIRealSimulator clona la casilla concreta antes de
	# mutarla (_writable), así que ningún clon ve mutaciones de otro. IMPORTANTE:
	# no mutar TileSnap directamente desde fuera; hacerlo siempre vía AIRealSimulator.
	c.tiles = tiles.duplicate()
	for f in fronts:
		c.fronts.append((f as FrontSnap).clone())
	return c


# ── Consultas derivadas ──────────────────────────────────────────────────────

## Número de casillas controladas por `owner` (OWNER_SELF / OWNER_RIVAL).
func count_tiles(p_owner: int) -> int:
	var n := 0
	for id in tiles:
		if (tiles[id] as TileSnap).owner == p_owner:
			n += 1
	return n
