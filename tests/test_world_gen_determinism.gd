extends GutTest

## Verifica que la generación del mundo es DETERMINISTA respecto a la semilla:
## misma semilla (+ misma forma/radio) ⇒ mundo IDÉNTICO en biomas, recursos
## naturales, nombres de provincia y colocación de imperios; y que una semilla
## DISTINTA produce un mundo distinto (la semilla realmente gobierna la generación).
##
## Monta el WorldGenerator real headless (igual que game_sim_harness): tiles,
## biomas, agua/montañas, recursos y colocación de imperios vía EmpireCreator +
## TilesTracker. La "huella" por tile captura todo lo que debe ser reproducible.

const DEFAULT_SETTINGS := preload("res://resources/world_settings/Default.tres")
const TILES_TRACKER_SCRIPT := preload("res://scripts/tile/tiles_tracker.gd")
const WORLD_GENERATOR := preload("res://scripts/world_gen/world_generator.gd")

const SEED_A := 12345
const SEED_B := 987654321
const RADIUS := 6


## Genera un mundo con la semilla/radio dados y devuelve una "huella" por tile
## (posición | bioma | recurso | provincia | imperio) en el orden de WorldMap.map.
func _generate_fingerprint(seed_value: int, radius: int) -> Array:
	BattleFront.clear_active_instances()
	WorldMap.map = []
	WorldMap.map_as_dict = {}

	# Un raíz por generación: tiles + tracker + generator cuelgan aquí y se liberan
	# en bloque para no arrastrar estado (ni doble TilesTracker) a la siguiente.
	var run_root := Node.new()
	run_root.name = "DetRunRoot"
	add_child(run_root)

	# TilesTracker: EmpireCreator emite change_tile_controller y el tracker es quien
	# asigna tile.controller (la colocación de imperios que queremos comparar).
	var tracker := Node.new()
	tracker.set_script(TILES_TRACKER_SCRIPT)
	run_root.add_child(tracker)

	# Duplicar a fondo para no mutar el Default.tres global entre generaciones.
	var settings := DEFAULT_SETTINGS.duplicate(true) as GenerationSettings
	settings.map_seed = seed_value
	settings.radius = radius
	settings.debug = false

	var tile_parent := Node3D.new()
	tile_parent.name = "TileParent"
	run_root.add_child(tile_parent)

	var generator := WORLD_GENERATOR.new()
	generator.auto_generate_on_ready = false
	generator.settings = settings
	generator.tile_parent = tile_parent
	run_root.add_child(generator)
	generator.init_seed()
	generator.generate_world()

	var fingerprint: Array = []
	for tile in WorldMap.map:
		var gp: Vector2 = tile.pos_data.grid_position
		var biome: String = str(tile.biome)
		var resource_name: String = tile.natural_resource.name if tile.natural_resource != null else "-"
		var province: String = str(tile.province_name)
		var controller: String = tile.controller.name if tile.controller != null else "-"
		fingerprint.append("%d,%d|%s|%s|%s|%s" % [
			int(gp.x), int(gp.y), biome, resource_name, province, controller])

	# Limpieza: liberar el raíz y esperar un frame a que queue_free se procese.
	run_root.queue_free()
	WorldMap.map = []
	WorldMap.map_as_dict = {}
	BattleFront.clear_active_instances()
	await get_tree().process_frame

	return fingerprint


func test_same_seed_generates_identical_world() -> void:
	var fp1 := await _generate_fingerprint(SEED_A, RADIUS)
	var fp2 := await _generate_fingerprint(SEED_A, RADIUS)

	assert_gt(fp1.size(), 0, "La generación debe producir tiles")
	assert_eq(fp1.size(), fp2.size(),
		"Dos generaciones con la misma semilla deben tener el mismo nº de tiles")
	assert_eq(fp1, fp2,
		"Misma semilla + forma ⇒ mundo IDÉNTICO (biomas, recursos, provincias, imperios)")


func test_fingerprint_includes_two_placed_empires() -> void:
	# Asegura que la huella comparada incluye REALMENTE la colocación de imperios:
	# tras generar debe haber exactamente 2 controladores distintos (jugador + rival).
	var fp := await _generate_fingerprint(SEED_A, RADIUS)
	var controllers := {}
	for entry in fp:
		var parts: PackedStringArray = entry.split("|")
		var ctrl: String = parts[parts.size() - 1]
		if ctrl != "-":
			controllers[ctrl] = true
	assert_eq(controllers.size(), 2,
		"Deben colocarse exactamente 2 imperios (jugador + rival) y quedar en la huella")


func test_different_seed_generates_different_world() -> void:
	var fp_a := await _generate_fingerprint(SEED_A, RADIUS)
	var fp_b := await _generate_fingerprint(SEED_B, RADIUS)
	assert_ne(fp_a, fp_b,
		"Semillas distintas deben producir mundos distintos (la semilla gobierna la generación)")
