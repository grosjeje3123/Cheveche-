class_name ProgressScreen
extends Control
## « Mes résultats » : un bilan, sans bouton de jeu. Les dossiers trouvés, la semaine, puis la progression
## par discipline. On y arrive depuis la couverture ; la flèche en haut à gauche y ramène. Défile verticalement.
## (Pour jouer une discipline : les fiches de la couverture.)

signal closed

## Les disciplines, dans l'ordre d'affichage. Une discipline sans dossier s'affiche « à venir ».
## (Le pack relie chacune de ses catégories à l'une d'elles : collection_par_categorie.)
const DISCIPLINES := ["Nature", "Animaux", "Sciences", "Astronomie", "Histoire", "Arts", "Géographie", "Littérature"]
var _pack: QuestionPack
var _save: SaveStore
var _scroll: ScrollContainer
# Éléments qui suivent la progression (mis à jour par refresh()).
var _category_meta := {}
var _category_bar := {}
var _category_level := {}
var _cabinet_count: Label
var _cabinet_unit: Label
var _cabinet_total: Label
var _cabinet_bar: DsSegments
var _cabinet_detail: Label
var _cabinet_best: Label
var _week_range: Label
var _week_bars: DsWeekBars
var _week_points: Label
var _week_found: Label
var _week_found_caption: Label
var _week_days: Label
var _week_best: Label
var _week_last: Label


func setup(pack: QuestionPack, save: SaveStore) -> void:
	_pack = pack
	_save = save

	# En-tête fixe (flèche de retour, titre), puis le contenu qui défile.
	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", 0)
	add_child(page)
	var head := MarginContainer.new()
	head.add_theme_constant_override("margin_left", Ds.MARGIN)
	head.add_theme_constant_override("margin_right", Ds.MARGIN)
	head.add_theme_constant_override("margin_top", 24)
	page.add_child(head)
	head.add_child(Ds.page_top("Mes résultats", func() -> void: closed.emit()))

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER  # défile au doigt, sans barre grise
	page.add_child(_scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", Ds.MARGIN)
	margin.add_theme_constant_override("margin_right", Ds.MARGIN)
	margin.add_theme_constant_override("margin_top", Ds.S5)
	margin.add_theme_constant_override("margin_bottom", 72)
	_scroll.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	margin.add_child(col)

	_build_cabinet(col)
	col.add_child(Ds.spacer(Ds.S6))
	_build_week(col)
	col.add_child(Ds.spacer(Ds.S6))
	_build_summary(col)
	refresh()


# La progression par discipline : un nom, un compte et une fine barre. Simple lecture, rien à toucher.
func _build_summary(col: VBoxContainer) -> void:
	var open_list: Array[String] = []
	for d in DISCIPLINES:
		if not _pack.questions_in(d).is_empty():
			open_list.append(d)
	col.add_child(Ds.section_header("Par discipline"))
	for d in open_list:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", Ds.S1)
		col.add_child(Ds.spacer(Ds.S3))
		col.add_child(row)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", Ds.S2 + 4)
		row.add_child(h)
		var ic := Ds.icon_rect(d, 30, Ds.discipline_color(d))
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ic)
		h.add_child(Ds.fill_h(Ds.label(d, Ds.Role.BODY, Ds.INK)))
		var meta := Ds.label("", Ds.Role.SMALL, Ds.INK_SOFT)
		h.add_child(meta)
		_category_meta[d] = meta
		var bar := DsSegments.new()
		bar.thickness = 4
		bar.fill_color = Ds.discipline_color(d)
		row.add_child(bar)
		_category_bar[d] = bar
		# Le niveau dans la discipline (Mastery), calculé sur les premières réponses à chaque dossier.
		var lvl := Ds.label("", Ds.Role.SMALL, Ds.INK_SOFT)
		row.add_child(lvl)
		_category_level[d] = lvl


func _build_cabinet(col: VBoxContainer) -> void:
	col.add_child(Ds.section_header("Vos dossiers"))
	col.add_child(Ds.spacer(Ds.S4))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Ds.S3)
	col.add_child(row)
	_cabinet_count = Ds.label("0", Ds.Role.DISPLAY, Ds.INK)
	_cabinet_count.add_theme_font_override("font", Ds.SERIF_MEDIUM)
	row.add_child(_cabinet_count)
	var side := VBoxContainer.new()
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	side.add_theme_constant_override("separation", 0)
	row.add_child(side)
	_cabinet_unit = Ds.label("", Ds.Role.BODY, Ds.INK)
	side.add_child(_cabinet_unit)
	_cabinet_total = Ds.label("", Ds.Role.SMALL, Ds.INK_SOFT)
	side.add_child(_cabinet_total)

	col.add_child(Ds.spacer(Ds.S4))
	_cabinet_bar = DsSegments.new()
	_cabinet_bar.thickness = 4
	col.add_child(_cabinet_bar)
	col.add_child(Ds.spacer(Ds.S3))
	_cabinet_detail = Ds.label("", Ds.Role.SMALL, Ds.INK_SOFT, true)
	col.add_child(_cabinet_detail)
	_cabinet_best = Ds.label("", Ds.Role.SMALL, Ds.INK_SOFT, true)
	col.add_child(_cabinet_best)


