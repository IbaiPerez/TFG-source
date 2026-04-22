extends Modifier
class_name GoldOnCardModifier

## Iconos precargados por signo
const ICONS := {
	"gold_on_card_positive": preload("res://assets/modifiers/gold_on_card_positive.svg"),
	"gold_on_card_negative": preload("res://assets/modifiers/gold_on_card_negative.svg"),
}

var card_id:String
var gold_amount:int


func _init(p_id:String, p_name:String, p_card_id:String, p_gold:int,
		p_duration:int, p_icon:Texture2D = null):
	super(p_id, p_name, p_duration, p_icon)
	card_id = p_card_id
	gold_amount = p_gold

	# Asignar icono y descripcion automaticamente
	if icon == null:
		icon = _resolve_icon()
	if description.is_empty():
		description = _build_description()


func activate(p_stats:Stats) -> void:
	super.activate(p_stats)
	Events.card_played.connect(_on_card_played)


func deactivate() -> void:
	if Events.card_played.is_connected(_on_card_played):
		Events.card_played.disconnect(_on_card_played)
	super.deactivate()


func _on_card_played(card:Card) -> void:
	if card.id == card_id:
		stats.total_gold += gold_amount


func duplicate_modifier() -> Modifier:
	return GoldOnCardModifier.new(id, name, card_id, gold_amount, duration, icon)


func _resolve_icon() -> Texture2D:
	var key := _build_icon_key()
	return ICONS.get(key)


func _build_icon_key() -> String:
	var signo := "positive" if gold_amount >= 0 else "negative"
	return "gold_on_card_" + signo


func _build_description() -> String:
	var sign := "+" if gold_amount >= 0 else ""
	return "%s%d gold on %s played" % [sign, gold_amount, card_id]
