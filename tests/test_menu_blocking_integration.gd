extends GutTest

## Integration test suite for menu blocking system
## Verifies complete end-to-end blocking workflow: open menu → block input → close menu → unblock


class IntegrationTestPanel:
	extends PanelContainer
	## Simulates real menu panel behavior

	var is_open := false

	func _ready() -> void:
		is_open = true
		if UIState:
			UIState.register_menu()

	func _exit_tree() -> void:
		if is_open and UIState:
			UIState.unregister_menu()
		is_open = false


class IntegrationTestInput:
	extends Node
	## Simulates both interaction.gd and camera_3d.gd input processing

	var clicks_processed: int = 0
	var scrolls_processed: int = 0

	func _unhandled_input(event: InputEvent) -> void:
		# Replicate interaction.gd blocking
		if UIState and UIState.is_any_menu_open():
			return
		if event is InputEventMouseButton:
			if Input.is_action_just_pressed("Click") and event.pressed:
				clicks_processed += 1

	func _input(event: InputEvent) -> void:
		# Replicate camera_3d.gd blocking
		if UIState and UIState.is_any_menu_open():
			return
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				scrolls_processed += 1


var input_simulator: IntegrationTestInput


# ============================================================================
# TESTS: Complete Menu Lifecycle
# ============================================================================

func test_complete_menu_open_block_close_unblock_flow():
	# Arrange: Initial state - no menus, input not blocked
	assert_false(UIState.is_any_menu_open(), "Setup: no menus open")
	var click_event = InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true

	# Act 1: Simulate click without menus
	Input.action_press("Click")
	input_simulator._unhandled_input(click_event)
	Input.action_release("Click")
	# Assert 1: Click should be processed
	assert_eq(input_simulator.clicks_processed, 1, "Step 1: click processed without menus")

	# Act 2: Open a menu
	var menu1 = IntegrationTestPanel.new()
	add_child_autofree(menu1)
	# Assert 2: Menu should be registered
	assert_true(UIState.is_any_menu_open(), "Step 2: menu is open")
	assert_eq(UIState._menu_count, 1, "Step 2: counter is 1")

	# Act 3: Try to click with menu open
	Input.action_press("Click")
	input_simulator._unhandled_input(click_event)
	Input.action_release("Click")
	# Assert 3: Click should be blocked
	assert_eq(input_simulator.clicks_processed, 1, "Step 3: click blocked with menu open")

	# Act 4: Open second menu
	var menu2 = IntegrationTestPanel.new()
	add_child_autofree(menu2)
	# Assert 4: Both menus should be registered
	assert_eq(UIState._menu_count, 2, "Step 4: two menus open")

	# Act 5: Try click with multiple menus
	Input.action_press("Click")
	input_simulator._unhandled_input(click_event)
	Input.action_release("Click")
	# Assert 5: Still blocked
	assert_eq(input_simulator.clicks_processed, 1, "Step 5: click blocked with multiple menus")

	# Act 6: Close first menu
	menu1.queue_free()
	await get_tree().process_frame
	# Assert 6: One menu still open, input blocked
	assert_eq(UIState._menu_count, 1, "Step 6: one menu remains")
	Input.action_press("Click")
	input_simulator._unhandled_input(click_event)
	Input.action_release("Click")
	assert_eq(input_simulator.clicks_processed, 1, "Step 6: input still blocked")

	# Act 7: Close last menu
	menu2.queue_free()
	await get_tree().process_frame
	# Assert 7: All menus closed, input unblocked
	assert_false(UIState.is_any_menu_open(), "Step 7: all menus closed")
	Input.action_press("Click")
	input_simulator._unhandled_input(click_event)
	Input.action_release("Click")
	assert_eq(input_simulator.clicks_processed, 2, "Step 7: click processed after all menus close")


# ============================================================================
# TESTS: Scroll Blocking Integration
# ============================================================================

func test_scroll_blocking_with_menu_lifecycle():
	# Arrange: Initial state
	assert_eq(input_simulator.scrolls_processed, 0, "Setup: no scrolls processed")
	var scroll_event = InputEventMouseButton.new()
	scroll_event.button_index = MOUSE_BUTTON_WHEEL_UP
	scroll_event.pressed = true

	# Act 1: Scroll without menus
	input_simulator._input(scroll_event)
	# Assert 1: Scroll processed
	assert_eq(input_simulator.scrolls_processed, 1, "Step 1: scroll processed without menus")

	# Act 2: Open menu and try to scroll
	var menu = IntegrationTestPanel.new()
	add_child_autofree(menu)

	input_simulator._input(scroll_event)
	# Assert 2: Scroll blocked
	assert_eq(input_simulator.scrolls_processed, 1, "Step 2: scroll blocked with menu")

	# Act 3: Close menu and scroll
	menu.queue_free()
	await get_tree().process_frame

	input_simulator._input(scroll_event)
	# Assert 3: Scroll processed
	assert_eq(input_simulator.scrolls_processed, 2, "Step 3: scroll processed after menu close")


