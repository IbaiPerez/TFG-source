extends GutTest

## Tests para CardConfirmingState y la guarda en CardDraggingState.
##
## Bug original: al pinchar rapido sobre una carta con `needs_confirmation`
## que requiere target (UpgradeBuildingCard, BuildCard) sin moverla a
## una tile, el state machine transitionaba a CONFIRMING. Alli
## `card_ui.confirm()` llamaba a `card.confirm(empty_targets, stats)`,
## que para UpgradeBuildingCard sale temprano si `targets.size() != 1` y
## NO emite la señal — por tanto `card.menu` NO se crea.
## Luego, `card.menu.card_confirmed.connect(...)` crasheaba:
##   - "Invalid access ... on Nil" (primer intento), o
##   - "Invalid access ... on previously freed" (intentos siguientes,
##     porque exit() hacia queue_free pero no nuleaba la referencia).
##
## Fix:
##   1. CardConfirmingState.exit(): tras `queue_free()` ponemos `card.menu = null`
##      para no dejar referencias colgantes.
##   2. CardConfirmingState.enter(): si tras `card_ui.confirm()` el menu no
##      existe, pedimos transicion a BASE de forma diferida.
##   3. CardDraggingState.on_input(): si la carta requiere target y no hay
##      targets validos, vamos a BASE en lugar de a CONFIRMING.

const CONFIRMING_STATE := preload("res://scripts/ui/cards/card_states/card_confirming_state.gd")
const DRAGGING_STATE := preload("res://scripts/ui/cards/card_states/card_dragging_state.gd")
const CARD_UI_SCENE := preload("uid://cf5a8tg1tqyy7")
const BUILDING_PANEL_SCENE := preload("uid://d4kc0x1wj7vrm")


# ============================================================
#  Helpers
# ============================================================

func _make_upgrade_card() -> UpgradeBuildingCard:
	var c := UpgradeBuildingCard.new()
	c.id = "upgrade"
	c.target = Card.Target.TILE
	c.needs_confirmation = true
	return c


func _spawn_card_ui(card:Card) -> CardUI:
	# La scene de CardUI tiene Panel/Icon/DropPointDetector/Tooltip/StateMachine
	# como hijos, asi que cuando entra al arbol _ready resuelve los @onready
	# correctamente. Esto evita tener que mockear todo a mano.
	var cui := CARD_UI_SCENE.instantiate()
	add_child_autofree(cui)
	cui.card = card
	return cui


func _spawn_confirming(cui:CardUI):
	var state = CONFIRMING_STATE.new()
	state.card_ui = cui
	state.state = CardState.State.CONFIRMING
	add_child_autofree(state)
	return state


# ============================================================
#  exit() nula la referencia al menu
# ============================================================

func test_exit_sets_card_menu_to_null_after_free():
	# Reproduce el escenario raiz del bug "previously freed":
	#   1) Una sesion de CONFIRMING anterior creó un menu (BuildingPanel)
	#      y lo asignó a `card.menu`.
	#   2) Al salir, antes del fix, exit() hacia `queue_free` pero dejaba
	#      la referencia colgando — al volver a entrar, `card.menu` no era
	#      null pero apuntaba a un objeto liberado.
	#   3) Tras el fix, exit() tambien nulea la referencia.
	var card := _make_upgrade_card()
	# Instanciamos desde scene (no .new()) porque BuildingPanel tiene
	# @onready vars que resuelven hijos por ruta y solo existen al
	# instanciar la scene.
	var menu := BUILDING_PANEL_SCENE.instantiate()
	add_child_autofree(menu)
	card.menu = menu
	var cui := _spawn_card_ui(card)
	var state = _spawn_confirming(cui)

	state.exit()

	assert_null(card.menu,
		"exit() debe nulear card.menu tras liberarlo para no dejar referencias colgantes")


func test_exit_is_safe_when_menu_already_null():
	# exit() no debe crashear si nunca llegamos a crear menu (caso del
	# bug original: confirm() rechazo, no hay menu, y luego se cancela).
	var card := _make_upgrade_card()
	card.menu = null
	var cui := _spawn_card_ui(card)
	var state = _spawn_confirming(cui)

	state.exit()  # No debe lanzar

	assert_null(card.menu, "card.menu sigue null tras exit() idempotente")


