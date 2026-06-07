extends RefCounted
class_name AIWorldView

## Encapsula toda la información que la IA puede ver legítimamente durante su turno.
##
## La IA recibe un AIWorldView en AITurnContext y solo debe consultar esta clase
## en lugar de acceder directamente a los Stats de otros controllers.
## Esto garantiza que la IA no viola la barrera de información imperfecta:
## nunca puede leer draw_pile, discard_pile ni la mano real de ningún rival.

var own_stats: Stats                             ## acceso completo a las propias stats
var rival_views: Array[AIEmpirePublicView] = []  ## una vista pública por cada rival


## Construye un AIWorldView para la IA, extrayendo la info pública de todos
## los controllers del juego. El controller cuyas stats coincidan con own_stats
## se omite (es la propia IA).
static func build(own_stats: Stats,
		all_controllers: Array[EmpireController]) -> AIWorldView:
	var wv := AIWorldView.new()
	wv.own_stats = own_stats
	for ctrl in all_controllers:
		if ctrl.stats == null or ctrl.stats == own_stats:
			continue
		if ctrl.stats.empire == null:
			continue
		wv.rival_views.append(AIEmpirePublicView.from_controller(ctrl))
	return wv


## Devuelve la vista del primer rival, o null si no hay rivales conocidos.
## Atajo para la lógica 1v1 (el escenario habitual de la partida).
func get_rival_view() -> AIEmpirePublicView:
	if rival_views.is_empty():
		return null
	return rival_views[0]