# Le bilan de la semaine : sept colonnes de points, puis trois chiffres.
func _build_week(col: VBoxContainer) -> void:
	var header := Ds.section_header("Cette semaine", " ")
	_week_range = (header.get_child(0) as HBoxContainer).get_child(1) as Label
	col.add_child(header)
	col.add_child(Ds.spacer(Ds.S4))
	_week_bars = DsWeekBars.new()
	col.add_child(_week_bars)
	col.add_child(Ds.spacer(Ds.S4))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Ds.S3)
	col.add_child(row)
	_week_points = _week_figure(row, "points")[0]
	var found := _week_figure(row, "trouvés")
	_week_found = found[0]
	_week_found_caption = found[1]
	_week_days = _week_figure(row, "jours sur 7")[0]

	col.add_child(Ds.spacer(Ds.S3))
	_week_best = Ds.label("", Ds.Role.SMALL, Ds.INK_SOFT, true)
	col.add_child(_week_best)
	_week_last = Ds.label("", Ds.Role.SMALL, Ds.INK_SOFT, true)
	col.add_child(_week_last)


# Un chiffre en serif et sa légende, dans une colonne de la rangée. Renvoie [chiffre, légende].
func _week_figure(row: HBoxContainer, caption: String) -> Array:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 0)
	row.add_child(box)
	var number := Ds.label("0", Ds.Role.TITLE, Ds.INK)
	box.add_child(number)
	var cap := Ds.label(caption, Ds.Role.SMALL, Ds.INK_SOFT)
	box.add_child(cap)
	return [number, cap]


## Remet à jour tout ce qui dépend de la progression (après chaque réponse ou série).
## « Votre niveau : Érudit » ; avant assez de réponses : « Votre niveau : connu dans 4 dossiers » ;
## discipline pas encore jouée : rien.
static func level_line(info: Dictionary) -> String:
	if int(info["n"]) == 0:
		return ""
	if Mastery.known(info):
		return "Votre niveau : %s" % Mastery.name_of(info["r"])
	var left: int = Mastery.MIN_ANSWERS - int(info["n"])
	return "Votre niveau : connu dans %d dossier%s" % [left, "s" if left > 1 else ""]


func refresh() -> void:
	if _cabinet_count == null:
		return
	for category in _category_meta:
		var all: Array = _pack.questions_in(category)
		var got := _save.collected_in(all)
		var meta := Ds.discipline_count(got, all.size())
		var ratio := float(got) / float(maxi(all.size(), 1))
		var expert: Array = _pack.questions_in(category, 2)
		if got == all.size() and got > 0 and not expert.is_empty():
			# Fiche complète avec un niveau 2 : on suit le niveau 2.
			var got2 := _save.collected_in(expert)
			var flawless2 := _save.flawless_in(expert)
			ratio = float(got2) / float(expert.size())
			if got2 < expert.size():
				meta = "Niveau 2 : %s" % Ds.discipline_count(got2, expert.size())
			else:
				meta = "Niveau 2 sans faute" if flawless2 == got2 else "Niveau 2 complet, %d sans indice" % flawless2
		elif got == all.size() and got > 0:
			var flawless := _save.flawless_in(all)
			meta = "Sans faute" if flawless == got else "Complète, %d sans indice" % flawless
		(_category_meta[category] as Label).text = meta
		var level_label: Label = _category_level[category]
		level_label.text = level_line(Mastery.rating(_save, all + expert))
		level_label.visible = level_label.text != ""
		var fill := PackedFloat32Array()
		fill.append(ratio)
		(_category_bar[category] as DsSegments).fills = fill

	var collected := _save.collected_in(_pack.questions)
	_cabinet_count.text = str(collected)
	_cabinet_unit.text = "dossier%s trouvé%s" % ["s" if collected > 1 else "", "s" if collected > 1 else ""]
	_cabinet_total.text = "sur %d" % _pack.questions.size()

	# Une seule barre : la part des dossiers trouvés (le détail par discipline est dans la liste plus bas).
	var fill := PackedFloat32Array()
	fill.append(float(collected) / float(maxi(_pack.questions.size(), 1)))
	_cabinet_bar.fills = fill
	_cabinet_detail.text = "Un dossier est trouvé dès que vous y répondez juste, avec ou sans indice. " \
			+ "Quand vous jouez une fiche, les dossiers pas encore trouvés passent en premier."

	var best := _save.best_daily()
	_cabinet_best.visible = best > 0
	_cabinet_best.text = "Meilleur défi du jour : %d / %d" % [best, Scoring.max_total(Daily.CHALLENGE_LENGTH)]
	_refresh_week()


func _refresh_week() -> void:
	var today := Week.today()
	var week := _save.week_summary(today)
	var last := _save.week_summary(Week.shifted(today, -7))
	_week_range.text = Week.range_label(today)

	var pts: Array = []
	var ans: Array = []
	for d in week["days"]:
		pts.append(d["points"])
		ans.append(d["answers"])
	_week_bars.set_week(pts, ans, Week.weekday_index(today))

	_week_points.text = str(week["points"])
	_week_found.text = str(week["correct"])
	_week_found_caption.text = "trouvé%s sur %d" % ["s" if int(week["correct"]) > 1 else "", int(week["answers"])]
	_week_days.text = str(week["days_played"])

	var best_index := int(week["best_index"])
	if best_index >= 0:
		var day: Dictionary = week["days"][best_index]
		_week_best.text = "Meilleure journée : %s, %d point%s." % [Week.DAY_NAMES[best_index], int(day["points"]),
				"s" if int(day["points"]) > 1 else ""]
	else:
		_week_best.text = "Pas encore de partie cette semaine."
	_week_last.visible = int(last["points"]) > 0
	_week_last.text = "Semaine dernière : %d points." % int(last["points"])
