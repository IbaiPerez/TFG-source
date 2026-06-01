extends Control
class_name GenerationUI

# Node references (initialized in _ready)
var seed_spin_box: SpinBox
var random_seed_button: Button
var radius_value: Label
var radius_slider: HSlider
var shape_option_button: OptionButton

var grassland_check: CheckBox
var grassland_density: HSlider
var grassland_density_value: Label
var forest_check: CheckBox
var forest_density: HSlider
var forest_density_value: Label
var desert_check: CheckBox
var desert_density: HSlider
var desert_density_value: Label
var swamp_check: CheckBox
var swamp_density: HSlider
var swamp_density_value: Label
var tundra_check: CheckBox
var tundra_density: HSlider
var tundra_density_value: Label

var ocean_check: CheckBox
var ocean_density: HSlider
var ocean_density_value: Label

var mountain_check: CheckBox
var mountain_density: HSlider
var mountain_density_value: Label

var outer_buffer_spin_box: SpinBox
var inner_buffer_spin_box: SpinBox

var generate_button: Button
var generation_settings_panel: PanelContainer

# Biome and resource preloads
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

var settings: GenerationSettings
var selected_empire: Empire
var biome_ui_map: Dictionary


func _ready() -> void:
	_setup_theme()
	_initialize_references()

	# Validate that all references were initialized
	if not _validate_references():
		push_error("GenerationUI: Failed to initialize all node references")
		return

	# Initialize settings
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

	settings.tiles = [GRASSLAND, DESERT, FOREST, SWAMP, TUNDRA]
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

	biome_ui_map = {
		"grassland": {"resource": GRASSLAND, "check": grassland_check, "density": grassland_density, "density_value": grassland_density_value},
		"forest":    {"resource": FOREST,    "check": forest_check,    "density": forest_density,    "density_value": forest_density_value},
		"desert":    {"resource": DESERT,    "check": desert_check,    "density": desert_density,    "density_value": desert_density_value},
		"swamp":     {"resource": SWAMP,     "check": swamp_check,     "density": swamp_density,     "density_value": swamp_density_value},
		"tundra":    {"resource": TUNDRA,    "check": tundra_check,    "density": tundra_density,    "density_value": tundra_density_value},
	}

	# Connect signals for all UI controls
	_connect_signals()

	setup_shape_options()
	load_settings_to_ui()


func _initialize_references() -> void:
	# Use find_child() to get node references
	# These nodes have unique_name_in_owner = true, so they can be found by name

	seed_spin_box = find_child("SeedSpinBox", true, false) as SpinBox
	random_seed_button = find_child("RandomSeedButton", true, false) as Button
	radius_value = find_child("RadiusValue", true, false) as Label
	radius_slider = find_child("RadiusSlider", true, false) as HSlider
	shape_option_button = find_child("ShapeOptionButton", true, false) as OptionButton

	grassland_check = find_child("GrasslandCheck", true, false) as CheckBox
	grassland_density = find_child("GrasslandDensity", true, false) as HSlider
	grassland_density_value = find_child("GrasslandDensityValue", true, false) as Label
	forest_check = find_child("ForestCheck", true, false) as CheckBox
	forest_density = find_child("ForestDensity", true, false) as HSlider
	forest_density_value = find_child("ForestDensityValue", true, false) as Label
	desert_check = find_child("DesertCheck", true, false) as CheckBox
	desert_density = find_child("DesertDensity", true, false) as HSlider
	desert_density_value = find_child("DesertDensityValue", true, false) as Label
	swamp_check = find_child("SwampCheck", true, false) as CheckBox
	swamp_density = find_child("SwampDensity", true, false) as HSlider
	swamp_density_value = find_child("SwampDensityValue", true, false) as Label
	tundra_check = find_child("TundraCheck", true, false) as CheckBox
	tundra_density = find_child("TundraDensity", true, false) as HSlider
	tundra_density_value = find_child("TundraDensityValue", true, false) as Label

	ocean_check = find_child("OceanCheck", true, false) as CheckBox
	ocean_density = find_child("OceanDensity", true, false) as HSlider
	ocean_density_value = find_child("OceanDensityValue", true, false) as Label

	mountain_check = find_child("MountainCheck", true, false) as CheckBox
	mountain_density = find_child("MountainDensity", true, false) as HSlider
	mountain_density_value = find_child("MountainDensityValue", true, false) as Label

	outer_buffer_spin_box = find_child("OuterBufferSpinBox", true, false) as SpinBox
	inner_buffer_spin_box = find_child("InnerBufferSpinBox", true, false) as SpinBox

	generate_button = find_child("GenerateButton", true, false) as Button
	generation_settings_panel = find_child("GenerationSettings", true, false) as PanelContainer


