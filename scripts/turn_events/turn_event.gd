extends Resource
class_name TurnEvent

@export var id:String
@export var title:String
@export_multiline var description:String
@export var icon:Texture2D
@export var allow_skip:bool = true
@export var weight:float = 1.0
@export var unique:bool = false
@export var choices:Array[TurnEventChoice] = []

## Categoría a la que pertenece el evento. La asigna cada subclase en
## su _init(). Determina la pool en la que compite el evento dentro del
## TurnEventManager (ver EventCategoryWeights).
@export var category:EventCategory.Type = EventCategory.Type.FLAVOUR

var conditions:Array[TurnEventCondition] = []


func is_available(context:EventContext) -> bool:
	return conditions.all(func(c): return c.is_met(context))


## Llamado antes de mostrar el evento al jugador.
## Sobrescribir en subclases que necesiten configurar choices dinámicamente.
func prepare(_context:EventContext) -> void:
	pass


## Fábrica del choice típico de un evento de desbloqueo de carta: añade la carta a
## la mano (AddCardEffect) y al pool con su curva de peso (AddToCardPoolEffect),
## más `extra_effects` opcionales (p.ej. UnlockBuildingEffect). Traduce las claves
## i18n con tr() al construir, igual que hacían los _init() de cada evento. Reúne
## en un solo sitio el bloque que se repetía en ~14 clases unlock_*.
## Choice de desbloqueo de EDIFICIO: el imperio pasa a poder construirlo.
## Hermana de `make_card_unlock_choice`, para la otra familia de eventos unlock —
## los que amplían `possible_buildings` en vez de dar una carta. Las cinco que
## seguían montando el TurnEventChoice a mano eran idénticas salvo el edificio y las
## dos claves i18n.
func make_building_unlock_choice(building:Building, label_key:String,
		desc_key:String) -> TurnEventChoice:
	var choice := TurnEventChoice.new()
	choice.label = tr(label_key)
	choice.description = tr(desc_key)
	choice.effects = [UnlockBuildingEffect.new(building)] as Array[TurnEventEffect]
	return choice


func make_card_unlock_choice(card:Card, label_key:String, desc_key:String,
		pool_base:float, pool_per_turn:float, pool_min:float,
		extra_effects:Array = []) -> TurnEventChoice:
	var choice := TurnEventChoice.new()
	choice.label = tr(label_key)
	choice.description = tr(desc_key)
	var effects:Array[TurnEventEffect] = [
		AddCardEffect.new(card),
		AddToCardPoolEffect.new(card, pool_base, pool_per_turn, pool_min),
	]
	for e in extra_effects:
		effects.append(e as TurnEventEffect)
	choice.effects = effects
	return choice
