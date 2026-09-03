extends RefCounted
class_name HeuristicOpponents

## Construye el POOL de rivales para HeuristicFitness: la baseline (pesos por
## defecto) + arquetipos de heurística con distintas "puntuaciones" (estilos de
## juego marcadamente distintos). Todo en modo HEURISTIC → sin coste de MCTS.
##
## Enfrentar al candidato contra un pool diverso mide efectividad de forma más
## robusta (evita sobreajustar a un único rival) y da más señal al optimizador
## (un cambio de peso que voltea una decisión en cualquier matchup mueve el
## fitness).
##
## Los arquetipos se generan escalando GRUPOS de pesos del default, de modo que
## representen prioridades claras: economía, guerra o expansión. Los factores
## (×0.6–1.8) se mantienen dentro de los rangos de get_bounds.


# --- Configs listas para el pool ---------------------------------------------

## Pool ligero para la ETAPA 1 (búsqueda): baseline + 2 arquetipos contrastados.
## Menos rivales = evaluaciones más baratas mientras se explora.
static func core_pool() -> Array:
	return [
		heur_config(baseline()),
		heur_config(militarist()),
		heur_config(expansionist()),
	]


## Pool completo para la ETAPA 2 (revalidación): baseline + los 3 arquetipos.
##
## SIN política aleatoria, y no por gusto: en la corrida real de dos etapas el
## rival `Mode.RANDOM` separó a los tres finalistas por solo 0.056 de win-rate
## (0.887 / 0.906 / 0.944) frente al ~0.30 que los separaban los rivales de
## verdad. Era un quinto del presupuesto de partidas dedicado a una pregunta cuya
## respuesta ya se sabe —todos le ganan— y además inflaba el win-rate global de
## todos por igual: la baseline aparentaba 0.606 cuando contra rivales reales iba
## en 0.535.
##
## Hay un segundo motivo, de ruido: como la partida diverge según lo que juega el
## candidato, cada uno acaba enfrentándose a una REALIZACIÓN distinta de la
## política aleatoria aunque la semilla sea la misma. Con un rival heurístico eso
## también pasa, pero su calidad es estable; la de una política aleatoria no.
static func full_pool() -> Array:
	return [
		heur_config(baseline()),
		heur_config(economic()),
		heur_config(militarist()),
		heur_config(expansionist()),
	]


# --- Fábricas de AIConfig ----------------------------------------------------

static func heur_config(w: HeuristicWeights) -> AIConfig:
	var c := AIConfig.new()
	c.mode = AIConfig.Mode.HEURISTIC
	c.heuristic_weights = w
	return c


## Config de política aleatoria. Ya NO entra en `full_pool` (ver ahí el porqué),
## pero se conserva porque `AIModeComparator` la usa como referencia de suelo en
## las comparaciones de modo, que es donde sí tiene sentido.
static func random_config() -> AIConfig:
	var c := AIConfig.new()
	c.mode = AIConfig.Mode.RANDOM
	return c


# --- Arquetipos de pesos -----------------------------------------------------

static func baseline() -> HeuristicWeights:
	return HeuristicWeights.new()


## Prioriza economía y crecimiento; resta valor a lo militar.
static func economic() -> HeuristicWeights:
	var w := HeuristicWeights.new()
	w.gold_weight_pos *= 1.6
	w.food_weight *= 1.6
	w.colonize_gold *= 1.4
	w.colonize_food *= 1.4
	w.se_flat_gold *= 1.4
	w.defense_weight *= 0.6
	w.recruit_atkdef_weight *= 0.6
	w.openfront_base_strategic *= 0.6
	w.tactic_base *= 0.6
	return w


## Prioriza fuerza militar, apertura de frentes y tácticas.
static func militarist() -> HeuristicWeights:
	var w := HeuristicWeights.new()
	w.defense_weight *= 1.8
	w.recruit_atkdef_weight *= 1.8
	w.counter_bonus *= 1.3
	w.openfront_gold *= 1.5
	w.openfront_base_strategic *= 1.6
	w.tactic_base *= 1.7
	w.tactic_urgency_scale *= 1.3
	w.colonize_gold *= 0.7
	w.colonize_expansion *= 0.7
	return w


## Heurística con pesos ALEATORIOS moderados: cada peso optimizable = default ×
## uniforme(1-spread, 1+spread), acotado a get_bounds. Rival "razonable pero
## variado", útil como conjunto HELD-OUT (no es ninguno de los 3 arquetipos con
## los que se entrenó/validó el campeón), para medir generalización.
static func random_heuristic(rng: RandomNumberGenerator, spread: float = 0.5) -> HeuristicWeights:
	var w := HeuristicWeights.new()
	for k in HeuristicWeightsSpec.OPTIMIZABLE_KEYS:
		var b := HeuristicWeightsSpec.get_bounds(k)
		var factor := rng.randf_range(1.0 - spread, 1.0 + spread)
		w.set(k, clampf(float(w.get(k)) * factor, b.x, b.y))
	# Reparar es imprescindible desde que las curvas de urgencia entraron en el
	# espacio: escalar cada umbral por su propio factor los cruza constantemente.
	# Medido con spread 0.5: 36 de 50 semillas producían un rival con alguna cadena
	# rota. Un rival con tramos muertos no es «razonable pero variado» — es más
	# débil de lo previsto, e inflaría la generalización aparente del campeón.
	HeuristicWeightsInvariants.repair(w)
	return w


## Pool HELD-OUT para validar generalización del campeón: baseline (referencia
## cara a cara) + `k` heurísticas de pesos aleatorios frescos (semilla propia,
## fuera de los arquetipos de entrenamiento). NO incluye MCTS (que va aparte por
## su coste). Con `seed` fijo el pool es reproducible.
static func heldout_pool(seed: int, k: int = 3, spread: float = 0.5) -> Array:
	var pool: Array = [heur_config(baseline())]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in range(k):
		pool.append(heur_config(random_heuristic(rng, spread)))
	return pool


## AIConfig en modo MCTS (rival de lookahead fuerte) para el test de
## generalización. Controlado por PRESUPUESTO DE TIEMPO (como las sims previas a
## 500/750/1000 ms), no por iteraciones fijas: acota la duración por decisión y
## es comparable con los benchmarks del round-robin/sweep. Replica la config BASE
## del sweep (C=1.0, K=12, depth=10, tope de iteraciones de seguridad).
## Nota: el modo por tiempo NO es determinista (nº de iteraciones ∝ velocidad de
## la máquina); para una MEDIDA de win-rate (no la búsqueda del optimizador) es
## aceptable.
static func mcts_config(budget_ms: int = 500) -> AIConfig:
	var c := AIConfig.new()
	c.mode = AIConfig.Mode.MCTS
	c.mcts_heuristic_rollout = true
	c.mcts_time_budget_ms = budget_ms
	c.mcts_iterations = 100000        # tope de seguridad; la búsqueda para por tiempo
	c.mcts_rollout_depth = 10
	c.mcts_exploration_c = 1.0
	c.mcts_action_pruning_k = 12
	return c


## Prioriza expansión territorial y negación al rival.
static func expansionist() -> HeuristicWeights:
	var w := HeuristicWeights.new()
	w.colonize_gold *= 1.5
	w.colonize_food *= 1.5
	w.colonize_expansion *= 1.8
	w.colonize_denial *= 1.7
	w.encircle_low *= 1.3
	w.encircle_min *= 1.3
	w.tr_close_factor *= 1.2
	w.defense_weight *= 0.7
	w.tactic_base *= 0.7
	return w
