extends Modifier
class_name CardReturnModifier

## Icono precargado
const ICON_CARD_RETURN := preload("res://assets/modifiers/card_return_positive.svg")

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

	# Asignar icono y descripcion automaticamente
	if icon == null:
		icon = ICON_CARD_RETURN
	if description.is_empty():
		description = _build_description()


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


func _build_description() -> String:
	return "%d%% chance to return %s to hand" % [int(chance * 100), card_id]
