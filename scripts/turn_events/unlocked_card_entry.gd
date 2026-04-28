extends RefCounted
class_name UnlockedCardEntry

## Entrada del pool de cartas desbloqueadas.
## Representa una carta disponible con peso dinámico según el turno.

var card:Card
var base_weight:float
var weight_per_turn:float
var min_weight:float


func _init(p_card:Card, p_base_weight:float = 5.0,
		p_weight_per_turn:float = 0.0, p_min_weight:float = 1.0):
	card = p_card
	base_weight = p_base_weight
	weight_per_turn = p_weight_per_turn
	min_weight = p_min_weight


func get_weight(turn:int) -> float:
	return maxf(min_weight, base_weight + turn * weight_per_turn)
