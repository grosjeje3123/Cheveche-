class_name DsStar
extends Control
## Une petite étoile à cinq branches : pleine (favori) ou au trait (pas encore). Dessinée, pas tirée d'une police.

var filled := false:
	set(value):
		filled = value
		queue_redraw()
var color := Ds.OCHRE:
	set(value):
		color = value
		queue_redraw()


func _init(side := 28.0, star_color := Ds.OCHRE, is_filled := false) -> void:
	custom_minimum_size = Vector2(side, side)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = star_color
	filled = is_filled


func _draw() -> void:
	var c := size / 2.0
	var outer := minf(size.x, size.y) * 0.5
	var inner := outer * 0.45
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		var r := outer if i % 2 == 0 else inner
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	if filled:
		draw_colored_polygon(pts, color)
	else:
		pts.append(pts[0])
		draw_polyline(pts, color, 2.0, true)
