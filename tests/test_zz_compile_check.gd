extends GutTest

## Comprueba que los scripts tocados por la localización compilan (con autoloads
## disponibles, a diferencia del modo --script suelto).
##
## La cobertura EXHAUSTIVA de scripts/ la da test_zz_all_scripts_compile; esta
## lista se conserva porque documenta cuáles son los ficheros de la localización,
## e incluye algunos que no viven bajo scripts/ui.
##
## OJO: la comprobación NO puede ser `assert_not_null(load(p))`. `load()` de un
## script con un parse error devuelve un GDScript a medio compilar, no null, así
## que esa aserción no falla nunca — es lo que hacía este fichero hasta ahora, y
## por eso no habría cazado una rotura en ninguno de los 43. Lo que discrimina es
## `can_instantiate()`.

func test_localized_scripts_compile() -> void:
	var scripts := [
		"res://scripts/i18n.gd",
		"res://scripts/ui/menus/language_selector.gd",
		"res://scripts/ui/menus/tutorial_panel.gd",
		"res://scripts/ui/menus/tutorial/tutorial_content.gd",
		"res://scripts/ui/menus/tutorial/tutorial_balance_entries.gd",
		"res://scripts/ui/menus/tutorial/tutorial_text.gd",
		"res://scripts/ui/menus/tutorial/tutorial_entry.gd",
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
		var script := load(p) as GDScript
		assert_true(script != null and script.can_instantiate(), "Debe compilar: " + p)
