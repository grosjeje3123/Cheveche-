class_name NotebookPaper
extends Control
## Une page de carnet de naturaliste : papier clair, une trame de points très légère, et l'ombre de la reliure
## sur le bord gauche (la page tourne autour de ce bord). Le contenu de la page est posé dessus.

const DOT_STEP := 26.0
const SPINE_SHADOW := 30.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	clip_contents = true


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Ds.IVORY_CARD)
	var dot := Color(Ds.INK, 0.07)
	var y := DOT_STEP
	while y < size.y:
		var x := SPINE_SHADOW + DOT_STEP * 0.5
		while x < size.x:
			draw_circle(Vector2(x, y), 1.1, dot)
			x += DOT_STEP
		y += DOT_STEP
	# L'ombre de la reliure : de plus en plus claire vers la droite.
	var steps := 12
	for i in steps:
		var t := float(i) / steps
		draw_rect(Rect2(SPINE_SHADOW * t, 0, SPINE_SHADOW / steps + 0.5, size.y), Color(Ds.INK, 0.13 * (1.0 - t) * (1.0 - t)))
	draw_line(Vector2(size.x - 0.5, 0), Vector2(size.x - 0.5, size.y), Color(Ds.INK, 0.1), 1.0)
