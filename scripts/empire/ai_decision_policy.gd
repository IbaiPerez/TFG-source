extends RefCounted
class_name AIDecisionPolicy

## Elige QUÉ jugada hace la IA en cada iteración del turno, según el modo de
## AIConfig:
##   - MCTS (por defecto): SO-ISMCTS sobre un estado real determinizado
##     (AIRealState), con la heurística fuerte como prior/poda en la raíz y
##     reutilización de subárbol intra-turno (warm start).
##   - HEURISTIC: puntúa cada opción con AIHeuristic.score_option y elige la
##     mejor. Es también el fallback cuando el MCTS degenera.
##   - RANDOM: una opción legal al azar; rival de referencia débil para el
##     fitness del optimizador de pesos.
## En los tres casos la opción "no jugar nada" (PASS) compite como una más.
##
## Vive aparte de AIController porque son dos cosas distintas: el controller
## ORQUESTA el turno (robar, esperar, descartar, cerrar) y esto DECIDE. Además
## aquí está el estado que sobrevive entre decisiones del mismo turno (el
## subárbol conservado) y los contadores de diagnóstico que lee el arnés.

var _rng: RandomNumberGenerator

## Diagnóstico MCTS (acumulado durante la partida): nº de decisiones tomadas con
## MCTS y de cuántas la búsqueda se apartó del prior heurístico (overrode_prior).
## El harness de simulación los lee al final para medir la tasa de "override".
var mcts_decisions: int = 0
var mcts_prior_overrides: int = 0
## Iteraciones MCTS acumuladas: `mcts_total_iterations` = cómputo real gastado
## (iteraciones NUEVAS por decisión); `mcts_total_root_visits` = visitas totales en
## la raíz de cada búsqueda, que con reutilización de subárbol INCLUYE el warm start
## heredado. El ratio root_visits/iterations > 1 mide cuánto aporta la persistencia.
var mcts_total_iterations: int = 0
var mcts_total_root_visits: int = 0

## Subárbol MCTS conservado entre decisiones del MISMO turno (tree persistence —
## una de las fortalezas de MCTS). Tras jugar una carta se re-enraíza en el hijo
## de la jugada elegida, así la siguiente decisión reutiliza las visitas/valor ya
## calculados (warm start) en vez de empezar el árbol de cero. Se descarta (null)
## al empezar cada turno y cuando el árbol deja de ser válido (PASS, fallback a
## heurística, o jugada sin opción real correspondiente).
var _mcts_root: AIRealMCTSNode = null


func _init(p_rng: RandomNumberGenerator) -> void:
	_rng = p_rng


## Nuevo turno: el árbol de turnos anteriores ya no es válido (intervinieron el
## rival y advance_turn). La reutilización de subárbol es SOLO intra-turno.
func reset_tree() -> void:
	_mcts_root = null


func enumerate_all_options(ctx: AITurnContext) -> Array[AIPlayOption]:
	var all: Array[AIPlayOption] = []
	for card in ctx.drawn_cards:
		all.append_array(AIOptionsBuilder.build_options(card, ctx))
	return all


func pick_best(options: Array[AIPlayOption], ctx: AITurnContext) -> AIPlayOption:
	if options.is_empty():
		return null
	var cfg := ctx.config
	if cfg != null and cfg.mode == AIConfig.Mode.RANDOM:
		# Política aleatoria: una opción legal al azar (incluye PASS). Rival de
		# referencia débil para el fitness del optimizador; usa ctx.rng para que
		# la partida siga siendo determinista con seed fijo.
		return options[ctx.rng.randi_range(0, options.size() - 1)]
	if cfg != null and cfg.mode == AIConfig.Mode.MCTS:
		var picked := _pick_best_option_mcts(options, ctx, cfg)
		# Si MCTS no devuelve jugada (sin acciones modelables), caemos a heurística.
		if picked != null:
			return picked
	return _pick_best_option_heuristic(options, ctx)


