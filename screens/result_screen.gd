class_name ResultScreen
extends Control
## Fin d'une série (dix dossiers d'une fiche, ou le défi du jour) : la chouette sur ses livres sous une courte pluie
## de papier découpé (`celebrate`), le score, un mot, ce qui a été trouvé (et les pépites), le niveau s'il a monté,
## le détail de chaque dossier avec sa difficulté, les crédits des images, puis la suite ou le retour.

signal back
signal open_credits
## « Série suivante » (seulement avec `next_text` dans `info`).
signal next_pressed

## La pluie de papier (null sans `celebrate`).
var confetti: PaperConfetti
## L'illustration de la chouette (null sans `celebrate`).
var owl: TextureRect

var _fade: Array[Control] = []
## Le tampon dateur de la page (null sans `stamp` dans `info`).
var stamp: DsStamp
## Le bouton qui copie le résultat (null sans `share` dans `info`).
var share_button: Button
## Le presse-papiers (remplaçable dans les tests).
var clipboard_set := func(text: String) -> void: DisplayServer.clipboard_set(text)


## `info` : {kicker: String (en haut à gauche, ex. « Défi du jour »), label: String (en haut à droite, ex. la date),
##           back_text: String, note: String (ligne en sauge, ex. « 3 jours de suite »),
##           stamp: {top, day, month, bottom} (facultatif : tampon dateur à droite du score, posé à l'ouverture),
##           share: String (facultatif : texte copié par « Copier mon résultat »),
##           quiet: bool (page revue plus tard : le tampon est déjà posé, pas de jingle),
##           celebrate: bool (la chouette ; et la pluie de papier, si au moins la moitié est trouvée),
##           summary: String (remplace « 3 bonnes réponses sur 5 »),
##           next_text: String (bouton principal « Série suivante » ; le retour devient un bouton discret)}
func show_results(pack: QuestionPack, results: Array, info: Dictionary) -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_fade.clear()

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

	# En-tête : la chouette, puis ce qui vient d'être joué.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", Ds.S2)
	col.add_child(top)
	# La signature du jeu, dans le coin (elle se retrouve sur une capture d'écran) ; sauf quand l'illustration de la
	# chouette vient fêter la série juste en dessous : une seule chouette par page.
	if not bool(info.get("celebrate", false)):
		top.add_child(OwlMark.new(48))
	var kicker := Ds.fill_h(Ds.label(str(info.get("kicker", "Terminé")), Ds.Role.OVERLINE, Ds.INK_SOFT))
	(kicker as Label).vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(kicker)
	var where := Ds.label(str(info.get("label", "")), Ds.Role.OVERLINE, Ds.INK_SOFT)
	where.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(where)
	col.add_child(Ds.spacer(Ds.S2))
	col.add_child(Ds.rule(Ds.RULE, 1))
	var celebrate := bool(info.get("celebrate", false))
	owl = null
	confetti = null
	if celebrate:
		# La chouette sur ses livres : l'illustration de la couverture, qui vient saluer la fin de la série.
		col.add_child(Ds.spacer(Ds.S3))
		owl = TextureRect.new()
		owl.texture = RulesScreen.SCENE
		owl.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		owl.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		owl.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		owl.custom_minimum_size = Vector2(0, 180)
		owl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(owl)
		_fade.append(owl)
		col.add_child(Ds.spacer(Ds.S2))
	else:
		col.add_child(Ds.spacer(Ds.S5))

	# Le score : un grand chiffre, puis un mot. Avec un tampon : le score à gauche, le tampon à droite,
	# comme une fiche remplie puis tamponnée ; sans tampon, tout est centré.
	var count := results.size()
	var total := Scoring.total(results)
	var right := Scoring.correct_count(results)
	var stamp_info: Dictionary = info.get("stamp", {})
	stamp = null
	var block := col
	var align := HORIZONTAL_ALIGNMENT_CENTER
	if not stamp_info.is_empty():
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", Ds.S3)
		col.add_child(head)
		block = VBoxContainer.new()
		block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		block.alignment = BoxContainer.ALIGNMENT_CENTER
		block.add_theme_constant_override("separation", 0)
		head.add_child(block)
		align = HORIZONTAL_ALIGNMENT_LEFT
		stamp = DsStamp.new(216.0)
		stamp.color = Ds.SAGE
		stamp.arc_text_scale = 0.17
		stamp.top_text = str(stamp_info.get("top", ""))
		stamp.bottom_text = str(stamp_info.get("bottom", ""))
		stamp.center_text = str(stamp_info.get("day", ""))
		stamp.center_caption = str(stamp_info.get("month", ""))
		stamp.filled = total >= Scoring.max_total(count) and count > 0   # défi parfait : tampon plein
		stamp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(stamp)
	var score := HBoxContainer.new()
	score.alignment = BoxContainer.ALIGNMENT_CENTER if align == HORIZONTAL_ALIGNMENT_CENTER else BoxContainer.ALIGNMENT_BEGIN
	score.add_theme_constant_override("separation", Ds.S3)
	block.add_child(score)
	var big := Ds.label(str(total), Ds.Role.DISPLAY, Ds.INK)
	big.add_theme_font_override("font", Ds.SERIF_MEDIUM)
	big.add_theme_font_size_override("font_size", 124)
	score.add_child(big)
	var of := Ds.label("/ %d" % Scoring.max_total(count), Ds.Role.NUMERAL, Ds.INK_SOFT)
	of.size_flags_vertical = Control.SIZE_SHRINK_END
	of.add_theme_constant_override("line_spacing", 0)
	var of_box := MarginContainer.new()
	of_box.size_flags_vertical = Control.SIZE_SHRINK_END
	of_box.add_theme_constant_override("margin_bottom", 22)
	of_box.add_child(of)
	score.add_child(of_box)
	_fade.append(score)

	var verdict := Ds.label(Scoring.verdict(results), Ds.Role.NUMERAL, Ds.INK)
	verdict.add_theme_font_size_override("font_size", 36)
	verdict.horizontal_alignment = align
	block.add_child(verdict)
	_fade.append(verdict)
	block.add_child(Ds.spacer(Ds.S1))
	var sub := Ds.label(str(info.get("summary", "%d bonne%s réponse%s sur %d" % [right, "s" if right > 1 else "",
			"s" if right > 1 else "", count])), Ds.Role.SMALL, Ds.INK_SOFT, true)
	sub.horizontal_alignment = align
	block.add_child(sub)
	_fade.append(sub)
	var record := str(info.get("note", ""))
	if record != "":
		block.add_child(Ds.spacer(Ds.S1))
		var rl := Ds.label(record, Ds.Role.SMALL, Ds.SAGE, true)
		rl.horizontal_alignment = align
		block.add_child(rl)
		_fade.append(rl)
	col.add_child(Ds.spacer(Ds.S4))

	# Le détail : une ligne par dossier, puis les crédits des images (seulement s'il y en a).
	col.add_child(Ds.section_header("Les dossiers", "points"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 0)
	scroll.add_child(list)

	var with_image := false
	for i in results.size():
		var r: Dictionary = results[i]
		var q := pack.by_id(str(r["id"]))
		if q.is_empty():
			continue
		var row := _row(i + 1, r, q, pack)
		list.add_child(row)
		_fade.append(row)
		with_image = with_image or pack.has_verified_image(q)
	# Les crédits complets (titres, auteurs, licences, liens) sont sur leur propre page : ici, juste le chemin.
	if with_image:
		list.add_child(Ds.spacer(Ds.S2))
		var more := Button.new()
		more.theme_type_variation = "FlatButton"
		more.text = "Crédits des images"
		more.alignment = HORIZONTAL_ALIGNMENT_LEFT
		more.custom_minimum_size = Vector2(0, 56)
		more.add_theme_font_override("font", Ds.SERIF_ITALIC)
		more.add_theme_font_size_override("font_size", 24)
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			more.add_theme_color_override(c, Ds.TERRACOTTA)
		more.pressed.connect(func() -> void: open_credits.emit())
		list.add_child(more)

	col.add_child(Ds.spacer(Ds.S3))
	share_button = null
	var share := str(info.get("share", ""))
	if share != "":
		share_button = Button.new()
		share_button.theme_type_variation = "GhostButton"
		share_button.text = SHARE_TEXT
		share_button.custom_minimum_size = Vector2(0, 88)
		share_button.pressed.connect(func() -> void: _copy_share(share))
		col.add_child(share_button)
		col.add_child(Ds.spacer(Ds.S2))
	var next_text := str(info.get("next_text", ""))
	if next_text != "":
		var next := Button.new()
		next.theme_type_variation = "PrimaryButton"
		next.text = next_text
		next.custom_minimum_size = Vector2(0, 96)
		next.pressed.connect(func() -> void: next_pressed.emit())
		col.add_child(next)
		col.add_child(Ds.spacer(Ds.S2))
	var leave := Button.new()
	leave.theme_type_variation = "PrimaryButton" if next_text == "" else "GhostButton"
	leave.text = str(info.get("back_text", "Retour"))
	leave.custom_minimum_size = Vector2(0, 96 if next_text == "" else 80)
	leave.pressed.connect(func() -> void: back.emit())
	col.add_child(leave)

	# La pluie de papier quand au moins la moitié des dossiers est trouvée ; sinon, la chouette seule.
	if celebrate and Scoring.correct_count(results) * 2 >= results.size():
		confetti = PaperConfetti.new()
		confetti.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(confetti)

	var quiet := bool(info.get("quiet", false))
	_play_intro(quiet)
	if quiet:
		return
	if confetti != null:
		get_tree().create_timer(0.25).timeout.connect(func() -> void:
			if is_instance_valid(confetti):
				confetti.burst())
	# Le jingle arrive avec le score, une fois l'écran apparu (après le tampon, s'il y en a un).
	var effect := Scoring.finish_effect(results)
	get_tree().create_timer(0.35 if stamp == null else 0.85).timeout.connect(func() -> void: Feedback.say(effect))


const SHARE_TEXT := "Copier mon résultat"
## L'ocre des pépites, foncé pour se lire sur le papier.
const PEPITE_INK := Color("8C7440")


# Le résultat part dans le presse-papiers ; le bouton le dit quelques secondes, puis reprend son nom.
func _copy_share(text: String) -> void:
	clipboard_set.call(text)
	Feedback.say("tap")
	var b := share_button
	b.text = "Copié : collez-le dans un message"
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		if is_instance_valid(b):
			b.text = SHARE_TEXT)


