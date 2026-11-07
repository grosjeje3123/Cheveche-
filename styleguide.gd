extends Control
## Page de référence du design system : palette, typographie, composants, espacements.
## Ouvrir styleguide.tscn pour la voir ; tout est construit avec les mêmes briques que les écrans.


func _ready() -> void:
	theme = Ds.build_theme()
	add_child(Ds.paper_background())

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", Ds.MARGIN)
	margin.add_theme_constant_override("margin_right", Ds.MARGIN)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 72)
	scroll.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	margin.add_child(col)

	col.add_child(Ds.label("Design system", Ds.Role.OVERLINE, Ds.TERRACOTTA))
	col.add_child(Ds.label("CHEVÊCHE", Ds.Role.DISPLAY, Ds.INK))
	col.add_child(Ds.label("Jetons et composants. Une valeur modifiée ici change toute l’application.",
			Ds.Role.BODY, Ds.INK_SOFT, true))

	_section(col, "Couleurs", _palette())
	_section(col, "Typographie", _type_specimens())
	_section(col, "Boutons", _buttons())
	_section(col, "Réponses", _options())
	_section(col, "Étiquettes et progression", _tags())
	_section(col, "Carte d’archive", _card())
	_section(col, "Espacements et filets", _spacing())


func _section(col: VBoxContainer, title: String, content: Control) -> void:
	col.add_child(Ds.spacer(Ds.S6))
	col.add_child(Ds.section_header(title))
	col.add_child(Ds.spacer(Ds.S4))
	col.add_child(content)


func _vbox(sep := Ds.S3) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


func _palette() -> Control:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", Ds.S3)
	grid.add_theme_constant_override("v_separation", Ds.S4)
	var swatches := [
		["Ivoire", Ds.IVORY, "fond"], ["Papier", Ds.IVORY_CARD, "cartes"],
		["Ivoire foncé", Ds.IVORY_DEEP, "fiches"], ["Anthracite", Ds.INK, "texte"],
		["Sauge", Ds.SAGE, "secondaire"], ["Terre cuite", Ds.TERRACOTTA, "accent"],
		["Ocre", Ds.OCHRE, "détails"], ["Ardoise", Ds.SLATE, "à gratter"]]
	for s in swatches:
		var cell := _vbox(Ds.S1)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var chip := PanelContainer.new()
		chip.custom_minimum_size = Vector2(0, 84)
		chip.add_theme_stylebox_override("panel", Ds.box(s[1], Color(Ds.INK, 0.25), 1, 0, 0, 0, 0))
		cell.add_child(chip)
		cell.add_child(Ds.label(s[0], Ds.Role.SMALL, Ds.INK, true))
		cell.add_child(Ds.label("#" + (s[1] as Color).to_html(false).to_upper(), Ds.Role.CAPTION, Ds.INK_SOFT, true))
		cell.add_child(Ds.label(s[2], Ds.Role.CAPTION, Ds.INK_FAINT, true))
		grid.add_child(cell)
	return grid


func _type_specimens() -> Control:
	var v := _vbox(Ds.S4)
	var rows := [
		[Ds.Role.DISPLAY, "CHEVÊCHE", "Display · Newsreader Medium 66, interlettrage"],
		[Ds.Role.TITLE, "Le cabinet du jour", "Titre · Newsreader Medium 44"],
		[Ds.Role.HEADING, "Géographie", "Intertitre · Newsreader Medium 32"],
		[Ds.Role.QUESTION, "Quel fleuve traverse dix pays avant de se jeter dans la mer Noire ?",
				"Question · Newsreader Regular 34"],
		[Ds.Role.CLUE, "Il prend sa source en Forêt-Noire, en Allemagne.", "Indice · Newsreader Regular 24"],
		[Ds.Role.NUMERAL, "I   II   III", "Numéral · Newsreader Italique 30"],
		[Ds.Role.BODY, "Un dossier se résout par déduction : chaque indice resserre l’enquête.",
				"Texte · DM Sans Regular 27"],
		[Ds.Role.SMALL, "12 / 48 dossiers", "Annotation · DM Sans Regular 23"],
		[Ds.Role.OVERLINE, "Dossier Nº 0087", "Surtitre · DM Sans SemiBold 19, capitales"]]
	for r in rows:
		var item := _vbox(Ds.S1)
		var sample := Ds.label(r[1], r[0], Ds.INK, true)
		item.add_child(sample)
		item.add_child(Ds.label(r[2], Ds.Role.CAPTION, Ds.INK_FAINT))
		v.add_child(item)
	return v


func _buttons() -> Control:
	var v := _vbox(Ds.S3)
	var primary := Button.new()
	primary.theme_type_variation = "PrimaryButton"
	primary.text = "Ouvrir le dossier"
	primary.custom_minimum_size = Vector2(0, 80)
	v.add_child(primary)
	var ghost := Button.new()
	ghost.theme_type_variation = "GhostButton"
	ghost.text = "Voir la collection"
	ghost.custom_minimum_size = Vector2(0, 80)
	v.add_child(ghost)
	var off := Button.new()
	off.theme_type_variation = "PrimaryButton"
	off.text = "Continuer (inactif)"
	off.disabled = true
	off.custom_minimum_size = Vector2(0, 80)
	v.add_child(off)
	return v


