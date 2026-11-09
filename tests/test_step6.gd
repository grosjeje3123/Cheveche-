extends SceneTree
## Étape 6 : points, sauvegarde, écran de résultat, progression sur l'accueil et la couverture.

var fails := 0
const SAVE := "user://test_step6_progress.json"

func check(label: String, ok: bool, extra := "") -> void:
	print(("OK   " if ok else "FAIL ") + label + ("  " + extra if extra != "" else ""))
	if not ok:
		fails += 1

func _frames(n: int) -> void:
	for i in n:
		await process_frame

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

func _answer(play: PlayScreen, want_correct: bool, target: float) -> void:
	if target > 0.0:
		await _scratch_to(play._zone.cover, target)
	for b in play._options:
		if (b.text == play._correct_text) == want_correct:
			b.pressed.emit()
			break
	await _frames(3)

func _initialize() -> void:
	# ---------- Points ----------
	check("points : 0 indice = 100", Scoring.points_for(true, 0) == 100)
	check("points : 1 indice = 60", Scoring.points_for(true, 1) == 60)
	check("points : 2 indices = 30", Scoring.points_for(true, 2) == 30)
	check("points : un 3e indice n'existe plus (ramené à 30)", Scoring.points_for(true, 3) == 30)
	check("points : mauvaise réponse = 0, quel que soit le nombre d'indices", Scoring.points_for(false, 0) == 0 and Scoring.points_for(false, 3) == 0)
	check("points : indices hors bornes ramenés dans 0..2", Scoring.points_for(true, 9) == 30 and Scoring.points_for(true, -2) == 100)
	var res := [{"points": 100, "correct": true}, {"points": 30, "correct": true}, {"points": 0, "correct": false}]
	check("total = 130", Scoring.total(res) == 130)
	check("2 bonnes réponses", Scoring.correct_count(res) == 2)
	check("maximum de 5 dossiers = 500", Scoring.max_total(5) == 500)
	check("verdict : tout juste", Scoring.verdict([{"points": 100}, {"points": 100}]) == "Excellent.")
	check("verdict : 60 %", Scoring.verdict([{"points": 75}, {"points": 50}]) == "Très bien.")
	check("verdict : 30 %", Scoring.verdict([{"points": 25}, {"points": 50}]) == "Honorable.", Scoring.verdict([{"points": 25}, {"points": 50}]))
	check("verdict : 0", Scoring.verdict([{"points": 0}, {"points": 0}]) == "On progresse, dossier après dossier.")
	check("verdict : liste vide", Scoring.verdict([]) == "")

	# ---------- Sauvegarde ----------
	DirAccess.remove_absolute(SAVE)
	var s := SaveStore.new(SAVE)
	check("sauvegarde neuve : rien de collecté", not s.is_collected("a") and s.best_series(5) == 0 and s.series_played() == 0)
	s.record_answer("a", true, 75)
	s.record_answer("a", true, 100)
	s.record_answer("a", false, 0)
	s.record_answer("b", false, 0)
	check("collecté après une bonne réponse", s.is_collected("a"))
	check("raté : pas collecté", not s.is_collected("b"))
	check("meilleur score du dossier conservé (100)", s.best_points("a") == 100, str(s.best_points("a")))
	check("3 parties comptées", s.plays("a") == 3 and s.plays("b") == 1)
	s.record_series(5, 300)
	s.record_series(5, 240)
	s.record_series(3, 90)
	check("meilleure série de 5 = 300", s.best_series(5) == 300)
	check("meilleure série de 3 gardée à part", s.best_series(3) == 90)
	check("2 séries (+1) comptées", s.series_played() == 3)
	check("fichier écrit", FileAccess.file_exists(SAVE))
	check("pas de fichier temporaire oublié", not FileAccess.file_exists(SAVE + ".tmp"))
	var again := SaveStore.new(SAVE)
	check("relecture identique", again.is_collected("a") and not again.is_collected("b") and again.best_points("a") == 100
			and again.plays("a") == 3 and again.best_series(5) == 300 and again.series_played() == 3)
	var pack := QuestionPack.load_file("res://data/packs/svt_01.json")
	check("collected_in ignore les identifiants hors pack", again.collected_in(pack.questions) == 0)
	again.record_answer(pack.questions[0]["id"], true, 50)
	check("collected_in compte les dossiers du pack", again.collected_in(pack.questions) == 1)

	# tirage : les dossiers pas encore trouvés passent en premier
	var drawn := again.draw(pack.questions, 5)
	check("tirage : 5 dossiers", drawn.size() == 5)
	check("tirage : le dossier déjà trouvé n'est pas dans les 5 (14 autres disponibles)", not drawn.any(func(q): return q["id"] == pack.questions[0]["id"]))
	# Trouvé avec un indice aujourd'hui : mis de côté jusqu'à demain.
	var few := again.draw(pack.questions.slice(0, 3), 5)
	check("tirage : trouvé avec un indice aujourd'hui, il ne revient pas tout de suite", few.size() == 2
			and not few.any(func(q): return q["id"] == pack.questions[0]["id"]), str(few.size()))
	var tomorrow := Week.key(Week.shifted(Week.today(), 1))
	var later := again.draw(pack.questions.slice(0, 3), 5, tomorrow)
	check("tirage : demain, il revient après les dossiers pas encore trouvés", later.size() == 3 and later[2]["id"] == pack.questions[0]["id"])
	again.record_answer(pack.questions[1]["id"], true, 100)
	var perfect := again.draw(pack.questions.slice(0, 3), 5)
	var in_week := Week.key(Week.shifted(Week.today(), 7))
	check("tirage : trouvé sans indice du premier coup, il est vérifié dans 7 jours (à consolider)", perfect.size() == 1
			and again.return_day(pack.questions[1]["id"]) == in_week)
	var reread := SaveStore.new(SAVE)
	check("la date de retour est gardée dans la sauvegarde", not reread.is_due(pack.questions[0]["id"]) and reread.is_due(pack.questions[0]["id"], tomorrow)
			and not reread.is_due(pack.questions[1]["id"]) and reread.is_due(pack.questions[1]["id"], in_week))
	var fresh := SaveStore.new("user://test_step6_empty.json")
	DirAccess.remove_absolute("user://test_step6_empty.json")
	fresh.load_from_disk()
	check("tirage sans progression : 5 dossiers distincts", _ids(fresh.draw(pack.questions, 5)).size() == 5)

	# sauvegarde abîmée : on repart de zéro, sans planter, l'ancien fichier est mis de côté
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string("{ ceci n'est pas du json")
	f.close()
	var broken := SaveStore.new(SAVE)
	check("fichier abîmé : on repart de zéro", broken.collected_in(pack.questions) == 0 and broken.series_played() == 0)
	check("fichier abîmé : mis de côté en .bad", FileAccess.file_exists(SAVE + ".bad"))
	var odd := FileAccess.open(SAVE, FileAccess.WRITE)
	odd.store_string('{"dossiers": {"x": {"best": "beaucoup", "plays": -4, "wins": 1}, "y": 7}, "best_series": [], "series_played": "a"}')
	odd.close()
	var weird := SaveStore.new(SAVE)
	check("valeurs bizarres : assainies, sans plantage", weird.is_collected("x") and weird.best_points("x") == 0 and weird.plays("x") == 0
			and not weird.is_collected("y") and weird.best_series(5) == 0 and weird.series_played() == 0)
	var unwritable := SaveStore.new("user://dossier_inexistant/progress.json")
	check("écriture impossible : renvoie faux sans planter", not unwritable.save())

	# ---------- Crédit d'image ----------
	var q: Dictionary = pack.questions[4].duplicate(true)
	q["image"] = {"statut": "a_trouver", "recherche": "test"}  # un dossier encore sans image
	check("crédit : vide sans photo vérifiée", pack.credit_line(q) == "")
	q["image"] = {"statut": "verifie", "recherche": "", "fichier": "_test_photo.png", "auteur": "Camille Test",
		"licence": "CC BY-SA 4.0", "url_page": "u", "url_fichier": "u", "modifications": "Aucune"}
	check("crédit : photo vérifiée présente", pack.has_verified_image(q))
	check("crédit : auteur et licence", pack.credit_line(q) == "Image : Camille Test, CC BY-SA 4.0.", pack.credit_line(q))
	q["image"]["modifications"] = "Redimensionnée à 1600 px de large"
	check("crédit : court, sans les modifications (elles sont sur la page Crédits)", pack.credit_line(q) == "Image : Camille Test, CC BY-SA 4.0.", pack.credit_line(q))
	check("modifications en bref : recadrée et réduite", QuestionPack.changes_short("Redimensionnée à 1280 px (Commons) ; puis recadrée sur la bande que le jeu peut montrer et réduite à 1024 px") == "Recadrée et réduite")
	check("modifications en bref : réduite, recadrée, aucune", QuestionPack.changes_short("Redimensionnée à 1600 px de large") == "Réduite"
			and QuestionPack.changes_short("Recadrée sur la bande que le jeu peut montrer") == "Recadrée" and QuestionPack.changes_short("Aucune") == "")
	q["image"]["licence"] = "CC BY-NC 4.0"
	check("crédit : licence refusée = pas de crédit (et pas d'image)", pack.credit_line(q) == "" and not pack.has_verified_image(q))

	# ---------- Le crédit apparaît dans l'explication, et dans les crédits du résultat ----------
	root.size = Vector2i(720, 1280)
	var pq: Dictionary = pack.by_id("svt01-q07")
	var saved_image = pq["image"]
	pq["image"] = {"statut": "verifie", "recherche": "", "fichier": "_test_photo.png", "auteur": "Camille Test",
		"licence": "CC BY-SA 4.0", "url_page": "u", "url_fichier": "u", "modifications": "Aucune"}
	var play0 := PlayScreen.new()
	play0.theme = Ds.build_theme()
	play0.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(play0)
	play0.build()
	await _frames(3)
	play0.start(pack, [pq])
	await _frames(6)
	check("photo de test affichée", play0._zone.shows_photo())
	await _answer(play0, true, 0.11)
	var texts0: Array = []
	for n in play0._explain_box.get_children():
		if n is Label:
			texts0.append(n.text)
	check("explication : crédit de la photo affiché", texts0.has("Image : Camille Test, CC BY-SA 4.0."), str(texts0))
	var res0 := ResultScreen.new()
	res0.theme = Ds.build_theme()
	res0.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(res0)
	res0.show_results(pack, [{"id": pq["id"], "correct": true, "clues": 0, "points": 100},
			{"id": pack.questions[0]["id"], "correct": false, "clues": 1, "points": 0}], {"label": "Test", "back_text": "Retour"})
	await _frames(3)
	var rl: Array = []
	_collect_labels(res0, rl)
	check("résultat : un seul lien « Crédits des images », pas de liste de crédits", "Crédits des images" in _button_texts(res0)
			and not rl.any(func(t): return ". Image : " in t or t.begins_with("Image :")), str(rl))
	play0.queue_free()
	res0.queue_free()
	pq["image"] = saved_image

	# ---------- Parcours complet ----------
	DirAccess.remove_absolute(SAVE)
	DirAccess.remove_absolute(SAVE + ".bad")
	root.size = Vector2i(720, 1280)
	var main: Control = load("res://main.tscn").instantiate()
	main.save_path = SAVE
	root.add_child(main)
	if not main.is_node_ready():
		await main.ready
	main._settings.rules_seen = true  # « Comment jouer » déjà vue : on entre directement dans le jeu
	await _frames(8)
	await create_timer(0.8).timeout
	check("couverture : consigne de premier lancement", main._cover._info.visible and main._cover._info.text == "Touchez une fiche et jouez autant que vous voulez.", main._cover._info.text)
	check("couverture : pas de compteur global, une barre vide par fiche de discipline", main._cover._bars.size() == 8
			and main._cover._bars.values().all(func(b): return b.fills[0] == 0.0))
	check("résultats : 0 dossier trouvé", main._progress._cabinet_count.text == "0" and main._progress._cabinet_unit.text == "dossier trouvé", main._progress._cabinet_unit.text)
	check("résultats : Nature « 30 dossiers »", (main._progress._category_meta["Nature"] as Label).text == "30 dossiers")
	check("résultats : pas encore de meilleur défi", not main._progress._cabinet_best.visible)

	# « Au hasard » : jeu continu sur les 240 dossiers, pas de fin de série
	main._cover.play_pressed.emit()
	await create_timer(0.7).timeout
	var play: PlayScreen = main._play
	var result: ResultScreen = main._result
	check("« Au hasard » : jeu continu, 240 dossiers à la file", play._continuous and play._questions.size() == 240 and play._index == 0)
	var lv: Array = play._questions.map(func(x): return main._pack.difficulty_level(x))
	var sorted_lv := lv.duplicate()
	sorted_lv.sort()
	check("« Au hasard » : on commence par les plus accessibles, les plus difficiles à la fin", lv == sorted_lv and lv[0] == 1 and lv[239] == 4)
	check("carte : le repère de niveau suit le dossier", play._card._level.visible and play._card._level.level == lv[0])
	check("en haut : « 0 / 240 trouvés » et une barre vide", play._counter.text == "0 / 240 trouvés" and play._segments.fills.size() == 1
			and play._segments.fills[0] == 0.0, play._counter.text)
	# 5 dossiers : juste sans rien gratter (100), juste à 25 % (60), juste à 50 % (30), faux, juste à 80 % (30)
	var plan := [[true, 0.0], [true, 0.28], [true, 0.55], [false, 0.12], [true, 0.80]]
	var expected := [100, 60, 30, 0, 30]
	for i in 5:
		await _answer(play, plan[i][0], plan[i][1])
		check("dossier %d : %s" % [i + 1, "+%d" % expected[i] if expected[i] > 0 else "0"], play._points.text == ("+%d" % expected[i] if expected[i] > 0 else "0"), play._points.text)
		if i == 0:
			await create_timer(0.4).timeout
			check("répondu sans gratter : « Grattez pour découvrir l’image » s'efface sur l'image dévoilée", play._hint.modulate.a < 0.05, str(play._hint.modulate.a))
			check("après la 1re réponse : sauvegarde écrite", FileAccess.file_exists(SAVE))
			var first_q: Dictionary = play._questions[0]
			var first_d: String = main._pack.collection_of(first_q)
			check("après la 1re réponse : la consigne disparaît", not main._cover._info.visible)
			check("après la 1re réponse : la barre de la discipline avance", (main._cover._bars[first_d] as DsSegments).fills[0] > 0.0, first_d)
			check("après la 1re réponse : cabinet à jour", main._progress._cabinet_count.text == "1")
			check("après une bonne réponse : « 1 / 240 trouvés »", play._counter.text == "1 / 240 trouvés", play._counter.text)
			check("bouton « Dossier suivant »", play._next.text == "Dossier suivant", play._next.text)
		if i == 3:
			check("après une mauvaise réponse : le compte ne bouge pas", play._counter.text == "3 / 240 trouvés", play._counter.text)
		play._next.pressed.emit()
		await _frames(6)
	check("après 5 dossiers : pas de fin de série, le 6e dossier arrive", main._current == play and play._index == 5 and not result.visible)
	check("en haut : « 4 / 240 trouvés », barre remplie d'autant", play._counter.text == "4 / 240 trouvés"
			and is_equal_approx(play._segments.fills[0], 4.0 / 240.0), play._counter.text)
	play.closed.emit()
	await create_timer(0.8).timeout
	check("flèche retour : couverture, sans page de résultat", main._cover.visible and main._current == main._cover and not result.visible)
	check("progression : 4 dossiers trouvés", main._progress._cabinet_count.text == "4", main._progress._cabinet_count.text)
	check("progression : pluriel", main._progress._cabinet_unit.text == "dossiers trouvés")
	var bars_ok := true
	for d in main._cover._bars:
		var all: Array = main._pack.questions_in(d)
		if not is_equal_approx((main._cover._bars[d] as DsSegments).fills[0], float(main._save.collected_in(all)) / float(all.size())):
			bars_ok = false
	check("couverture : chaque barre suit la part de dossiers trouvés de sa discipline", bars_ok)
	check("fiche : aucun record de série, pas de meilleur défi", main._save.series_played() == 0 and not main._progress._cabinet_best.visible)
	check("progression écrite sur disque", SaveStore.new(SAVE).collected_in(main._pack.questions) == 4)

	# Bilan de la semaine (« Mes résultats ») : 220 points, 5 réponses dont 4 trouvées, aujourd'hui
	var home: ProgressScreen = main._progress
	var today := Week.today()
	check("semaine : intitulé", home._week_range.text == Week.range_label(today), home._week_range.text)
	check("semaine : 220 points", home._week_points.text == "220", home._week_points.text)
	check("semaine : 4 trouvés sur 5", home._week_found.text == "4" and home._week_found_caption.text == "trouvés sur 5", home._week_found.text + " / " + home._week_found_caption.text)
	check("semaine : 1 jour joué", home._week_days.text == "1", home._week_days.text)
	check("semaine : meilleure journée = aujourd'hui, 220 points", home._week_best.text == "Meilleure journée : %s, 220 points." % Week.DAY_NAMES[Week.weekday_index(today)], home._week_best.text)
	check("semaine : pas de semaine dernière à comparer", not home._week_last.visible)
	check("semaine : la colonne du jour porte 220 points", home._week_bars.points[Week.weekday_index(today)] == 220 and home._week_bars.today_index == Week.weekday_index(today), str(home._week_bars.points))

	# On reprend « Au hasard » le jour même : les 235 pas encore trouvés, puis le seul trouvé sans indice (révision) ;
	# les 4 ratés ou trouvés avec un indice attendent demain.
	main._cover.play_pressed.emit()
	await create_timer(0.7).timeout
	var known_first := 0
	for k in 235:
		if main._save.is_collected(play._questions[k]["id"]):
			known_first += 1
	check("reprise : 235 dossiers pas encore trouvés ; les 5 joués reviendront à leur date", play._questions.size() == 235
			and known_first == 0 and play.revision_from == -1 and play.waiting == 5 and play.return_words == "à partir de demain",
			"%d dossiers, révision à %d, %d en attente, %s" % [play._questions.size(), play.revision_from, play.waiting, play.return_words])
	check("reprise : « 4 / 240 trouvés », résultats remis à zéro", play._counter.text == "4 / 240 trouvés" and play._results.is_empty() and play._index == 0)
	check("reprise : pas de mot de révision sur le premier dossier", play._feedback.text == "Répondez, ou grattez pour un indice.", play._feedback.text)
	for k in 234:  # on saute les 234 premiers : comme s'ils avaient été joués (la file s'adapte sans eux)
		main._session_played[play._questions[k]["id"]] = true
	play._index = 233
	play._next.pressed.emit()  # le dernier dossier de la file
	await _frames(6)
	await _answer(play, false, 0.0)
	var notes: Array = []
	for n in play._explain_box.get_children():
		if n is Label:
			notes.append(n.text)
	check("bout de la file : « La suite à partir de demain : 6 dossiers à revoir. »", notes.back() == "La suite à partir de demain : 6 dossiers à revoir." and play._next.text == "Retour à la couverture", str(notes.back()))
	play.closed.emit()
	await create_timer(0.7).timeout

	# Une fiche de discipline jusqu'au bout de la file : retour à la couverture
	main._cover.open_category.emit("Sciences")
	await create_timer(0.7).timeout
	var sciences_found: int = main._save.collected_in(main._pack.questions_in("Sciences"))
	var sciences_waiting: int = main._save.waiting_in(main._pack.questions_in("Sciences"))
	var n_queue := play._questions.size()
	check("fiche Sciences : ses dossiers du jour (30 moins ceux à revoir demain), « n / 30 trouvés »", n_queue == 30 - sciences_waiting
			and play._questions.all(func(x): return main._pack.collection_of(x) == "Sciences")
			and play._counter.text == "%d / 30 trouvés" % sciences_found, play._counter.text)
	for k in n_queue - 1:  # comme si les autres avaient été joués
		main._session_played[play._questions[k]["id"]] = true
	play._index = n_queue - 2
	play._next.pressed.emit()  # on saute au dernier dossier de la file
	await _frames(6)
	await _answer(play, true, 0.0)
	check("dernier dossier de la fiche : « Retour à la couverture »", play._next.text == "Retour à la couverture", play._next.text)
	play._next.pressed.emit()
	await create_timer(0.8).timeout
	check("bout de la file : couverture, sans page de résultat", main._cover.visible and main._current == main._cover and not result.visible)
	check("résultats : progression de Sciences mise à jour, le dernier dossier compte", (main._progress._category_meta["Sciences"] as Label).text == Ds.discipline_count(main._save.collected_in(main._pack.questions_in("Sciences")), 30)
			and main._save.is_collected(play._questions[n_queue - 1]["id"]), (main._progress._category_meta["Sciences"] as Label).text)

	# Le défi du jour : série numérotée, puis la page de résultat
	main._cover.daily_pressed.emit()
	await create_timer(0.7).timeout
	check("défi : « 1 sur 5 », barre en étapes", not play._continuous and play._counter.text == "1 sur 5" and play._segments.fills.is_empty()
			and play._segments.total == 5, play._counter.text)
	for i in 5:
		await _answer(play, plan[i][0], plan[i][1])
		if i < 4:
			if i == 0:
				check("défi : bouton « Continuer »", play._next.text == "Continuer", play._next.text)
			play._next.pressed.emit()
			await _frames(6)
	check("défi, dernier dossier : « Voir le résultat »", play._next.text == "Voir le résultat")
	play._next.pressed.emit()
	await create_timer(0.8).timeout
	check("résultat du défi visible, jeu caché", result.visible and not play.visible and main._current == result)
	var labels: Array = []
	_collect_labels(result, labels)
	print(labels)
	check("résultat : « Défi du jour » et la date", "Défi du jour" in labels and Daily.date_label(today) in labels, str(labels.slice(0, 4)))
	check("résultat : score 220", "220" in labels)
	check("résultat : « / 500 »", "/ 500" in labels)
	check("résultat : verdict « Honorable. » (44 %)", "Honorable." in labels, str(labels))
	check("résultat : 4 bonnes réponses sur 5", "4 bonnes réponses sur 5" in labels)
	check("résultat : jours de suite", "1 jour de suite. Prochain défi demain." in labels)
	check("résultat : points par dossier", "+100" in labels and "+60" in labels and "+30" in labels and "0" in labels)
	check("résultat : « manqué » pour le dossier raté", labels.any(func(t): return t.ends_with(", manqué")))
	check("résultat : lien vers les crédits, sans liste", "Crédits des images" in _button_texts(result)
			and not labels.any(func(t): return ". Image : " in t), str(labels))
	check("résultat : un seul bouton, retour à la couverture (plus de « Rejouer »)", "Retour à la couverture" in _button_texts(result)
			and not "Rejouer" in _button_texts(result), str(_button_texts(result)))
	check("résultat : le petit hibou est dans le coin", _has_owl(result))
	check("résultat : tampon dateur « Défi du jour », jour, mois, année ; pas plein (défi non parfait)", result.stamp != null
			and result.stamp.top_text == "Défi du jour" and result.stamp.center_text == str(int(today["day"]))
			and result.stamp.center_caption == Week.MONTHS_SHORT[int(today["month"]) - 1] and result.stamp.bottom_text == str(int(today["year"]))
			and not result.stamp.filled, "%s %s %s" % [result.stamp.center_text, result.stamp.center_caption, result.stamp.bottom_text] if result.stamp else "aucun")
	await create_timer(0.4).timeout
	check("résultat : le « tchok » du tampon, puis le jingle", main._feedback.history.slice(-2) == ["stamp", "series_good"], str(main._feedback.history.slice(-3)))
	check("meilleur défi enregistré : 220", main._save.best_daily() == 220, str(main._save.best_daily()))
	check("meilleur défi dans « Mes résultats »", main._progress._cabinet_best.visible and main._progress._cabinet_best.text == "Meilleur défi du jour : 220 / 500", main._progress._cabinet_best.text)
	var ev := InputEventAction.new()
	ev.action = "ui_cancel"
	ev.pressed = true
	main._unhandled_input(ev)
	await create_timer(0.7).timeout
	check("Échap sur le résultat : retour à la couverture", main._cover.visible and not result.visible)
	check("couverture : toujours pas de consigne après avoir joué", not main._cover._info.visible)

	# Résultats : la définition d'un dossier trouvé, les barres
	main._cover.open_results.emit()
	await create_timer(0.6).timeout
	check("résultats : Nature indique la progression « n / 30 trouvés »",
			(main._progress._category_meta["Nature"] as Label).text == Ds.discipline_count(main._save.collected_in(main._pack.questions_in("Nature")), 30), (main._progress._category_meta["Nature"] as Label).text)
	check("résultats : la définition d'un dossier trouvé est affichée", main._progress._cabinet_detail.text.begins_with("Un dossier est trouvé dès que vous y répondez juste")
			and "Quand vous jouez une fiche" in main._progress._cabinet_detail.text, main._progress._cabinet_detail.text)
	check("résultats : une seule barre, remplie à la part de dossiers trouvés", main._progress._cabinet_bar.fills.size() == 1 and is_equal_approx(main._progress._cabinet_bar.fills[0], float(main._save.collected_in(main._pack.questions)) / 240.0), str(main._progress._cabinet_bar.fills))
	check("résultats : un bilan seul, sans bouton de jeu par discipline", not main._progress.has_signal("open_category"))
	check("résultats : la barre de Nature suit sa progression", is_equal_approx((main._progress._category_bar["Nature"] as DsSegments).fills[0],
			float(main._save.collected_in(main._pack.questions_in("Nature"))) / 30.0))
	main._progress.closed.emit()
	await create_timer(0.6).timeout

	DirAccess.remove_absolute(SAVE)
	print("--- ", "TOUT EST OK" if fails == 0 else "%d ÉCHEC(S)" % fails)
	quit(1 if fails > 0 else 0)


func _ids(list: Array) -> Dictionary:
	var d := {}
	for q in list:
		d[q["id"]] = true
	return d

func _collect_labels(n: Node, out: Array) -> void:
	if n is Label:
		out.append((n as Label).text)
	for c in n.get_children():
		_collect_labels(c, out)

func _has_owl(n: Node) -> bool:
	if n is OwlMark:
		return true
	for c in n.get_children():
		if _has_owl(c):
			return true
	return false

func _button_texts(n: Node) -> Array:
	var out: Array = []
	if n is Button:
		out.append((n as Button).text)
	for c in n.get_children():
		out.append_array(_button_texts(c))
	return out
