extends SceneTree

var fails := 0
func check(label: String, ok: bool, extra := "") -> void:
	print(("OK   " if ok else "FAIL ") + label + ("  " + extra if extra != "" else ""))
	if not ok:
		fails += 1

func _esc(main: Control) -> void:
	var ev := InputEventAction.new()
	ev.action = "ui_cancel"
	ev.pressed = true
	main._unhandled_input(ev)

func _initialize() -> void:
	var main: Control = load("res://main.tscn").instantiate()
	main.save_path = "user://test_nav_progress.json"
	DirAccess.remove_absolute(main.save_path)
	root.add_child(main)
	for i in 8:
		await process_frame
	await create_timer(0.8).timeout
	check("démarrage : couverture visible", main._cover.visible and main._current == main._cover)
	check("démarrage : résultats et jeu cachés", not main._progress.visible and not main._play.visible)

	main._cover.open_results.emit()
	await create_timer(0.7).timeout
	check("« Mes résultats » : écran des résultats visible, couverture cachée", main._progress.visible and not main._cover.visible)

	_esc(main)
	await create_timer(0.7).timeout
	check("Échap depuis les résultats : retour à la couverture", main._cover.visible and not main._progress.visible)

	main._cover.play_pressed.emit()
	await create_timer(0.7).timeout
	check("« Jouer » : écran de jeu visible", main._play.visible and not main._cover.visible)
	check("« Au hasard » : jeu continu, tous les dossiers à la file", main._play._continuous and main._play._questions.size() == 240, str(main._play._questions.size()))
	var ids := {}
	var first_cols := {}
	for i in main._play._questions.size():
		var q: Dictionary = main._play._questions[i]
		ids[q["id"]] = true
		if i < 12:
			first_cols[main._pack.collection_of(q)] = true
	check("« Au hasard » : 240 dossiers différents", ids.size() == 240)
	check("« Au hasard » : les disciplines se mêlent dès les premiers dossiers", first_cols.size() >= 4, str(first_cols.keys()))
	check("« Au hasard » : en haut, « 0 / 240 trouvés »", main._play._counter.text == "0 / 240 trouvés", main._play._counter.text)
	check("240 dossiers chargés depuis les quinze packs", main._pack.questions.size() == 240 and main._pack.ignored == 0, str(main._pack.questions.size()))
	check("30 dossiers dans chacune des 8 disciplines", ProgressScreen.DISCIPLINES.all(func(d): return main._pack.questions_in(d).size() == 30))
	var a1: Dictionary = main._pack.by_id("astro01-q01")
	check("numéros de dossier : astro01-q01 = 101, animaux01-q15 = 215, svt01-q07 = 7", main._pack.dossier_number(a1) == 101
			and main._pack.dossier_number(main._pack.by_id("animaux01-q15")) == 215 and main._pack.dossier_number(main._pack.by_id("svt01-q07")) == 7)
	check("images : chaque dossier cherche ses images dans le dossier de son pack", main._pack.image_path(a1).begins_with("res://assets/images/astro_01/"), main._pack.image_path(a1))
	var nums := {}
	for q in main._pack.questions:
		nums[main._pack.dossier_number(q)] = true
	check("numéros de dossier tous différents", nums.size() == 240)
	check("numéros 501, 615, 16 (Nature), 60 (Sciences), 630", main._pack.dossier_number(main._pack.by_id("nature01-q01")) == 16 and main._pack.dossier_number(main._pack.by_id("sciences01-q25")) == 60 and main._pack.dossier_number(main._pack.by_id("litterature02-q15")) == 630 and main._pack.dossier_number(main._pack.by_id("geographie01-q01")) == 501 and main._pack.dossier_number(main._pack.by_id("litterature01-q15")) == 615)
	check("numéros 301 et 415",  main._pack.dossier_number(main._pack.by_id("histoire01-q01")) == 301 and main._pack.dossier_number(main._pack.by_id("arts01-q15")) == 415)

	_esc(main)
	await create_timer(0.7).timeout
	check("Échap depuis « Jouer » : retour à la couverture", main._cover.visible and not main._play.visible)
	var drawers: GridContainer = null
	for c in main._cover.find_children("*", "GridContainer", true, false):
		drawers = c
	check("couverture : 9 tiroirs (« Au hasard » + 8 disciplines), plus de bouton « Jouer » à part",
			drawers != null and drawers.get_child_count() == 9 and not main._cover.has_signal("choose_discipline"),
			str(drawers.get_child_count() if drawers else -1))
	var first_texts: Array = []
	for l in drawers.get_child(0).find_children("*", "Label", true, false):
		first_texts.append(l.text)
	check("couverture : le premier tiroir est « Au hasard »", "Au hasard" in first_texts, str(first_texts))
	(drawers.get_child(0) as Button).pressed.emit()
	await create_timer(0.7).timeout
	check("tiroir « Au hasard » : jeu continu sur tout le pack", main._play.visible and main._play._questions.size() == 240 and main._series_category == "")
	main._play.closed.emit()
	await create_timer(0.7).timeout
	(drawers.get_child(3) as Button).pressed.emit()   # 3e discipline : Sciences
	await create_timer(0.7).timeout
	check("tiroir Sciences : jeu visible, les 30 dossiers de Sciences", main._play.visible and main._play._questions.size() == 30
			and main._play._questions.all(func(q): return main._pack.collection_of(q) == "Sciences"), main._series_category)
	main._play.closed.emit()
	await create_timer(0.7).timeout
	check("flèche retour depuis le jeu : retour à la couverture", main._cover.visible and not main._play.visible)
	main._cover.open_results.emit()
	await create_timer(0.7).timeout
	main._progress.closed.emit()
	await create_timer(0.7).timeout
	check("flèche retour sur les résultats : couverture", main._cover.visible and not main._progress.visible)

	main._cover.open_category.emit("Nature")
	await create_timer(0.7).timeout
	check("discipline Nature : les 30 dossiers de Nature", main._play.visible and main._play._questions.size() == 30
			and main._play._questions.all(func(q): return main._pack.collection_of(q) == "Nature"), str(main._play._questions.size()))
	main._play.finished.emit([])
	await create_timer(0.7).timeout
	check("fiche : bout de la file, retour à la couverture sans page de résultat", main._cover.visible and not main._result.visible)

	# Ordre d'une fiche : le seul dossier d'Arts pas encore trouvé passe en tête, les autres suivent.
	var store := SaveStore.new("user://test_nav_mix.json")
	for q in main._pack.questions:
		if main._pack.collection_of(q) == "Arts" and q["id"] != "arts01-q03":
			store.record_answer(q["id"], true, 100)
	var always_first := true
	for i in 20:
		var order := store.draw(main._pack.questions_in("Arts"), 30)
		if order.size() != 30 or order[0]["id"] != "arts01-q03":
			always_first = false
	check("ordre d'une fiche : le dossier pas encore trouvé d'abord, puis les 29 autres", always_first)
	var rising := true
	for i in 20:
		var order := store.draw(main._pack.questions_in("Arts"), 30).slice(1)
		for k in range(1, order.size()):
			if main._pack.difficulty_level(order[k]) < main._pack.difficulty_level(order[k - 1]):
				rising = false
	check("ordre d'une fiche : la difficulté monte dans chaque paquet (faciles, moyens, difficiles)", rising)
	var mixed_inside := {}
	for i in 30:
		mixed_inside[store.draw(main._pack.questions_in("Arts"), 30)[1]["id"]] = true
	check("ordre d'une fiche : mélangé à l'intérieur d'un même niveau", mixed_inside.size() > 3, str(mixed_inside.size()))
	var counts := {}
	for d in ProgressScreen.DISCIPLINES:
		var c := [0, 0, 0]
		for q in main._pack.questions_in(d):
			c[main._pack.difficulty_level(q) - 1] += 1
		counts[d] = c
	check("niveaux : dans chaque discipline, au moins 9 faciles, 12 moyens et 6 difficiles", counts.values().all(func(c): return c[0] >= 9 and c[1] >= 12 and c[2] >= 6), str(counts))
	DirAccess.remove_absolute("user://test_nav_mix.json")

	check("jour de l'année : 3 novembre 2026 = 307", Daily.day_of_year({"year": 2026, "month": 11, "day": 3}) == 307)
	check("jour de l'année : 29 février 2028 = 60", Daily.day_of_year({"year": 2028, "month": 2, "day": 29}) == 60)
	check("jour de l'année : 31 décembre 2024 = 366", Daily.day_of_year({"year": 2024, "month": 12, "day": 31}) == 366)
	print("--- ", "TOUT EST OK" if fails == 0 else "%d ÉCHEC(S)" % fails)
	quit(1 if fails > 0 else 0)
