extends GutTest

## El umbral de un frente DECAE (de FRONT_INITIAL_THRESHOLD a FRONT_MIN_THRESHOLD
## en FRONT_THRESHOLD_DECAY_TURNS), y todo el motor lo respeta: `can_resolve`,
## `calculate_casualties`, la asignación de tropas y los visuales usan el umbral
## EFECTIVO. La heurística era el único consumidor que leía el campo crudo
## `threshold`, cuyo propio contrato dice que solo vale para inicialización,
## persistencia o configuración — no para comparaciones.
##
## Consecuencia del defecto: en un frente viejo a punto de perderse, la presión
## salía a la mitad, la urgencia militar no llegaba a su techo y la carta táctica
## —la que existe para salvar ese frente— valía un 30 % menos.
##
## Por qué la suite no lo veía: `test_ai_urgency` prueba `front_pressure` como
## FUNCIÓN PURA con un threshold inventado. Ningún test le pasaba nunca un frente
## real con `turns_elapsed > 0`, así que el fallo vivía entero en los LLAMANTES.
## De ahí que aquí no se pruebe la fórmula sino los cinco puntos de llamada.
##
## Las entradas se derivan de la REGLA (`get_current_threshold()`,
## `GameBalance.FRONT_THRESHOLD_DECAY_TURNS`), nunca de literales: con números a
## mano, tocar el decaimiento dejaría estos tests en verde midiendo otra banda.


const DECAY_TURNS := GameBalance.FRONT_THRESHOLD_DECAY_TURNS

var _mi_imperio: Empire
var _rival: Empire


func before_each() -> void:
	BattleFront.clear_active_instances()
	_mi_imperio = Empire.new()
	_mi_imperio.name = "Propio"
	_rival = Empire.new()
	_rival.name = "Rival"


func after_each() -> void:
	BattleFront.clear_active_instances()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Frente donde ATACAMOS nosotros, con `turnos` transcurridos. El marcador se fija
## como una fracción del umbral EFECTIVO para que el escenario signifique lo mismo
## sea cual sea el decaimiento.
func _frente_atacando(turnos: int, fraccion_perdida: float) -> BattleFront:
	var atk := TestBuilders.tile().build()
	var def := TestBuilders.tile().build()
	add_child_autofree(atk)
	add_child_autofree(def)
	var f := BattleFront.new(atk, def, _mi_imperio, _rival)
	f.turns_elapsed = turnos
	# marker negativo = va ganando el defensor = lo estamos perdiendo.
	f.marker = -f.get_current_threshold() * fraccion_perdida
	return f


func _snap_atacando(turnos: int, fraccion_perdida: float) -> AIRealState.FrontSnap:
	var fs := AIRealState.FrontSnap.new()
	fs.attacker_owner = AIRealState.OWNER_SELF
	fs.defender_owner = AIRealState.OWNER_RIVAL
	fs.turns_elapsed = turnos
	fs.marker = -fs.current_threshold() * fraccion_perdida
	return fs


func _estado_con(fronts: Array) -> AIRealState:
	var s := AIRealState.new()
	s.fronts = fronts
	s.total_map_tiles = 100
	return s


func _w() -> HeuristicWeights:
	return HeuristicWeights.new()


# ---------------------------------------------------------------------------
# Mundo vivo · presión de frente
# ---------------------------------------------------------------------------

func test_presion_se_mide_contra_el_umbral_efectivo_no_el_inicial() -> void:
	var f := _frente_atacando(DECAY_TURNS, 1.0)   # justo en el punto de perderlo
	var fronts: Array[BattleFront] = [f]

	assert_lt(f.get_current_threshold(), f.threshold,
		"precondición: con el decaimiento agotado el umbral efectivo debe ser menor")

	var p := AIDecisionCache._max_front_pressure_from_list(fronts, _mi_imperio)
	assert_almost_eq(p, 1.0, 0.001,
		"un frente en su umbral efectivo está al 100 % de presión")


func test_dos_frentes_iguales_con_distinta_antiguedad_no_dan_la_misma_presion() -> void:
	# EL test que discrimina: mismo marcador absoluto, distinta antigüedad. Con el
	# umbral crudo ambos daban EXACTAMENTE lo mismo, porque el divisor era el mismo.
	var nuevo := _frente_atacando(0, 0.5)
	var viejo := _frente_atacando(DECAY_TURNS, 0.5)
	viejo.marker = nuevo.marker   # mismo marcador absoluto en los dos

	var p_nuevo := AIDecisionCache._max_front_pressure_from_list(
		[nuevo] as Array[BattleFront], _mi_imperio)
	var p_viejo := AIDecisionCache._max_front_pressure_from_list(
		[viejo] as Array[BattleFront], _mi_imperio)

	assert_gt(p_viejo, p_nuevo,
		"con el mismo marcador, el frente viejo está MÁS cerca de perderse")


