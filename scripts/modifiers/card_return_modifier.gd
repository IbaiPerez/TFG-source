extends Modifier
class_name CardReturnModifier

## Carta que tiene probabilidad de volver a la mano
var card_id:String
## Probabilidad de 0.0 a 1.0
var chance:float
## Solo se activa una vez por turno
var _used_this_turn:bool = false


func _init(p_id:String, p_name:String, p_card_id:String, p_chance:float,
		p_duration:int, p_icon:Texture2D = null):
	super(p_id, p_name, p_duration, p_icon)
	card_id = p_card_id
	chance = p_chance


func on_turn_start() -> void:
	_used_this_turn = false


func should_return(card:Card) -> bool:
	if card.id != card_id:
		return false
	if _used_this_turn:
		return false
	if randf() > chance:
		return false
	_used_this_turn = true
	return true


func duplicate_modifier() -> Modifier:
	return CardReturnModifier.new(id, name, card_id, chance, duration, icon)
