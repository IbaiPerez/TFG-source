extends RefCounted
class_name HeuristicFitness

## Función de fitness para el optimizador de pesos de la heurística.
##
## Mide la eficacia de un candidato HeuristicWeights enfrentándolo, en modo
## HEURISTIC puro, a un POOL de rivales sobre partidas headless. Reutiliza
## AIModeComparator + GameSimHarness (la misma infraestructura del round-robin).
##
## El pool de rivales (opponents) permite medir efectividad de forma ROBUSTA sin
## sobreajustar a un único oponente y sin el coste del MCTS: baseline (pesos por
## defecto) + arquetipos de heurística con distintas puntuaciones (económico,
## militarista, expansionista) + política aleatoria (Mode.RANDOM). Ver
## HeuristicOpponents. Si `opponents` está vacío, se usa solo la baseline.
##
## Además de aportar robustez, un pool con varios rivales SUAVIZA el problema de
## la meseta argmax: un cambio de peso que voltea una decisión en CUALQUIER
## matchup ya mueve el fitness → más señal para SA/GA.
##
## En modo HEURISTIC/RANDOM la partida es DETERMINISTA con seeds fijos, así que
## el fitness no tiene ruido de muestreo (solo la granularidad de N partidas).
##
## Uso:
##   var fit := HeuristicFitness.new(self)          # self = GutTest
##   fit.opponents = HeuristicOpponents.full_pool()
##   fit.n_games = 24
##   var wr := await fit.evaluate(candidate)        # win-rate medio en [0,1]


var gut_test                              ## nodo GutTest para attach del harness
var n_games: int = 24                     ## partidas por matchup (por rol si mirror)
var seed_master: int = 20260706           ## misma semilla → mismas partidas
var mirror: bool = true                   ## jugar candidato como A y como B y promediar
var max_rounds: int = 500
var baseline: HeuristicWeights = null     ## rival por defecto si opponents vacío
var opponents: Array = []                 ## Array[AIConfig]: pool de rivales (ver HeuristicOpponents)

var evals: int = 0                        ## nº total de partidas jugadas (telemetría)
var cache_hits: int = 0                   ## nº de evaluaciones servidas desde caché

# Memoización: el fitness es DETERMINISTA (mismos pesos+seed+pool+rondas →
# mismo resultado), así que candidatos idénticos (élites del GA que pasan intactos
# entre generaciones, descendientes duplicados, candidatos que la SA revisita) no
# se re-simulan. Clave = seed|games|vector de pesos optimizables. El pool y
# max_rounds son fijos por instancia, así que no hacen falta en la clave.
var _cache: Dictionary = {}


func _init(p_gut_test = null) -> void:
	gut_test = p_gut_test


## Win-rate medio del candidato en [0, 1] sobre todo el pool de rivales.
## Es lo que consumen SA/GA como fitness a maximizar.
func evaluate(candidate: HeuristicWeights, seed_val: int = -1, games: int = -1) -> float:
	return float((await evaluate_detailed(candidate, seed_val, games))["winrate"])


## Evaluación detallada: win-rate agregado + IC95 sobre TODAS las partidas
## decisivas del pool, más el desglose por rival. Pensado para la revalidación
## del campeón (etapa 2), donde interesa el intervalo de confianza.
## Devuelve {winrate, wins, decisive, ci95_lo, ci95_hi, per_opponent:[...]}.
func evaluate_detailed(candidate: HeuristicWeights, seed_val: int = -1, games: int = -1) -> Dictionary:
	var s := seed_val if seed_val >= 0 else seed_master
	var g := games if games > 0 else n_games

	var key := "%d|%d|%s" % [s, g, str(candidate.to_vector(HeuristicWeights.OPTIMIZABLE_KEYS))]
	if _cache.has(key):
		cache_hits += 1
		return _cache[key]

	var cand_cfg := _heur_config(candidate)

	var pool := opponents
	if pool.is_empty():
		var base := baseline if baseline != null else HeuristicWeights.new()
		pool = [_heur_config(base)]

	var total_wins := 0
	var total_decisive := 0
	var per_opponent: Array = []
	for opp in pool:
		var r := await _matchup(cand_cfg, opp as AIConfig, g, s)
		total_wins += int(r["wins"])
		total_decisive += int(r["decisive"])
		per_opponent.append(r)

	var wr := float(total_wins) / float(maxi(total_decisive, 1))
	var ci := 1.96 * sqrt(wr * (1.0 - wr) / float(maxi(total_decisive, 1)))
	var result := {
		"winrate": wr,
		"wins": total_wins,
		"decisive": total_decisive,
		"ci95_lo": clampf(wr - ci, 0.0, 1.0),
		"ci95_hi": clampf(wr + ci, 0.0, 1.0),
		"per_opponent": per_opponent,
	}
	_cache[key] = result
	return result


## AIConfig en modo HEURISTIC con los pesos dados.
func _heur_config(weights: HeuristicWeights) -> AIConfig:
	var cfg := AIConfig.new()
	cfg.mode = AIConfig.Mode.HEURISTIC
	cfg.heuristic_weights = weights
	return cfg


## Enfrenta al candidato contra UN rival (con mirror si procede) y devuelve las
## victorias DECISIVAS del candidato y el nº de partidas decisivas.
func _matchup(cand_cfg: AIConfig, opp_cfg: AIConfig, g: int, s: int) -> Dictionary:
	# Tanda 1: candidato = A (mueve primero), rival = B.
	var s1 := await _run(cand_cfg, opp_cfg, g, s)
	var wins := int(s1["a_wins"])
	var decisive := int(s1["a_wins"]) + int(s1["b_wins"])
	if mirror:
		# Tanda 2: rival = A, candidato = B (mismas partidas, roles cambiados).
		var s2 := await _run(opp_cfg, cand_cfg, g, s)
		wins += int(s2["b_wins"])
		decisive += int(s2["a_wins"]) + int(s2["b_wins"])
	var wr := float(wins) / float(maxi(decisive, 1))
	return {"wins": wins, "decisive": decisive, "winrate": wr, "label": _label(opp_cfg)}


## Corre una tanda A vs B y devuelve el summary del comparador.
func _run(cfg_a: AIConfig, cfg_b: AIConfig, g: int, s: int) -> Dictionary:
	var cmp := AIModeComparator.new()
	cmp.config_a = cfg_a
	cmp.config_b = cfg_b
	cmp.label_a = "CAND"
	cmp.label_b = "OPP"
	cmp.matchup_name = "opt_eval"
	cmp.n_games = g
	cmp.max_rounds = max_rounds
	cmp.rng_master_seed = s
	cmp.self_eval_games = 0
	cmp.capture_snapshots = false
	cmp.attach_to(gut_test)
	await cmp.run()
	evals += g
	WorldMap.map = []
	WorldMap.map_as_dict = {}
	BattleFront.clear_active_instances()
	return cmp.summary


func _label(cfg: AIConfig) -> String:
	if cfg == null:
		return "?"
	match cfg.mode:
		AIConfig.Mode.RANDOM: return "random"
		AIConfig.Mode.MCTS:   return "mcts"
		_:                    return "heur"
