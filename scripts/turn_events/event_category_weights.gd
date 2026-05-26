extends Resource
class_name EventCategoryWeights

## Configuración de pesos por categoría para el TurnEventManager.
## Cada categoría tiene un peso constante de fallback y, opcionalmente,
## una Curve nativa de Godot (editable en el inspector) que mapea
## turno → peso. Cuando la curva está presente tiene prioridad sobre el
## fallback; si la curva es null se usa el fallback constante.
##
## CORE_PROGRESSION recibe un trato especial: si hay candidatos en esa
## categoría, se dispara con probabilidad core_priority_chance saltándose
## el resto. Si el roll falla, CORE compite con las demás como cualquier
## otra categoría usando su peso (curva o fallback).

# --- Curvas opcionales (override fino) ---
@export var core_progression_curve:Curve
@export var optional_progression_curve:Curve
@export var flavour_curve:Curve
@export var deck_curve:Curve
@export var shop_curve:Curve
@export var spirit_curve:Curve
@export var decision_curve:Curve

# --- Pesos constantes de fallback ---
# Se usan cuando la curva correspondiente es null.
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

## Curva opcional que modela la probabilidad global de que ocurra un
## evento (fase A del manager) a lo largo de la partida. Eje X = turno,
## eje Y = probabilidad [0, 1]. Si es null se usa event_chance_fallback.
## Idea típica: empieza ~0.5 en early game y sube hacia ~0.9 en lategame
## para que en partidas avanzadas haya casi un evento por turno.
@export var event_chance_curve:Curve

## Fallback constante para la probabilidad global cuando event_chance_curve
## es null. Mantiene compatibilidad con el comportamiento anterior.
@export_range(0.0, 1.0) var event_chance_fallback:float = 0.5


## Devuelve el peso para una categoría en un turno concreto.
## Si hay curva configurada se samplea (clampando al dominio).
## Si no, se devuelve el peso constante de fallback.
func get_weight(category:int, turn:int) -> float:
	var curve:Curve = _curve_for(category)
	if curve != null:
		var clamped:float = clamp(float(turn), curve.min_domain, curve.max_domain)
		return curve.sample(clamped)
	return _fallback_for(category)


## Devuelve la probabilidad global de que ocurra un evento en el turno
## indicado. Usa event_chance_curve si está presente (clampando al
## dominio y al rango [0, 1]) y cae a event_chance_fallback si no.
func get_event_chance(turn:int) -> float:
	if event_chance_curve != null:
		var clamped:float = clamp(
			float(turn),
			event_chance_curve.min_domain,
			event_chance_curve.max_domain
		)
		return clampf(event_chance_curve.sample(clamped), 0.0, 1.0)
	return event_chance_fallback


func _curve_for(category:int) -> Curve:
	match category:
		EventCategory.Type.CORE_PROGRESSION: return core_progression_curve
		EventCategory.Type.OPTIONAL_PROGRESSION: return optional_progression_curve
		EventCategory.Type.FLAVOUR: return flavour_curve
		EventCategory.Type.DECK: return deck_curve
		EventCategory.Type.SHOP: return shop_curve
		EventCategory.Type.SPIRIT: return spirit_curve
		EventCategory.Type.DECISION: return decision_curve
	return null


func _fallback_for(category:int) -> float:
	match category:
		EventCategory.Type.CORE_PROGRESSION: return core_progression_fallback
		EventCategory.Type.OPTIONAL_PROGRESSION: return optional_progression_fallback
		EventCategory.Type.FLAVOUR: return flavour_fallback
		EventCategory.Type.DECK: return deck_fallback
		EventCategory.Type.SHOP: return shop_fallback
		EventCategory.Type.SPIRIT: return spirit_fallback
		EventCategory.Type.DECISION: return decision_fallback
	return 0.0
