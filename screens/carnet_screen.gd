class_name CarnetScreen
extends Control
## « Carnets » : une étagère de petits carnets de naturaliste, un par discipline, et celui des favoris. Chaque dossier
## joué (trouvé ou manqué) y a sa page : la photo scotchée, la question, la réponse en grand, l'explication, l'anecdote
## dans la marge, et un tampon qui dit où on en est (à revoir, à consolider, acquis). Rien de nouveau n'est montré :
## seuls les dossiers déjà joués, dont on a déjà vu la réponse.
##
## On touche un carnet : sa couverture s'ouvre sur le sommaire (la liste de ses pages). On tourne les pages du doigt
## (glisser vers la gauche ou la droite) ou avec les flèches du bas ; la page tourne autour de la reliure, avec un bruit
## de papier. On touche une ligne du sommaire pour aller à sa page. La flèche du haut (ou le bouton Retour) referme le
## carnet, puis ramène à la couverture du jeu.

signal closed

const FAVORITES := "Favoris"
const COVER_HEIGHT := 280
const SPINE := 24          # le dos du carnet ouvert, à gauche de la page
const PHOTO_BOX := 300     # hauteur de la photo scotchée, scotch compris
const TURN_TIME := 0.34
const OPEN_TIME := 0.42
const SWIPE := 70.0        # glissé horizontal minimal pour tourner une page
const PHOTO_SHADER := preload("res://ds/rounded_photo.gdshader")

var _pack: QuestionPack
var _save: SaveStore
var _title: Label
var _shelf_view: ScrollContainer
var _shelf_body: VBoxContainer
var _count: Label
var _count_caption: Label
var _book_view: VBoxContainer
var _frame: Control        # le carnet ouvert : la couverture qui dépasse autour de la page
var _paper_area: Control   # là où sont les pages
var _paper: NotebookPaper  # la page à l'écran
var _prev: Button
var _next: Button
var _page_label: Label
var _press_at := Vector2.INF
var _turning := false

## Le carnet ouvert ("" : l'étagère), la page à l'écran (0 : le sommaire) et le dossier de cette page ("" : aucun).
var book := ""
var page_index := 0
var detail_id := ""
## Les dossiers du carnet ouvert, dans l'ordre des pages.
var pages: Array = []
## Les couvertures de l'étagère, par nom de carnet (pour les tests).
var covers := {}
var _book_color := Ds.SAGE
var _favorite_button: Button
var _favorite_star: DsStar
var _stage_stamp: DsStamp


func setup(pack: QuestionPack, save: SaveStore) -> void:
	_pack = pack
	_save = save
	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", 0)
	add_child(page)
	var head := MarginContainer.new()
	head.add_theme_constant_override("margin_left", Ds.MARGIN)
	head.add_theme_constant_override("margin_right", Ds.MARGIN)
	head.add_theme_constant_override("margin_top", 24)
	page.add_child(head)
	var top := Ds.page_top("Carnets", back)
	head.add_child(top)
	_title = top.get_child(0).get_child(1) as Label

	# L'étagère.
	_shelf_view = ScrollContainer.new()
	_shelf_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shelf_view.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_shelf_view.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	page.add_child(_shelf_view)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", Ds.MARGIN)
	margin.add_theme_constant_override("margin_right", Ds.MARGIN)
	margin.add_theme_constant_override("margin_top", Ds.S3)
	margin.add_theme_constant_override("margin_bottom", 72)
	_shelf_view.add_child(margin)
	_shelf_body = VBoxContainer.new()
	_shelf_body.add_theme_constant_override("separation", 0)
	margin.add_child(_shelf_body)

	# Le carnet ouvert : la page, et en bas les flèches pour tourner.
	_book_view = VBoxContainer.new()
	_book_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_book_view.add_theme_constant_override("separation", 0)
	_book_view.visible = false
	page.add_child(_book_view)
	var around := MarginContainer.new()
	around.size_flags_vertical = Control.SIZE_EXPAND_FILL
	around.add_theme_constant_override("margin_left", Ds.MARGIN - 16)
	around.add_theme_constant_override("margin_right", Ds.MARGIN - 16)
	around.add_theme_constant_override("margin_top", Ds.S3)
	_book_view.add_child(around)
	_frame = Control.new()
	_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_frame.draw.connect(_draw_frame)
	around.add_child(_frame)
	_paper_area = Control.new()
	_paper_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_paper_area.offset_left = SPINE
	_paper_area.offset_top = 8
	_paper_area.offset_right = -14
	_paper_area.offset_bottom = -10
	_frame.add_child(_paper_area)
	var nav := HBoxContainer.new()
	nav.custom_minimum_size = Vector2(0, 88)
	nav.add_theme_constant_override("separation", 0)
	var nav_margin := MarginContainer.new()
	nav_margin.add_theme_constant_override("margin_left", Ds.MARGIN - 16)
	nav_margin.add_theme_constant_override("margin_right", Ds.MARGIN - 16)
	nav_margin.add_child(nav)
	_book_view.add_child(nav_margin)
	_prev = _arrow(DsIcon.Kind.CHEVRON_LEFT)
	_prev.pressed.connect(prev_page)
	nav.add_child(_prev)
	_page_label = Ds.label("", Ds.Role.OVERLINE, Ds.INK_SOFT)
	_page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nav.add_child(_page_label)
	_next = _arrow(DsIcon.Kind.CHEVRON_RIGHT)
	_next.pressed.connect(next_page)
	nav.add_child(_next)


