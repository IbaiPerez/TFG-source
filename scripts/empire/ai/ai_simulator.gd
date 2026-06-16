extends RefCounted
class_name AISimulator

## Motor de simulación headless para rollouts MCTS (Fase C).
##
## Opera exclusivamente sobre AIGameState — sin efectos secundarios,
## sin señales, sin referencias a nodos de escena.
## Todas las funciones son estáticas.
##
## Simplificaciones documentadas (ampliables en iteraciones futuras):
##   - simulate_turn() modela efectos de cartas con estimaciones fijas.
##     Los valores concretos (coste de edificio, potencia de tropa) son
##     promedios calibrados sobre los recursos del juego; no se lee el
##     .tres de cada carta individual durante la simulación.
##   - Los turnos del rival se simulan solo con ingresos, sin acciones
##     de cartas (decisión "Solo turno propio" del PLAN_IA_COMPLETO §2.4).
##   - El mazo se trata como circular (la misma carta puede aparecer en
##     manos sucesivas simuladas). Razonable para rollouts de 2-4 turnos.


# ---------------------------------------------------------------------------
# Evaluación y condición terminal
# ---------------------------------------------------------------------------

## Evalúa el estado desde la perspectiva de la propia IA.
## Retorna [-1.0, 1.0] via tanh (mirrors AIHeuristic.score_state).
## +1.0 = victoria segura · -1.0 = derrota segura.
static func evaluate(state: AIGameState) -> float:
	var total := maxi(state.total_map_tiles,
		state.own_tiles + state.rival_tiles + 1)
	var own_share   := float(state.own_tiles)   / float(total)
	var rival_share := float(state.rival_tiles) / float(total)

	# Condiciones terminales
	if own_share   >= 0.70: return  1.0
	if rival_share >= 0.70: return -1.0
	if state.rival_tiles == 0: return  1.0
	if state.own_tiles   == 0: return -1.0

	# Fase simplificada (sin Stats real)
	var late  := own_share >= 0.30 or state.own_gold_per_turn >= 350
	var early := own_share < 0.08  and state.own_gold_per_turn < 100

	var w_t := 0.40; var w_e := 0.40; var w_m := 0.15; var w_k := 0.05
	if late:
		w_t = 0.30; w_e = 0.20; w_m = 0.40; w_k = 0.10
	elif not early:
		w_t = 0.30; w_e = 0.35; w_m = 0.25; w_k = 0.10

	var t_score := (own_share - rival_share) / 0.70
	var e_score := clampf(
		float(state.own_gold_per_turn - state.rival_gold_per_turn) / 1000.0, -1.0, 1.0)
	var food_stability := clampf(float(state.own_food) / 20.0, -1.0, 0.5)
	# Dimensión militar: poder de tropas + ventaja en frentes activos. Sin el
	# término de frentes, evaluate ignora Tactic/OpenFront y el MCTS no los usa.
	# front_advantage ≈ suma de progreso por frente (cada frente casi resuelto
	# vale ~±1 swing territorial), de modo que avanzar marcadores sube el valor.
	var m_score := clampf(
		(state.own_troop_power - state.rival_troop_power) / 100.0
		+ _front_advantage(state) * 0.4, -1.0, 1.0)
	var k_score := clampf(
		float(state.own_cards_per_turn - state.rival_hand_size) / 5.0, -1.0, 1.0)

	var raw := w_t * t_score \
			 + w_e * (e_score + food_stability * 0.3) \
			 + w_m * m_score \
			 + w_k * k_score
	return tanh(raw * 2.0)


## Ventaja propia agregada en frentes activos (en "tiles esperados").
## Para cada frente: +1 si lo tenemos ganado, -1 si lo perdemos, escalado por
## la posición del marcador respecto al umbral. Atacante gana con marker>0;
## defensor gana con marker<0.
static func _front_advantage(state: AIGameState) -> float:
	var sum := 0.0
	for f in state.fronts:
		var snap := f as AIGameState.FrontSnapshot
		var our_marker := snap.marker if snap.own_side == &"attacker" else -snap.marker
		sum += clampf(our_marker / maxf(snap.threshold, 1.0), -1.0, 1.0)
	return sum


