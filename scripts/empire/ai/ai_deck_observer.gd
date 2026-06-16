extends RefCounted
class_name AIDeckObserver

## Registra cartas jugadas por el rival para descubrir adquisiciones de tienda/eventos.
##
## El starting_deck del rival es información pública (mismo recurso compartido al inicio).
## Las cartas compradas en tienda o ganadas por eventos son privadas hasta que se juegan.
## Cuando el rival juega una carta cuyo id NO está en su starting_deck conocido, esta
## clase la registra en `acquired_cards` — ampliando el modelo de deck conocido.
##
## Ciclo de vida: uno por partida, creado por AIController en cuanto tiene un rival
## disponible (primer turno con turn_manager). Persiste entre turnos.
## Llamar cleanup() al destruir el AIController para desconectar la señal.

var _rival_stats: Stats = null
var _starting_deck_ids: Dictionary = {}  ## card_id → true, ids del starting_deck público
var acquired_cards: Array[Card] = []     ## cartas observadas que NO estaban en starting_deck


## Inicializa el observer para un rival concreto.
## rival_stats: Stats del rival (para filtrar el signal).
## starting_deck: cartas del deck inicial público (stats.starting_deck.cards).
func init(rival_stats: Stats, starting_deck: Array[Card]) -> void:
	_rival_stats = rival_stats
	_starting_deck_ids = {}
	for card in starting_deck:
		_starting_deck_ids[card.id] = true
	acquired_cards = []
	Events.card_played.connect(_on_card_played)


## Desconecta el signal. Llamar antes de liberar el AIController.
func cleanup() -> void:
	if Events.card_played.is_connected(_on_card_played):
		Events.card_played.disconnect(_on_card_played)
	_rival_stats = null


func _on_card_played(card: Card, owner_stats: Stats) -> void:
	if owner_stats != _rival_stats:
		return
	if card.id in _starting_deck_ids:
		return
	# Carta no vista antes: adquisición desconocida hasta ahora.
	# Registrar una copia por id único (no podemos distinguir copias adicionales
	# de la misma carta, pero una copia extra por id es una aproximación correcta).
	for ac in acquired_cards:
		if ac.id == card.id:
			return
	acquired_cards.append(card)
