extends RefCounted
class_name MultiRunSimulator

## Orquesta N runs del GameSimHarness y agrega las metricas numericas por
## (ronda, ai_label) calculando mean / min / max / std. Cada run usa un
## mapa, imperios y seeds distintos derivados de `rng_master_seed` para
## ser reproducibles.
##
## Uso:
##   var multi := MultiRunSimulator.new()
##   multi.num_runs = 5
##   multi.max_rounds = 500  # limite de seguridad; la partida termina por victoria
##   multi.rng_master_seed = 12345
##   multi.attach_to(gut_test)
##   await multi.run()
##   multi.dump_to("user://sim_multi.json")


# --- Config ----------------------------------------------------------------

var num_runs: int = 5
var max_rounds: int = 500   ## Limite de seguridad por run; la partida termina antes si hay ganador
var rng_master_seed: int = 12345


# --- Estado ----------------------------------------------------------------

var _gut_test
var runs: Array = []        ## Array of {run_id, seed_meta, snapshots}


# --- API publica -----------------------------------------------------------

func attach_to(gut_test) -> void:
	_gut_test = gut_test


func run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_master_seed

	for i in num_runs:
		print("[Sim] === RUN %d / %d ===" % [i + 1, num_runs])
		var harness := GameSimHarness.new()
		harness.max_rounds = max_rounds
		harness.run_id = i
		# RNG independiente por run pero derivado del master, asi la
		# misma rng_master_seed reproduce exactamente la misma serie.
		var run_rng := RandomNumberGenerator.new()
		run_rng.seed = rng.randi()
		harness.rng_master = run_rng
		harness.attach_to(_gut_test)
		await harness.run()

		runs.append({
			"run_id": i,
			"seed_meta": harness.run_seed_meta,
			"snapshots": harness.snapshots,
			"winner": harness.winner_empire_name,
			"victory_condition": harness.victory_condition,
			"finished_round": harness.finished_round,
		})

		# Limpieza obligatoria entre runs: WorldMap y BattleFront son
		# globales (autoload y static), si no las vaciamos la siguiente
		# run encuentra estado contaminado.
		WorldMap.map = []
		WorldMap.map_as_dict = {}
		BattleFront.clear_active_instances()


## Vuelca runs + agregaciones a JSON.
func dump_to(path: String) -> void:
	var payload := {
		"metadata": {
			"num_runs": num_runs,
			"max_rounds_safety_cap": max_rounds,
			"rng_master_seed": rng_master_seed,
			"timestamp": Time.get_datetime_string_from_system(true),
		},
		"runs": runs,
		"aggregated_by_round": aggregate(),
	}
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("[Sim] No se pudo abrir %s para escribir" % path)
		return
	f.store_string(JSON.stringify(payload, "  "))
	f.close()
	print("[Sim] JSON volcado en: %s" % path)


# --- Agregacion ------------------------------------------------------------

## Construye, para cada (round, ai_label), un dict de metricas numericas
## con media, min, max y std a traves de las runs.
func aggregate() -> Array:
	# Asumimos misma estructura entre runs (mismo num_rounds, mismas
	# ai_labels). Cogemos los snapshots de la primera run como plantilla.
	if runs.is_empty():
		return []
	var template_snapshots: Array = runs[0]["snapshots"]
	var out := []

	for tpl in template_snapshots:
		var round_num: int = tpl["round"]
		var ai_label: String = tpl["ai_label"]
		# Recoger el mismo snapshot (round, ai_label) en cada run.
		var matched: Array = []
		for r in runs:
			for snap in r["snapshots"]:
				if snap["round"] == round_num and snap["ai_label"] == ai_label:
					matched.append(snap)
					break
		out.append({
			"round": round_num,
			"ai_label": ai_label,
			"n_samples": matched.size(),
			"metrics": _aggregate_metrics(matched),
		})
	return out


## Calcula mean/min/max/std de las metricas numericas seleccionadas a
## traves de los snapshots dados.
func _aggregate_metrics(snapshots: Array) -> Dictionary:
	var paths := [
		"economy.total_gold",
		"economy.gold_per_turn",
		"economy.food",
		"economy.total_purges_done",
		"economy.combat_multiplier",
		"deck.draw_pile",
		"deck.discard_pile",
		"deck.played_pile",
		"deck.deck_total_real",
		"deck.cards_per_turn",
		"deck.unlocked_pool_size",
		"map.total_map_tiles",
		"map.controlled_tiles",
		"map.buildings_total",
		"military.troop_pool_size",
		"military.fronts_as_attacker",
		"military.fronts_as_defender",
		"military.troop_maintenance_gold",
		"military.troop_maintenance_food",
		"military.fronts_in_manager",
		"military.resolved.won_as_attacker",
		"military.resolved.won_as_defender",
		"military.resolved.lost_as_attacker",
		"military.resolved.lost_as_defender",
		"military.resolved.total_resolved",
		"heuristic.gold_urgency",
		"heuristic.food_urgency",
		"heuristic.military_urgency",
		"heuristic.deck_urgency",
		"heuristic.expansion_factor",
		"heuristic.resource_surplus_factor",
		"heuristic.max_front_pressure",
		"heuristic.buildable_slots",
		"heuristic.upgradeable_buildings",
		"heuristic.colonizable_tiles",
		"heuristic.territory_pct",
		"heuristic.tiles_to_domination",
	]

	var out := {}
	for path in paths:
		var values: Array = []
		for s in snapshots:
			var v = _path_get(s, path)
			if v == null:
				continue
			values.append(float(v))
		out[path] = _stats_of(values)
	return out


func _path_get(d: Dictionary, path: String) -> Variant:
	var parts := path.split(".")
	var cur: Variant = d
	for p in parts:
		if cur is Dictionary and (cur as Dictionary).has(p):
			cur = (cur as Dictionary)[p]
		else:
			return null
	return cur


func _stats_of(values: Array) -> Dictionary:
	if values.is_empty():
		return {"mean": 0.0, "min": 0.0, "max": 0.0, "std": 0.0, "n": 0}
	var mean := 0.0
	var vmin: float = values[0]
	var vmax: float = values[0]
	for v in values:
		mean += v
		vmin = min(vmin, v)
		vmax = max(vmax, v)
	mean /= values.size()
	var variance := 0.0
	for v in values:
		variance += (v - mean) * (v - mean)
	variance /= values.size()
	return {
		"mean": mean,
		"min": vmin,
		"max": vmax,
		"std": sqrt(variance),
		"n": values.size(),
	}
