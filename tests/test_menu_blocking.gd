extends GutTest

## Bloqueo de la interacción con el mapa mientras hay menús abiertos, probado
## sobre los SCRIPTS REALES: `camera_3d.gd`, `interaction.gd` y los paneles que
## se registran en `UIState`.
##
## Sustituye a cuatro ficheros (`test_interaction_blocking`, `test_camera_blocking`,
## `test_menu_blocking_integration`, `test_menu_registration`) cuyos 30 tests
## ejercitaban MOCKS que "replicaban" la lógica de producción: si alguien borraba
## el `if UIState.is_any_menu_open()` de la cámara, seguían en verde. El contador
## de `UIState` en sí lo cubre `test_ui_state.gd`.

const CAMERA_SCRIPT := preload("res://scripts/camera/camera_3d.gd")
const INTERACTION_SCRIPT := preload("res://scripts/map/interaction.gd")
const TILE_CURSOR := preload("res://scenes/hexagon_cursor.tscn")

const BUILDING_PANEL := preload("res://scenes/UI/building/building_panel.tscn")
const SHOP_PANEL := preload("res://scenes/UI/shop/shop_panel.tscn")
const TURN_EVENT_PANEL := preload("res://scenes/UI/turn_events/turn_event_panel.tscn")
const CARD_SELECTION_PANEL := preload("res://scenes/UI/turn_events/event_card_selection_panel.tscn")


class DeselectListener extends RefCounted:
	var count := 0
	func on_fired() -> void:
		count += 1


var _menus_before: int


func before_each() -> void:
	# Otro test puede dejar un menú registrado; se afirma sobre la DIFERENCIA.
	_menus_before = UIState._menu_count


func after_each() -> void:
	# Dos frames: queue_free de los paneles → _exit_tree → unregister.
	await get_tree().process_frame
	await get_tree().process_frame
	UIState._menu_count = _menus_before


# ============================================================
#  Fixtures sobre los scripts reales
# ============================================================

## Cámara real colgada de un pivote, como en map.tscn; con sol para que
## `adjust_shadows` no pise null.
func _camera() -> Camera3D:
	var pivot := Node3D.new()
	add_child_autofree(pivot)
	var cam: Camera3D = CAMERA_SCRIPT.new()
	cam.sun = DirectionalLight3D.new()
	pivot.add_child(cam.sun)
	pivot.add_child(cam)
	return cam


func _wheel(button: MouseButton) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = true
	return ev


func _click() -> InputEventMouseButton:
	return _wheel(MOUSE_BUTTON_LEFT)


## InteractionTracker real, con su cursor y una cámara en el árbol (el raycast
## proyecta desde ella). Sin casillas en el mundo, un clic que llega al raycast
## no da con nada y termina en `deselect()` → `Events.tile_deselected`.
func _tracker() -> InteractionTracker:
	var root := Node3D.new()
	add_child_autofree(root)
	var cam := Camera3D.new()
	root.add_child(cam)
	var tracker: InteractionTracker = INTERACTION_SCRIPT.new()
	tracker.tile_cursor_scene = TILE_CURSOR
	tracker.main_camera = cam
	root.add_child(tracker)
	return tracker


func _panel(scene: PackedScene) -> Node:
	var p: Node = scene.instantiate()
	add_child(p)
	return p


# ============================================================
#  Cámara (camera_3d.gd)
# ============================================================

func test_la_rueda_hace_zoom_sin_menus() -> void:
	var cam := _camera()
	var fov_antes := cam.fov
	cam._input(_wheel(MOUSE_BUTTON_WHEEL_UP))
	assert_lt(cam.fov, fov_antes, "rueda arriba acerca (baja el FOV)")
	cam._input(_wheel(MOUSE_BUTTON_WHEEL_DOWN))
	assert_almost_eq(cam.fov, fov_antes, 0.001, "rueda abajo deshace el zoom")


