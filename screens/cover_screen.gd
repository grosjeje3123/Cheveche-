class_name CoverScreen
extends Control
## Couverture : sur le papier ivoire, la chouette, le titre, le défi du jour, puis neuf fiches : « Au hasard »
## (un mélange de toutes les disciplines, en anthracite) et une fiche pleine à la couleur de chaque discipline.
## Un seul geste pour jouer : toucher une fiche (ou le défi). « Mes résultats » et « Réglages » sont deux liens
## discrets, tout en bas.

## « Au hasard » : tous les dossiers, toutes disciplines mêlées, en continu.
signal play_pressed
signal open_results
signal open_settings
## Le défi du jour : à jouer, à reprendre, ou déjà fait (on revoit alors son résultat).
signal daily_pressed
signal open_category(category: String)


var _emblem: CoverEmblem
var _fade: Array[Control] = []
var _pack: QuestionPack
var _save: SaveStore
var _info: Label
## Barre de progression de chaque fiche de discipline (part des dossiers trouvés).
var _bars := {}
## Petit tampon en haut à droite de chaque fiche de discipline : visible quand la fiche est complète,
## plein quand tous ses dossiers sont trouvés sans indice.
var _stamps := {}
## « niveau 2 », à côté du pictogramme, quand la fiche complète s'est agrandie de son niveau 2 ;
## la barre de la fiche suit alors le niveau 2.
var _level_tags := {}
var _info_gap: Control
## Fin du dernier mot affiché par show_note (en millisecondes depuis le lancement).
var _note_until := 0
var _daily: Button
var _daily_title: Label
var _daily_sub: Label
var _daily_streak: Label
var _daily_streak_caption: Label
## Le défi fait : un petit tampon dateur à droite de la carte (comme sur la page de résultat).
var _daily_stamp: DsStamp
## Les styles de la carte : à faire (cerclée d'encre) et faite (posée, plus calme).
var _daily_styles_open := {}
var _daily_styles_done := {}
## Taille du tampon de la carte, et note pleine du défi (tampon plein, comme sur la page de résultat).
const DAILY_STAMP_SIZE := 92.0


func setup(pack: QuestionPack, save: SaveStore) -> void:
	_pack = pack
	_save = save
	var today := Time.get_date_dict_from_system()

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", Ds.MARGIN)
	margin.add_theme_constant_override("margin_right", Ds.MARGIN)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	margin.add_child(col)

	var date := Ds.label(Daily.date_label(today), Ds.Role.OVERLINE, Ds.INK_SOFT)
	col.add_child(date)

	col.add_child(_flex())

	_emblem = CoverEmblem.new(300.0, RulesScreen.SCENE)  # la chouette sur ses livres, comme sur « Comment jouer »
	resized.connect(_fit_emblem)
	_emblem.show_stars = false
	_emblem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_emblem)
	col.add_child(Ds.spacer(Ds.S3))

	var title := Ds.label("CHEVÊCHE", Ds.Role.DISPLAY, Ds.INK)
	title.add_theme_font_size_override("font_size", 72)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var tag := Ds.label("Carnet de curiosités", Ds.Role.NUMERAL, Ds.INK_SOFT)
	tag.add_theme_font_size_override("font_size", 32)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(tag)
	# Consigne de premier lancement : elle disparaît dès la première réponse.
	_info_gap = Ds.spacer(Ds.S4)
	col.add_child(_info_gap)
	_info = Ds.label("", Ds.Role.SMALL, Ds.INK_SOFT, true)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_info)

	col.add_child(_flex())

	_daily = _daily_card()
	col.add_child(_daily)
	col.add_child(Ds.spacer(Ds.S3))

	# Un seul geste pour jouer : toucher une fiche. La première, « Au hasard », mélange toutes les disciplines.
	var drawers := GridContainer.new()
	drawers.columns = 3
	drawers.add_theme_constant_override("h_separation", 12)
	drawers.add_theme_constant_override("v_separation", 12)
	col.add_child(drawers)
	drawers.add_child(_random_drawer())
	for d in ProgressScreen.DISCIPLINES:
		if not _pack.questions_in(d).is_empty():
			drawers.add_child(_drawer(d))
	col.add_child(Ds.spacer(Ds.S3))

	var links := HBoxContainer.new()
	links.add_theme_constant_override("separation", 0)
	col.add_child(links)
	links.add_child(_link("Mes résultats", func() -> void: open_results.emit()))
	links.add_child(_link("Réglages", func() -> void: open_settings.emit()))

	_fade = [date, title, tag, _info, _daily, drawers, links]
	refresh()


# Une fiche pleine : fond de couleur, pictogramme en haut à gauche, nom en bas. Renvoie [bouton, colonne].
func _fiche(color: Color, action: Callable) -> Array:
	var b := Button.new()
	b.theme_type_variation = "FlatButton"
	b.custom_minimum_size = Vector2(0, 132)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = color if state != "pressed" else color.darkened(0.14)
		sb.set_corner_radius_all(6)
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func() -> void:
		Feedback.say("tap")
		action.call())
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 16
	v.offset_right = -12
	v.offset_top = 14
	v.offset_bottom = -12
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	return [b, v]


