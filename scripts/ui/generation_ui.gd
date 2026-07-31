extends Control
class_name GenerationUI

@onready var seed_spin_box: SpinBox = %SeedSpinBox
@onready var random_seed_button: Button = %RandomSeedButton
@onready var radius_value: Label = %RadiusValue
@onready var radius_slider: HSlider = %RadiusSlider
@onready var shape_option_button: OptionButton = %ShapeOptionButton

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
var biome_ui_map: Dictionary



func _ready() -> void:
	settings = _make_default_settings()
	biome_ui_map = _build_biome_ui_map()

	setup_shape_options()
	load_settings_to_ui()
	generate_button.grab_focus()


## Ajustes de generación por defecto: ruidos, biomas y sus pesos, recursos
## naturales e imperios en juego.
##
## DEUDA ANOTADA: esto son valores de DOMINIO viviendo en la UI. Su sitio natural
## sería una fábrica junto a GenerationSettings, pero mover los ~25 `preload` de
## casillas, recursos e imperios al dominio es un cambio mayor y con riesgo de
## ciclos de clase (ver [SceneGroups]), así que aquí solo se separa de la
## construcción de la interfaz.
func _make_default_settings() -> GenerationSettings:
	var s := GenerationSettings.new()

	s.biome_noise = _make_noise(5, 0.1555)
	s.ocean_tile = OCEAN
	s.ocean_noise = _make_noise(3, 0.11111)
	s.mountain_tile = MOUNTAIN
	s.mountain_noise = _make_noise(1, 0.121212)

	s.tiles = [GRASSLAND, DESERT, FOREST, SWAMP, TUNDRA]
	s.biome_weights = [0.5, 0.3, 0.2, 0.4, 0.1]
	# Local TIPADO y luego asignación: `natural_resources` es Array[NaturalResource]
	# y volcarle un literal suelto es de los sitios donde GDScript falla en
	# EJECUCIÓN, no al parsear — y este camino (pantalla de generación) no lo cubre
	# ningún test.
	var resources: Array[NaturalResource] = [FISH, GOLD, IRON, LIVESTOCK, SALT,
		STONE, SAND, WHEAT, WILD_GAME, WOOD]
	s.natural_resources = resources

	s.empires.append(MONGOL)
	s.empires.append(MEDICI)
	s.empires.append(BABYLONIAN)
	s.player_empire = selected_empire if selected_empire else MONGOL
	return s


func _make_noise(noise_type: int, frequency: float) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.noise_type = noise_type
	noise.frequency = frequency
	return noise


## Empareja cada bioma con sus controles del .tscn (casilla de activación y
## deslizador de densidad con su etiqueta de valor).
func _build_biome_ui_map() -> Dictionary:
	return {
		"grassland": {"resource": GRASSLAND, "check": %GrasslandCheck, "density": %GrasslandDensity, "density_value": %GrasslandDensityValue},
		"forest":    {"resource": FOREST,    "check": %ForestCheck,    "density": %ForestDensity,    "density_value": %ForestDensityValue},
		"desert":    {"resource": DESERT,    "check": %DesertCheck,    "density": %DesertDensity,    "density_value": %DesertDensityValue},
		"swamp":     {"resource": SWAMP,     "check": %SwampCheck,     "density": %SwampDensity,     "density_value": %SwampDensityValue},
		"tundra":    {"resource": TUNDRA,    "check": %TundraCheck,    "density": %TundraDensity,    "density_value": %TundraDensityValue},
	}


func setup_shape_options() -> void:
	shape_option_button.clear()
	for shape in GenerationSettings.shape:
		shape_option_button.add_item(str(shape),GenerationSettings.shape.get(shape))


func load_settings_to_ui():
	seed_spin_box.value = settings.map_seed
	radius_slider.value = settings.radius
	radius_value.text = str(settings.radius)
	shape_option_button.selected = settings.map_shape
	
	
	for biome_key in biome_ui_map:
		_setup_biome_ui(biome_key)
	
	%MountainCheck.button_pressed = settings.create_mountains
	%MountainDensity.value = settings.mountain_threshold
	%MountainDensityValue.text = "%.2f" % settings.mountain_threshold

	%OceanCheck.button_pressed = settings.create_water
	%OceanDensity.value = settings.ocean_threshold
	%OceanDensityValue.text = "%.2f" % settings.ocean_threshold
	
	# Buffers
	outer_buffer_spin_box.value = settings.outer_buffer
	inner_buffer_spin_box.value = settings.inner_buffer
	inner_buffer_spin_box.max_value = settings.radius
	outer_buffer_spin_box.max_value = settings.inner_buffer



