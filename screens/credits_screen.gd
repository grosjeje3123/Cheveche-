class_name CreditsScreen
extends Control
## « Crédits » : pour chaque image, rangée par discipline, le dossier, le titre du fichier, l'auteur, la licence,
## la page source et les modifications, avec des liens qu'on touche pour les ouvrir (comme le demandent les licences
## CC BY et CC BY-SA) ; puis les polices, les sons et les dessins. Un sommaire en haut mène à chaque discipline.
## On y arrive depuis les Réglages ou depuis l'écran de résultat ; la flèche ramène à l'écran d'origine.

signal closed

const LINK := "B66F55"
## L'auteur du jeu, en tête des crédits (l'adresse s'ouvre dans l'appli de mail).
const AUTHOR := "Jérôme Hosdez"
const AUTHOR_EMAIL := "jerome.hosdez@gmail.com"

var _pack: QuestionPack
var _body: VBoxContainer
var _scroll: ScrollContainer
## Titre de chaque discipline, pour le sommaire.
var _sections := {}
## Dernière adresse ouverte (sert aux tests ; l'ouverture réelle passe par OS.shell_open).
var last_opened := ""
## Vrai pendant les tests : les liens ne quittent pas l'application.
var dry_run := false


func setup(pack: QuestionPack) -> void:
	_pack = pack
	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", 0)
	add_child(page)
	var head := MarginContainer.new()
	head.add_theme_constant_override("margin_left", Ds.MARGIN)
	head.add_theme_constant_override("margin_right", Ds.MARGIN)
	head.add_theme_constant_override("margin_top", 24)
	page.add_child(head)
	head.add_child(Ds.page_top("Crédits", func() -> void: closed.emit()))

	var scroll := ScrollContainer.new()
	_scroll = scroll
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	page.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", Ds.MARGIN)
	margin.add_theme_constant_override("margin_right", Ds.MARGIN)
	margin.add_theme_constant_override("margin_top", Ds.S4)
	margin.add_theme_constant_override("margin_bottom", 72)
	scroll.add_child(margin)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 0)
	margin.add_child(_body)
	rebuild()


## Reconstruit la page (après l'ajout d'images, par exemple).
func rebuild() -> void:
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_sections.clear()
	_body.add_child(Ds.section_header("Le jeu"))
	_body.add_child(Ds.spacer(Ds.S3))
	_body.add_child(_text("Un jeu de [b]%s[/b]. Contact : %s." % [AUTHOR, _link("mailto:" + AUTHOR_EMAIL, AUTHOR_EMAIL)]))
	_body.add_child(Ds.spacer(Ds.S5))
	_body.add_child(Ds.section_header("Images"))
	_body.add_child(Ds.spacer(Ds.S3))
	var entries := _pack.credit_entries()
	if entries.is_empty():
		_body.add_child(_text("Aucune image pour l’instant : les dossiers affichent un gabarit provisoire."))
	else:
		_body.add_child(_text("Les images viennent de Wikimedia Commons, sous licence libre. Touchez un lien pour ouvrir la page de l’image ou le texte de sa licence."))
		_body.add_child(Ds.spacer(Ds.S2))
		_body.add_child(_text("[i]Réduite[/i] : une copie plus petite que l’original, faite par Commons ou pour le jeu. [i]Recadrée[/i] : seule la bande que le jeu peut montrer est gardée. Rien d’autre n’est changé."))
		_body.add_child(Ds.spacer(Ds.S4))
		var groups := {}
		for e in entries:
			var d := str(e["discipline"])
			if not groups.has(d):
				groups[d] = []
			groups[d].append(e)
		var order: Array = ProgressScreen.DISCIPLINES.filter(func(d): return groups.has(d))
		for d in groups:
			if not order.has(d):
				order.append(d)
		_body.add_child(_summary(order))
		for d in order:
			_body.add_child(Ds.spacer(Ds.S5))
			var head := _discipline_header(d, groups[d].size())
			_sections[d] = head
			_body.add_child(head)
			_body.add_child(Ds.spacer(Ds.S3))
			for e in groups[d]:
				_body.add_child(_entry(e))
				_body.add_child(Ds.spacer(Ds.S3))

	_body.add_child(Ds.spacer(Ds.S5))
	_body.add_child(Ds.section_header("Polices"))
	_body.add_child(Ds.spacer(Ds.S3))
	_body.add_child(_text("Newsreader (Production Type) et DM Sans (Colophon Foundry), sous %s." %
			_link("https://openfontlicense.org", "SIL Open Font License 1.1")))

	_body.add_child(Ds.spacer(Ds.S5))
	_body.add_child(Ds.section_header("Sons, dessins et textes"))
	_body.add_child(Ds.spacer(Ds.S3))
	_body.add_child(_text("Les sons sont fabriqués pour le jeu, par synthèse. La chouette et les pictogrammes sont dessinés pour le jeu. Les questions, indices et explications sont rédigés pour le jeu."))


