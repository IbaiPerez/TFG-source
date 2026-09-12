extends GutTest

## Barrido del CATÁLOGO de eventos de turno: todos los `.tres` de
## `resources/turn_events/`, cargados por la misma vía que el juego
## (`TurnEventLoader.load_all`, la que usan `map.gd` y el serializador).
##
## `test_turn_events.gd` prueba la MAQUINARIA (condiciones, efectos, costes,
## manager) con eventos sintéticos. Esto prueba los EVENTOS CONCRETOS: 28 clases
## de evento, sus condiciones y sus efectos escalados no se instanciaban en
## ningún test, y una clave i18n rota o un efecto null en un `_init()` solo se
## veía al caerle el evento a un jugador.
##
## Todo va por bucle sobre el catálogo: añadir un evento lo mete aquí solo.

const EVENTS_DIR := TurnEventLoader.EVENTS_DIR
const CSV_PATH := "res://localization/translations.csv"

var _events: Array[TurnEvent] = []
var _csv_keys: Dictionary = {}


func before_all() -> void:
	_events = TurnEventLoader.load_all()
	_csv_keys = _load_csv_keys()


func before_each() -> void:
	TestWorld.reset()


func after_each() -> void:
	TestWorld.reset()


# ============================================================
#  Fixture: un imperio en el que TODOS los eventos tienen algo que hacer
# ============================================================

## Ciudad con 3 edificios (elegible para Megalópolis), una aldea, una vecina
## libre (para colonizar), oro de sobra para cualquier coste, mazo con cartas
## que purgar y un pool de desbloqueadas del que ofrecer.
func _rich_stats() -> Stats:
	var buildings: Array = []
	for i in range(3):
		buildings.append(TestBuilders.building().with_name("b%d" % i).build())
	var town := TestBuilders.tile().with_location(Tile.location_type.Town, 4) \
		.with_buildings(buildings).build()
	var village := TestBuilders.tile().build()
	var free := TestBuilders.tile().build()
	add_child_autofree(town)
	add_child_autofree(village)
	add_child_autofree(free)
	town.neighbors = [village, free]
	village.neighbors = [town]
	free.neighbors = [town]

	var stats := TestBuilders.stats().with_turn(20).with_gold(1000).with_gpt(100) \
		.with_food(50).with_tiles([town, village]).with_event_chance(1.0).build()
	stats.used_unique_events = []
	stats.available_events = []
	stats.unlocked_card_pool = []
	stats.shop_exclusive_pool = []
	for i in range(4):
		stats.draw_pile.add_card(_card("deck%d" % i))
	stats.unlocked_card_pool.append(UnlockedCardEntry.new(_card("pool"), 5.0, 0.0, 1.0))
	return stats


func _card(id: String) -> Card:
	var c := CardDrawCard.new()
	c.id = id
	c.type = Card.Type.BASIC
	c.amount = 1
	c.target = Card.Target.SELF
	return c


func _context(stats: Stats) -> EventContext:
	var mgr := ModifierManager.new()
	add_child_autofree(mgr)
	return EventContext.build(stats, mgr, stats.turn_number)


func _manager(stats: Stats) -> TurnEventManager:
	var mgr := TurnEventManager.new()
	mgr.stats = stats
	add_child_autofree(mgr)
	return mgr


func _load_csv_keys() -> Dictionary:
	var keys: Dictionary = {}
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		return keys
	file.get_csv_line()  # cabecera
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() > 0 and row[0] != "":
			keys[row[0]] = true
	file.close()
	return keys


func _tres_files() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(EVENTS_DIR)
	assert_not_null(dir, "debe poder abrirse %s" % EVENTS_DIR)
	if dir == null:
		return out
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.ends_with(".tres"):
			out.append(f)
		f = dir.get_next()
	dir.list_dir_end()
	return out


# ============================================================
#  Carga
# ============================================================

## El cargador descarta en silencio lo que no carga como TurnEvent, así que un
## evento roto simplemente desaparecería del juego. Se cuadra el recuento contra
## el directorio: cada .tres es un TurnEvent o la tabla de pesos por categoría.
func test_el_cargador_devuelve_todos_los_eventos_del_directorio() -> void:
	var esperados := 0
	for f in _tres_files():
		var r := load(EVENTS_DIR + f)
		assert_not_null(r, "%s no carga" % f)
		if r is TurnEvent:
			esperados += 1
		else:
			assert_true(r is EventCategoryWeights,
				"%s no es TurnEvent ni EventCategoryWeights: no debería estar en el catálogo" % f)
	assert_gt(esperados, 40, "el catálogo tiene decenas de eventos")
	assert_eq(_events.size(), esperados,
		"load_all() debe devolver exactamente los TurnEvent del directorio")