func _validate_references() -> bool:
	var all_valid = true

	# Validate critical nodes for setup_shape_options()
	if shape_option_button == null:
		push_error("GenerationUI: shape_option_button not found")
		all_valid = false

	# Validate other basic controls
	if seed_spin_box == null:
		push_error("GenerationUI: seed_spin_box not found")
		all_valid = false
	if random_seed_button == null:
		push_error("GenerationUI: random_seed_button not found")
		all_valid = false
	if radius_value == null:
		push_error("GenerationUI: radius_value not found")
		all_valid = false
	if radius_slider == null:
		push_error("GenerationUI: radius_slider not found")
		all_valid = false

	# Validate biome UI controls
	if grassland_check == null:
		push_error("GenerationUI: grassland_check not found")
		all_valid = false
	if grassland_density == null:
		push_error("GenerationUI: grassland_density not found")
		all_valid = false
	if grassland_density_value == null:
		push_error("GenerationUI: grassland_density_value not found")
		all_valid = false
	if forest_check == null:
		push_error("GenerationUI: forest_check not found")
		all_valid = false
	if forest_density == null:
		push_error("GenerationUI: forest_density not found")
		all_valid = false
	if forest_density_value == null:
		push_error("GenerationUI: forest_density_value not found")
		all_valid = false
	if desert_check == null:
		push_error("GenerationUI: desert_check not found")
		all_valid = false
	if desert_density == null:
		push_error("GenerationUI: desert_density not found")
		all_valid = false
	if desert_density_value == null:
		push_error("GenerationUI: desert_density_value not found")
		all_valid = false
	if swamp_check == null:
		push_error("GenerationUI: swamp_check not found")
		all_valid = false
	if swamp_density == null:
		push_error("GenerationUI: swamp_density not found")
		all_valid = false
	if swamp_density_value == null:
		push_error("GenerationUI: swamp_density_value not found")
		all_valid = false
	if tundra_check == null:
		push_error("GenerationUI: tundra_check not found")
		all_valid = false
	if tundra_density == null:
		push_error("GenerationUI: tundra_density not found")
		all_valid = false
	if tundra_density_value == null:
		push_error("GenerationUI: tundra_density_value not found")
		all_valid = false

	# Validate special features
	if ocean_check == null:
		push_error("GenerationUI: ocean_check not found")
		all_valid = false
	if ocean_density == null:
		push_error("GenerationUI: ocean_density not found")
		all_valid = false
	if ocean_density_value == null:
		push_error("GenerationUI: ocean_density_value not found")
		all_valid = false
	if mountain_check == null:
		push_error("GenerationUI: mountain_check not found")
		all_valid = false
	if mountain_density == null:
		push_error("GenerationUI: mountain_density not found")
		all_valid = false
	if mountain_density_value == null:
		push_error("GenerationUI: mountain_density_value not found")
		all_valid = false

	# Validate buffers
	if outer_buffer_spin_box == null:
		push_error("GenerationUI: outer_buffer_spin_box not found")
		all_valid = false
	if inner_buffer_spin_box == null:
		push_error("GenerationUI: inner_buffer_spin_box not found")
		all_valid = false

	# Validate buttons
	if generate_button == null:
		push_error("GenerationUI: generate_button not found")
		all_valid = false

	# Validate panel
	if generation_settings_panel == null:
		push_error("GenerationUI: generation_settings_panel not found")
		all_valid = false

	return all_valid


