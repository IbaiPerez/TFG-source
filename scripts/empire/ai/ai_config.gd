extends Resource
class_name AIConfig

## Configuración del algoritmo de decisión de la IA.
##
## Permite elegir entre heurística pura (Fase B) y MCTS (Fase C),
## y dentro de MCTS si los rollouts usan la heurística o son aleatorios.
## Exportable como .tres → permite perfiles de dificultad y benchmarks.

enum Mode {
	HEURISTIC,  ## Solo heurística de Fase B: rápida, determinista, ~41µs/opción.
	MCTS,       ## Monte Carlo Tree Search con política de rollout configurable.
	RANDOM,     ## Política aleatoria (elige una opción legal al azar, incluido PASS).
	            ## Rival de referencia débil para el fitness del optimizador de pesos.
}

## Algoritmo de decisión principal.
@export var mode: Mode = Mode.MCTS

## Pesos de la heurística (AIHeuristic). null → usa los valores por defecto
## codificados en HeuristicWeights. Asignar un .tres distinto permite perfiles
## de dificultad y, sobre todo, que el optimizador (SA/GA) enfrente candidatos
## de pesos contra la baseline sin tocar código.
@export var heuristic_weights: HeuristicWeights = null

## Solo relevante si mode == MCTS.
## Controla si la heurística (Fase B) guía la búsqueda en tres puntos:
##   true  → prior PUCT P = score_option normalizado, rival en ▽ usa score_option,
##            rollouts usan score_option como política. Más fuerte, más lento.
##   false → prior P uniforme (1/K), rival en ▽ y rollouts aleatorios.
##            Permite aislar la aportación pura del lookahead MCTS sin heurística.
@export var mcts_heuristic_rollout: bool = true

## Número de iteraciones MCTS por decisión de turno.
## Más iteraciones = mejor calidad, mayor coste de CPU.
## Si mcts_time_budget_ms > 0, esto actúa como TOPE DE SEGURIDAD (la búsqueda
## para antes si agota el tiempo). Si == 0, es el número exacto de iteraciones
## (modo determinista, ideal para tests reproducibles con semilla fija).
@export var mcts_iterations: int = 500

## Presupuesto de tiempo por decisión, en milisegundos. 0 = desactivado (se usan
## exactamente mcts_iterations).
##
## Con la v2 (estado real), el coste por iteración varía mucho según el tamaño
## del estado, frentes activos y eventos, así que un presupuesto de TIEMPO acota
## la latencia de la IA mejor que un número fijo de iteraciones. Cuando es > 0,
## la búsqueda itera hasta agotar el tiempo (con mcts_iterations como techo).
##
## NOTA: el modo por tiempo NO es determinista (el nº de iteraciones depende de
## la velocidad de la máquina) → los tests reproducibles deben dejarlo en 0.
@export var mcts_time_budget_ms: int = 0

## Profundidad del rollout en turnos futuros tras agotar la mano del turno actual.
## 0 → evaluación inmediata (sin lookahead, equivale a búsqueda de 1 turno).
## Profundidad alta es CLAVE aquí: evaluate() (= score_state) es muy "plana" por
## acción, así que las diferencias estratégicas (p.ej. robar cartas → más
## expansión) solo se vuelven legibles tras varios turnos de rollout.
@export var mcts_rollout_depth: int = 5

## Constante de exploración de UCT (C). Las recompensas están en [-1, 1], así que
## sqrt(2) sobre-explora; ~1.0 equilibra mejor explotación/exploración aquí.
@export var mcts_exploration_c: float = 1.0

## Action pruning: número máximo de acciones distintas que se expanden desde
## la raíz, ordenadas por score heurístico (Fase B). Como las acciones ya se
## abstraen por carta (no por target), el branching real suele ser ≤ tamaño de
## mano; K actúa como tope de seguridad. Ver PLAN_IA_COMPLETO §2.1.
@export var mcts_action_pruning_k: int = 12