## True si el estado es terminal (victoria o derrota determinadas).
static func is_terminal(state: AIGameState) -> bool:
	if state.total_map_tiles <= 0:
		return false
	var total := float(state.total_map_tiles)
	if float(state.own_tiles)   / total >= 0.70: return true
	if float(state.rival_tiles) / total >= 0.70: return true
	return state.own_tiles == 0 or state.rival_tiles == 0


# ---------------------------------------------------------------------------
# Simulación de turno
# ---------------------------------------------------------------------------

## Simula un turno propio sobre una copia del estado dado.
## El estado original no se modifica.
##
## use_heuristic=true  → política greedy por score abstracto (más fuerte)
## use_heuristic=false → política aleatoria (útil para benchmarking puro)
static func simulate_turn(state: AIGameState, use_heuristic: bool,
		rng: RandomNumberGenerator) -> AIGameState:
	var s := state.clone()

	# Ingresos propios del turno
	s.own_gold += s.own_gold_per_turn
	s.turn_number += 1

	# Fase de cartas propia con una mano sampleada del deck.
	var hand := _draw_hand(s, rng)
	_play_card_phase(s, hand, use_heuristic, rng)
	return s


## Aplica la fase de cartas (bucle de juego de opciones) sobre `s` con la mano
## `hand` dada, SIN añadir ingresos. Pensado para terminar la mano real del
## turno en curso durante un rollout MCTS (los ingresos ya están aplicados en
## el estado raíz). Muta `s` y devuelve la misma referencia por comodidad.
static func play_hand(s: AIGameState, hand: Array[Card], use_heuristic: bool,
		rng: RandomNumberGenerator) -> AIGameState:
	_play_card_phase(s, hand.duplicate(), use_heuristic, rng)
	return s


## Bucle interno de juego de opciones. Muta `s` y consume `hand` (por valor:
## el llamante pasa una copia si quiere conservarla).
## Tope duro de jugadas: CardDraw añade cartas a la mano (tempo) y el mazo es
## circular, así que sin tope podría no terminar.
static func _play_card_phase(s: AIGameState, hand: Array[Card],
		use_heuristic: bool, rng: RandomNumberGenerator) -> void:
	const MAX_PLAYS := 40
	var plays := 0
	while not hand.is_empty() and plays < MAX_PLAYS:
		plays += 1
		var opts := _generate_options(s, hand)
		if opts.is_empty():
			break
		var chosen_idx: int
		if use_heuristic:
			chosen_idx = _pick_best(opts, s)
		else:
			chosen_idx = rng.randi_range(0, opts.size() - 1)
		var opt: Dictionary = opts[chosen_idx]
		if opt.get("type", "") == "PASS":
			break
		_apply_option(s, opt)
		var played_card: Card = opt.get("card", null)
		if played_card != null:
			hand.erase(played_card)
		# CardDraw: roba `draw_count` cartas del mazo a la mano de este turno.
		# El tempo (más jugadas ahora) es justo lo que explota la heurística.
		if opt.get("type", "") == "DRAW" and not s.own_deck.is_empty():
			for _j in range(int(opt.get("draw_count", 1))):
				hand.append(s.own_deck[rng.randi_range(0, s.own_deck.size() - 1)])


## Simula el turno del rival sobre `s` (mutación in-place) usando una mano
## determinizada (sampleada por AIDeterminizer en cada iteración SO-ISMCTS).
##
## Modelo deliberadamente ligero: el AIGameState no rastrea oro/slots/deck del
## rival, solo sus magnitudes públicas (tiles, gpt, troop_power). Cada carta de
## la mano determinizada empuja una de esas magnitudes:
##   - Colonize  → +1 tile rival (si queda territorio libre)
##   - Build/Upgrade → +gpt rival (estimación calibrada, ~igual que el modelo propio)
##   - Recruit   → +troop_power rival
##   - resto (GenerateGold, CardDraw, Tactic…) → sin efecto territorial/militar directo
##
## Esto hace que distintas determinizaciones produzcan proyecciones rivales
## distintas: la varianza que MCTS promedia es justo lo que aporta SO-ISMCTS.
## Ver PLAN_IA_COMPLETO §2.3 y §8.1 (alternancia de 2 agentes).
static func simulate_rival_turn(s: AIGameState, rival_hand: Array[Card],
		_rng: RandomNumberGenerator) -> void:
	var free_tiles := s.total_map_tiles - s.own_tiles - s.rival_tiles
	for card in rival_hand:
		if card is ColonizeCard:
			if free_tiles > 0:
				s.rival_tiles += 1
				free_tiles -= 1
		elif card is BuildCard or card is DirectBuildCard or card is UpgradeBuildingCard:
			s.rival_gold_per_turn += 15
		elif card is RecruitCard:
			s.rival_troop_power += 12.0


