extends Control
class_name CardUI

signal reparent_requested(card_ui:CardUI)

@export var card:Card:set = _set_card
@export var stats:Stats

@onready var panel: Panel = $Panel
@onready var icon: TextureRect = $Icon
@onready var drop_point_detector: Area2D = $DropPointDetector
@onready var card_state_machine: CardStateMachine = $CardStateMachine as CardStateMachine
@onready var targets: Array[Node] = []

var parent:Control
var tween:Tween

func _ready() -> void:
	card_state_machine.init(self)

func _input(event:InputEvent) -> void:
	card_state_machine.on_input(event)

func animate_to_position(new_position:Vector2, duration:float) -> void:
	tween = create_tween().set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", new_position, duration)

func play() -> void:
	if not card:
		return
	
	card.play(targets,stats)
	queue_free()

func _on_gui_input(event:InputEvent) -> void:
	card_state_machine.on_gui_input(event)

func _on_mouse_entered() -> void:
	card_state_machine.on_mouse_entered()

func _on_mouse_exited() -> void:
	card_state_machine.on_mouse_exited()

func _set_card(value:Card) -> void:
	if not is_node_ready():
		await ready
	
	card = value
	icon.texture = card.icon

func _on_drop_point_detector_area_entered(area: Area2D) -> void:
	if not targets.has(area):
		targets.append(area)


func _on_drop_point_detector_area_exited(area: Area2D) -> void:
	targets.erase(area)