func _setup_theme() -> void:
	var generation_settings = find_child("GenerationSettings", true, false) as PanelContainer
	if generation_settings == null:
		push_error("GenerationUI: Cannot setup theme - GenerationSettings panel not found")
		return

	var theme = Theme.new()

	var panel_bg = Color(0.15, 0.15, 0.2, 0.9)
	var panel_border = Color(0.3, 0.4, 0.5, 0.8)
	var accent_color = Color(0.4, 0.6, 0.9, 1.0)
	var text_color = Color(0.85, 0.9, 0.95, 1.0)

	var panel_stylebox = StyleBoxFlat.new()
	panel_stylebox.bg_color = panel_bg
	panel_stylebox.border_color = panel_border
	panel_stylebox.border_width_left = 1
	panel_stylebox.border_width_top = 1
	panel_stylebox.border_width_right = 1
	panel_stylebox.border_width_bottom = 1
	panel_stylebox.corner_radius_top_left = 4
	panel_stylebox.corner_radius_top_right = 4
	panel_stylebox.corner_radius_bottom_right = 4
	panel_stylebox.corner_radius_bottom_left = 4
	panel_stylebox.content_margin_left = 12
	panel_stylebox.content_margin_top = 12
	panel_stylebox.content_margin_right = 12
	panel_stylebox.content_margin_bottom = 12

	theme.set_stylebox("panel", "PanelContainer", panel_stylebox)
	theme.set_color("font_color", "Label", text_color)
	theme.set_color("font_color", "Button", text_color)
	theme.set_color("font_focus_color", "Button", accent_color)
	theme.set_font_size("font_size", "Label", 14)
	theme.set_font_size("font_size", "Button", 14)

	var button_bg = StyleBoxFlat.new()
	button_bg.bg_color = accent_color
	button_bg.corner_radius_top_left = 4
	button_bg.corner_radius_top_right = 4
	button_bg.corner_radius_bottom_right = 4
	button_bg.corner_radius_bottom_left = 4
	button_bg.content_margin_left = 8
	button_bg.content_margin_top = 8
	button_bg.content_margin_right = 8
	button_bg.content_margin_bottom = 8
	theme.set_stylebox("normal", "Button", button_bg)

	var button_hover = StyleBoxFlat.new()
	button_hover.bg_color = Color(0.5, 0.7, 1.0, 1.0)
	button_hover.corner_radius_top_left = 4
	button_hover.corner_radius_top_right = 4
	button_hover.corner_radius_bottom_right = 4
	button_hover.corner_radius_bottom_left = 4
	button_hover.content_margin_left = 8
	button_hover.content_margin_top = 8
	button_hover.content_margin_right = 8
	button_hover.content_margin_bottom = 8
	theme.set_stylebox("hover", "Button", button_hover)

	var button_pressed = StyleBoxFlat.new()
	button_pressed.bg_color = Color(0.3, 0.5, 0.8, 1.0)
	button_pressed.corner_radius_top_left = 4
	button_pressed.corner_radius_top_right = 4
	button_pressed.corner_radius_bottom_right = 4
	button_pressed.corner_radius_bottom_left = 4
	button_pressed.content_margin_left = 8
	button_pressed.content_margin_top = 8
	button_pressed.content_margin_right = 8
	button_pressed.content_margin_bottom = 8
	theme.set_stylebox("pressed", "Button", button_pressed)

	generation_settings.theme = theme


func _connect_signals() -> void:
	# Connect seed controls
	if seed_spin_box != null:
		seed_spin_box.value_changed.connect(_on_seed_spin_box_value_changed)
	if random_seed_button != null:
		random_seed_button.pressed.connect(_on_random_seed_button_pressed)

	# Connect radius controls
	if radius_slider != null:
		radius_slider.value_changed.connect(_on_radius_slider_value_changed)

	# Connect shape control
	if shape_option_button != null:
		shape_option_button.item_selected.connect(_on_shape_option_button_item_selected)

	# Connect biome controls
	if grassland_check != null:
		grassland_check.toggled.connect(_on_grassland_check_toggled)
	if grassland_density != null:
		grassland_density.value_changed.connect(_on_grassland_density_value_changed)

	if forest_check != null:
		forest_check.toggled.connect(_on_forest_check_toggled)
	if forest_density != null:
		forest_density.value_changed.connect(_on_forest_density_value_changed)

	if desert_check != null:
		desert_check.toggled.connect(_on_desert_check_toggled)
	if desert_density != null:
		desert_density.value_changed.connect(_on_desert_density_value_changed)

	if swamp_check != null:
		swamp_check.toggled.connect(_on_swamp_check_toggled)
	if swamp_density != null:
		swamp_density.value_changed.connect(_on_swamp_density_value_changed)

	if tundra_check != null:
		tundra_check.toggled.connect(_on_tundra_check_toggled)
	if tundra_density != null:
		tundra_density.value_changed.connect(_on_tundra_density_value_changed)

	# Connect ocean controls
	if ocean_check != null:
		ocean_check.toggled.connect(_on_ocean_check_toggled)
	if ocean_density != null:
		ocean_density.value_changed.connect(_on_ocean_density_value_changed)

	# Connect mountain controls
	if mountain_check != null:
		mountain_check.toggled.connect(_on_mountain_check_toggled)
	if mountain_density != null:
		mountain_density.value_changed.connect(_on_mountain_density_value_changed)

	# Connect buffer controls
	if outer_buffer_spin_box != null:
		outer_buffer_spin_box.value_changed.connect(_on_outer_buffer_spin_box_value_changed)
	if inner_buffer_spin_box != null:
		inner_buffer_spin_box.value_changed.connect(_on_inner_buffer_spin_box_value_changed)

	# Connect generate button
	if generate_button != null:
		generate_button.pressed.connect(_on_generation_button_pressed)


