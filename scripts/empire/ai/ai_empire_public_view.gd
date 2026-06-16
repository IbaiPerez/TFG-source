extends RefCounted
class_name AIEmpirePublicView

## Vista pública de un imperio rival — solo contiene información observable.
##
## Todo lo que está aquí es visible en la UI del juego para ambos jugadores.
## Lo que NO está aquí (información privada del rival):
##   - draw_pile:    el orden exacto de las cartas que quedan por robar
##   - discard_pile: las cartas que ha descartado esta partida
##   - played_pile:  las cartas de un solo uso ya gastadas
##   - mano real:    qué cartas específicas tiene este turno (solo se sabe cuántas)

var empire: Empire               ## tiles, edificios, tropas en frentes (visible en el mapa)
var total_gold: int              ## visible en UI
var gold_per_turn: int           ## visible en UI
var food: int                    ## visible en UI
var hand_size: int               ## cartas que robará este turno (cards_per_turn + bonuses activos)
var deck_size: int               ## draw_pile + discard_pile del rival (sin played_pile ni mano actual).
                                 ## Refleja purgas y cartas de un solo uso consumidas sin revelarlas.
var known_deck: Array[Card]      ## deck inferido: empieza como el deck inicial (info pública).
                                 ## AIDeckObserver lo amplía al observar cartas jugadas (Fase C).


## Construye la vista pública a partir de un controller rival.
## Solo lee información que la UI expone a ambos jugadores.
static func from_controller(ctrl: EmpireController) -> AIEmpirePublicView:
	var view := AIEmpirePublicView.new()
	view.empire = ctrl.stats.empire
	view.total_gold = ctrl.stats.total_gold
	view.gold_per_turn = ctrl.stats.gold_per_turn
	view.food = ctrl.stats.food

	# hand_size: cards_per_turn base + bonus de modificadores activos.
	# Observable porque la UI muestra cuántas cartas robará el rival.
	var bonus := 0
	if ctrl.modifier_manager != null:
		bonus = ctrl.modifier_manager.get_cards_per_turn_bonus()
	view.hand_size = clampi(ctrl.stats.cards_per_turn + bonus, 1, 20)

	# deck_size = draw_pile + discard_pile (excluye played_pile y mano robada).
	# Permite a la IA detectar purgas y cartas de un solo uso consumidas sin
	# saber cuáles son: si known_deck.size() > deck_size, alguna fue eliminada.
	view.deck_size = ctrl.stats.draw_pile.cards.size() + ctrl.stats.discard_pile.cards.size()

	# El starting_deck es información pública: ambos imperios arrancan con el mismo
	# recurso. Las cartas compradas en tienda o ganadas por eventos NO están aquí
	# (son privadas hasta que se juegan). AIDeckObserver las añade al modelo de
	# deck conocido conforme las observa (Fase C).
	# Fallback a stats.deck para compatibilidad con tests que no inicializan starting_deck.
	if ctrl.stats.starting_deck != null:
		view.known_deck = ctrl.stats.starting_deck.cards.duplicate()
	elif ctrl.stats.deck != null:
		view.known_deck = ctrl.stats.deck.cards.duplicate()
	else:
		view.known_deck = []

	return view
