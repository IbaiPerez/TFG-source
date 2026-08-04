extends TurnEventCondition
class_name HasAdjacentUncontrolledCondition

## Comprueba si existe al menos una casilla adyacente no controlada
## por el imperio. Filtro opcional por bioma.
## -1 = sin filtro de bioma.
##
## Lee los agregados de EventContext: la adyacencia libre se recolecta
## una vez al construir el contexto, en vez de recorrer aqui los vecinos.

var required_biome_type:int = -1


func _init(p_biome:int = -1):
	required_biome_type = p_biome


func is_met(context:EventContext) -> bool:
	if required_biome_type == -1:
		return context.has_adjacent_uncontrolled
	return context.adjacent_uncontrolled_biomes.has(required_biome_type)
