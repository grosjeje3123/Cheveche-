class_name PlaceholderArt
extends Control
## Gabarit d'image provisoire. Volontairement abstrait et étiqueté « provisoire » :
## on ne fabrique jamais une fausse illustration qui prétendrait représenter le sujet.


func _init(description := "") -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Ds.box(Ds.IVORY_DEEP, Color.TRANSPARENT, 0, 28, 28, 18, 18))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", Ds.S2)
	v.custom_minimum_size = Vector2(400, 0)
	panel.add_child(v)

	var kicker := Ds.label("Image provisoire", Ds.Role.OVERLINE, Ds.TERRACOTTA)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(kicker)
	var text := Ds.label(description, Ds.Role.NUMERAL, Ds.INK, true)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(text)
	var note := Ds.label("Aucune image vérifiée pour ce dossier", Ds.Role.CAPTION, Ds.INK_SOFT, true)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(note)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Ds.IVORY_DEEP)
	var hatch := Color(Ds.SAGE, 0.22)
	var k := -size.y
	while k < size.x:
		draw_line(Vector2(k, size.y), Vector2(k + size.y, 0.0), hatch, 1.0)
		k += 22.0
	draw_rect(Rect2(Vector2(14, 14), size - Vector2(28, 28)), Color(Ds.INK, 0.22), false, 1.0)
