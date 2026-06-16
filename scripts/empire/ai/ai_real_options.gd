extends RefCounted
class_name AIRealOptions

## Enumeración y aplicación de jugadas (carta + TARGET) sobre AIRealState para la
## búsqueda MCTS v2 (Fase C v2 — F3a). Espejo, sobre el snapshot, de
## AIOptionsBuilder: produce un Move por colocación concreta (qué carta, dónde),
## que es justo lo que el árbol ramifica (la fuerza del MCTS es decidir DÓNDE).
##
## Cada Move es aplicable con `apply()`, que delega en AIRealSimulator /
## AIRealEvents. No toca escena ni señales (datos puros).
##
## Cobertura: Colonize, Build, DirectBuild, Upgrade, ChangeLocation, GenerateGold,
## CardDraw, Recruit, OpenFront, Tactic. Recover se omite (el snapshot no modela
## played_pile); CardDraw muta la mano del turno, que gestiona el árbol (F3b).


## Una jugada concreta del árbol. Solo se rellenan los campos del `kind`.
class Move:
	var kind: StringName = &"PASS"
	var card: Card = null
	var tile_id: int = -1            ## target principal (colonize/build/upgrade/changeloc/open_front src)
	var def_tile_id: int = -1        ## defensora (open_front)
	var building: Building = null    ## build / direct_build
	var old_building: Building = null ## upgrade
	var new_building: Building = null ## upgrade
	var location: LocationType = null ## change_location
	var troop: Troop = null          ## recruit
	var troop_count: int = 1         ## recruit (tropas por play efectivas)
	var front_idx: int = -1          ## tactic (índice en state.fronts)
	var amount: int = 0              ## generate_gold / card_draw

	static func pass_move() -> Move:
		var m := Move.new()
		m.kind = &"PASS"
		return m


## Enumera todas las jugadas legales de `hand` sobre el estado, desde la
## perspectiva de `p_owner`. Mirror de AIOptionsBuilder sobre el snapshot.
static func enumerate(state: AIRealState, hand: Array[Card],
		p_owner: int = AIRealState.OWNER_SELF) -> Array:
	var moves: Array = []
	var emp := state.own if p_owner == AIRealState.OWNER_SELF else state.rival
	if emp == null:
		return moves
	for card in hand:
		if card == null:
			continue
		if card is DirectBuildCard:
			_add_direct_build(moves, state, card as DirectBuildCard, emp, p_owner)
		elif card is UpgradeBuildingCard:
			_add_upgrade(moves, state, card as UpgradeBuildingCard, emp, p_owner)
		elif card is BuildCard:
			_add_build(moves, state, card as BuildCard, emp, p_owner)
		elif card is ColonizeCard:
			_add_colonize(moves, state, card as ColonizeCard, p_owner)
		elif card is ChangeLocationTypeCard:
			_add_change_location(moves, state, card as ChangeLocationTypeCard, emp, p_owner)
		elif card is GenerateGoldCard:
			_add_generate_gold(moves, card as GenerateGoldCard)
		elif card is CardDrawCard:
			_add_card_draw(moves, card as CardDrawCard)
		elif card is RecruitCard:
			_add_recruit(moves, card as RecruitCard, emp, p_owner)
		elif card is OpenFrontCard:
			_add_open_front(moves, state, card as OpenFrontCard, p_owner)
		elif card is TacticCard:
			_add_tactic(moves, state, card as TacticCard, p_owner)
		# RecoverCard: omitida (sin played_pile en el snapshot).
	return moves


## Aplica un Move sobre el estado (in-place). `rng` solo lo usan efectos con azar.
static func apply(state: AIRealState, move: Move, p_owner: int = AIRealState.OWNER_SELF,
		rng: RandomNumberGenerator = null) -> void:
	match move.kind:
		&"COLONIZE":
			AIRealSimulator.apply_colonize(state, move.tile_id, p_owner)
		&"BUILD", &"DIRECT_BUILD":
			AIRealSimulator.apply_build(state, move.tile_id, move.building, p_owner)
		&"UPGRADE":
			AIRealSimulator.apply_upgrade(state, move.tile_id, move.old_building,
				move.new_building, p_owner)
		&"CHANGE_LOCATION":
			AIRealSimulator.apply_change_location(state, move.tile_id, move.location, p_owner)
		&"GENERATE_GOLD":
			AIRealSimulator.apply_generate_gold(state, move.amount, p_owner)
		&"RECRUIT":
			AIRealSimulator.apply_recruit(state, move.troop, move.troop_count, p_owner)
		&"OPEN_FRONT":
			AIRealSimulator.apply_open_front(state, move.tile_id, move.def_tile_id, p_owner)
		&"TACTIC":
			if move.front_idx >= 0 and move.front_idx < state.fronts.size():
				AIRealSimulator.apply_tactic(state, state.fronts[move.front_idx]
					as AIRealState.FrontSnap, move.card, p_owner)
		&"CARD_DRAW", &"PASS":
			pass   # CARD_DRAW: la mano del turno la gestiona el árbol (tempo).


