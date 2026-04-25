extends GutTest
## Tests para GridMapper (cálculos de posición, formas de mapa, filtros),
## GenerationSettings, y PositionData.


# ============================================================
#  Helpers
# ============================================================

func _make_settings(p_radius: int = 4, p_shape: GenerationSettings.shape = GenerationSettings.shape.HEXAGONAL) -> GenerationSettings:
	var s := GenerationSettings.new()
	s.radius = p_radius
	s.map_shape = p_shape
	s.tile_size = 1.0
	s.create_water = false
	s.create_mountains = false
	s.outer_buffer = 1
	s.inner_buffer = 2
	s.debug = false
	s.biome_noise = FastNoiseLite.new()
	s.ocean_noise = FastNoiseLite.new()
	s.mountain_noise = FastNoiseLite.new()
	s.mountain_treshold = 0.6
	s.ocean_treshold = 0.6
	s.tiles = []
	s.biome_weights = []
	s.natural_resources = []
	s.empires = []
	return s


# ============================================================
#  GridMapper.tile_to_world
# ============================================================

func test_tile_to_world_origin_stagger():
	var mapper := GridMapper.new()
	mapper.settings = _make_settings()
	var pos := mapper.tile_to_world(0, 0, true)
	assert_almost_eq(pos.x, 0.0, 0.001)
	assert_almost_eq(pos.z, 0.0, 0.001)


func test_tile_to_world_origin_no_stagger():
	var mapper := GridMapper.new()
	mapper.settings = _make_settings()
	var pos := mapper.tile_to_world(0, 0, false)
	assert_almost_eq(pos.x, 0.0, 0.001)
	assert_almost_eq(pos.z, 0.0, 0.001)


func test_tile_to_world_horizontal_spacing():
	var mapper := GridMapper.new()
	mapper.settings = _make_settings()
	var pos0 := mapper.tile_to_world(0, 0, true)
	var pos1 := mapper.tile_to_world(1, 0, true)
	# Horizontal spacing for flat-top hex: 3/2 * col
	assert_almost_eq(pos1.x - pos0.x, 1.5, 0.001)


func test_tile_to_world_y_is_zero():
	var mapper := GridMapper.new()
	mapper.settings = _make_settings()
	var pos := mapper.tile_to_world(3, 2, true)
	assert_almost_eq(pos.y, 0.0, 0.001, "Height should always be 0")


func test_tile_to_world_tile_size_scales():
	var s := _make_settings()
	s.tile_size = 2.0
	var mapper := GridMapper.new()
	mapper.settings = s
	var pos := mapper.tile_to_world(1, 0, false)
	# x = 3/2 * 1 * tile_size = 3.0
	assert_almost_eq(pos.x, 3.0, 0.001)


# ============================================================
#  GridMapper.noise_at_tile
# ============================================================

func test_noise_at_tile_normalized():
	var mapper := GridMapper.new()
	mapper.settings = _make_settings()
	var noise := FastNoiseLite.new()
	noise.seed = 42
	# Test multiple positions - should all be in [0, 1]
	for c in range(-5, 6):
		for r in range(-5, 6):
			var val := mapper.noise_at_tile(c, r, noise)
			assert_true(val >= 0.0 and val <= 1.0,
				"Noise at (%d,%d) should be in [0,1], got %f" % [c, r, val])


# ============================================================
#  GridMapper shape filters
# ============================================================

func test_circle_shape_filter_origin():
	var mapper := GridMapper.new()
	mapper.settings = _make_settings(5)
	assert_true(mapper.circle_shape_filter(0, 0), "Origin should be in circle")


func test_circle_shape_filter_inside():
	var mapper := GridMapper.new()
	mapper.settings = _make_settings(5)
	assert_true(mapper.circle_shape_filter(2, 2), "Point inside circle")


func test_circle_shape_filter_outside():
	var mapper := GridMapper.new()
	mapper.settings = _make_settings(3)
	assert_false(mapper.circle_shape_filter(3, 3), "Point outside circle")


func test_diamond_shape_filter_origin():
	var mapper := GridMapper.new()
	mapper.settings = _make_settings(5)
	assert_true(mapper.diamond_shape_filter(0, 0))


func test_diamond_shape_filter_outside():
	var mapper := GridMapper.new()
	mapper.settings = _make_settings(3)
	assert_false(mapper.diamond_shape_filter(2, 2), "|2|+|2|=4 >= 3")


# ============================================================
#  GridMapper buffer filters
# ============================================================

func test_hexagonal_buffer_filter_center_inside():
	var mapper := GridMapper.new()
	mapper.settings = _make_settings(5)
	# Center should NOT be in buffer
	assert_false(mapper.hexagonal_buffer_filter(0, 0, 3))


func test_hexagonal_buffer_filter_edge_outside():
	var mapper := GridMapper.new()
	mapper.settings = _make_settings(5)
	assert_true(mapper.hexagonal_buffer_filter(4, 0, 3))


func test_rectangular_buffer_filter():
	var mapper := GridMapper.new()
	mapper.settings = _make_settings(5)
	assert_false(mapper.rectangular_buffer_filter(0, 0, 3))
	assert_true(mapper.rectangular_buffer_filter(4, 0, 3))


func test_circular_buffer_filter():
	var mapper := GridMapper.new()
	mapper.settings = _make_settings(5)
	assert_false(mapper.circular_buffer_filter(0, 0, 3), "Center not in buffer")
	assert_true(mapper.circular_buffer_filter(3, 2, 3), "Far point in buffer")


func test_diamond_buffer_filter():
	var mapper := GridMapper.new()
	mapper.settings = _make_settings(5)
	assert_false(mapper.diamond_buffer_filter(0, 0, 3))
	assert_true(mapper.diamond_buffer_filter(2, 2, 3), "|2|+|2|=4 >= 3")


# ============================================================
#  GridMapper.find_noise_caps
# ============================================================

func test_find_noise_caps():
	var mapper := GridMapper.new()
	mapper.settings = _make_settings()
	var positions: Array = []
	var p1 := PositionData.new()
	p1.noise = 0.3
	var p2 := PositionData.new()
	p2.noise = 0.8
	var p3 := PositionData.new()
	p3.noise = 0.1
	positions = [p1, p2, p3]
	var caps := mapper.find_noise_caps(positions)
	assert_almost_eq(caps.x, 0.1, 0.001, "Min noise should be 0.1")
	assert_almost_eq(caps.y, 0.8, 0.001, "Max noise should be 0.8")


# ============================================================
#  GridMapper.generate_position
# ============================================================

func test_generate_position():
	var mapper := GridMapper.new()
	mapper.settings = _make_settings()
	var pos := mapper.generate_position(2, 3, true)
	assert_eq(pos.grid_position, Vector2i(2, 3))
	assert_almost_eq(pos.world_position.x, 3.0, 0.001, "x = 3/2 * 2 = 3")


# ============================================================
#  GenerationSettings
# ============================================================

func test_generation_settings_defaults():
	var s := GenerationSettings.new()
	assert_eq(s.tile_size, 1.0)
	assert_eq(s.map_shape, GenerationSettings.shape.HEXAGONAL)


func test_generation_settings_shape_enum():
	assert_eq(GenerationSettings.shape.HEXAGONAL, 0)
	assert_eq(GenerationSettings.shape.RECTANGULAR, 1)
	assert_eq(GenerationSettings.shape.DIAMOND, 2)
	assert_eq(GenerationSettings.shape.CIRCLE, 3)
