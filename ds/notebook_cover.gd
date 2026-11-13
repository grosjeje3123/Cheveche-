class_name NotebookCover
extends Control
## La couverture d'un petit carnet, comme ceux qu'on range sur une étagère : toile de la couleur de la discipline,
## dos plus sombre, élastique, pictogramme gaufré en ivoire et étiquette de papier avec le nom et le nombre de pages.
## Le bloc des pages dépasse un peu à droite et en bas. Un carnet vierge est plus pâle ; celui des favoris porte
## une étoile ocre. Dessiné à la taille qu'on lui donne (sur l'étagère, ou en grand quand le carnet s'ouvre).

var color := Ds.SAGE:
	set(value):
		color = value
		queue_redraw()
var title := "":
	set(value):
		title = value
		queue_redraw()
var caption := "":
	set(value):
		caption = value
		queue_redraw()
## Pictogramme de la discipline (vide : aucun).
var discipline := "":
	set(value):
		discipline = value
		queue_redraw()
## Carnet des favoris : une étoile à la place du pictogramme.
var star := false:
	set(value):
		star = value
		queue_redraw()
## Carnet encore vierge : plus pâle.
var blank := false:
	set(value):
		blank = value
		queue_redraw()
## Le bloc des pages derrière la couverture (pas quand la couverture s'ouvre sur le carnet).
var with_pages := true


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _box(r: Rect2, c: Color, left: int, right: int) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.corner_radius_top_left = left
	sb.corner_radius_bottom_left = left
	sb.corner_radius_top_right = right
	sb.corner_radius_bottom_right = right
	sb.anti_aliasing = true
	draw_style_box(sb, r)


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 24.0 or h < 24.0:
		return
	var a := 0.5 if blank else 1.0
	var off := maxf(3.0, w * 0.022) if with_pages else 0.0
	if with_pages:
		# Le bloc des pages, qui dépasse de la couverture : papier, et le filet de la tranche.
		_box(Rect2(off, off, w - off, h - off), Color(Ds.IVORY_DEEP, a), 3, 6)
		draw_line(Vector2(w - off * 0.45, off * 2.0), Vector2(w - off * 0.45, h - off), Color(Ds.INK, 0.12 * a), 1.0)
	var cover := Rect2(0, 0, w - off, h - off)
	var cw := cover.size.x
	var ch := cover.size.y
	_box(cover, Color(color, a), 3, int(clampf(w * 0.04, 4.0, 14.0)))
	# Le dos, plus sombre, et son filet.
	var spine := cw * 0.1
	_box(Rect2(0, 0, spine, ch), Color(color.darkened(0.18), a), 3, 0)
	draw_line(Vector2(spine, 0), Vector2(spine, ch), Color(color.darkened(0.34), a), maxf(1.0, w * 0.006))
	# L'élastique.
	var band_x := cw * 0.85
	draw_rect(Rect2(band_x, 0, maxf(4.0, cw * 0.035), ch), Color(color.darkened(0.42), a))
	var cx := (spine + band_x) / 2.0
	# Le pictogramme, ivoire, comme gaufré dans la toile ; ou l'étoile des favoris.
	var icon_side := cw * 0.3
	var icon_center := Vector2(cx, ch * 0.3)
	if star:
		_star(icon_center, icon_side * 0.55, Color(Ds.OCHRE, a))
	elif discipline != "" and Ds.discipline_icon(discipline) != null:
		draw_texture_rect(Ds.discipline_icon(discipline), Rect2(icon_center - Vector2.ONE * icon_side / 2.0, Vector2.ONE * icon_side),
				false, Color(Ds.IVORY, 0.88 * a))
	# L'étiquette de papier : le nom, le nombre de pages.
	var lw := (band_x - spine) * 0.86
	var lh := ch * 0.27
	var label := Rect2(cx - lw / 2.0, ch * 0.55, lw, lh)
	_box(label, Color(Ds.IVORY_CARD, 0.96 if not blank else 0.75), 2, 2)
	var inset := maxf(3.0, lw * 0.035)
	draw_rect(label.grow(-inset), Color(color, 0.45 * a), false, 1.0)
	var title_size := int(clampf(cw * 0.105, 14.0, 64.0))
	var cap_size := int(clampf(cw * 0.085, 12.0, 44.0))
	var ink := Color(Ds.INK, 1.0 if not blank else 0.7)
	draw_string(Ds.SERIF_MEDIUM, Vector2(label.position.x, label.position.y + lh * 0.5), title, HORIZONTAL_ALIGNMENT_CENTER,
			lw, title_size, ink)
	draw_string(Ds.SANS, Vector2(label.position.x, label.position.y + lh * 0.8), caption, HORIZONTAL_ALIGNMENT_CENTER,
			lw, cap_size, Color(Ds.INK, 0.62 if not blank else 0.5))


func _star(center: Vector2, radius: float, c: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var r := radius if i % 2 == 0 else radius * 0.45
		var ang := -PI / 2.0 + i * PI / 5.0
		pts.append(center + Vector2(cos(ang), sin(ang)) * r)
	draw_colored_polygon(pts, c)
