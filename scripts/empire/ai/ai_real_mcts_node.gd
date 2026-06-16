extends RefCounted
class_name AIRealMCTSNode

## Nodo del árbol MCTS v2 (Fase C v2 — F3b), forma canónica de ISMCTS.
##
## El nodo es un CONJUNTO DE INFORMACIÓN: guarda solo la jugada que lo generó y
## sus estadísticos, NO el estado. El estado se re-deriva en cada iteración
## aplicando las jugadas del camino raíz→nodo bajo la determinización de esa
## iteración (así las transiciones estocásticas — eventos, robos, mano del rival
## — se promedian como chance nodes, en vez de congelar un estado por nodo).
##
## Sin puntero a `parent` (igual que la v1): la selección construye un `path` y
## la retropropagación lo recorre, evitando ciclos que RefCounted no recolecta.
##
## Estadísticos (Cowling 2012): visits (n), value_sum (Σ valor en perspectiva
## SELF), availability (A). El valor se acumula SIEMPRE en perspectiva propia
## (la hoja es score_state propio); el negamax se aplica al SELECCIONAR (el
## orquestador invierte el signo de Q en nodos del rival).

const OWNER_SELF := AIRealState.OWNER_SELF
const OWNER_RIVAL := AIRealState.OWNER_RIVAL

var to_move: int = OWNER_SELF         ## jugador que decide EN este nodo
var depth: int = 0                    ## rondas completas (▲+▽) desde la raíz
var move: AIRealOptions.Move = null   ## jugada que generó este nodo (null en la raíz)
var prior: float = 0.0                ## P (score_move normalizado) para el PUCT
var is_eval_leaf: bool = false        ## hoja: terminal o límite de profundidad → score_state directo

var children: Array[AIRealMCTSNode] = []
var child_by_key: Dictionary = {}     ## move_key -> AIRealMCTSNode (para casar disponibilidad)

var visits: int = 0
var value_sum: float = 0.0
var availability: int = 0


static func create(p_to_move: int, p_depth: int) -> AIRealMCTSNode:
	var n := AIRealMCTSNode.new()
	n.to_move = p_to_move
	n.depth = p_depth
	return n


## Añade un hijo indexado por la clave de su jugada.
func add_child(child: AIRealMCTSNode, key: String) -> void:
	children.append(child)
	child_by_key[key] = child


## Valor medio acumulado (Q) en perspectiva propia. 0 si no visitado.
func avg_value() -> float:
	if visits == 0:
		return 0.0
	return value_sum / float(visits)


## Hijo más visitado (robust child) — la decisión final del MCTS.
## Desempata por mayor avg_value en perspectiva propia.
func most_visited_child() -> AIRealMCTSNode:
	var best: AIRealMCTSNode = null
	var best_visits := -1
	var best_avg := -INF
	for child in children:
		if child.visits > best_visits \
				or (child.visits == best_visits and child.avg_value() > best_avg):
			best_visits = child.visits
			best_avg = child.avg_value()
			best = child
	return best


## Clave de identidad de un Move, para casar jugadas disponibles (que varían por
## determinización en los nodos del rival) con los hijos ya expandidos.
static func move_key(m: AIRealOptions.Move) -> String:
	if m == null or m.kind == &"PASS":
		return "PASS"
	var parts: Array[String] = [String(m.kind)]
	parts.append(str(m.card.get_instance_id()) if m.card != null else "_")
	parts.append(str(m.tile_id))
	parts.append(str(m.def_tile_id))
	parts.append(str(m.building.get_instance_id()) if m.building != null else "_")
	parts.append(str(m.new_building.get_instance_id()) if m.new_building != null else "_")
	parts.append(str(m.troop.get_instance_id()) if m.troop != null else "_")
	parts.append(str(m.front_idx))
	return "|".join(parts)
