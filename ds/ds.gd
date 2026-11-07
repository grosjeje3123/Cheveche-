class_name Ds
extends RefCounted
## Design system de Chevêche : jetons (couleurs, espacements, typographie), styles et fabriques.
## Tout le graphisme de l'application passe par ici : changer une valeur la change partout.

# ---------- Couleurs : palette restreinte, aucun dégradé ----------
const IVORY := Color("F1EDE3")        # fond principal (jamais blanc pur)
const IVORY_CARD := Color("F8F5EC")   # papier des cartes
const IVORY_DEEP := Color("E7E1D1")   # fiches et zones en retrait
const INK := Color("292D2A")          # anthracite : texte
const SAGE := Color("687B70")         # vert sauge : éléments secondaires
const TERRACOTTA := Color("B66F55")   # terre cuite : accents
const OCHRE := Color("C2A66D")        # ocre : détails
const SLATE := Color("34423A")        # couche à gratter : vert profond mat
const FELT := Color("2E3A33")         # fond « cabinet » de la couverture : vert sombre mat
const FELT_RAISED := Color("38463E")  # éléments posés sur ce fond

# ---------- Disciplines : une couleur et un pictogramme chacune ----------
## Couleurs franches mais éteintes, assez sombres pour porter un texte ivoire.
const DISCIPLINE_COLORS := {
	"Nature": Color("687B70"), "Animaux": Color("B0694F"), "Sciences": Color("5E7387"), "Astronomie": Color("3F4A63"),
	"Histoire": Color("957638"), "Arts": Color("8E4A4F"), "Géographie": Color("737A45"), "Littérature": Color("6E5643"),
}
## Pictogrammes (assets/icons/<nom>.svg, traits blancs : on les teinte avec modulate).
const DISCIPLINE_ICONS := {
	"Nature": "nature", "Animaux": "animaux", "Sciences": "sciences", "Astronomie": "astronomie",
	"Histoire": "histoire", "Arts": "arts", "Géographie": "geographie", "Littérature": "litterature",
}

# Nuances de l'encre (même couleur, opacité différente).
const INK_STRONG := Color(0.161, 0.176, 0.165, 0.88)
const INK_SOFT := Color(0.161, 0.176, 0.165, 0.68)
const INK_FAINT := Color(0.161, 0.176, 0.165, 0.42)
const RULE := Color(0.161, 0.176, 0.165, 0.16)

# ---------- Espacements : grille de 8 ----------
const S1 := 4
const S2 := 8
const S3 := 16
const S4 := 24
const S5 := 32
const S6 := 48
const S7 := 64
const MARGIN := 40          # marge latérale des écrans
const RADIUS := 4           # coins : petits, partout pareils

# ---------- Polices : deux familles ----------
const SERIF: Font = preload("res://fonts/Newsreader-Regular.woff2")
const SERIF_MEDIUM: Font = preload("res://fonts/Newsreader-Medium.woff2")
const SERIF_ITALIC: Font = preload("res://fonts/Newsreader-Italic.woff2")
const SANS: Font = preload("res://fonts/DMSans-Regular.woff2")
const SANS_MEDIUM: Font = preload("res://fonts/DMSans-Medium.woff2")
const SANS_SEMIBOLD: Font = preload("res://fonts/DMSans-SemiBold.woff2")

## Rôles typographiques : la hiérarchie complète tient en dix lignes.
enum Role { DISPLAY, TITLE, HEADING, QUESTION, CLUE, NUMERAL, BODY, SMALL, CAPTION, OVERLINE }

static var _font_cache := {}


static func spaced(base: Font, spacing: int) -> FontVariation:
	var key := "%s|%d" % [base.resource_path, spacing]
	if not _font_cache.has(key):
		var fv := FontVariation.new()
		fv.base_font = base
		fv.spacing_glyph = spacing
		_font_cache[key] = fv
	return _font_cache[key]


## Applique un rôle typographique à un Label existant.
static func style(l: Label, role: Role, color := INK) -> void:
	var font: Font = SANS
	var size := 27
	var line := 0
	match role:
		Role.DISPLAY:
			font = spaced(SERIF_MEDIUM, 9)
			size = 66
		Role.TITLE:
			font = SERIF_MEDIUM
			size = 44
		Role.HEADING:
			font = SERIF_MEDIUM
			size = 32
		Role.QUESTION:
			font = SERIF
			size = 34
			line = 4
		Role.CLUE:
			font = SERIF
			size = 24
			line = 2
		Role.NUMERAL:
			font = SERIF_ITALIC
			size = 30
		Role.BODY:
			font = SANS
			size = 27
			line = 6
		Role.SMALL:
			font = SANS
			size = 23
		Role.CAPTION:
			font = SANS
			size = 20
		Role.OVERLINE:
			# Petite légende : italique, en minuscules (plus de capitales espacées).
			font = SERIF_ITALIC
			size = 24
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if line != 0:
		l.add_theme_constant_override("line_spacing", line)