func _options() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.add_child(Ds.rule(Ds.INK_STRONG, 1))
	var states := [["A", "Réponse disponible", null], ["B", "Réponse juste", Ds.SAGE],
			["C", "Réponse fausse", Ds.TERRACOTTA], ["D", "Réponse verrouillée", false]]
	for s in states:
		var b := Button.new()
		b.theme_type_variation = "RowButton"
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 76)
		b.text = s[1]
		var letter_color := Ds.TERRACOTTA
		if s[2] is Color:
			b.disabled = true
			b.add_theme_stylebox_override("disabled", Ds.row_box(s[2]))
			b.add_theme_color_override("font_disabled_color", Ds.IVORY)
			letter_color = Ds.IVORY
		elif s[2] is bool:
			b.disabled = true
		var l := Ds.label(s[0], Ds.Role.NUMERAL, letter_color)
		l.set_anchors_preset(Control.PRESET_CENTER_LEFT)
		l.offset_left = 20
		l.offset_right = 60
		l.offset_top = -24
		l.offset_bottom = 24
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		b.add_child(l)
		v.add_child(b)
	return v


func _tags() -> Control:
	var v := _vbox(Ds.S4)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Ds.S5)
	row.add_child(Ds.category_tag("Géographie"))
	row.add_child(Ds.category_tag("Sciences", Ds.SAGE))
	row.add_child(Ds.category_tag("Arts", Ds.OCHRE))
	v.add_child(row)

	v.add_child(Ds.label("Progression d’une série (5 étapes, la troisième en cours)", Ds.Role.CAPTION, Ds.INK_FAINT))
	var steps := DsSegments.new()
	steps.total = 5
	steps.current = 2
	v.add_child(steps)

	v.add_child(Ds.label("Progression par discipline", Ds.Role.CAPTION, Ds.INK_FAINT))
	var bar := DsSegments.new()
	bar.thickness = 4
	bar.fills = PackedFloat32Array([0.75, 0.5, 0.3, 0.15, 0.05, 0.0])
	v.add_child(bar)

	var icons := HBoxContainer.new()
	icons.add_theme_constant_override("separation", Ds.S5)
	icons.add_child(DsIcon.new(DsIcon.Kind.CHEVRON_LEFT, Ds.INK, 40))
	icons.add_child(DsIcon.new(DsIcon.Kind.CHEVRON_RIGHT, Ds.INK, 40))
	icons.add_child(Ds.label("Icônes au trait, 2,5 px", Ds.Role.CAPTION, Ds.INK_FAINT))
	v.add_child(icons)
	return v


func _card() -> Control:
	var card := ArchiveCard.new()
	card.setup(12, "Géologie", "Quelle théorie explique le mouvement des continents, les séismes et la naissance des montagnes ?", "Sciences")
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", Ds.S3)
	card.body.add_child(inner)
	var zone := ImageZone.new(false)
	zone.custom_minimum_size = Vector2(0, 220)
	zone.show_placeholder("carte scientifique des limites des plaques tectoniques")
	inner.add_child(zone)
	var clues := ClueList.new()
	clues.set_clues([
		"La surface terrestre est découpée en grandes unités mobiles.",
		"Ces unités se déplacent lentement.",
		"Cette théorie explique notamment les séismes et la formation des montagnes."])
	inner.add_child(clues)
	clues.unlock(2, false)
	_preview(zone.cover)
	return card


func _preview(cover: ScratchCover) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	cover.scratch_path([Vector2(0.03, 0.30), Vector2(0.30, 0.34), Vector2(0.62, 0.29),
			Vector2(0.97, 0.33)], 3)
	cover.scratch_path([Vector2(0.03, 0.62), Vector2(0.40, 0.58), Vector2(0.78, 0.63)], 3)


func _spacing() -> Control:
	var v := _vbox(Ds.S2)
	for pair in [["S1", Ds.S1], ["S2", Ds.S2], ["S3", Ds.S3], ["S4", Ds.S4], ["S5", Ds.S5], ["S6", Ds.S6], ["S7", Ds.S7]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", Ds.S3)
		var name := Ds.label("%s  ·  %d px" % [pair[0], pair[1]], Ds.Role.CAPTION, Ds.INK_SOFT)
		name.custom_minimum_size = Vector2(140, 0)
		row.add_child(name)
		var bar := ColorRect.new()
		bar.color = Ds.SAGE
		bar.custom_minimum_size = Vector2(pair[1] * 4, 10)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		v.add_child(row)
	v.add_child(Ds.spacer(Ds.S3))
	v.add_child(Ds.label("Filet fin (1 px) pour séparer · filet épais (3 px) réservé au masthead · coins de 4 px partout.",
			Ds.Role.SMALL, Ds.INK_SOFT, true))
	return v
