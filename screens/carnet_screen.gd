class_name CarnetScreen
extends Control
## « Carnet » : tout ce que le joueur a découvert, rangé par discipline, comme un carnet de curiosités. Chaque dossier
## joué (trouvé ou manqué) y garde sa vignette, son titre et sa réponse ; on le touche pour relire l'image, la question,
## l'explication et l'anecdote, et le garder en favori. Un onglet par état : tout, à revoir (pas encore acquis), acquis,
## favoris. Rien de nouveau n'est montré : seuls les dossiers déjà joués, dont on a déjà vu la réponse.
## On y arrive depuis la couverture ; la flèche (ou le bouton Retour) ramène de la fiche à la liste, puis à la couverture.

signal closed

const THUMB := 88
const TABS := ["Tout", "À revoir", "Acquis", "Favoris"]
enum Tab { ALL, REVIEW, ACQUIRED, FAVORITES }
const PHOTO_SHADER := preload("res://ds/rounded_photo.gdshader")
const PHOTO_HEIGHT := 360

var _pack: QuestionPack
var _save: SaveStore
var _scroll: ScrollContainer
var _body: VBoxContainer
var _top: Control  # le résumé et les onglets : cachés sur la fiche d'un dossier
var _count: Label
var _count_caption: Label
var _tab_buttons: Array[Button] = []
var _tab_marks: Array[ColorRect] = []
var _tab := Tab.ALL
## Dossier ouvert ("" : la liste).
var detail_id := ""
var _list_scroll := 0
var _favorite_button: Button
var _favorite_star: DsStar


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
	head.add_child(Ds.page_top("Carnet", back))

	var top := MarginContainer.new()
	_top = top
	top.add_theme_constant_override("margin_left", Ds.MARGIN)
	top.add_theme_constant_override("margin_right", Ds.MARGIN)
	top.add_theme_constant_override("margin_top", Ds.S3)
	page.add_child(top)
	var top_col := VBoxContainer.new()
	top_col.add_theme_constant_override("separation", 0)
	top.add_child(top_col)
	# Le compte des découvertes, comme sur « Mes résultats » : un grand chiffre, sa légende à côté.
	var count_row := HBoxContainer.new()
	count_row.add_theme_constant_override("separation", Ds.S3)
	top_col.add_child(count_row)
	_count = Ds.label("0", Ds.Role.TITLE, Ds.INK)
	_count.add_theme_font_size_override("font_size", 60)
	count_row.add_child(_count)
	_count_caption = Ds.label("", Ds.Role.SMALL, Ds.INK_SOFT, true)
	_count_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_row.add_child(_count_caption)
	top_col.add_child(Ds.spacer(Ds.S3))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 0)
	top_col.add_child(tabs)
	for i in TABS.size():
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 0)
		tabs.add_child(cell)
		var b := Button.new()
		b.theme_type_variation = "FlatButton"
		b.text = TABS[i]
		b.custom_minimum_size = Vector2(0, 64)
		b.add_theme_font_size_override("font_size", 24)
		b.pressed.connect(_set_tab.bind(i))
		cell.add_child(b)
		_tab_buttons.append(b)
		var mark := ColorRect.new()
		mark.custom_minimum_size = Vector2(0, 3)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(mark)
		_tab_marks.append(mark)
	top_col.add_child(Ds.rule(Ds.RULE, 1))

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	page.add_child(_scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", Ds.MARGIN)
	margin.add_theme_constant_override("margin_right", Ds.MARGIN)
	margin.add_theme_constant_override("margin_top", Ds.S3)
	margin.add_theme_constant_override("margin_bottom", 72)
	_scroll.add_child(margin)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 0)
	margin.add_child(_body)


## À l'ouverture : la liste, sur l'onglet laissé la dernière fois.
func open() -> void:
	detail_id = ""
	_show_list(0)


## La flèche : de la fiche d'un dossier à la liste, de la liste à la couverture.
func back() -> void:
	if detail_id != "":
		detail_id = ""
		_show_list(_list_scroll)
	else:
		closed.emit()


func _set_tab(i: int) -> void:
	_tab = i as Tab
	_show_list(0)


func _clear() -> void:
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()


func _passes(q: Dictionary) -> bool:
	match _tab:
		Tab.REVIEW:
			return not _save.is_acquired(q["id"])
		Tab.ACQUIRED:
			return _save.is_acquired(q["id"])
		Tab.FAVORITES:
			return _save.is_favorite(q["id"])
	return true


## Tous les dossiers du jeu, niveau 2 compris.
func _all() -> Array:
	return _pack.questions + _pack.expert


# ---------- La liste ----------

