extends PanelContainer
class_name ModifiersPanel

## Panel que muestra los modificadores activos del jugador.
## Solo muestra un numero limitado de modificadores a la vez
## y permite navegar con botones de flecha a izquierda y derecha.

const MODIFIER_ICON = preload("uid://mdfricon4tscn0")

@export var visible_count:int = 4

@onready var left_button: Button = %LeftButton
@onready var right_button: Button = %RightButton
@onready var slots: HBoxContainer = %Slots
@onready var page_label: Label = %PageLabel

var modifier_manager:ModifierManager:set = _set_modifier_manager
var page_offset:int = 0


func _ready() -> void:
	left_button.pressed.connect(_on_left_pressed)
	right_button.pressed.connect(_on_right_pressed)
	refresh()


func _set_modifier_manager(value:ModifierManager) -> void:
	if modifier_manager:
		if modifier_manager.modifiers_changed.is_connected(_on_modifiers_changed):
			modifier_manager.modifiers_changed.disconnect(_on_modifiers_changed)

	modifier_manager = value

	if modifier_manager:
		modifier_manager.modifiers_changed.connect(_on_modifiers_changed)

	if is_node_ready():
		page_offset = 0
		refresh()


func _on_modifiers_changed() -> void:
	## Si estabamos en una pagina que ya no existe, retrocedemos
	var total := _total_modifiers()
	if page_offset > 0 and page_offset >= total:
		page_offset = maxi(0, total - visible_count)
	refresh()


func _total_modifiers() -> int:
	if not modifier_manager:
		return 0
	return modifier_manager.active_modifiers.size()


func refresh() -> void:
	if not is_node_ready():
		return

	for child in slots.get_children():
		child.queue_free()

	var mods:Array[Modifier] = []
	if modifier_manager:
		mods = modifier_manager.active_modifiers

	var total := mods.size()
	var end := mini(page_offset + visible_count, total)

	for i in range(page_offset, end):
		var icon_instance:ModifierIcon = MODIFIER_ICON.instantiate()
		slots.add_child(icon_instance)
		icon_instance.modifier = mods[i]

	## Rellenar huecos vacios para que el layout no se contraiga
	for i in range(end - page_offset, visible_count):
		var placeholder := Control.new()
		placeholder.custom_minimum_size = Vector2(52, 52)
		placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slots.add_child(placeholder)

	_update_nav_state(total)


func _update_nav_state(total:int) -> void:
	left_button.disabled = page_offset <= 0
	right_button.disabled = page_offset + visible_count >= total

	if total <= visible_count:
		page_label.text = "%d" % total
	else:
		var current_page:int = (page_offset / visible_count) + 1
		var total_pages:int = int(ceil(float(total) / float(visible_count)))
		page_label.text = "%d / %d" % [current_page, total_pages]


func _on_left_pressed() -> void:
	page_offset = maxi(0, page_offset - visible_count)
	refresh()


func _on_right_pressed() -> void:
	var total := _total_modifiers()
	if page_offset + visible_count < total:
		page_offset += visible_count
	refresh()
