extends GutTest

## `open_front_win_factor` estima P(ganar) al abrir un frente: es lo que decide la
## jugada más cara del juego. No tenía NI UN test, y acumulaba dos desalineaciones
## contra el motor de combate real (CombatMath):
##
##   1. El `combat_multiplier` del imperio —la penalización por déficit económico,
##      que deja las tropas hasta al 10 % de sus stats— se ignoraba por completo.
##   2. El multiplicador defensivo del BIOMA se aplicaba a los EDIFICIOS en vez de
##      a las TROPAS, que es al revés de lo que hace CombatMath.total_defense.
##
## La referencia de estos tests es el propio motor:
##
##     total_defense = defensa_edificios + defensa_tropas · bioma · combat_mult
##     total_attack  = ...              + ataque_tropas  · bioma · combat_mult
##
## Los edificios quedan PLANOS en los dos multiplicadores; solo las tropas pasan por
## ellos. Donde se puede, se afirma que la heurística ORDENA igual que CombatMath,
## en vez de comparar contra una cifra elegida a mano.


func _w() -> HeuristicWeights:
	return HeuristicWeights.new()


func before_each() -> void:
	BattleFront.clear_active_instances()


func after_each() -> void:
	BattleFront.clear_active_instances()


# ---------------------------------------------------------------------------
# Escenarios
# ---------------------------------------------------------------------------

## P(ganar) en el mundo vivo para una casilla enemiga con `def_edificio` de defensa
## en edificios y `def_tropas` en tropas comprometidas, sobre `bioma`.
## `biome_factor` (el de ATAQUE) se pasa como 1.0 a propósito: aquí se mide la
## defensa, y mezclar los dos biomas ocultaría lo que se está probando.
func _p_vivo(bioma: Tile.biome_type, def_edificio: int, def_tropas: int,
		mi_mult := 1.0, rival_mult := 1.0) -> float:
	var mio := Empire.new()
	mio.name = "Propio"
	mio.combat_multiplier = mi_mult
	var rival := Empire.new()
	rival.name = "Rival"
	rival.combat_multiplier = rival_mult

	var tropas: Array = []
	for i in range(3):
		tropas.append(TestBuilders.troop().with_attack(5).with_defense(1).build())
	var stats := TestBuilders.stats().with_empire(mio).with_troop_pool(tropas).build()

	var vista := AIEmpirePublicView.new()
	vista.empire = rival
	var vistas: Array[AIEmpirePublicView] = [vista]
	var wv := AIWorldView.new()
	wv.own_stats = stats
	wv.rival_views = vistas
	var ctx := TestBuilders.context(stats).with_world_view(wv).build()

	var edificios: Array = []
	if def_edificio > 0:
		edificios.append(TestBuilders.building().with_defense(def_edificio).build())
	var enemiga := TestBuilders.tile().with_biome(bioma).with_buildings(edificios).build()
	add_child_autofree(enemiga)

	if def_tropas > 0:
		var propia := TestBuilders.tile().with_biome(bioma).build()
		add_child_autofree(propia)
		var f := BattleFront.new(propia, enemiga, mio, rival)
		f.defender_troops = [
			TestBuilders.troop().with_defense(def_tropas).build()] as Array[Troop]

	return LiveStateView.new(ctx).open_front_win_factor(enemiga, 1.0)


## Mismo escenario sobre el snapshot.
func _p_snap(bioma: Tile.biome_type, def_edificio: int, def_tropas: int,
		mi_mult := 1.0, rival_mult := 1.0) -> float:
	var s := AIRealState.new()
	s.total_map_tiles = 100
	s.own.combat_multiplier = mi_mult
	s.rival.combat_multiplier = rival_mult
	var tropas: Array[Troop] = []
	for i in range(3):
		tropas.append(TestBuilders.troop().with_attack(5).with_defense(1).build())
	s.own.troop_pool = tropas

	var t := AIRealState.TileSnap.new()
	t.id = 1
	t.biome = bioma
	t.owner = AIRealState.OWNER_RIVAL
	if def_edificio > 0:
		var blds: Array[Building] = [
			TestBuilders.building().with_defense(def_edificio).build()]
		t.buildings = blds
	s.tiles[1] = t

	if def_tropas > 0:
		var fs := AIRealState.FrontSnap.new()
		fs.attacker_owner = AIRealState.OWNER_SELF
		fs.defender_owner = AIRealState.OWNER_RIVAL
		fs.defender_tile_id = 1
		fs.defender_troops = [
			TestBuilders.troop().with_defense(def_tropas).build()] as Array[Troop]
		s.fronts = [fs]

	return SnapshotStateView.new(s, AIRealState.OWNER_SELF, _w()) \
		.open_front_win_factor(s.tiles[1], 1.0)


# ---------------------------------------------------------------------------
# Defecto 1 · combat_multiplier
# ---------------------------------------------------------------------------

func test_mi_colapso_economico_baja_la_probabilidad_estimada_de_ganar() -> void:
	assert_lt(_p_vivo(Tile.biome_type.Tundra, 5, 0, 0.1, 1.0),
		_p_vivo(Tile.biome_type.Tundra, 5, 0, 1.0, 1.0),
		"con las tropas al 10 % por déficit, atacar debe estimarse peor")


func test_el_rival_arruinado_se_estima_mas_facil_de_batir() -> void:
	# El multiplicador del rival solo se nota si TIENE tropas: los edificios no
	# pasan por él.
	assert_gt(_p_vivo(Tile.biome_type.Tundra, 0, 20, 1.0, 0.1),
		_p_vivo(Tile.biome_type.Tundra, 0, 20, 1.0, 1.0),
		"un rival con sus tropas al 10 % debe estimarse más fácil de batir")