func _show_list(scroll_to: int) -> void:
	_top.visible = true
	_clear()
	var played := _save.played_in(_all())
	var acquired := _save.acquired_in(played)
	_count.text = str(played.size())
	_count_caption.text = ("découverte%s, dont %d acquise%s" % ["s" if played.size() > 1 else "", acquired, "s" if acquired > 1 else ""]) \
			if not played.is_empty() else "découverte pour l’instant"
	for i in _tab_buttons.size():
		var on := i == _tab
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			_tab_buttons[i].add_theme_color_override(c, Ds.INK if on else Ds.INK_SOFT)
		_tab_marks[i].color = Ds.TERRACOTTA if on else Color.TRANSPARENT

	var shown := 0
	for d in ProgressScreen.DISCIPLINES:
		var qs: Array = _save.played_in(_pack.questions_in(d) + _pack.questions_in(d, 2)).filter(_passes)
		if qs.is_empty():
			continue
		qs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _pack.dossier_number(a) < _pack.dossier_number(b))
		_body.add_child(Ds.spacer(Ds.S4 if shown > 0 else Ds.S2))
		var got := _save.acquired_in(qs)
		var right := ("%d, dont %d acquis" % [qs.size(), got]) if _tab == Tab.ALL else "%d dossier%s" % [qs.size(), "s" if qs.size() > 1 else ""]
		_body.add_child(Ds.section_header(d, right))
		for q in qs:
			_body.add_child(_row(q))
			_body.add_child(Ds.rule(Ds.RULE, 1))
		shown += qs.size()
	if shown == 0:
		_body.add_child(Ds.spacer(Ds.S4))
		var words := "Votre carnet se remplit à chaque dossier joué : l’image, la réponse et l’anecdote y restent, à relire quand vous voulez."
		match _tab:
			Tab.REVIEW:
				words = "Rien à revoir : tous les dossiers joués sont acquis." if not played.is_empty() else words
			Tab.ACQUIRED:
				words = "Un dossier est acquis quand vous l’avez retrouvé sans indice, plusieurs jours de suite." if not played.is_empty() else words
			Tab.FAVORITES:
				words = "Pas encore de favori : touchez l’étoile d’un dossier pour le garder ici."
		_body.add_child(Ds.label(words, Ds.Role.BODY, Ds.INK_SOFT, true))
	await get_tree().process_frame
	_scroll.scroll_vertical = scroll_to


# Une ligne du carnet : la vignette, le titre du dossier, sa réponse, son état ; une étoile s'il est en favori.
func _row(q: Dictionary) -> Button:
	var b := Button.new()
	b.theme_type_variation = "FlatButton"
	b.custom_minimum_size = Vector2(0, THUMB + Ds.S3 * 2)
	b.pressed.connect(_show_detail.bind(String(q["id"])))
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.add_theme_constant_override("separation", Ds.S3)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var thumb := _photo(q, Vector2(THUMB, THUMB), true)
	thumb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(thumb)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(col)
	var title := Ds.label(str(q.get("titre", q["reponse_courte"])), Ds.Role.CLUE, Ds.INK)
	title.add_theme_font_size_override("font_size", 28)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(title)
	# La réponse, sauf quand le titre la dit déjà (« Baleine bleue », « La baleine bleue »).
	if not _same_words(str(q.get("titre", "")), str(q["reponse_courte"])):
		var answer := Ds.label(str(q["reponse_courte"]), Ds.Role.SMALL, Ds.INK_SOFT)
		answer.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		col.add_child(answer)
	var st := _save.stage(q["id"])
	col.add_child(Ds.label(stage_word(st), Ds.Role.CAPTION, stage_color(st)))
	for c in col.get_children():
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _save.is_favorite(q["id"]):
		h.add_child(DsStar.new(26.0, Ds.OCHRE, true))
	return b


## Vrai si l'un des deux textes contient l'autre, sans tenir compte des articles ni des majuscules.
static func _same_words(a: String, b: String) -> bool:
	var na := _plain(a)
	var nb := _plain(b)
	return na != "" and nb != "" and (na.contains(nb) or nb.contains(na))


static func _plain(t: String) -> String:
	var x := " " + t.to_lower().replace("’", "'") + " "
	for art in [" le ", " la ", " les ", " l'", " un ", " une ", " des "]:
		x = x.replace(art, " ")
	return x.strip_edges()


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


# La photo d'un dossier, recadrée et arrondie (vignette dans la liste, grande image sur la fiche).
func _photo(q: Dictionary, box: Vector2, thumb: bool) -> Control:
	var path := _pack.thumb_path(q) if thumb else (_pack.image_path(q) if _pack.has_verified_image(q) else "")
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
	m.set_shader_parameter("corner_radius", 4.0)
	r.material = m
	if not thumb:
		r.resized.connect(func() -> void: m.set_shader_parameter("rect_size", r.size))
	return r


