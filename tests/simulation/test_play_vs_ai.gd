extends GutTest

## JUGAR UNA PARTIDA CONTRA LA IA desde fuera del juego.
##
## El bando A lo lleva un guion externo (ver ManualPolicy) y el B, la IA con los
## pesos DESPLEGADOS. Todo lo demás del turno —robar, eventos, descartes, cierre,
## frentes— es el del juego real: no es una maqueta, es una partida.
##
## PROTOCOLO. La partida es determinista con semilla fija, así que no hace falta
## guardar estado entre jugadas: cada vez se rejuega entera aplicando el guion y,
## en la primera decisión que el guion no cubre, se vuelca el estado y las
## opciones legales. Quien juega añade su decisión al final del guion y relanza.
## Es append-only: añadir al final nunca altera una decisión anterior.
##
## Lanzar:
##   RUN_PLAY_VS_AI=1 godot --headless -s addons/gut/gut_cmdln.gd "-gconfig=" \
##     -gtest=res://tests/simulation/test_play_vs_ai.gd -gexit
## Diales: PLAY_GUION (ruta del guion, default user://guion.json),
##         PLAY_SEED (semilla de la partida), PLAY_MAX_ROUNDS.
## Salida: user://play_state.json


const ENABLE_FROM_GUI := false
const CHAMPION_PATH := "res://resources/ai/heuristic_weights_optimized.tres"
const PLAY_SEED := 20260912
const PLAY_MAX_ROUNDS := 200


func test_jugar_contra_la_ia() -> void:
	if not (ENABLE_FROM_GUI or OS.get_environment("RUN_PLAY_VS_AI") != ""):
		pass_test("Saltado: RUN_PLAY_VS_AI=1 para ejecutar.")
		return

	TestWorld.reset()
	var guion := _leer_guion()
	print("[play] guion con %d decisiones ya tomadas" % guion.size())

	var pol := ManualPolicy.new(RandomNumberGenerator.new())
	pol.guion = guion

	# IMPRESCINDIBLE para que el protocolo de rejugado funcione: el WorldGenerator
	# usa el RNG GLOBAL para barajar imperios y sembrar los ruidos, no el
	# rng_master del arnés. Sin esto el mapa cambia en cada repetición y el guion
	# —que son índices dentro de una enumeración— deja de significar nada. Se
	# detectó porque tras "colonizar" una casilla concreta resultaban ser otras
	# dos las controladas.
	var semilla := SimEnv.int_env("PLAY_SEED", PLAY_SEED)
	seed(semilla)

	var h := GameSimHarness.new()
	h.run_id = 0
	h.max_rounds = SimEnv.int_env("PLAY_MAX_ROUNDS", PLAY_MAX_ROUNDS)
	h.rng_master = RandomNumberGenerator.new()
	h.rng_master.seed = semilla
	h.capture_snapshots = false
	h.policy_a = pol
	h.config_a = _config_ia()      # los pesos de A dan igual: decide el guion
	h.config_b = _config_ia()
	h.attach_to(self)
	await h.run()

	_informar(h, pol)

	WorldMap.map = []
	WorldMap.map_as_dict = {}
	BattleFront.clear_active_instances()
	for e in get_errors():
		e.handled = true
	assert_true(true)


func _config_ia() -> AIConfig:
	var cfg := AIConfig.new()
	cfg.mode = AIConfig.Mode.HEURISTIC
	var w = load(CHAMPION_PATH)
	assert_not_null(w, "el campeón desplegado debe cargar")
	cfg.heuristic_weights = w
	return cfg


func _leer_guion() -> Array:
	var ruta := OS.get_environment("PLAY_GUION")
	if ruta == "":
		ruta = "user://guion.json"
	if not FileAccess.file_exists(ruta):
		return []
	var f := FileAccess.open(ruta, FileAccess.READ)
	if f == null:
		return []
	var txt := f.get_as_text()
	f.close()
	var d = JSON.parse_string(txt)
	return d if d is Array else []


## Si la partida terminó antes de agotar el guion, la captura queda vacía: eso
## significa que ya hay resultado y no hay nada que decidir.
func _informar(h: GameSimHarness, pol: ManualPolicy) -> void:
	if h.finished_round > 0:
		print("[play] PARTIDA TERMINADA en la ronda %d · gana %s (%s)" % [
			h.finished_round, h.winner_label, h.victory_condition])
		print("[play] casillas finales: A=%d  B=%d  de %d" % [
			h.final_tiles_a, h.final_tiles_b, h.final_total_tiles])
	if pol.captura.is_empty():
		print("[play] sin punto de decisión pendiente.")
		return

	var c := pol.captura
	print("\n[play] ===== TU TURNO · ronda %d · decisión nº %d =====" % [
		int(c["turno"]), int(c["decision_n"])])
	print("[play] tú:    oro %d (%+d/turno) · comida %d · casillas %d · combat %.2f" % [
		int(c["yo"]["oro"]), int(c["yo"]["oro_por_turno"]), int(c["yo"]["comida"]),
		int(c["yo"]["casillas"]), float(c["yo"]["combat_multiplier"])])
	print("[play] rival: casillas %d" % int(c["rival"]["casillas"]))
	print("[play] mapa:  %d casillas · %d colonizables · %d para dominar" % [
		int(c["mapa"]["total"]), int(c["mapa"]["colonizables"]),
		int(c["mapa"]["para_dominar"])])
	for mc in c["mis_casillas"]:
		print("[play] mía:   %s" % str(mc))
	print("[play] mano:  %s" % ", ".join(PackedStringArray(c["mano"])))
	for fr in c["frentes"]:
		print("[play] frente: marcador %.1f / umbral %.1f (%d turnos)" % [
			float(fr["marcador"]), float(fr["umbral"]), int(fr["turnos"])])
	print("[play] --- opciones ---")
	for o in c["opciones"]:
		var d := str(o.get("donde", ""))
		print("[play]  %3d  %-26s %s" % [int(o["i"]), str(o["que"]), d])

	var f := FileAccess.open("user://play_state.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(c, "  "))
		f.close()
