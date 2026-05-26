extends GutTest

## Tests para BuildingPanel — el panel de seleccion que aparece al jugar
## una BuildCard sobre una ciudad.
##
## Bug original: cuando el jugador no tenia oro suficiente para construir
## un edificio del panel, `set_buildings` intentaba pintar el precio en
## rojo via `slot.price_label.label_settings.font_color = Color.DARK_RED`.
## El PriceLabel del BuildingSlot usa `theme_override_colors`, no un
## LabelSettings asignado, asi que `label_settings` es null → crash.
## Fix: usar `add_theme_color_override("font_color", ...)`.

const BUILDING_PANEL_SCENE := preload("uid://d4kc0x1wj7vrm")


# ============================================================
#  Helpers
# ============================================================

func _make_resource(p_name: String = "Wheat") -> NaturalResource:
	var res := NaturalResource.new()
	res.name = p_name
	res.gold_produced = 1
	res.food_produced = 1
	return res


func _make_location() -> LocationType:
	var loc := LocationType.new()
	loc.type = Tile.location_type.Village
	loc.max_building = 5
	loc.food_consumption = 0
	return loc


func _make_mesh_data() -> TileMeshData:
	var md := TileMeshData.new()
	md.color = Color.GREEN
	md.type = Tile.biome_type.Grassland
	return md


func _make_tile() -> Tile:
	var tile := Tile.new()
	tile.mesh_data = _make_mesh_data()
	tile.natural_resource = _make_resource()
	tile.location = _make_location()
	tile.max_buildings = 5
	tile.food_production = 1
	tile.gold_production = 1
	tile.buildings = []
	autofree(tile)
	return tile


func _make_building(p_cost:int) -> Building:
	# Edificio "permisivo": sin requisitos de recurso/bioma/location, asi
	# que `tile.can_build(b)` solo decide por max_buildings (libre).
	var b := Building.new()
	b.name = "TestBuilding"
	b.construction_cost = p_cost
	b.gold_produced = 1
	b.food_produced = 0
	b.required_natural_resource = null
	b.allowed_location_type = []
	b.allowed_biomes = []
	b.effects = []
	b.upgrades_to = []
	return b


func _make_stats(p_gold:int) -> Stats:
	var s := Stats.new()
	s.total_gold = p_gold
	return s


func _spawn_panel(tile:Tile, stats:Stats) -> BuildingPanel:
	var panel:BuildingPanel = BUILDING_PANEL_SCENE.instantiate()
	add_child_autofree(panel)
	panel.tile = tile
	panel.stats = stats
	panel.action = panel.possible_action.BUILD
	return panel


# ============================================================
#  Build sin oro suficiente: no debe crashear
# ============================================================

func test_set_buildings_does_not_crash_when_player_cannot_afford() -> void:
	# El caso del bug: total_gold (10) < construction_cost (50). Antes
	# del fix esto crasheaba al intentar `label_settings.font_color =`.
	var tile := _make_tile()
	var stats := _make_stats(10)
	var panel := _spawn_panel(tile, stats)

	var expensive:Array[Building] = [_make_building(50)]

	# Si `set_buildings` lanza el error de "null instance", esta linea
	# nunca llega — el test fallaria por la propia excepcion del engine.
	panel.buildings = expensive
	await get_tree().process_frame

	assert_eq(panel._slots.size(), 1,
		"se crea el slot aun siendo inasequible (solo cambia la presentacion)")


func test_unaffordable_slot_marks_price_label_in_red() -> void:
	var tile := _make_tile()
	var stats := _make_stats(10)
	var panel := _spawn_panel(tile, stats)

	var expensive:Array[Building] = [_make_building(50)]
	panel.buildings = expensive
	await get_tree().process_frame

	var slot:BuildingSlot = panel._slots[0]
	assert_true(slot.price_label.has_theme_color_override("font_color"),
		"el slot inasequible debe tener un override de color sobre PriceLabel")
	var override:Color = slot.price_label.get_theme_color("font_color")
	assert_eq(override, Color.DARK_RED,
		"el override debe ser DARK_RED para indicar precio inasequible")


func test_unaffordable_slot_does_not_emit_building_selected_on_click() -> void:
	# Si la conexion a `_on_building_to_build_selected` se hace solo en
	# el camino "afford", un slot inasequible no debe propagar la señal
	# al panel: el jugador no puede elegir un edificio que no se puede
	# pagar.
	var tile := _make_tile()
	var stats := _make_stats(10)
	var panel := _spawn_panel(tile, stats)

	var expensive:Array[Building] = [_make_building(50)]
	panel.buildings = expensive
	await get_tree().process_frame

	var slot:BuildingSlot = panel._slots[0]
	watch_signals(panel)
	slot.building_selected.emit(expensive[0])

	assert_signal_not_emitted(panel, "card_confirmed",
		"slot inasequible no debe propagar card_confirmed al panel")


# ============================================================
#  Build con oro suficiente: comportamiento normal sigue intacto
# ============================================================

func test_affordable_slot_emits_card_confirmed_on_selection() -> void:
	var tile := _make_tile()
	var stats := _make_stats(1000)
	var panel := _spawn_panel(tile, stats)

	var cheap:Array[Building] = [_make_building(50)]
	panel.buildings = cheap
	await get_tree().process_frame

	var slot:BuildingSlot = panel._slots[0]
	watch_signals(panel)
	slot.building_selected.emit(cheap[0])

	assert_signal_emitted(panel, "card_confirmed",
		"slot asequible debe propagar card_confirmed con el edificio elegido")