func test_la_presion_como_defensor_tambien_usa_el_umbral_efectivo() -> void:
	# El signo lo normaliza el llamante; el divisor debe decaer igual en ambos bandos.
	var atk := TestBuilders.tile().build()
	var def := TestBuilders.tile().build()
	add_child_autofree(atk)
	add_child_autofree(def)
	var f := BattleFront.new(atk, def, _rival, _mi_imperio)   # defendemos nosotros
	f.turns_elapsed = DECAY_TURNS
	f.marker = f.get_current_threshold()   # marcador a favor del atacante = perdemos

	var p := AIDecisionCache._max_front_pressure_from_list(
		[f] as Array[BattleFront], _mi_imperio)
	assert_almost_eq(p, 1.0, 0.001, "defendiendo, el umbral efectivo manda igual")


# ---------------------------------------------------------------------------
# Mundo vivo · urgencia militar
# ---------------------------------------------------------------------------

func test_urgencia_militar_alcanza_su_techo_en_un_frente_a_punto_de_perderse() -> void:
	var f := _frente_atacando(DECAY_TURNS, 1.0)
	var stats := TestBuilders.stats().with_empire(_mi_imperio).build()
	var ctx := TestBuilders.context(stats).build()

	var mu := AIDecisionCache._military_urgency(ctx, AIGamePhase.Phase.MID)
	assert_almost_eq(mu, _w().mil_urg_max, 0.001,
		"presión 1.0 debe interpolar hasta mil_urg_max")
	assert_not_null(f, "el frente vive mientras dura el test")


# ---------------------------------------------------------------------------
# Mundo vivo · valor de la carta táctica
# ---------------------------------------------------------------------------

func test_la_tactica_vale_mas_en_el_frente_viejo_que_en_el_nuevo() -> void:
	# La carta táctica existe para salvar el frente comprometido. Con el umbral
	# crudo, dos frentes con el mismo marcador la valoraban IGUAL.
	var stats := TestBuilders.stats().with_empire(_mi_imperio).build()

	var nuevo := _frente_atacando(0, 0.5)
	var ctx_nuevo := TestBuilders.context(stats).build()
	var s_nuevo := AIHeuristic.score_option(
		AITacticOption.from_card(TacticCard.new(), nuevo), ctx_nuevo)
	BattleFront.clear_active_instances()

	var viejo := _frente_atacando(DECAY_TURNS, 0.5)
	viejo.marker = nuevo.marker
	var ctx_viejo := TestBuilders.context(stats).build()
	var s_viejo := AIHeuristic.score_option(
		AITacticOption.from_card(TacticCard.new(), viejo), ctx_viejo)

	assert_gt(s_viejo, s_nuevo,
		"con el mismo marcador, la táctica vale más en el frente más comprometido")


# ---------------------------------------------------------------------------
# Snapshot (MCTS) · el espejo debe decaer igual
# ---------------------------------------------------------------------------

func test_snapshot_presion_militar_usa_el_umbral_efectivo() -> void:
	var nuevo := _snap_atacando(0, 0.5)
	var viejo := _snap_atacando(DECAY_TURNS, 0.5)
	viejo.marker = nuevo.marker

	var mu_nuevo := AISnapshotFacts._military_urgency(
		_estado_con([nuevo]), AIRealState.OWNER_SELF, _w())
	var mu_viejo := AISnapshotFacts._military_urgency(
		_estado_con([viejo]), AIRealState.OWNER_SELF, _w())

	assert_gt(mu_viejo, mu_nuevo,
		"el snapshot debe leer el frente viejo como más urgente, igual que el vivo")


func test_snapshot_tactica_usa_el_umbral_efectivo() -> void:
	var nuevo := _snap_atacando(0, 0.5)
	var viejo := _snap_atacando(DECAY_TURNS, 0.5)
	viejo.marker = nuevo.marker

	var m := AIRealOptions.Move.new()
	m.kind = &"TACTIC"
	m.card = TacticCard.new()
	m.front_idx = 0

	var s_nuevo := AIRealEvalStrong.score_move(
		m, _estado_con([nuevo]), AIRealState.OWNER_SELF, _w())
	var s_viejo := AIRealEvalStrong.score_move(
		m, _estado_con([viejo]), AIRealState.OWNER_SELF, _w())

	assert_gt(s_viejo, s_nuevo,
		"el prior del MCTS debe valorar más la táctica en el frente comprometido")


# ---------------------------------------------------------------------------
# Paridad entre mundos
# ---------------------------------------------------------------------------

func test_vivo_y_snapshot_dan_la_misma_presion_para_el_mismo_frente() -> void:
	# Si los dos mundos divergieran aquí, el prior de la raíz y el árbol estarían
	# midiendo frentes distintos.
	var vivo := _frente_atacando(DECAY_TURNS, 0.6)
	var snap := _snap_atacando(DECAY_TURNS, 0.6)

	var p_vivo := AIDecisionCache._max_front_pressure_from_list(
		[vivo] as Array[BattleFront], _mi_imperio)
	var p_snap := AISnapshotFacts._max_front_pressure(
		_estado_con([snap]), AIRealState.OWNER_SELF)

	assert_almost_eq(p_vivo, p_snap, 0.001,
		"mismo frente, misma presión en los dos mundos")
