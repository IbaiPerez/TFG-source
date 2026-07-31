extends VBoxContainer
class_name ShopItemView

## Un artículo de la tienda: carta, precio, stock y botón de compra.
##
## Existe para que el panel deje de rebuscar entre los hijos de un contenedor
## genérico. Antes el artículo se guardaba en un `set_meta("shop_item")`, la
## etiqueta de stock se localizaba con otro `set_meta("is_stock_label")` y el
## refresco de asequibilidad recorría los hijos preguntando `child is Button`.
## Ese código se rompía en cuanto se añadiese un segundo botón o una segunda
## etiqueta al artículo, y el compilador no podía avisar de nada.
##
## Aquí cada artículo se conoce a sí mismo y sabe repintarse.

## El jugador ha pulsado comprar. El panel decide si la compra procede: esta vista
## no toca las stats.
signal purchase_requested(item: ShopItem)

var item: ShopItem

var _stock_label: Label
var _buy_button: Button


## Construye los widgets del artículo. `on_tooltip_requested` se cablea a la carta
## a través de [CardUIFactory], igual que en la vista de purga.
func setup(p_item: ShopItem, on_tooltip_requested: Callable) -> void:
	item = p_item
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	CardUIFactory.create(item.card, self, on_tooltip_requested)

	var price_label := Label.new()
	price_label.text = tr("FMT_GOLD") % item.price
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_color_override("font_color", UITheme.TEXT_DARK)
	price_label.add_theme_font_size_override("font_size", 14)
	add_child(price_label)

	# stock == -1 significa ilimitado: no se muestra contador.
	if item.stock != -1:
		_stock_label = Label.new()
		_stock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_stock_label.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
		_stock_label.add_theme_font_size_override("font_size", 12)
		add_child(_stock_label)

	_buy_button = Button.new()
	_buy_button.text = tr("SHOP_BUY")
	_buy_button.pressed.connect(func() -> void: purchase_requested.emit(item))
	add_child(_buy_button)


## Repinta stock, botón y atenuado según el oro disponible. Idempotente: el panel
## la llama sobre TODOS los artículos después de cualquier compra o purga, porque
## gastar oro puede dejar sin fondos a los demás.
func refresh(gold: int) -> void:
	if item == null or _buy_button == null:
		return

	if _stock_label != null:
		_stock_label.text = tr("SHOP_STOCK") % item.remaining_stock()

	if item.is_available():
		_buy_button.disabled = not item.can_afford(gold)
	else:
		# Agotado: solo se llega aquí comprando, porque el panel no llega a crear
		# vistas de artículos que ya vinieran sin stock.
		modulate = UITheme.DISABLED_MUTED
		_buy_button.disabled = true
		_buy_button.text = tr("SHOP_SOLD_OUT")
