extends GutTest

## HUMO de una partida completa, en la suite por defecto.
##
## Es el único sitio donde generación de mundo, creación de imperios, las dos IAs,
## eventos, frentes y condición de victoria corren JUNTOS sin variable de
## entorno. Todo lo demás que los junta vive en tests/simulation/ y tarda de
## minutos a horas, así que una regresión de integración —un cambio que rompe el
## bootstrap, o que deja a una IA sin jugar— no la veía nadie hasta lanzar una
## tanda. Mapa mínimo (radio 4, ~61 casillas) y pocas rondas: segundos.
##
## La SEGUNDA partida con la misma semilla debe ser idéntica a la primera. De ese
## determinismo dependen las mediciones pareadas (`test_ab_throughput`) y el
## protocolo de rejugado de `test_play_vs_ai`; una regresión ahí no falla ningún
## test unitario, solo deja de significar nada la comparación.

const HARNESS := preload("res://tests/simulation/game_sim_harness.gd")
const SEED := 20260911
const ROUNDS := 4


func before_each() -> void:
	TestWorld.reset()


func after_each() -> void:
	TestWorld.reset()


## Como en test_harness_no_double_generation: el arnés arrastra warnings del
## motor de física al instanciar colliders headless y del fallback de
## EmpireCreator con radios bajos. Se consumen para que GUT no los cuente como
## "Unexpected Errors"; lo que estos tests afirman está en sus aserciones.
## Tiene que llamarse DENTRO del test: GUT decide el fallo por errores justo al
## terminar el cuerpo, antes de after_each.
func _consume_bootstrap_warnings() -> void:
	for e in get_errors():
		e.handled = true


func _heuristic() -> AIConfig:
	var cfg := AIConfig.new()
	cfg.mode = AIConfig.Mode.HEURISTIC
	return cfg


func _play(seed_value: int) -> GameSimHarness:
	# El WorldGenerator baraja imperios y siembra los ruidos con el RNG GLOBAL,
	# no con rng_master (ver test_play_vs_ai): sin esto dos partidas con la
	# misma semilla tienen mapas distintos.
	seed(seed_value)
	var h: GameSimHarness = HARNESS.new()
	h.run_id = 0
	h.max_rounds = ROUNDS
	h.radius_range = Vector2i(4, 4)
	h.rng_master = RandomNumberGenerator.new()
	h.rng_master.seed = seed_value
	h.config_a = _heuristic()
	h.config_b = _heuristic()
	h.attach_to(self)
	await h.run()
	return h


func _total_actions(h: GameSimHarness, label: String) -> int:
	var n := 0
	for k in h.actions_by_label[label]:
		n += int(h.actions_by_label[label][k])
	return n


func test_una_partida_corta_arranca_juega_y_termina() -> void:
	var h := await _play(SEED)

	assert_gt(h.final_total_tiles, 0, "el mundo se generó")
	assert_gt(h.final_tiles_a, 0, "el imperio A tiene casillas")
	assert_gt(h.final_tiles_b, 0, "el imperio B tiene casillas")

	var jugadas: int = h.turns_by_label["AI_A"] + h.turns_by_label["AI_B"]
	assert_gt(jugadas, 0, "alguien jugó")
	if h.victory_condition == "":
		assert_eq(h.turns_by_label["AI_A"], ROUNDS, "A jugó todas las rondas")
		assert_eq(h.turns_by_label["AI_B"], ROUNDS, "B jugó todas las rondas")
	assert_eq(h.snapshots.size(), 2 + jugadas, "un snapshot por turno más los dos iniciales")

	assert_gt(_total_actions(h, "AI_A") + _total_actions(h, "AI_B"), 0,
		"las IAs deben haber jugado alguna carta en %d rondas" % ROUNDS)
	for s in h.snapshots:
		assert_gte(int(s["economy"]["total_gold"]), 0,
			"el oro no puede ser negativo (ronda %s, %s)" % [s.get("round"), s.get("ai_label")])
	_consume_bootstrap_warnings()


func test_la_misma_semilla_reproduce_la_misma_partida() -> void:
	var h1 := await _play(SEED)
	TestWorld.reset()
	var h2 := await _play(SEED)

	assert_eq_deep(h2.run_seed_meta, h1.run_seed_meta)
	assert_eq(h2.final_total_tiles, h1.final_total_tiles, "mismo mapa")
	assert_eq_deep(h2.actions_by_label, h1.actions_by_label)
	assert_eq(h2.final_tiles_a, h1.final_tiles_a)
	assert_eq(h2.final_tiles_b, h1.final_tiles_b)
	assert_eq(h2.victory_condition, h1.victory_condition)
	_consume_bootstrap_warnings()
