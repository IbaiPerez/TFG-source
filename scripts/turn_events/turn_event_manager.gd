extends Node
class_name TurnEventManager

var stats:Stats


## Evalua si dispara un evento este turno y, si es asi, cual.
##
## Selección en tres fases:
##   A) Roll global stats.event_chance: si falla, no hay evento.
##   B) Si hay candidatos en CORE_PROGRESSION, se prioriza esa categoría
##      con probabilidad core_priority_chance (definida en
##      stats.category_weights). Si el roll pasa, se dispara un evento
##      CORE; si falla, CORE entra al pickeo normal junto al resto.
##   C) Pickeo ponderado por categoría usando los pesos de
##      EventCategoryWeights (curva → fallback constante). Solo participan
##      las categorías que tengan al menos un candidato. Una vez elegida
##      la categoría, se hace pickeo ponderado por evento dentro usando
##      el campo weight individual.
##
## Si stats.category_weights es null se usa un peso uniforme (1.0) para
## todas las categorías como fallback de seguridad.
func evaluate(context:EventContext) -> TurnEvent:
	# Fase A: probabilidad global de que ocurra un evento.
	# Si stats.category_weights está configurado, usa su curva
	# (event_chance_curve) o su fallback. Si no, cae al legacy
	# stats.event_chance para compatibilidad.
	var event_chance:float = _get_event_chance(context.turn_number)
	if randf() > event_chance:
		return null

	# Filtrar eventos disponibles y agruparlos por categoría
	var by_category:Dictionary = _collect_available_by_category(context)
	if by_category.is_empty():
		return null

	# Fase B: prioridad CORE_PROGRESSION
	var picked:TurnEvent = null
	if by_category.has(EventCategory.Type.CORE_PROGRESSION):
		var priority_chance:float = _get_core_priority_chance()
		if randf() < priority_chance:
			picked = _weighted_pick_event(
				by_category[EventCategory.Type.CORE_PROGRESSION]
			)

	# Fase C: si no se ha priorizado CORE, pickeo por categoría
	if picked == null:
		var category:int = _pick_category(by_category, context.turn_number)
		if category < 0:
			return null
		picked = _weighted_pick_event(by_category[category])

	if picked:
		picked.prepare(context)
	return picked


func resolve(event:TurnEvent, choice:TurnEventChoice,
		context:EventContext, chosen_cards:Dictionary = {}) -> void:
	choice.execute(context, chosen_cards)
	if event.unique:
		stats.used_unique_events.append(event.id)


# ============================================================
#  Helpers internos
# ============================================================

## Devuelve un Dictionary { EventCategory.Type : Array[TurnEvent] } con
## los eventos disponibles agrupados por categoría. Filtra unique ya
## consumidos y comprueba is_available().
func _collect_available_by_category(context:EventContext) -> Dictionary:
	var by_category:Dictionary = {}
	for event in stats.available_events:
		if event.unique and event.id in stats.used_unique_events:
			continue
		if not event.is_available(context):
			continue
		if not by_category.has(event.category):
			by_category[event.category] = []
		by_category[event.category].append(event)
	return by_category


## Selección ponderada de categoría en función del peso que devuelve
## EventCategoryWeights.get_weight(category, turn). Solo se consideran
## las categorías presentes en `by_category`. Devuelve -1 si todos los
## pesos son cero (no debería ocurrir en práctica, pero es defensivo).
func _pick_category(by_category:Dictionary, turn:int) -> int:
	var weights:EventCategoryWeights = stats.category_weights
	var total_weight:float = 0.0
	var category_weights:Dictionary = {}

	for category in by_category.keys():
		var w:float = 1.0
		if weights != null:
			w = weights.get_weight(category, turn)
		if w <= 0.0:
			continue
		category_weights[category] = w
		total_weight += w

	if total_weight <= 0.0:
		return -1

	var roll:float = randf() * total_weight
	var cumulative:float = 0.0
	var last_category:int = -1
	for category in category_weights.keys():
		cumulative += category_weights[category]
		last_category = category
		if roll <= cumulative:
			return category
	return last_category


## Pickeo ponderado de evento dentro de una categoría usando event.weight.
func _weighted_pick_event(events:Array) -> TurnEvent:
	if events.is_empty():
		return null

	var total_weight:float = 0.0
	for e in events:
		total_weight += e.weight

	if total_weight <= 0.0:
		# Si todos los pesos son 0, devolver el primero como fallback.
		return events[0]

	var roll:float = randf() * total_weight
	var cumulative:float = 0.0
	for e in events:
		cumulative += e.weight
		if roll <= cumulative:
			return e

	return events.back()


func _get_core_priority_chance() -> float:
	if stats.category_weights == null:
		return 0.9
	return stats.category_weights.core_priority_chance


func _get_event_chance(turn:int) -> float:
	if stats.category_weights == null:
		return stats.event_chance
	return stats.category_weights.get_event_chance(turn)
