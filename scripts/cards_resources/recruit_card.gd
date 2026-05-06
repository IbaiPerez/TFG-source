extends Card
class_name RecruitCard

## Carta de reclutamiento de tropas. Target SELF, needs_confirmation=true.
## Al jugarla abre un menú para seleccionar qué tipo de tropa reclutar.
## Si se cancela, la carta vuelve a la mano.

## Tropas disponibles para reclutar (se configuran desde el recurso .tres)
@export var available_troops: Array[Troop] = []

var menu: RecruitPanel
var chosen: Troop


func _build_tooltip() -> String:
	return "[center][b][color=#8B1A1A]Recluta[/color][/b] una [color=#4A6A8A]tropa[/color] para tu ejército[/center]"


func confirm(_targets: Array[Node], stats: Stats) -> void:
	Events.recruit_card_confirm_started.emit(self, stats)


func apply_effects(_targets: Array[Node], stats: Stats) -> void:
	if chosen == null:
		return
	stats.recruit_troop(chosen)