static func label(text: String, role: Role, color := INK, wrap := false) -> Label:
	var l := Label.new()
	style(l, role, color)
	l.text = text
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


# ---------- Éléments de base ----------

## Filet fin. Les séparations passent par des filets, jamais par des cadres épais.
static func rule(color := RULE, thickness := 1) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.custom_minimum_size = Vector2(0, thickness)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func spacer(height: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func fill_h(c: Control) -> Control:
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


## Catégorie : petit carré terre cuite + légende en capitales. Le Label est le 2e enfant.
static func category_tag(text: String, color := TERRACOTTA) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", S2)
	var dot := ColorRect.new()
	dot.color = color
	dot.custom_minimum_size = Vector2(8, 8)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(dot)
	row.add_child(label(text, Role.OVERLINE, color))
	return row


## En-tête de section : un titre en serif, en minuscules, et un filet fin. `right` reste vide si inutile.
static func section_header(title: String, right := "") -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", S2)
	var row := HBoxContainer.new()
	box.add_child(row)
	var t := fill_h(label(title, Role.HEADING, INK)) as Label
	t.add_theme_font_size_override("font_size", 30)
	row.add_child(t)
	if right != "":
		var r := label(right, Role.OVERLINE, INK_SOFT)
		r.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		row.add_child(r)
	box.add_child(rule(RULE, 1))
	return box


static func discipline_color(discipline: String) -> Color:
	return DISCIPLINE_COLORS.get(discipline, SAGE)


static var _icon_cache := {}

## Pictogramme d'une discipline (texture blanche à teinter), ou null si la discipline n'en a pas.
static func discipline_icon(discipline: String) -> Texture2D:
	if not DISCIPLINE_ICONS.has(discipline):
		return null
	if not _icon_cache.has(discipline):
		_icon_cache[discipline] = load("res://assets/icons/%s.svg" % DISCIPLINE_ICONS[discipline])
	return _icon_cache[discipline]


## Pictogramme prêt à placer : `size` px de côté, teinté de `color`.
static func icon_rect(discipline: String, size: int, color: Color) -> TextureRect:
	var r := TextureRect.new()
	r.texture = discipline_icon(discipline)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(size, size)
	r.self_modulate = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## En-tête d'une page secondaire : flèche de retour puis titre, alignés à gauche.
## `on_back` est appelé quand on touche la flèche.
static func page_top(title: String, on_back: Callable) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	var bar := HBoxContainer.new()
	bar.custom_minimum_size = Vector2(0, 56)
	v.add_child(bar)
	var back := Button.new()
	back.theme_type_variation = "FlatButton"
	back.custom_minimum_size = Vector2(64, 56)
	back.pressed.connect(on_back)
	var chev := DsIcon.new(DsIcon.Kind.CHEVRON_LEFT, INK, 40)
	chev.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	chev.offset_left = 0
	chev.offset_right = 40
	chev.offset_top = -20
	chev.offset_bottom = 20
	back.add_child(chev)
	bar.add_child(back)
	var t := fill_h(label(title, Role.TITLE, INK)) as Label
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 44)
	bar.add_child(t)
	return v