# ---------------------------------------------------------------------------
# Constructores por tipo de carta (espejo de AIOptionsBuilder sobre el snapshot)
# ---------------------------------------------------------------------------

static func _add_colonize(moves: Array, state: AIRealState, card: ColonizeCard,
		p_owner: int) -> void:
	# Tiles sin colonizar adyacentes a una casilla propia (AdjacentCondition).
	# Iteramos las casillas PROPIAS y recogemos sus vecinas libres (dedup), igual
	# que open_front/eventos: así solo dependemos de la dirección propio→vecino.
	var seen := {}
	for id in state.tiles:
		var t := state.tiles[id] as AIRealState.TileSnap
		if t.owner != p_owner:
			continue
		for nid in t.neighbor_ids:
			if seen.has(nid):
				continue
			var nb := state.tiles.get(nid) as AIRealState.TileSnap
			if nb != null and nb.owner == AIRealState.OWNER_NONE:
				seen[nid] = true
				var m := Move.new()
				m.kind = &"COLONIZE"
				m.card = card
				m.tile_id = nid
				moves.append(m)


static func _add_build(moves: Array, state: AIRealState, card: BuildCard,
		emp: AIRealState.EmpireSnap, p_owner: int) -> void:
	# Las opciones de edificio salen de possible_buildings (refleja unlocks),
	# no de card.buildings (que puede estar desincronizado en el snapshot).
	for id in state.tiles:
		var t := state.tiles[id] as AIRealState.TileSnap
		if t.owner != p_owner:
			continue
		for building in emp.possible_buildings:
			if building == null:
				continue
			if AIRealSimulator._effective_build_cost(building, emp) > emp.gold:
				continue
			if not t.can_build(building):
				continue
			var m := Move.new()
			m.kind = &"BUILD"
			m.card = card
			m.tile_id = id
			m.building = building
			moves.append(m)


static func _add_direct_build(moves: Array, state: AIRealState, card: DirectBuildCard,
		emp: AIRealState.EmpireSnap, p_owner: int) -> void:
	if card.buildings.is_empty() or card.buildings[0] == null:
		return
	var building := card.buildings[0]
	for id in state.tiles:
		var t := state.tiles[id] as AIRealState.TileSnap
		if t.owner != p_owner:
			continue
		if AIRealSimulator._effective_build_cost(building, emp) > emp.gold:
			continue
		if not t.can_build(building):
			continue
		var m := Move.new()
		m.kind = &"DIRECT_BUILD"
		m.card = card
		m.tile_id = id
		m.building = building
		moves.append(m)


static func _add_upgrade(moves: Array, state: AIRealState, card: UpgradeBuildingCard,
		emp: AIRealState.EmpireSnap, p_owner: int) -> void:
	for id in state.tiles:
		var t := state.tiles[id] as AIRealState.TileSnap
		if t.owner != p_owner:
			continue
		for old_b in t.buildings:
			if old_b == null:
				continue
			for new_b in old_b.upgrades_to:
				if new_b == null:
					continue
				if AIRealSimulator._effective_build_cost(new_b, emp) > emp.gold:
					continue
				if not _can_upgrade(t, old_b, new_b):
					continue
				var m := Move.new()
				m.kind = &"UPGRADE"
				m.card = card
				m.tile_id = id
				m.old_building = old_b
				m.new_building = new_b
				moves.append(m)


static func _add_change_location(moves: Array, state: AIRealState,
		card: ChangeLocationTypeCard, emp: AIRealState.EmpireSnap, p_owner: int) -> void:
	if card.location_type == null:
		return
	var target := card.location_type
	for id in state.tiles:
		var t := state.tiles[id] as AIRealState.TileSnap
		if t.owner != p_owner:
			continue
		if t.location_type + 1 != target.type:
			continue
		if emp.food < target.food_consumption:
			continue
		var m := Move.new()
		m.kind = &"CHANGE_LOCATION"
		m.card = card
		m.tile_id = id
		m.location = target
		moves.append(m)


