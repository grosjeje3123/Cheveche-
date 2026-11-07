class_name DsStamp
extends Control
## Tampon de fiche complète, comme sur un carnet : deux anneaux, légèrement penché.
## - Grand (page « Fiche complète ») : un texte en arc en haut (`top_text`) et en bas (`bottom_text`),
##   le pictogramme de la discipline au centre.
## - Tampon dateur (fin du défi du jour) : `center_text` (le jour, « 5 ») et `center_caption` (« nov. »)
##   au centre, à la place du pictogramme. Sans texte en arc (petit tampon de la carte du défi, sur la couverture),
##   le disque intérieur s'élargit pour que la date reste lisible.
## - Petit (fiche de la couverture) : `with_text` faux, une coche au centre.
## `filled` (fiche sans faute) : le disque intérieur est plein, le motif ressort en clair.

var color := Ds.TERRACOTTA:
	set(value):
		color = value
		queue_redraw()
var discipline := "":
	set(value):
		discipline = value
		queue_redraw()
var top_text := "":
	set(value):
		top_text = value
		queue_redraw()
var bottom_text := "":
	set(value):
		bottom_text = value
		queue_redraw()
var center_text := "":
	set(value):
		center_text = value
		queue_redraw()
var center_caption := "":
	set(value):
		center_caption = value
		queue_redraw()
## Taille des textes en arc, en part du rayon (plus grand sur un petit tampon, pour rester lisible).
var arc_text_scale := 0.15
var with_text := true:
	set(value):
		with_text = value
		queue_redraw()
var filled := false:
	set(value):
		filled = value
		queue_redraw()
## Couleur du motif sur le disque plein.
var paper := Ds.IVORY
## Inclinaison (en radians) : un tampon n'est jamais posé tout droit.
var tilt := -0.16


func _init(diameter := 300.0) -> void:
	custom_minimum_size = Vector2(diameter, diameter)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = custom_minimum_size / 2.0


func _draw() -> void:
	var r := minf(size.x, size.y) / 2.0
	if r <= 2.0:
		return
	var c := size / 2.0
	draw_set_transform(c, tilt)
	var outer := r * (0.97 if with_text else 0.92)
	draw_arc(Vector2.ZERO, outer, 0.0, TAU, 96, color, maxf(2.0, r * 0.05), true)
	var date_only := with_text and top_text == "" and bottom_text == "" and center_text != ""
	var inner := r * (0.80 if date_only else 0.70)
	if filled:
		draw_circle(Vector2.ZERO, inner, color)
	else:
		draw_arc(Vector2.ZERO, inner, 0.0, TAU, 96, color, maxf(1.5, r * 0.022), true)
	var motif := paper if filled else color

	if date_only:
		_center_date(inner, motif, 0.3)
	elif with_text:
		var band := (outer + inner) / 2.0
		var font_size := int(r * arc_text_scale)
		_arc_text(top_text, band, -PI / 2.0, true, font_size)
		_arc_text(bottom_text, band, PI / 2.0, false, font_size)
		# Deux petits points pour séparer les deux textes, à gauche et à droite.
		for side in [-1.0, 1.0]:
			draw_circle(Vector2(side * band, 0.0), maxf(2.0, r * 0.028), color)
		var icon := Ds.discipline_icon(discipline) if center_text == "" else null
		if center_text != "":
			_center_date(inner, motif)
		elif icon != null:
			var s := minf(96.0, inner * 1.05)
			draw_texture_rect(icon, Rect2(Vector2(-s, -s) / 2.0, Vector2(s, s)), false, motif)
	else:
		# Une coche, au trait.
		var k := inner * 0.62
		var pts := PackedVector2Array([Vector2(-0.55, 0.02) * k, Vector2(-0.12, 0.45) * k, Vector2(0.62, -0.42) * k])
		draw_polyline(pts, motif, maxf(2.0, r * 0.11), true)
	draw_set_transform(Vector2.ZERO)


# Au centre du tampon dateur : le jour en grand chiffre serif, le mois en petites capitales dessous.
func _center_date(inner: float, ink: Color, caption_scale := 0.24) -> void:
	var big_font: Font = Ds.SERIF_MEDIUM
	var big_size := int(inner * 0.95)
	var small_font: Font = Ds.SANS_SEMIBOLD
	var small_size := int(inner * caption_scale)
	var big_w := big_font.get_string_size(center_text, HORIZONTAL_ALIGNMENT_LEFT, -1, big_size).x
	var cap := center_caption.to_upper()
	var spacing := small_size * 0.2
	var cap_w := small_font.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, small_size).x + spacing * maxi(cap.length() - 1, 0)
	# Hauteur visible du chiffre (environ la hauteur des capitales) et du mois, séparés par un petit blanc.
	var big_h := big_font.get_ascent(big_size) * 0.72
	var small_h := small_font.get_ascent(small_size) * 0.72
	var gap := inner * 0.1
	var top := -(big_h + gap + small_h) / 2.0
	draw_string(big_font, Vector2(-big_w / 2.0, top + big_h), center_text, HORIZONTAL_ALIGNMENT_LEFT, -1, big_size, ink)
	var x := -cap_w / 2.0
	for ch in cap:
		draw_string(small_font, Vector2(x, top + big_h + gap + small_h), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, small_size, ink)
		x += small_font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, small_size).x + spacing


# Texte en capitales espacées le long d'un cercle de rayon `radius`, centré sur l'angle `center_angle`.
# En haut, il se lit de gauche à droite en tournant dans le sens horaire ; en bas, dans l'autre sens,
# pour rester à l'endroit.
func _arc_text(text: String, radius: float, center_angle: float, on_top: bool, font_size: int) -> void:
	if text == "":
		return
	var font: Font = Ds.SANS_SEMIBOLD
	var t := text.to_upper()
	var spacing := font_size * 0.22
	var widths: Array[float] = []
	var total := 0.0
	for ch in t:
		var w := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + spacing
		widths.append(w)
		total += w
	total -= spacing
	var direction := 1.0 if on_top else -1.0
	var angle := center_angle - direction * (total / radius) / 2.0
	var ascent := font.get_ascent(font_size)
	var descent := font.get_descent(font_size)
	for i in t.length():
		var w: float = widths[i]
		var mid := angle + direction * (w - spacing) / 2.0 / radius
		var pos := Vector2(cos(mid), sin(mid)) * radius
		var rot := mid + PI / 2.0 if on_top else mid - PI / 2.0
		var glyph_w := w - spacing
		draw_set_transform(size / 2.0 + pos.rotated(tilt), rot + tilt)
		draw_string(font, Vector2(-glyph_w / 2.0, (ascent - descent) / 2.0), t[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		angle += direction * w / radius
	draw_set_transform(size / 2.0, tilt)
