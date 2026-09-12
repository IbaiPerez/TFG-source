extends GutTest

## Test suite for UIState autoload
## Verifies that UIState correctly tracks open menus and emits signals


# ============================================================================
# TESTS: Counter State Management
# ============================================================================

func test_ui_state_initial_state_is_empty():
	# Arrange: UIState is already in initial state

	# Act: Check initial state
	var menu_count = UIState._menu_count
	var is_any_open = UIState.is_any_menu_open()

	# Assert: Counter should be 0 and no menus should be reported open
	assert_eq(menu_count, 0, "Counter should start at 0")
	assert_false(is_any_open, "No menus should be open initially")


func test_register_menu_increments_counter_by_one():
	# Arrange: Clean state

	# Act: Register a single menu
	UIState.register_menu()

	# Assert: Counter increments and state reflects menu open
	assert_eq(UIState._menu_count, 1, "Counter should increment to 1")
	assert_true(UIState.is_any_menu_open(), "is_any_menu_open() should return true")


func test_register_multiple_menus_accumulate():
	# Arrange: Empty state

	# Act: Register three menus
	UIState.register_menu()
	UIState.register_menu()
	UIState.register_menu()

	# Assert: Counter accumulates correctly
	assert_eq(UIState._menu_count, 3, "Counter should be 3 after three registrations")
	assert_true(UIState.is_any_menu_open(), "Should report menu open")


func test_unregister_menu_decrements_counter_by_one():
	# Arrange: Two menus open
	UIState.register_menu()
	UIState.register_menu()

	# Act: Unregister one menu
	UIState.unregister_menu()

	# Assert: Counter decrements but menu still open
	assert_eq(UIState._menu_count, 1, "Counter should decrement to 1")
	assert_true(UIState.is_any_menu_open(), "Should still report menu open")


func test_unregister_all_menus_returns_to_zero():
	# Arrange: Three menus open
	UIState.register_menu()
	UIState.register_menu()
	UIState.register_menu()

	# Act: Unregister all menus
	UIState.unregister_menu()
	UIState.unregister_menu()
	UIState.unregister_menu()

	# Assert: Counter returns to 0 and no menus reported open
	assert_eq(UIState._menu_count, 0, "Counter should return to 0")
	assert_false(UIState.is_any_menu_open(), "Should report no menus open")


func test_unregister_menu_cannot_go_negative():
	# Arrange: Empty state (no menus)

	# Act: Try to unregister menus when none are registered
	UIState.unregister_menu()
	UIState.unregister_menu()
	UIState.unregister_menu()

	# Assert: Counter stays at 0 (protected against negative values)
	assert_eq(UIState._menu_count, 0, "Counter should not go below 0")
	assert_false(UIState.is_any_menu_open(), "Should report no menus open")


# ============================================================================
# TESTS: Complex Scenarios
# ============================================================================

func test_open_state_follows_counter_transitions():
	# Arrange: Initial state
	assert_eq(UIState._menu_count, 0, "Setup: counter at 0")

	# Act + Assert: solo la transición 0→1 abre y solo la 1→0 cierra
	UIState.register_menu()
	assert_true(UIState.is_any_menu_open(), "0→1 abre")
	UIState.register_menu()
	UIState.register_menu()
	UIState.unregister_menu()
	UIState.unregister_menu()
	assert_true(UIState.is_any_menu_open(), "3→1 sigue abierto")
	UIState.unregister_menu()
	assert_false(UIState.is_any_menu_open(), "1→0 cierra")


func test_repeated_open_close_cycles():
	# Arrange: Initial state
	assert_eq(UIState._menu_count, 0, "Setup: counter at 0")

	# Act + Assert: cada ciclo vuelve al estado cerrado
	for i in range(3):
		UIState.register_menu()
		assert_true(UIState.is_any_menu_open(), "ciclo %d: abierto" % i)
		UIState.unregister_menu()
		assert_false(UIState.is_any_menu_open(), "ciclo %d: cerrado" % i)


# ============================================================================
# SETUP / TEARDOWN
# ============================================================================

func before_each():
	## Called before each test
	# Reset UIState to clean state
	while UIState._menu_count > 0:
		UIState.unregister_menu()


func after_each():
	## Called after each test
	# Clean up: reset counter
	while UIState._menu_count > 0:
		UIState.unregister_menu()
