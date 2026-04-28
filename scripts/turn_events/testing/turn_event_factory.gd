extends RefCounted
class_name TurnEventFactory

## Factoria temporal de eventos para testear el sistema.
## Uso desde map.gd u otro sitio de inicializacion:
##   stats.available_events = TurnEventFactory.create_test_events()


const COLONIZE_CARD = preload("res://resources/cards/colonize_card.tres")
const CARD_DRAW_CARD = preload("res://resources/cards/card_draw_card.tres")
const WHEAT_RESOURCE = preload("res://resources/natural_resources/wheat.tres")


static func create_test_events() -> Array[TurnEvent]:
	var events:Array[TurnEvent] = []
	events.append(_merchant_caravan())
	events.append(_poor_harvest())
	events.append(_investment())
	events.append(_trade_route_discovery())
	events.append(_golden_age())
	return events


## Evento simple: te dan 30 oro sin mas
static func _merchant_caravan() -> TurnEvent:
	var event := TurnEvent.new()
	event.id = "merchant_caravan"
	event.title = "Caravana mercante"
	event.description = "[i]Una caravana mercante llega a tus tierras cargada de monedas.[/i]"
	event.weight = 2.0
	event.allow_skip = false

	var choice := TurnEventChoice.new()
	choice.label = "Aceptar las monedas (+30 oro)"
	choice.description = "Recibes 30 piezas de oro inmediatamente."
	choice.effects = [GoldEventEffect.new(30)]
	event.choices = [choice]

	return event


## Evento malo: modificador negativo de produccion durante 3 turnos
static func _poor_harvest() -> TurnEvent:
	var event := TurnEvent.new()
	event.id = "poor_harvest"
	event.title = "Mala cosecha"
	event.description = "[i]Las lluvias no llegaron este año. Tus reservas menguan.[/i]"
	event.weight = 1.0
	event.allow_skip = false

	# Reduccion plana de oro durante 3 turnos
	var penalty := StatModifier.new(
		"poor_harvest_penalty",
		"Mala cosecha",
		StatModifier.StatType.FLAT_GOLD,
		-5.0,
		3
	)

	var choice := TurnEventChoice.new()
	choice.label = "Aguantar (-5 oro/turno durante 3 turnos)"
	choice.description = "No hay nada que hacer, solo esperar a que pase."
	choice.effects = [ApplyModifierEffect.new(penalty)]
	event.choices = [choice]

	return event


## Evento de inversion: pierdes ahora, ganas despues
static func _investment() -> TurnEvent:
	var event := TurnEvent.new()
	event.id = "investment_opportunity"
	event.title = "Oportunidad de inversion"
	event.description = "[i]Un comerciante te ofrece financiar una ruta arriesgada.[/i]"
	event.weight = 1.0

	# Opcion 1: invertir - pierdes 20 oro ahora pero +40% de oro durante 4 turnos
	var invest_choice := TurnEventChoice.new()
	invest_choice.label = "Invertir 20 oro"
	invest_choice.description = "Pagas 20 oro ahora. A cambio, tu produccion de oro aumenta un 40% durante 4 turnos."

	var cost := TurnEventCost.new()
	cost.gold = 20
	invest_choice.cost = cost

	var bonus := StatModifier.new(
		"investment_bonus",
		"Ruta comercial",
		StatModifier.StatType.PERCENT_GOLD,
		40.0,
		4
	)
	invest_choice.effects = [ApplyModifierEffect.new(bonus)]
	event.choices = [invest_choice]

	return event


## Evento que requiere eliminar una carta para recibir oro
static func _trade_route_discovery() -> TurnEvent:
	var event := TurnEvent.new()
	event.id = "trade_route"
	event.title = "Ruta comercial descubierta"
	event.description = "[i]Tus exploradores han encontrado una nueva ruta, pero necesitan sacrificar provisiones.[/i]"
	event.weight = 1.0

	# Eliminar automaticamente una carta de colonizar a cambio de 50 oro
	var remove_colonize_choice := TurnEventChoice.new()
	remove_colonize_choice.label = "Sacrificar una carta de Colonizar por 50 oro"
	remove_colonize_choice.description = "Elimina una carta de Colonizar de tu mazo y recibe 50 oro."
	var cost := TurnEventCost.new()
	var auto_filter := CardRemovalFilter.new()
	auto_filter.card_id = "colonize"
	cost.auto_remove_filter = auto_filter
	remove_colonize_choice.cost = cost
	remove_colonize_choice.effects = [GoldEventEffect.new(50)]

	event.choices = [remove_colonize_choice]
	return event


## Evento UNICO: para probar el titulo dorado
## Condicion: tener al menos 100 de oro
static func _golden_age() -> TurnEvent:
	var event := TurnEvent.new()
	event.id = "golden_age"
	event.title = "Edad Dorada"
	event.description = "[i]Tu prosperidad atrae a artesanos y mercaderes de tierras lejanas. Una nueva era comienza.[/i]"
	event.weight = 5.0
	event.unique = true
	event.allow_skip = false

	event.conditions = [
		GoldThresholdCondition.new(100, Comparison.Type.GREATER_EQUAL)
	]

	# Gran bonificacion: +20% oro permanente
	var bonus := StatModifier.new(
		"golden_age_bonus",
		"Edad Dorada",
		StatModifier.StatType.PERCENT_GOLD,
		20.0,
		-1  # -1 = permanente
	)
	var choice := TurnEventChoice.new()
	choice.label = "Abrazar la prosperidad"
	choice.description = "+20% a la produccion de oro de forma permanente."
	choice.effects = [ApplyModifierEffect.new(bonus)]
	event.choices = [choice]

	return event
