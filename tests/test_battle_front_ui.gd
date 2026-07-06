extends GutTest

## Tests para BattleFrontPanel y AssignTroopsPanel.

const BATTLE_FRONT_PANEL = preload("res://scenes/UI/military/battle_front_panel.tscn")

var empire_a: Empire
var empire_b: Empire
var stats: Stats

# Los tests de stats comparan contra texto en español ("Tropas:", "Mant.",
# "oro", "comida"). Fijamos el locale aqui para que no dependan del idioma
# guardado en user://settings.cfg o del idioma del SO.
var _prev_locale: String


func before_all() -> void:
	_prev_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("es")


func after_all() -> void:
	TranslationServer.set_locale(_prev_locale)


func _create_troop(troop_name: String, atk: int = 3, def: int = 3) -> Troop:
	var troop := Troop.new()
	troop.name = troop_name
	troop.attack = atk
	troop.defense = def
	troop.recruitment_cost_gold = 20
	troop.maintenance_gold = 2
	troop.maintenance_food = 1
	return troop


func _create_tile(biome: Tile.biome_type, ctrl: Empire, pos: Vector3 = Vector3.ZERO) -> Tile:
	var tile := Tile.new()
	tile.mesh_data = TileMeshData.new()
	tile.mesh_data.type = biome
	tile.natural_resource = NaturalResource.new()
	tile.buildings = []
	tile.controller = ctrl
	tile.position = pos
	autofree(tile)
	return tile


func before_each() -> void:
	BattleFront.clear_active_instances()

	empire_a = Empire.new()
	empire_a.name = "Player"
	empire_a.color = Color.RED
	empire_a.controlled_tiles = []

	empire_b = Empire.new()
	empire_b.name = "Enemy"
	empire_b.color = Color.BLUE
	empire_b.controlled_tiles = []

	stats = Stats.new()
	stats.empire = empire_a
	stats.troop_pool = []
	stats.total_gold = 100
	stats.food = 50


func after_each() -> void:
	BattleFront.clear_active_instances()


# --- Tests BattleFrontPanel ---

func test_panel_creates_with_valid_front() -> void:
	var tile_a := _create_tile(Tile.biome_type.Grassland, empire_a)
	var tile_b := _create_tile(Tile.biome_type.Grassland, empire_b)
	var front := BattleFront.new(tile_a, tile_b, empire_a, empire_b)

	var panel: BattleFrontPanel = BATTLE_FRONT_PANEL.instantiate()
	panel.setup(front, empire_a)
	add_child(panel)

	assert_not_null(panel.title_label, "Debe tener label de título")
	assert_not_null(panel.assign_button, "Debe tener botón de asignar")
	assert_not_null(panel.close_button, "Debe tener botón de cerrar")

	panel.queue_free()


func test_panel_shows_empire_names() -> void:
	var tile_a := _create_tile(Tile.biome_type.Grassland, empire_a)
	var tile_b := _create_tile(Tile.biome_type.Grassland, empire_b)
	var front := BattleFront.new(tile_a, tile_b, empire_a, empire_b)

	var panel: BattleFrontPanel = BATTLE_FRONT_PANEL.instantiate()
	panel.setup(front, empire_a)
	add_child(panel)

	assert_string_contains(panel.title_label.text, "Player")
	assert_string_contains(panel.title_label.text, "Enemy")

	panel.queue_free()


func test_panel_shows_assign_button_for_participant() -> void:
	var tile_a := _create_tile(Tile.biome_type.Grassland, empire_a)
	var tile_b := _create_tile(Tile.biome_type.Grassland, empire_b)
	var front := BattleFront.new(tile_a, tile_b, empire_a, empire_b)

	var panel: BattleFrontPanel = BATTLE_FRONT_PANEL.instantiate()
	panel.setup(front, empire_a)
	add_child(panel)

	assert_true(panel.assign_button.visible, "Botón debe ser visible para participante")

	panel.queue_free()


