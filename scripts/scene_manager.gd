extends Node

const MAP = preload("uid://dxw5gc7xqbkqj")
const BUILDING_PANEL = preload("uid://d4kc0x1wj7vrm")
const TURN_EVENT_PANEL = preload("uid://dt9hturneventpnl")
const SHOP_PANEL = preload("res://scenes/UI/shop/shop_panel.tscn")
const RECOVER_CARD_PANEL = preload("res://scenes/UI/card/recover_card_panel.tscn")
const MAIN_MENU = preload("res://scenes/UI/menus/main_menu.tscn")
const EMPIRE_SELECTION = preload("res://scenes/UI/menus/empire_selection.tscn")
const GENERATION_UI = preload("res://scenes/UI/generation_ui.tscn")

func _ready() -> void:
	Events.generate_world.connect(_on_events_generate_world)
	Events.navigate_to_empire_selection.connect(_on_navigate_to_empire_selection)
	Events.navigate_to_generation.connect(_on_navigate_to_generation)
	Events.navigate_to_main_menu.connect(_on_navigate_to_main_menu)
	Events.build_card_confirm_started.connect(_on_build_card_confirm_started)
	Events.upgrade_building_card_confirm_started.connect(_on_upgrade_building_card_confirm_started)
	Events.recover_card_confirm_started.connect(_on_recover_card_confirm_started)
	Events.turn_event_triggered.connect(_on_turn_event_triggered)


func _change_scene(new_scene: Node) -> void:
	var scene_to_remove = get_tree().current_scene
	get_tree().root.add_child(new_scene)
	get_tree().current_scene = new_scene
	if scene_to_remove:
		scene_to_remove.queue_free()


func _on_navigate_to_main_menu() -> void:
	var new_scene = MAIN_MENU.instantiate()
	_change_scene(new_scene)


func _on_navigate_to_empire_selection() -> void:
	var new_scene = EMPIRE_SELECTION.instantiate()
	_change_scene(new_scene)


func _on_navigate_to_generation(empire: Empire) -> void:
	var new_scene = GENERATION_UI.instantiate()
	new_scene.selected_empire = empire
	_change_scene(new_scene)


func _on_events_generate_world(settings: GenerationSettings, stats: Stats) -> void:
	var new_scene = MAP.instantiate()

	var world_generator = new_scene.get_node("%WorldGenerator")
	world_generator.settings = settings
	new_scene.stats = stats
	new_scene.generation_settings = settings

	_change_scene(new_scene)

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

func _on_recover_card_confirm_started(card:RecoverCard, stats:Stats) -> void:
	card.menu = RECOVER_CARD_PANEL.instantiate()
	card.menu.card_pile = stats.played_pile
	get_tree().get_first_node_in_group("ui_layer").add_child(card.menu)

func _on_turn_event_triggered(event:TurnEvent, context:EventContext) -> void:
	var ui_layer := get_tree().get_first_node_in_group("ui_layer")
	var player_handler:PlayerHandler = get_tree().get_first_node_in_group("player_handler")

	if event is ShopEvent:
		var shop_event := event as ShopEvent
		var shop_panel:ShopPanel = SHOP_PANEL.instantiate()
		ui_layer.add_child(shop_panel)
		var config := shop_event.generate_shop(context.stats)
		shop_panel.setup(config, context.stats, event.title, event.description)
		# Marcar evento unico si aplica
		if event.unique:
			player_handler.turn_event_manager.stats.used_unique_events.append(event.id)
	else:
		var panel:TurnEventPanel = TURN_EVENT_PANEL.instantiate()
		ui_layer.add_child(panel)
		panel.setup(event, context, player_handler.turn_event_manager)
