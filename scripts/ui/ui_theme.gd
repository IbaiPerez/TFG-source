class_name UITheme

## Paleta de colores y factories de StyleBox para toda la UI.
## Uso: UITheme.PARCHMENT, UITheme.make_panel_style(empire.color)

# --- Fondos ---
const PARCHMENT       := Color(0.97, 0.93, 0.85, 1.0)
const PARCHMENT_HOVER := Color(0.92, 0.85, 0.68, 1.0)

# --- Bordes ---
const BORDER_BROWN := Color(0.243, 0.153, 0.137, 1.0)

# --- Texto ---
const TEXT_DARK          := Color(0.15, 0.10, 0.08, 1.0)
const TEXT_SECONDARY     := Color(0.35, 0.30, 0.20, 1.0)
const TEXT_MUTED         := Color(0.40, 0.35, 0.30, 1.0)
const TEXT_OUTLINE       := Color(0.05, 0.05, 0.05, 1.0)
const TEXT_TITLE_OUTLINE := Color(0.15, 0.08, 0.00, 1.0)

# --- Valores de estado ---
const VALUE_POSITIVE := Color(0.10196079, 0.38823530, 0.10196079, 1.0)
const VALUE_NEGATIVE := Color.DARK_RED
const VALUE_NEUTRAL  := Color.BLACK

# --- Unidades militares ---
const TROOP_TYPE        := Color(0.30, 0.30, 0.50, 1.0)
const TROOP_MAINTENANCE := Color(0.45, 0.30, 0.15, 1.0)

# --- Miscelánea ---
const OVERLAY_DARK   := Color(0.00, 0.00, 0.00, 0.60)
const DISABLED_MUTED := Color(0.50, 0.50, 0.50, 1.0)
const EMPTY_MUTED    := Color(0.60, 0.40, 0.40, 1.0)


## Color según el signo de un valor: negativo → rojo, positivo → verde.
## Con `zero_is_neutral`, el 0 usa el color neutro (producción de casilla); si no,
## el 0 cuenta como positivo (p.ej. "+0" por turno).
static func signed_color(value: float, zero_is_neutral := false) -> Color:
	if value < 0.0:
		return VALUE_NEGATIVE
	if zero_is_neutral and value == 0.0:
		return VALUE_NEUTRAL
	return VALUE_POSITIVE


## Escribe en `label` un valor con signo y aplica su color: prefijo "+" para los
## valores no negativos (salvo el 0 neutro) y color según el signo. Unifica el
## bloque if v<0 / elif v==0 / else repetido en los paneles de stats y casilla.
static func apply_signed(label: Label, value: int, zero_is_neutral := false) -> void:
	label.add_theme_color_override("font_color", signed_color(value, zero_is_neutral))
	if value < 0 or (zero_is_neutral and value == 0):
		label.text = str(value)
	else:
		label.text = "+" + str(value)


static func make_panel_style(
		border_color: Color = BORDER_BROWN,
		border_width: int = 4,
		corner_radius: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PARCHMENT
	s.border_width_left   = border_width
	s.border_width_top    = border_width
	s.border_width_right  = border_width
	s.border_width_bottom = border_width
	s.border_color = border_color
	s.corner_radius_top_left     = corner_radius
	s.corner_radius_top_right    = corner_radius
	s.corner_radius_bottom_right = corner_radius
	s.corner_radius_bottom_left  = corner_radius
	s.content_margin_left   = 16.0
	s.content_margin_top    = 16.0
	s.content_margin_right  = 16.0
	s.content_margin_bottom = 16.0
	return s


static func make_panel_hover_style(
		border_color: Color = BORDER_BROWN,
		border_width: int = 4,
		corner_radius: int = 12) -> StyleBoxFlat:
	var s := make_panel_style(border_color, border_width, corner_radius)
	s.bg_color = PARCHMENT_HOVER
	return s
