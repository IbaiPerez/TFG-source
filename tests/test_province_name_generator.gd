extends GutTest
## Tests del generador silábico de nombres de provincia.

const BIOMES: Array = ["Grassland", "Forest", "Desert", "Swamp", "Tundra", "Mountain", "Ocean"]


# --- Determinismo --------------------------------------------------------

func test_same_position_same_biome_produces_same_name():
	var pos := Vector2(3, -2)
	var name_a := ProvinceNameGenerator.generate("Grassland", pos)
	var name_b := ProvinceNameGenerator.generate("Grassland", pos)
	assert_eq(name_a, name_b, "El mismo bioma+posición debe dar siempre el mismo nombre")


func test_different_positions_produce_different_names():
	var name_a := ProvinceNameGenerator.generate("Grassland", Vector2(0, 0))
	var name_b := ProvinceNameGenerator.generate("Grassland", Vector2(1, 0))
	var name_c := ProvinceNameGenerator.generate("Grassland", Vector2(0, 1))
	# Con sólo 3 posiciones la probabilidad de colisión es insignificante
	assert_ne(name_a, name_b, "Posiciones distintas deben dar nombres distintos")
	assert_ne(name_a, name_c)


func test_different_biomes_same_position_may_differ():
	# No garantizamos diferencia (pool distinta puede colisionar por azar),
	# pero sí comprobamos que los nombres no sean cadenas vacías.
	for biome in BIOMES:
		var name := ProvinceNameGenerator.generate(biome, Vector2(0, 0))
		assert_ne(name, "", "El nombre para %s no debe ser vacío" % biome)


# --- Formato -------------------------------------------------------------

func test_name_is_not_empty_for_all_biomes():
	for biome in BIOMES:
		var name := ProvinceNameGenerator.generate(biome, Vector2(5, -3))
		assert_ne(name, "", "Bioma %s no debe generar nombre vacío" % biome)


func test_name_has_minimum_length():
	# Prefijo mínimo = 2 chars + root mínimo = 1 + suffix mínimo = 1 → 4 chars
	for biome in BIOMES:
		var name := ProvinceNameGenerator.generate(biome, Vector2(2, 7))
		assert_true(name.length() >= 4,
			"El nombre '%s' para %s es demasiado corto" % [name, biome])


func test_name_has_reasonable_max_length():
	# Prefijo máx ≈ 6 + root máx ≈ 5 + suffix máx ≈ 5 → 16 chars como tope holgado
	for biome in BIOMES:
		var name := ProvinceNameGenerator.generate(biome, Vector2(-4, 9))
		assert_true(name.length() <= 20,
			"El nombre '%s' para %s es demasiado largo" % [name, biome])


# --- Fallback para bioma desconocido ------------------------------------

func test_unknown_biome_returns_non_empty_name():
	var name := ProvinceNameGenerator.generate("BiomaNoCatalogado", Vector2(0, 0))
	assert_ne(name, "", "Un bioma desconocido debe usar el fallback y no devolver vacío")


# --- Cobertura de posiciones extremas -----------------------------------

func test_negative_positions_work():
	var name := ProvinceNameGenerator.generate("Desert", Vector2(-50, -50))
	assert_ne(name, "")


func test_zero_position_works():
	var name := ProvinceNameGenerator.generate("Ocean", Vector2(0, 0))
	assert_ne(name, "")


func test_large_position_works():
	var name := ProvinceNameGenerator.generate("Tundra", Vector2(999, 999))
	assert_ne(name, "")
