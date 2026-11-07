class_name DsIcon
extends Control
## Icônes au trait (aucune image) : chevrons de navigation.

enum Kind { CHEVRON_LEFT, CHEVRON_RIGHT }

var kind := Kind.CHEVRON_LEFT:
	set(value):
		kind = value
		queue_redraw()
var color := Ds.INK:
	set(value):
		color = value
		queue_redraw()


func _init(k := Kind.CHEVRON_LEFT, icon_color := Ds.INK, icon_size := 40) -> void:
	kind = k
	color = icon_color
	custom_minimum_size = Vector2(icon_size, icon_size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size / 2.0
	var dir := -1.0 if kind == Kind.CHEVRON_LEFT else 1.0
	var pts := PackedVector2Array([
		Vector2(c.x - dir * 6.0, c.y - 13.0),
		Vector2(c.x + dir * 6.0, c.y),
		Vector2(c.x - dir * 6.0, c.y + 13.0)])
	draw_polyline(pts, color, 2.5, true)