func setup_shape_options() -> void:
	if shape_option_button == null:
		push_error("GenerationUI.setup_shape_options(): shape_option_button is null")
		return

	shape_option_button.clear()
	for shape in GenerationSettings.shape:
		shape_option_button.add_item(str(shape), GenerationSettings.shape.get(shape))


func load_settings_to_ui() -> void:
	if seed_spin_box == null or settings == null:
		push_error("GenerationUI.load_settings_to_ui(): seed_spin_box or settings is null")
		return

	seed_spin_box.value = settings.map_seed

	if radius_slider == null or radius_value == null:
		push_error("GenerationUI.load_settings_to_ui(): radius_slider or radius_value is null")
		return

	radius_slider.value = settings.radius
	radius_value.text = str(settings.radius)

	if shape_option_button == null:
		push_error("GenerationUI.load_settings_to_ui(): shape_option_button is null")
		return

	shape_option_button.selected = settings.map_shape

	# Setup biome UI
	for biome_key in biome_ui_map:
		_setup_biome_ui(biome_key)

	# Mountain settings
	if mountain_check == null or mountain_density == null or mountain_density_value == null:
		push_error("GenerationUI.load_settings_to_ui(): mountain controls are null")
		return

	mountain_check.button_pressed = settings.create_mountains
	mountain_density.value = settings.mountain_threshold
	mountain_density_value.text = "%.2f" % settings.mountain_threshold

	# Ocean settings
	if ocean_check == null or ocean_density == null or ocean_density_value == null:
		push_error("GenerationUI.load_settings_to_ui(): ocean controls are null")
		return

	ocean_check.button_pressed = settings.create_water
	ocean_density.value = settings.ocean_threshold
	ocean_density_value.text = "%.2f" % settings.ocean_threshold

	# Buffer settings
	if outer_buffer_spin_box == null or inner_buffer_spin_box == null:
		push_error("GenerationUI.load_settings_to_ui(): buffer spinboxes are null")
		return

	outer_buffer_spin_box.value = settings.outer_buffer
	inner_buffer_spin_box.value = settings.inner_buffer
	inner_buffer_spin_box.max_value = settings.radius
	outer_buffer_spin_box.max_value = settings.inner_buffer


func _setup_biome_ui(biome_key: String) -> void:
	if not biome_ui_map.has(biome_key):
		push_error("GenerationUI._setup_biome_ui(): biome_key '%s' not found in biome_ui_map" % biome_key)
		return

	var d = biome_ui_map[biome_key]

	# Validate biome UI dictionary
	if d.get("resource") == null or d.get("check") == null or d.get("density") == null or d.get("density_value") == null:
		push_error("GenerationUI._setup_biome_ui(): incomplete biome UI dictionary for '%s'" % biome_key)
		return

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
	if not biome_ui_map.has(biome_key):
		push_error("GenerationUI._on_biome_check_toggled(): biome_key '%s' not found" % biome_key)
		return

	var d = biome_ui_map[biome_key]
	if d.get("density") == null:
		push_error("GenerationUI._on_biome_check_toggled(): density not found for '%s'" % biome_key)
		return

	d["density"].editable = toggled_on
	if toggled_on:
		settings.tiles.append(d["resource"])
		_update_biome_weight(settings.tiles.find(d["resource"]), d["density"].value)
	else:
		settings.biome_weights.pop_at(settings.tiles.find(d["resource"]))
		settings.tiles.erase(d["resource"])


