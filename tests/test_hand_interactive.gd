extends GutTest

## Tests para el toggle de interactividad de Hand.
##
## Bug original: si el jugador agarraba una carta mientras todavia se
## estaban repartiendo cartas al inicio de turno, se acababa repartiendo
## una carta de mas (la carta arrastrada salia temporalmente del
## HBoxContainer y descuadraba el conteo). PlayerHandler.draw_cards_animated
## ahora desactiva la mano antes de empezar el tween de robo y la
## reactiva en `tween.finished`.
##
## Aqui solo testeamos el contrato basico de Hand.set_interactive: que
## actualiza mouse_filter en las cartas presentes y propaga el estado a
## las cartas añadidas mientras la mano esta desactivada.


func _make_dummy_card() -> Card:
	# Carta minima viable. Solo necesitamos que `cui.card = card` no
	# crashee (acceder a card.icon es lo unico que CardUI.set_card hace).
	var c := Card.new()
	c.id = "dummy"
	c.target = Card.Target.SELF
	c.needs_confirmation = false
	return c


func _spawn_hand() -> Hand:
	# Hand tiene class_name + extends HBoxContainer, asi que Hand.new()
	# da una instancia con el script ya enlazado.
	var h := Hand.new()
	add_child_autofree(h)
	return h


# ============================================================
#  set_interactive: estado por defecto y toggle
# ============================================================

func test_hand_starts_interactive_by_default() -> void:
	var hand := _spawn_hand()
	hand.add_card(_make_dummy_card())
	# Esperar a que el CardUI termine su _ready (set_card hace await ready).
	await get_tree().process_frame

	var cui:CardUI = hand.get_child(0)
	assert_eq(cui.mouse_filter, Control.MOUSE_FILTER_STOP,
		"carta en mano interactiva debe tener mouse_filter = STOP")


func test_set_interactive_false_disables_existing_cards() -> void:
	var hand := _spawn_hand()
	hand.add_card(_make_dummy_card())
	hand.add_card(_make_dummy_card())
	await get_tree().process_frame

	hand.set_interactive(false)

	for child in hand.get_children():
		assert_eq(child.mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"set_interactive(false) debe poner MOUSE_FILTER_IGNORE en cada CardUI")


func test_set_interactive_true_reenables_existing_cards() -> void:
	var hand := _spawn_hand()
	hand.add_card(_make_dummy_card())
	hand.add_card(_make_dummy_card())
	await get_tree().process_frame

	hand.set_interactive(false)
	hand.set_interactive(true)

	for child in hand.get_children():
		assert_eq(child.mouse_filter, Control.MOUSE_FILTER_STOP,
			"set_interactive(true) debe restaurar MOUSE_FILTER_STOP")


# ============================================================
#  add_card propaga el estado actual a la carta nueva
# ============================================================

func test_add_card_while_disabled_creates_non_interactive_card() -> void:
	# El caso del bug: durante draw_cards_animated, la mano esta
	# desactivada y las cartas se añaden una a una. Las recien añadidas
	# tambien deben respetar el estado.
	var hand := _spawn_hand()
	hand.set_interactive(false)

	hand.add_card(_make_dummy_card())
	await get_tree().process_frame

	var cui:CardUI = hand.get_child(0)
	assert_eq(cui.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"cartas añadidas mientras la mano esta desactivada deben heredar el estado")


func test_add_card_while_enabled_creates_interactive_card() -> void:
	var hand := _spawn_hand()
	hand.set_interactive(true)

	hand.add_card(_make_dummy_card())
	await get_tree().process_frame

	var cui:CardUI = hand.get_child(0)
	assert_eq(cui.mouse_filter, Control.MOUSE_FILTER_STOP,
		"cartas añadidas con la mano activa deben quedar interactivas")