func _arrow(kind: DsIcon.Kind) -> Button:
	var b := Button.new()
	b.theme_type_variation = "FlatButton"
	b.custom_minimum_size = Vector2(96, 88)
	var chev := DsIcon.new(kind, Ds.INK, 36)
	chev.set_anchors_preset(Control.PRESET_CENTER)
	chev.offset_left = -18
	chev.offset_right = 18
	chev.offset_top = -18
	chev.offset_bottom = 18
	b.add_child(chev)
	return b


## À l'ouverture : l'étagère.
func open() -> void:
	_show_shelf()


## La flèche : du carnet ouvert à l'étagère, de l'étagère à la couverture du jeu.
func back() -> void:
	if book != "":
		_show_shelf()
	else:
		closed.emit()


## Tous les dossiers du jeu, niveau 2 compris.
func _all() -> Array:
	return _pack.questions + _pack.expert


## Les dossiers joués d'un carnet, dans l'ordre des pages.
func book_pages(name: String) -> Array:
	var qs: Array = []
	if name == FAVORITES:
		for d in ProgressScreen.DISCIPLINES:
			qs += _sorted(_save.played_in(_pack.questions_in(d) + _pack.questions_in(d, 2)).filter(func(q): return _save.is_favorite(q["id"])))
	else:
		qs = _sorted(_save.played_in(_pack.questions_in(name) + _pack.questions_in(name, 2)))
	return qs


func _sorted(qs: Array) -> Array:
	qs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _pack.dossier_number(a) < _pack.dossier_number(b))
	return qs


static func _pages_word(n: int) -> String:
	return "vierge" if n == 0 else ("1 page" if n == 1 else "%d pages" % n)


func _clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


# ---------- L'étagère ----------

func _show_shelf() -> void:
	book = ""
	detail_id = ""
	page_index = 0
	pages = []
	_turning = false
	_title.text = "Carnets"
	_book_view.visible = false
	_shelf_view.visible = true
	_clear(_paper_area)
	_paper = null
	_clear(_shelf_body)
	covers.clear()
	var played := _save.played_in(_all())
	var acquired := _save.acquired_in(played)
	# Le compte des découvertes, comme sur « Mes résultats » : un grand chiffre, sa légende à côté.
	var count_row := HBoxContainer.new()
	count_row.add_theme_constant_override("separation", Ds.S3)
	_shelf_body.add_child(count_row)
	_count = Ds.label(str(played.size()), Ds.Role.TITLE, Ds.INK)
	_count.add_theme_font_size_override("font_size", 60)
	count_row.add_child(_count)
	_count_caption = Ds.label(("découverte%s, dont %d acquise%s" % ["s" if played.size() > 1 else "", acquired, "s" if acquired > 1 else ""])
			if not played.is_empty() else "découverte pour l’instant", Ds.Role.SMALL, Ds.INK_SOFT, true)
	_count_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_row.add_child(_count_caption)
	_shelf_body.add_child(Ds.spacer(Ds.S2))
	var words := "Touchez un carnet pour le feuilleter : chaque dossier joué y a sa page, avec l’image, la réponse et l’anecdote." \
			if not played.is_empty() else "Vos carnets se remplissent à chaque dossier joué : l’image, la réponse et l’anecdote y restent, à relire quand vous voulez."
	_shelf_body.add_child(Ds.label(words, Ds.Role.SMALL, Ds.INK_SOFT, true))
	_shelf_body.add_child(Ds.spacer(Ds.S5))
	var names: Array = ProgressScreen.DISCIPLINES.duplicate()
	names.append(FAVORITES)
	var row: HBoxContainer
	for i in names.size():
		if i % 3 == 0:
			row = HBoxContainer.new()
			row.add_theme_constant_override("separation", Ds.S4)
			_shelf_body.add_child(row)
		row.add_child(_shelf_book(names[i]))
		if i % 3 == 2 or i == names.size() - 1:
			# La planche de l'étagère, sous chaque rangée.
			var plank := ColorRect.new()
			plank.color = Color(Ds.INK, 0.2)
			plank.custom_minimum_size = Vector2(0, 5)
			plank.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_shelf_body.add_child(plank)
			_shelf_body.add_child(Ds.spacer(Ds.S5))
	_shelf_view.scroll_vertical = 0


