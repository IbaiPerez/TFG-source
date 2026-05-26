extends GutTest

## Regresión: el InteractionTracker debe usar `_unhandled_input` y NO `_input`.
##
## Si vuelve a usar `_input`, los clicks sobre la UI (botón de demoler en el
## TilePanel, cartas en la mano, popups, etc.) son interceptados por el
## raycast 3D antes de que la UI pueda procesarlos. Eso provoca, entre otras
## cosas, que el botón rojo de demoler "no haga nada": el raycast atraviesa
## la UI, golpea la tile detrás del panel y dispara `tile_selected`, que
## reconstruye el TilePanel y mata el botón que se acababa de pulsar.

const INTERACTION_SCRIPT := preload("res://scripts/map/interaction.gd")


func test_uses_unhandled_input_callback() -> void:
	# `has_method` solo devuelve true si el script define el método (los
	# virtuales por defecto de Node no cuentan), así que sirve como guardia
	# contra que alguien lo renombre o lo revierta a `_input`.
	var tracker:Node = INTERACTION_SCRIPT.new()
	autofree(tracker)

	assert_true(tracker.has_method("_unhandled_input"),
		"InteractionTracker debe procesar input via _unhandled_input para "
		+ "respetar el consumo de eventos por la UI.")
	assert_false(tracker.has_method("_input"),
		"InteractionTracker NO debe usar _input: robaría clicks a la UI "
		+ "(p.ej. el botón rojo de demoler edificios del TilePanel).")
