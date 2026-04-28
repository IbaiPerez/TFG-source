extends TurnEventEffect
class_name AddToCardPoolEffect

## Añade una carta al pool de cartas desbloqueadas cuando se ejecuta.
## Controla duplicados internamente via Stats.add_to_card_pool().

var entry:UnlockedCardEntry


func _init(p_card:Card, p_base_weight:float = 5.0,
		p_weight_per_turn:float = 0.0, p_min_weight:float = 1.0):
	entry = UnlockedCardEntry.new(p_card, p_base_weight, p_weight_per_turn, p_min_weight)


func execute(context:EventContext, _chosen_card:Card = null) -> void:
	context.stats.add_to_card_pool(entry)
