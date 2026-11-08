class_name RulesScreen
extends Control
## « Comment jouer » : trois règles sur une page. Elle s'ouvre une seule fois, avant la toute première série
## (une fiche ou le défi du jour), puis reste à portée de main dans les Réglages.

## « Commencer » : la première série peut démarrer.
signal start_pressed
## La flèche retour (ou le bouton Retour d'Android).
signal closed

const RULES := [
	["Une image, une question",
		"Chaque dossier pose une question, avec quatre réponses possibles. Une image est cachée sous la couche à gratter, mais la question se comprend sans elle."],
	["Gratter aide, mais coûte",
		"En grattant, l’image apparaît et deux indices se dévoilent. Chaque indice fait baisser les points : 100 sans indice, 60 avec un, 30 avec deux."],
	["Rien n’est perdu",
		"Un dossier manqué, ou trouvé avec des indices, revient le lendemain. Et chaque jour, un défi de cinq dossiers, le même pour tout le monde."],
]

## La chouette sur ses livres (dessinée par tools/make_owl.py).
const SCENE := preload("res://assets/brand/owl_scene.svg")

## Le bouton « Commencer » : visible seulement avant la première série.
var start_button: Button
var scene: TextureRect
var _fade: Array[Control] = []


func build() -> void:
	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", 0)
	add_child(page)
	var head := MarginContainer.new()
	head.add_theme_constant_override("margin_left", Ds.MARGIN)
	head.add_theme_constant_override("margin_right", Ds.MARGIN)
	head.add_theme_constant_override("margin_top", 24)
	page.add_child(head)
	head.add_child(Ds.page_top("Comment jouer", func() -> void: closed.emit()))

	# Le texte tient sur un téléphone : il est posé un peu au-dessus du milieu de la page, sous l'illustration.
	var flex_top := Control.new()
	flex_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	flex_top.size_flags_stretch_ratio = 0.6
	page.add_child(flex_top)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", Ds.MARGIN)
	margin.add_theme_constant_override("margin_right", Ds.MARGIN)
	page.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	margin.add_child(col)
	# La chouette sur ses livres : l'illustration du jeu, à la taille que laisse l'écran (voir `_fit_scene`).
	scene = TextureRect.new()
	scene.texture = SCENE
	scene.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scene.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	scene.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(scene)
	_fade.append(scene)
	col.add_child(Ds.spacer(Ds.S4))

	# Trois règles comme les entrées d'un carnet : un titre en romain, le texte dessous, un filet entre elles.
	for i in RULES.size():
		var block := VBoxContainer.new()
		block.add_theme_constant_override("separation", Ds.S2)
		col.add_child(block)
		var title := Ds.label(RULES[i][0], Ds.Role.HEADING, Ds.INK)
		block.add_child(title)
		block.add_child(Ds.label(RULES[i][1], Ds.Role.BODY, Ds.INK_STRONG, true))
		_fade.append(block)
		if i < RULES.size() - 1:
			col.add_child(Ds.spacer(Ds.S4))
			col.add_child(Ds.rule(Ds.RULE, 1))
			col.add_child(Ds.spacer(Ds.S4))

	var flex_bottom := Control.new()
	flex_bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(flex_bottom)
	var foot := MarginContainer.new()
	foot.add_theme_constant_override("margin_left", Ds.MARGIN)
	foot.add_theme_constant_override("margin_right", Ds.MARGIN)
	foot.add_theme_constant_override("margin_bottom", 56)
	page.add_child(foot)
	start_button = Button.new()
	start_button.theme_type_variation = "PrimaryButton"
	start_button.text = "Commencer"
	start_button.custom_minimum_size = Vector2(0, 96)
	start_button.pressed.connect(func() -> void: start_pressed.emit())
	foot.add_child(start_button)
	resized.connect(_fit_scene)


## L’illustration grandit avec la hauteur de l’écran : 270 sur un écran 16:9, 330 sur un écran allongé.
func _fit_scene() -> void:
	var h := clampf(size.y * 0.21, 190.0, 330.0) if size.y > 0.0 else 270.0
	scene.custom_minimum_size = Vector2(0, h)


## `before_first_series` : la page s'ouvre avant la première série (bouton « Commencer »),
## sinon depuis les Réglages (seule la flèche ramène).
func open(before_first_series: bool) -> void:
	start_button.visible = before_first_series
	_fit_scene()
	for i in _fade.size():
		var c := _fade[i]
		c.modulate.a = 0.0
		create_tween().tween_property(c, "modulate:a", 1.0, 0.35).set_delay(0.15 + i * 0.12).set_trans(Tween.TRANS_SINE)