func _on_biome_density_value_changed(biome_key: String, value: float) -> void:
	if not biome_ui_map.has(biome_key):
		push_error("GenerationUI._on_biome_density_value_changed(): biome_key '%s' not found" % biome_key)
		return

	var d = biome_ui_map[biome_key]
	if d.get("density_value") == null:
		push_error("GenerationUI._on_biome_density_value_changed(): density_value not found for '%s'" % biome_key)
		return

	d["density_value"].text = "%.2f" % value
	_update_biome_weight(settings.tiles.find(d["resource"]), value)


func _update_biome_weight(index: int, value: float) -> void:
	while settings.biome_weights.size() <= index:
		settings.biome_weights.append(0.0)

	settings.biome_weights[index] = value


func _on_seed_spin_box_value_changed(value: float) -> void:
	if settings == null:
		push_error("GenerationUI._on_seed_spin_box_value_changed(): settings is null")
		return
	settings.map_seed = int(value)


func _on_random_seed_button_pressed() -> void:
	if seed_spin_box == null or settings == null:
		push_error("GenerationUI._on_random_seed_button_pressed(): seed_spin_box or settings is null")
		return
	var random_seed = randi_range(0, 999999)
	seed_spin_box.value = random_seed
	settings.map_seed = random_seed


func _on_radius_slider_value_changed(value: float) -> void:
	if settings == null or radius_value == null or inner_buffer_spin_box == null:
		push_error("GenerationUI._on_radius_slider_value_changed(): required nodes are null")
		return

	var new_radius = int(value)
	settings.radius = new_radius
	radius_value.text = str(new_radius)

	inner_buffer_spin_box.max_value = new_radius
	if inner_buffer_spin_box.value > new_radius:
		inner_buffer_spin_box.value = new_radius


func _on_shape_option_button_item_selected(index: int) -> void:
	if shape_option_button == null or settings == null:
		push_error("GenerationUI._on_shape_option_button_item_selected(): shape_option_button or settings is null")
		return

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
	if ocean_density == null:
		push_error("GenerationUI._on_ocean_check_toggled(): ocean_density is null")
		return
	if settings == null:
		push_error("GenerationUI._on_ocean_check_toggled(): settings is null")
		return

	settings.create_water = toggled_on
	ocean_density.editable = toggled_on


func _on_ocean_density_value_changed(value: float) -> void:
	if ocean_density_value == null or settings == null:
		push_error("GenerationUI._on_ocean_density_value_changed(): ocean_density_value or settings is null")
		return

	ocean_density_value.text = "%.2f" % value
	settings.ocean_threshold = 0.7 - value * 0.2


func _on_mountain_check_toggled(toggled_on: bool) -> void:
	if mountain_density == null or settings == null:
		push_error("GenerationUI._on_mountain_check_toggled(): mountain_density or settings is null")
		return

	settings.create_mountains = toggled_on
	mountain_density.editable = toggled_on


func _on_mountain_density_value_changed(value: float) -> void:
	if mountain_density_value == null or settings == null:
		push_error("GenerationUI._on_mountain_density_value_changed(): mountain_density_value or settings is null")
		return

	mountain_density_value.text = "%.2f" % value
	settings.mountain_threshold = 0.7 - value * 0.2


func _on_outer_buffer_spin_box_value_changed(value: float) -> void:
	if settings == null:
		push_error("GenerationUI._on_outer_buffer_spin_box_value_changed(): settings is null")
		return
	settings.outer_buffer = int(value)


func _on_inner_buffer_spin_box_value_changed(value: float) -> void:
	if settings == null or outer_buffer_spin_box == null:
		push_error("GenerationUI._on_inner_buffer_spin_box_value_changed(): required nodes are null")
		return

	var new_inner = int(value)
	settings.inner_buffer = new_inner

	outer_buffer_spin_box.max_value = new_inner - 1
	if outer_buffer_spin_box.value >= new_inner:
		outer_buffer_spin_box.value = new_inner - 1


func _on_generation_button_pressed() -> void:
	if settings == null:
		push_error("GenerationUI._on_generation_button_pressed(): settings is null")
		return

	settings.empires.erase(settings.player_empire)
	# Solo 1 imperio IA: elegir uno aleatorio y descartar el resto
	var ai_empire: Empire = settings.empires.pick_random()
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
	var stats_template: Stats = INITIAL_STATS.duplicate()
	stats_template.empire = settings.player_empire
	Events.generate_world.emit(settings, stats_template)
