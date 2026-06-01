extends Control
## UI para la generación de mapas con opciones de personalización
## Gestiona la interfaz de dos columnas: configuración izquierda, vista previa derecha

# ============================================================================
# REFERENCIAS A NODOS
# ============================================================================

var basic_settings_panel: PanelContainer
var biomes_panel: PanelContainer
var special_panel: PanelContainer
var buffer_panel: PanelContainer

var seed_spin_box: SpinBox
var seed_random_button: Button
var width_spin_box: SpinBox
var height_spin_box: SpinBox

var biome_forest_check: CheckBox
var biome_desert_check: CheckBox
var biome_mountain_check: CheckBox
var biome_water_check: CheckBox

var forest_density_slider: HSlider
var desert_density_slider: HSlider
var mountain_density_slider: HSlider

var spawn_points_slider: HSlider
var spawn_points_label: Label

var border_size_slider: HSlider
var border_size_label: Label

var generate_button: Button
var cancel_button: Button

var preview_texture_rect: TextureRect
var preview_label: Label

# ============================================================================
# VARIABLES DE ESTADO
# ============================================================================

var selected_empire: Resource = null
var settings: GenerationSettings = null

var current_seed: int = 0
var map_width: int = 100
var map_height: int = 100

var selected_biomes: Array[String] = []
var biome_densities: Dictionary = {
	"forest": 0.5,
	"desert": 0.3,
	"mountain": 0.4
}

var num_spawn_points: int = 4
var border_buffer_size: int = 5

var is_generating: bool = false
var biome_ui_map: Dictionary = {}

# ============================================================================
# CICLO DE VIDA
# ============================================================================

func _ready() -> void:
	_initialize_references()
	_setup_theme()
	_setup_signal_connections()
	_debug_print_references()
	_initialize_default_values()


func _initialize_references() -> void:
	## Inicializa todas las referencias a nodos usando get_node_or_null()

	# Paneles principales
	basic_settings_panel = get_node_or_null("VBoxContainer/HBoxContainer/LeftColumn/BasicSettingsPanel")
	biomes_panel = get_node_or_null("VBoxContainer/HBoxContainer/LeftColumn/BiomesPanel")
	special_panel = get_node_or_null("VBoxContainer/HBoxContainer/LeftColumn/SpecialPanel")
	buffer_panel = get_node_or_null("VBoxContainer/HBoxContainer/LeftColumn/BufferPanel")

	# Configuración básica
	seed_spin_box = get_node_or_null("VBoxContainer/HBoxContainer/LeftColumn/BasicSettingsPanel/VBoxContainer/SeedHBox/SeedSpinBox")
	seed_random_button = get_node_or_null("VBoxContainer/HBoxContainer/LeftColumn/BasicSettingsPanel/VBoxContainer/SeedHBox/RandomButton")
	width_spin_box = get_node_or_null("VBoxContainer/HBoxContainer/LeftColumn/BasicSettingsPanel/VBoxContainer/DimensionsHBox/WidthSpinBox")
	height_spin_box = get_node_or_null("VBoxContainer/HBoxContainer/LeftColumn/BasicSettingsPanel/VBoxContainer/DimensionsHBox/HeightSpinBox")

	# Biomas
	biome_forest_check = get_node_or_null("VBoxContainer/HBoxContainer/LeftColumn/BiomesPanel/VBoxContainer/ForestCheckBox")
	biome_desert_check = get_node_or_null("VBoxContainer/HBoxContainer/LeftColumn/BiomesPanel/VBoxContainer/DesertCheckBox")
	biome_mountain_check = get_node_or_null("VBoxContainer/HBoxContainer/LeftColumn/BiomesPanel/VBoxContainer/MountainCheckBox")
	biome_water_check = get_node_or_null("VBoxContainer/HBoxContainer/LeftColumn/BiomesPanel/VBoxContainer/WaterCheckBox")

	# Densidades de biomas
	forest_density_slider = get_node_or_null("VBoxContainer/HBoxContainer/LeftColumn/BiomesPanel/VBoxContainer/ForestDensityHBox/ForestDensitySlider")
	desert_density_slider = get_node_or_null("VBoxContainer/HBoxContainer/LeftColumn/BiomesPanel/VBoxContainer/DesertDensityHBox/DesertDensitySlider")
	mountain_density_slider = get_node_or_null("VBoxContainer/HBoxContainer/LeftColumn/BiomesPanel/VBoxContainer/MountainDensityHBox/MountainDensitySlider")

	# Puntos de aparición
	spawn_points_slider = get_node_or_null("VBoxContainer/HBoxContainer/LeftColumn/SpecialPanel/VBoxContainer/SpawnPointsHBox/SpawnPointsSlider")
	spawn_points_label = get_node_or_null("VBoxContainer/HBoxContainer/LeftColumn/SpecialPanel/VBoxContainer/SpawnPointsHBox/SpawnPointsLabel")

	# Buffer
	border_size_slider = get_node_or_null("VBoxContainer/HBoxContainer/LeftColumn/BufferPanel/VBoxContainer/BorderSizeHBox/BorderSizeSlider")
	border_size_label = get_node_or_null("VBoxContainer/HBoxContainer/LeftColumn/BufferPanel/VBoxContainer/BorderSizeHBox/BorderSizeLabel")

	# Botones de acción
	generate_button = get_node_or_null("VBoxContainer/HBoxContainer/LeftColumn/ActionHBox/GenerateButton")
	cancel_button = get_node_or_null("VBoxContainer/HBoxContainer/LeftColumn/ActionHBox/CancelButton")

	# Vista previa (derecha)
	preview_texture_rect = get_node_or_null("VBoxContainer/HBoxContainer/RightColumn/PreviewTextureRect")
	preview_label = get_node_or_null("VBoxContainer/HBoxContainer/RightColumn/PreviewLabel")


