extends Resource
class_name EventCategoryWeights

## Pesos por categoría de evento para el TurnEventManager: un peso constante por
## categoría, la probabilidad global de que dispare un evento y la prioridad de
## CORE_PROGRESSION.
##
## CORE_PROGRESSION recibe un trato especial: si hay candidatos en esa categoría,
## se dispara con probabilidad core_priority_chance saltándose el resto. Si el
## roll falla, CORE compite con las demás como cualquier otra categoría.

# Calibrados para mid-game en turnos 30-40.
@export var core_progression_fallback:float = 3.0
@export var optional_progression_fallback:float = 4.0
@export var flavour_fallback:float = 4.0
@export var deck_fallback:float = 2.5
@export var shop_fallback:float = 2.5
@export var spirit_fallback:float = 2.0
@export var decision_fallback:float = 1.0

## Probabilidad de priorizar CORE_PROGRESSION cuando tiene candidatos.
## Si el roll falla, CORE entra en el pickeo normal junto al resto.
@export_range(0.0, 1.0) var core_priority_chance:float = 0.9

## Probabilidad global de que ocurra un evento (fase A del manager).
@export_range(0.0, 1.0) var event_chance_fallback:float = 0.5


func get_weight(category:int) -> float:
	match category:
		EventCategory.Type.CORE_PROGRESSION: return core_progression_fallback
		EventCategory.Type.OPTIONAL_PROGRESSION: return optional_progression_fallback
		EventCategory.Type.FLAVOUR: return flavour_fallback
		EventCategory.Type.DECK: return deck_fallback
		EventCategory.Type.SHOP: return shop_fallback
		EventCategory.Type.SPIRIT: return spirit_fallback
		EventCategory.Type.DECISION: return decision_fallback
	return 0.0
