extends Effect
class_name DrawCardEffect

var cards_to_draw := 1

func execute(targets: Array[Node]) -> void:
	if targets.is_empty():
		return
	
	var player_handler := targets[0].get_tree().get_first_node_in_group("player_handler")
	
	if not player_handler:
		return
	
	player_handler.draw_cards(cards_to_draw)
	