# ============================================================
#  enter() defiende contra confirm() que no crea menu
# ============================================================

func test_enter_without_menu_requests_back_to_base_deferred():
	# UpgradeBuildingCard sin targets: confirm() sale temprano y NO crea
	# menu. enter() debe detectarlo y pedir vuelta a BASE en vez de
	# crashear conectando una señal a null.
	var card := _make_upgrade_card()
	var cui := _spawn_card_ui(card)
	# targets vacio a proposito.
	var state = _spawn_confirming(cui)

	watch_signals(state)
	state.enter()

	# La transicion va por call_deferred (ver comentario en el script:
	# emitir desde enter() sincronicamente es ignorado por el state
	# machine porque current_state aun no esta actualizado).
	await get_tree().process_frame

	assert_signal_emitted(state, "transition_requested",
		"enter() sin menu debe pedir transicion (a BASE) en vez de crashear")


func test_enter_clears_dangling_freed_reference_before_confirming():
	# Si entramos a CONFIRMING con `card.menu` apuntando a un panel
	# previously freed, enter() lo limpia antes de pedir uno nuevo.
	# Asi `is_instance_valid` posterior funciona de forma coherente.
	var card := _make_upgrade_card()
	var dangling := BUILDING_PANEL_SCENE.instantiate()
	add_child_autofree(dangling)
	card.menu = dangling
	dangling.free()  # Forzar el estado "previously freed".

	var cui := _spawn_card_ui(card)
	var state = _spawn_confirming(cui)

	# Sin crash; y como confirm() no crea menu (sin targets), debe
	# acabar con menu = null y pedir transicion diferida.
	watch_signals(state)
	state.enter()
	await get_tree().process_frame

	assert_null(card.menu,
		"enter() debe limpiar la referencia colgante antes de seguir")
	assert_signal_emitted(state, "transition_requested",
		"sin menu valido tras confirm(), enter() solicita salir de CONFIRMING")


# ============================================================
#  _request_back_to_base: emision con el destino correcto
# ============================================================

func test_request_back_to_base_emits_with_base_target():
	var card := _make_upgrade_card()
	var cui := _spawn_card_ui(card)
	var state = _spawn_confirming(cui)

	watch_signals(state)
	state._request_back_to_base()

	assert_signal_emitted_with_parameters(state, "transition_requested",
		[state, CardState.State.BASE])


# ============================================================
#  Guarda en CardDraggingState
# ============================================================

func _spawn_dragging(cui:CardUI):
	# CardDraggingState.enter() depende de un ui_layer en el grupo y del
	# scene tree (create_timer, panel.set...). En este test solo nos
	# interesa on_input, asi que no llamamos a enter().
	var state = DRAGGING_STATE.new()
	state.card_ui = cui
	state.state = CardState.State.DRAGGING
	add_child_autofree(state)
	return state


func test_dragging_targeted_card_without_targets_returns_to_base():
	# Reproduce el doble clic rapido sobre una carta UPGRADE sin moverla
	# fuera de la mano: la carta es TILE-targeted, targets esta vacio.
	# Antes del fix, transitabamos a CONFIRMING aunque card.confirm() no
	# fuese a producir menu, lo que luego provocaba el crash al conectar
	# `card_confirmed`. Ahora va directo a BASE.
	var card := _make_upgrade_card()
	var cui := _spawn_card_ui(card)
	cui.targets.clear()  # explicito

	var state = _spawn_dragging(cui)
	state.minimum_drag_time_elapsed = true

	var event := InputEventAction.new()
	event.action = "Click"
	event.pressed = true  # press de click

	watch_signals(state)
	state.on_input(event)

	# Nota: assert_signal_emitted_with_parameters tiene firma
	# (object, signal, parameters, index). El 4o arg es un int, no un
	# mensaje. Para no chocar con eso, primero verificamos que se emitio
	# (con mensaje) y luego validamos los parametros.
	assert_signal_emitted(state, "transition_requested",
		"carta TILE-targeted sin targets debe volver a BASE en lugar de CONFIRMING")
	assert_signal_emitted_with_parameters(state, "transition_requested",
		[state, CardState.State.BASE])
