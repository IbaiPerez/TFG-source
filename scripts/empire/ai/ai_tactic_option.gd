extends AIPlayOption
class_name AITacticOption

## Bypass de TacticCard: el AIOptionsBuilder enumera frentes desde
## battle_front_manager.active_fronts, en vez de TacticCard.get_valid_targets, que
## lee el group "battle_front_visuals" del scene tree de forma frágil.
##
## La IA NO resuelve el nodo visual. `TacticCard.apply_effects` usa el
## BattleFrontVisual como MERO PORTADOR (lo único que hace es desenvolver
## `visual.battle_front` y llamar a `apply_to_front`), y `Card.play` solo emite
## `card_played` + `apply_effects`. Así que aplicar directamente sobre el frente y
## emitir la señal a mano es EQUIVALENTE, y elimina la única dependencia IA→UI del
## bloque: ya no se recorre el scene tree desde una clase de IA, y el camino de la
## IA es el mismo con escena 3D o sin ella.

var front: BattleFront


static func from_card(p_card: TacticCard, p_front: BattleFront) -> AITacticOption:
	var opt := AITacticOption.new()
	opt.card = p_card
	opt.front = p_front
	# La táctica se aplica sobre el BattleFront, no sobre un nodo de escena.
	opt.targets = []
	opt.payload = {"front": p_front}
	return opt


func execute(ctx: AITurnContext) -> Card:
	if card == null or front == null:
		return null

	# Equivalente a `card.play([visual], stats)`: play() emite card_played y llama a
	# apply_effects, que con el visual solo desenvuelve su battle_front. Aquí se
	# aplica sobre el frente sin pasar por la escena.
	Events.card_played.emit(card, ctx.stats)
	(card as TacticCard).apply_to_front(front, ctx.stats)
	return card


func describe() -> String:
	return "Tactic(front)"


## Como ancla del feedback visual usamos la tile defensora del frente
## (es donde "ocurre" el efecto desde el punto de vista del atacante).
## Si la IA es defensora, la atacante tiene el mismo sentido visual.
func anchor_tile() -> Tile:
	if front == null:
		return null
	return front.defender_tile if front.defender_tile != null else front.attacker_tile
