extends GutTest

## Reglas de bonuses tacticos, ahora escritas UNA sola vez en CombatMath y usadas
## por los dos mundos: BattleFront (juego real) y el snapshot del MCTS.
##
## Estos tests existen porque la unificacion tuvo que reconciliar dos versiones
## que NO eran identicas: la viva toleraba el formato Dictionary legacy y la del
## snapshot solo TacticBonus tipados. La compartida conserva las dos ramas, asi
## que hay que fijar que ninguno de los dos mundos cambia de comportamiento.


func _bonus(tactic_name: String, duration: int) -> TacticBonus:
	var b := TacticBonus.new()
	b.tactic_name = tactic_name
	b.duration = duration
	return b


# --- tick_bonuses ----------------------------------------------------------

func test_los_bonuses_con_duracion_caducan() -> void:
	var bonuses: Array = [_bonus("Carga", 2)]
	CombatMath.tick_bonuses(bonuses)
	assert_eq(bonuses.size(), 1, "con duracion 2 aun no caduca")
	assert_eq((bonuses[0] as TacticBonus).duration, 1)
	CombatMath.tick_bonuses(bonuses)
	assert_eq(bonuses.size(), 0, "al llegar a 0 se elimina")


func test_los_bonuses_de_duracion_negativa_son_permanentes() -> void:
	var bonuses: Array = [_bonus("Fortaleza", -1)]
	for i in range(5):
		CombatMath.tick_bonuses(bonuses)
	assert_eq(bonuses.size(), 1, "duracion negativa = permanente, no caduca nunca")


func test_tick_tolera_el_formato_dictionary_legacy() -> void:
	# Rama que SOLO usa el mundo vivo: hay tests y codigo que asignan Dictionaries
	# directamente a attacker_bonuses. En el snapshot nunca se toma.
	var bonuses: Array = [{"tactic_name": "Legacy", "duration": 2}]
	CombatMath.tick_bonuses(bonuses)
	assert_eq(int((bonuses[0] as Dictionary)["duration"]), 1)
	CombatMath.tick_bonuses(bonuses)
	assert_eq(bonuses.size(), 0, "el Dictionary legacy tambien caduca")


# --- clear_tactics ---------------------------------------------------------

func test_clear_tactics_solo_quita_las_tacticas() -> void:
	# tactic_name vacio = bonus plano (manual, de evento o de edificio): NO se toca.
	var bonuses: Array = [_bonus("Carga", 3), _bonus("", 3), _bonus("Falange", 3)]
	var quitadas := CombatMath.clear_tactics(bonuses)
	assert_eq(quitadas, 2, "devuelve cuantas tacticas quito")
	assert_eq(bonuses.size(), 1, "el bonus plano sobrevive")
	assert_eq((bonuses[0] as TacticBonus).tactic_name, "")


func test_clear_tactics_sin_tacticas_no_quita_nada() -> void:
	var bonuses: Array = [_bonus("", 3)]
	assert_eq(CombatMath.clear_tactics(bonuses), 0)
	assert_eq(bonuses.size(), 1)


# --- has_active_tactic -----------------------------------------------------

func test_has_active_tactic_distingue_tactica_de_bonus_plano() -> void:
	assert_false(CombatMath.has_active_tactic([_bonus("", 3)]),
		"un bonus plano no es una tactica activa")
	assert_true(CombatMath.has_active_tactic([_bonus("", 3), _bonus("Carga", 3)]))


# --- Los dos mundos aplican la MISMA regla ---------------------------------

func test_el_frente_vivo_y_el_snapshot_caducan_igual() -> void:
	# El punto de la unificacion: misma entrada, mismo resultado en ambos mundos.
	var vivos: Array = [_bonus("Carga", 1), _bonus("", -1)]
	var snap: Array[TacticBonus] = [_bonus("Carga", 1), _bonus("", -1)]

	CombatMath.tick_bonuses(vivos)
	CombatMath.tick_bonuses(snap)

	assert_eq(vivos.size(), snap.size(),
		"la caducidad no puede divergir entre el juego y la simulacion del MCTS")
	assert_eq(vivos.size(), 1, "caduca la tactica, sobrevive el permanente")
