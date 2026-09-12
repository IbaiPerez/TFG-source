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


## Choice con etiqueta y descripción traducidas, sus efectos y un coste opcional.
## Es el bloque que todos los eventos montaban a mano en su _init().
func make_choice(label_key:String, desc_key:String, effects:Array,
		cost:TurnEventCost = null) -> TurnEventChoice:
	var choice := TurnEventChoice.new()
	choice.label = tr(label_key)
	choice.description = tr(desc_key)
	choice.effects.assign(effects)
	choice.cost = cost
	return choice


## Choice de desbloqueo de EDIFICIO: el imperio pasa a poder construirlo.
func make_building_unlock_choice(building:Building, label_key:String,
		desc_key:String) -> TurnEventChoice:
	return make_choice(label_key, desc_key, [UnlockBuildingEffect.new(building)])


## Choice de desbloqueo de CARTA: la añade a la mano (AddCardEffect) y al pool con
## su curva de peso (AddToCardPoolEffect), más `extra_effects` opcionales
## (p.ej. UnlockBuildingEffect).
func make_card_unlock_choice(card:Card, label_key:String, desc_key:String,
		pool_base:float, pool_per_turn:float, pool_min:float,
		extra_effects:Array = []) -> TurnEventChoice:
	var effects := [AddCardEffect.new(card),
		AddToCardPoolEffect.new(card, pool_base, pool_per_turn, pool_min)]
	effects.append_array(extra_effects)
	return make_choice(label_key, desc_key, effects)
