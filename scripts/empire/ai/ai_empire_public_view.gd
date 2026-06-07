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

	# El deck inicial es información pública: ambos imperios comienzan con el
	# mismo recurso de deck. Solo se duplica la lista de cartas; AIDeckObserver
	# amplía esto cuando observa cartas adquiridas en tienda o por eventos (Fase C).
	if ctrl.stats.deck != null:
		view.known_deck = ctrl.stats.deck.cards.duplicate()
	else:
		view.known_deck = []

	return view
