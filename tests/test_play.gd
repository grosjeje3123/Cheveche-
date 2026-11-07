extends SceneTree

var fails := 0

func check(label: String, ok: bool, extra := "") -> void:
	print(("OK   " if ok else "FAIL ") + label + ("  " + extra if extra != "" else ""))
	if not ok:
		fails += 1

func _btn(cover: Control, pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	cover._gui_input(e)

func _mv(cover: Control, pos: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	cover._gui_input(e)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

# Gratte par bandes horizontales jusqu'à atteindre la fraction visée (ou la fin).
func _scratch_to(cover: ScratchCover, target: float) -> void:
	var y := 8.0
	var ltr := true
	_btn(cover, Vector2(10, y), true)
	while y < cover.size.y and cover.scratch_fraction < target:
		_mv(cover, Vector2(cover.size.x - 10 if ltr else 10.0, y))
		cover._process(0.0)
		ltr = not ltr
		y += cover.size.x * cover.brush_radius_ratio * 0.8
	_btn(cover, Vector2(10, y), false)
	await _frames(2)

func _enabled(play: PlayScreen) -> int:
	var n := 0
	for b in play._options:
		if not b.disabled:
			n += 1
	return n

func _initialize() -> void:
	var pack := QuestionPack.load_file("res://data/packs/svt_01.json")
	check("pack chargé", pack != null)
	check("15 questions", pack.questions.size() == 15, str(pack.questions.size()))
	check("0 ignorée", int(pack.ignored) == 0, str(pack.ignored))
	check("Nature = 10", pack.questions_in("Nature").size() == 10)
	check("Sciences = 5", pack.questions_in("Sciences").size() == 5)
	for q in pack.questions:
		var ch := QuestionPack.choices_for(q)
		var uniq := {}
		for c in ch:
			uniq[c] = true
		if ch.size() != 4 or uniq.size() != 4 or not (q["reponse_courte"] in ch):
			check("choix valides " + q["id"], false, str(ch))
	check("choix valides (15 questions)", true)
	check("toutes les images du pack sont vérifiées et présentes", pack.questions.all(func(q): return pack.has_verified_image(q)))

	check("RevealRules 0.24 -> 0 indice", RevealRules.clues_unlocked(0.24) == 0)
	check("RevealRules 0.25 -> 1", RevealRules.clues_unlocked(0.25) == 1)
	check("RevealRules 0.50 -> 2", RevealRules.clues_unlocked(0.50) == 2)
	check("RevealRules 0.75 -> toujours 2 (deux indices au plus)", RevealRules.clues_unlocked(0.75) == 2)
	check("RevealRules 1.0 -> 2", RevealRules.clues_unlocked(1.0) == 2)
	check("RevealRules : deux indices par dossier", RevealRules.clue_count() == 2)
	check("Scoring : 100 / 60 / 30", Scoring.points_for(true, 0) == 100 and Scoring.points_for(true, 1) == 60 and Scoring.points_for(true, 2) == 30)
	check("Scoring : jamais plus de points qu'avec 0 indice, plafonné à 2 indices", Scoring.points_for(true, 3) == 30 and Scoring.points_for(false, 0) == 0)
	check("chaque dossier du pack a exactement 2 indices", pack.questions.all(func(q): return q["indices"].size() == 2))
	check("aucune question ne renvoie à l'image (« cet », « cette », « ces »)",
			not pack.questions.any(func(q): return RegEx.create_from_string("\\b(cet|cette|ces)\\b").search(q["question"]) != null))

	root.size = Vector2i(720, 1280)
	var play := PlayScreen.new()
	play.theme = Ds.build_theme()
	play.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(play)
	play.build()
	await _frames(3)
	var qs := pack.questions.slice(0, 3)
	play.start(pack, qs)
	await _frames(6)
	var cover := play._zone.cover
	print("cover size ", cover.size, " zone ", play._zone.size)

	check("départ : fraction 0", cover.scratch_fraction == 0.0)
	check("départ : les 4 réponses sont déjà ouvertes (on peut répondre sans gratter)", _enabled(play) == 4)
	check("départ : 0 indice", play._clues.unlocked_count() == 0)
	check("départ : la photo du dossier est affichée", play._zone.shows_photo())

	await _scratch_to(cover, 0.12)
	print("fraction ", cover.scratch_fraction)
	check("12 % : réponses ouvertes", _enabled(play) == 4)
	check("12 % : toujours 0 indice", play._clues.unlocked_count() == 0)
	check("12 % : le dossier vaut 100 pts", play._points.text == "100 pts", play._points.text)

	await _scratch_to(cover, 0.30)
	print("fraction ", cover.scratch_fraction)
	check("≥25 % : 1 indice", play._clues.unlocked_count() == 1, str(play._clues.unlocked_count()))
	check("≥25 % : le dossier vaut 60 pts", play._points.text == "60 pts", play._points.text)

	await _scratch_to(cover, 0.55)
	print("fraction ", cover.scratch_fraction)
	check("≥50 % : 2 indices", play._clues.unlocked_count() == 2, str(play._clues.unlocked_count()))
	check("≥50 % : le dossier vaut 30 pts", play._points.text == "30 pts", play._points.text)
	await _scratch_to(cover, 0.90)
	check("90 % : toujours 2 indices, 30 pts", play._clues.unlocked_count() == 2 and play._points.text == "30 pts")

	# bonne réponse avec 2 indices
	var correct: String = play._correct_text
	var card_before: Vector2 = play._card.size
	var zone_before: float = play._zone.size.y
	var next_y_before: float = play._next.position.y
	check("image : hauteur entre %d et %d px" % [int(PlayScreen.ZONE_MIN), int(PlayScreen.ZONE_MAX)],
			zone_before >= PlayScreen.ZONE_MIN - 0.5 and zone_before <= PlayScreen.ZONE_MAX + 0.5, str(zone_before))
	check("réponses : lignes entre %d et %d px" % [int(PlayScreen.ROW_MIN), int(PlayScreen.ROW_MAX)],
			play._options.all(func(o): return o.size.y >= PlayScreen.ROW_MIN - 0.5 and o.size.y <= PlayScreen.ROW_MAX + 0.5), str(play._options[0].size.y))
	var rows_before := 0.0
	for o in play._options:
		rows_before += o.size.y
	var got: Array = []
	play.answered.connect(func(id: String, ok: bool, clues: int, pts: int) -> void: got.append([id, ok, clues, pts]))
	for b in play._options:
		if b.text == correct:
			b.pressed.emit()
	await _frames(4)
	print("feedback: ", play._feedback.text)
	check("bonne réponse : +30 points affichés", play._points.text == "+30", play._points.text)
	check("signal answered : [id, juste, 2 indices, 30]", got.size() == 1 and got[0] == [qs[0]["id"], true, 2, 30], str(got))
	check("explication visible, réponses masquées", play._slot.visible and not play._options.any(func(o): return o.visible))
	check("zone d'explication au moins aussi haute que les 4 réponses", play._slot.size.y >= rows_before - 0.5 and rows_before > 0.0, "%s / %s" % [play._slot.size.y, rows_before])
	await create_timer(0.8).timeout
	check("explication : la carte cède au plus %d px à l'explication" % int(PlayScreen.EXPLAIN_MAX_EXTRA),
			play._card.size.y <= card_before.y + 0.5 and play._card.size.y >= card_before.y - PlayScreen.EXPLAIN_MAX_EXTRA - 0.5,
			"%s -> %s" % [card_before, play._card.size])
	check("explication : l'image garde au moins %d px" % int(PlayScreen.EXPLAIN_MIN_IMAGE_HEIGHT),
			play._zone.size.y >= minf(zone_before, PlayScreen.EXPLAIN_MIN_IMAGE_HEIGHT) - 1.0, "%s -> %s" % [zone_before, play._zone.size.y])
	check("explication : la zone d'explication gagne au moins ce que la carte cède",
			play._slot.size.y - rows_before >= card_before.y - play._card.size.y - 0.5, "%s / %s" % [play._slot.size.y - rows_before, card_before.y - play._card.size.y])
	check("explication : le bouton Continuer ne bouge pas", absf(play._next.position.y - next_y_before) < 1.0, "%s -> %s" % [next_y_before, play._next.position.y])
	var texts: Array = []
	for n in play._explain_box.get_children():
		if n is Label:
			texts.append(n.text)
	check("explication : réponse, explication et anecdote affichées",
			correct in texts and qs[0]["explication"] in texts and qs[0]["anecdote"] in texts, str(texts.size()))
	check("explication : crédit de la photo affiché", texts.any(func(t): return t.begins_with("Image :")))
	check("bonne réponse : feedback avec 2 indices", play._feedback.text == "Exact, avec 2 indices.")
	check("après réponse : les 2 indices sont lisibles", play._clues.unlocked_count() == 2)
	check("après réponse : couche révélée", cover.is_revealed())
	check("après réponse : boutons désactivés", _enabled(play) == 0)
	check("bouton suivant actif", not play._next.disabled)

	# question suivante
	play._next.pressed.emit()
	await _frames(6)
	check("question 2 : l'image retrouve une taille normale, les 4 réponses reviennent",
			play._zone.size.y >= PlayScreen.ZONE_MIN - 0.5 and play._zone.size.y <= PlayScreen.ZONE_MAX + 0.5
			and play._options.all(func(o): return o.visible) and not play._slot.visible, "%s" % play._zone.size)
	check("question 2 : le bouton Continuer reste à la même place", absf(play._next.position.y - next_y_before) < 1.0, "%s -> %s" % [next_y_before, play._next.position.y])
	check("question 2 : fraction remise à 0", cover.scratch_fraction == 0.0)
	check("question 2 : couche non révélée", not cover.is_revealed())
	check("question 2 : 0 indice", play._clues.unlocked_count() == 0)
	check("question 2 : réponses ouvertes dès le départ", _enabled(play) == 4)
	check("question 2 : bouton suivant inactif", play._next.disabled)

	# mauvaise réponse sans avoir rien gratté
	var wrong: Button = null
	for b in play._options:
		if b.text != play._correct_text:
			wrong = b
			break
	wrong.pressed.emit()
	await _frames(3)
	print("feedback: ", play._feedback.text)
	check("mauvaise réponse : feedback", play._feedback.text == "Pas tout à fait.")
	check("mauvaise réponse : 0 point", play._points.text == "0", play._points.text)
	var shown: Array = []
	for n in play._explain_box.get_children():
		if n is Label:
			shown.append(n.text)
	check("mauvaise réponse : « Votre choix » rappelé", shown.any(func(t): return t.begins_with("Votre choix : ") and t.ends_with(wrong.text)), str(shown))
	check("question 2 : la bonne réponse est indiquée", play._correct_text in shown)

	# dernière question, puis sortie
	play._next.pressed.emit()
	await _frames(6)
	var done := [false]
	var final_results: Array = []
	play.finished.connect(func(r: Array) -> void:
		done[0] = true
		final_results.append_array(r))
	var correct3: String = play._correct_text
	check("question 3 : rien n'est gratté", play._zone.cover.scratch_fraction == 0.0)
	for b in play._options:
		if b.text == correct3:
			b.pressed.emit()
	await _frames(2)
	check("dernière question : bouton « Voir le résultat »", play._next.text == "Voir le résultat", play._next.text)
	check("dernière question juste sans rien gratter : +100", play._points.text == "+100", play._points.text)
	check("dernière question : « Exact, sans aucun indice. »", play._feedback.text == "Exact, sans aucun indice.", play._feedback.text)
	play._next.pressed.emit()
	check("signal finished émis", done[0])
	check("finished : 3 résultats", final_results.size() == 3, str(final_results.size()))
	check("finished : points 30 + 0 + 100 = 130", Scoring.total(final_results) == 130, str(Scoring.total(final_results)))
	check("finished : 2 bonnes réponses", Scoring.correct_count(final_results) == 2)

	# dossier seul : le bouton propose de terminer
	play.start(pack, [pack.questions[3]])
	await _frames(6)
	for b in play._options:
		if b.text == play._correct_text:
			b.pressed.emit()
	await _frames(2)
	check("dossier seul : bouton « Terminer »", play._next.text == "Terminer", play._next.text)

	print("--- ", "TOUT EST OK" if fails == 0 else "%d ÉCHEC(S)" % fails)
	quit(1 if fails > 0 else 0)