## Texte de progression d'une discipline : « 10 dossiers » tant que rien n'est trouvé, puis « 3 trouvés sur 10 ».
## « 2 140 » : chiffres groupés par trois, séparés par une espace insécable.
static func thousands(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	while digits.length() > 3:
		out = "\u00A0" + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return ("-" if n < 0 else "") + digits + out


static func discipline_count(found: int, total: int) -> String:
	if found <= 0:
		return "%d dossier%s" % [total, "s" if total > 1 else ""]
	return "%d trouvé%s sur %d" % [found, "s" if found > 1 else "", total]


# ---------- Styles de boîtes ----------

static func box(bg: Color, border := Color.TRANSPARENT, border_w := 0, ml := 24.0, mr := 24.0, mt := 14.0, mb := 14.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(RADIUS)
	s.content_margin_left = ml
	s.content_margin_right = mr
	s.content_margin_top = mt
	s.content_margin_bottom = mb
	return s


## Ligne de liste : transparente, avec un filet en dessous.
static func row_box(bg: Color, ml := 76.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = RULE
	s.border_width_bottom = 1
	s.content_margin_left = ml
	s.content_margin_right = 16.0
	s.content_margin_top = 16.0
	s.content_margin_bottom = 16.0
	return s


## Fond de papier ivoire, partagé par tous les écrans.
static func paper_background() -> ColorRect:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://ds/paper.gdshader")
	bg.material = mat
	bg.resized.connect(func() -> void: mat.set_shader_parameter("rect_size", bg.size))
	return bg


static func build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = SANS
	t.default_font_size = 27
	t.set_color("font_color", "Label", INK)

	# Bouton principal : anthracite plein, texte ivoire. Rien de brillant.
	t.set_type_variation("PrimaryButton", "Button")
	t.set_stylebox("normal", "PrimaryButton", box(INK, Color.TRANSPARENT, 0, 24, 24, 0, 0))
	t.set_stylebox("hover", "PrimaryButton", box(Color("3A403C"), Color.TRANSPARENT, 0, 24, 24, 0, 0))
	t.set_stylebox("pressed", "PrimaryButton", box(Color("1F2321"), Color.TRANSPARENT, 0, 24, 24, 0, 0))
	t.set_stylebox("disabled", "PrimaryButton", box(Color(INK, 0.22), Color.TRANSPARENT, 0, 24, 24, 0, 0))
	t.set_stylebox("focus", "PrimaryButton", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		t.set_color(c, "PrimaryButton", IVORY)
	t.set_font("font", "PrimaryButton", spaced(SANS_SEMIBOLD, 1))
	t.set_font_size("font_size", "PrimaryButton", 26)

	# Bouton secondaire : simple filet anthracite.
	t.set_type_variation("GhostButton", "Button")
	t.set_stylebox("normal", "GhostButton", box(Color.TRANSPARENT, INK, 2, 24, 24, 0, 0))
	t.set_stylebox("hover", "GhostButton", box(IVORY_DEEP, INK, 2, 24, 24, 0, 0))
	t.set_stylebox("pressed", "GhostButton", box(IVORY_DEEP, INK, 2, 24, 24, 0, 0))
	t.set_stylebox("disabled", "GhostButton", box(Color.TRANSPARENT, Color(INK, 0.3), 2, 24, 24, 0, 0))
	t.set_stylebox("focus", "GhostButton", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		t.set_color(c, "GhostButton", INK)
	t.set_color("font_disabled_color", "GhostButton", INK_FAINT)
	t.set_font("font", "GhostButton", spaced(SANS_SEMIBOLD, 1))
	t.set_font_size("font_size", "GhostButton", 26)

	# Ligne de réponse / de sommaire : texte sur filet.
	t.set_type_variation("RowButton", "Button")
	t.set_stylebox("normal", "RowButton", row_box(Color.TRANSPARENT))
	t.set_stylebox("hover", "RowButton", row_box(IVORY_DEEP))
	t.set_stylebox("pressed", "RowButton", row_box(IVORY_DEEP))
	t.set_stylebox("disabled", "RowButton", row_box(Color.TRANSPARENT))
	t.set_stylebox("focus", "RowButton", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		t.set_color(c, "RowButton", INK)
	t.set_color("font_disabled_color", "RowButton", INK_FAINT)
	t.set_font("font", "RowButton", SANS_MEDIUM)
	t.set_font_size("font_size", "RowButton", 26)

	# Bouton sans cadre (retour, liens).
	# Bouton ivoire, pour le fond vert sombre de la couverture.
	t.set_type_variation("IvoryButton", "Button")
	t.set_stylebox("normal", "IvoryButton", box(IVORY, Color.TRANSPARENT, 0, 24, 24, 0, 0))
	t.set_stylebox("hover", "IvoryButton", box(IVORY_CARD, Color.TRANSPARENT, 0, 24, 24, 0, 0))
	t.set_stylebox("pressed", "IvoryButton", box(IVORY_DEEP, Color.TRANSPARENT, 0, 24, 24, 0, 0))
	t.set_stylebox("focus", "IvoryButton", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(c, "IvoryButton", INK)
	t.set_font("font", "IvoryButton", spaced(SANS_SEMIBOLD, 1))
	t.set_font_size("font_size", "IvoryButton", 28)

	t.set_type_variation("FlatButton", "Button")
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		t.set_stylebox(state, "FlatButton", StyleBoxEmpty.new())

	# Carte d'archive : papier clair, filet fin, petits coins.
	t.set_type_variation("Card", "PanelContainer")
	t.set_stylebox("panel", "Card", box(IVORY_CARD, Color(INK, 0.30), 1, 28, 28, 24, 20))

	# Cellule : encadré léger.
	t.set_type_variation("Cell", "PanelContainer")
	t.set_stylebox("panel", "Cell", box(Color.TRANSPARENT, Color(INK, 0.30), 1, 20, 20, 18, 18))
	return t
