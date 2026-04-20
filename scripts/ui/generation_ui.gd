extends Control
class_name GenerationUI

@onready var seed_spin_box: SpinBox = %SeedSpinBox
@onready var random_seed_button: Button = %RandomSeedButton
@onready var radius_value: Label = %RadiusValue
@onready var radius_slider: HSlider = %RadiusSlider
@onready var shape_option_button: OptionButton = %ShapeOptionButton

@onready var grassland_check: CheckBox = %GrasslandCheck
@onready var grassland_density: HSlider = %GrasslandDensity
@onready var grassland_density_value: Label = %GrasslandDensityValue
@onready var forest_check: CheckBox = %ForestCheck
@onready var forest_density: HSlider = %ForestDensity
@onready var forest_density_value: Label = %ForestDensityValue
@onready var desert_check: CheckBox = %DesertCheck
@onready var desert_density: HSlider = %DesertDensity
@onready var desert_density_value: Label = %DesertDensityValue
@onready var swamp_check: CheckBox = %SwampCheck
@onready var swamp_density: HSlider = %SwampDensity
@onready var swamp_density_value: Label = %SwampDensityValue
@onready var tundra_check: CheckBox = %TundraCheck
@onready var tundra_density: HSlider = %TundraDensity
@onready var tundra_density_value: Label = %TundraDensityValue

@onready var ocean_check: CheckBox = %OceanCheck
@onready var ocean_density: HSlider = %OceanDensity
@onready var ocean_density_value: Label = %OceanDensityValue

@onready var mountain_check: CheckBox = %MountainCheck
@onready var mountain_density: HSlider = %MountainDensity
@onready var mountain_density_value: Label = %MountainDensityValue

@onready var outer_buffer_spin_box: SpinBox = %OuterBufferSpinBox
@onready var inner_buffer_spin_box: SpinBox = %InnerBufferSpinBox

@onready var generate_button: Button = %GenerationButton

const DESERT = preload("uid://fdtmsxpg31sc")
const FOREST = preload("uid://d37byfwefsudv")
const GRASSLAND = preload("uid://bcxmjb1pjcnsj")
const MOUNTAIN = preload("uid://wcupwklnw38j")
const OCEAN = preload("uid://ocx6xpafcagw")
const SWAMP = preload("uid://ndof7a80hfxe")
const TUNDRA = preload("uid://digb4xqb5ftle")

const FISH = preload("uid://oo7b8gl1jhg")
const GOLD = preload("uid://b54xf0rwim6kw")
const IRON = preload("uid://c2jvo50o3o5gh")
const LIVESTOCK = preload("uid://bdc8ttqwuh7kc")
const SALT = preload("uid://b1glfrb7777r0")
const SAND = preload("uid://cmixmuy45uhbr")
const STONE = preload("uid://x52d3rkafp3")
const WHEAT = preload("uid://d24re8efjrw3")
const WILD_GAME = preload("uid://hrxtpk1h8o5y")
const WOOD = preload("uid://qm6yeu6t77kn")

const BABYLONIAN = preload("uid://dlljlcjgbqsv5")
const MONGOL = preload("uid://b4mhfidkmt6ag")
const MEDICI = preload("uid://ba6dn1gfrs32d")

const INITIAL_STATS = preload("uid://cwfokudqrj6s1")

var settings:GenerationSettings
var selected_empire:Empire



func _ready() -> void:
	settings = GenerationSettings.new()
	settings.tiles = []
	var biome_noise = FastNoiseLite.new()
	biome_noise.noise_type = 5
	biome_noise.frequency = 0.1555
	settings.biome_noise = biome_noise
	
	settings.ocean_tile = OCEAN
	var ocean_noise = FastNoiseLite.new()
	ocean_noise.noise_type = 3
	ocean_noise.frequency = 0.11111
	settings.ocean_noise = ocean_noise
	
	settings.mountain_tile = MOUNTAIN
	var mountain_noise = FastNoiseLite.new()
	mountain_noise.noise_type = 1
	mountain_noise.frequency = 0.121212
	settings.mountain_noise = mountain_noise
	
	settings.tiles = [GRASSLAND,DESERT,FOREST, SWAMP, TUNDRA]
	settings.biome_weights = [0.5, 0.3, 0.2, 0.4, 0.1]
	

	settings.natural_resources = []
	settings.natural_resources.append(FISH)
	settings.natural_resources.append(GOLD)
	settings.natural_resources.append(IRON)
	settings.natural_resources.append(LIVESTOCK)
	settings.natural_resources.append(SALT)
	settings.natural_resources.append(STONE)
	settings.natural_resources.append(SAND)
	settings.natural_resources.append(WHEAT)
	settings.natural_resources.append(WILD_GAME)
	settings.natural_resources.append(WOOD)
	
	settings.empires.append(MONGOL)
	settings.empires.append(MEDICI)
	settings.empires.append(BABYLONIAN)
	if selected_empire:
		settings.player_empire = selected_empire
	else:
		settings.player_empire = MONGOL

	setup_shape_options()
	
	load_settings_to_ui()
	

