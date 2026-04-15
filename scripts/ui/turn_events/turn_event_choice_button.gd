extends Control
class_name TurnEventChoiceButton

@onready var button: Button = $Button
@onready var tooltip_panel: PanelContainer = $Tooltip
@onready var tooltip_text_label: Label = %TooltipText

var choice:TurnEventChoice
var affordable:bool = true

signal choice_selected(choice:TurnEventChoice)


func setup(p_choice:TurnEventChoice, p_affordable:bool) -> void:
	if not is_node_ready():
		await ready

	choice = p_choice
	affordable = p_affordable
	button.text = choice.label
	button.disabled = not affordable
	tooltip_text_label.text = choice.description
	tooltip_panel.visible = false


func _on_button_mouse_entered() -> void:
	if not choice:
		return
	tooltip_panel.visible = true
	# Esperar un frame para que el tooltip recompute su tamaño tras mostrarse
	await get_tree().process_frame
	_update_tooltip_position()


func _on_button_mouse_exited() -> void:
	tooltip_panel.visible = false


func _on_button_pressed() -> void:
	choice_selected.emit(choice)


func _update_tooltip_position() -> void:
	var vp_size := get_viewport_rect().size
	var tooltip_size := tooltip_panel.size
	var global := global_position
	var self_size := size

	# Preferencia: a la derecha del boton
	var x := global.x + self_size.x + 8
	if x + tooltip_size.x > vp_size.x:
		# Si no cabe a la derecha, ponerlo a la izquierda
		x = global.x - tooltip_size.x - 8

	# Si tampoco cabe a la izquierda, pegarlo al borde izquierdo de la pantalla
	if x < 0:
		x = 4

	var y := global.y
	if y + tooltip_size.y > vp_size.y:
		y = vp_size.y - tooltip_size.y - 4
	if y < 0:
		y = 4

	tooltip_panel.global_position = Vector2(x, y)
