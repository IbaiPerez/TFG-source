extends GutTest

## Tests para la demolición manual de edificios desde la UI:
## - BuildingCardUI: botón rojo de demoler (visibilidad y señal).
## - TilePanel: cableado con stats, restricción a casillas controladas
##   por el jugador y flujo confirmación → demolición.

const BUILDING_CARD_UI = preload("res://scenes/UI/building/building_card_ui.tscn")
const TILE_PANEL = preload("res://scenes/UI/tile/tile_panel.tscn")


# --- Helpers ---------------------------------------------------------------

func _make_building(b_name:String = "TestBldg", cost:int = 50) -> Building:
	var b := Building.new()
	b.name = b_name
	b.construction_cost = cost
	b.gold_produced = 1
	b.food_produced = 1
	return b


func _make_location(type:int, max_b:int = 3) -> LocationType:
	var loc := LocationType.new()
	loc.type = type
	loc.max_building = max_b
	loc.color = Color.WHITE
	loc.food_consumption = 0
	return loc


func _make_tile(controller:Empire, building:Building) -> Tile:
	var tile := Tile.new()
	tile.mesh_data = TileMeshData.new()
	tile.mesh_data.type = Tile.biome_type.Grassland
	tile.location = _make_location(Tile.location_type.Village, 3)
	tile.buildings = [building] as Array[Building]
	tile.controller = controller
	tile.recalculate_modifiers()
	autofree(tile)
	return tile


func _make_stats(empire:Empire) -> Stats:
	var s := Stats.new()
	s.empire = empire
	s.total_gold = 0
	s.food = 0
	return s


# --- BuildingCardUI: visibilidad del botón ---------------------------------

func test_demolish_button_hidden_by_default() -> void:
	var card:BuildingCardUI = BUILDING_CARD_UI.instantiate()
	add_child_autofree(card)
	card.building = _make_building()

	assert_false(card.demolish_button.visible,
		"Por defecto allow_demolish=false → botón oculto incluso con building")


func test_demolish_button_hidden_when_no_building() -> void:
	var card:BuildingCardUI = BUILDING_CARD_UI.instantiate()
	add_child_autofree(card)
	card.allow_demolish = true
	card.building = null

	assert_false(card.demolish_button.visible,
		"Sin building asignado el botón debe estar oculto aunque allow_demolish")


func test_demolish_button_visible_when_allowed_and_building_set() -> void:
	var card:BuildingCardUI = BUILDING_CARD_UI.instantiate()
	add_child_autofree(card)
	card.allow_demolish = true
	card.building = _make_building()

	assert_true(card.demolish_button.visible,
		"allow_demolish=true + building asignado → botón visible")


func test_demolish_button_hides_when_building_cleared() -> void:
	var card:BuildingCardUI = BUILDING_CARD_UI.instantiate()
	add_child_autofree(card)
	card.allow_demolish = true
	card.building = _make_building()
	assert_true(card.demolish_button.visible)

	card.building = null
	assert_false(card.demolish_button.visible,
		"Al limpiar el building el botón debe ocultarse")


# --- BuildingCardUI: señal demolish_requested ------------------------------

func test_pressing_demolish_button_emits_signal() -> void:
	var card:BuildingCardUI = BUILDING_CARD_UI.instantiate()
	add_child_autofree(card)
	var b := _make_building("Forge", 200)
	card.allow_demolish = true
	card.building = b
	watch_signals(card)

	card._on_demolish_button_pressed()

	assert_signal_emitted(card, "demolish_requested",
		"Al pulsar el botón debe emitirse demolish_requested")
	assert_signal_emitted_with_parameters(card, "demolish_requested", [b])


func test_pressing_demolish_does_nothing_when_no_building() -> void:
	var card:BuildingCardUI = BUILDING_CARD_UI.instantiate()
	add_child_autofree(card)
	card.allow_demolish = true
	card.building = null
	watch_signals(card)

	card._on_demolish_button_pressed()

	assert_signal_not_emitted(card, "demolish_requested",
		"Sin building no debe emitirse la señal")


# --- TilePanel: control de casillas y flujo de demolición ------------------

func test_tile_panel_disables_demolish_on_uncontrolled_tile() -> void:
	var player := Empire.new()
	player.name = "Player"
	player.color = Color.RED
	var enemy := Empire.new()
	enemy.name = "Enemy"
	enemy.color = Color.BLUE

	var b := _make_building("Library")
	var tile := _make_tile(enemy, b)  # casilla del enemigo

	var panel:TilePanel = TILE_PANEL.instantiate()
	add_child_autofree(panel)
	panel.stats = _make_stats(player)
	panel.tile = tile

	# Buscar la primera BuildingCardUI del grid
	var card:BuildingCardUI = panel.building_grid.get_child(0) as BuildingCardUI
	assert_not_null(card, "Debe haberse instanciado al menos un slot")
	assert_false(card.allow_demolish,
		"Si el tile no es del jugador, allow_demolish debe ser false")
	assert_false(card.demolish_button.visible,
		"Tile no controlado → botón oculto")


