extends GutTest
## Tests de SaveConstants: rutas y formato de archivo.


func test_save_format_version_is_positive():
	assert_gt(SaveConstants.SAVE_FORMAT_VERSION, 0)


func test_user_slot_path_uses_user_dir():
	var path := SaveConstants.user_slot_path("foo")
	assert_true(path.begins_with("user://saves/"), "expected user:// prefix, got %s" % path)
	assert_true(path.ends_with(SaveConstants.SAVE_EXTENSION))
	assert_string_contains(path, "foo")


func test_fixture_path_uses_test_dir():
	var path := SaveConstants.fixture_path("bar")
	assert_true(path.begins_with("res://tests/fixtures/"))
	assert_true(path.ends_with(SaveConstants.SAVE_EXTENSION))
	assert_string_contains(path, "bar")


func test_quicksave_slot_constant_defined():
	assert_ne(SaveConstants.QUICKSAVE_SLOT, "")