func _setup_theme() -> void:
	## Configura tema y estilos (se puede expandir)
	pass


func _setup_signal_connections() -> void:
	## Conecta todas las señales de UI a sus callbacks

	if seed_random_button:
		seed_random_button.pressed.connect(_on_seed_random_button_pressed)

	if seed_spin_box:
		seed_spin_box.value_changed.connect(_on_seed_spin_box_value_changed)

	if width_spin_box:
		width_spin_box.value_changed.connect(_on_width_spin_box_value_changed)

	if height_spin_box:
		height_spin_box.value_changed.connect(_on_height_spin_box_value_changed)

	# Biomas
	if biome_forest_check:
		biome_forest_check.toggled.connect(_on_biome_forest_toggled)

	if biome_desert_check:
		biome_desert_check.toggled.connect(_on_biome_desert_toggled)

	if biome_mountain_check:
		biome_mountain_check.toggled.connect(_on_biome_mountain_toggled)

	if biome_water_check:
		biome_water_check.toggled.connect(_on_biome_water_toggled)

	# Densidades
	if forest_density_slider:
		forest_density_slider.value_changed.connect(_on_forest_density_changed)

	if desert_density_slider:
		desert_density_slider.value_changed.connect(_on_desert_density_changed)

	if mountain_density_slider:
		mountain_density_slider.value_changed.connect(_on_mountain_density_changed)

	# Puntos de aparición
	if spawn_points_slider:
		spawn_points_slider.value_changed.connect(_on_spawn_points_changed)

	# Buffer
	if border_size_slider:
		border_size_slider.value_changed.connect(_on_border_size_changed)

	# Botones
	if generate_button:
		generate_button.pressed.connect(_on_generate_button_pressed)

	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_button_pressed)


func _debug_print_references() -> void:
	## Imprime el estado de todas las referencias para debugging
	var all_refs = {
		"basic_settings_panel": basic_settings_panel,
		"biomes_panel": biomes_panel,
		"special_panel": special_panel,
		"buffer_panel": buffer_panel,
		"seed_spin_box": seed_spin_box,
		"seed_random_button": seed_random_button,
		"width_spin_box": width_spin_box,
		"height_spin_box": height_spin_box,
		"biome_forest_check": biome_forest_check,
		"biome_desert_check": biome_desert_check,
		"biome_mountain_check": biome_mountain_check,
		"biome_water_check": biome_water_check,
		"forest_density_slider": forest_density_slider,
		"desert_density_slider": desert_density_slider,
		"mountain_density_slider": mountain_density_slider,
		"spawn_points_slider": spawn_points_slider,
		"spawn_points_label": spawn_points_label,
		"border_size_slider": border_size_slider,
		"border_size_label": border_size_label,
		"generate_button": generate_button,
		"cancel_button": cancel_button,
		"preview_texture_rect": preview_texture_rect,
		"preview_label": preview_label
	}

	var missing_refs = []
	for ref_name in all_refs:
		if all_refs[ref_name] == null:
			missing_refs.append(ref_name)

	if missing_refs.is_empty():
		print("[GenerationUI] Todas las referencias inicializadas correctamente")
	else:
		print("[GenerationUI] ADVERTENCIA - Referencias faltantes: ", missing_refs)


