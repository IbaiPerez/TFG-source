extends RefCounted
class_name AIGameState

## Snapshot liviano del estado del juego para rollouts MCTS (Fase C).
##
## Solo contiene datos escalares — sin referencias a nodos de escena,
## señales ni efectos secundarios. Se puede clonar en O(deck_size).
##
## El estado captura dos perspectivas:
##   own_*   → IA que ejecuta el MCTS (acceso completo a sus datos)
##   rival_* → oponente (solo info pública observable)
##
## Limitaciones documentadas (ampliables en iteraciones futuras):
##   - buildable_slots es una estimación (requiere ctx con cache preparada)
##   - rival_troop_power solo incluye tropas visibles en frentes activos
##   - Los modificadores activos no se propagan a las simulaciones futuras


## Snapshot de un frente activo desde la perspectiva propia.
class FrontSnapshot:
	var own_side: BattleFront.Side    ## BattleFront.Side.ATTACKER o BattleFront.Side.DEFENDER
	var marker: float
	var threshold: float

	static func of(p_side: BattleFront.Side, p_marker: float, p_threshold: float) -> FrontSnapshot:
		var f := AIGameState.FrontSnapshot.new()
		f.own_side = p_side
		f.marker = p_marker
		f.threshold = p_threshold
		return f

	func clone() -> FrontSnapshot:
		return AIGameState.FrontSnapshot.of(own_side, marker, threshold)


# ── Propio ───────────────────────────────────────────────────────────────────
var own_tiles: int = 0
var own_gold: int = 0
var own_gold_per_turn: int = 0
var own_food: int = 0
var own_troop_power: float = 0.0   ## sum(atk+def) del troop_pool completo
var own_cards_per_turn: int = 2    ## base sin modificadores
var own_hand: Array[Card] = []     ## cartas en mano este turno
var own_deck: Array[Card] = []     ## draw+discard propios para draws simuladas

# ── Rival (información pública) ──────────────────────────────────────────────
var rival_tiles: int = 0
var rival_gold_per_turn: int = 0
var rival_hand_size: int = 2
var rival_troop_power: float = 0.0  ## tropas visibles en frentes activos

# ── Contexto del mapa ────────────────────────────────────────────────────────
var turn_number: int = 0
var total_map_tiles: int = 0
var colonizable_count: int = 0     ## tiles adyacentes sin controller disponibles
var buildable_slots: int = 0       ## tiles propias con al menos un slot libre
var fronts: Array = []             ## Array[FrontSnapshot] — frentes en los que participamos


## Construye el estado inicial desde el AITurnContext del turno real.
## Llamar AIHeuristic.prepare_decision_cache(ctx) antes para que
## buildable_slots y colonizable_count tengan datos precisos.
static func from_context(ctx: AITurnContext) -> AIGameState:
	var s := AIGameState.new()
	var stats: Stats = ctx.stats

	# ── Propio ───────────────────────────────────────────────────────────────
	if stats.empire != null:
		s.own_tiles = stats.empire.controlled_tiles.size()
	s.own_gold = stats.total_gold
	s.own_gold_per_turn = stats.gold_per_turn
	s.own_food = stats.food
	s.own_cards_per_turn = stats.cards_per_turn
	s.own_hand = ctx.drawn_cards.duplicate()
	if stats.draw_pile != null:
		s.own_deck = stats.draw_pile.cards.duplicate()
	if stats.discard_pile != null:
		for c in stats.discard_pile.cards:
			s.own_deck.append(c)
	for t in stats.troop_pool:
		s.own_troop_power += float(t.attack + t.defense)

	# ── Rival ─────────────────────────────────────────────────────────────────
	var rival: AIEmpirePublicView = null
	if ctx.world_view != null:
		rival = ctx.world_view.get_rival_view()
	if rival != null:
		if rival.empire != null:
			s.rival_tiles = rival.empire.controlled_tiles.size()
		s.rival_gold_per_turn = rival.gold_per_turn
		s.rival_hand_size = rival.hand_size
		if rival.empire != null:
			for front in BattleFront.get_active_instances():
				if front == null or front.is_resolved:
					continue
				if front.attacker_empire != rival.empire \
						and front.defender_empire != rival.empire:
					continue
				var rt: Array[Troop] = front.attacker_troops \
					if front.attacker_empire == rival.empire else front.defender_troops
				for t in rt:
					s.rival_troop_power += float(t.attack + t.defense)

	# ── Contexto ──────────────────────────────────────────────────────────────
	s.turn_number = stats.turn_number
	s.total_map_tiles = ctx.total_map_tiles
	s.colonizable_count = maxi(0, ctx.colonizable_tiles_count)
	s.buildable_slots = ctx._cache_buildable_slots if ctx._cache_valid else 0

	# ── Frentes propios ───────────────────────────────────────────────────────
	if stats.empire != null:
		for front in BattleFront.get_active_instances():
			if front == null or front.is_resolved:
				continue
			var side: BattleFront.Side
			if front.attacker_empire == stats.empire:
				side = BattleFront.Side.ATTACKER
			elif front.defender_empire == stats.empire:
				side = BattleFront.Side.DEFENDER
			else:
				continue
			s.fronts.append(
				FrontSnapshot.of(side, front.marker, front.get_current_threshold()))

	return s


## Copia profunda. O(deck_size + fronts_count).
## Los Card en own_hand/own_deck son recursos compartidos (no se clonan):
## solo se copian las referencias, lo que es correcto pues no los mutamos.
func clone() -> AIGameState:
	var c := AIGameState.new()
	c.own_tiles          = own_tiles
	c.own_gold           = own_gold
	c.own_gold_per_turn  = own_gold_per_turn
	c.own_food           = own_food
	c.own_troop_power    = own_troop_power
	c.own_cards_per_turn = own_cards_per_turn
	c.own_hand           = own_hand.duplicate()
	c.own_deck           = own_deck.duplicate()
	c.rival_tiles        = rival_tiles
	c.rival_gold_per_turn = rival_gold_per_turn
	c.rival_hand_size    = rival_hand_size
	c.rival_troop_power  = rival_troop_power
	c.turn_number        = turn_number
	c.total_map_tiles    = total_map_tiles
	c.colonizable_count  = colonizable_count
	c.buildable_slots    = buildable_slots
	for f in fronts:
		c.fronts.append((f as FrontSnapshot).clone())
	return c
