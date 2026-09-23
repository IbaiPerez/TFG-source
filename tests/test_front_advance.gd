extends GutTest

## Ofensivas: el frente que gana se reabre una casilla más adentro (FrontAdvance),
## en el juego (BattleFrontManager) y en su espejo del snapshot (AIRealCombat).
##
## Mapa de prueba. A y B son del atacante; D, Y, X del defensor. El frente es A→D.
##
##     A ─ D ─ Y            vecinas de D, en orden: A, Y, X
##          \
##           X ─ B          X toca D y B; Y solo toca D
##
## Tras conquistar D, las candidatas son Y (1 vecina del atacante: D) y X (2: D y
## B). Y va primero en el orden de vecinas. X lleva una Fortaleza: así CONSOLIDATE
## elige X (más rodeada) y WEAKEST elige Y (sin fortificar).

const A := 0
const D := 1
const X := 2
const Y := 3
const B := 4
const NEIGHBORS := {A: [D], D: [A, Y, X], X: [D, B], Y: [D], B: [X]}
const ATTACKER_TILES := [A, B]


func _fortress() -> Building:
	var b := Building.new()
	b.name = "Fortaleza"
	b.flat_defense_bonus = 5
	return b


func _troop() -> Troop:
	return TestBuilders.troop().with_name("T").with_attack(5).with_defense(1) \
		.with_recruit_cost(10).with_maintenance(2, 1).build()


## La casilla que el criterio vigente debe elegir en el mapa de prueba.
func _expected_target() -> int:
	return X if GameBalance.FRONT_ADVANCE_CRITERION \
		== GameBalance.FrontAdvanceCriterion.CONSOLIDATE else Y


# ============================================================
#  La regla (FrontAdvance)
# ============================================================

func _easy_and_hard_biomes() -> Array[int]:
	var easy := Tile.biome_type.Grassland
	var hard := Tile.biome_type.Mountain
	var ce := FrontAdvance.candidate(0, [] as Array[Building], easy)
	var ch := FrontAdvance.candidate(0, [] as Array[Building], hard)
	var ordered: Array[int] = []
	ordered.assign([easy, hard] if ce.difficulty < ch.difficulty else [hard, easy])
	return ordered


func test_consolidar_prefiere_la_casilla_mas_rodeada_aunque_sea_dura() -> void:
	var biomes := _easy_and_hard_biomes()
	var cands: Array[FrontAdvance.Candidate] = [
		FrontAdvance.candidate(1, [] as Array[Building], biomes[0]),
		FrontAdvance.candidate(3, [_fortress()] as Array[Building], biomes[1]),
	]
	assert_eq(FrontAdvance.pick(cands, GameBalance.FrontAdvanceCriterion.CONSOLIDATE), 1)
	assert_eq(FrontAdvance.pick(cands, GameBalance.FrontAdvanceCriterion.WEAKEST), 0,
		"el punto débil elige la fácil aunque esté menos rodeada")


func test_los_desempates_van_en_cadena() -> void:
	var biomes := _easy_and_hard_biomes()
	var none: Array[Building] = []
	var fort: Array[Building] = [_fortress()]
	for criterion in GameBalance.FrontAdvanceCriterion.values():
		var sin_fortificar: Array[FrontAdvance.Candidate] = [
			FrontAdvance.candidate(2, fort, biomes[0]), FrontAdvance.candidate(2, none, biomes[0])]
		assert_eq(FrontAdvance.pick(sin_fortificar, criterion), 1, "sin Fortaleza antes")
		var bioma: Array[FrontAdvance.Candidate] = [
			FrontAdvance.candidate(2, none, biomes[1]), FrontAdvance.candidate(2, none, biomes[0])]
		assert_eq(FrontAdvance.pick(bioma, criterion), 1, "bioma más fácil antes")
		var empate: Array[FrontAdvance.Candidate] = [
			FrontAdvance.candidate(2, none, biomes[0]), FrontAdvance.candidate(2, none, biomes[0])]
		assert_eq(FrontAdvance.pick(empate, criterion), 0, "empate total: la primera")
	assert_eq(FrontAdvance.pick([] as Array[FrontAdvance.Candidate]), -1)


# ============================================================
#  Mundo vivo (BattleFrontManager)
# ============================================================

var _atk: Empire
var _def: Empire
var _tiles := {}
var _manager: BattleFrontManager


## Lo que hace TilesTracker en la partida (vía bus, en el acto): la casilla
## conquistada pasa a ser del ganador. Aquí no hay escena que lo haga.
func _change_controller(tile: Tile, new_controller: Empire) -> void:
	tile.controller = new_controller


func before_each() -> void:
	BattleFront.clear_active_instances()
	if not Events.change_tile_controller.is_connected(_change_controller):
		Events.change_tile_controller.connect(_change_controller)
	_atk = Empire.new()
	_def = Empire.new()
	_tiles = {}
	for id in NEIGHBORS:
		var owner := _atk if id in ATTACKER_TILES else _def
		_tiles[id] = autofree(TestBuilders.tile().with_biome(Tile.biome_type.Grassland) \
			.with_resource(0, 0).with_controller(owner).build())
	for id in NEIGHBORS:
		var nbrs: Array[Tile] = []
		for n in NEIGHBORS[id]:
			nbrs.append(_tiles[n])
		(_tiles[id] as Tile).neighbors = nbrs
	(_tiles[X] as Tile).buildings.append(_fortress())
	_atk.controlled_tiles = [_tiles[A], _tiles[B]]
	var stats := Stats.new()
	stats.troop_pool = []
	stats.empire = _atk
	_manager = BattleFrontManager.new()
	_manager.stats = stats
	add_child_autofree(_manager)