func _initialize_default_values() -> void:
	## Inicializa los valores por defecto de la UI

	current_seed = randi()
	if seed_spin_box:
		seed_spin_box.value = current_seed

	map_width = 100
	if width_spin_box:
		width_spin_box.value = map_width

	map_height = 100
	if height_spin_box:
		height_spin_box.value = map_height

	# Biomas por defecto: todos excepto agua
	selected_biomes = ["forest", "desert", "mountain"]
	if biome_forest_check:
		biome_forest_check.button_pressed = true
	if biome_desert_check:
		biome_desert_check.button_pressed = true
	if biome_mountain_check:
		biome_mountain_check.button_pressed = true
	if biome_water_check:
		biome_water_check.button_pressed = false

	# Densidades
	biome_densities = {
		"forest": 0.5,
		"desert": 0.3,
		"mountain": 0.4
	}
	if forest_density_slider:
		forest_density_slider.value = biome_densities["forest"]
	if desert_density_slider:
		desert_density_slider.value = biome_densities["desert"]
	if mountain_density_slider:
		mountain_density_slider.value = biome_densities["mountain"]

	# Puntos de aparición
	num_spawn_points = 4
	if spawn_points_slider:
		spawn_points_slider.value = num_spawn_points
	_update_spawn_points_label()

	# Buffer
	border_buffer_size = 5
	if border_size_slider:
		border_size_slider.value = border_buffer_size
	_update_border_size_label()

	# Vista previa
	_update_preview_label()


# ============================================================================
# CALLBACKS DE SEED
# ============================================================================

func _on_seed_random_button_pressed() -> void:
	## Genera una nueva semilla aleatoria
	current_seed = randi()
	if seed_spin_box:
		seed_spin_box.value = current_seed


func _on_seed_spin_box_value_changed(value: float) -> void:
	## Actualiza la semilla cuando cambia el SpinBox
	current_seed = int(value)


# ============================================================================
# CALLBACKS DE DIMENSIONES
# ============================================================================

func _on_width_spin_box_value_changed(value: float) -> void:
	## Actualiza el ancho del mapa
	map_width = int(value)
	_update_preview_label()


func _on_height_spin_box_value_changed(value: float) -> void:
	## Actualiza el alto del mapa
	map_height = int(value)
	_update_preview_label()


# ============================================================================
# CALLBACKS DE BIOMAS
# ============================================================================

func _on_biome_forest_toggled(pressed: bool) -> void:
	## Toggle para el bioma de bosque
	_update_selected_biomes()


func _on_biome_desert_toggled(pressed: bool) -> void:
	## Toggle para el bioma de desierto
	_update_selected_biomes()


func _on_biome_mountain_toggled(pressed: bool) -> void:
	## Toggle para el bioma de montaña
	_update_selected_biomes()


func _on_biome_water_toggled(pressed: bool) -> void:
	## Toggle para el bioma de agua
	_update_selected_biomes()


func _update_selected_biomes() -> void:
	## Recalcula la lista de biomas seleccionados basada en los checkboxes
	selected_biomes.clear()

	if biome_forest_check and biome_forest_check.button_pressed:
		selected_biomes.append("forest")

	if biome_desert_check and biome_desert_check.button_pressed:
		selected_biomes.append("desert")

	if biome_mountain_check and biome_mountain_check.button_pressed:
		selected_biomes.append("mountain")

	if biome_water_check and biome_water_check.button_pressed:
		selected_biomes.append("water")

	_update_preview_label()


# ============================================================================
# CALLBACKS DE DENSIDADES
# ============================================================================

func _on_forest_density_changed(value: float) -> void:
	## Actualiza la densidad del bosque
	biome_densities["forest"] = value
	_update_preview_label()


func _on_desert_density_changed(value: float) -> void:
	## Actualiza la densidad del desierto
	biome_densities["desert"] = value
	_update_preview_label()


func _on_mountain_density_changed(value: float) -> void:
	## Actualiza la densidad de la montaña
	biome_densities["mountain"] = value
	_update_preview_label()


# ============================================================================
# CALLBACKS DE PUNTOS DE APARICIÓN
# ============================================================================

func _on_spawn_points_changed(value: float) -> void:
	## Actualiza el número de puntos de aparición
	num_spawn_points = int(value)
	_update_spawn_points_label()
	_update_preview_label()


func _update_spawn_points_label() -> void:
	## Actualiza el label que muestra el número de puntos de aparición
	if spawn_points_label:
		spawn_points_label.text = "Spawn Points: %d" % num_spawn_points


