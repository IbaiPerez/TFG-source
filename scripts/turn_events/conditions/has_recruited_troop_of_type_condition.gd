extends TurnEventCondition
class_name HasRecruitedTroopOfTypeCondition

## Comprueba si el jugador ha reclutado al menos N tropas de un tipo
## (Troop.TroopType) a lo largo de la partida. Util para desbloquear cartas
## tacticas especificas segun la composicion del ejercito ("doctrina
## diegetica").
##
## Lee `stats.types_ever_recruited`, contador historico incrementado en
## `Stats.recruit_troop()`. NO mira `stats.troop_pool` — antes la condicion
## se evaluaba sobre el pool vivo, y como el AIController vacia el pool
## hacia los frentes en cuanto recluta, casi ninguna tactica llegaba a
## desbloquearse aunque el imperio si hubiera reclutado el tipo requerido.
## El contador historico desacopla "tengo este tipo de tropa AHORA" (pool)
## de "he reclutado este tipo alguna vez" (doctrina).

var troop_type: int
var min_count: int


func _init(p_troop_type: int = -1, p_min_count: int = 1):
	troop_type = p_troop_type
	min_count = p_min_count


func is_met(context: EventContext) -> bool:
	if troop_type < 0 or context.stats == null:
		return false
	var recruited: int = int(context.stats.types_ever_recruited.get(troop_type, 0))
	return recruited >= min_count