# Une ligne de détail : rang dans le défi, réponse, ce qui a été lu, points.
func _row(rank: int, r: Dictionary, q: Dictionary, pack: QuestionPack) -> Control:
	var correct: bool = r["correct"]
	var clues := int(r["clues"])
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_top", 16)
	pad.add_theme_constant_override("margin_bottom", 16)
	box.add_child(pad)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", Ds.S3)
	pad.add_child(h)

	var num := Ds.label(str(rank), Ds.Role.NUMERAL, Ds.INK_FAINT)
	num.custom_minimum_size = Vector2(36, 0)
	h.add_child(num)

	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 2)
	h.add_child(words)
	var name := Ds.label(str(q["reponse_courte"]), Ds.Role.HEADING, Ds.INK, true)
	name.add_theme_font_size_override("font_size", 28)
	words.add_child(name)
	var detail: String
	var in_image := bool(r.get("visual", false))
	if not correct:
		detail = "manqué"
	elif in_image:
		var pct := PlayScreen.percent(float(r.get("revealed", 0.0)))
		detail = "rien gratté" if pct == 0 else "%d %% dévoilé" % pct
	elif clues == 0:
		detail = "sans indice"
	else:
		detail = "%d indice%s" % [clues, "s" if clues > 1 else ""]
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", Ds.S2)
	words.add_child(line)
	# La difficulté du dossier, en cinq barres, avant ce qui s'est passé.
	var level := DsLevel.new(16.0)
	level.color = Ds.INK_SOFT
	level.level = pack.difficulty_level(q)
	level.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(level)
	var what := "Dossier en image" if in_image else "Dossier %d" % pack.dossier_number(q)
	line.add_child(Ds.label("%s, %s" % [what, detail], Ds.Role.SMALL, Ds.INK_SOFT if correct else Ds.TERRACOTTA))
	if bool(r.get("pepite", false)):
		line.add_child(Ds.label("pépite", Ds.Role.SMALL, PEPITE_INK))

	var pts := Ds.label(("+%d" % int(r["points"])) if correct else "0", Ds.Role.NUMERAL,
			Ds.SAGE if correct else Ds.INK_FAINT)
	pts.add_theme_font_size_override("font_size", 34)
	pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pts.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(pts)

	box.add_child(Ds.rule())
	return box


func _play_intro(quiet := false) -> void:
	if stamp != null and not quiet:
		# Le tampon tombe sur la page, un peu après le score, avec son « tchok » (voir CompleteScreen).
		stamp.modulate.a = 0.0
		stamp.scale = Vector2(1.4, 1.4)
		var st := create_tween()
		st.tween_interval(0.42)
		st.tween_property(stamp, "modulate:a", 1.0, 0.06)
		st.parallel().tween_property(stamp, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		st.tween_callback(func() -> void: Feedback.say("stamp"))
		st.tween_property(stamp, "scale", Vector2(0.97, 0.97), 0.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		st.tween_property(stamp, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var tw := create_tween().set_parallel(true)
	for i in _fade.size():
		var c := _fade[i]
		c.modulate.a = 0.0
		tw.tween_property(c, "modulate:a", 1.0, 0.4).set_delay(0.08 + i * 0.07).set_trans(Tween.TRANS_SINE)
