extends GutTest
## Tests de BattleFrontSerializer.


var atk_tile:Tile
var def_tile:Tile
var atk_emp:Empire
var def_emp:Empire
var troop_a:Troop
var troop_b:Troop


func before_each() -> void:
	BattleFront.clear_active_instances()

	atk_tile = Tile.new()
	atk_tile.pos_data = PositionData.new()
	atk_tile.pos_data.grid_position = Vector2(1, 0)

	def_tile = Tile.new()
	def_tile.pos_data = PositionData.new()
	def_tile.pos_data.grid_position = Vector2(2, 0)

	atk_emp = Empire.new()
	atk_emp.name = "Mongol"
	atk_emp.resource_path = "res://test/mongol.tres"
	def_emp = Empire.new()
	def_emp.name = "Babylonian"
	def_emp.resource_path = "res://test/babylonian.tres"

	troop_a = Troop.new()
	troop_a.name = "Soldier A"
	troop_a.attack = 5
	troop_a.defense = 3

	troop_b = Troop.new()
	troop_b.name = "Soldier B"
	troop_b.attack = 4
	troop_b.defense = 4


func after_each() -> void:
	BattleFront.clear_active_instances()
	# Los Tile son Node3D creados con .new() y nunca añadidos al árbol —
	# hay que liberarlos a mano o GUT los detecta como orphans.
	if is_instance_valid(atk_tile):
		atk_tile.free()
	if is_instance_valid(def_tile):
		def_tile.free()
	WorldMap.map_as_dict.clear()


func test_resolved_front_serializes_to_empty_dict():
	var front := BattleFront.new(atk_tile, def_tile, atk_emp, def_emp)
	front.is_resolved = true
	var d := BattleFrontSerializer.to_dict(front)
	assert_true(d.is_empty(), "frente resuelto no debe serializarse")


func test_to_dict_captures_positions_and_empires():
	var front := BattleFront.new(atk_tile, def_tile, atk_emp, def_emp)
	front.marker = 7.5
	front.turns_elapsed = 4

	var d := BattleFrontSerializer.to_dict(front)
	assert_eq(d["attacker_pos"], [1, 0])
	assert_eq(d["defender_pos"], [2, 0])
	assert_eq(d["attacker_empire"], "res://test/mongol.tres")
	assert_eq(d["defender_empire"], "res://test/babylonian.tres")
	assert_eq(d["marker"], 7.5)
	assert_eq(d["turns_elapsed"], 4)


func test_to_dict_serializes_troops_by_resource_path():
	# Troops creadas in-memory no tienen resource_path; los paths quedan "".
	# El serializer debe tolerarlo sin reventar.
	var front := BattleFront.new(atk_tile, def_tile, atk_emp, def_emp)
	front.attacker_troops = [troop_a, troop_b]

	var d := BattleFrontSerializer.to_dict(front)
	assert_eq(d["attacker_troops"].size(), 2)


func test_to_dict_sanitizes_resource_in_bonuses():
	var front := BattleFront.new(atk_tile, def_tile, atk_emp, def_emp)
	# Bonus que mete un Resource bajo una clave: el serializer debe
	# guardarlo como path (string), no como objeto.
	var fake_card := Card.new()
	fake_card.id = "tactic_x"
	front.attacker_bonuses = [
		{ "tactic_name": "Test Tactic", "attack": 5.0, "card_ref": fake_card }
	]

	var d := BattleFrontSerializer.to_dict(front)
	assert_eq(d["attacker_bonuses"].size(), 1)
	# El Resource sin resource_path queda como "" pero NO como objeto Card.
	var entry:Dictionary = d["attacker_bonuses"][0]
	assert_typeof(entry["card_ref"], TYPE_STRING)


func test_from_dict_returns_null_when_tiles_not_in_world():
	# Sin WorldMap.map_as_dict poblado, no se puede resolver tiles.
	WorldMap.map_as_dict.clear()
	var data := {
		"attacker_pos": [99, 99],
		"defender_pos": [100, 100],
		"attacker_empire": "res://test/mongol.tres",
		"defender_empire": "res://test/babylonian.tres",
	}
	var restored := BattleFrontSerializer.from_dict(data, { "res://test/mongol.tres": atk_emp, "res://test/babylonian.tres": def_emp })
	assert_null(restored)


func test_from_dict_rebuilds_with_world_and_empires():
	WorldMap.map_as_dict.clear()
	WorldMap.map_as_dict[Vector2(1, 0)] = atk_tile
	WorldMap.map_as_dict[Vector2(2, 0)] = def_tile

	var data := {
		"attacker_pos": [1, 0],
		"defender_pos": [2, 0],
		"attacker_empire": "res://test/mongol.tres",
		"defender_empire": "res://test/babylonian.tres",
		"marker": 4.0,
		"turns_elapsed": 2,
		"min_duration": 3,
		"threshold": 15.0,
		"attacker_troops": [],
		"defender_troops": [],
		"attacker_bonuses": [],
		"defender_bonuses": [],
	}
	var empires_by_name := { "res://test/mongol.tres": atk_emp, "res://test/babylonian.tres": def_emp }
	var front := BattleFrontSerializer.from_dict(data, empires_by_name)
	assert_not_null(front)
	assert_eq(front.attacker_empire.name, "Mongol")
	assert_eq(front.marker, 4.0)
	assert_eq(front.turns_elapsed, 2)

	# Limpieza del registro estático (autoregistra _init).
	WorldMap.map_as_dict.clear()
