class_name CompleteScreen
extends Control
## Fiche complète : les 30 dossiers d'une discipline sont trouvés (ou, plus tard, tous trouvés sans indice),
## au niveau 1 ou au niveau 2. Un tampon se pose, puis le bilan et la suite : le niveau 2 qui s'ouvre,
## ou trouver chaque dossier sans indice. Pas de confettis : une page de carnet qu'on tamponne, et on continue.

signal continue_pressed
signal back
## « Jouer le niveau 2 », quand la page l'annonce.
signal play_next_level

var stamp: DsStamp
var _fade: Array[Control] = []


## `info` : {discipline: String, total: int (dossiers de la fiche), points: int (meilleurs points cumulés),
##           flawless: int (dossiers trouvés sans indice), perfect: bool (tous sans indice),
##           level: int (1 ou 2), next_level: bool (le niveau 2 est ouvert et reste à jouer : la page le propose)}
func show_fiche(info: Dictionary) -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_fade.clear()
	var discipline := str(info.get("discipline", ""))
	var total := int(info.get("total", 0))
	var points := int(info.get("points", 0))
	var flawless := int(info.get("flawless", 0))
	var perfect := bool(info.get("perfect", false))
	var level := int(info.get("level", 1))
	var next_level := bool(info.get("next_level", false))
	var kicker_text := ("Sans faute" if perfect else "Fiche complète") if level < 2 \
			else ("Niveau 2 sans faute" if perfect else "Niveau 2 complet")

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", Ds.MARGIN)
	margin.add_theme_constant_override("margin_right", Ds.MARGIN)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 56)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	margin.add_child(col)

	# En-tête : la chouette, ce qui vient d'arriver, la discipline.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", Ds.S2)
	col.add_child(top)
	top.add_child(OwlMark.new(48))
	var kicker := Ds.fill_h(Ds.label(kicker_text, Ds.Role.OVERLINE, Ds.INK_SOFT))
	(kicker as Label).vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(kicker)
	var where := Ds.label(discipline, Ds.Role.OVERLINE, Ds.INK_SOFT)
	where.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(where)
	col.add_child(Ds.spacer(Ds.S2))
	col.add_child(Ds.rule(Ds.RULE, 1))

	var flex_top := Control.new()
	flex_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	flex_top.size_flags_stretch_ratio = 0.8
	col.add_child(flex_top)

	# Le tampon : terre cuite (anthracite au niveau 2), plein si tout est trouvé sans indice.
	var holder := CenterContainer.new()
	col.add_child(holder)
	stamp = DsStamp.new(300.0)
	stamp.discipline = discipline
	stamp.top_text = ("Sans faute" if perfect else "Fiche complète") if level < 2 else ("Sans faute" if perfect else "Niveau 2")
	stamp.bottom_text = discipline
	stamp.filled = perfect
	if level >= 2:
		stamp.color = Ds.INK
	holder.add_child(stamp)
	col.add_child(Ds.spacer(Ds.S5))

	var title := Ds.label(discipline if level < 2 else "%s, niveau 2" % discipline, Ds.Role.TITLE, Ds.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	_fade.append(title)
	var sub_text := "Les %d dossiers trouvés sans aucun indice." % total if perfect else "Les %d dossiers sont trouvés." % total
	var sub := Ds.label(sub_text, Ds.Role.NUMERAL, Ds.INK)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	_fade.append(sub)
	col.add_child(Ds.spacer(Ds.S5))

	# Deux chiffres : les points de la fiche (meilleur score de chaque dossier) et les dossiers trouvés sans indice.
	var figures := HBoxContainer.new()
	figures.add_theme_constant_override("separation", Ds.S3)
	col.add_child(figures)
	_figure(figures, Ds.thousands(points), "points sur %s" % Ds.thousands(total * Scoring.MAX_POINTS))
	_figure(figures, str(flawless), "sans indice, sur %d" % total)
	_fade.append(figures)
	col.add_child(Ds.spacer(Ds.S4))

	var left := total - flawless
	var next_text := "Rien à redire : chaque dossier de la fiche a été trouvé du premier coup d’œil." if perfect \
			else "Nouvel objectif : trouver les %d autre%s sans indice. En rejouant la fiche, ce sont eux qui passent en premier." % [left, "s" if left > 1 else ""]
	if next_level:
		next_text = "Le niveau 2 est ouvert : 30 dossiers plus pointus vous attendent dans cette fiche."
	var next := Ds.label(next_text, Ds.Role.SMALL, Ds.INK_SOFT, true)
	next.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(next)
	_fade.append(next)

	var flex := Control.new()
	flex.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(flex)
	# Niveau 2 ouvert : on propose d'y aller tout de suite (« Plus tard » reprend là où on en était).
	var go := Button.new()
	go.theme_type_variation = "PrimaryButton"
	go.text = "Jouer le niveau 2" if next_level else "Continuer"
	go.custom_minimum_size = Vector2(0, 96)
	go.pressed.connect(func() -> void: (play_next_level if next_level else continue_pressed).emit())
	col.add_child(go)
	var leave := Button.new()
	leave.theme_type_variation = "FlatButton"
	leave.text = "Plus tard" if next_level else "Retour à la couverture"
	leave.custom_minimum_size = Vector2(0, 64)
	leave.add_theme_font_size_override("font_size", 26)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		leave.add_theme_color_override(c, Ds.INK_SOFT)
	leave.pressed.connect(func() -> void: (continue_pressed if next_level else back).emit())
	col.add_child(leave)
	_fade.append(go)
	_fade.append(leave)
	_play_intro()


func _figure(row: HBoxContainer, number: String, caption: String) -> void:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 0)
	row.add_child(box)
	var n := Ds.label(number, Ds.Role.TITLE, Ds.INK)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(n)
	var cap := Ds.label(caption, Ds.Role.SMALL, Ds.INK_SOFT)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(cap)


# Le seul moment animé : le tampon tombe sur la page (un peu trop grand, de plus en plus vite), touche le papier
# avec son « tchok » et s'écrase à peine, puis le jingle ; le texte apparaît ensuite.
func _play_intro() -> void:
	stamp.modulate.a = 0.0
	stamp.scale = Vector2(1.4, 1.4)
	var tw := create_tween()
	tw.tween_interval(0.25)
	tw.tween_property(stamp, "modulate:a", 1.0, 0.06)
	tw.parallel().tween_property(stamp, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: Feedback.say("stamp"))
	tw.tween_property(stamp, "scale", Vector2(0.97, 0.97), 0.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(stamp, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_interval(0.12)
	tw.tween_callback(func() -> void: Feedback.say("complete"))
	var texts := create_tween().set_parallel(true)
	for i in _fade.size():
		var c := _fade[i]
		c.modulate.a = 0.0
		texts.tween_property(c, "modulate:a", 1.0, 0.4).set_delay(0.6 + i * 0.07).set_trans(Tween.TRANS_SINE)