# ---------------------------------------------------------------------------
# API pública para el árbol MCTS (AIMCTS / AIMCTSNode)
# ---------------------------------------------------------------------------

## Mapea una carta concreta a su opción abstracta dado el estado.
## Devuelve {} si la carta no es modelable/jugable en el estado abstracto.
static func abstract_option_for_card(card: Card, s: AIGameState) -> Dictionary:
	return _card_to_option(card, s)


## Aplica una opción abstracta (dict) sobre `s` (mutación in-place).
static func apply_abstract(s: AIGameState, opt: Dictionary) -> void:
	_apply_option(s, opt)


## Opción abstracta "no jugar nada" (PASS).
static func pass_option() -> Dictionary:
	return _make_pass()


# ---------------------------------------------------------------------------
# Internals — generación y aplicación de opciones abstractas
# ---------------------------------------------------------------------------

## Samplea una mano del deck propio del estado usando Fisher-Yates parcial.
## El mazo se trata como circular: no se extrae del state.own_deck.
static func _draw_hand(s: AIGameState, rng: RandomNumberGenerator) -> Array[Card]:
	if s.own_deck.is_empty() or s.own_cards_per_turn <= 0:
		return []
	var pool: Array[Card] = s.own_deck.duplicate()
	var n := mini(s.own_cards_per_turn, pool.size())
	for i in range(pool.size() - 1, pool.size() - n - 1, -1):
		var j := rng.randi_range(0, i)
		var tmp: Card = pool[i]; pool[i] = pool[j]; pool[j] = tmp
	return pool.slice(pool.size() - n, pool.size())


## Genera opciones abstractas para la mano actual según el estado.
## Retorna un Array de Dictionary con las keys:
##   "type"               — String identificador del tipo de acción
##   "card"               — Card que se juega (null en PASS)
##   "gold_cost"          — oro inmediato que cuesta
##   "gold_per_turn_delta"— cambio en GPT al aplicarla
##   "food_delta"         — cambio en food
##   "tiles_delta"        — cambio en own_tiles
##   "troop_power_delta"  — cambio en own_troop_power
##   "gold_immediate"     — oro extra generado inmediatamente (GenerateGold)
static func _generate_options(s: AIGameState, hand: Array[Card]) -> Array:
	var opts: Array = []
	for card in hand:
		var opt := _card_to_option(card, s)
		if not opt.is_empty():
			opts.append(opt)
	if opts.is_empty():
		opts.append(_make_pass())
	return opts