func test_el_multiplicador_del_rival_no_toca_la_defensa_de_edificios() -> void:
	# Guarda de la mitad "plana" de la regla: sin tropas, arruinar al rival no
	# cambia nada, porque sus edificios defienden igual.
	assert_almost_eq(_p_vivo(Tile.biome_type.Tundra, 10, 0, 1.0, 0.1),
		_p_vivo(Tile.biome_type.Tundra, 10, 0, 1.0, 1.0), 0.001,
		"los edificios no sufren la penalización económica")


func test_snapshot_replica_el_efecto_del_multiplicador() -> void:
	assert_lt(_p_snap(Tile.biome_type.Tundra, 5, 0, 0.1, 1.0),
		_p_snap(Tile.biome_type.Tundra, 5, 0, 1.0, 1.0),
		"propio déficit: el snapshot debe penalizar igual que el vivo")
	assert_gt(_p_snap(Tile.biome_type.Tundra, 0, 20, 1.0, 0.1),
		_p_snap(Tile.biome_type.Tundra, 0, 20, 1.0, 1.0),
		"déficit del rival: el snapshot debe verlo igual que el vivo")


# ---------------------------------------------------------------------------
# Defecto 2 · a qué término aplica el bioma defensivo
# ---------------------------------------------------------------------------

## Ordenación de referencia del MOTOR: en montaña, ¿defienden más 10 puntos en
## tropas o 10 en edificios? Devuelve [solo_edificios, solo_tropas].
func _defensa_segun_el_motor(bioma: Tile.biome_type, puntos: int) -> Array:
	var mult := BiomeConfig.shared().get_defense_multiplier(bioma)
	var sin_tropas: Array[Troop] = []
	var con_tropas: Array[Troop] = [
		TestBuilders.troop().with_defense(puntos).build()]
	var sin_bonus: Array = []
	return [
		CombatMath.total_defense(sin_tropas, sin_bonus, mult, 1.0, float(puntos)),
		CombatMath.total_defense(con_tropas, sin_bonus, mult, 1.0, 0.0),
	]


func test_el_bioma_defensivo_escala_las_tropas_no_los_edificios() -> void:
	# Referencia: con el mismo número de puntos de defensa, en MONTAÑA las tropas
	# defienden más que los edificios, porque solo ellas pasan por el bioma.
	var motor := _defensa_segun_el_motor(Tile.biome_type.Mountain, 10)
	assert_gt(motor[1], motor[0],
		"precondición: CombatMath escala las tropas, no los edificios")

	# La heurística debe ORDENARLO IGUAL: más defensa ⇒ menor P(ganar).
	var p_edificios := _p_vivo(Tile.biome_type.Mountain, 10, 0)
	var p_tropas := _p_vivo(Tile.biome_type.Mountain, 0, 10)
	assert_lt(p_tropas, p_edificios,
		"en montaña, 10 puntos en tropas deben estimarse más duros que 10 en edificios")


func test_en_bioma_neutro_da_igual_donde_este_la_defensa() -> void:
	# Control: con multiplicador 1.0 el reparto es irrelevante. Si este test
	# fallara, el anterior estaría midiendo otra cosa distinta del bioma.
	assert_almost_eq(BiomeConfig.shared().get_defense_multiplier(Tile.biome_type.Tundra),
		1.0, 0.001, "precondición: Tundra es el bioma defensivamente neutro")
	assert_almost_eq(_p_vivo(Tile.biome_type.Tundra, 10, 0),
		_p_vivo(Tile.biome_type.Tundra, 0, 10), 0.001,
		"sin efecto de bioma, edificios y tropas deben pesar igual")


func test_atacar_montana_se_estima_mas_duro_que_atacar_pradera() -> void:
	# La consecuencia que importa en juego: el terreno defensivo debe disuadir. Con
	# el bug, la defensa por TROPAS en montaña no se escalaba y la montaña salía
	# igual de blanda que la pradera.
	assert_lt(_p_vivo(Tile.biome_type.Mountain, 0, 10),
		_p_vivo(Tile.biome_type.Grassland, 0, 10),
		"defender tropas en montaña debe valer más que en pradera")


func test_snapshot_aplica_el_bioma_al_mismo_termino_que_el_vivo() -> void:
	assert_lt(_p_snap(Tile.biome_type.Mountain, 0, 10),
		_p_snap(Tile.biome_type.Mountain, 10, 0),
		"el snapshot debe escalar las tropas, no los edificios")


# ---------------------------------------------------------------------------
# Paridad entre mundos
# ---------------------------------------------------------------------------

func test_vivo_y_snapshot_estiman_lo_mismo() -> void:
	# Escenario con las dos correcciones activas a la vez: bioma no neutro,
	# defensa repartida entre edificios y tropas, y déficit en ambos imperios.
	assert_almost_eq(
		_p_vivo(Tile.biome_type.Mountain, 8, 6, 0.4, 0.7),
		_p_snap(Tile.biome_type.Mountain, 8, 6, 0.4, 0.7), 0.001,
		"mismo escenario → misma estimación en los dos mundos")


func test_el_factor_sigue_acotado_a_su_banda() -> void:
	var w := _w()
	assert_between(_p_vivo(Tile.biome_type.Mountain, 200, 200), w.openfront_win_min,
		w.openfront_win_max, "defensa abrumadora: no baja del suelo")
	assert_between(_p_vivo(Tile.biome_type.Grassland, 0, 0), w.openfront_win_min,
		w.openfront_win_max, "sin defensa: no supera el techo")
