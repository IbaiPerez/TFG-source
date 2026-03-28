extends Resource
class_name Card

enum Type {BASIC, SPECIAL, SINGLE_USE}
enum Target {TILE,SELF,BATTLE_FRONT}

@export_group("Card Attributes")
@export var id:String
@export var type:Type
@export var target:Target

@export_group("Card Visual")
@export var icon:Texture
@export_multiline var tooltipe_text:String

func is_tile_targeted() -> bool:
	return target == Target.TILE

func is_batle_front_targeted() -> bool:
	return target == Target.BATTLE_FRONT

func is_single_use() -> bool:
	return type == Type.SINGLE_USE

func play(targets:Array[Node], stats:Stats) -> void:
	Events.card_played.emit(self)
	apply_effects(targets,stats)

func apply_effects(_targets:Array[Node],_stats:Stats) -> void:
	pass

func get_valid_targets(_stats:Stats) -> Array[Node]:
	return []

func is_valid_target(_node:Node,_stats:Stats) -> bool:
	return false