static func _card_to_option(card: Card, s: AIGameState) -> Dictionary:
	if card is ColonizeCard:
		if s.colonizable_count <= 0:
			return {}
		return {"type": "COLONIZE", "card": card, "gold_cost": 0,
			"gold_per_turn_delta": 0, "food_delta": 0,
			"tiles_delta": 1, "troop_power_delta": 0.0, "gold_immediate": 0}

	if card is BuildCard:
		# Estimación calibrada con los recursos del juego:
		# coste medio de edificio: ~60 oro · delta GPT medio: ~18/turno
		if s.buildable_slots <= 0 or s.own_gold < 40:
			return {}
		return {"type": "BUILD", "card": card, "gold_cost": 60,
			"gold_per_turn_delta": 18, "food_delta": 0,
			"tiles_delta": 0, "troop_power_delta": 0.0, "gold_immediate": 0}

	if card is DirectBuildCard:
		if s.buildable_slots <= 0 or s.own_gold < 40:
			return {}
		return {"type": "BUILD", "card": card, "gold_cost": 60,
			"gold_per_turn_delta": 18, "food_delta": 0,
			"tiles_delta": 0, "troop_power_delta": 0.0, "gold_immediate": 0}

	if card is UpgradeBuildingCard:
		if s.buildable_slots <= 0 or s.own_gold < 50:
			return {}
		return {"type": "UPGRADE", "card": card, "gold_cost": 50,
			"gold_per_turn_delta": 12, "food_delta": 0,
			"tiles_delta": 0, "troop_power_delta": 0.0, "gold_immediate": 0}

	if card is GenerateGoldCard:
		var amount := (card as GenerateGoldCard).amount
		return {"type": "GENERATE_GOLD", "card": card, "gold_cost": 0,
			"gold_per_turn_delta": 0, "food_delta": 0,
			"tiles_delta": 0, "troop_power_delta": 0.0, "gold_immediate": amount}

	if card is RecruitCard:
		# Estimación: coste mínimo de tropa (~25 oro), potencia media (~12 atk+def)
		if s.own_gold < 25 or s.own_food < 0:
			return {}
		return {"type": "RECRUIT", "card": card, "gold_cost": 25,
			"gold_per_turn_delta": 0, "food_delta": -1,
			"tiles_delta": 0, "troop_power_delta": 12.0, "gold_immediate": 0}

	if card is ChangeLocationTypeCard:
		# Urbanizar: coste típico en food (no en gold).
		# Efecto: desbloquea más slots de edificio → buildable_slots++
		if s.own_food < 5:
			return {}
		return {"type": "URBANIZE", "card": card, "gold_cost": 0,
			"gold_per_turn_delta": 0, "food_delta": -3,
			"tiles_delta": 0, "troop_power_delta": 0.0, "gold_immediate": 0,
			"slots_delta": 2}

	if card is CardDrawCard:
		# Tempo: robar cartas añade jugadas a este turno (lo modela _play_card_phase
		# y AIMCTS._expand añadiendo cartas a la mano). Sin esto el MCTS ignoraba
		# CardDraw (8% vs 21% de la heurística) y perdía el motor de aceleración.
		var n := (card as CardDrawCard).amount
		return {"type": "DRAW", "card": card, "gold_cost": 0,
			"gold_per_turn_delta": 0, "food_delta": 0,
			"tiles_delta": 0, "troop_power_delta": 0.0, "gold_immediate": 0,
			"draw_count": maxi(n, 1)}

	if card is OpenFrontCard:
		# Abrir frente: coste ~50 oro, efecto territorial diferido.
		if s.own_gold < 50 or s.own_troop_power < 5.0:
			return {}
		return {"type": "OPEN_FRONT", "card": card, "gold_cost": 50,
			"gold_per_turn_delta": 0, "food_delta": 0,
			"tiles_delta": 0, "troop_power_delta": 0.0, "gold_immediate": 0}

	if card is TacticCard:
		if s.fronts.is_empty():
			return {}
		return {"type": "TACTIC", "card": card, "gold_cost": 0,
			"gold_per_turn_delta": 0, "food_delta": 0,
			"tiles_delta": 0, "troop_power_delta": 0.0, "gold_immediate": 0,
			"marker_delta": 2.0}

	if card is RecoverCard:
		return {}  # efecto de ciclo de deck: sin impacto en escalares clave

	return {}  # carta no reconocida → ignorar en simulación


static func _apply_option(s: AIGameState, opt: Dictionary) -> void:
	var gold_cost: int = opt.get("gold_cost", 0)
	s.own_gold = maxi(0, s.own_gold - gold_cost)
	s.own_gold += opt.get("gold_immediate", 0)
	s.own_gold_per_turn += opt.get("gold_per_turn_delta", 0)
	s.own_food += opt.get("food_delta", 0)
	s.own_tiles = maxi(0, s.own_tiles + opt.get("tiles_delta", 0))
	s.own_troop_power = maxf(0.0,
		s.own_troop_power + opt.get("troop_power_delta", 0.0))

	match opt.get("type", ""):
		"COLONIZE":
			s.colonizable_count = maxi(0, s.colonizable_count - 1)
		"BUILD", "UPGRADE":
			s.buildable_slots = maxi(0, s.buildable_slots - 1)
		"URBANIZE":
			s.buildable_slots += opt.get("slots_delta", 0)
		"TACTIC":
			_advance_front_markers(s, opt.get("marker_delta", 0.0))
		"OPEN_FRONT":
			# Añadimos un frente nuevo en equilibrio como estimación.
			s.fronts.append(AIGameState.FrontSnapshot.of(&"attacker", 0.0, 12.0))


