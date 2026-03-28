extends BuildingEffect
class_name GoldOnCard

@export var required_card:Card
@export var gold_reward:int = 10

var assigned_stats:Stats

func apply_effect(_tile: Tile, stats: Stats) -> void:
	assigned_stats = stats
	Events.card_played.connect(_on_card_played)

func remove_effect(_tile: Tile, _stats: Stats) -> void:
	Events.card_played.disconnect(_on_card_played)
	assigned_stats = null

func _on_card_played(card:Card):
	if card.id == required_card.id:
		assigned_stats.total_gold += gold_reward