# ============================================================================
# CALLBACKS DE BUFFER
# ============================================================================

func _on_border_size_changed(value: float) -> void:
	## Actualiza el tamaño del buffer de borde
	border_buffer_size = int(value)
	_update_border_size_label()
	_update_preview_label()


func _update_border_size_label() -> void:
	## Actualiza el label que muestra el tamaño del borde
	if border_size_label:
		border_size_label.text = "Border Size: %d" % border_buffer_size


# ============================================================================
# CALLBACKS DE ACCIONES
# ============================================================================

func _on_generate_button_pressed() -> void:
	## Inicia la generación del mapa
	if is_generating:
		return

	is_generating = true

	if generate_button:
		generate_button.disabled = true

	# Aquí iría la lógica real de generación del mapa
	# Por ahora, simulamos un retraso
	await get_tree().create_timer(1.0).timeout

	_on_generation_complete()


func _on_cancel_button_pressed() -> void:
	## Cancela y cierra la UI de generación
	queue_free()


func _on_generation_complete() -> void:
	## Se llama cuando la generación del mapa se completa
	is_generating = false

	if generate_button:
		generate_button.disabled = false

	print("[GenerationUI] Generación completada")
	print("  Seed: %d" % current_seed)
	print("  Dimensiones: %dx%d" % [map_width, map_height])
	print("  Biomas: %s" % [selected_biomes])
	print("  Densidades: %s" % [biome_densities])
	print("  Puntos de aparición: %d" % num_spawn_points)
	print("  Buffer de borde: %d" % border_buffer_size)


# ============================================================================
# FUNCIONES AUXILIARES
# ============================================================================

func _update_preview_label() -> void:
	## Actualiza el label de vista previa con información actual
	if preview_label:
		var biomes_text = ", ".join(selected_biomes) if not selected_biomes.is_empty() else "None"
		preview_label.text = """
Map Size: %dx%d
Seed: %d
Biomes: %s
Spawn Points: %d
Border Buffer: %d
""" % [map_width, map_height, current_seed, biomes_text, num_spawn_points, border_buffer_size]


func get_generation_config() -> Dictionary:
	## Retorna un diccionario con toda la configuración actual
	return {
		"seed": current_seed,
		"width": map_width,
		"height": map_height,
		"biomes": selected_biomes.duplicate(),
		"biome_densities": biome_densities.duplicate(),
		"spawn_points": num_spawn_points,
		"border_buffer": border_buffer_size
	}


func set_generation_config(config: Dictionary) -> void:
	## Establece la configuración desde un diccionario
	if "seed" in config:
		current_seed = config["seed"]
		if seed_spin_box:
			seed_spin_box.value = current_seed

	if "width" in config:
		map_width = config["width"]
		if width_spin_box:
			width_spin_box.value = map_width

	if "height" in config:
		map_height = config["height"]
		if height_spin_box:
			height_spin_box.value = map_height

	if "biomes" in config:
		selected_biomes = config["biomes"].duplicate()
		_sync_biome_checkboxes()

	if "biome_densities" in config:
		biome_densities = config["biome_densities"].duplicate()
		_sync_density_sliders()

	if "spawn_points" in config:
		num_spawn_points = config["spawn_points"]
		if spawn_points_slider:
			spawn_points_slider.value = num_spawn_points
		_update_spawn_points_label()

	if "border_buffer" in config:
		border_buffer_size = config["border_buffer"]
		if border_size_slider:
			border_size_slider.value = border_buffer_size
		_update_border_size_label()

	_update_preview_label()


func _sync_biome_checkboxes() -> void:
	## Sincroniza los checkboxes de biomas con selected_biomes
	if biome_forest_check:
		biome_forest_check.button_pressed = "forest" in selected_biomes

	if biome_desert_check:
		biome_desert_check.button_pressed = "desert" in selected_biomes

	if biome_mountain_check:
		biome_mountain_check.button_pressed = "mountain" in selected_biomes

	if biome_water_check:
		biome_water_check.button_pressed = "water" in selected_biomes


func _sync_density_sliders() -> void:
	## Sincroniza los sliders de densidad con biome_densities
	if forest_density_slider and "forest" in biome_densities:
		forest_density_slider.value = biome_densities["forest"]

	if desert_density_slider and "desert" in biome_densities:
		desert_density_slider.value = biome_densities["desert"]

	if mountain_density_slider and "mountain" in biome_densities:
		mountain_density_slider.value = biome_densities["mountain"]


func reset_to_defaults() -> void:
	## Resetea toda la configuración a los valores por defecto
	_initialize_default_values()