func setup_shape_options() -> void:
	shape_option_button.clear()
	for shape in GenerationSettings.shape:
		shape_option_button.add_item(str(shape),GenerationSettings.shape.get(shape))


func load_settings_to_ui():
	seed_spin_box.value = settings.map_seed
	radius_slider.value = settings.radius
	radius_value.text = str(settings.radius)
	shape_option_button.selected = settings.map_shape
	
	
	grassland_check.button_pressed = settings.tiles.find(GRASSLAND) != -1
	if grassland_check.button_pressed:
		grassland_density.value = settings.biome_weights.get(settings.tiles.find(GRASSLAND))
		grassland_density_value.text = "%.2f" % grassland_density.value
	else:
		grassland_density.value = 0.5
		grassland_density_value.text = "%.2f" % 0.5
	forest_check.button_pressed = settings.tiles.find(FOREST) != -1
	if forest_check.button_pressed:
		forest_density.value = settings.biome_weights.get(settings.tiles.find(FOREST))
		forest_density_value.text = "%.2f" % forest_density.value
	else:
		forest_density.value = 0.5
		forest_density_value.text = "%.2f" % 0.5
	desert_check.button_pressed = settings.tiles.find(DESERT) != -1
	if desert_check.button_pressed:
		desert_density.value = settings.biome_weights.get(settings.tiles.find(DESERT))
		desert_density_value.text = "%.2f" % desert_density.value
	else:
		desert_density.value = 0.5
		desert_density_value.text = "%.2f" % 0.5
	swamp_check.button_pressed = settings.tiles.find(SWAMP) != -1
	if swamp_check.button_pressed:
		swamp_density.value = settings.biome_weights.get(settings.tiles.find(SWAMP))
		swamp_density_value.text = "%.2f" % swamp_density.value
	else:
		swamp_density.value = 0.5
		swamp_density_value.text = "%.2f" % 0.5
	tundra_check.button_pressed = settings.tiles.find(TUNDRA) != -1
	if tundra_check.button_pressed:
		tundra_density.value = settings.biome_weights.get(settings.tiles.find(TUNDRA))
		tundra_density_value.text = "%.2f" % tundra_density.value
	else:
		tundra_density.value = 0.5
		tundra_density_value.text = "%.2f" % 0.5
	
	mountain_check.button_pressed = settings.create_mountains
	mountain_density.value = settings.mountain_treshold
	mountain_density_value.text = "%.2f" % settings.mountain_treshold
	
	ocean_check.button_pressed = settings.create_water
	ocean_density.value = settings.ocean_treshold
	ocean_density_value.text = "%.2f" % settings.ocean_treshold
	
	# Buffers
	outer_buffer_spin_box.value = settings.outer_buffer
	inner_buffer_spin_box.value = settings.inner_buffer
	inner_buffer_spin_box.max_value = settings.radius
	outer_buffer_spin_box.max_value = settings.inner_buffer



func _update_biome_weight(index: int, value: float):
	while settings.biome_weights.size() <= index:
		settings.biome_weights.append(0.0)
	
	settings.biome_weights[index] = value


func _on_seed_spin_box_value_changed(value: float) -> void:
	settings.map_seed = int(value)

func _on_random_seed_button_pressed() -> void:
	var random_seed = randi_range(0, 999999)
	seed_spin_box.value = random_seed
	settings.map_seed = random_seed


func _on_radius_slider_value_changed(value: float) -> void:
	var new_radius = int(value)
	settings.radius = new_radius
	radius_value.text = str(new_radius)
	
	inner_buffer_spin_box.max_value = new_radius
	if inner_buffer_spin_box.value > new_radius:
		inner_buffer_spin_box.value = new_radius




func _on_shape_option_button_item_selected(index: int) -> void:
	@warning_ignore("int_as_enum_without_cast")
	settings.map_shape = shape_option_button.get_item_id(index)

func _on_grassland_check_toggled(toggled_on: bool) -> void:
	grassland_density.editable = toggled_on
	if toggled_on:
		settings.tiles.append(GRASSLAND)
		_update_biome_weight(settings.tiles.find(GRASSLAND), grassland_density.value)
	else:
		settings.biome_weights.pop_at(settings.tiles.find(GRASSLAND))
		settings.tiles.erase(GRASSLAND)

