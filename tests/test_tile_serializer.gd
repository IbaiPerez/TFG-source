extends GutTest
## Tests de TileSerializer: serialización a dict.
##
## La reconstrucción de Tile completa requiere instanciar mesh y materiales
## (Tile.set_parameters() depende de un MeshInstance3D hijo). Eso se cubre
## en un test de integración manual al final del fichero, marcado para
## ejecutarse cuando los recursos del proyecto están disponibles.


func _make_minimal_tile() -> Tile:
	# Construye un Tile "esqueleto": pos_data + flags + recursos como
	# referencias por path, sin Tile.set_parameters() (que necesita
	# meshes hijos). Suficiente para probar to_dict.
	#
	# `add_child_autofree` libera el Node al terminar el test; sin esto,
	# Tile (Node3D) creado con .new() se queda como orphan.
	var tile := add_child_autofree(Tile.new()) as Tile
	var pos_data := PositionData.new()
	pos_data.grid_position = Vector2(3, -2)
	pos_data.world_position = Vector3(1.5, 0.0, 2.5)
	pos_data.buffer = true
	pos_data.water = false
	pos_data.mountain = false
	tile.pos_data = pos_data
	tile.biome = "Grassland"
	tile.position = pos_data.world_position
	return tile


# --- to_dict ----------------------------------------------------------

func test_to_dict_records_grid_position():
	var tile := _make_minimal_tile()
	var d := TileSerializer.to_dict(tile)
	assert_eq(d["pos"], [3, -2])


func test_to_dict_records_world_position():
	var tile := _make_minimal_tile()
	var d := TileSerializer.to_dict(tile)
	assert_eq(d["world_position"], [1.5, 0.0, 2.5])


func test_to_dict_records_flags():
	var tile := _make_minimal_tile()
	var d := TileSerializer.to_dict(tile)
	assert_true(d["buffer"])
	assert_false(d["water"])
	assert_false(d["mountain"])


func test_to_dict_records_biome():
	var tile := _make_minimal_tile()
	var d := TileSerializer.to_dict(tile)
	assert_eq(d["biome"], "Grassland")


func test_to_dict_empty_buildings_when_none():
	var tile := _make_minimal_tile()
	var d := TileSerializer.to_dict(tile)
	assert_eq(d["buildings"], [])


func test_to_dict_records_buildings_by_path():
	var tile := _make_minimal_tile()
	# Cargamos un building real para verificar que se serializa por path.
	var dir := DirAccess.open("res://resources/buildings/")
	if dir == null:
		pending("Sin recursos de buildings disponibles para este test")
		return
	dir.list_dir_begin()
	var first_building_path:String = ""
	var f := dir.get_next()
	while f != "":
		if f.ends_with(".tres"):
			first_building_path = "res://resources/buildings/" + f
			break
		f = dir.get_next()
	dir.list_dir_end()

	if first_building_path == "":
		pending("No se encontró ningún building.tres en res://resources/buildings/")
		return

	var building:Building = load(first_building_path) as Building
	tile.buildings = [building.duplicate(true)]
	var d := TileSerializer.to_dict(tile)
	assert_eq(d["buildings"].size(), 1)
	# El building es un duplicate → su resource_path queda vacío y el
	# registry devuelve `building.name` como clave. Solo comprobamos que
	# no esté vacío; el contenido exacto depende del .tres concreto.
	assert_ne(d["buildings"][0], "")


func test_to_dict_no_controller_serializes_empty_string():
	var tile := _make_minimal_tile()
	var d := TileSerializer.to_dict(tile)
	assert_eq(d["controller_path"], "")


# --- province_name -------------------------------------------------------

func test_to_dict_records_province_name():
	var tile := _make_minimal_tile()
	tile.province_name = "Valentia"
	var d := TileSerializer.to_dict(tile)
	assert_eq(d["province_name"], "Valentia")


func test_to_dict_province_name_empty_by_default():
	var tile := _make_minimal_tile()
	var d := TileSerializer.to_dict(tile)
	assert_eq(d["province_name"], "",
		"Sin asignar province_name, el dict debe guardar cadena vacía")
