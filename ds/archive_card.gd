class_name ArchiveCard
extends PanelContainer
## Carte d'un dossier : un bandeau à la couleur de sa discipline (pictogramme, catégorie, niveau, numéro du dossier),
## la question, puis une zone libre (`body`) : sur l'écran de jeu, l'image à gratter et les indices.

var body: MarginContainer
var footer: HBoxContainer

var _band: PanelContainer
var _band_style: StyleBoxFlat
var _icon: TextureRect
var _category: Label
var _dossier: Label
var _level: DsLevel
var _tier: Label
var _question: Label


func _init() -> void:
	theme_type_variation = "Card"
	# Le bandeau touche les bords : la carte n'a pas de marge intérieure, c'est le contenu qui la porte.
	add_theme_stylebox_override("panel", Ds.box(Ds.IVORY_CARD, Color(Ds.INK, 0.22), 1, 0, 0, 0, 0))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	add_child(v)

	_band = PanelContainer.new()
	_band_style = StyleBoxFlat.new()
	_band_style.bg_color = Ds.SAGE
	_band_style.corner_radius_top_left = Ds.RADIUS
	_band_style.corner_radius_top_right = Ds.RADIUS
	_band_style.content_margin_left = 24
	_band_style.content_margin_right = 24
	_band_style.content_margin_top = 12
	_band_style.content_margin_bottom = 12
	_band.add_theme_stylebox_override("panel", _band_style)
	v.add_child(_band)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", Ds.S2 + 4)
	_band.add_child(head)
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.custom_minimum_size = Vector2(32, 32)
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon.self_modulate = Ds.IVORY
	head.add_child(_icon)
	_category = Ds.fill_h(Ds.label("", Ds.Role.OVERLINE, Ds.IVORY))
	_category.add_theme_font_size_override("font_size", 26)
	_category.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(_category)
	# La difficulté du dossier, discrète, juste avant son numéro : cinq barres montantes.
	_level = DsLevel.new(18.0)
	_level.color = Color(Ds.IVORY, 0.9)
	head.add_child(_level)
	# Un dossier du niveau 2 le dit en toutes lettres, à la place des barres.
	_tier = Ds.label("niveau 2", Ds.Role.OVERLINE, Ds.IVORY)
	_tier.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tier.visible = false
	head.add_child(_tier)
	_dossier = Ds.label("", Ds.Role.OVERLINE, Color(Ds.IVORY, 0.82))
	_dossier.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(_dossier)

	var inner := MarginContainer.new()
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("margin_left", 28)
	inner.add_theme_constant_override("margin_right", 28)
	inner.add_theme_constant_override("margin_top", 18)
	inner.add_theme_constant_override("margin_bottom", 20)
	v.add_child(inner)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", Ds.S3)
	inner.add_child(col)

	_question = Ds.label("", Ds.Role.QUESTION, Ds.INK, true)
	col.add_child(_question)

	body = MarginContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)

	footer = HBoxContainer.new()
	footer.visible = false
	col.add_child(footer)


## `discipline` choisit la couleur et le pictogramme du bandeau (Nature, Astronomie…) ;
## `level` : 1 facile, 2 moyen, 3 difficile (0 : pas de repère) ; `tier` 2 : dossier du niveau 2.
func setup(dossier_no: int, category: String, question: String, discipline := "", level := 0, tier := 1) -> void:
	_dossier.text = "nº %d" % dossier_no
	_level.level = level
	_level.visible = level > 0 and tier < 2
	_tier.visible = tier >= 2
	_category.text = category
	_question.text = question
	_band_style.bg_color = Ds.discipline_color(discipline)
	_icon.texture = Ds.discipline_icon(discipline)
	_icon.visible = _icon.texture != null
	_icon.self_modulate = Ds.IVORY


## Dossier en image : un bandeau anthracite « Dossier en image », le pictogramme de la discipline en ocre, pas de numéro.
func setup_visual(question: String, discipline: String, level := 0) -> void:
	setup(0, "Dossier en image", question, discipline, level)
	_dossier.text = ""
	_band_style.bg_color = Ds.INK
	_icon.self_modulate = Ds.OCHRE
