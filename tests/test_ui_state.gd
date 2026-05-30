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
# TESTS: Signal Emissions
# ============================================================================

func test_menu_opened_signal_emitted_on_first_registration():
	# Arrange: Initial state should have no menus
	assert_eq(UIState._menu_count, 0, "Setup: counter should start at 0")
	watch_signals(UIState)

	# Act: Register first menu
	UIState.register_menu()

	# Assert: menu_opened signal should emit on 0→1 transition
	assert_signal_emitted(UIState, "menu_opened", "menu_opened signal should emit on first registration")


func test_menu_opened_signal_not_emitted_on_subsequent_registrations():
	# Arrange: First menu already registered
	UIState.register_menu()

	# Act: Connect listener and register another menu
	var signal_count = 0
	UIState.menu_opened.connect(func(): signal_count += 1)
	UIState.register_menu()

	# Assert: Signal should not emit when already open (not a 0→1 transition)
	assert_eq(signal_count, 0, "menu_opened should only emit on 0→1 transition")


func test_menu_closed_signal_emitted_on_last_unregistration():
	# Arrange: One menu registered
	UIState.register_menu()
	assert_eq(UIState._menu_count, 1, "Setup: one menu registered")
	watch_signals(UIState)

	# Act: Unregister last menu
	UIState.unregister_menu()

	# Assert: menu_closed signal should emit on 1→0 transition
	assert_signal_emitted(UIState, "menu_closed", "menu_closed signal should emit on last unregistration")


func test_menu_closed_signal_not_emitted_on_partial_unregistration():
	# Arrange: Two menus registered
	UIState.register_menu()
	UIState.register_menu()

	# Act: Connect listener and unregister one menu
	var signal_count = 0
	UIState.menu_closed.connect(func(): signal_count += 1)
	UIState.unregister_menu()

	# Assert: Signal should not emit when menus still open (not a 1→0 transition)
	assert_eq(signal_count, 0, "menu_closed should only emit on 1→0 transition")


# ============================================================================
# TESTS: Complex Scenarios
# ============================================================================

func test_signal_transitions_with_multiple_menus():
	# Arrange: Initial state
	assert_eq(UIState._menu_count, 0, "Setup: counter at 0")
	watch_signals(UIState)

	# Act: Complex sequence of registrations and unregistrations
	UIState.register_menu()  # 0→1, should emit opened
	UIState.register_menu()  # 1→2, should not emit
	UIState.register_menu()  # 2→3, should not emit
	UIState.unregister_menu()  # 3→2, should not emit
	UIState.unregister_menu()  # 2→1, should not emit
	UIState.unregister_menu()  # 1→0, should emit closed

	# Assert: Signals emitted only on transitions
	assert_signal_emit_count(UIState, "menu_opened", 1)
	assert_signal_emit_count(UIState, "menu_closed", 1)


func test_repeated_open_close_cycles():
	# Arrange: Initial state
	assert_eq(UIState._menu_count, 0, "Setup: counter at 0")
	watch_signals(UIState)

	# Act: Multiple open/close cycles
	for i in range(3):
		UIState.register_menu()  # Should emit opened (0→1)
		UIState.unregister_menu()  # Should emit closed (1→0)

	# Assert: Each cycle should emit both signals
	assert_signal_emit_count(UIState, "menu_opened", 3)
	assert_signal_emit_count(UIState, "menu_closed", 3)


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
