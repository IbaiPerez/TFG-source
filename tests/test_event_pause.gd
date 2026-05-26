extends GutTest

## Tests para la pausa del árbol durante menús de evento.
##
## El SceneManager (autoload) pausa get_tree() cuando se dispara un evento
## de turno y lo despausa cuando el panel emite turn_event_resolved o
## shop_event_resolved. Mientras tanto los nodos relacionados con la
## resolución del evento llevan PROCESS_MODE_ALWAYS para seguir
## funcionando.

const TURN_EVENT_PANEL = preload("res://scenes/UI/turn_events/turn_event_panel.tscn")
const EVENT_CARD_SELECTION_PANEL = preload("res://scenes/UI/turn_events/event_card_selection_panel.tscn")
const SHOP_PANEL = preload("res://scenes/UI/shop/shop_panel.tscn")
const INTERACTION_SCRIPT = preload("res://scripts/map/interaction.gd")


# --- Process modes de las scenes de evento ---------------------------------

func test_turn_event_panel_process_mode_is_always() -> void:
	var panel:Node = TURN_EVENT_PANEL.instantiate()
	autofree(panel)
	assert_eq(panel.process_mode, Node.PROCESS_MODE_ALWAYS,
		"TurnEventPanel debe ser ALWAYS para seguir respondiendo a clicks "
		+ "mientras el árbol está pausado por un evento.")


func test_event_card_selection_panel_process_mode_is_always() -> void:
	var panel:Node = EVENT_CARD_SELECTION_PANEL.instantiate()
	autofree(panel)
	assert_eq(panel.process_mode, Node.PROCESS_MODE_ALWAYS,
		"EventCardSelectionPanel debe ser ALWAYS para que el jugador pueda "
		+ "elegir una carta mientras el árbol está pausado.")


func test_shop_panel_process_mode_is_always() -> void:
	var panel:Node = SHOP_PANEL.instantiate()
	autofree(panel)
	assert_eq(panel.process_mode, Node.PROCESS_MODE_ALWAYS,
		"ShopPanel debe ser ALWAYS para seguir aceptando compras durante la pausa.")


# --- Unpause via señales ----------------------------------------------------

func test_turn_event_resolved_unpauses_tree() -> void:
	# Simulamos que estamos en mitad de un evento (árbol pausado).
	get_tree().paused = true

	Events.turn_event_resolved.emit()

	assert_false(get_tree().paused,
		"Al resolver el evento de turno el SceneManager debe despausar el árbol.")

	# Defensivo: aseguramos que sale despausado aunque el test falle.
	get_tree().paused = false


func test_shop_event_resolved_unpauses_tree() -> void:
	get_tree().paused = true

	Events.shop_event_resolved.emit()

	assert_false(get_tree().paused,
		"Al cerrar el shop el SceneManager debe despausar el árbol.")

	get_tree().paused = false


# --- InteractionTracker durante pausa --------------------------------------

func test_interaction_tracker_uses_unhandled_input() -> void:
	# Esto ya se cubre en test_interaction_tracker.gd pero lo repetimos aquí
	# como recordatorio: si interaction.gd vuelve a `_input`, los clicks
	# sobre el TurnEventPanel se procesarían como clicks de mundo y romperían
	# el flujo de eventos exactamente igual que rompían el botón de demoler.
	var tracker:Node = INTERACTION_SCRIPT.new()
	autofree(tracker)
	assert_true(tracker.has_method("_unhandled_input"),
		"InteractionTracker debe usar _unhandled_input para que los clicks "
		+ "consumidos por el TurnEventPanel (PROCESS_MODE_ALWAYS) no se "
		+ "reinterpreten como clicks en el mundo.")
