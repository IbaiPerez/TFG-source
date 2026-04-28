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

var conditions:Array[TurnEventCondition] = []


func is_available(context:EventContext) -> bool:
	return conditions.all(func(c): return c.is_met(context))


## Llamado antes de mostrar el evento al jugador.
## Sobrescribir en subclases que necesiten configurar choices dinámicamente.
func prepare(_context:EventContext) -> void:
	pass