func _shelf_book(name: String) -> Button:
	var n := book_pages(name).size()
	var b := Button.new()
	b.theme_type_variation = "FlatButton"
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, COVER_HEIGHT)
	b.pressed.connect(open_book.bind(name))
	var c := _cover_for(name, n)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.add_child(c)
	covers[name] = b
	return b


func _cover_for(name: String, n: int) -> NotebookCover:
	var c := NotebookCover.new()
	c.color = Ds.INK if name == FAVORITES else Ds.discipline_color(name)
	c.title = name
	c.caption = _pages_word(n)
	c.discipline = "" if name == FAVORITES else name
	c.star = name == FAVORITES
	c.blank = n == 0
	return c


# ---------- Le carnet ouvert ----------

## Ouvre un carnet sur son sommaire ; la couverture s'ouvre autour de la reliure.
func open_book(name: String) -> void:
	book = name
	pages = book_pages(name)
	page_index = 0
	detail_id = ""
	_book_color = Ds.INK if name == FAVORITES else Ds.discipline_color(name)
	_title.text = name
	_shelf_view.visible = false
	_book_view.visible = true
	_frame.queue_redraw()
	_clear(_paper_area)
	_paper = _make_paper(0)
	_paper_area.add_child(_paper)
	_update_nav()
	# La couverture, posée sur le carnet ouvert, qui s'ouvre (elle pivote autour du dos, à gauche).
	var front := _cover_for(name, pages.size())
	front.with_pages = false
	front.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame.add_child(front)
	_turning = true
	Feedback.say("page")
	await get_tree().process_frame
	if not is_instance_valid(front):
		return
	front.pivot_offset = Vector2(0, front.size.y / 2.0)
	var tw := create_tween()
	tw.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(front, "scale:x", 0.0, OPEN_TIME)
	tw.parallel().tween_property(front, "modulate", Color(0.78, 0.76, 0.72), OPEN_TIME)
	await tw.finished
	if is_instance_valid(front):
		front.queue_free()
	_turning = false


## La page suivante, la précédente, celle d'un dossier.
func next_page() -> void:
	if not _turning and book != "" and page_index < pages.size():
		_turn_to(page_index + 1)


func prev_page() -> void:
	if not _turning and book != "" and page_index > 0:
		_turn_to(page_index - 1)


func open_page(id: String) -> void:
	var i := pages.find_custom(func(q): return q["id"] == id)
	if i >= 0 and not _turning:
		_turn_to(i + 1)


