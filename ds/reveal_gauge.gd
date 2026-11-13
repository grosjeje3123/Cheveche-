class_name RevealGauge
extends Control
## La jauge d'un dossier en image, sous l'image : la part dévoilée en grattant, et le barème en trois tiers
## (100 points sous un tiers, 60 jusqu'aux deux tiers, 30 au-delà). Le tiers en cours est écrit en encre pleine,
## les autres en gris ; deux petits repères marquent les paliers.

const HEIGHT := 46.0
const TRACK := 6.0

var fraction := 0.0:
	set(value):
		fraction = clampf(value, 0.0, 1.0)
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(0, HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var w := size.x
	if w <= 0.0:
		return
	var tier := RevealRules.visual_tier(fraction)
	var y := 6.0
	_bar(Rect2(0, y, w, TRACK), Ds.RULE)
	var ink: Color = [Ds.SAGE, Color("8C7440"), Ds.TERRACOTTA][tier]
	if fraction > 0.0:
		_bar(Rect2(0, y, maxf(TRACK, w * fraction), TRACK), ink)
	for t in RevealRules.VISUAL_THRESHOLDS:
		var x := roundf(w * float(t))
		draw_line(Vector2(x, y - 4), Vector2(x, y + TRACK + 4), Ds.INK_SOFT, 2.0)
	var labels := ["100 pts", "60 pts", "30 pts"]
	var bounds := [0.0] + RevealRules.VISUAL_THRESHOLDS + [1.0]
	for i in 3:
		var x0: float = w * float(bounds[i])
		var x1: float = w * float(bounds[i + 1])
		var c := Ds.INK if i == tier else Ds.INK_FAINT
		draw_string(Ds.SANS_MEDIUM if i == tier else Ds.SANS, Vector2(x0, y + TRACK + 26), labels[i], HORIZONTAL_ALIGNMENT_CENTER,
				x1 - x0, 19, c)


func _bar(r: Rect2, c: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(int(TRACK / 2.0))
	sb.anti_aliasing = true
	draw_style_box(sb, r)
