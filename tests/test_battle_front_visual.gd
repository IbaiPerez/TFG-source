extends GutTest

## Tests para BattleFrontVisual y BattleFrontVisualManager.

var empire_a: Empire
var empire_b: Empire
var stats: Stats


func _create_tile(biome: Tile.biome_type, ctrl: Empire, pos: Vector3) -> Tile:
	var tile := Tile.new()
	tile.mesh_data = TileMeshData.new()
	tile.mesh_data.type = biome
	tile.natural_resource = NaturalResource.new()
	tile.buildings = []
	tile.controller = ctrl
	tile.position = pos
	return tile


func before_each() -> void:
	BattleFront.clear_active_instances()

	empire_a = Empire.new()
	empire_a.name = "Empire A"
	empire_a.color = Color.RED
	empire_a.controlled_tiles = []

	empire_b = Empire.new()
	empire_b.name = "Empire B"
	empire_b.color = Color.BLUE
	empire_b.controlled_tiles = []

	stats = Stats.new()
	stats.empire = empire_a
	stats.troop_pool = []
	stats.total_gold = 100
	stats.food = 50


func after_each() -> void:
	BattleFront.clear_active_instances()


# --- Tests BattleFrontVisual ---

func test_visual_positions_at_midpoint() -> void:
	var tile_a := _create_tile(Tile.biome_type.Grassland, empire_a, Vector3(0, 0, 0))
	var tile_b := _create_tile(Tile.biome_type.Grassland, empire_b, Vector3(2, 0, 0))
	add_child(tile_a)
	add_child(tile_b)

	var front := BattleFront.new(tile_a, tile_b, empire_a, empire_b)
	var visual := BattleFrontVisual.new(front)
	add_child(visual)

	# Debe estar en el punto medio entre las dos tiles
	var expected_mid := Vector3(1, 0.1, 0)
	assert_almost_eq(visual.global_position.x, expected_mid.x, 0.01, "X debe ser punto medio")
	assert_almost_eq(visual.global_position.z, expected_mid.z, 0.01, "Z debe ser punto medio")

	tile_a.free()
	tile_b.free()
	visual.queue_free()


func test_visual_has_area3d_on_layer_3() -> void:
	var tile_a := _create_tile(Tile.biome_type.Grassland, empire_a, Vector3(0, 0, 0))
	var tile_b := _create_tile(Tile.biome_type.Grassland, empire_b, Vector3(2, 0, 0))
	add_child(tile_a)
	add_child(tile_b)

	var front := BattleFront.new(tile_a, tile_b, empire_a, empire_b)
	var visual := BattleFrontVisual.new(front)
	add_child(visual)

	assert_not_null(visual.area_3d, "Debe tener Area3D")
	# Layer 3 = bit 2 = valor 4
	assert_eq(visual.area_3d.collision_layer, 4, "Area3D debe estar en layer 3 (valor 4)")
	assert_eq(visual.area_3d.collision_mask, 0, "No debe detectar otras áreas")

	tile_a.free()
	tile_b.free()
	visual.queue_free()


func test_visual_set_highlight() -> void:
	var tile_a := _create_tile(Tile.biome_type.Grassland, empire_a, Vector3(0, 0, 0))
	var tile_b := _create_tile(Tile.biome_type.Grassland, empire_b, Vector3(2, 0, 0))
	add_child(tile_a)
	add_child(tile_b)

	var front := BattleFront.new(tile_a, tile_b, empire_a, empire_b)
	var visual := BattleFrontVisual.new(front)
	add_child(visual)

	visual.set_highlight(true)
	assert_not_null(visual.bar_mesh.material_overlay, "Highlight activo debe tener material_overlay")

	visual.set_highlight(false)
	assert_null(visual.bar_mesh.material_overlay, "Highlight inactivo debe quitar material_overlay")

	tile_a.free()
	tile_b.free()
	visual.queue_free()


