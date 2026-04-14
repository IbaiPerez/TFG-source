extends RefCounted
class_name Modifier

var id:String
var name:String
var description:String
var icon:Texture2D
var duration:int  ## turnos restantes, -1 = permanente
var stats:Stats  ## referencia a las stats del jugador propietario


func _init(p_id:String = "", p_name:String = "", p_duration:int = -1, p_icon:Texture2D = null):
	id = p_id
	name = p_name
	duration = p_duration
	icon = p_icon


## Se llama al añadir el modificador al manager
func activate(p_stats:Stats) -> void:
	stats = p_stats


## Se llama al eliminar el modificador del manager
func deactivate() -> void:
	stats = null


## Se llama al inicio de cada turno para resetear contadores internos
func on_turn_start() -> void:
	pass


func duplicate_modifier() -> Modifier:
	return null
