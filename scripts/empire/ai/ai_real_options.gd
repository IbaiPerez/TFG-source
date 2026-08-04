extends RefCounted
class_name AIRealOptions

## Enumeración y aplicación de jugadas (carta + TARGET) sobre AIRealState para la
## búsqueda MCTS. Comparte las reglas de legalidad con el mundo vivo (AILegality y
## los métodos de la vista); lo propio de este módulo es TRADUCIR cada objetivo
## legal a un Move por colocación concreta (qué carta, dónde), que es justo lo que
## el árbol ramifica: la fuerza del MCTS está en decidir DÓNDE.
##
## Cada Move es aplicable con `apply()`, que delega en AIRealSimulator /
## AIRealEvents. No toca escena ni señales (datos puros).
##
## Cobertura: Colonize, Build, DirectBuild, Upgrade, ChangeLocation, GenerateGold,
## CardDraw, Recruit, OpenFront, Tactic. Recover se omite (el snapshot no modela
## played_pile); CardDraw muta la mano del turno, que gestiona el árbol.


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


## Dispatcher por tipo de carta: Script → Callable resuelto SUBIENDO por la cadena de
## herencia (DirectBuildCard antes que BuildCard por tipo exacto, sin depender del
## orden de una cadena de `if`). RecoverCard no tiene handler → omitida (sin
## played_pile en el snapshot). Todos los handlers comparten firma (moves, view, card).
static var _handlers: Dictionary = {}


static func _ensure_handlers() -> void:
	if not _handlers.is_empty():
		return
	_handlers[DirectBuildCard]        = Callable(AIRealOptions, "_add_direct_build")
	_handlers[UpgradeBuildingCard]    = Callable(AIRealOptions, "_add_upgrade")
	_handlers[BuildCard]              = Callable(AIRealOptions, "_add_build")
	_handlers[ColonizeCard]           = Callable(AIRealOptions, "_add_colonize")
	_handlers[ChangeLocationTypeCard] = Callable(AIRealOptions, "_add_change_location")
	_handlers[GenerateGoldCard]       = Callable(AIRealOptions, "_add_generate_gold")
	_handlers[CardDrawCard]           = Callable(AIRealOptions, "_add_card_draw")
	_handlers[RecruitCard]            = Callable(AIRealOptions, "_add_recruit")
	_handlers[OpenFrontCard]          = Callable(AIRealOptions, "_add_open_front")
	_handlers[TacticCard]             = Callable(AIRealOptions, "_add_tactic")


## Enumera todas las jugadas legales de `hand` sobre el estado, desde la
## perspectiva de `p_owner`. Mirror de AIOptionsBuilder sobre el snapshot.
static func enumerate(state: AIRealState, hand: Array[Card],
		p_owner: int = AIRealState.OWNER_SELF) -> Array:
	var moves: Array = []
	var emp := state.own if p_owner == AIRealState.OWNER_SELF else state.rival
	if emp == null:
		return moves
	# Vista compartida para toda la enumeración. Sin pesos (solo legalidad).
	var view := SnapshotStateView.new(state, p_owner)
	_ensure_handlers()
	for card in hand:
		if card == null:
			continue
		var script := card.get_script() as Script
		while script != null:
			if _handlers.has(script):
				(_handlers[script] as Callable).call(moves, view, card)
				break
			script = script.get_base_script()
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
# Constructores por tipo de carta: objetivo legal → Move
# ---------------------------------------------------------------------------

static func _add_colonize(moves: Array, view: SnapshotStateView, card: ColonizeCard) -> void:
	# Legalidad unificada: view.colonizable_tiles() (recorrido propio→vecinos libres).
	for tsnap in view.colonizable_tiles():
		var m := Move.new()
		m.kind = &"COLONIZE"
		m.card = card
		m.tile_id = (tsnap as AIRealState.TileSnap).id
		moves.append(m)


## BUILD: legalidad unificada. La fuente de edificios del snapshot es
## view.possible_buildings() (refleja unlocks; divergencia con card.buildings del vivo).
static func _add_build(moves: Array, view: SnapshotStateView, card: BuildCard) -> void:
	for t in AILegality.build_targets(view, view.possible_buildings()):
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
	# Legalidad unificada: AILegality.change_location_targets.
	for tsnap in AILegality.change_location_targets(view, card.location_type):
		var m := Move.new()
		m.kind = &"CHANGE_LOCATION"
		m.card = card
		m.tile_id = (tsnap as AIRealState.TileSnap).id
		m.location = card.location_type
		moves.append(m)


static func _add_generate_gold(moves: Array, _view: SnapshotStateView,
		card: GenerateGoldCard) -> void:
	var m := Move.new()
	m.kind = &"GENERATE_GOLD"
	m.card = card
	m.amount = card.amount
	moves.append(m)


static func _add_card_draw(moves: Array, _view: SnapshotStateView,
		card: CardDrawCard) -> void:
	var m := Move.new()
	m.kind = &"CARD_DRAW"
	m.card = card
	m.amount = card.amount
	moves.append(m)


static func _add_recruit(moves: Array, view: SnapshotStateView, card: RecruitCard) -> void:
	# Legalidad unificada: AILegality.recruit_targets sobre la vista del snapshot.
	for t in AILegality.recruit_targets(view, card):
		var m := Move.new()
		m.kind = &"RECRUIT"
		m.card = card
		m.troop = t["troop"]
		m.troop_count = t["per_play"]
		moves.append(m)


static func _add_open_front(moves: Array, view: SnapshotStateView, card: OpenFrontCard) -> void:
	# Legalidad unificada: view.open_front_pairs (recorrido propia→enemiga).
	for pair in view.open_front_pairs(card):
		var m := Move.new()
		m.kind = &"OPEN_FRONT"
		m.card = card
		m.tile_id = (pair["source"] as AIRealState.TileSnap).id
		m.def_tile_id = (pair["def"] as AIRealState.TileSnap).id
		moves.append(m)


static func _add_tactic(moves: Array, view: SnapshotStateView, card: TacticCard) -> void:
	# Legalidad unificada: view.tactic_targets() (índices de frentes elegibles).
	for idx in view.tactic_targets():
		var m := Move.new()
		m.kind = &"TACTIC"
		m.card = card
		m.front_idx = idx
		moves.append(m)