func test_visual_updates_color_on_marker_change() -> void:
	var tile_a := _create_tile(Tile.biome_type.Grassland, empire_a, Vector3(0, 0, 0))
	var tile_b := _create_tile(Tile.biome_type.Grassland, empire_b, Vector3(2, 0, 0))
	add_child(tile_a)
	add_child(tile_b)

	var front := BattleFront.new(tile_a, tile_b, empire_a, empire_b)
	var visual := BattleFrontVisual.new(front)
	add_child(visual)

	var initial_color: Color = visual.bar_material.albedo_color

	# Mover marcador a favor del atacante
	front.marker = front.threshold * 0.8
	front.marker_changed.emit(front, front.marker)

	var new_color: Color = visual.bar_material.albedo_color
	# El color debe haber cambiado hacia el color del atacante
	assert_ne(initial_color, new_color, "El color debe cambiar con el marcador")

	tile_a.free()
	tile_b.free()
	visual.queue_free()


func test_visual_emits_front_clicked() -> void:
	var tile_a := _create_tile(Tile.biome_type.Grassland, empire_a, Vector3(0, 0, 0))
	var tile_b := _create_tile(Tile.biome_type.Grassland, empire_b, Vector3(2, 0, 0))
	add_child(tile_a)
	add_child(tile_b)

	var front := BattleFront.new(tile_a, tile_b, empire_a, empire_b)
	var visual := BattleFrontVisual.new(front)
	add_child(visual)

	watch_signals(visual)
	visual.front_clicked.emit(front)
	assert_signal_emitted(visual, "front_clicked")

	tile_a.free()
	tile_b.free()
	visual.queue_free()


# --- Tests BattleFrontVisualManager ---

func test_manager_creates_visual_on_front_opened() -> void:
	var parent_3d := Node3D.new()
	add_child(parent_3d)

	var manager := BattleFrontVisualManager.new()
	manager.visual_parent = parent_3d
	add_child(manager)

	var tile_a := _create_tile(Tile.biome_type.Grassland, empire_a, Vector3(0, 0, 0))
	var tile_b := _create_tile(Tile.biome_type.Grassland, empire_b, Vector3(2, 0, 0))
	add_child(tile_a)
	add_child(tile_b)

	var front := BattleFront.new(tile_a, tile_b, empire_a, empire_b)
	Events.battle_front_opened.emit(front)

	# Esperar un frame para que se procese
	await get_tree().process_frame

	var visual := manager.get_visual_for_front(front)
	assert_not_null(visual, "Debe crear un visual para el frente abierto")
	assert_eq(parent_3d.get_child_count(), 1, "Visual debe ser hijo del parent_3d")

	tile_a.free()
	tile_b.free()
	manager.queue_free()
	parent_3d.queue_free()


func test_manager_removes_visual_on_front_resolved() -> void:
	var parent_3d := Node3D.new()
	add_child(parent_3d)

	var manager := BattleFrontVisualManager.new()
	manager.visual_parent = parent_3d
	add_child(manager)

	var tile_a := _create_tile(Tile.biome_type.Grassland, empire_a, Vector3(0, 0, 0))
	var tile_b := _create_tile(Tile.biome_type.Grassland, empire_b, Vector3(2, 0, 0))
	add_child(tile_a)
	add_child(tile_b)

	var front := BattleFront.new(tile_a, tile_b, empire_a, empire_b)
	Events.battle_front_opened.emit(front)
	await get_tree().process_frame

	# Resolver frente
	Events.battle_front_resolved.emit(front, true)
	await get_tree().process_frame

	var visual := manager.get_visual_for_front(front)
	assert_null(visual, "Debe eliminar la referencia al visual tras resolución")

	tile_a.free()
	tile_b.free()
	manager.queue_free()
	parent_3d.queue_free()


