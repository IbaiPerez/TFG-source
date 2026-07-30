extends RefCounted
class_name SceneGroups

## Nombres de los grupos con los que se localizan los nodos únicos de la escena de
## partida, y accesores tipados para ellos.
##
## Antes el nombre del grupo era un literal repetido en 16 puntos
## (`get_tree().get_first_node_in_group("ui_layer")`), la mitad de ellos en
## SceneManager. Renombrar el grupo en map.tscn no habría dado ningún aviso: la
## búsqueda simplemente empieza a devolver null. Con estas constantes el nombre se
## declara una vez y el accesor devuelve el tipo correcto sin castear en cada sitio.
##
## Es el mismo motivo que [MapScenePaths], que centraliza las RUTAS de nodo de
## map.tscn; esto centraliza los GRUPOS.
##
## Los accesores devuelven null EN SILENCIO a propósito, sin `assert` ni
## `push_error`: correr sin PlayerHandler ni capa de UI es legítimo en los tests
## headless y en los arneses de simulación, y varios llamantes ya tratan ese null
## como caso normal. Además GUT convierte cualquier error de motor en un fallo de
## test, así que avisar aquí rompería suites que hoy pasan.
##
## ⚠️ ESTE MÓDULO NO PUEDE REFERENCIAR NINGUNA CLASE DEL JUEGO — por eso los dos
## accesores devuelven `Node` y el casteo se hace en el llamante. Tipar el de
## PlayerHandler creaba el ciclo
##   initial_stats.tres → cartas → DrawCardEffect → SceneGroups → PlayerHandler
##   → EmpireController → Stats
## y GDScript no lo resolvía al cargar el recurso: `load()` devolvía null y 12
## tests de serialización fallaban con un mensaje que no apuntaba al ciclo. Como
## los usan efectos y cartas, que están dentro del grafo de dependencias de los
## recursos, esto debe quedarse sin dependencias, igual que [MapScenePaths],
## [GameBalance] y [PhysicsLayers].

## Grupo del CanvasLayer que contiene la UI de partida (Scene/UI_layer en map.tscn).
const UI_LAYER := "ui_layer"
## Grupo del PlayerHandler (se registra desde el propio player_handler.gd).
const PLAYER_HANDLER := "player_handler"


## Capa de UI de la partida, o null si no hay escena de mapa montada.
##
## Es un CanvasLayer en map.tscn, pero se devuelve como Node: los llamantes solo
## usan API de Node —`add_child`, `reparent`, `has_node`— y así el módulo queda
## sin dependencias (ver el aviso de la cabecera).
static func ui_layer(tree: SceneTree) -> Node:
	return tree.get_first_node_in_group(UI_LAYER)


## PlayerHandler de la partida, o null si no hay escena de mapa montada.
## Sin tipar, por el ciclo descrito en la cabecera: castea el llamante.
static func player_handler(tree: SceneTree) -> Node:
	return tree.get_first_node_in_group(PLAYER_HANDLER)
