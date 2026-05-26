extends GutTest

## Tests para AIActionFeedback (floating labels 3D) y AIActionLog
## (mini-log lateral). Cobertura Fase 5.


# ============================================================
#  Helpers
# ============================================================

func _make_empire(p_name: String = "TestEmp") -> Empire:
	var e := Empire.new()
	e.name = p_name
	e.color = Color.RED
	e.controlled_tiles = []
	return e


func _make_tile() -> Tile:
	var tile := Tile.new()
	tile.mesh_data = TileMeshData.new()
	tile.mesh_data.type = Tile.biome_type.Grassland
	tile.natural_resource = NaturalResource.new()
	tile.pos_data = PositionData.new()
	tile.pos_data.grid_position = Vector2i(3, 2)
	tile.neighbors = []
	tile.buildings = []
	return tile


func _make_card(p_id: String = "colonize") -> Card:
	var c := Card.new()
	c.id = p_id
	c.target = Card.Target.TILE
	return c


# ============================================================
#  AIActionFeedback: floating labels 3D
# ============================================================

func test_floating_label_spawns_when_card_played_with_tile() -> void:
	var feedback := AIActionFeedback.new()
	add_child_autofree(feedback)
	var initial_children := feedback.get_child_count()

	var tile := _make_tile()
	add_child_autofree(tile)
	var card := _make_card("colonize")
	var empire := _make_empire("E")

	Events.ai_card_played.emit(card, tile, empire, {})
	await get_tree().process_frame

	assert_eq(feedback.get_child_count(), initial_children + 1,
		"Debe spawnear 1 AIFloatingLabel cuando hay anchor_tile")
	var spawned := feedback.get_child(feedback.get_child_count() - 1)
	assert_true(spawned is AIFloatingLabel,
		"El hijo nuevo debe ser un AIFloatingLabel")


func test_no_floating_label_when_anchor_tile_null() -> void:
	var feedback := AIActionFeedback.new()
	add_child_autofree(feedback)
	var initial_children := feedback.get_child_count()

	var card := _make_card("recruit")
	var empire := _make_empire("E")

	Events.ai_card_played.emit(card, null, empire, {})
	await get_tree().process_frame

	assert_eq(feedback.get_child_count(), initial_children,
		"Sin anchor_tile no debe spawnear label")


func test_no_floating_label_when_card_or_empire_null() -> void:
	var feedback := AIActionFeedback.new()
	add_child_autofree(feedback)
	var initial_children := feedback.get_child_count()

	var tile := _make_tile()
	add_child_autofree(tile)

	# Ningún hijo debe spawnearse con card=null o empire=null.
	Events.ai_card_played.emit(null, tile, _make_empire(), {})
	await get_tree().process_frame
	Events.ai_card_played.emit(_make_card(), tile, null, {})
	await get_tree().process_frame

	assert_eq(feedback.get_child_count(), initial_children,
		"card=null ni empire=null deben spawnear label")


# ============================================================
#  AIActionLog: mini-log lateral
# ============================================================

func test_log_appends_one_line_per_event() -> void:
	var log_panel := preload("res://scenes/UI/ai_action_log.tscn").instantiate() as AIActionLog
	add_child_autofree(log_panel)
	await get_tree().process_frame

	var card := _make_card("colonize")
	var tile := _make_tile()
	add_child_autofree(tile)
	var empire := _make_empire("Mongol")

	var box := log_panel.get_node("Layout/Lines") as VBoxContainer
	var initial_lines := box.get_child_count()

	Events.ai_card_played.emit(card, tile, empire, {})
	Events.ai_card_played.emit(card, tile, empire, {})
	await get_tree().process_frame

	assert_eq(box.get_child_count(), initial_lines + 2,
		"Cada emit añade una línea al log")


func test_log_respects_max_lines() -> void:
	var log_panel := preload("res://scenes/UI/ai_action_log.tscn").instantiate() as AIActionLog
	log_panel.max_lines = 3
	add_child_autofree(log_panel)
	await get_tree().process_frame

	var card := _make_card("colonize")
	var tile := _make_tile()
	add_child_autofree(tile)
	var empire := _make_empire("Mongol")

	# Disparar 5 emits con max_lines=3 → al final debe haber 3.
	for i in range(5):
		Events.ai_card_played.emit(card, tile, empire, {})
	await get_tree().process_frame

	var box := log_panel.get_node("Layout/Lines") as VBoxContainer
	assert_eq(box.get_child_count(), 3,
		"Log no debe exceder max_lines aunque haya más eventos")


func test_log_describes_building_from_payload() -> void:
	var log_panel := preload("res://scenes/UI/ai_action_log.tscn").instantiate() as AIActionLog
	add_child_autofree(log_panel)
	await get_tree().process_frame

	var card := _make_card("build")
	var tile := _make_tile()
	add_child_autofree(tile)
	var empire := _make_empire("Mongol")
	var b := Building.new()
	b.name = "Mina"

	Events.ai_card_played.emit(card, tile, empire, {"building": b})
	await get_tree().process_frame

	var box := log_panel.get_node("Layout/Lines") as VBoxContainer
	assert_eq(box.get_child_count(), 1)
	var line: Label = box.get_child(0) as Label
	assert_true(line.text.contains("Mina"),
		"El log debe mencionar el building del payload. Fue: %s" % line.text)
	assert_true(line.text.contains("Mongol"),
		"El log debe mencionar el imperio. Fue: %s" % line.text)


func test_log_describes_troop_from_payload() -> void:
	var log_panel := preload("res://scenes/UI/ai_action_log.tscn").instantiate() as AIActionLog
	add_child_autofree(log_panel)
	await get_tree().process_frame

	var card := _make_card("recruit")
	var empire := _make_empire("Mongol")
	var troop := Troop.new()
	troop.name = "Caballería"

	# Recruit es SELF: tile null. El log igual lo registra.
	Events.ai_card_played.emit(card, null, empire, {"troop": troop})
	await get_tree().process_frame

	var box := log_panel.get_node("Layout/Lines") as VBoxContainer
	assert_eq(box.get_child_count(), 1)
	var line: Label = box.get_child(0) as Label
	assert_true(line.text.contains("Caballería"),
		"El log debe mencionar la tropa del payload")