func test_manager_no_duplicate_visuals() -> void:
	var parent_3d := Node3D.new()
	add_child(parent_3d)

	var manager := BattleFrontVisualManager.new()
	manager.visual_parent = parent_3d
	add_child(manager)

	var tile_a := _create_tile(Tile.biome_type.Grassland, empire_a, Vector3(0, 0, 0))
	var tile_b := _create_tile(Tile.biome_type.Grassland, empire_b, Vector3(2, 0, 0))
	add_child(tile_a)
	add_child(tile_b)

	var front := BattleFront.new(tile_a, tile_b, empire_a, empire_b)
	Events.battle_front_opened.emit(front)
	Events.battle_front_opened.emit(front)  # Duplicado
	await get_tree().process_frame

	assert_eq(parent_3d.get_child_count(), 1, "No debe crear visuales duplicados")

	tile_a.free()
	tile_b.free()
	manager.queue_free()
	parent_3d.queue_free()


func test_manager_get_all_visuals() -> void:
	var parent_3d := Node3D.new()
	add_child(parent_3d)

	var manager := BattleFrontVisualManager.new()
	manager.visual_parent = parent_3d
	add_child(manager)

	var tile_a := _create_tile(Tile.biome_type.Grassland, empire_a, Vector3(0, 0, 0))
	var tile_b := _create_tile(Tile.biome_type.Grassland, empire_b, Vector3(2, 0, 0))
	var tile_c := _create_tile(Tile.biome_type.Forest, empire_b, Vector3(0, 0, 2))
	add_child(tile_a)
	add_child(tile_b)
	add_child(tile_c)

	tile_a.neighbors = [tile_b, tile_c]

	var front1 := BattleFront.new(tile_a, tile_b, empire_a, empire_b)
	var front2 := BattleFront.new(tile_a, tile_c, empire_a, empire_b)

	Events.battle_front_opened.emit(front1)
	Events.battle_front_opened.emit(front2)
	await get_tree().process_frame

	var all_visuals := manager.get_all_visuals()
	assert_eq(all_visuals.size(), 2, "Debe devolver todos los visuales activos")

	tile_a.free()
	tile_b.free()
	tile_c.free()
	manager.queue_free()
	parent_3d.queue_free()


# --- Tests del indicador 3D filtrado al bando del jugador ---

func _make_tactic_bonus() -> Dictionary:
	# Bonus dict mínimo con tactic_name (el filtro de "es táctica" se basa en
	# esa clave). Suficiente para los tests del indicador.
	return {
		"tactic_name": "TestTactic",
		"troop_types": [Troop.TroopType.CABALLERIA],
		"attack_percent_per_type": 20.0,
		"attack_biome_modifier": 1.0,
		"defense_biome_modifier": 1.0,
	}


func _setup_visual_with_player(player_empire_local: Empire) -> Dictionary:
	# Helper: crea un frente, su visual y le inyecta el player_empire.
	# Devuelve { "front": ..., "visual": ..., "tile_a": ..., "tile_b": ... }
	# para que el test pueda asignar tácticas y comprobar el indicador.
	var tile_a := _create_tile(Tile.biome_type.Grassland, empire_a, Vector3(0, 0, 0))
	var tile_b := _create_tile(Tile.biome_type.Grassland, empire_b, Vector3(2, 0, 0))
	add_child(tile_a)
	add_child(tile_b)

	var front := BattleFront.new(tile_a, tile_b, empire_a, empire_b)
	var visual := BattleFrontVisual.new(front)
	add_child(visual)
	if player_empire_local != null:
		visual.set_player_empire(player_empire_local)

	return {
		"front": front,
		"visual": visual,
		"tile_a": tile_a,
		"tile_b": tile_b,
	}


func _teardown_visual(setup: Dictionary) -> void:
	if is_instance_valid(setup["visual"]):
		setup["visual"].queue_free()
	if is_instance_valid(setup["tile_a"]):
		setup["tile_a"].free()
	if is_instance_valid(setup["tile_b"]):
		setup["tile_b"].free()