func _setup_biome_ui(biome_key: String) -> void:
	var d = biome_ui_map[biome_key]
	var idx: int = settings.tiles.find(d["resource"])
	var is_selected: bool = idx != -1
	d["check"].button_pressed = is_selected
	if is_selected:
		d["density"].value = settings.biome_weights.get(idx)
		d["density_value"].text = "%.2f" % d["density"].value
	else:
		d["density"].value = 0.5
		d["density_value"].text = "%.2f" % 0.5


func _on_biome_check_toggled(biome_key: String, toggled_on: bool) -> void:
	var d = biome_ui_map[biome_key]
	d["density"].editable = toggled_on
	if toggled_on:
		settings.tiles.append(d["resource"])
		_update_biome_weight(settings.tiles.find(d["resource"]), d["density"].value)
	else:
		settings.biome_weights.pop_at(settings.tiles.find(d["resource"]))
		settings.tiles.erase(d["resource"])


func _on_biome_density_value_changed(biome_key: String, value: float) -> void:
	var d = biome_ui_map[biome_key]
	d["density_value"].text = "%.2f" % value
	_update_biome_weight(settings.tiles.find(d["resource"]), value)


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
	_on_biome_check_toggled("grassland", toggled_on)

func _on_grassland_density_value_changed(value: float) -> void:
	_on_biome_density_value_changed("grassland", value)

func _on_forest_check_toggled(toggled_on: bool) -> void:
	_on_biome_check_toggled("forest", toggled_on)

func _on_forest_density_value_changed(value: float) -> void:
	_on_biome_density_value_changed("forest", value)

func _on_desert_check_toggled(toggled_on: bool) -> void:
	_on_biome_check_toggled("desert", toggled_on)

func _on_desert_density_value_changed(value: float) -> void:
	_on_biome_density_value_changed("desert", value)

func _on_swamp_check_toggled(toggled_on: bool) -> void:
	_on_biome_check_toggled("swamp", toggled_on)

func _on_swamp_density_value_changed(value: float) -> void:
	_on_biome_density_value_changed("swamp", value)

func _on_tundra_check_toggled(toggled_on: bool) -> void:
	_on_biome_check_toggled("tundra", toggled_on)

func _on_tundra_density_value_changed(value: float) -> void:
	_on_biome_density_value_changed("tundra", value)

func _on_ocean_check_toggled(toggled_on: bool) -> void:
	settings.create_water = toggled_on
	%OceanDensity.editable = toggled_on

func _on_ocean_density_value_changed(value: float) -> void:
	%OceanDensityValue.text = "%.2f" % value
	settings.ocean_threshold = 0.7 - value * 0.2

func _on_mountain_check_toggled(toggled_on: bool) -> void:
	settings.create_mountains = toggled_on
	%MountainDensity.editable = toggled_on

func _on_mountain_density_value_changed(value: float) -> void:
	%MountainDensityValue.text = "%.2f" % value
	settings.mountain_threshold = 0.7 - value * 0.2

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
	GameLogger.info("=== GENERANDO MAPA ===")
	GameLogger.info("Seed: " + str(settings.map_seed))
	GameLogger.info("Noise: " + str(settings.biome_noise.noise_type))
	GameLogger.info("Radio: " + str(settings.radius))
	GameLogger.info("Forma: " + str(settings.map_shape))
	GameLogger.info("Biomas activos: " + str(settings.biome_weights))
	GameLogger.info("Montañas: " + str(settings.create_mountains) + " - Umbral: " + str(settings.mountain_threshold))
	GameLogger.info("Océano: " + str(settings.create_water) + " - Umbral: " + str(settings.ocean_threshold))
	GameLogger.info("Buffers: Ext:" + str(settings.outer_buffer) + " Int:" + str(settings.inner_buffer))
	# Prepare stats with the selected empire
	var stats_template:Stats = INITIAL_STATS.duplicate()
	stats_template.empire = settings.player_empire
	Events.generate_world.emit(settings, stats_template)