# Nom de la fiche, en bas, puis une fine barre de progression (invisible mais à sa place pour « Au hasard »,
# pour que tous les noms restent alignés).
func _fiche_name(v: VBoxContainer, text: String, discipline := "") -> void:
	var flex := Control.new()
	flex.size_flags_vertical = Control.SIZE_EXPAND_FILL
	flex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(flex)
	var name := Ds.label(text, Ds.Role.HEADING, Ds.IVORY)
	name.add_theme_font_size_override("font_size", 25)
	name.clip_text = true
	v.add_child(name)
	v.add_child(Ds.spacer(6))
	var bar := DsSegments.new()
	bar.thickness = 4
	bar.fill_color = Ds.IVORY
	bar.track_color = Color(Ds.IVORY, 0.28)
	bar.fills = PackedFloat32Array([0.0])
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(bar)
	if discipline == "":
		bar.modulate.a = 0.0
	else:
		_bars[discipline] = bar


# « Au hasard » : la fiche anthracite, avec la chouette sur une pastille ivoire. C'est le geste par défaut.
func _random_drawer() -> Button:
	var parts := _fiche(Ds.INK, func() -> void: play_pressed.emit())
	var v: VBoxContainer = parts[1]
	var badge := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Ds.IVORY
	sb.set_corner_radius_all(24)
	badge.add_theme_stylebox_override("panel", sb)
	badge.custom_minimum_size = Vector2(48, 48)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var owl := OwlMark.new(38)
	owl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	owl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_child(owl)
	v.add_child(badge)
	_fiche_name(v, "Au hasard")
	return parts[0]


# Une fiche de discipline, à sa couleur.
func _drawer(discipline: String) -> Button:
	var parts := _fiche(Ds.discipline_color(discipline), func() -> void: open_category.emit(discipline))
	var v: VBoxContainer = parts[1]
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	var icon := Ds.icon_rect(discipline, 40, Ds.IVORY)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	top.add_child(icon)
	var tag := Ds.fill_h(Ds.label("niveau 2", Ds.Role.SMALL, Color(Ds.IVORY, 0.92)))
	tag.add_theme_font_size_override("font_size", 20)
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.modulate.a = 0.0  # garde sa place : le tampon reste à droite
	top.add_child(tag)
	_level_tags[discipline] = tag
	var stamp := DsStamp.new(42.0)
	stamp.with_text = false
	stamp.color = Ds.IVORY
	stamp.paper = Ds.discipline_color(discipline)
	stamp.visible = false
	top.add_child(stamp)
	_stamps[discipline] = stamp
	_fiche_name(v, discipline, discipline)
	return parts[0]


# Le défi du jour : une carte claire cerclée d'encre, sur toute la largeur. À droite, les jours de suite.
# Une fois fait, la carte se fait plus discrète (fond du papier, filet léger) et porte le tampon dateur du jour :
# on voit que c'est fait, et on peut encore la toucher pour revoir le résultat.
func _daily_card() -> Button:
	var b := Button.new()
	b.theme_type_variation = "FlatButton"
	b.custom_minimum_size = Vector2(0, 112)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Ds.IVORY_CARD if state != "pressed" else Ds.IVORY_DEEP
		sb.border_color = Color(Ds.INK, 0.85 if state != "disabled" else 0.25)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(6)
		_daily_styles_open[state] = sb
		var done := StyleBoxFlat.new()
		done.bg_color = Color(Ds.IVORY_DEEP, 0.0) if state != "pressed" else Ds.IVORY_DEEP
		done.border_color = Color(Ds.INK, 0.28)
		done.set_border_width_all(1)
		done.set_corner_radius_all(6)
		_daily_styles_done[state] = done
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func() -> void:
		Feedback.say("tap")
		daily_pressed.emit())
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 22
	h.offset_right = -22
	h.add_theme_constant_override("separation", Ds.S3)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 2)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(left)
	_daily_title = Ds.label("Défi du jour", Ds.Role.HEADING, Ds.INK)
	_daily_title.add_theme_font_size_override("font_size", 30)
	left.add_child(_daily_title)
	_daily_sub = Ds.label("", Ds.Role.SMALL, Ds.INK_SOFT)
	_daily_sub.add_theme_font_size_override("font_size", 21)
	left.add_child(_daily_sub)
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", -6)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(right)
	_daily_streak = Ds.label("", Ds.Role.HEADING, Ds.TERRACOTTA)
	_daily_streak.add_theme_font_size_override("font_size", 44)
	_daily_streak.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(_daily_streak)
	_daily_streak_caption = Ds.label("", Ds.Role.OVERLINE, Ds.INK_SOFT)
	_daily_streak_caption.add_theme_font_size_override("font_size", 19)
	_daily_streak_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(_daily_streak_caption)
	_daily_stamp = DsStamp.new(DAILY_STAMP_SIZE)
	_daily_stamp.color = Ds.SAGE
	_daily_stamp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_daily_stamp.visible = false
	h.add_child(_daily_stamp)
	return b