# ============================================================================
# TESTS: Multiple Menu Open/Close Cycles
# ============================================================================

func test_blocking_works_across_multiple_cycles():
	# Arrange
	var click_event = InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true

	# Act & Assert: Three complete cycles
	for cycle in range(3):
		# Open menu
		var menu = IntegrationTestPanel.new()
		add_child_autofree(menu)

		# Try click - should be blocked
		Input.action_press("Click")
		input_simulator._unhandled_input(click_event)
		Input.action_release("Click")
		assert_eq(input_simulator.clicks_processed, cycle, "Cycle %d: click blocked" % cycle)

		# Close menu
		menu.queue_free()
		await get_tree().process_frame

		# Try click - should be processed
		Input.action_press("Click")
		input_simulator._unhandled_input(click_event)
		Input.action_release("Click")
		assert_eq(input_simulator.clicks_processed, cycle + 1, "Cycle %d: click processed" % cycle)


# ============================================================================
# TESTS: Complex Multi-Menu Scenarios
# ============================================================================

func test_partial_menu_closure_keeps_blocking():
	# Arrange: Three menus open
	var menus = []
	for i in range(3):
		var menu = IntegrationTestPanel.new()
		add_child_autofree(menu)
		menus.append(menu)

	assert_eq(UIState._menu_count, 3, "Setup: three menus open")

	var click_event = InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true

	# Act: Close first menu
	menus[0].queue_free()
	await get_tree().process_frame

	# Assert: Should still be blocked
	Input.action_press("Click")
	input_simulator._unhandled_input(click_event)
	Input.action_release("Click")
	assert_eq(input_simulator.clicks_processed, 0, "Should be blocked with remaining menus")

	# Act: Close second menu
	menus[1].queue_free()
	await get_tree().process_frame

	# Assert: Should still be blocked
	Input.action_press("Click")
	input_simulator._unhandled_input(click_event)
	Input.action_release("Click")
	assert_eq(input_simulator.clicks_processed, 0, "Should still be blocked")

	# Act: Close last menu
	menus[2].queue_free()
	await get_tree().process_frame

	# Assert: Now should be unblocked
	Input.action_press("Click")
	input_simulator._unhandled_input(click_event)
	Input.action_release("Click")
	assert_eq(input_simulator.clicks_processed, 1, "Should be unblocked when all menus closed")


func test_concurrent_input_blocking_both_click_and_scroll():
	# Arrange
	var click_event = InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	var scroll_event = InputEventMouseButton.new()
	scroll_event.button_index = MOUSE_BUTTON_WHEEL_UP
	scroll_event.pressed = true

	# Act 1: Process both inputs without menus
	Input.action_press("Click")
	input_simulator._unhandled_input(click_event)
	Input.action_release("Click")
	input_simulator._input(scroll_event)
	# Assert 1: Both processed
	assert_eq(input_simulator.clicks_processed, 1, "Click processed without menus")
	assert_eq(input_simulator.scrolls_processed, 1, "Scroll processed without menus")

	# Act 2: Open menu
	var menu = IntegrationTestPanel.new()
	add_child_autofree(menu)

	# Try both inputs
	Input.action_press("Click")
	input_simulator._unhandled_input(click_event)
	Input.action_release("Click")
	input_simulator._input(scroll_event)
	# Assert 2: Both blocked
	assert_eq(input_simulator.clicks_processed, 1, "Click blocked with menu")
	assert_eq(input_simulator.scrolls_processed, 1, "Scroll blocked with menu")

	# Act 3: Close menu
	menu.queue_free()
	await get_tree().process_frame

	# Try both inputs
	Input.action_press("Click")
	input_simulator._unhandled_input(click_event)
	Input.action_release("Click")
	input_simulator._input(scroll_event)
	# Assert 3: Both unblocked
	assert_eq(input_simulator.clicks_processed, 2, "Click unblocked")
	assert_eq(input_simulator.scrolls_processed, 2, "Scroll unblocked")


# ============================================================================
# SETUP / TEARDOWN
# ============================================================================

func before_each():
	## Called before each test
	input_simulator = IntegrationTestInput.new()
	add_child_autofree(input_simulator)
	# Evitar que el engine llame a _input/_unhandled_input con eventos reales
	# (p.ej. scroll del panel de GUT durante await). Los tests solo usan llamadas directas.
	input_simulator.set_process_input(false)
	input_simulator.set_process_unhandled_input(false)

	# Reset counters
	input_simulator.clicks_processed = 0
	input_simulator.scrolls_processed = 0

	# Reset del estado global de Input. `Input.action_press` NO refresca el flag
	# "just_pressed" si la acción ya estaba pulsada; liberar "Click" garantiza
	# que el primer click de cada test se registre de forma determinista.
	Input.action_release("Click")

	# Clean UIState
	while UIState._menu_count > 0:
		UIState.unregister_menu()


func after_each():
	## Called after each test
	# Clean UIState
	while UIState._menu_count > 0:
		UIState.unregister_menu()
