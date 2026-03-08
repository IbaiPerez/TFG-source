extends Resource
class_name Card

enum Type {BASIC, SPECIAL, SINGLE_USE}
enum Target {TILE,SELF,BATTLE_FRONT}

@export_group("Card Attributes")
@export var id:String
@export var type:Type
@export var target:Target

func is_tile_targeted() -> bool:
	return target == Target.TILE

func is_batle_front_targeted() -> bool:
	return target == Target.BATTLE_FRONT

func is_single_use() -> bool:
	return type == Type.SINGLE_USE
