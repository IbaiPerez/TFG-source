extends RefCounted
class_name HeuristicOpponents

## Construye el POOL de rivales para HeuristicFitness: la baseline (pesos por
## defecto) + arquetipos de heurística con distintas "puntuaciones" (estilos de
## juego marcadamente distintos) + una política aleatoria. Todo en modo
## HEURISTIC/RANDOM → sin coste de MCTS.
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


## Pool completo para la ETAPA 2 (revalidación): baseline + 3 arquetipos + random.
static func full_pool() -> Array:
	return [
		heur_config(baseline()),
		heur_config(economic()),
		heur_config(militarist()),
		heur_config(expansionist()),
		random_config(),
	]


# --- Fábricas de AIConfig ----------------------------------------------------

static func heur_config(w: HeuristicWeights) -> AIConfig:
	var c := AIConfig.new()
	c.mode = AIConfig.Mode.HEURISTIC
	c.heuristic_weights = w
	return c


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
	for k in HeuristicWeights.OPTIMIZABLE_KEYS:
		var b := HeuristicWeights.get_bounds(k)
		var factor := rng.randf_range(1.0 - spread, 1.0 + spread)
		w.set(k, clampf(float(w.get(k)) * factor, b.x, b.y))
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