func test_panel_hides_assign_button_for_non_participant() -> void:
	var empire_c := Empire.new()
	empire_c.name = "Spectator"

	var tile_a := _create_tile(Tile.biome_type.Grassland, empire_a)
	var tile_b := _create_tile(Tile.biome_type.Grassland, empire_b)
	var front := BattleFront.new(tile_a, tile_b, empire_a, empire_b)

	var panel: BattleFrontPanel = BATTLE_FRONT_PANEL.instantiate()
	panel.setup(front, empire_c)
	add_child(panel)

	assert_false(panel.assign_button.visible, "Botón debe ocultarse para no participante")

	panel.queue_free()


func test_panel_emits_assign_signal() -> void:
	var tile_a := _create_tile(Tile.biome_type.Grassland, empire_a)
	var tile_b := _create_tile(Tile.biome_type.Grassland, empire_b)
	var front := BattleFront.new(tile_a, tile_b, empire_a, empire_b)

	var panel: BattleFrontPanel = BATTLE_FRONT_PANEL.instantiate()
	panel.setup(front, empire_a)
	add_child(panel)
	watch_signals(panel)

	panel.assign_button.pressed.emit()
	assert_signal_emitted(panel, "assign_troop_requested")

	panel.queue_free()


func test_panel_emits_close_signal() -> void:
	var tile_a := _create_tile(Tile.biome_type.Grassland, empire_a)
	var tile_b := _create_tile(Tile.biome_type.Grassland, empire_b)
	var front := BattleFront.new(tile_a, tile_b, empire_a, empire_b)

	var panel: BattleFrontPanel = BATTLE_FRONT_PANEL.instantiate()
	panel.setup(front, empire_a)
	add_child(panel)
	watch_signals(panel)

	panel.close_button.pressed.emit()
	assert_signal_emitted(panel, "panel_closed")

	# Panel se auto-destruye al cerrar, no hacemos queue_free


# --- Tests del bloque de stats por bando ---

func test_panel_shows_assigned_troops_in_stats() -> void:
	var tile_a := _create_tile(Tile.biome_type.Grassland, empire_a)
	var tile_b := _create_tile(Tile.biome_type.Grassland, empire_b)
	var front := BattleFront.new(tile_a, tile_b, empire_a, empire_b)

	# Asignar tropas antes de mostrar para que _update_display las recoja
	front.assign_troop(_create_troop("Milicia", 4, 1), BattleFront.Side.ATTACKER)
	front.assign_troop(_create_troop("Lanceros", 2, 3), BattleFront.Side.ATTACKER)

	var panel: BattleFrontPanel = BATTLE_FRONT_PANEL.instantiate()
	panel.setup(front, empire_a)
	add_child(panel)

	# 4+2 ATK y 1+3 DEF aportados por las tropas, distinguidos del total.
	# Usamos get_parsed_text() porque RichTextLabel.append_text() no actualiza .text.
	var attacker_text := panel.attacker_stats_label.get_parsed_text()
	assert_string_contains(attacker_text, "Tropas:",
		"El bloque de stats debe etiquetar la fila de tropas")
	assert_string_contains(attacker_text, "6 ATK",
		"Debe mostrar el ATK aportado solo por las tropas asignadas")
	assert_string_contains(attacker_text, "4 DEF",
		"Debe mostrar el DEF aportado solo por las tropas asignadas")

	panel.queue_free()


func test_panel_shows_maintenance_cost_per_side() -> void:
	var tile_a := _create_tile(Tile.biome_type.Grassland, empire_a)
	var tile_b := _create_tile(Tile.biome_type.Grassland, empire_b)
	var front := BattleFront.new(tile_a, tile_b, empire_a, empire_b)

	# Tres tropas → mantenimiento progresivo: 5+10+15 = 30 oro / 30 comida
	front.assign_troop(_create_troop("T1"), BattleFront.Side.ATTACKER)
	front.assign_troop(_create_troop("T2"), BattleFront.Side.ATTACKER)
	front.assign_troop(_create_troop("T3"), BattleFront.Side.ATTACKER)

	var panel: BattleFrontPanel = BATTLE_FRONT_PANEL.instantiate()
	panel.setup(front, empire_a)
	add_child(panel)

	# RichTextLabel.append_text() no actualiza .text; usamos get_parsed_text().
	var attacker_text := panel.attacker_stats_label.get_parsed_text()
	assert_string_contains(attacker_text, "Mant.",
		"El bloque de stats debe etiquetar el coste de mantenimiento")
	assert_string_contains(attacker_text, "-30 oro",
		"Debe reflejar el oro extra que el frente está consumiendo")
	assert_string_contains(attacker_text, "-30 comida",
		"Debe reflejar la comida extra que el frente está consumiendo")

	panel.queue_free()


