extends GutTest

## Tests para WorldGenerator. Cubre el flag `auto_generate_on_ready` que
## permite a los harnesses headless evitar la doble generacion: sin el
## flag, `add_child(generator)` disparaba `_ready()` → init_seed +
## generate_world, y luego el harness invocaba generate_world otra vez,
## creando dos mapas y dejando a EmpireCreator corriendo dos veces sobre
## WorldMaps distintos.


const WORLD_GENERATOR := preload("res://scripts/world_gen/world_generator.gd")


# Limpieza obligatoria: WorldMap es autoload y persiste entre tests.
func before_each() -> void:
	WorldMap.map = []
	WorldMap.map_as_dict = {}


func after_each() -> void:
	WorldMap.map = []
	WorldMap.map_as_dict = {}


# ============================================================
#  Default del flag — preserva el flujo de map.tscn
# ============================================================

func test_auto_generate_on_ready_defaults_to_true() -> void:
	# Contrato: en la escena de juego real (`scenes/world_generation/map.tscn`),
	# WorldGenerator es un nodo declarado que arranca solo via `_ready()`.
	# Cambiar el default a false romperia silenciosamente la generacion
	# de partida nueva.
	var generator: Node = WORLD_GENERATOR.new()
	autofree(generator)
	assert_true(generator.auto_generate_on_ready,
		"Por defecto auto_generate_on_ready=true para preservar map.tscn")


# ============================================================
#  Flag a false → _ready no genera
# ============================================================

func test_ready_does_not_generate_when_flag_is_false() -> void:
	var generator: Node = WORLD_GENERATOR.new()
	generator.auto_generate_on_ready = false
	# Sin settings: el early-return del flag se da antes de init_seed,
	# asi que no hace falta inyectar nada para que `add_child` sea seguro.
	add_child_autofree(generator)
	assert_eq(WorldMap.map.size(), 0,
		"Con auto_generate_on_ready=false, _ready() no debe poblar WorldMap")
