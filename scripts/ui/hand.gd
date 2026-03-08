extends HBoxContainer
class_name Hand

func _ready() -> void:
	for child in get_children():
		var card_ui := child as CardUI
		card_ui.parent = self
		card_ui.reparent_requested.connect(_on_card_ui_reparent_requested)

func _on_card_ui_reparent_requested(card_ui:CardUI) -> void:
	card_ui.reparent(self)