## Met à jour les barres des fiches (part des dossiers trouvés) et la consigne de premier lancement.
## Pas de compteur global ici : le détail est dans « Mes résultats ».
func refresh() -> void:
	if _info == null:
		return
	for d in _bars:
		var all: Array = _pack.questions_in(d)
		var found := _save.collected_in(all)
		var fill := float(found) / float(maxi(all.size(), 1))
		var expert: Array = _pack.questions_in(d, 2)
		var level2 := not all.is_empty() and found == all.size() and not expert.is_empty()
		(_level_tags[d] as Label).modulate.a = 1.0 if level2 else 0.0
		if level2:
			fill = float(_save.collected_in(expert)) / float(expert.size())
		(_bars[d] as DsSegments).fills = PackedFloat32Array([fill])
		var stamp: DsStamp = _stamps[d]
		stamp.visible = not all.is_empty() and found == all.size()
		stamp.filled = stamp.visible and _save.flawless_in(all) == all.size()
	var played := _pack.questions.any(func(q: Dictionary) -> bool: return _save.plays(q["id"]) > 0)
	_info.visible = not played
	_info_gap.visible = not played
	_info.text = "Touchez une fiche et jouez autant que vous voulez."
	_refresh_daily()


## Un mot bref sous le titre (« Astronomie : 4 dossiers à revoir demain. »), qui s'efface au bout de quelques secondes.
func show_note(text: String) -> void:
	_note_until = Time.get_ticks_msec() + 3800
	_info.text = text
	_info.visible = true
	_info_gap.visible = true
	_info.modulate.a = 0.0
	create_tween().tween_property(_info, "modulate:a", 1.0, 0.25)
	get_tree().create_timer(4.0).timeout.connect(func() -> void:
		if Time.get_ticks_msec() >= _note_until:
			_info.modulate.a = 1.0
			refresh())


## Le défi : à jouer, à reprendre, ou fait (la carte porte alors le tampon du jour et rouvre le résultat).
func _refresh_daily() -> void:
	var key := Week.today_key()
	var state := _save.daily_state(key)
	var streak := _save.daily_streak(key)
	var played: int = state["results"].size()
	var done: bool = state["done"]
	for st in _daily_styles_open:
		_daily.add_theme_stylebox_override(st, _daily_styles_done[st] if done else _daily_styles_open[st])
	_daily_stamp.visible = done
	if done:
		var d := Week.from_key(key)
		_daily_stamp.center_text = str(d["day"])
		_daily_stamp.center_caption = Week.MONTHS_SHORT[int(d["month"]) - 1]
		_daily_stamp.filled = int(state["points"]) >= Scoring.max_total(Daily.CHALLENGE_LENGTH)
		_daily_sub.text = "%d points. Voir le résultat." % int(state["points"])
		_daily.disabled = false
	elif played > 0:
		_daily_sub.text = "À reprendre : %d dossier%s sur %d." % [played, "s" if played > 1 else "", Daily.CHALLENGE_LENGTH]
		_daily.disabled = false
	else:
		_daily_sub.text = "Cinq dossiers, les mêmes pour tout le monde."
		_daily.disabled = false
	_daily.mouse_default_cursor_shape = Control.CURSOR_ARROW if _daily.disabled else Control.CURSOR_POINTING_HAND
	_daily_streak.visible = streak > 0
	_daily_streak_caption.visible = streak > 0
	_daily_streak.text = str(streak)
	_daily_streak_caption.text = "jour de suite" if streak == 1 else "jours de suite"


## L'illustration grandit avec la hauteur de l'écran : 300 sur un écran 16:9, jusqu'à 390 sur un écran allongé.
func _fit_emblem() -> void:
	if size.y > 0.0:
		_emblem.set_emblem_size(clampf(size.y * 0.235, 260.0, 390.0))


## Ouverture de la couverture. `first` : au lancement (complète) ; sinon, simple fondu rapide au retour.
## Rien n'est bloqué pendant l'animation : on peut toucher une fiche tout de suite.
func play_intro(first := false) -> void:
	_fit_emblem()
	_emblem.play(first)
	if first:  # au lancement seulement : le thème d'ouverture, quand la chouette apparaît
		get_tree().create_timer(0.45).timeout.connect(func() -> void: Feedback.say("startup"))
	var k := 1.0 if first else 0.4
	var tw := create_tween().set_parallel(true)
	for i in _fade.size():
		var c := _fade[i]
		c.modulate.a = 0.0
		tw.tween_property(c, "modulate:a", 1.0, 0.55 * k).set_delay((0.45 + i * 0.1) * k).set_trans(Tween.TRANS_SINE)


# Lien discret : texte seul, même largeur pour les deux liens côte à côte.
func _link(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.theme_type_variation = "FlatButton"
	b.text = text
	b.custom_minimum_size = Vector2(0, 64)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 25)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, Ds.INK_SOFT)
	b.pressed.connect(action)
	return b


func _flex() -> Control:
	var c := Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c
