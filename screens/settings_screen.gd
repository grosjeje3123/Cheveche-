class_name SettingsScreen
extends Control
## « Réglages » : son, vibrations ; « Comment jouer » ; le code de sauvegarde (copier, restaurer) et la remise à zéro de la progression
## (deux touchers pour confirmer ce qui remplace ou efface, sans fenêtre surgissante) ; crédits.
## On y arrive depuis la couverture ; la flèche y ramène.

signal closed
signal open_credits
## « Comment jouer » : les règles, à relire.
signal open_rules
## La progression vient d'être effacée ou remplacée (les autres écrans doivent se remettre à jour).
signal progress_reset

const VERSION_TEXT := "Chevêche, prototype 0.9.33."
## Délai pour confirmer par un second toucher (remise à zéro, restauration), et durée des messages d'état.
const CONFIRM_SECONDS := 4.0

## Le presse-papiers (remplaçable dans les tests).
var clipboard_get := func() -> String: return DisplayServer.clipboard_get()
var clipboard_set := func(text: String) -> void: DisplayServer.clipboard_set(text)

var _settings: Settings
var _save: SaveStore
var _sound_state: Label
var _vibration_state: Label
var _reset_state: Label
var _copy_state: Label
var _restore_state: Label
## La ligne qui attend un second toucher (son état), ou null.
var _armed: Label
## Le dernier message d'état posé : seul le plus récent s'efface à la fin de son délai.
var _timer: SceneTreeTimer


func setup(settings: Settings, save: SaveStore) -> void:
	_settings = settings
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
	head.add_child(Ds.page_top("Réglages", func() -> void:
		_disarm()
		closed.emit()))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", Ds.MARGIN)
	margin.add_theme_constant_override("margin_right", Ds.MARGIN)
	margin.add_theme_constant_override("margin_top", Ds.S5)
	margin.add_theme_constant_override("margin_bottom", Ds.S6)
	scroll.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	margin.add_child(col)

	col.add_child(Ds.section_header("Jeu"))
	var sound := _row(col, "Son")
	_sound_state = sound[1]
	(sound[0] as Button).pressed.connect(func() -> void:
		_settings.set_sound(not _settings.sound)
		_refresh()
		Feedback.say("tap"))
	var vib := _row(col, "Vibrations")
	_vibration_state = vib[1]
	(vib[0] as Button).pressed.connect(func() -> void:
		_settings.set_vibration(not _settings.vibration)
		_refresh()
		if _settings.vibration:
			Feedback.say("clue"))

	col.add_child(Ds.spacer(Ds.S6))
	col.add_child(Ds.section_header("Progression"))
	var copy := _row(col, "Copier ma sauvegarde")
	_copy_state = copy[1]
	(copy[0] as Button).pressed.connect(_on_copy_pressed)
	var restore := _row(col, "Restaurer une sauvegarde")
	_restore_state = restore[1]
	(restore[0] as Button).pressed.connect(_on_restore_pressed)
	col.add_child(Ds.spacer(Ds.S2))
	col.add_child(Ds.label("Votre progression reste sur cet appareil : rien n’est envoyé. Pour la retrouver ailleurs, copiez votre sauvegarde et gardez ce code dans une note ou un message à vous-même. Sur l’autre appareil, copiez le code, puis touchez « Restaurer une sauvegarde ».",
			Ds.Role.SMALL, Ds.INK_SOFT, true))
	col.add_child(Ds.spacer(Ds.S3))
	var reset := _row(col, "Remettre à zéro")
	_reset_state = reset[1]
	(reset[0] as Button).pressed.connect(_on_reset_pressed)
	col.add_child(Ds.spacer(Ds.S2))
	col.add_child(Ds.label("La remise à zéro efface les dossiers trouvés, les scores et les défis ; elle garde ces réglages.",
			Ds.Role.SMALL, Ds.INK_SOFT, true))

	col.add_child(Ds.spacer(Ds.S6))
	col.add_child(Ds.section_header("À propos"))
	var rules := _row(col, "Comment jouer", true)
	(rules[0] as Button).pressed.connect(func() -> void:
		_disarm()
		open_rules.emit())
	var credits := _row(col, "Crédits", true)
	(credits[0] as Button).pressed.connect(func() -> void: open_credits.emit())
	col.add_child(Ds.spacer(Ds.S3))
	col.add_child(Ds.label(VERSION_TEXT, Ds.Role.SMALL, Ds.INK_SOFT))
	_refresh()


