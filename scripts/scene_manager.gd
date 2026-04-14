extends Node

const MAP = preload("uid://dxw5gc7xqbkqj")
const BUILDING_PANEL = preload("uid://d4kc0x1wj7vrm")
const TURN_EVENT_PANEL = preload("uid://dt9hturneventpnl")

func _ready() -> void:
	Events.generate_world.connect(_on_events_generate_world)
	Events.build_card_confirm_started.connect(_on_build_card_confirm_started)
	Events.upgrade_building_card_confirm_started.connect(_on_upgrade_building_card_confirm_started)
	Events.turn_event_triggered.connect(_on_turn_event_triggered)


func _on_events_generate_world(settings):
	var new_scene = MAP.instantiate()
	
	var world_generator = new_scene.get_node("%WorldGenerator")
	world_generator.settings = settings
	
	var scene_to_remove = get_tree().current_scene
	get_tree().root.add_child(new_scene) # Aquí se ejecuta el _ready()
	get_tree().current_scene = new_scene
	scene_to_remove.queue_free()

func _on_build_card_confirm_started(card:BuildCard,targets:Array[Node],stats:Stats):
	card.menu = BUILDING_PANEL.instantiate()
	for t in targets:
		card.menu.tile = t
		card.menu.stats = stats
		card.menu.action = card.menu.possible_action.BUILD
		card.menu.buildings = card.buildings
	get_tree().get_first_node_in_group("ui_layer").add_child(card.menu)

func _on_upgrade_building_card_confirm_started(card:UpgradeBuildingCard,targets:Array[Node],stats:Stats):
	card.menu = BUILDING_PANEL.instantiate()
	for t in targets:
		card.menu.tile = t
		card.menu.stats = stats
		card.menu.action = card.menu.possible_action.SHOW
		card.menu.buildings = []
		card.menu.building_to_upgrade_selected.connect(
			func(building): card.old_building = building
			)
	get_tree().get_first_node_in_group("ui_layer").add_child(card.menu)

func _on_turn_event_triggered(event:TurnEvent, context:EventContext) -> void:
	var panel:TurnEventPanel = TURN_EVENT_PANEL.instantiate()
	get_tree().get_first_node_in_group("ui_layer").add_child(panel)

	var player_handler:PlayerHandler = get_tree().get_first_node_in_group("player_handler")
	panel.setup(event, context, player_handler.turn_event_manager)