func _on_grassland_density_value_changed(value: float) -> void:
	grassland_density_value.text = "%.2f" % value
	_update_biome_weight(settings.tiles.find(GRASSLAND), value)

func _on_forest_check_toggled(toggled_on: bool) -> void:
	forest_density.editable = toggled_on
	if toggled_on:
		settings.tiles.append(FOREST)
		_update_biome_weight(settings.tiles.find(FOREST), forest_density.value)
	else:
		settings.biome_weights.pop_at(settings.tiles.find(FOREST))
		settings.tiles.erase(FOREST)


func _on_forest_density_value_changed(value: float) -> void:
	forest_density_value.text = "%.2f" % value
	_update_biome_weight(settings.tiles.find(FOREST), value)

func _on_desert_check_toggled(toggled_on: bool) -> void:
	desert_density.editable = toggled_on
	if toggled_on:
		settings.tiles.append(DESERT)
		_update_biome_weight(settings.tiles.find(DESERT), desert_density.value)
	else:
		settings.biome_weights.pop_at(settings.tiles.find(DESERT))
		settings.tiles.erase(DESERT)

func _on_desert_density_value_changed(value: float) -> void:
	desert_density_value.text = "%.2f" % value
	_update_biome_weight(settings.tiles.find(DESERT), value)


func _on_swamp_check_toggled(toggled_on: bool) -> void:
	swamp_density.editable = toggled_on
	if toggled_on:
		settings.tiles.append(SWAMP)
		_update_biome_weight(settings.tiles.find(SWAMP), swamp_density.value)
	else:
		settings.biome_weights.pop_at(settings.tiles.find(SWAMP))
		settings.tiles.erase(SWAMP)


func _on_swamp_density_value_changed(value: float) -> void:
	swamp_density_value.text = "%.2f" % value
	_update_biome_weight(settings.tiles.find(SWAMP), value)

func _on_tundra_check_toggled(toggled_on: bool) -> void:
	tundra_density.editable = toggled_on
	if toggled_on:
		settings.tiles.append(TUNDRA)
		_update_biome_weight(settings.tiles.find(TUNDRA), tundra_density.value)
	else:
		settings.biome_weights.pop_at(settings.tiles.find(TUNDRA))
		settings.tiles.erase(TUNDRA)

func _on_tundra_density_value_changed(value: float) -> void:
	tundra_density_value.text = "%.2f" % value
	_update_biome_weight(settings.tiles.find(TUNDRA), value)

func _on_ocean_check_toggled(toggled_on: bool) -> void:
	settings.create_water = toggled_on
	ocean_density.editable = toggled_on

func _on_ocean_density_value_changed(value: float) -> void:
	ocean_density_value.text = "%.2f" % value
	settings.ocean_treshold = 0.7 - value * 0.2

func _on_mountain_check_toggled(toggled_on: bool) -> void:
	settings.create_mountains = toggled_on
	mountain_density.editable = toggled_on

func _on_mountain_density_value_changed(value: float) -> void:
	mountain_density_value.text = "%.2f" % value
	settings.mountain_treshold = 0.7 - value * 0.2

func _on_outer_buffer_spin_box_value_changed(value: float) -> void:
	settings.outer_buffer = int(value)

func _on_inner_buffer_spin_box_value_changed(value: float) -> void:
	var new_inner = int(value)
	settings.inner_buffer = new_inner
	
	outer_buffer_spin_box.max_value = new_inner-1
	if outer_buffer_spin_box.value >= new_inner:
		outer_buffer_spin_box.value = new_inner-1

func _on_generation_button_pressed() -> void:
	settings.empires.erase(settings.player_empire)
	# Solo 1 imperio IA: elegir uno aleatorio y descartar el resto
	var ai_empire:Empire = settings.empires.pick_random()
	settings.empires = [ai_empire]
	print("=== GENERANDO MAPA ===")
	print("Seed: ", settings.map_seed)
	print("Noise: ", settings.biome_noise.noise_type)
	print("Radio: ", settings.radius)
	print("Forma: ", settings.map_shape)
	print("Biomas activos: ", settings.biome_weights)
	print("Montañas: ", settings.create_mountains, " - Umbral: ", settings.mountain_treshold)
	print("Océano: ", settings.create_water, " - Umbral: ", settings.ocean_treshold)
	print("Buffers: Ext:", settings.outer_buffer, " Int:", settings.inner_buffer)
	# Prepare stats with the selected empire
	var stats_template:Stats = INITIAL_STATS.duplicate()
	stats_template.empire = settings.player_empire
	Events.generate_world.emit(settings, stats_template)
