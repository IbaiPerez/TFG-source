extends RefCounted
class_name SaveConstants

## Constantes del sistema de guardado.

## Versión actual del formato. Incrementar al cambiar el esquema de manera
## incompatible. El loader rechaza versiones desconocidas.
##
## v2: la localización (i18n) convirtió los `name` de Building/Troop en claves
## de traducción (p.ej. "BLD_MOLINO_NAME"). El SaveResourceRegistry indexa por
## esas claves, así que los saves v1 (que guardaban nombres en español como
## "Molino") ya no resuelven y se rechazan limpiamente.
const SAVE_FORMAT_VERSION:int = 2

## Carpeta donde viven los slots de guardado del usuario (persistente).
const USER_SAVES_DIR:String = "user://saves"

## Carpeta de fixtures de testing (snapshots predefinidos para tests GUT).
const TEST_FIXTURES_DIR:String = "res://tests/fixtures"

## Extensión usada para los archivos de save.
const SAVE_EXTENSION:String = ".json"

## Slot reservado para quicksave (F5/F9).
const QUICKSAVE_SLOT:String = "quicksave"


## Devuelve la ruta completa de un slot de save de usuario.
static func user_slot_path(slot_name:String) -> String:
	return "%s/%s%s" % [USER_SAVES_DIR, slot_name, SAVE_EXTENSION]


## Devuelve la ruta completa de un fixture de testing.
static func fixture_path(fixture_name:String) -> String:
	return "%s/%s%s" % [TEST_FIXTURES_DIR, fixture_name, SAVE_EXTENSION]
