extends Resource
class_name Card

enum Type {BASIC, SPECIAL, SINGLE_USE}
enum Target {TILE,SELF,BATTLE_FRONT}

@export_group("Card Attributes")
## Identificador INTERNO. No se muestra al jugador: es texto sin traducir y sin
## tildes ("Build Escuela de Planificacion"). Para enseñar el nombre en pantalla
## está `name_key`.
@export var id:String
## Clave i18n del nombre visible. Es un campo explícito y no una clave derivada
## del `id` a propósito: construirlas por concatenación se rompe en silencio al
## renombrar, que es justo lo que vigila `test_i18n_keys`.
@export var name_key:String
@export var type:Type
@export var target:Target
@export var needs_confirmation:bool

@export_group("Card Visual")
@export var icon:Texture
@export_multiline var tooltipe_text:String

func is_tile_targeted() -> bool:
	return target == Target.TILE

func is_batle_front_targeted() -> bool:
	return target == Target.BATTLE_FRONT

func is_single_use() -> bool:
	return type == Type.SINGLE_USE


## Nombre para mostrar al jugador, ya traducido. Si la carta no declara
## `name_key` cae al `id`, que es feo pero legible — mejor que una cadena vacía
## en pantalla. `test_card_names` vigila que ninguna carta del juego llegue ahí.
func get_display_name() -> String:
	return tr(name_key) if not name_key.is_empty() else id


## Devuelve el tooltip de la carta. Si tooltipe_text está vacío, genera uno automático.
func get_tooltip() -> String:
	if tooltipe_text.is_empty():
		tooltipe_text = _build_tooltip()
	return tooltipe_text


## Sobrescribir en subclases para generar el tooltip automáticamente.
func _build_tooltip() -> String:
	return ""

func play(targets:Array[Node], stats:Stats) -> void:
	Events.card_played.emit(self, stats)
	apply_effects(targets,stats)

func apply_effects(_targets:Array[Node],_stats:Stats) -> void:
	pass

func get_valid_targets(_stats:Stats) -> Array[Node]:
	return []

func is_valid_target(_node:Node,_stats:Stats) -> bool:
	return false
