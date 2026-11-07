class_name DsSegments
extends Control
## Indicateur de progression : fins segments alignés.
## - Mode « étapes » : `total` segments, `current` en cours (terre cuite), précédents en anthracite.
## - Mode « remplissage » : `fills` (0 à 1 par segment), pour la progression par discipline.

var total := 5:
	set(value):
		total = value
		queue_redraw()
var current := 0:
	set(value):
		current = value
		queue_redraw()
var fills: PackedFloat32Array = PackedFloat32Array():
	set(value):
		fills = value
		queue_redraw()
var gap := 8.0
## Couleur du remplissage (mode « remplissage »).
var fill_color := Ds.SAGE
## Couleur de la piste non remplie (mode « remplissage »).
var track_color := Color(Ds.INK, 0.14)
var thickness := 3.0


func _init() -> void:
	custom_minimum_size = Vector2(0, 8)


func _draw() -> void:
	var count := fills.size() if fills.size() > 0 else total
	if count <= 0 or size.x <= 0.0:
		return
	var w := (size.x - gap * (count - 1)) / count
	var y := (size.y - thickness) / 2.0
	for i in count:
		var r := Rect2(i * (w + gap), y, w, thickness)
		if fills.size() > 0:
			draw_rect(r, track_color)
			draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(fills[i], 0.0, 1.0), thickness)), fill_color)
		elif i < current:
			draw_rect(r, Ds.INK)
		elif i == current:
			draw_rect(r, Ds.TERRACOTTA)
		else:
			draw_rect(r, Color(Ds.INK, 0.14))
