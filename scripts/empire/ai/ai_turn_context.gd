extends RefCounted
class_name AITurnContext

## Contexto compartido durante el turno de un AIController.
## Se pasa a AIPlayOption.execute() y a AIOptionsBuilder.build_options()
## para que las opciones tengan todo lo que necesitan sin acoplarse a
## detalles del controller.
##
## El contexto es mutable: las opciones que roban cartas extra (CardDraw)
## modifican `drawn_cards`; la opción ejecutada se elimina de `drawn_cards`
## desde el controller tras llamar `execute()`.

var controller: Node                    ## AIController dueño del turno
var stats: Stats                        ## Stats del controller
var battle_front_manager: BattleFrontManager  ## BFM del controller
var rng: RandomNumberGenerator          ## RNG con seed para determinismo
var drawn_cards: Array[Card] = []       ## Cartas que la IA tiene "en mano" durante el turno
var world_view: AIWorldView             ## Vista de información del turno (Fase A):
                                        ## own_stats + vistas públicas de rivales.

## Tiles sin controller adyacentes a tiles propias. -1 = desconocido (tests).
var colonizable_tiles_count: int = -1


static func create(p_controller: Node, p_rng: RandomNumberGenerator) -> AITurnContext:
	var ctx := AITurnContext.new()
	ctx.controller = p_controller
	ctx.stats = p_controller.stats
	ctx.battle_front_manager = p_controller.battle_front_manager
	ctx.rng = p_rng
	ctx.drawn_cards = []
	return ctx