# Tourne jusqu'à la page `to` : vers l'avant, la page à l'écran se replie vers la reliure et découvre la suivante,
# posée dessous ; vers l'arrière, la page précédente revient de la reliure par-dessus.
func _turn_to(to: int) -> void:
	var forward := to > page_index
	var old := _paper
	var fresh := _make_paper(to)
	_paper_area.add_child(fresh)
	page_index = to
	detail_id = "" if to == 0 else String(pages[to - 1]["id"])
	_update_nav()
	Feedback.say("page")
	if old == null:
		_paper = fresh
		return
	var turning: Control
	if forward:
		_paper_area.move_child(fresh, old.get_index())
		turning = old
	else:
		turning = fresh
		fresh.scale.x = 0.0
		fresh.modulate = Color(0.8, 0.78, 0.74)
	turning.pivot_offset = Vector2.ZERO
	# L'ombre que la page qui tourne jette sur celle de dessous, le long de son bord.
	var fold := Control.new()
	fold.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fold.draw.connect(_draw_fold.bind(fold, turning))
	_paper_area.add_child(fold)
	_paper_area.move_child(fold, turning.get_index())
	_paper = fresh
	_turning = true
	var tw := create_tween()
	tw.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_method(func(x: float) -> void:
		if is_instance_valid(turning):
			turning.scale.x = x
		fold.queue_redraw(), 1.0 if forward else 0.0, 0.0 if forward else 1.0, TURN_TIME)
	tw.parallel().tween_property(turning, "modulate", Color(0.8, 0.78, 0.74) if forward else Color.WHITE, TURN_TIME)
	await tw.finished
	if is_instance_valid(old):
		old.queue_free()
	if is_instance_valid(fold):
		fold.queue_free()
	_turning = false


# Une ombre douce à droite du bord de la page qui tourne, plus marquée à mi-course.
func _draw_fold(fold: Control, turning: Control) -> void:
	if not is_instance_valid(turning):
		return
	var k := turning.scale.x
	var x0 := turning.size.x * k
	var strength := sin(PI * clampf(k, 0.0, 1.0))
	var w := 54.0 * strength + 6.0
	var steps := 10
	for i in steps:
		var t := float(i) / steps
		fold.draw_rect(Rect2(x0 + w * t, 0, w / steps + 0.5, fold.size.y), Color(Ds.INK, 0.2 * strength * (1.0 - t) * (1.0 - t)))


func _update_nav() -> void:
	_page_label.text = "sommaire" if page_index == 0 else "page %d sur %d" % [page_index, pages.size()]
	_prev.disabled = page_index == 0
	_next.disabled = page_index >= pages.size()
	_prev.modulate.a = 0.25 if _prev.disabled else 1.0
	_next.modulate.a = 0.25 if _next.disabled else 1.0


# Le carnet ouvert : la couverture qui dépasse autour de la page, le dos à gauche, la tranche des pages à droite.
func _draw_frame() -> void:
	var s := _frame.size
	var sb := StyleBoxFlat.new()
	sb.bg_color = _book_color
	sb.corner_radius_top_left = 3
	sb.corner_radius_bottom_left = 3
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_right = 10
	sb.anti_aliasing = true
	_frame.draw_style_box(sb, Rect2(Vector2.ZERO, s))
	_frame.draw_rect(Rect2(0, 0, SPINE - 6, s.y), _book_color.darkened(0.18))
	_frame.draw_line(Vector2(SPINE - 6, 0), Vector2(SPINE - 6, s.y), _book_color.darkened(0.34), 1.5)
	# La tranche : deux feuilles qui dépassent sous la page.
	for k in 2:
		var d := 4.0 * (k + 1)
		_frame.draw_rect(Rect2(SPINE, 8 + d, s.x - SPINE - 14 + d, s.y - 18), Color(Ds.IVORY_DEEP).darkened(0.03 * k))
	_frame.draw_rect(Rect2(SPINE, 8, s.x - SPINE - 14, s.y - 18), Ds.IVORY_CARD)


# Glisser vers la gauche : la page suivante ; vers la droite : la précédente.
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or book == "":
		return
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		_press_at = mb.position
	elif _press_at != Vector2.INF:
		var d := mb.position - _press_at
		_press_at = Vector2.INF
		if absf(d.x) >= SWIPE and absf(d.x) > 1.5 * absf(d.y):
			get_viewport().set_input_as_handled()  # le doigt qui glisse ne touche pas aussi une ligne du sommaire
			if d.x < 0:
				next_page()
			else:
				prev_page()


# ---------- Les pages ----------

