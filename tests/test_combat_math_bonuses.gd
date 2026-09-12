extends GutTest

## Reglas de bonuses tacticos, ahora escritas UNA sola vez en CombatMath y usadas
## por los dos mundos: BattleFront (juego real) y el snapshot del MCTS.
##
## Los bonuses son siempre TacticBonus tipados en los dos mundos.


func _bonus(tactic_name: String, duration: int) -> TacticBonus:
	var b := TacticBonus.new()
	b.tactic_name = tactic_name
	b.duration = duration
	return b


# --- tick_bonuses ----------------------------------------------------------

func test_los_bonuses_con_duracion_caducan() -> void:
	var bonuses: Array[TacticBonus] = [_bonus("Carga", 2)]
	CombatMath.tick_bonuses(bonuses)
	assert_eq(bonuses.size(), 1, "con duracion 2 aun no caduca")
	assert_eq((bonuses[0] as TacticBonus).duration, 1)
	CombatMath.tick_bonuses(bonuses)
	assert_eq(bonuses.size(), 0, "al llegar a 0 se elimina")


func test_los_bonuses_de_duracion_negativa_son_permanentes() -> void:
	var bonuses: Array[TacticBonus] = [_bonus("Fortaleza", -1)]
	for i in range(5):
		CombatMath.tick_bonuses(bonuses)
	assert_eq(bonuses.size(), 1, "duracion negativa = permanente, no caduca nunca")


# --- clear_tactics ---------------------------------------------------------

func test_clear_tactics_solo_quita_las_tacticas() -> void:
	# tactic_name vacio = bonus plano (manual, de evento o de edificio): NO se toca.
	var bonuses: Array[TacticBonus] = [_bonus("Carga", 3), _bonus("", 3), _bonus("Falange", 3)]
	var quitadas := CombatMath.clear_tactics(bonuses)
	assert_eq(quitadas, 2, "devuelve cuantas tacticas quito")
	assert_eq(bonuses.size(), 1, "el bonus plano sobrevive")
	assert_eq((bonuses[0] as TacticBonus).tactic_name, "")


func test_clear_tactics_sin_tacticas_no_quita_nada() -> void:
	var bonuses: Array[TacticBonus] = [_bonus("", 3)]
	assert_eq(CombatMath.clear_tactics(bonuses), 0)
	assert_eq(bonuses.size(), 1)


# --- has_active_tactic -----------------------------------------------------

func test_has_active_tactic_distingue_tactica_de_bonus_plano() -> void:
	assert_false(CombatMath.has_active_tactic([_bonus("", 3)]),
		"un bonus plano no es una tactica activa")
	assert_true(CombatMath.has_active_tactic([_bonus("", 3), _bonus("Carga", 3)]))
