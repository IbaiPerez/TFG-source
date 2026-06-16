extends GutTest

## Test suite for interaction.gd input blocking
## Verifies that mouse clicks are blocked when menus are open


class MockInteractionTracker:
	extends Node
	## Mock of interaction.gd's _unhandled_input behavior

	var clicks_processed: int = 0

	func _unhandled_input(event: InputEvent) -> void:
		# Replicate interaction.gd blocking logic
		if UIState and UIState.is_any_menu_open():
			return

		if event is InputEventMouseButton:
			if Input.is_action_just_pressed("Click") and event.pressed:
				clicks_processed += 1


var tracker: MockInteractionTracker


# ============================================================================
# TESTS: Input Processing Without Menus
# ============================================================================

func test_click_is_processed_when_no_menus_open():
	# Arrange: No menus, tracker ready
	var click_event = InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true

	# Act: Simulate click input
	Input.action_press("Click")
	tracker._unhandled_input(click_event)
	Input.action_release("Click")

	# Assert: Click should be processed (counter incremented)
	assert_eq(tracker.clicks_processed, 1, "Click should be processed without menus")


func test_multiple_clicks_processed_without_menus():
	# Arrange: No menus
	var click_event = InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true

	# Act: Simulate multiple clicks
	for i in range(5):
		Input.action_press("Click")
		tracker._unhandled_input(click_event)
		Input.action_release("Click")

	# Assert: All clicks should be processed
	assert_eq(tracker.clicks_processed, 5, "All clicks should be processed without menus")


# ============================================================================
# TESTS: Input Blocking With Menus
# ============================================================================

func test_click_is_blocked_when_one_menu_open():
	# Arrange: One menu open
	UIState.register_menu()
	var click_event = InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true

	# Act: Simulate click input
	Input.action_press("Click")
	tracker._unhandled_input(click_event)
	Input.action_release("Click")

	# Assert: Click should be blocked (counter not incremented)
	assert_eq(tracker.clicks_processed, 0, "Click should be blocked with menu open")


func test_click_is_blocked_with_multiple_menus_open():
	# Arrange: Three menus open
	UIState.register_menu()
	UIState.register_menu()
	UIState.register_menu()
	var click_event = InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true

	# Act: Simulate click input
	Input.action_press("Click")
	tracker._unhandled_input(click_event)
	Input.action_release("Click")

	# Assert: Click should be blocked
	assert_eq(tracker.clicks_processed, 0, "Click should be blocked with multiple menus")


func test_multiple_clicks_blocked_consistently():
	# Arrange: One menu open
	UIState.register_menu()
	var click_event = InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true

	# Act: Simulate multiple clicks
	for i in range(5):
		Input.action_press("Click")
		tracker._unhandled_input(click_event)
		Input.action_release("Click")

	# Assert: All clicks should be blocked
	assert_eq(tracker.clicks_processed, 0, "All clicks should be blocked with menu open")


# ============================================================================
# TESTS: Unblocking When Menus Close
# ============================================================================

func test_click_is_unblocked_when_last_menu_closes():
	# Arrange: Two menus open
	UIState.register_menu()
	UIState.register_menu()
	var click_event = InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true

	# Act: Close both menus
	UIState.unregister_menu()
	UIState.unregister_menu()

	# Simulate click
	Input.action_press("Click")
	tracker._unhandled_input(click_event)
	Input.action_release("Click")

	# Assert: Click should be processed after all menus close
	assert_eq(tracker.clicks_processed, 1, "Click should be processed after closing all menus")


func test_click_remains_blocked_when_menu_still_open():
	# Arrange: Two menus open
	UIState.register_menu()
	UIState.register_menu()
	var click_event = InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true

	# Act: Close only one menu
	UIState.unregister_menu()

	# Simulate click
	Input.action_press("Click")
	tracker._unhandled_input(click_event)
	Input.action_release("Click")

	# Assert: Click should still be blocked (one menu remaining)
	assert_eq(tracker.clicks_processed, 0, "Click should remain blocked while menus are still open")


# ============================================================================
# TESTS: Complex Menu Scenarios
# ============================================================================

func test_blocking_works_with_opening_closing_cycles():
	# Arrange
	var click_event = InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true

	# Act & Assert: Multiple open/close cycles
	for cycle in range(3):
		# Open menu - click should be blocked
		UIState.register_menu()
		Input.action_press("Click")
		tracker._unhandled_input(click_event)
		Input.action_release("Click")
		assert_eq(tracker.clicks_processed, cycle, "Click should be blocked during cycle %d open" % cycle)

		# Close menu - click should be processed
		UIState.unregister_menu()
		Input.action_press("Click")
		tracker._unhandled_input(click_event)
		Input.action_release("Click")
		assert_eq(tracker.clicks_processed, cycle + 1, "Click should be processed during cycle %d close" % cycle)


# ============================================================================
# SETUP / TEARDOWN
# ============================================================================

func before_each():
	## Called before each test
	tracker = MockInteractionTracker.new()
	add_child_autofree(tracker)

	# Reset del estado global de Input. `Input.action_press` NO refresca el flag
	# "just_pressed" si la acción ya estaba pulsada, así que cualquier "Click"
	# colgado (de otro contexto, p.ej. el editor) haría que el primer click del
	# test no se contara. Liberarlo garantiza un punto de partida determinista.
	Input.action_release("Click")

	# Clean UIState
	while UIState._menu_count > 0:
		UIState.unregister_menu()


func after_each():
	## Called after each test
	# Clean UIState
	while UIState._menu_count > 0:
		UIState.unregister_menu()
