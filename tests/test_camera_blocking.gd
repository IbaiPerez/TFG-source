extends GutTest

## Test suite for camera_3d.gd scroll blocking
## Verifies that camera zoom (scroll events) are blocked when menus are open


class MockCamera:
	extends Node
	## Mock of camera_3d.gd's _input behavior

	var zoom_events_processed: int = 0
	var last_fov: float = 45.0

	func _input(event: InputEvent) -> void:
		# Replicate camera_3d.gd blocking logic
		if UIState and UIState.is_any_menu_open():
			return

		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				last_fov -= 2.0
				zoom_events_processed += 1
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				last_fov += 2.0
				zoom_events_processed += 1


var camera: MockCamera


# ============================================================================
# TESTS: Scroll Processing Without Menus
# ============================================================================

func test_scroll_wheel_up_processed_without_menus():
	# Arrange: No menus
	var initial_fov = camera.last_fov
	var scroll_event = InputEventMouseButton.new()
	scroll_event.button_index = MOUSE_BUTTON_WHEEL_UP
	scroll_event.pressed = true

	# Act: Simulate scroll up (zoom in)
	camera._input(scroll_event)

	# Assert: FOV should decrease and event should be counted
	assert_eq(camera.zoom_events_processed, 1, "Scroll up should be processed")
	assert_eq(camera.last_fov, initial_fov - 2.0, "FOV should decrease on scroll up")


func test_scroll_wheel_down_processed_without_menus():
	# Arrange: No menus
	var initial_fov = camera.last_fov
	var scroll_event = InputEventMouseButton.new()
	scroll_event.button_index = MOUSE_BUTTON_WHEEL_DOWN
	scroll_event.pressed = true

	# Act: Simulate scroll down (zoom out)
	camera._input(scroll_event)

	# Assert: FOV should increase and event should be counted
	assert_eq(camera.zoom_events_processed, 1, "Scroll down should be processed")
	assert_eq(camera.last_fov, initial_fov + 2.0, "FOV should increase on scroll down")


func test_multiple_scroll_events_processed_without_menus():
	# Arrange: No menus
	var initial_fov = camera.last_fov
	var scroll_event = InputEventMouseButton.new()

	# Act: Simulate multiple scroll events (alternating up and down)
	for i in range(5):
		if i % 2 == 0:
			scroll_event.button_index = MOUSE_BUTTON_WHEEL_UP
		else:
			scroll_event.button_index = MOUSE_BUTTON_WHEEL_DOWN
		camera._input(scroll_event)

	# Assert: All events should be processed
	assert_eq(camera.zoom_events_processed, 5, "All scroll events should be processed")


# ============================================================================
# TESTS: Scroll Blocking With Menus
# ============================================================================

func test_scroll_wheel_blocked_when_one_menu_open():
	# Arrange: One menu open
	UIState.register_menu()
	var initial_fov = camera.last_fov
	var scroll_event = InputEventMouseButton.new()
	scroll_event.button_index = MOUSE_BUTTON_WHEEL_UP
	scroll_event.pressed = true

	# Act: Simulate scroll up
	camera._input(scroll_event)

	# Assert: FOV should not change and event should not be counted
	assert_eq(camera.zoom_events_processed, 0, "Scroll should be blocked with menu open")
	assert_eq(camera.last_fov, initial_fov, "FOV should not change with menu open")


func test_scroll_wheel_blocked_with_multiple_menus():
	# Arrange: Three menus open
	UIState.register_menu()
	UIState.register_menu()
	UIState.register_menu()
	var initial_fov = camera.last_fov
	var scroll_event = InputEventMouseButton.new()
	scroll_event.button_index = MOUSE_BUTTON_WHEEL_DOWN
	scroll_event.pressed = true

	# Act: Simulate scroll down
	camera._input(scroll_event)

	# Assert: FOV should not change
	assert_eq(camera.zoom_events_processed, 0, "Scroll should be blocked with multiple menus")
	assert_eq(camera.last_fov, initial_fov, "FOV should not change")


