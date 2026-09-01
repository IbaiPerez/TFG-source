extends GutTest

## Los modifiers de `TROOP_MAINTENANCE_PERCENT` (p. ej. la Horda Nómada, que abarata
## la caballería) deben abaratar la tropa TAMBIÉN cuando está guarnecida en un frente.
##
## No era así: `ProductionCalculator` aplicaba el descuento por-tropa al mantenimiento
## del pool, pero el coste del frente lo cobraba sin descuento. Cuando ese coste era
## un recargo PLANO —(i+1)·5, ajeno a la tropa— tenía sentido y estaba documentado.
## Al pasar a cobrar el mantenimiento BASE multiplicado, dejó de tenerlo: el
## modificador del imperio se apagaba en silencio en cuanto la tropa se desplegaba,
## que es justo cuando más cuesta.
##
## El descuento es POR TROPA (`troop_type_filter`), así que no puede aplicarse como
## un factor global al total del frente: una guarnición mixta lo necesita tropa a
## tropa. Estos tests fijan eso.


const DESCUENTO := -25.0


func _mods_caballeria() -> Array[Modifier]:
	return [StatModifier.new("m", "-25% mant caballería",
		StatModifier.StatType.TROOP_MAINTENANCE_PERCENT, DESCUENTO, -1,
		null, null, Troop.TroopType.CABALLERIA)] as Array[Modifier]


func _troop(tipo: int, oro: int, comida: int) -> Troop:
	var t := TestBuilders.troop().with_type(tipo).with_maintenance(oro, comida).build()
	return t


# ---------------------------------------------------------------------------
# Mundo vivo
# ---------------------------------------------------------------------------

var _front: BattleFront


func before_each() -> void:
	BattleFront.clear_active_instances()
	var atk := TestBuilders.tile().build()
	var def := TestBuilders.tile().build()
	add_child_autofree(atk)
	add_child_autofree(def)
	_front = BattleFront.new(atk, def, Empire.new(), Empire.new())


func after_each() -> void:
	BattleFront.clear_active_instances()


## ModifierManager extiende Node: sin autofree queda huérfano al acabar el test.
func _manager_con(mods: Array[Modifier]) -> ModifierManager:
	var mm: ModifierManager = autofree(ModifierManager.new())
	for m in mods:
		mm.active_modifiers.append(m)
	return mm


func test_el_descuento_llega_a_las_tropas_guarnecidas() -> void:
	# EL test que discrimina: mismo frente, mismas tropas, con y sin el modificador.
	_front.assign_troop(_troop(Troop.TroopType.CABALLERIA, 20, 4), BattleFront.Side.ATTACKER)
	_front.assign_troop(_troop(Troop.TroopType.CABALLERIA, 20, 4), BattleFront.Side.ATTACKER)

	var sin_mod := _front.get_front_maintenance(BattleFront.Side.ATTACKER)
	var con_mod := _front.get_front_maintenance(
		BattleFront.Side.ATTACKER, _manager_con(_mods_caballeria()))

	assert_lt(con_mod["gold"], sin_mod["gold"],
		"el modificador debe abaratar la guarnición, no apagarse al desplegar")
	assert_lt(con_mod["food"], sin_mod["food"])


func test_el_filtro_por_tipo_se_respeta_dentro_del_frente() -> void:
	# Guarnición MIXTA: el descuento es por tropa, así que no puede aplicarse como un
	# porcentaje al total. Solo debe abaratar la caballería.
	_front.assign_troop(_troop(Troop.TroopType.PIQUEROS, 20, 4), BattleFront.Side.ATTACKER)
	var solo_piqueros := _front.get_front_maintenance(
		BattleFront.Side.ATTACKER, _manager_con(_mods_caballeria()))
	var solo_piqueros_sin := _front.get_front_maintenance(BattleFront.Side.ATTACKER)

	assert_eq(solo_piqueros["gold"], solo_piqueros_sin["gold"],
		"un modificador de caballería no puede abaratar a los piqueros")


func test_sin_modifiers_el_coste_no_cambia() -> void:
	# Guarda de no-regresión: pasar un manager vacío debe dar lo mismo que no pasarlo.
	_front.assign_troop(_troop(Troop.TroopType.CABALLERIA, 20, 4), BattleFront.Side.ATTACKER)
	var vacio: Array[Modifier] = []
	assert_eq(
		_front.get_front_maintenance(BattleFront.Side.ATTACKER, _manager_con(vacio))["gold"],
		_front.get_front_maintenance(BattleFront.Side.ATTACKER)["gold"])


func test_la_curva_del_frente_sigue_aplicandose_sobre_el_coste_ya_descontado() -> void:
	# El descuento no debe anular el recargo progresivo: siguen componiéndose.
	for i in range(3):
		_front.assign_troop(_troop(Troop.TroopType.CABALLERIA, 20, 4), BattleFront.Side.ATTACKER)
	var m := _front.get_front_maintenance(
		BattleFront.Side.ATTACKER, _manager_con(_mods_caballeria()))
	var base_descontada := 20.0 * ProductionMath.maintenance_multiplier(DESCUENTO)
	assert_gt(float(m["gold"]), base_descontada * 3.0,
		"tres tropas siguen costando más que tres veces una, aun con descuento")


# ---------------------------------------------------------------------------
# Paridad con el snapshot del MCTS
# ---------------------------------------------------------------------------

func test_el_snapshot_aplica_el_mismo_descuento_a_la_guarnicion() -> void:
	var mods := _mods_caballeria()
	var tropas: Array[Troop] = [
		_troop(Troop.TroopType.CABALLERIA, 20, 4),
		_troop(Troop.TroopType.CABALLERIA, 20, 4),
	]
	# Vivo
	for t in tropas:
		_front.assign_troop(t, BattleFront.Side.ATTACKER)
	var vivo := _front.get_front_maintenance(
		BattleFront.Side.ATTACKER, _manager_con(mods))

	# Snapshot: mismo frente, mismas tropas, mismos modifiers.
	var s := AIRealState.new()
	s.total_map_tiles = 10
	s.own.modifiers = mods
	var fs := AIRealState.FrontSnap.new()
	fs.attacker_owner = AIRealState.OWNER_SELF
	fs.defender_owner = AIRealState.OWNER_RIVAL
	fs.attacker_troops = tropas
	s.fronts = [fs]
	AIRealSimulator.recompute_own_economy(s)

	# Sin producción ni pool, el gpt es exactamente −coste de guarnición.
	assert_eq(-s.own.gold_per_turn, vivo["gold"],
		"los dos mundos deben cobrar la misma guarnición descontada")
	assert_eq(-s.own.food, vivo["food"])