func after_each() -> void:
	BattleFront.clear_active_instances()
	if Events.change_tile_controller.is_connected(_change_controller):
		Events.change_tile_controller.disconnect(_change_controller)


## Abre A→D con tropas y lo resuelve con el marcador a favor de `attacker_wins`.
func _resolve_live(step: int, attacker_wins: bool) -> BattleFront:
	var front := _manager.open_front(_tiles[A], _tiles[D])
	front.campaign_step = step
	for i in 4:
		front.attacker_troops.append(_troop())
	front.turns_elapsed = front.min_duration
	front.marker = 1000.0 if attacker_wins else -1000.0
	front._resolve()
	return front


func test_ganar_reabre_el_frente_desde_la_casilla_conquistada() -> void:
	var old := _resolve_live(1, true)
	assert_eq(_manager.active_fronts.size(), 1, "la ofensiva sigue")
	var next := _manager.active_fronts[0]
	assert_eq(next.attacker_tile, _tiles[D], "desde la casilla conquistada")
	assert_eq(next.defender_tile, _tiles[_expected_target()], "hacia la que dicta el criterio")
	assert_eq(next.campaign_step, 2)
	var survivors := 4 - int(old.get_resolved_casualties()["attacker_losses"])
	assert_eq(next.attacker_troops.size(), survivors, "las supervivientes pasan al frente nuevo")
	assert_eq(_manager.stats.troop_pool.size(), 0, "y no se quedan en el pool")


func test_la_ofensiva_para_en_el_tope() -> void:
	_resolve_live(GameBalance.FRONT_CAMPAIGN_TILES, true)
	assert_eq(_manager.active_fronts.size(), 0, "última casilla: no reabre")
	assert_gt(_manager.stats.troop_pool.size(), 0, "las tropas vuelven al pool")


func test_si_gana_el_defensor_no_hay_avance() -> void:
	_resolve_live(1, false)
	assert_eq(_manager.active_fronts.size(), 0)


func test_sin_casillas_enemigas_libres_la_ofensiva_termina() -> void:
	for id in [X, Y]:
		(_tiles[id] as Tile).controller = _atk
	_resolve_live(1, true)
	assert_eq(_manager.active_fronts.size(), 0)


# ============================================================
#  Snapshot (AIRealCombat) y paridad
# ============================================================

func _snapshot(fortified: int) -> AIRealState:
	var s := AIRealState.new()
	for id in NEIGHBORS:
		var t := AIRealState.TileSnap.new()
		t.id = id
		t.biome = Tile.biome_type.Grassland
		t.owner = AIRealState.OWNER_SELF if id in ATTACKER_TILES else AIRealState.OWNER_RIVAL
		var nbrs: Array[int] = []
		nbrs.assign(NEIGHBORS[id])
		t.neighbor_ids = nbrs
		if id == fortified:
			t.buildings.append(_fortress())
		s.tiles[id] = t
	return s


func _resolve_snapshot(s: AIRealState, step: int) -> AIRealState.FrontSnap:
	var fs := AIRealEffects.apply_open_front(s, A, D, AIRealState.OWNER_SELF)
	fs.campaign_step = step
	for i in 4:
		fs.attacker_troops.append(_troop())
	fs.turns_elapsed = fs.min_duration
	fs.marker = 1000.0
	AIRealCombat._resolve_front(s, fs)
	return fs


func _open_snapshot_fronts(s: AIRealState) -> Array:
	return s.fronts.filter(func(f): return not (f as AIRealState.FrontSnap).is_resolved)


func test_el_snapshot_reabre_igual_que_el_juego() -> void:
	var s := _snapshot(X)
	_resolve_snapshot(s, 1)
	var open := _open_snapshot_fronts(s)
	assert_eq(open.size(), 1, "la ofensiva sigue")
	var next := open[0] as AIRealState.FrontSnap
	assert_eq(next.attacker_tile_id, D)
	assert_eq(next.defender_tile_id, _expected_target(), "misma casilla que el juego")
	assert_eq(next.campaign_step, 2)
	assert_gt(next.attacker_troops.size(), 0, "con las supervivientes dentro")
	assert_eq(s.own.troop_pool.size(), 0)


func test_el_snapshot_para_en_el_tope() -> void:
	var s := _snapshot(X)
	_resolve_snapshot(s, GameBalance.FRONT_CAMPAIGN_TILES)
	assert_eq(_open_snapshot_fronts(s).size(), 0)


## Sin Fortaleza en X, CONSOLIDATE sigue eligiendo X y WEAKEST empata en defensa y
## bioma y cae a la más rodeada. Con la Fortaleza en Y, los dos criterios coinciden.
## En todos los casos los dos mundos tienen que elegir la misma casilla.
func test_los_dos_mundos_eligen_la_misma_casilla() -> void:
	for fortified in [X, Y, -1]:
		before_each()
		for id in [X, Y]:
			(_tiles[id] as Tile).buildings.clear()
		if fortified >= 0:
			(_tiles[fortified] as Tile).buildings.append(_fortress())
		_resolve_live(1, true)
		var live_target: Tile = _manager.active_fronts[0].defender_tile
		var s := _snapshot(fortified)
		_resolve_snapshot(s, 1)
		var snap_target: int = (_open_snapshot_fronts(s)[0] as AIRealState.FrontSnap).defender_tile_id
		assert_eq(live_target, _tiles[snap_target], "Fortaleza en %d" % fortified)
		after_each()
