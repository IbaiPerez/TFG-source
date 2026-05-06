extends TurnEventCondition
class_name HasRecruitedTroopOfTypeCondition

## Comprueba si el jugador tiene al menos N tropas de un tipo concreto
## (Troop.TroopType) en el pool. Útil para desbloquear cartas tácticas
## específicas según la composición del ejército ("doctrina diegética").
##
## Nota: actualmente cuenta sólo las tropas vivas en el pool. Si una tropa
## se recluta y muere en un frente sin que se recluten más de ese tipo,
## la condición deja de cumplirse. En el futuro podría reemplazarse por
## un tracking histórico (`stats.types_ever_recruited`) si fuera necesario.

var troop_type: int
var min_count: int


func _init(p_troop_type: int = -1, p_min_count: int = 1):
	troop_type = p_troop_type
	min_count = p_min_count


func is_met(context: EventContext) -> bool:
	if troop_type < 0 or context.stats == null:
		return false
	var count := 0
	for troop in context.stats.troop_pool:
		if troop != null and troop.type == troop_type:
			count += 1
			if count >= min_count:
				return true
	return false
