extends Control
class_name TroopPoolView

## Vista a pantalla completa con todas las tropas reclutadas del jugador,
## agrupadas por tipo. Sigue el patrón de CardPileView (background oscuro,
## título, grid, botón de Back y cierre con ESC).

const TROOP_MENU_UI = preload("res://scenes/UI/military/troop_menu_ui.tscn")

@export var stats:Stats

@onready var title: Label = %Title
@onready var troops_container: GridContainer = %TroopsContainer
@onready var back_button: Button = %BackButton
@onready var empty_label: Label = %EmptyLabel


func _ready() -> void:
	back_button.pressed.connect(hide)

	for slot:Node in troops_container.get_children():
		slot.queue_free()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	# Consumimos el input para que ESC no se propague al menu de pausa, que
	# abriria "encima" de esta vista.
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		hide()


func show_current_view(new_title:String) -> void:
	for slot:Node in troops_container.get_children():
		slot.queue_free()

	title.text = tr(new_title)
	_update_view.call_deferred()


func _update_view() -> void:
	if not stats:
		return

	# Agrupar por tipo de tropa (mismo Resource compartido)
	var counts:Dictionary = {}
	var order:Array[Troop] = []
	for troop:Troop in stats.troop_pool:
		if not counts.has(troop):
			counts[troop] = 0
			order.append(troop)
		counts[troop] += 1

	# Mostrar/ocultar el ScrollContainer entero según si hay tropas.
	var scroll:Node = troops_container.get_parent()
	if scroll is Control:
		(scroll as Control).visible = not order.is_empty()
	empty_label.visible = order.is_empty()

	for troop:Troop in order:
		var slot := TROOP_MENU_UI.instantiate() as TroopMenuUi
		troops_container.add_child(slot)
		slot.troop = troop
		slot.count = counts[troop]

	show()
