extends Card
class_name RecruitCard

## Carta de reclutamiento de tropas. Target SELF, needs_confirmation=true.
## Al jugarla abre un menú para seleccionar qué tipo de tropa reclutar.
## Si se cancela, la carta vuelve a la mano.
##
## La carta recluta `base_troops_per_play + modifier_bonus` tropas del tipo
## elegido en cada jugada. El bonus viene de modifiers tipo
## `StatModifier.StatType.TROOPS_PER_RECRUIT` (Cuartel = +1, Academia
## Militar = +1 adicional). Si en mitad del reclutamiento se queda sin oro,
## se reclutan las que se puedan y se descarta el resto silenciosamente.

## Tropas disponibles para reclutar (se configuran desde el recurso .tres)
@export var available_troops: Array[Troop] = []

## Tropas reclutadas por play de esta carta antes de aplicar bonuses de
## modifiers. Default 1; cartas tematicas especiales (eventos "leva en
## masa", etc.) pueden tener una base mayor en su .tres.
@export var base_troops_per_play: int = 1

var menu: RecruitPanel
var chosen: Troop


func _build_tooltip() -> String:
	return "[center][b][color=#8B1A1A]Recluta[/color][/b] una [color=#4A6A8A]tropa[/color] para tu ejército[/center]"


func confirm(_targets: Array[Node], stats: Stats) -> void:
	Events.recruit_card_confirm_started.emit(self, stats)


## Calcula cuantas tropas se reclutarian con un play sobre este Stats.
## Expuesto como helper publico para que el AIOptionsBuilder pueda filtrar
## las opciones por oro suficiente para TODAS las tropas, no solo una.
func get_effective_troops_per_play(stats: Stats) -> int:
	var bonus := 0
	if stats != null and stats.modifier_manager != null:
		bonus = stats.modifier_manager.get_troops_per_recruit_bonus()
	return maxi(1, base_troops_per_play + bonus)


func apply_effects(_targets: Array[Node], stats: Stats) -> void:
	if chosen == null:
		return
	var total := get_effective_troops_per_play(stats)
	for i in total:
		# `recruit_troop` devuelve false si el oro no alcanza. Salimos del
		# bucle para no intentar reclutar tropas gratis ni desperdiciar
		# ciclos. Las tropas reclutadas hasta aqui se quedan.
		if not stats.recruit_troop(chosen):
			return