func _make_paper(i: int) -> NotebookPaper:
	var paper := NotebookPaper.new()
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	paper.add_child(scroll)
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.add_theme_constant_override("margin_left", NotebookPaper.SPINE_SHADOW + 10)
	m.add_theme_constant_override("margin_right", 26)
	m.add_theme_constant_override("margin_top", 24)
	m.add_theme_constant_override("margin_bottom", 28)
	scroll.add_child(m)
	# La page fait au moins la hauteur de la feuille : le tampon se pose en bas.
	scroll.resized.connect(func() -> void: m.custom_minimum_size.y = scroll.size.y)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	m.add_child(col)
	if i == 0:
		_fill_contents(col)
	else:
		_fill_page(col, pages[i - 1])
	return paper


# Le sommaire : le nom du carnet, le nombre de pages, une ligne par page.
func _fill_contents(col: VBoxContainer) -> void:
	var mark: Control = null
	if book == FAVORITES:
		mark = DsStar.new(40.0, Ds.OCHRE, true)
	elif Ds.discipline_icon(book) != null:
		mark = Ds.icon_rect(book, 44, _book_color)
	if mark != null:
		mark.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		col.add_child(mark)
	col.add_child(Ds.spacer(Ds.S2))
	col.add_child(Ds.label(book, Ds.Role.TITLE, Ds.INK))
	var got := _save.acquired_in(pages)
	var sub := ""
	if pages.is_empty():
		sub = "Pas encore de favori : touchez l’étoile en haut d’une page pour la garder ici." if book == FAVORITES \
				else "Ce carnet est encore vierge : chaque dossier de la discipline joué y ajoutera sa page."
	elif book == FAVORITES:
		sub = "%s gardée%s." % [_pages_word(pages.size()), "s" if pages.size() > 1 else ""]
	else:
		sub = "%s, dont %d acquise%s." % [_pages_word(pages.size()), got, "s" if got > 1 else ""]
	col.add_child(Ds.label(sub, Ds.Role.SMALL, Ds.INK_SOFT, true))
	if pages.is_empty():
		return
	col.add_child(Ds.spacer(Ds.S4))
	col.add_child(Ds.rule())
	for q in pages:
		col.add_child(_contents_row(q))
		col.add_child(Ds.rule())
	col.add_child(Ds.spacer(Ds.S4))
	col.add_child(Ds.label("Tournez les pages du doigt, ou touchez une ligne pour aller à sa page.", Ds.Role.CAPTION, Ds.INK_SOFT, true))