func test_tile_panel_enables_demolish_on_controlled_tile() -> void:
	var player := Empire.new()
	player.name = "Player"
	player.color = Color.RED

	var b := _make_building("Library")
	var tile := _make_tile(player, b)

	var panel:TilePanel = TILE_PANEL.instantiate()
	add_child_autofree(panel)
	panel.stats = _make_stats(player)
	panel.tile = tile

	var card:BuildingCardUI = panel.building_grid.get_child(0) as BuildingCardUI
	assert_not_null(card)
	assert_true(card.allow_demolish,
		"Tile controlado por el jugador → allow_demolish=true")
	assert_true(card.demolish_button.visible,
		"Tile controlado y building presente → botón visible")


func test_tile_panel_demolishes_on_confirm() -> void:
	var player := Empire.new()
	player.name = "Player"
	player.color = Color.RED

	var b := _make_building("Library")
	var tile := _make_tile(player, b)
	# Tomamos la instancia real que vive en tile.buildings
	# (Tile.demolish trabaja por referencia)
	var instance:Building = tile.buildings[0]

	var panel:TilePanel = TILE_PANEL.instantiate()
	add_child_autofree(panel)
	panel.stats = _make_stats(player)
	panel.tile = tile

	# Simulamos el flujo: solicitud + confirmación
	panel._on_demolish_requested(instance)
	panel._on_demolish_confirmed()

	assert_eq(tile.buildings.size(), 0,
		"Tras confirmar, el edificio debe haber sido demolido")


func test_tile_panel_keeps_building_on_cancel() -> void:
	var player := Empire.new()
	player.name = "Player"
	player.color = Color.RED

	var b := _make_building("Library")
	var tile := _make_tile(player, b)
	var instance:Building = tile.buildings[0]

	var panel:TilePanel = TILE_PANEL.instantiate()
	add_child_autofree(panel)
	panel.stats = _make_stats(player)
	panel.tile = tile

	panel._on_demolish_requested(instance)
	panel._on_demolish_canceled()

	assert_eq(tile.buildings.size(), 1,
		"Si se cancela el popup, el edificio no se demuele")


func test_tile_panel_ignores_demolish_request_on_uncontrolled_tile() -> void:
	var player := Empire.new()
	player.name = "Player"
	var enemy := Empire.new()
	enemy.name = "Enemy"

	var b := _make_building("Library")
	var tile := _make_tile(enemy, b)
	var instance:Building = tile.buildings[0]

	var panel:TilePanel = TILE_PANEL.instantiate()
	add_child_autofree(panel)
	panel.stats = _make_stats(player)
	panel.tile = tile

	# Aunque alguien forzase la señal, no debe demoler
	panel._on_demolish_requested(instance)
	panel._on_demolish_confirmed()

	assert_eq(tile.buildings.size(), 1,
		"En tile no controlado por el jugador, demoler debe ser ignorado")


func test_tile_panel_frees_slot_after_demolish() -> void:
	var player := Empire.new()
	player.name = "Player"

	var b := _make_building("Library")
	var tile := _make_tile(player, b)
	var instance:Building = tile.buildings[0]

	var panel:TilePanel = TILE_PANEL.instantiate()
	add_child_autofree(panel)
	panel.stats = _make_stats(player)
	panel.tile = tile

	panel._on_demolish_requested(instance)
	panel._on_demolish_confirmed()

	# Esperar un frame para que el queue_free de los slots viejos
	# se materialice y get_children() devuelva sólo los nuevos.
	await get_tree().process_frame
	await get_tree().process_frame

	# Tras refresco, el primer slot debe estar vacío (sin building).
	# Filtramos por instancias válidas para evitar coger nodos en cola.
	var fresh_cards:Array = []
	for child in panel.building_grid.get_children():
		if not child.is_queued_for_deletion():
			fresh_cards.append(child)

	assert_eq(fresh_cards.size(), tile.max_buildings,
		"El grid debe contener exactamente max_buildings slots tras refrescar")
	var first:BuildingCardUI = fresh_cards[0] as BuildingCardUI
	assert_null(first.building,
		"Tras demoler, el primer slot se libera (building=null)")
	assert_false(first.demolish_button.visible,
		"Slot vacío → botón rojo oculto aunque allow_demolish siga activo")
