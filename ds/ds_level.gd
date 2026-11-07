class_name DsLevel
extends Control
## Niveau d'un dossier : trois barres montantes, 1 à 3 pleines (facile, moyen, difficile).
## 0 : rien n'est dessiné.

var level := 0:
	set(value):
		level = clampi(value, 0, 3)
		queue_redraw()
var color := Ds.IVORY:
	set(value):
		color = value
		queue_redraw()
## Opacité des barres vides.
var empty_alpha := 0.3


func _init(bar_height := 18.0) -> void:
	custom_minimum_size = Vector2(bar_height * 1.35, bar_height)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if level <= 0:
		return
	var h := size.y
	var w := size.x
	var bar := w * 0.24
	var gap := (w - bar * 3.0) / 2.0
	for i in 3:
		var bh := h * (0.45 + 0.275 * i)
		var r := Rect2(i * (bar + gap), h - bh, bar, bh)
		var c := color if i < level else Color(color, color.a * empty_alpha)
		draw_rect(r, c)