func test_la_rueda_se_ignora_con_un_menu_abierto() -> void:
	var cam := _camera()
	var fov_antes := cam.fov
	UIState.register_menu()
	cam._input(_wheel(MOUSE_BUTTON_WHEEL_UP))
	cam._input(_wheel(MOUSE_BUTTON_WHEEL_DOWN))
	assert_eq(cam.fov, fov_antes, "con un menú abierto la rueda no toca el FOV")
	UIState.unregister_menu()
	cam._input(_wheel(MOUSE_BUTTON_WHEEL_UP))
	assert_lt(cam.fov, fov_antes, "al cerrar el último menú vuelve a hacer zoom")


func test_el_zoom_sigue_bloqueado_mientras_quede_un_menu() -> void:
	var cam := _camera()
	var fov_antes := cam.fov
	UIState.register_menu()
	UIState.register_menu()
	UIState.unregister_menu()
	cam._input(_wheel(MOUSE_BUTTON_WHEEL_UP))
	assert_eq(cam.fov, fov_antes, "queda un menú: sigue bloqueado")
	UIState.unregister_menu()


# ============================================================
#  Selección de casillas (interaction.gd)
# ============================================================

func test_un_clic_sin_menus_llega_al_raycast() -> void:
	var tracker := _tracker()
	var listener := DeselectListener.new()
	Events.tile_deselected.connect(listener.on_fired)
	var antes := listener.count
	tracker._unhandled_input(_click())
	Events.tile_deselected.disconnect(listener.on_fired)
	assert_eq(listener.count, antes + 1,
		"sin menús el clic se procesa: el raycast no da con nada y deselecciona")


func test_un_clic_con_un_menu_abierto_no_llega_al_raycast() -> void:
	var tracker := _tracker()
	var listener := DeselectListener.new()
	Events.tile_deselected.connect(listener.on_fired)
	UIState.register_menu()
	var antes := listener.count
	tracker._unhandled_input(_click())
	UIState.unregister_menu()
	Events.tile_deselected.disconnect(listener.on_fired)
	assert_eq(listener.count, antes, "con un menú abierto el clic ni mira el mundo")


# ============================================================
#  Paneles reales: se registran al entrar y se liberan al salir
# ============================================================

func test_los_paneles_registran_al_entrar_en_el_arbol() -> void:
	for scene in [BUILDING_PANEL, SHOP_PANEL, TURN_EVENT_PANEL]:
		var p := _panel(scene)
		var nombre := String(p.name)
		assert_eq(UIState._menu_count, _menus_before + 1,
			"%s debe registrarse en _ready" % nombre)
		p.free()
		assert_eq(UIState._menu_count, _menus_before,
			"%s debe liberar el registro al salir del árbol" % nombre)


func test_el_panel_de_reclutar_registra_al_entrar() -> void:
	var p := RecruitPanel.new()
	add_child(p)
	assert_eq(UIState._menu_count, _menus_before + 1)
	p.free()
	assert_eq(UIState._menu_count, _menus_before)


func test_varios_paneles_abiertos_acumulan_y_el_ultimo_libera() -> void:
	var a := _panel(SHOP_PANEL)
	var b := _panel(TURN_EVENT_PANEL)
	assert_eq(UIState._menu_count, _menus_before + 2)
	a.free()
	assert_true(UIState.is_any_menu_open(), "queda uno abierto")
	b.free()
	assert_eq(UIState._menu_count, _menus_before)


func test_el_selector_de_cartas_registra_por_visibilidad() -> void:
	var p: Control = _panel(CARD_SELECTION_PANEL)
	assert_false(p.visible, "arranca oculto")
	assert_eq(UIState._menu_count, _menus_before, "oculto no cuenta")
	p.show()
	assert_eq(UIState._menu_count, _menus_before + 1, "al mostrarse se registra")
	p.hide()
	assert_eq(UIState._menu_count, _menus_before, "al ocultarse se libera")
	p.free()


## Town con 3 edificios: la única casilla que admite Megalópolis.
func _town_elegible() -> Tile:
	var tile := Tile.new()
	tile.mesh_data = TileMeshData.new()
	tile.mesh_data.type = Tile.biome_type.Grassland
	tile.natural_resource = NaturalResource.new()
	var loc := LocationType.new()
	loc.type = Tile.location_type.Town
	tile.location = loc
	tile.buildings = [Building.new(), Building.new(), Building.new()]
	tile.neighbors = []
	tile.add_child(MeshInstance3D.new())  # la malla que resalta set_highlight
	return autofree(tile)


