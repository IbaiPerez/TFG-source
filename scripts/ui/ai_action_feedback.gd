extends Node3D
class_name AIActionFeedback

## Consumidor de Events.ai_card_played. Spawnea un AIFloatingLabel 3D
## sobre la tile ancla cuando la IA juega una carta con anchor_tile != null.
## Para opciones SELF (sin tile concreta) no spawnea label — el feedback
## se delega al AIActionLog lateral.
##
## Debe añadirse al árbol del Map para que las labels que crea tengan un
## espacio 3D donde renderizarse.

## Altura sobre la tile donde aparece la label (centro+offset Y).
@export var anchor_y_offset: float = 2.0


func _ready() -> void:
	Events.ai_card_played.connect(_on_ai_card_played)


func _on_ai_card_played(card: Card, anchor_tile: Tile, empire: Empire,
		_payload: Dictionary) -> void:
	if anchor_tile == null:
		return  # SELF cards: sin tile, no floating label.
	if card == null or empire == null:
		return

	var label := AIFloatingLabel.new()
	add_child(label)
	var pos := anchor_tile.global_position + Vector3(0, anchor_y_offset, 0)
	var text := _describe_card(card)
	label.setup(text, empire.color, pos)


## Texto humano-legible de la carta para mostrar sobre la tile. Si el
## tooltip tiene markup BBCode, lo strippeamos en una primera versión —
## el label 3D no renderiza BBCode.
func _describe_card(card: Card) -> String:
	# Usar el id como fallback amigable. Las cartas suelen tener id
	# corto y descriptivo ("colonize", "build", "recruit", etc.).
	if card.id and card.id != "":
		return card.id.capitalize()
	return "?"
