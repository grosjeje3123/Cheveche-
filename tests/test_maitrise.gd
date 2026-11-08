extends SceneTree
## Difficulté de 1 à 5 et niveau par discipline (Mastery) : le calcul, la première réponse gardée par la sauvegarde,
## l'ordre des fiches qui s'adapte, les mots du niveau dans le jeu et dans « Mes résultats ».

const SAVE := "user://test_maitrise.json"
const SETTINGS := "user://test_maitrise_settings.json"
var fails := 0

func check(label: String, ok: bool, extra := "") -> void:
	print(("OK   " if ok else "FAIL ") + label + ("  " + extra if extra != "" else ""))
	if not ok:
		fails += 1


func _obs(levels: Array, result: float) -> Array:
	return levels.map(func(d): return [d, result])


func _initialize() -> void:
	for p in [SAVE, SETTINGS, "user://test_maitrise_store.json"]:
		DirAccess.remove_absolute(p)

	# --- Le calcul seul
	check("sans réponse : le point de départ, Curieux", absf(Mastery.estimate([]) - Mastery.PRIOR) < 0.01 and Mastery.name_of(Mastery.estimate([])) == "Curieux")
	var all_wrong := Mastery.estimate(_obs([1, 1, 2, 2, 1, 2, 1, 2], 0.0))
	check("tout manqué sur des dossiers faciles : Découverte", Mastery.name_of(all_wrong) == "Découverte", str(all_wrong))
	var easy_perfect := Mastery.estimate(_obs([1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 1, 2, 3, 2, 1, 2, 3, 3, 2, 1], 1.0))
	check("vingt dossiers faciles ou moyens sans faute, aucun difficile : pas plus qu'Érudit", Mastery.rank_of(easy_perfect) == 2, str(easy_perfect))
	var strong := Mastery.estimate(_obs([1, 2, 2, 3, 3, 3, 4, 4, 3, 2], 1.0))
	check("deux dossiers de difficulté 4 réussis en plus : Expert", Mastery.name_of(strong) == "Expert", str(strong))
	var top := Mastery.estimate(_obs([2, 3, 3, 4, 4, 4, 5, 5, 4, 5, 3, 4], 1.0))
	check("et deux de difficulté 5 : Grand Hibou", Mastery.name_of(top) == "Grand Hibou", str(top))
	var helped := Mastery.estimate(_obs([2, 2, 3, 3, 2, 3], 0.3))
	var clean := Mastery.estimate(_obs([2, 2, 3, 3, 2, 3], 1.0))
	check("trouvé avec deux indices compte moins que trouvé sans indice", helped < clean, "%.2f < %.2f" % [helped, clean])
	var hard_win := Mastery.estimate(_obs([2, 2, 2], 0.6) + [[4, 1.0]])
	var easy_win := Mastery.estimate(_obs([2, 2, 2], 0.6) + [[1, 1.0]])
	check("réussir un dossier difficile fait monter plus qu'un facile", hard_win > easy_win, "%.2f > %.2f" % [hard_win, easy_win])
	var easy_miss := Mastery.estimate(_obs([2, 2, 2], 0.6) + [[1, 0.0]])
	check("manquer un dossier facile fait un peu baisser", easy_miss < Mastery.estimate(_obs([2, 2, 2], 0.6)))
	check("départ : le plus accessible tant qu'on n'a rien joué", Mastery.start_level({"r": 4.0, "n": 0}) == 1)
	check("départ : un joueur fort commence haut", Mastery.start_level({"r": strong, "n": 10}) >= 4)
	check("départ : un débutant commence par les plus accessibles", Mastery.start_level({"r": all_wrong, "n": 8}) == 1)
	check("niveau annoncé à partir de six dossiers", not Mastery.known({"r": 3.0, "n": 5}) and Mastery.known({"r": 3.0, "n": 6}))

	# --- Les packs
	var pack := QuestionPack.load_files(load("res://main.gd").PACK_PATHS)
	var range_ok := pack.questions.all(func(q): return q["difficulte"] is float or q["difficulte"] is int) \
			and (pack.questions + pack.expert).all(func(q): return QuestionPack.difficulty_of(q) >= 1 and QuestionPack.difficulty_of(q) <= 5)
	check("chaque dossier a une difficulté de 1 à 5", range_ok)
	check("ancien format lu : facile 2, moyenne 3, difficile 4", QuestionPack.difficulty_of({"difficulte": "facile"}) == 2
			and QuestionPack.difficulty_of({"difficulte": "moyenne"}) == 3 and QuestionPack.difficulty_of({"difficulte": "difficile"}) == 4)
	check("contrôle : une difficulté de 6 est refusée", QuestionPack.check_question({"id": "x", "categorie": "c", "difficulte": 6, "question": "q",
			"indices": ["a", "b"], "reponse": "r", "reponse_courte": "r", "distracteurs": ["a", "b", "c"], "explication": "e",
			"image": {"statut": "a_trouver"}}).has("difficulté inconnue"))

	# --- La sauvegarde garde la première réponse
	var store := SaveStore.new("user://test_maitrise_store.json")
	var astro := pack.questions_in("Astronomie")
	var a0: Dictionary = astro[0]
	store.record_answer(a0["id"], true, 60)
	store.record_answer(a0["id"], true, 100)
	check("première réponse gardée (60), même après un sans-faute", store.first_points(a0["id"]) == 60 and store.best_points(a0["id"]) == 100)
	check("jamais joué : -1", store.first_points(astro[1]["id"]) == -1)
	var reloaded := SaveStore.new("user://test_maitrise_store.json")
	check("la première réponse survit au rechargement", reloaded.first_points(a0["id"]) == 60)
	var legacy := SaveStore.new("user://test_maitrise_legacy.json")
	legacy._apply({"dossiers": {"x1": {"best": 100, "plays": 1, "wins": 1}, "x2": {"best": 100, "plays": 4, "wins": 2}}})
	check("ancienne sauvegarde : la première réponse se déduit", legacy.first_points("x1") == 100 and legacy.first_points("x2") == 50)
	DirAccess.remove_absolute("user://test_maitrise_legacy.json")

	# --- L'ordre d'une fiche s'adapte
	var fresh := SaveStore.new("user://test_maitrise_fresh.json")
	var order3 := fresh.draw(astro, astro.size(), "", 3)
	var first_easy := order3.find_custom(func(q): return QuestionPack.difficulty_of(q) < 3)
	var head_ok := order3.slice(0, first_easy).all(func(q): return QuestionPack.difficulty_of(q) >= 3)
	var tail_ok := order3.slice(first_easy).all(func(q): return QuestionPack.difficulty_of(q) < 3)
	check("départ à 3 : d'abord les difficultés 3 et plus, les plus faciles à la fin", first_easy > 0 and head_ok and tail_ok)
	var skip := {astro[2]["id"]: true, astro[3]["id"]: true}
	check("dossiers déjà joués dans la partie : laissés de côté", fresh.draw(astro, astro.size(), "", 1, skip).size() == astro.size() - 2)
	DirAccess.remove_absolute("user://test_maitrise_fresh.json")

	# --- Dans le jeu
	var main: Control = load("res://main.tscn").instantiate()
	main.save_path = SAVE
	main.settings_path = SETTINGS
	root.add_child(main)
	if not main.is_node_ready():
		await main.ready
	main._settings.rules_seen = true
	await create_timer(1.0).timeout
	# Un joueur qui a déjà réussi sans indice tous les dossiers d'astronomie de difficulté 1 à 3 : Érudit.
	for q in main._pack.questions_in("Astronomie"):
		if QuestionPack.difficulty_of(q) <= 3:
			main._save.record_answer(q["id"], true, 100)
	var info: Dictionary = main._mastery_of("Astronomie")
	check("Astronomie : Érudit après un sans-faute jusqu'à la difficulté 3", Mastery.known(info) and Mastery.name_of(info["r"]) == "Érudit", str(info))
	main._progress.refresh()
	check("Mes résultats : « Votre niveau : Érudit »", (main._progress._category_level["Astronomie"] as Label).text == "Votre niveau : Érudit")
	check("Mes résultats : rien pour une discipline pas encore jouée", not (main._progress._category_level["Histoire"] as Label).visible)
	main._save.record_answer(main._pack.questions_in("Arts")[0]["id"], true, 100)
	main._progress.refresh()
	check("Mes résultats : « connu dans 5 dossiers » après un dossier d'Arts",
			(main._progress._category_level["Arts"] as Label).text == "Votre niveau : connu dans 5 dossiers")
	main._start_fiche("Astronomie", main._cover)
	await create_timer(0.8).timeout
	var play: PlayScreen = main._play
	check("fiche d'astronomie : on commence par un dossier de difficulté 4", QuestionPack.difficulty_of(play._q) == 4, str(QuestionPack.difficulty_of(play._q)))
	check("carte : cinq barres, autant de pleines que la difficulté", play._card._level.level == 4)
	# Deux dossiers de difficulté 4 trouvés sans indice : le niveau passe à Expert, et le jeu le dit.
	var notes := ""
	for i in 2:
		var right: Button = play._options.filter(func(o): return o.text == play._correct_text)[0]
		play._on_option_pressed(right)
		await create_timer(0.3).timeout
		notes += " ".join(play._explain_box.find_children("*", "Label", true, false).map(func(l): return (l as Label).text))
		check("réponse %d : « Peu de gens le savent. » après un dossier difficile trouvé sans indice" % (i + 1), play._feedback.text == "Exact, sans aucun indice. Peu de gens le savent.", play._feedback.text)
		if i == 0:
			play.resume()
			await create_timer(0.4).timeout
	check("niveau qui monte : « Astronomie : vous passez Expert. » sous l'explication", notes.contains("Astronomie : vous passez Expert."), notes.right(200))
	var ids: Array = play._questions.map(func(q): return q["id"])
	var unique := {}
	for id in ids:
		unique[id] = true
	check("la file adaptée ne repropose aucun dossier", unique.size() == ids.size())
	var rest: Array = play._questions.slice(play._index + 1)
	var waiting_rest := rest.filter(func(q): return not main._save.is_flawless(q["id"]))
	check("la suite : les dossiers pas encore trouvés, plus de dossier de difficulté 1 en tête", not waiting_rest.is_empty()
			and QuestionPack.difficulty_of(waiting_rest[0]) >= 3, str(waiting_rest.map(func(q): return QuestionPack.difficulty_of(q))))

	# Un dossier facile manqué : pas de phrase en plus.
	var easy_q: Dictionary = main._pack.questions_in("Histoire").filter(func(q): return QuestionPack.difficulty_of(q) == 1)[0]
	play.start(main._pack, [easy_q], [], true)
	await create_timer(0.4).timeout
	var wrong: Button = play._options.filter(func(o): return o.text != play._correct_text)[0]
	play._on_option_pressed(wrong)
	check("dossier facile manqué : « Pas tout à fait. »", play._feedback.text == "Pas tout à fait.", play._feedback.text)

	for p in [SAVE, SETTINGS, "user://test_maitrise_store.json"]:
		DirAccess.remove_absolute(p)
	print("--- ", "TOUT EST OK" if fails == 0 else "%d ÉCHEC(S)" % fails)
	quit(1 if fails > 0 else 0)
