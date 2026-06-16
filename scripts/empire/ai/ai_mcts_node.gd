extends RefCounted
class_name AIMCTSNode

## Nodo del árbol de búsqueda MCTS/UCT (Fase C).
##
## Cada nodo representa un estado del juego (AIGameState) alcanzado tras una
## secuencia de jugadas DENTRO del turno actual de la IA. Las aristas son
## "moves" (jugar una carta concreta, o PASS). El lookahead a turnos futuros
## NO vive en el árbol sino en el rollout (ver AIMCTS), por lo que la
## profundidad del árbol está acotada por el tamaño de la mano (~2-5).
##
## DISEÑO — sin puntero a `parent`:
##   Guardar parent↔children crearía un ciclo de referencias que RefCounted
##   (conteo de referencias) no recolecta → fuga de memoria. En su lugar, la
##   fase de selección de AIMCTS construye un `path` raíz→hoja y la
##   retropropagación lo recorre. Así el árbol es un DAG dirigido hacia abajo
##   y se libera limpiamente al soltar la raíz.
##
## Forma de un "move" (Dictionary):
##   { "kind": "abstract", "abstract": <opción abstracta>, "card": Card,
##     "real": AIPlayOption|null }   → jugar una carta
##   { "kind": "pass" }              → no jugar nada y cerrar el turno
## El campo "real" solo se rellena en los moves de la raíz: es la AIPlayOption
## concreta (mejor instancia por score heurístico) que el controller ejecutará.

var state: AIGameState
var hand: Array[Card] = []              ## Cartas aún jugables este turno en este nodo
var children: Array[AIMCTSNode] = []
var untried_moves: Array = []           ## Moves pendientes de expandir
var move: Dictionary = {}               ## Move que generó este nodo (vacío en la raíz)
var is_turn_end: bool = false           ## Alcanzado vía PASS o mano agotada

var visits: int = 0
var value_sum: float = 0.0


static func create(p_state: AIGameState, p_hand: Array[Card]) -> AIMCTSNode:
	var n := AIMCTSNode.new()
	n.state = p_state
	n.hand = p_hand
	return n


## Valor medio acumulado (Q). 0.0 si aún no se ha visitado.
func avg_value() -> float:
	if visits == 0:
		return 0.0
	return value_sum / float(visits)


func is_fully_expanded() -> bool:
	return untried_moves.is_empty()


## True si es hoja del árbol: fin de turno o sin moves posibles.
func is_leaf() -> bool:
	return is_turn_end or (children.is_empty() and untried_moves.is_empty())


## Selecciona el hijo con mayor valor UCB1.
##   UCB1 = Q_i + c · sqrt(ln(N) / n_i)
## Recompensas en [-1, 1]; c se configura vía AIConfig.mcts_exploration_c.
## Un hijo sin visitas (n_i == 0) tiene prioridad infinita (se explora primero),
## aunque en la práctica la expansión los visita antes de llegar aquí.
func best_uct_child(c: float) -> AIMCTSNode:
	var best: AIMCTSNode = null
	var best_score := -INF
	var log_n := log(float(maxi(visits, 1)))
	for child in children:
		var score: float
		if child.visits == 0:
			score = INF
		else:
			var exploit := child.value_sum / float(child.visits)
			var explore := c * sqrt(log_n / float(child.visits))
			score = exploit + explore
		if score > best_score:
			best_score = score
			best = child
	return best


## Hijo más visitado (robust child) — la decisión final de MCTS.
## Desempata por valor medio mayor.
func most_visited_child() -> AIMCTSNode:
	var best: AIMCTSNode = null
	var best_visits := -1
	var best_avg := -INF
	for child in children:
		if child.visits > best_visits \
				or (child.visits == best_visits and child.avg_value() > best_avg):
			best_visits = child.visits
			best_avg = child.avg_value()
			best = child
	return best