func _contents_row(q: Dictionary) -> Button:
	var b := Button.new()
	b.theme_type_variation = "FlatButton"
	b.custom_minimum_size = Vector2(0, 60)
	b.pressed.connect(open_page.bind(String(q["id"])))
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.add_theme_constant_override("separation", Ds.S2)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	if book == FAVORITES:
		var ic := Ds.icon_rect(_pack.collection_of(q), 22, Ds.discipline_color(_pack.collection_of(q)))
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ic)
	var num := Ds.label("nº %d" % _pack.dossier_number(q), Ds.Role.CAPTION, Ds.INK_SOFT)
	num.custom_minimum_size = Vector2(64, 0)
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(num)
	var title := Ds.label(str(q.get("titre", q["reponse_courte"])), Ds.Role.CLUE, Ds.INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(title)
	if _save.is_favorite(q["id"]) and book != FAVORITES:
		var st := DsStar.new(18.0, Ds.OCHRE, true)
		st.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(st)
	var stage := _save.stage(q["id"])
	var w := Ds.label(stage_word(stage), Ds.Role.CAPTION, stage_color(stage))
	w.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(w)
	for c in h.get_children():
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


# La page d'un dossier, comme dans un carnet de naturaliste.
func _fill_page(col: VBoxContainer, q: Dictionary) -> void:
	var id := String(q["id"])
	var discipline := _pack.collection_of(q)
	# En haut : la discipline et la catégorie, le numéro, l'étoile des favoris.
	var tag := HBoxContainer.new()
	tag.add_theme_constant_override("separation", Ds.S2)
	col.add_child(tag)
	if Ds.discipline_icon(discipline) != null:
		var ic := Ds.icon_rect(discipline, 24, Ds.discipline_color(discipline))
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tag.add_child(ic)
	var where := Ds.label(String(q["categorie"]), Ds.Role.OVERLINE, Ds.INK_SOFT)
	where.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	where.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	where.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag.add_child(where)
	var num := Ds.label("nº %d" % _pack.dossier_number(q), Ds.Role.OVERLINE, Ds.INK_SOFT)
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag.add_child(num)
	_favorite_button = Button.new()
	_favorite_button.theme_type_variation = "FlatButton"
	_favorite_button.custom_minimum_size = Vector2(56, 52)
	_favorite_star = DsStar.new(28.0, Ds.OCHRE, _save.is_favorite(id))
	_favorite_star.set_anchors_preset(Control.PRESET_CENTER)
	_favorite_star.offset_left = -14
	_favorite_star.offset_right = 14
	_favorite_star.offset_top = -14
	_favorite_star.offset_bottom = 14
	_favorite_button.add_child(_favorite_star)
	var star := _favorite_star
	_favorite_button.pressed.connect(func() -> void:
		_save.set_favorite(id, not _save.is_favorite(id))
		star.filled = _save.is_favorite(id))
	tag.add_child(_favorite_button)
	col.add_child(Ds.spacer(Ds.S2))
	# La photo, tirée sur papier et scotchée de travers, avec son crédit au crayon dessous.
	if _pack.has_verified_image(q):
		col.add_child(_taped_photo(q))
		var credit := _pack.credit_line(q)
		if credit != "":
			var cr := Ds.label(credit, Ds.Role.CAPTION, Ds.INK_SOFT, true)
			cr.add_theme_font_size_override("font_size", 16)
			cr.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			col.add_child(cr)
		col.add_child(Ds.spacer(Ds.S3))
	# La question, puis la réponse en grand.
	var question := Ds.label(str(q["question"]), Ds.Role.CLUE, Ds.INK_SOFT, true)
	question.add_theme_font_size_override("font_size", 23)
	col.add_child(question)
	col.add_child(Ds.spacer(Ds.S2))
	var answer := Ds.label(str(q["reponse_courte"]), Ds.Role.NUMERAL, Ds.INK, true)
	answer.add_theme_font_size_override("font_size", 42)
	col.add_child(answer)
	col.add_child(Ds.spacer(Ds.S2))
	var why := Ds.label(str(q["explication"]), Ds.Role.BODY, Ds.INK, true)
	why.add_theme_font_size_override("font_size", 21)
	why.add_theme_constant_override("line_spacing", 4)
	col.add_child(why)
	# L'anecdote, comme une note dans la marge : un trait ocre, l'italique.
	var anecdote := str(q.get("anecdote", "")).strip_edges()
	if anecdote != "":
		col.add_child(Ds.spacer(Ds.S3))
		var note := HBoxContainer.new()
		note.add_theme_constant_override("separation", Ds.S3)
		col.add_child(note)
		var line := ColorRect.new()
		line.color = Ds.OCHRE
		line.custom_minimum_size = Vector2(3, 0)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		note.add_child(line)
		var note_col := VBoxContainer.new()
		note_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		note_col.add_theme_constant_override("separation", 2)
		note.add_child(note_col)
		var head := Ds.label("Le saviez-vous ?", Ds.Role.OVERLINE, Color("8C7440"))
		head.add_theme_font_size_override("font_size", 20)
		note_col.add_child(head)
		var fun := Ds.label(anecdote, Ds.Role.NUMERAL, Ds.INK_STRONG, true)
		fun.add_theme_font_size_override("font_size", 22)
		note_col.add_child(fun)
	# En bas de la page : où on en est, en une phrase, et le tampon.
	var push := Ds.spacer(Ds.S3)
	push.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(push)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", Ds.S3)
	col.add_child(foot)
	var stage := _save.stage(id)
	var said := Ds.label(stage_line(stage, _save.return_day(id)), Ds.Role.SMALL, stage_color(stage), true)
	said.add_theme_font_size_override("font_size", 19)
	said.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	said.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	foot.add_child(said)
	_stage_stamp = DsStamp.new(118.0)
	_stage_stamp.color = stage_color(stage)
	_stage_stamp.top_text = {SaveStore.STAGE_ACQUIRED: "Acquis", SaveStore.STAGE_CONSOLIDATE: "À consolider"}.get(stage, "À revoir")
	_stage_stamp.bottom_text = _stamp_when(stage, _save.return_day(id))
	_stage_stamp.arc_text_scale = 0.2
	_stage_stamp.discipline = discipline
	_stage_stamp.tilt = -0.22 if stage == SaveStore.STAGE_ACQUIRED else 0.18
	foot.add_child(_stage_stamp)


## Le bas du tampon : « sans indice » pour un acquis, sinon quand le dossier revient.
static func _stamp_when(stage: int, return_day: String) -> String:
	if stage == SaveStore.STAGE_ACQUIRED:
		return "sans indice"
	if not Week.is_key(return_day):
		return "à rejouer"
	var days := Week.days_between(Week.today(), Week.from_key(return_day))
	return "à rejouer" if days <= 0 else ("demain" if days == 1 else "dans %d jours" % days)


# La photo d'un dossier, tirée sur papier (un liseré clair), un peu de travers, deux bouts de scotch en haut.
func _taped_photo(q: Dictionary) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, PHOTO_BOX)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shadow := ColorRect.new()
	shadow.color = Color(Ds.INK, 0.08)
	var sheet := ColorRect.new()
	sheet.color = Color("FCFAF5")
	var photo := _photo(q, Vector2.ZERO)
	sheet.add_child(photo)
	var tapes: Array[ColorRect] = []
	for k in 2:
		var t := ColorRect.new()
		t.color = Color("DED2B4", 0.78)
		t.size = Vector2(76, 24)
		t.pivot_offset = t.size / 2.0
		tapes.append(t)
	for c: Control in [shadow, sheet] + tapes:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(c)
	var tilt := -0.022 if _pack.dossier_number(q) % 2 == 0 else 0.018
	var layout := func() -> void:
		var w := holder.size.x * 0.92
		var h := holder.size.y - 22.0
		var at := Vector2((holder.size.x - w) / 2.0, 14.0)
		for r: Control in [shadow, sheet]:
			r.size = Vector2(w, h)
			r.pivot_offset = r.size / 2.0
			r.rotation = tilt
		sheet.position = at
		shadow.position = at + Vector2(3, 4)
		photo.position = Vector2(8, 8)
		photo.size = Vector2(w - 16, h - 16)
		tapes[0].position = at + Vector2(-14, -8)
		tapes[0].rotation = -0.62 + tilt
		tapes[1].position = at + Vector2(w - 62, -8)
		tapes[1].rotation = 0.62 + tilt
	holder.resized.connect(layout)
	return holder


