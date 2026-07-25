extends RefCounted
class_name CardUIFactory

## Fábrica de la tarjeta visual (CardMenuUi) usada por las listas de cartas
## (tienda, pilas de mazo, selección en eventos, recuperación). Centraliza el
## preload de la escena, el add_child y el cableado de `tooltip_requested`, que
## antes se repetía verbatim en cada panel.

const CARD_MENU_UI = preload("uid://bt76i1liwhags")


## Crea la tarjeta para `card`, la añade a `container` y conecta su señal
## `tooltip_requested` a `on_tooltip_requested` (mostrar tooltip en unos paneles,
## seleccionar la carta en otros). Devuelve la instancia por si el llamante la
## necesita después.
static func create(card: Card, container: Node,
		on_tooltip_requested: Callable) -> CardMenuUi:
	var card_ui := CARD_MENU_UI.instantiate() as CardMenuUi
	container.add_child(card_ui)
	card_ui.card = card
	card_ui.tooltip_requested.connect(on_tooltip_requested)
	return card_ui
