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
	# Vista compartida para los enumeradores portados a AILegality (§1.4). Sin pesos
	# (la enumeración solo usa legalidad).
	var view := SnapshotStateView.new(state, p_owner)
	for card in hand:
		if card == null:
			continue
		if card is DirectBuildCard:
			_add_direct_build(moves, view, card as DirectBuildCard)
		elif card is UpgradeBuildingCard:
			_add_upgrade(moves, view, card as UpgradeBuildingCard)
		elif card is BuildCard:
			_add_build(moves, view, emp.possible_buildings, card as BuildCard)
		elif card is ColonizeCard:
			_add_colonize(moves, view, card as ColonizeCard)
		elif card is ChangeLocationTypeCard:
			_add_change_location(moves, view, card as ChangeLocationTypeCard)
		elif card is GenerateGoldCard:
			_add_generate_gold(moves, card as GenerateGoldCard)
		elif card is CardDrawCard:
			_add_card_draw(moves, card as CardDrawCard)
		elif card is RecruitCard:
			_add_recruit(moves, view, card as RecruitCard)
		elif card is OpenFrontCard:
			_add_open_front(moves, view, card as OpenFrontCard)
		elif card is TacticCard:
			_add_tactic(moves, view, card as TacticCard)
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

static func _add_colonize(moves: Array, view: SnapshotStateView, card: ColonizeCard) -> void:
	# Legalidad unificada (§1.4): view.colonizable_tiles() (recorrido propio→vecinos libres).
	for tsnap in view.colonizable_tiles():
		var m := Move.new()
		m.kind = &"COLONIZE"
		m.card = card
		m.tile_id = (tsnap as AIRealState.TileSnap).id
		moves.append(m)


## BUILD: legalidad unificada (§1.4). `buildings` = emp.possible_buildings (refleja
## unlocks; divergencia con card.buildings del vivo, aislada aquí en el llamante).
static func _add_build(moves: Array, view: SnapshotStateView,
		buildings: Array[Building], card: BuildCard) -> void:
	for t in AILegality.build_targets(view, buildings):
		var m := Move.new()
		m.kind = &"BUILD"
		m.card = card
		m.tile_id = (t["tile"] as AIRealState.TileSnap).id
		m.building = t["building"]
		moves.append(m)


static func _add_direct_build(moves: Array, view: SnapshotStateView,
		card: DirectBuildCard) -> void:
	if card.buildings.is_empty() or card.buildings[0] == null:
		return
	# DIRECT_BUILD: un solo edificio (buildings[0]) sobre el mismo generador que BUILD.
	var singleton: Array[Building] = [card.buildings[0]]
	for t in AILegality.build_targets(view, singleton):
		var m := Move.new()
		m.kind = &"DIRECT_BUILD"
		m.card = card
		m.tile_id = (t["tile"] as AIRealState.TileSnap).id
		m.building = t["building"]
		moves.append(m)


static func _add_upgrade(moves: Array, view: SnapshotStateView,
		card: UpgradeBuildingCard) -> void:
	for t in AILegality.upgrade_targets(view):
		var m := Move.new()
		m.kind = &"UPGRADE"
		m.card = card
		m.tile_id = (t["tile"] as AIRealState.TileSnap).id
		m.old_building = t["old"]
		m.new_building = t["new"]
		moves.append(m)


static func _add_change_location(moves: Array, view: SnapshotStateView,
		card: ChangeLocationTypeCard) -> void:
	if card.location_type == null:
		return
	# Legalidad unificada (§1.4): AILegality.change_location_targets.
	for tsnap in AILegality.change_location_targets(view, card.location_type):
		var m := Move.new()
		m.kind = &"CHANGE_LOCATION"
		m.card = card
		m.tile_id = (tsnap as AIRealState.TileSnap).id
		m.location = card.location_type
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


static func _add_recruit(moves: Array, view: SnapshotStateView, card: RecruitCard) -> void:
	# Legalidad unificada (§1.4): AILegality.recruit_targets sobre la vista del snapshot.
	for t in AILegality.recruit_targets(view, card):
		var m := Move.new()
		m.kind = &"RECRUIT"
		m.card = card
		m.troop = t["troop"]
		m.troop_count = t["per_play"]
		moves.append(m)


static func _add_open_front(moves: Array, view: SnapshotStateView, card: OpenFrontCard) -> void:
	# Legalidad unificada (§1.4): view.open_front_pairs (recorrido propia→enemiga).
	for pair in view.open_front_pairs(card):
		var m := Move.new()
		m.kind = &"OPEN_FRONT"
		m.card = card
		m.tile_id = (pair["source"] as AIRealState.TileSnap).id
		m.def_tile_id = (pair["def"] as AIRealState.TileSnap).id
		moves.append(m)


static func _add_tactic(moves: Array, view: SnapshotStateView, card: TacticCard) -> void:
	# Legalidad unificada (§1.4): view.tactic_targets() (índices de frentes elegibles).
	for idx in view.tactic_targets():
		var m := Move.new()
		m.kind = &"TACTIC"
		m.card = card
		m.front_idx = idx
		moves.append(m)
