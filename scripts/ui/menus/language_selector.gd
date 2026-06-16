extends OptionButton
## Selector de idioma reutilizable.
##
## Se autopobla con los idiomas soportados por el autoload `I18n`, refleja el
## idioma activo y lo cambia (con persistencia) al seleccionar una opción.
## Basta con añadir un OptionButton con este script a cualquier escena.

func _ready() -> void:
	clear()
	for i in I18n.SUPPORTED_LOCALES.size():
		var loc: String = I18n.SUPPORTED_LOCALES[i]
		add_item(I18n.LOCALE_NAMES.get(loc, loc), i)
		set_item_metadata(i, loc)
		if loc == I18n.get_current_locale():
			selected = i
	item_selected.connect(_on_item_selected)


func _on_item_selected(index: int) -> void:
	I18n.set_locale(get_item_metadata(index))
