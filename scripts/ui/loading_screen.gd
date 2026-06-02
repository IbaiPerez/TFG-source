extends Control
class_name LoadingScreen

var seed_value: int = 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = UITheme.PARCHMENT
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "Generando mapa..."
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", UITheme.BORDER_BROWN)
	vbox.add_child(title)

	if seed_value != 0:
		var seed_label := Label.new()
		seed_label.text = "Semilla: %d" % seed_value
		seed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		seed_label.add_theme_font_size_override("font_size", 14)
		seed_label.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
		vbox.add_child(seed_label)
