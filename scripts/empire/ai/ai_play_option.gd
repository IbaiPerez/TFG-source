extends RefCounted
class_name AIPlayOption

## Representación uniforme de una jugada legal que la IA puede tomar.
## Una opción = (carta, targets[, payload con sub-decisiones]) o "PASS".
##
## El AIController enumera AIPlayOptions vía AIOptionsBuilder, elige una al
## azar usando el RNG del contexto, y llama execute(ctx) para aplicarla.
##
## La implementación por defecto de execute():
##  - Llama card.play(targets, stats) que emite Events.card_played con
##    owner_stats=ctx.stats. El bus refactorizado filtra por dueño, así
##    que sólo modifiers/buildings de la IA reaccionan; PlayerHandler/Hand
##    ignoran las cartas IA.
##  - Las subclases pueden override para casos que requieren bypass de
##    menús de UI (CardDraw, BuildCard con building elegido, etc.).
##    Esas subclases siguen usando card.play() para mantener simétrico
##    el flujo de señales — sólo rellenan los campos que el menú de UI
##    rellenaría antes de llamar play().

var card: Card                       ## null si is_pass == true
var targets: Array[Node] = []        ## targets resueltos para apply_effects
var payload: Dictionary = {}         ## sub-decisiones (building, troop, source_tile…)
var is_pass: bool = false            ## true → no jugar nada


## Factory para una opción de jugada simple (cubre cartas que solo necesitan
## card.apply_effects(targets, stats) sin sub-decisiones).
static func simple(p_card: Card, p_targets: Array[Node] = []) -> AIPlayOption:
	var opt := AIPlayOption.new()
	opt.card = p_card
	opt.targets = p_targets
	return opt


## Factory para la opción "no jugar nada y pasar".
static func create_pass() -> AIPlayOption:
	var opt := AIPlayOption.new()
	opt.is_pass = true
	return opt


## Ejecuta la opción. Por defecto, aplica los efectos de la carta.
## Las subclases sobrescriben para bypasses específicos.
##
## Devuelve la carta jugada (para que el controller la pase a
## _handle_card_played), o null si la opción no consume carta (PASS).
func execute(ctx: AITurnContext) -> Card:
	if is_pass:
		return null
	if card == null:
		push_warning("[AIPlayOption] execute() sin card y sin is_pass")
		return null
	# play() emite card_played(card, stats) y luego apply_effects internamente.
	card.play(targets, ctx.stats)
	return card


## Descripción legible para logs y feedback. Las subclases pueden override
## para enriquecer (p.ej. BuildOption diría "Construye Mina").
func describe() -> String:
	if is_pass:
		return "PASS"
	if card == null:
		return "<sin carta>"
	return card.id if card.id else "<carta sin id>"


## Tile ancla para feedback visual (floating label sobre la tile).
## null si la opción no tiene una tile clara (SELF cards, PASS).
## Las subclases con sub-decisiones de tile (Build, Recruit con tile fijada,
## OpenFront) pueden override para devolver la tile correcta.
func anchor_tile() -> Tile:
	if is_pass or targets.is_empty():
		return null
	for t in targets:
		if t is Tile:
			return t
	return null