## « à revoir », « à consolider », « acquis ».
static func stage_word(stage: int) -> String:
	match stage:
		SaveStore.STAGE_ACQUIRED:
			return "acquis"
		SaveStore.STAGE_CONSOLIDATE:
			return "à consolider"
	return "à revoir"


static func stage_color(stage: int) -> Color:
	match stage:
		SaveStore.STAGE_ACQUIRED:
			return Ds.SAGE
		SaveStore.STAGE_CONSOLIDATE:
			return Color("8C7440")  # l'ocre, foncé pour se lire sur le papier
	return Ds.TERRACOTTA


# La photo d'un dossier, recadrée et arrondie.
func _photo(q: Dictionary, box: Vector2) -> Control:
	var path := _pack.image_path(q) if _pack.has_verified_image(q) else ""
	if path == "":
		var none := ColorRect.new()
		none.color = Ds.IVORY_DEEP
		none.custom_minimum_size = box
		none.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return none
	var tex: Texture2D = load(path)
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.custom_minimum_size = box
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = PHOTO_SHADER
	m.set_shader_parameter("photo", tex)
	m.set_shader_parameter("photo_size", tex.get_size())
	m.set_shader_parameter("rect_size", box)
	m.set_shader_parameter("corner_radius", 2.0)
	r.material = m
	r.resized.connect(func() -> void: m.set_shader_parameter("rect_size", r.size))
	return r


## L'état d'un dossier en une phrase, avec sa date de retour.
static func stage_line(stage: int, return_day: String) -> String:
	if stage == SaveStore.STAGE_ACQUIRED:
		return "Acquis : vous l’avez retrouvé sans indice, plusieurs jours de suite."
	var when := ""
	if Week.is_key(return_day):
		var days := Week.days_between(Week.today(), Week.from_key(return_day))
		when = "il vous attend dans sa fiche" if days <= 0 else ("il revient demain" if days == 1 else "il revient dans %d jours" % days)
	var what := "À consolider" if stage == SaveStore.STAGE_CONSOLIDATE else "À revoir"
	return "%s : %s." % [what, when] if when != "" else "%s." % what