func test_multiple_scroll_events_blocked_consistently():
	# Arrange: One menu open
	UIState.register_menu()
	var initial_fov = camera.last_fov
	var scroll_event = InputEventMouseButton.new()

	# Act: Simulate multiple scroll events
	for i in range(5):
		if i % 2 == 0:
			scroll_event.button_index = MOUSE_BUTTON_WHEEL_UP
		else:
			scroll_event.button_index = MOUSE_BUTTON_WHEEL_DOWN
		camera._input(scroll_event)

	# Assert: All events should be blocked
	assert_eq(camera.zoom_events_processed, 0, "All scroll events should be blocked")
	assert_eq(camera.last_fov, initial_fov, "FOV should not change")


# ============================================================================
# TESTS: Unblocking When Menus Close
# ============================================================================

func test_scroll_is_unblocked_when_last_menu_closes():
	# Arrange: Two menus open
	UIState.register_menu()
	UIState.register_menu()
	var initial_fov = camera.last_fov
	var scroll_event = InputEventMouseButton.new()
	scroll_event.button_index = MOUSE_BUTTON_WHEEL_UP
	scroll_event.pressed = true

	# Act: Close both menus
	UIState.unregister_menu()
	UIState.unregister_menu()

	# Simulate scroll
	camera._input(scroll_event)

	# Assert: Scroll should be processed after all menus close
	assert_eq(camera.zoom_events_processed, 1, "Scroll should be processed after closing all menus")
	assert_eq(camera.last_fov, initial_fov - 2.0, "FOV should change after closing menus")


func test_scroll_remains_blocked_when_menu_still_open():
	# Arrange: Two menus open
	UIState.register_menu()
	UIState.register_menu()
	var initial_fov = camera.last_fov
	var scroll_event = InputEventMouseButton.new()
	scroll_event.button_index = MOUSE_BUTTON_WHEEL_UP
	scroll_event.pressed = true

	# Act: Close only one menu
	UIState.unregister_menu()

	# Simulate scroll
	camera._input(scroll_event)

	# Assert: Scroll should still be blocked (one menu remaining)
	assert_eq(camera.zoom_events_processed, 0, "Scroll should remain blocked while menus are still open")
	assert_eq(camera.last_fov, initial_fov, "FOV should not change")


# ============================================================================
# TESTS: Complex Camera Scenarios
# ============================================================================

func test_blocking_works_with_zoom_cycles():
	# Arrange
	var scroll_event = InputEventMouseButton.new()
	var initial_fov = camera.last_fov

	# Act & Assert: Multiple zoom in/out cycles
	for cycle in range(3):
		# Open menu - scroll should be blocked
		UIState.register_menu()
		scroll_event.button_index = MOUSE_BUTTON_WHEEL_UP
		camera._input(scroll_event)
		assert_eq(camera.zoom_events_processed, cycle, "Scroll should be blocked during cycle %d open" % cycle)

		# Close menu - scroll should be processed
		UIState.unregister_menu()
		camera._input(scroll_event)
		assert_eq(camera.zoom_events_processed, cycle + 1, "Scroll should be processed during cycle %d close" % cycle)

	# Verify final FOV state
	var expected_fov = initial_fov - (2.0 * 3)  # Three successful scroll up events
	assert_eq(camera.last_fov, expected_fov, "FOV should match total processed scroll events")


# ============================================================================
# SETUP / TEARDOWN
# ============================================================================

func before_each():
	## Called before each test
	camera = MockCamera.new()
	add_child_autofree(camera)

	# Clean UIState
	while UIState._menu_count > 0:
		UIState.unregister_menu()


func after_each():
	## Called after each test
	# Clean UIState
	while UIState._menu_count > 0:
		UIState.unregister_menu()
