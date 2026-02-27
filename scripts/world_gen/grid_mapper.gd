extends Object
class_name GridMapper

var settings : GenerationSettings

## Main entry point, Get all positions to spawn tiles on
func calculate_map_positions(in_settings: GenerationSettings) -> MappingData:
	settings = in_settings
	var map = MappingData.new()
	var positions : Array[PositionData]

## Diamond and Circle also use the rectangular bounds. They carve our their shape from that rectangle
## using their individual shape filters 
	var stagger : bool
	match settings.map_shape:
		0:
			stagger = false
			positions = generate_map(hexagonal_bounds(), stagger, hexagonal_buffer_filter)
		1:
			stagger = true
			positions = generate_map(rectangle_bounds(), stagger, rectangular_buffer_filter)
		2:
			stagger = true
			positions = generate_map(rectangle_bounds(), stagger, diamond_buffer_filter, diamond_shape_filter)
		3:
			stagger = true
			positions = generate_map(rectangle_bounds(), stagger, circular_buffer_filter, circle_shape_filter)

	map.positions = positions
	map.noise_data = find_noise_caps(positions)
	WorldMap.is_map_staggered = stagger
	return map


func generate_map(loop_bounds: Callable, stagger: bool, buffer_filter: Callable, shape_filter: Callable = Callable()) -> Array[PositionData]:
	var map_data: Array[PositionData] = []
	for c in loop_bounds.call():
		for r in loop_bounds.call(c):
			if shape_filter and not shape_filter.call(c, r):
				continue
			var pos = generate_position(c, r, stagger)
			modify_position(pos, buffer_filter) #Hills, ocean, buffer
			map_data.append(pos)
	return map_data


func generate_position(c, r, stagger) -> PositionData:
	var new_pos = PositionData.new()
	new_pos.world_position = tile_to_world(c, r, stagger)
	new_pos.grid_position = Vector2(c, r)
	return new_pos

func modify_position(pos : PositionData, buffer_filter):
	var c = pos.grid_position.x
	var r = pos.grid_position.y
	pos.noise = noise_at_tile(c, r, settings.biome_noise)
	if settings.create_water and (buffer_filter.call(c,r,settings.radius-settings.outer_buffer) or (buffer_filter.call(c,r,settings.radius-settings.inner_buffer) and noise_at_tile(c,r,settings.ocean_noise) > settings.ocean_treshold)):
		pos.water = true
	elif settings.create_mountains and (noise_at_tile(c, r, settings.mountain_noise) > settings.mountain_treshold):
		pos.mountain = true
	
	if !buffer_filter.call(c,r,settings.radius-settings.outer_buffer) and buffer_filter.call(c,r,settings.radius-settings.inner_buffer):
		pos.buffer = true


## Get the world position for flat-side hexagons
func tile_to_world(col: int, row: int, stagger: bool) -> Vector3:
	var SQRT3 = sqrt(3)
	var x: float = 3.0 / 2.0 * col  # Horizontal spacing
	var z: float
	if stagger:
		z = row * SQRT3 + ((col % 2 + 2) % 2) * (SQRT3 / 2)
	else:
		z = (row * SQRT3 + (col * SQRT3 / 2))
	return Vector3(x * settings.tile_size, 0, z * settings.tile_size)


## Get noise at position of tile
func noise_at_tile(c, r, texture : FastNoiseLite) -> float:
	var value : float = texture.get_noise_2d(c, r)
	return (value + 1) / 2 # normalize [0, 1]


func find_noise_caps(positions) -> Vector2:
	var min_max_noise = Vector2(999999.0, -999999.0)
	for pos in positions:
		if pos.noise < min_max_noise.x:
			min_max_noise.x = pos.noise
		if pos.noise > min_max_noise.y:
			min_max_noise.y = pos.noise
	return min_max_noise


### Bounds
### # Specific bounds functions for each shape

func hexagonal_bounds() -> Callable:
	return func(col = null):
		if col == null:
			return range(-settings.radius, settings.radius + 1)
		else:
			return range(max(-settings.radius, -col - settings.radius), min(settings.radius, -col + settings.radius) + 1)


func rectangle_bounds() -> Callable:
	return func(_col = null):
		return range(-settings.radius, settings.radius + 1)


### Filters
### # Filters positions to keep only tiles inside a shape

func circle_shape_filter(col: int, row: int) -> bool:
	var dist = sqrt(col * col + row * row)
	return dist < settings.radius


func diamond_shape_filter(col: int, row: int) -> bool:
	var adjusted_row = row
	if col % 2 != 0:
		adjusted_row += 0.5 
	return abs(adjusted_row) + abs(col) < settings.radius


### Buffer-filters!
### Filter out buffer tiles

func hexagonal_buffer_filter(col: int, row: int, limit: int) -> bool:
	return abs(col + row) > limit or abs(col) > limit or abs(row) > limit


func rectangular_buffer_filter(col: int, row: int, limit: int) -> bool:
	return abs(col) > limit or abs(row) > limit


func diamond_buffer_filter(col: int, row: int, limit: int) -> bool:
	return abs(row) + abs(col) >= limit


func circular_buffer_filter(col: int, row: int, limit: int) -> bool:
	return col * col + row * row > limit * limit
