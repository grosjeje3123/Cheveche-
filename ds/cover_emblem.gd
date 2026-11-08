class_name CoverEmblem
extends Control
## L'emblème de la couverture : la chouette dans un cercle fin, une petite étoile à l'ocre sur le trait ;
## ou, si on lui donne une image, l'illustration du jeu seule (elle a déjà son disque : pas de cercle).
## `play()` joue l'ouverture : le cercle se dessine, la chouette apparaît, les étoiles s'allument.

## Taille par défaut ; la couverture en choisit une plus petite pour laisser la place aux tiroirs.
const SIZE := 450.0

var ring_t := 1.0: set = _set_ring    # 0 à 1 : part du cercle déjà tracée
var fill_t := 1.0: set = _set_fill    # 0 à 1 : intensité du disque sauge
var star_t := 1.0: set = _set_star    # 0 à 1 : taille des étoiles
## Sur fond sombre (couverture « cabinet ») : un médaillon ivoire cerclé d'ocre, sans étoiles.
var on_dark := false
## Les petites étoiles ocre sur le cercle (désactivées sur la couverture actuelle).
var show_stars := true

var _owl: Control  # la chouette (OwlMark) ou l'illustration (TextureRect)
var _tween: Tween
## Vrai si l'emblème montre une illustration : ni cercle ni disque, l'image occupe tout le carré.
var _illustrated := false


var _size := SIZE


func _init(emblem_size := SIZE, picture: Texture2D = null) -> void:
	_size = emblem_size
	custom_minimum_size = Vector2(_size, _size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if picture:
		_illustrated = true
		var pic := TextureRect.new()
		pic.texture = picture
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pic.pivot_offset = Vector2(_size, _size) / 2.0
		_owl = pic
		add_child(pic)
		return
	var owl := int(round(_size * 0.733))
	_owl = OwlMark.new(owl)
	_owl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_owl.offset_left = -owl / 2.0
	_owl.offset_right = owl / 2.0
	_owl.offset_top = -owl / 2.0 + _size * 0.022
	_owl.offset_bottom = owl / 2.0 + _size * 0.022
	_owl.pivot_offset = Vector2(owl, owl) / 2.0
	add_child(_owl)


## Change la taille de l'emblème illustré (la couverture l'agrandit sur les écrans allongés).
func set_emblem_size(px: float) -> void:
	if not _illustrated or is_equal_approx(px, _size):
		return
	_size = px
	custom_minimum_size = Vector2(px, px)
	_owl.pivot_offset = Vector2(px, px) / 2.0


## `first` : vrai au lancement (ouverture complète) ; faux quand on revient sur la couverture (fondu rapide).
func play(first := true) -> void:
	if _tween:
		_tween.kill()
	var k := 1.0 if first else 0.4
	ring_t = 0.0
	fill_t = 0.0
	star_t = 0.0
	_owl.modulate.a = 0.0
	_owl.scale = Vector2(0.94, 0.94)
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "ring_t", 1.0, 0.9 * k).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "fill_t", 1.0, 0.7 * k).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(_owl, "modulate:a", 1.0, 0.6 * k).set_delay(0.15 * k).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(_owl, "scale", Vector2.ONE, 0.8 * k).set_delay(0.15 * k) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "star_t", 1.0, 0.5 * k).set_delay(0.7 * k) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_ring(v: float) -> void:
	ring_t = v
	queue_redraw()


func _set_fill(v: float) -> void:
	fill_t = v
	queue_redraw()


func _set_star(v: float) -> void:
	star_t = v
	queue_redraw()


func _draw() -> void:
	if _illustrated:
		return
	var c := size / 2.0
	var r := _size / 2.0 - 8.0
	if on_dark:
		draw_circle(c, r - _size * 0.035, Color(Ds.IVORY, fill_t))
		if ring_t > 0.0:
			draw_arc(c, r, -PI / 2.0, -PI / 2.0 + TAU * ring_t, 160, Color(Ds.OCHRE, 0.9), 2.0, true)
		return
	draw_circle(c, r, Color(Ds.SAGE, 0.10 * fill_t))
	if ring_t > 0.0:
		draw_arc(c, r, -PI / 2.0, -PI / 2.0 + TAU * ring_t, 160, Color(Ds.SAGE, 0.85), 1.6, true)
	if show_stars and star_t > 0.05:  # en dessous, l'étoile fait moins d'un pixel : polygone dégénéré, le moteur proteste
		_star(c + Vector2.from_angle(deg_to_rad(-52.0)) * r, 11.0 * star_t)
		_star(c + Vector2.from_angle(deg_to_rad(-128.0)) * r, 6.0 * star_t)


# Étoile à quatre branches, comme sur une rose des vents.
func _star(p: Vector2, s: float) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var a := deg_to_rad(-90.0 + i * 45.0)
		pts.append(p + Vector2.from_angle(a) * (s if i % 2 == 0 else s * 0.3))
	draw_colored_polygon(pts, Ds.OCHRE)
