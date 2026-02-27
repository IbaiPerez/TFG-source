extends Node

const MAP = preload("uid://dxw5gc7xqbkqj")

func _ready() -> void:
	Events.generate_world.connect(_on_events_generate_world)


func _on_events_generate_world(settings):
	var new_scene = MAP.instantiate()
	
	var world_generator = new_scene.get_node("%WorldGenerator")
	world_generator.settings = settings
	
	var scene_to_remove = get_tree().current_scene
	get_tree().root.add_child(new_scene) # Aquí se ejecuta el _ready()
	get_tree().current_scene = new_scene
	scene_to_remove.queue_free()