## Decisión por MCTS (SO-ISMCTS sobre estado real). Construye el
## snapshot rico desde el contexto, busca con AIRealMCTS, y mapea la jugada
## elegida (snapshot) a la AIPlayOption real ejecutable. Devuelve:
##   - la AIPlayOption mapeada,
##   - una PASS si la búsqueda decidió pasar (cierra el turno),
##   - null si la búsqueda degeneró o la jugada no tiene opción real
##     correspondiente → el llamante cae a la heurística.
func _pick_best_option_mcts(options: Array[AIPlayOption], ctx: AITurnContext,
		cfg: AIConfig) -> AIPlayOption:
	var state := AIRealState.from_context(ctx)

	# Determinización del rival (SO-ISMCTS): deck conocido + tamaño de mano.
	var known_deck: Array[Card] = []
	var rival_hand_size := 2
	if ctx.world_view != null:
		var rival_view := ctx.world_view.get_rival_view()
		if rival_view != null:
			known_deck = AIDeterminizer.build_known_deck(rival_view, ctx.deck_observer)
			rival_hand_size = rival_view.hand_size

	# Prior HÍBRIDO de la raíz: puntuamos las jugadas reales con la heurística
	# REAL (score_option sobre el ctx real, con la caché ya preparada) y las
	# indexamos por move_key para que la raíz del MCTS use la heurística fuerte
	# como prior/poda, no la aproximación score_move.
	# Frentes activos en el mismo orden que from_context (para casar TACTIC). Se
	# calculan UNA vez por decisión, no por jugada.
	var active_fronts: Array = []
	for f in ctx.get_front_registry().get_active_instances():
		if f != null and not f.is_resolved:
			active_fronts.append(f)

	var root_priors := {}
	for m in AIRealOptions.enumerate(state, ctx.drawn_cards, AIRealState.OWNER_SELF):
		var opt := _map_move_to_option(m, options, ctx, active_fronts)
		if opt != null:
			root_priors[AIRealMCTSNode.move_key(m)] = AIHeuristic.score_option(opt, ctx)

	# Reutilización de subárbol: pasamos el árbol conservado de la decisión
	# anterior de este turno (null en la primera decisión) como warm start.
	var result := AIRealMCTS.search(state, ctx.drawn_cards, known_deck,
		rival_hand_size, cfg, _rng, root_priors, _mcts_root)
	# Diagnóstico: contar decisiones y cuántas se apartan del prior heurístico.
	mcts_decisions += 1
	mcts_total_iterations += result.iterations
	mcts_total_root_visits += result.root_visits
	if result.overrode_prior:
		mcts_prior_overrides += 1

	# Por defecto el árbol queda invalidado; solo se conserva en el camino feliz
	# (MCTS eligió una jugada con opción real ejecutable, distinta de PASS).
	_mcts_root = null

	if result.best_move == null:
		return null   # búsqueda degenerada → heurística
	if result.chose_pass:
		return AIPlayOption.create_pass()

	var picked := _map_move_to_option(result.best_move, options, ctx, active_fronts)
	if picked == null:
		return null   # jugada sin opción real correspondiente → heurística

	# La jugada elegida se EJECUTARÁ a continuación en _run_turn(): conservamos su
	# subárbol como raíz para la próxima decisión de este turno (warm start con las
	# visitas/valor ya acumulados bajo esa jugada).
	_mcts_root = result.best_child

	GameLogger.debug("[IA] MCTS-v2: %d iters · raíz %d/%d · Q=%.3f → %s" % [
		result.iterations, result.root_visits, result.root_children,
		result.best_avg_value, picked.describe()])
	return picked


## Mapea una jugada del snapshot (AIRealOptions.Move) a la AIPlayOption real
## equivalente entre las opciones legales del turno, casando por carta + target
## (índice de tile en WorldMap.map, igual que AIRealState.from_context). Devuelve
## null si ninguna casa (el llamante cae a la heurística).
## `active_fronts` y `ctx` los aporta el llamante para no recalcularlos por jugada:
## antes cada llamada duplicaba el registro global de frentes y resolvía
## cada tile con un find O(n) sobre WorldMap.map.
func _map_move_to_option(m: AIRealOptions.Move,
		options: Array[AIPlayOption], ctx: AITurnContext,
		active_fronts: Array) -> AIPlayOption:
	for opt in options:
		if opt == null or opt.is_pass or opt.card != m.card:
			continue
		match m.kind:
			&"COLONIZE", &"CHANGE_LOCATION":
				if ctx.index_of_tile(opt.anchor_tile()) == m.tile_id:
					return opt
			&"GENERATE_GOLD", &"CARD_DRAW":
				return opt   # sin target: basta la identidad de carta
			&"BUILD", &"DIRECT_BUILD":
				var bo := opt as AIBuildOption
				if bo != null and bo.building == m.building \
						and ctx.index_of_tile(opt.anchor_tile()) == m.tile_id:
					return opt
			&"UPGRADE":
				var uo := opt as AIUpgradeBuildingOption
				if uo != null and uo.old_building == m.old_building \
						and uo.new_building == m.new_building \
						and ctx.index_of_tile(opt.anchor_tile()) == m.tile_id:
					return opt
			&"RECRUIT":
				var ro := opt as AIRecruitOption
				if ro != null and ro.troop == m.troop:
					return opt
			&"OPEN_FRONT":
				var ofo := opt as AIOpenFrontOption
				if ofo != null and ctx.index_of_tile(ofo.enemy_tile) == m.def_tile_id \
						and ctx.index_of_tile(ofo.source_tile) == m.tile_id:
					return opt
			&"TACTIC":
				var to := opt as AITacticOption
				if to != null and m.front_idx >= 0 and m.front_idx < active_fronts.size() \
						and to.front == active_fronts[m.front_idx]:
					return opt
	return null



## Decisión por heurística pura. También es el fallback de MCTS.
func _pick_best_option_heuristic(options: Array[AIPlayOption],
		ctx: AITurnContext) -> AIPlayOption:
	var best: AIPlayOption = null
	var best_score := -INF
	for option in options:
		var s := AIHeuristic.score_option(option, ctx)
		if s > best_score:
			best_score = s
			best = option
	return best