func test_panel_shows_zero_maintenance_with_no_troops() -> void:
	var tile_a := _create_tile(Tile.biome_type.Grassland, empire_a)
	var tile_b := _create_tile(Tile.biome_type.Grassland, empire_b)
	var front := BattleFront.new(tile_a, tile_b, empire_a, empire_b)

	var panel: BattleFrontPanel = BATTLE_FRONT_PANEL.instantiate()
	panel.setup(front, empire_a)
	add_child(panel)

	# Sin tropas asignadas: mantenimiento 0 y stats de tropas a 0.
	# RichTextLabel.append_text() no actualiza .text; usamos get_parsed_text().
	var defender_text := panel.defender_stats_label.get_parsed_text()
	assert_string_contains(defender_text, "0 ATK")
	assert_string_contains(defender_text, "-0 oro")

	panel.queue_free()


# --- Tests AssignTroopsPanel ---

func test_assign_panel_shows_pool_troops() -> void:
	var tile_a := _create_tile(Tile.biome_type.Grassland, empire_a)
	var tile_b := _create_tile(Tile.biome_type.Grassland, empire_b)
	var front := BattleFront.new(tile_a, tile_b, empire_a, empire_b)

	stats.troop_pool = [_create_troop("Milicia"), _create_troop("Caballería")]

	var panel := AssignTroopsPanel.new()
	panel.setup(front, stats)
	add_child(panel)

	# La grid debe tener 2 slots (uno por tropa en el pool)
	assert_eq(panel.troops_grid.get_child_count(), 2, "Debe mostrar 2 tropas del pool")
	assert_string_contains(panel.pool_label.text, "2", "Label debe indicar 2 tropas")

	panel.queue_free()


func test_assign_panel_empty_pool_message() -> void:
	var tile_a := _create_tile(Tile.biome_type.Grassland, empire_a)
	var tile_b := _create_tile(Tile.biome_type.Grassland, empire_b)
	var front := BattleFront.new(tile_a, tile_b, empire_a, empire_b)

	stats.troop_pool = []

	var panel := AssignTroopsPanel.new()
	panel.setup(front, stats)
	add_child(panel)

	# Debe mostrar mensaje de pool vacío
	assert_eq(panel.troops_grid.get_child_count(), 1, "Debe mostrar 1 label de vacío")

	panel.queue_free()


func test_assign_panel_determines_correct_side() -> void:
	var tile_a := _create_tile(Tile.biome_type.Grassland, empire_a)
	var tile_b := _create_tile(Tile.biome_type.Grassland, empire_b)

	# Jugador es atacante
	var front := BattleFront.new(tile_a, tile_b, empire_a, empire_b)
	var panel := AssignTroopsPanel.new()
	panel.setup(front, stats)
	add_child(panel)
	assert_eq(panel.side, BattleFront.Side.ATTACKER, "Jugador es atacante")
	panel.queue_free()

	# Jugador es defensor
	var front2 := BattleFront.new(tile_b, tile_a, empire_b, empire_a)
	var panel2 := AssignTroopsPanel.new()
	panel2.setup(front2, stats)
	add_child(panel2)
	assert_eq(panel2.side, BattleFront.Side.DEFENDER, "Jugador es defensor")
	panel2.queue_free()


func test_assign_panel_emits_troop_assigned() -> void:
	var tile_a := _create_tile(Tile.biome_type.Grassland, empire_a)
	var tile_b := _create_tile(Tile.biome_type.Grassland, empire_b)
	var front := BattleFront.new(tile_a, tile_b, empire_a, empire_b)

	var troop := _create_troop("Milicia")
	stats.troop_pool = [troop]

	var panel := AssignTroopsPanel.new()
	panel.setup(front, stats)
	add_child(panel)
	watch_signals(panel)

	panel.troop_assigned.emit(troop)
	assert_signal_emitted(panel, "troop_assigned")

	panel.queue_free()