func test_tactic_indicator_hidden_without_player_empire() -> void:
	# Sin player_empire, el indicador siempre oculto aunque haya tácticas.
	var setup := _setup_visual_with_player(null)
	var front: BattleFront = setup["front"]
	var visual: BattleFrontVisual = setup["visual"]

	front.add_bonus(&"attacker", _make_tactic_bonus())
	front.add_bonus(&"defender", _make_tactic_bonus())
	assert_false(visual.tactic_indicator_sprite.visible,
		"Sin player_empire el indicador debe permanecer oculto")

	_teardown_visual(setup)


func test_tactic_indicator_hidden_when_player_does_not_participate() -> void:
	# El jugador es un imperio C que no está en este frente.
	var empire_c := Empire.new()
	empire_c.name = "Spectator"
	var setup := _setup_visual_with_player(empire_c)
	var front: BattleFront = setup["front"]
	var visual: BattleFrontVisual = setup["visual"]

	front.add_bonus(&"attacker", _make_tactic_bonus())
	front.add_bonus(&"defender", _make_tactic_bonus())
	assert_false(visual.tactic_indicator_sprite.visible,
		"Si el jugador no participa, el indicador debe quedar oculto")

	_teardown_visual(setup)


func test_tactic_indicator_visible_when_player_attacker_has_tactic() -> void:
	# Jugador es atacante (empire_a). Táctica en atacante → indicador visible.
	var setup := _setup_visual_with_player(empire_a)
	var front: BattleFront = setup["front"]
	var visual: BattleFrontVisual = setup["visual"]

	front.add_bonus(&"attacker", _make_tactic_bonus())
	assert_true(visual.tactic_indicator_sprite.visible,
		"Táctica en el bando del jugador (atacante) debe encender el indicador")

	_teardown_visual(setup)


func test_tactic_indicator_hidden_when_only_opponent_has_tactic() -> void:
	# Jugador es atacante, pero la táctica está en el defensor.
	var setup := _setup_visual_with_player(empire_a)
	var front: BattleFront = setup["front"]
	var visual: BattleFrontVisual = setup["visual"]

	front.add_bonus(&"defender", _make_tactic_bonus())
	assert_false(visual.tactic_indicator_sprite.visible,
		"Táctica del rival NO debe encender el indicador del jugador")

	_teardown_visual(setup)


func test_tactic_indicator_visible_when_player_defender_has_tactic() -> void:
	# Jugador es defensor (empire_b). Táctica en defensor → indicador visible.
	var setup := _setup_visual_with_player(empire_b)
	var front: BattleFront = setup["front"]
	var visual: BattleFrontVisual = setup["visual"]

	front.add_bonus(&"defender", _make_tactic_bonus())
	assert_true(visual.tactic_indicator_sprite.visible,
		"Táctica en el bando del jugador (defensor) debe encender el indicador")

	_teardown_visual(setup)


func test_tactic_indicator_updates_on_bonuses_changed() -> void:
	# El indicador debe reaccionar al instante a la señal bonuses_changed.
	var setup := _setup_visual_with_player(empire_a)
	var front: BattleFront = setup["front"]
	var visual: BattleFrontVisual = setup["visual"]

	# Inicialmente oculto.
	assert_false(visual.tactic_indicator_sprite.visible)

	# Añadir táctica del jugador → indicador se enciende.
	front.add_bonus(&"attacker", _make_tactic_bonus())
	assert_true(visual.tactic_indicator_sprite.visible)

	# Limpiar tácticas del jugador → indicador se apaga.
	front.clear_tactics_for_side(&"attacker")
	assert_false(visual.tactic_indicator_sprite.visible,
		"Al limpiar la táctica del jugador el indicador debe apagarse")

	_teardown_visual(setup)


func test_tactic_indicator_ignores_non_tactic_bonuses() -> void:
	# Un bonus plano sin tactic_name no debe encender el indicador.
	var setup := _setup_visual_with_player(empire_a)
	var front: BattleFront = setup["front"]
	var visual: BattleFrontVisual = setup["visual"]

	front.add_bonus(&"attacker", {"attack": 10.0})
	assert_false(visual.tactic_indicator_sprite.visible,
		"Bonus plano sin tactic_name no debe contar como táctica")

	_teardown_visual(setup)
