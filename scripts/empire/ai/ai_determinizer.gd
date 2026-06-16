extends RefCounted
class_name AIDeterminizer

## Genera manos simuladas del rival para SO-ISMCTS (determinización).
##
## En el juego de información imperfecta, la IA no conoce las cartas en mano del rival.
## SO-ISMCTS resuelve esto: cada iteración del árbol samplea una mano plausible
## del rival y la trata como si fuera la real durante esa iteración.
##
## Simplificación documentada (PLAN_IA_COMPLETO §2.3): el deck completo se trata como
## disponible para samplear, sin distinguir draw vs discard. El mazo recicla cada pocos
## turnos, así que esta aproximación es correcta a escala de los rollouts (2-4 turnos).
##
## Todas las funciones son estáticas: no hay estado interno.


## Construye el deck conocido completo del rival:
##   known_deck base (starting_deck del rival) + cartas adquiridas observadas.
## Si rival_view.deck_size < deck.size() (porque hubo purgas o cartas de un solo uso
## consumidas), se trunca el pool a deck_size. No sabemos cuáles se eliminaron,
## así que se recorta por el final de la lista (sesgo conservador aceptado).
## Fuente canónica para pasar a sample() en cada iteración MCTS.
static func build_known_deck(rival_view: AIEmpirePublicView,
		observer: AIDeckObserver) -> Array[Card]:
	if rival_view == null:
		return []
	var deck: Array[Card] = rival_view.known_deck.duplicate()
	if observer != null:
		for ac in observer.acquired_cards:
			deck.append(ac)
	if rival_view.deck_size > 0 and deck.size() > rival_view.deck_size:
		deck.resize(rival_view.deck_size)
	return deck


## Samplea `hand_size` cartas del deck conocido sin reposición.
## Usa Fisher-Yates con el RNG del llamante para garantizar determinismo reproducible.
## Si hand_size >= deck_size devuelve el deck completo barajado (en la práctica
## hand_size ≤ 4 y el deck tiene ≥ 8 cartas, así que no ocurre).
static func sample(known_deck: Array[Card], hand_size: int,
		rng: RandomNumberGenerator) -> Array[Card]:
	if known_deck.is_empty() or hand_size <= 0:
		return []

	var pool: Array[Card] = known_deck.duplicate()

	# Fisher-Yates con el RNG inyectado.
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Card = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp

	return pool.slice(0, mini(hand_size, pool.size()))
