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

## Tamaño total del mapa (todas las tiles). 0 = desconocido (tests, eventos).
## Usado por AIGamePhase.detect() para fases relativas al mapa (D5).
var total_map_tiles: int = 0

# ---------------------------------------------------------------------------
# Caché de decisión
# ---------------------------------------------------------------------------
# Rellenado por AIHeuristic.prepare_decision_cache() una sola vez antes del
# bucle de scoring de cada decisión. Invalida con invalidate_decision_cache()
# al ejecutar la opción elegida, de modo que la siguiente decisión recalcula.

var _cache_valid: bool = false
var _cache_gu: float = 0.0
var _cache_fu: float = 0.0
var _cache_mu: float = 0.0
var _cache_surplus: float = 1.0
var _cache_expansion: float = 0.5
var _cache_active_fronts: Array[BattleFront] = []
var _cache_has_active_front: bool = false
var _cache_has_adjacent_enemy: bool = false
var _cache_front_pressure: float = 0.0
var _cache_buildable_slots: int = 0
var _cache_upgradeable: int = 0
var _cache_deck_size: int = 0


func invalidate_decision_cache() -> void:
	_cache_valid = false


static func create(p_controller: Node, p_rng: RandomNumberGenerator) -> AITurnContext:
	var ctx := AITurnContext.new()
	ctx.controller = p_controller
	ctx.stats = p_controller.stats
	ctx.battle_front_manager = p_controller.battle_front_manager
	ctx.rng = p_rng
	ctx.drawn_cards = []
	return ctx