# Le sommaire : une étiquette teintée par discipline (quatre par ligne), qui fait défiler jusqu'à elle.
func _summary(order: Array) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", Ds.S2)
	grid.add_theme_constant_override("v_separation", Ds.S2)
	for d in order:
		var b := Button.new()
		b.text = d
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 56)
		b.clip_text = true
		b.add_theme_font_override("font", Ds.SERIF_ITALIC)
		b.add_theme_font_size_override("font_size", 22)
		var c := Ds.discipline_color(d)
		for state in [["normal", 0.16], ["hover", 0.24], ["pressed", 0.32], ["focus", 0.16]]:
			var box := StyleBoxFlat.new()
			box.bg_color = Color(c, state[1])
			box.set_corner_radius_all(Ds.RADIUS)
			box.content_margin_left = 6
			box.content_margin_right = 6
			if state[0] == "focus":
				box.draw_center = false
				box.border_color = c
				box.set_border_width_all(2)
			b.add_theme_stylebox_override(state[0], box)
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(k, Ds.INK)
		b.pressed.connect(func() -> void: scroll_to(d))
		grid.add_child(b)
	return grid


## Fait défiler la page jusqu'à une discipline (sommaire).
func scroll_to(discipline: String) -> void:
	var head: Control = _sections.get(discipline)
	if head == null:
		return
	_scroll.scroll_vertical = int(head.global_position.y - _body.global_position.y + _body.position.y - Ds.S2)


func _discipline_header(discipline: String, count: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Ds.S2)
	var c := Ds.discipline_color(discipline)
	if Ds.discipline_icon(discipline) != null:
		var icon := Ds.icon_rect(discipline, 30, c)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
	var t := Ds.label(discipline, Ds.Role.HEADING, Ds.INK)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	var n := Ds.label("%d image%s" % [count, "s" if count > 1 else ""], Ds.Role.OVERLINE, Ds.INK_SOFT)
	n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(n)
	return row


# Une image : le dossier (titre et numéro, comme sur la carte), puis le fichier, l'auteur, la licence et les liens.
func _entry(e: Dictionary) -> RichTextLabel:
	var head := "[font_size=26][color=#%s][i]%s[/i][/color][/font_size]  nº %d" % [
			Ds.INK.to_html(false), _esc(e["dossier_title"]), int(e["dossier"])]
	var parts: Array[String] = ["« %s », %s." % [_esc(e["title"]), _esc(e["author"])]]
	if str(e["licence_url"]) != "":
		parts.append("Licence %s." % _link(e["licence_url"], e["licence"]))
	else:
		parts.append("%s." % _esc(e["licence"]))
	parts.append("%s." % _link(e["source_url"], "Page de l’image"))
	if str(e["changes_short"]) != "":
		parts.append("%s." % _esc(e["changes_short"]))
	var r := _text(head + "\n" + " ".join(parts))
	r.add_theme_font_size_override("normal_font_size", 21)
	r.add_theme_constant_override("line_separation", 4)
	return r


func _text(bbcode: String) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.selection_enabled = false
	r.add_theme_font_override("normal_font", Ds.SANS)
	r.add_theme_font_override("bold_font", Ds.SANS_MEDIUM)
	r.add_theme_font_override("italics_font", Ds.SERIF_ITALIC)
	for k in ["normal_font_size", "bold_font_size", "italics_font_size"]:
		r.add_theme_font_size_override(k, 23)
	r.add_theme_color_override("default_color", Ds.INK_SOFT)
	r.add_theme_constant_override("line_separation", 6)
	r.text = bbcode
	r.meta_clicked.connect(_open)
	return r


func _open(meta) -> void:
	last_opened = str(meta)
	if not dry_run:
		OS.shell_open(last_opened)


func _link(url: String, label: String) -> String:
	return "[color=#%s][url=%s]%s[/url][/color]" % [LINK, url.replace("]", "%5D"), _esc(label)]


static func _esc(text) -> String:
	return str(text).replace("[", "[lb]")
