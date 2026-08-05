extends RefCounted
class_name AIRealState

## Snapshot RICO y clonable del estado real del juego para la búsqueda MCTS.
##
## Conserva la estructura POR-TILE (qué casilla tiene cada recurso, quién la
## controla, qué edificios tiene y a qué casillas es adyacente) para que el árbol
## MCTS ramifique sobre colocaciones CONCRETAS (colonizar la tile A vs la B) y
## cada colocación produzca consecuencias futuras reales (su producción, los
## edificios que habilita, los frentes que abre).
##
## Datos puros: sin nodos de escena, sin señales, sin el singleton BattleFront.
## Los Building/Card/Troop/NaturalResource son recursos read-only compartidos
## (no se clonan: solo se copian las referencias).
##
## Modela: tiles + economía (con modificadores y habilidad de imperio) + tropas
## + frentes de batalla + eventos/tienda.


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
	## La recalcula recompute_economy desde el déficit gpt/food. Rango [0.1, 1.0].
	var combat_multiplier: float = 1.0
	## Modificadores económicos activos (StatModifier/BuildCostModifier), incluida
	## la habilidad de imperio. Son copias propias con su `duration`, que
	## advance_turn decrementa y expira. Solo se modelan los PROPIOS: los del rival
	## son ocultos (su efecto ya está integrado en su gpt público).
	var modifiers: Array[Modifier] = []

	# ── Estado de eventos/desbloqueos ────────────────────────────────
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
	## BuildCard en la enumeración de acciones.
	var possible_buildings: Array[Building] = []
	## Configuración de eventos (refs read-only compartidas, no se clonan).
	var available_events: Array[TurnEvent] = []
	var category_weights: EventCategoryWeights = null
	var event_chance: float = 0.0   ## fallback legacy si category_weights es null

	# ── Estado de tienda ─────────────────────────────────────────────
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


## Snapshot de un frente de batalla activo. Datos puros espejo de
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

	## Umbral efectivo del turno actual (mismo motor que el juego real,
	## vía CombatMath.current_threshold).
	func current_threshold() -> float:
		return CombatMath.current_threshold(threshold, turns_elapsed)

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

## Snapshot del imperio de `p_owner` (OWNER_SELF / OWNER_RIVAL), o null si no
## corresponde a ninguno (OWNER_NONE). Fuente única para todos los espejos.
func empire(p_owner: int) -> EmpireSnap:
	if p_owner == OWNER_SELF:
		return own
	if p_owner == OWNER_RIVAL:
		return rival
	return null


## Número de casillas controladas por `owner` (OWNER_SELF / OWNER_RIVAL).
func count_tiles(p_owner: int) -> int:
	var n := 0
	for id in tiles:
		if (tiles[id] as TileSnap).owner == p_owner:
			n += 1
	return n