## Une ligne qu'on touche : un nom à gauche, un état (ou une flèche) à droite. Renvoie [bouton, état].
func _row(col: VBoxContainer, title: String, chevron := false) -> Array:
	var b := Button.new()
	b.theme_type_variation = "RowButton"
	b.custom_minimum_size = Vector2(0, 88)
	col.add_child(b)
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 4
	h.offset_right = -4
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var t := Ds.fill_h(Ds.label(title, Ds.Role.BODY, Ds.INK)) as Label
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(t)
	var state := Ds.label("", Ds.Role.OVERLINE, Ds.INK_SOFT)
	state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(state)
	if chevron:
		var c := DsIcon.new(DsIcon.Kind.CHEVRON_RIGHT, Ds.INK_SOFT, 32)
		c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(c)
	return [b, state]


func _refresh() -> void:
	_set_state(_sound_state, _settings.sound)
	_set_state(_vibration_state, _settings.vibration)


func _set_state(l: Label, on: bool) -> void:
	l.text = "Activé" if on else "Coupé"
	l.add_theme_color_override("font_color", Ds.SAGE if on else Ds.INK_FAINT)


# Un message dans l'état d'une ligne, effacé au bout de CONFIRM_SECONDS (sauf si un autre l'a remplacé).
func _say(l: Label, text: String, color: Color) -> void:
	for other in [_copy_state, _restore_state, _reset_state]:
		if other != l:
			other.text = ""
	l.text = text
	l.add_theme_color_override("font_color", color)
	_timer = get_tree().create_timer(CONFIRM_SECONDS)
	var timer := _timer
	timer.timeout.connect(func() -> void:
		if _timer == timer:
			_disarm())


func _arm(l: Label, text: String) -> void:
	_say(l, text, Ds.TERRACOTTA)
	_armed = l


func _on_copy_pressed() -> void:
	_armed = null
	clipboard_set.call(_save.export_code())
	_say(_copy_state, "Copiée", Ds.SAGE)
	Feedback.say("tap")


# Premier toucher : on lit le presse-papiers ; s'il contient un code, on demande confirmation. Second toucher :
# la progression est remplacée.
func _on_restore_pressed() -> void:
	var text: String = clipboard_get.call()
	if SaveStore.decode_code(text).is_empty():
		_armed = null
		_say(_restore_state, "Copiez d’abord un code", Ds.TERRACOTTA)
		return
	if _armed != _restore_state:
		_arm(_restore_state, "Toucher encore pour remplacer")
		return
	_armed = null
	if _save.import_code(text):
		_say(_restore_state, "Restaurée", Ds.SAGE)
		progress_reset.emit()
	else:
		_say(_restore_state, "Code illisible", Ds.TERRACOTTA)


# Premier toucher : on demande confirmation (quelques secondes). Second toucher : on efface.
func _on_reset_pressed() -> void:
	if _armed != _reset_state:
		_arm(_reset_state, "Toucher encore pour tout effacer")
		return
	_armed = null
	_save.reset()
	_say(_reset_state, "Effacée", Ds.SAGE)
	progress_reset.emit()


func _disarm() -> void:
	_armed = null
	_timer = null
	for l in [_copy_state, _restore_state, _reset_state]:
		if l != null:
			l.text = ""


## À l'ouverture de l'écran : rien n'est en attente de confirmation.
func reopen() -> void:
	_disarm()
	_refresh()
