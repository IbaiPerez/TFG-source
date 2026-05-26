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