# ---------- La fiche d'un dossier ----------

func _show_detail(id: String) -> void:
	var q := _pack.by_id(id)
	if q.is_empty():
		return
	_list_scroll = _scroll.scroll_vertical
	detail_id = id
	_top.visible = false
	_clear()
	var discipline := _pack.collection_of(q)
	_body.add_child(Ds.spacer(Ds.S2))
	var tag := HBoxContainer.new()
	tag.add_theme_constant_override("separation", Ds.S2)
	_body.add_child(tag)
	var color := Ds.discipline_color(discipline)
	if Ds.discipline_icon(discipline) != null:
		var ic := Ds.icon_rect(discipline, 28, color)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tag.add_child(ic)
	var where := Ds.label("%s, %s" % [discipline, String(q["categorie"]).to_lower()], Ds.Role.OVERLINE, Ds.INK_SOFT)
	where.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tag.add_child(where)
	tag.add_child(Ds.label("nº %d" % _pack.dossier_number(q), Ds.Role.OVERLINE, Ds.INK_SOFT))
	_body.add_child(Ds.spacer(Ds.S3))
	if _pack.has_verified_image(q):
		var photo := _photo(q, Vector2(0, PHOTO_HEIGHT), false)
		photo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_body.add_child(photo)
		_body.add_child(Ds.spacer(Ds.S3))
	_body.add_child(Ds.label(str(q["question"]), Ds.Role.QUESTION, Ds.INK, true))
	_body.add_child(Ds.spacer(Ds.S3))
	_body.add_child(Ds.label("La réponse", Ds.Role.OVERLINE, Ds.INK_SOFT))
	_body.add_child(Ds.label(str(q["reponse_courte"]), Ds.Role.HEADING, Ds.INK, true))
	_body.add_child(Ds.spacer(Ds.S2))
	var why := Ds.label(str(q["explication"]), Ds.Role.BODY, Ds.INK, true)
	why.add_theme_font_size_override("font_size", 25)
	_body.add_child(why)
	var anecdote := str(q.get("anecdote", "")).strip_edges()
	if anecdote != "":
		_body.add_child(Ds.spacer(Ds.S3))
		_body.add_child(Ds.rule())
		_body.add_child(Ds.spacer(Ds.S2))
		_body.add_child(Ds.label("Le saviez-vous ?", Ds.Role.OVERLINE, Ds.INK_SOFT))
		var fun := Ds.label(anecdote, Ds.Role.NUMERAL, Ds.INK, true)
		fun.add_theme_font_size_override("font_size", 26)
		_body.add_child(fun)
	var credit := _pack.credit_line(q)
	if credit != "":
		_body.add_child(Ds.spacer(Ds.S2))
		_body.add_child(Ds.label(credit, Ds.Role.CAPTION, Ds.INK_SOFT, true))
	_body.add_child(Ds.spacer(Ds.S4))
	_body.add_child(Ds.rule())
	_body.add_child(Ds.spacer(Ds.S3))
	var st := _save.stage(id)
	_body.add_child(Ds.label(stage_line(st, _save.return_day(id)), Ds.Role.SMALL, stage_color(st), true))
	_body.add_child(Ds.spacer(Ds.S3))
	# Le favori : une étoile et quelques mots, sur toute la largeur.
	_favorite_button = Button.new()
	_favorite_button.theme_type_variation = "FlatButton"
	_favorite_button.custom_minimum_size = Vector2(0, 72)
	_favorite_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_favorite_button.add_theme_font_size_override("font_size", 25)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_favorite_button.add_theme_color_override(c, Ds.INK)
	_favorite_button.add_theme_constant_override("h_separation", Ds.S2)
	_favorite_star = DsStar.new(30.0, Ds.OCHRE, false)
	_favorite_star.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_favorite_star.offset_left = 0
	_favorite_star.offset_right = 30
	_favorite_star.offset_top = -15
	_favorite_star.offset_bottom = 15
	_favorite_button.add_child(_favorite_star)
	_favorite_button.pressed.connect(func() -> void:
		_save.set_favorite(id, not _save.is_favorite(id))
		_refresh_favorite(id))
	_body.add_child(_favorite_button)
	_refresh_favorite(id)
	await get_tree().process_frame
	_scroll.scroll_vertical = 0


func _refresh_favorite(id: String) -> void:
	var on := _save.is_favorite(id)
	_favorite_star.filled = on
	_favorite_button.text = "      " + ("Dans vos favoris" if on else "Garder en favori")


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
