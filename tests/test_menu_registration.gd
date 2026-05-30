extends GutTest

## Test suite for panel registration with UIState
## Verifies that panels automatically register/unregister with UIState


class DummyMenuPanel:
	extends PanelContainer
	## Simulates a standard menu panel that registers on _ready and unregisters on _exit_tree

	func _ready() -> void:
		if UIState:
			UIState.register_menu()

	func _exit_tree() -> void:
		if UIState:
			UIState.unregister_menu()


class DummyVisibilityPanel:
	extends Control
	## Simulates a panel that registers/unregisters based on visibility changes

	func _init() -> void:
		# Start hidden so show() will trigger visibility_changed signal
		visible = false

	func _ready() -> void:
		visibility_changed.connect(_on_visibility_changed)

	func _on_visibility_changed() -> void:
		if not UIState:
			return
		if visible:
			UIState.register_menu()
		else:
			UIState.unregister_menu()


# ============================================================================
# TESTS: Basic Panel Registration
# ============================================================================

func test_panel_registers_on_ready():
	# Arrange: Create panel
	var panel = DummyMenuPanel.new()

	# Act: Add panel to tree (triggers _ready)
	add_child_autofree(panel)

	# Assert: UIState should register the panel
	assert_eq(UIState._menu_count, 1, "Panel should register on _ready")
	assert_true(UIState.is_any_menu_open(), "Menu should be reported as open")


func test_panel_unregisters_on_exit_tree():
	# Arrange: Panel in tree
	var panel = DummyMenuPanel.new()
	add_child_autofree(panel)

	assert_eq(UIState._menu_count, 1, "Panel should be registered")

	# Act: Remove panel from tree (triggers _exit_tree)
	panel.queue_free()
	await get_tree().process_frame

	# Assert: UIState should unregister the panel
	assert_eq(UIState._menu_count, 0, "Panel should unregister on _exit_tree")
	assert_false(UIState.is_any_menu_open(), "No menus should be open")


# ============================================================================
# TESTS: Multiple Panels
# ============================================================================

func test_multiple_panels_register_accumulate():
	# Arrange
	var panel1 = DummyMenuPanel.new()
	var panel2 = DummyMenuPanel.new()
	var panel3 = DummyMenuPanel.new()

	# Act: Add all panels to tree
	add_child_autofree(panel1)
	add_child_autofree(panel2)
	add_child_autofree(panel3)

	# Assert: All panels should be registered
	assert_eq(UIState._menu_count, 3, "All three panels should be registered")
	assert_true(UIState.is_any_menu_open(), "Menus should be reported as open")


func test_multiple_panels_unregister_sequentially():
	# Arrange: Three panels in tree
	var panel1 = DummyMenuPanel.new()
	var panel2 = DummyMenuPanel.new()
	var panel3 = DummyMenuPanel.new()

	add_child_autofree(panel1)
	add_child_autofree(panel2)
	add_child_autofree(panel3)

	assert_eq(UIState._menu_count, 3, "Setup: three panels registered")

	# Act & Assert: Remove panels one by one
	panel1.queue_free()
	await get_tree().process_frame
	assert_eq(UIState._menu_count, 2, "Counter should be 2 after first removal")
	assert_true(UIState.is_any_menu_open(), "Menus should still be open")

	panel2.queue_free()
	await get_tree().process_frame
	assert_eq(UIState._menu_count, 1, "Counter should be 1 after second removal")
	assert_true(UIState.is_any_menu_open(), "Menu should still be open")

	panel3.queue_free()
	await get_tree().process_frame
	assert_eq(UIState._menu_count, 0, "Counter should be 0 after third removal")
	assert_false(UIState.is_any_menu_open(), "No menus should be open")


# ============================================================================
# TESTS: Visibility-Based Panels
# ============================================================================

func test_visibility_panel_registers_on_show():
	# Arrange: Visibility panel (initially hidden)
	var panel = DummyVisibilityPanel.new()
	add_child_autofree(panel)

	assert_eq(UIState._menu_count, 0, "Setup: no menus registered initially")

	# Act: Show the panel
	panel.show()
	await get_tree().process_frame

	# Assert: Panel should register when shown
	assert_eq(UIState._menu_count, 1, "Panel should register on show()")
	assert_true(UIState.is_any_menu_open(), "Menu should be open")


func test_visibility_panel_unregisters_on_hide():
	# Arrange: Visible panel
	var panel = DummyVisibilityPanel.new()
	add_child_autofree(panel)

	panel.show()
	await get_tree().process_frame
	assert_eq(UIState._menu_count, 1, "Setup: panel visible and registered")

	# Act: Hide the panel
	panel.hide()
	await get_tree().process_frame

	# Assert: Panel should unregister when hidden
	assert_eq(UIState._menu_count, 0, "Panel should unregister on hide()")
	assert_false(UIState.is_any_menu_open(), "No menus should be open")


func test_visibility_panel_toggles_multiple_times():
	# Arrange: Visibility panel
	var panel = DummyVisibilityPanel.new()
	add_child_autofree(panel)

	# Act & Assert: Multiple show/hide cycles
	for cycle in range(3):
		panel.show()
		await get_tree().process_frame
		assert_eq(UIState._menu_count, 1, "Cycle %d: counter should be 1 when shown" % cycle)
		assert_true(UIState.is_any_menu_open(), "Cycle %d: menu should be open" % cycle)

		panel.hide()
		await get_tree().process_frame
		assert_eq(UIState._menu_count, 0, "Cycle %d: counter should be 0 when hidden" % cycle)
		assert_false(UIState.is_any_menu_open(), "Cycle %d: no menus should be open" % cycle)


# ============================================================================
# TESTS: Mixed Panel Types
# ============================================================================

func test_mixed_regular_and_visibility_panels():
	# Arrange: One regular, one visibility-based panel
	var regular = DummyMenuPanel.new()
	var dynamic = DummyVisibilityPanel.new()

	# Act: Add regular panel (automatically registers)
	add_child_autofree(regular)
	assert_eq(UIState._menu_count, 1, "Regular panel should register")

	# Add visibility panel and show it
	add_child_autofree(dynamic)
	dynamic.show()
	await get_tree().process_frame
	assert_eq(UIState._menu_count, 2, "Both panels should be registered")

	# Hide visibility panel
	dynamic.hide()
	await get_tree().process_frame
	assert_eq(UIState._menu_count, 1, "Regular panel still open")

	# Remove regular panel
	regular.queue_free()
	await get_tree().process_frame
	assert_eq(UIState._menu_count, 0, "All panels closed")


# ============================================================================
# SETUP / TEARDOWN
# ============================================================================

func before_each():
	## Called before each test
	# Clean UIState
	while UIState._menu_count > 0:
		UIState.unregister_menu()


func after_each():
	## Called after each test
	# Clean UIState
	while UIState._menu_count > 0:
		UIState.unregister_menu()
