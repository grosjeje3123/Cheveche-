class_name DsLevel
extends Control
## Difficulté d'un dossier : cinq barres montantes, de 1 à 5 pleines.
## 0 : rien n'est dessiné.

const BARS := 5

var level := 0:
	set(value):
		level = clampi(value, 0, BARS)
		queue_redraw()
var color := Ds.IVORY:
	set(value):
		color = value
		queue_redraw()
## Opacité des barres vides.
var empty_alpha := 0.3


func _init(bar_height := 18.0) -> void:
	custom_minimum_size = Vector2(bar_height * 1.75, bar_height)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if level <= 0:
		return
	var h := size.y
	var w := size.x
	var bar := w * 0.14
	var gap := (w - bar * BARS) / float(BARS - 1)
	for i in BARS:
		var bh := h * (0.36 + 0.16 * i)
		var r := Rect2(i * (bar + gap), h - bh, bar, bh)
		var c := color if i < level else Color(color, color.a * empty_alpha)
		draw_rect(r, c)