## Abre el evento de Megalópolis y pulsa su opción: el panel se oculta y espera
## un clic en el mapa.
func _panel_eligiendo_casilla() -> TurnEventPanel:
	var panel: TurnEventPanel = _panel(TURN_EVENT_PANEL)
	panel.context = EventContext.new()
	panel.context.controlled_tiles = [_town_elegible()]
	var choice := TurnEventChoice.new()
	choice.effects = [UrbanizeToMegalopolisEffect.new()]
	panel._on_choice_selected(choice)
	return panel


## El panel se oculta para que el jugador elija casilla; si siguiera contando
## como menú abierto, `interaction.gd` tiraría ese clic y la selección no
## terminaría nunca (las ciudades salían resaltadas pero ninguna respondía).
func test_el_panel_de_evento_libera_el_mapa_mientras_se_elige_casilla() -> void:
	var tracker := _tracker()
	var listener := DeselectListener.new()
	Events.tile_deselected.connect(listener.on_fired)
	var panel := _panel_eligiendo_casilla()
	assert_false(panel.visible, "se oculta para dejar ver el mapa")
	assert_eq(UIState._menu_count, _menus_before, "oculto no cuenta como menú")
	tracker._unhandled_input(_click())
	Events.tile_deselected.disconnect(listener.on_fired)
	assert_eq(listener.count, 1, "el clic en el mapa llega al raycast")

	Events.tile_selection_cancelled.emit()
	assert_true(panel.visible, "al cancelar vuelve el panel")
	assert_eq(UIState._menu_count, _menus_before + 1, "y vuelve a bloquear el mapa")
	panel.free()
	assert_eq(UIState._menu_count, _menus_before)


func _tecla(keycode: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.pressed = true
	return ev


func test_clic_derecho_y_escape_cancelan_la_seleccion_de_casilla() -> void:
	var selector := EventTileSelector.new()
	add_child_autofree(selector)
	for ev: InputEvent in [_wheel(MOUSE_BUTTON_RIGHT), _tecla(KEY_ESCAPE)]:
		var panel := _panel_eligiendo_casilla()
		selector._unhandled_input(ev)
		assert_true(panel.visible, "%s cancela y vuelve el panel" % ev.as_text())
		panel.free()
	var otro := _panel_eligiendo_casilla()
	selector._unhandled_input(_click())
	assert_false(otro.visible, "el clic izquierdo no cancela")
	otro.free()


func test_liberar_el_panel_oculto_no_descuenta_otro_menu() -> void:
	var panel := _panel_eligiendo_casilla()
	UIState.register_menu()
	panel.free()
	assert_eq(UIState._menu_count, _menus_before + 1,
		"el panel ya se había dado de baja al ocultarse")
	UIState.unregister_menu()


# ============================================================
#  Integración: un panel real bloquea la cámara y el mapa
# ============================================================

func test_un_panel_real_abierto_bloquea_zoom_y_clic() -> void:
	var cam := _camera()
	var tracker := _tracker()
	var listener := DeselectListener.new()
	Events.tile_deselected.connect(listener.on_fired)
	var fov_antes := cam.fov

	var panel := _panel(SHOP_PANEL)
	cam._input(_wheel(MOUSE_BUTTON_WHEEL_UP))
	tracker._unhandled_input(_click())
	assert_eq(cam.fov, fov_antes, "con la tienda abierta no hay zoom")
	assert_eq(listener.count, 0, "ni clics en el mapa")

	panel.free()
	cam._input(_wheel(MOUSE_BUTTON_WHEEL_UP))
	tracker._unhandled_input(_click())
	Events.tile_deselected.disconnect(listener.on_fired)
	assert_lt(cam.fov, fov_antes, "al cerrarla vuelve el zoom")
	assert_eq(listener.count, 1, "y los clics")
