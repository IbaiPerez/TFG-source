extends GutTest

## Comprueba que todos los scripts tocados por la localización compilan
## (con autoloads disponibles, a diferencia del modo --script suelto).

func test_localized_scripts_compile() -> void:
	var scripts := [
		"res://scripts/i18n.gd",
		"res://scripts/ui/menus/language_selector.gd",
		"res://scripts/ui/menus/tutorial_panel.gd",
		"res://scripts/ui/menus/save_load_panel.gd",
		"res://scripts/ui/menus/main_menu.gd",
		"res://scripts/ui/menus/options_menu.gd",
		"res://scripts/ui/menus/fullscreen_toggle.gd",
		"res://scripts/ui/military/battle_front_panel.gd",
		"res://scripts/ui/military/assign_troops_panel.gd",
		"res://scripts/ui/military/troop_slot.gd",
		"res://scripts/ui/military/troop_menu_ui.gd",
		"res://scripts/ui/military/recruit_panel.gd",
		"res://scripts/ui/military/open_front_panel.gd",
		"res://scripts/ui/military/troop_pool_view.gd",
		"res://scripts/ui/tiles/tile_panel.gd",
		"res://scripts/ui/shop/shop_panel.gd",
		"res://scripts/ui/stats_ui.gd",
		"res://scripts/ui/rival_stats_ui.gd",
		"res://scripts/ui/general_ui.gd",
		"res://scripts/ui/ai_action_log.gd",
		"res://scripts/ui/loading_screen.gd",
		"res://scripts/ui/modifiers/modifier_icon.gd",
		"res://scripts/ui/buildings/building_card.gd",
		"res://scripts/ui/cards/card_pile_view.gd",
		"res://scripts/ui/cards/card_tooltip_popup.gd",
		"res://scripts/ui/cards/recover_card_panel.gd",
		"res://scripts/ui/turn_events/event_card_selection_panel.gd",
		"res://scripts/military/troop.gd",
		"res://scripts/cards_resources/build_card.gd",
		"res://scripts/cards_resources/colonize_card.gd",
		"res://scripts/cards_resources/direct_build_card.gd",
		"res://scripts/cards_resources/upgrade_building_card.gd",
		"res://scripts/cards_resources/generate_gold_card.gd",
		"res://scripts/cards_resources/recruit_card.gd",
		"res://scripts/cards_resources/tactic_card.gd",
		"res://scripts/cards_resources/open_front_card.gd",
		"res://scripts/cards_resources/recover_card.gd",
		"res://scripts/cards_resources/change_location_type_card.gd",
		"res://scripts/cards_resources/card_draw_card.gd",
	]
	for p: String in scripts:
		assert_not_null(load(p), "Debe compilar: " + p)