func test_los_ids_son_unicos_y_coinciden_con_el_nombre_del_fichero() -> void:
	var vistos: Dictionary = {}
	for ev in _events:
		assert_ne(ev.id, "", "%s sin id" % ev.resource_path)
		assert_false(vistos.has(ev.id), "id repetido: %s" % ev.id)
		vistos[ev.id] = true
		var esperado := ev.resource_path.get_file().get_basename()
		assert_eq(ev.id, esperado, "el id debe coincidir con el fichero (%s)" % ev.resource_path)


# ============================================================
#  Textos
# ============================================================

func test_titulo_y_descripcion_son_claves_del_csv() -> void:
	for ev in _events:
		assert_true(_csv_keys.has(ev.title),
			"%s: title '%s' no está en el CSV" % [ev.id, ev.title])
		assert_true(_csv_keys.has(ev.description),
			"%s: description '%s' no está en el CSV" % [ev.id, ev.description])


## Las etiquetas se traducen con tr() al construir el evento: si la clave no
## existe, tr() devuelve la clave y el jugador ve "EVT_X_CH1_LABEL" en el botón.
func test_las_opciones_tienen_etiqueta_traducida_y_efectos_no_nulos() -> void:
	var stats := _rich_stats()
	var ctx := _context(stats)
	var opciones := 0
	for ev in _events:
		ev.prepare(ctx)
		if ev is ShopEvent:
			continue  # la tienda no tiene opciones: abre un panel propio
		assert_gt(ev.choices.size(), 0, "%s no tiene opciones" % ev.id)
		for c in ev.choices:
			opciones += 1
			assert_not_null(c, "%s: opción null" % ev.id)
			assert_ne(c.label, "", "%s: opción sin etiqueta" % ev.id)
			assert_false(c.label.begins_with("EVT_"),
				"%s: etiqueta sin traducir '%s'" % [ev.id, c.label])
			assert_false(c.description.begins_with("EVT_"),
				"%s: descripción sin traducir '%s'" % [ev.id, c.description])
			for e in c.effects:
				assert_not_null(e, "%s / '%s': efecto null" % [ev.id, c.label])
	assert_gt(opciones, 50, "el catálogo suma decenas de opciones")


# ============================================================
#  Condiciones
# ============================================================

func test_las_condiciones_se_evaluan_sobre_un_contexto_real() -> void:
	var ctx := _context(_rich_stats())
	var condiciones := 0
	for ev in _events:
		for c in ev.conditions:
			assert_not_null(c, "%s: condición null" % ev.id)
			if c == null:
				continue
			condiciones += 1
			assert_typeof(c.is_met(ctx), TYPE_BOOL, "%s: is_met debe devolver bool" % ev.id)
		assert_typeof(ev.is_available(ctx), TYPE_BOOL, "%s: is_available debe devolver bool" % ev.id)
	assert_gt(condiciones, 40, "el catálogo suma decenas de condiciones")


# ============================================================
#  Ejecución: el camino del JUGADOR (TurnEventPanel) y el de la IA
# ============================================================

## Lo que hace el panel al pulsar una opción sin input extra: pagar y ejecutar.
## Cada opción sobre un imperio recién construido, para que no se contaminen.
func test_cada_opcion_sin_input_del_jugador_se_ejecuta_sobre_un_imperio_de_prueba() -> void:
	var ejecutadas := 0
	for ev in _events:
		if ev is ShopEvent:
			continue
		for c in ev.choices:
			if c == null or c.needs_player_input():
				continue
			var stats := _rich_stats()
			var ctx := _context(stats)
			var oro_antes := stats.total_gold
			assert_true(c.is_affordable(ctx),
				"%s / '%s': con 1000 de oro toda opción debe ser asequible" % [ev.id, c.label])
			c.execute(ctx)
			ejecutadas += 1
			if c.cost != null and c.cost.gold(ctx) > 0:
				assert_lt(stats.total_gold, oro_antes,
					"%s / '%s': la opción tiene coste y no se cobró" % [ev.id, c.label])
	assert_gt(ejecutadas, 30, "deben haberse ejecutado decenas de opciones")


## El camino de la IA, con paneles incluidos (tienda, elegir carta, elegir
## casilla): es el que se recorre en cada partida simulada y en cada turno rival.
func test_la_ia_resuelve_cada_evento_del_catalogo() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260911
	for ev in _events:
		var stats := _rich_stats()
		var ctx := _context(stats)
		ev.prepare(ctx)
		AIEventResolver.resolve(ev, ctx, rng, _manager(stats))
		assert_true(stats.total_gold >= 0, "%s: la IA no puede dejar el oro en negativo" % ev.id)
		if ev.unique:
			assert_has(stats.used_unique_events, ev.id,
				"%s es unique y la IA no lo marcó como usado" % ev.id)
		else:
			assert_does_not_have(stats.used_unique_events, ev.id,
				"%s no es unique y no debe marcarse" % ev.id)