static func _advance_front_markers(s: AIGameState, delta: float) -> void:
	for f in s.fronts:
		var snap := f as AIGameState.FrontSnapshot
		if snap.own_side == &"attacker":
			snap.marker = minf(snap.marker + delta, snap.threshold * 1.5)
		else:
			snap.marker = maxf(snap.marker - delta, -snap.threshold * 1.5)


# ---------------------------------------------------------------------------
# Política greedy abstracta
# ---------------------------------------------------------------------------

## Devuelve el índice de la opción con mayor score abstracto.
static func _pick_best(opts: Array, s: AIGameState) -> int:
	var best_idx := 0
	var best_score := -INF
	for i in range(opts.size()):
		var sc := _score_option(opts[i], s)
		if sc > best_score:
			best_score = sc
			best_idx = i
	return best_idx


## Scoring abstracto de opciones para la política heurística del rollout.
## Calibrado para reflejar las mismas prioridades que AIHeuristic.score_option:
##   tiles >> GPT > tropas (si hay amenaza) > food > gold inmediato
static func _score_option(opt: Dictionary, s: AIGameState) -> float:
	var t: String = opt.get("type", "")
	if t == "PASS":
		return 0.0

	var total := maxi(s.total_map_tiles, s.own_tiles + s.rival_tiles + 1)
	var own_share := float(s.own_tiles) / float(total)

	# Urgencias
	var gold_urgency := _gold_urgency(s.own_gold_per_turn)
	var food_urgency := 1.0 if s.own_food < 0 else 0.6 if s.own_food < 5 else 0.2
	var mil_urgency := 0.4
	if not s.fronts.is_empty():
		mil_urgency = 1.5
		# Elevar si se está perdiendo en algún frente
		for f in s.fronts:
			var snap := f as AIGameState.FrontSnapshot
			var losing := (snap.own_side == &"attacker" and snap.marker < 0.0) \
				or (snap.own_side == &"defender" and snap.marker > 0.0)
			if losing:
				mil_urgency = 2.5
				break
	var expansion_factor := clampf(1.0 - own_share * 2.0, 0.2, 1.5)

	var score := 0.0
	score += float(opt.get("tiles_delta", 0))         * 5.0 * expansion_factor
	score += float(opt.get("gold_per_turn_delta", 0)) * 0.04 * gold_urgency
	score += opt.get("troop_power_delta", 0.0)         * 0.1 * mil_urgency
	score += float(-opt.get("food_delta", 0))          * food_urgency * 1.5
	score += float(opt.get("gold_immediate", 0))       * gold_urgency * 0.002

	match t:
		"URBANIZE":
			score += 3.0 * expansion_factor
		"DRAW":
			# Tempo: cada carta robada ≈ una jugada extra. Valor moderado para que
			# se juegue cuando no hay algo claramente mejor (refleja _score_draw).
			score += float(opt.get("draw_count", 1)) * 3.0
		"OPEN_FRONT":
			# Valor territorial esperado de abrir frente: mayor si el rival tiene
			# más tiles (hay qué ganar) y si tenemos poder militar para sostenerlo.
			var rival_share := float(s.rival_tiles) / float(total)
			var power_factor := clampf(s.own_troop_power / 30.0, 0.0, 1.5)
			score += (3.0 + rival_share * 8.0) * power_factor
		"TACTIC":
			# Empujar un frente: más valioso cuanto más cerca de resolverlo a favor.
			score += (4.0 + mil_urgency * 4.0)

	return score


static func _gold_urgency(gpt: int) -> float:
	if gpt < 0:    return 3.0
	if gpt < 50:   return 2.0
	if gpt < 100:  return 1.3
	if gpt < 200:  return 1.0
	if gpt < 500:  return 0.7
	return 0.35


static func _make_pass() -> Dictionary:
	return {"type": "PASS", "card": null, "gold_cost": 0,
		"gold_per_turn_delta": 0, "food_delta": 0,
		"tiles_delta": 0, "troop_power_delta": 0.0, "gold_immediate": 0}