static func _add_generate_gold(moves: Array, card: GenerateGoldCard) -> void:
	var m := Move.new()
	m.kind = &"GENERATE_GOLD"
	m.card = card
	m.amount = card.amount
	moves.append(m)


static func _add_card_draw(moves: Array, card: CardDrawCard) -> void:
	var m := Move.new()
	m.kind = &"CARD_DRAW"
	m.card = card
	m.amount = card.amount
	moves.append(m)


static func _add_recruit(moves: Array, card: RecruitCard,
		emp: AIRealState.EmpireSnap, p_owner: int) -> void:
	if card.available_troops.is_empty():
		return
	for troop in card.available_troops:
		if troop == null:
			continue
		if not _can_afford_troop(emp, troop):
			continue
		var per_play := _troops_per_play(card, troop, emp)
		if emp.gold < troop.recruitment_cost_gold * per_play:
			continue
		var m := Move.new()
		m.kind = &"RECRUIT"
		m.card = card
		m.troop = troop
		m.troop_count = per_play
		moves.append(m)


static func _add_open_front(moves: Array, state: AIRealState, card: OpenFrontCard,
		p_owner: int) -> void:
	if AIRealSimulator._active_front_count(state, p_owner) \
			>= AIRealSimulator._get_max_fronts(state, p_owner):
		return
	var enemy := AIRealState.OWNER_RIVAL if p_owner == AIRealState.OWNER_SELF \
		else AIRealState.OWNER_SELF
	for id in state.tiles:
		var t := state.tiles[id] as AIRealState.TileSnap
		if t.owner != p_owner or _tile_in_front(state, id):
			continue
		for nid in t.neighbor_ids:
			var nb := state.tiles.get(nid) as AIRealState.TileSnap
			if nb == null or nb.owner != enemy or _tile_in_front(state, nid):
				continue
			var m := Move.new()
			m.kind = &"OPEN_FRONT"
			m.card = card
			m.tile_id = id
			m.def_tile_id = nid
			moves.append(m)


static func _add_tactic(moves: Array, state: AIRealState, card: TacticCard,
		p_owner: int) -> void:
	for i in range(state.fronts.size()):
		var front := state.fronts[i] as AIRealState.FrontSnap
		if front.is_resolved or front.side_of(p_owner) == &"":
			continue
		var m := Move.new()
		m.kind = &"TACTIC"
		m.card = card
		m.front_idx = i
		moves.append(m)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Espejo de Tile.can_upgrade (sin la comprobación de coste, que se filtra aparte).
static func _can_upgrade(t: AIRealState.TileSnap, old_b: Building, new_b: Building) -> bool:
	if new_b not in old_b.upgrades_to:
		return false
	if not new_b.allowed_biomes.is_empty() and t.biome not in new_b.allowed_biomes:
		return false
	if new_b.required_natural_resource != null \
			and t.natural_resource != new_b.required_natural_resource:
		return false
	if not new_b.allowed_location_type.is_empty():
		var fits := false
		for lt in new_b.allowed_location_type:
			if lt.type == t.location_type:
				fits = true
				break
		if not fits:
			return false
	return true


## Espejo de Stats.can_afford_troop sobre el snapshot.
static func _can_afford_troop(emp: AIRealState.EmpireSnap, troop: Troop) -> bool:
	if emp.gold < troop.recruitment_cost_gold:
		return false
	if emp.gold_per_turn - troop.maintenance_gold < 0:
		return false
	if emp.food - troop.maintenance_food < 0:
		return false
	return true


## Tropas por play efectivas (espejo de RecruitCard.get_effective_troops_per_play).
static func _troops_per_play(card: RecruitCard, troop: Troop,
		emp: AIRealState.EmpireSnap) -> int:
	var bonus := 0
	for mod in emp.modifiers:
		if mod is StatModifier \
				and (mod as StatModifier).type == StatModifier.StatType.TROOPS_PER_RECRUIT \
				and (mod as StatModifier).applies_to_troop(troop):
			bonus += int((mod as StatModifier).value)
	return maxi(1, card.base_troops_per_play + bonus)


static func _tile_in_front(state: AIRealState, tile_id: int) -> bool:
	for f in state.fronts:
		var front := f as AIRealState.FrontSnap
		if front.is_resolved:
			continue
		if front.attacker_tile_id == tile_id or front.defender_tile_id == tile_id:
			return true
	return false
