extends Card
class_name RecoverCard

## Carta de un solo uso que permite recuperar una carta de la played_pile
## (cartas de un solo uso ya utilizadas) y devolverla a la mano del jugador.

var menu:Control  ## referencia al panel de seleccion (RecoverCardPanel)
var chosen:Card   ## carta elegida por el jugador


func _build_tooltip() -> String:
	return "[center][b][color=#5B7A3A]Recupera[/color][/b] una [color=#4A6A8A]carta de un solo uso[/color] jugada y devuelvela a tu mano[/center]"


func confirm(targets:Array[Node], stats:Stats) -> void:
	Events.recover_card_confirm_started.emit(self, stats)


func apply_effects(_targets:Array[Node], stats:Stats) -> void:
	if not chosen:
		return
	# Quitar la carta elegida de la played_pile
	stats.played_pile.remove_card(chosen)
	# Devolver la carta elegida a la mano del jugador
	Events.card_returned_to_hand.emit(chosen)
