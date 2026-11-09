extends SceneTree
## Révision espacée (boîtes 0 à 3 : demain, 3 jours, 7 jours, acquis) et carnet de curiosités (liste par discipline,
## onglets, fiche d'un dossier, favoris).

const SAVE := "user://test_carnet.json"
const SETTINGS := "user://test_carnet_settings.json"
const STORE := "user://test_carnet_store.json"
var fails := 0

func check(label: String, ok: bool, extra := "") -> void:
	print(("OK   " if ok else "FAIL ") + label + ("  " + extra if extra != "" else ""))
	if not ok:
		fails += 1


func _day(offset: int) -> String:
	return Week.key(Week.shifted(Week.today(), offset))


func _labels(node: Node) -> String:
	return " | ".join(node.find_children("*", "Label", true, false).filter(func(l): return (l as Label).is_visible_in_tree()).map(func(l): return (l as Label).text))


func _initialize() -> void:
	for p in [SAVE, SETTINGS, STORE]:
		DirAccess.remove_absolute(p)

	# --- Les boîtes
	var s := SaveStore.new(STORE)
	s.record_answer("a", false, 0, _day(0))
	check("manqué : à revoir, de retour demain", s.stage("a") == SaveStore.STAGE_REVIEW and s.return_day("a") == _day(1))
	check("pas avant demain : hors de la file aujourd'hui", not s.is_due("a", _day(0)) and s.is_due("a", _day(1)))
	s.record_answer("a", true, 100, _day(1))
	check("retrouvé sans indice le lendemain : à consolider, dans 3 jours", s.stage("a") == SaveStore.STAGE_CONSOLIDATE and s.return_day("a") == _day(4))
	s.record_answer("a", true, 100, _day(4))
	check("encore sans indice : dans 7 jours", s.stage("a") == SaveStore.STAGE_CONSOLIDATE and s.return_day("a") == _day(11))
	s.record_answer("a", true, 100, _day(11))
	check("encore sans indice : acquis, plus de date de retour", s.is_acquired("a") and s.return_day("a") == "")
	s.record_answer("b", true, 100, _day(0))
	check("trouvé sans indice du premier coup : à consolider, vérifié dans 7 jours", s.stage("b") == SaveStore.STAGE_CONSOLIDATE and s.return_day("b") == _day(7))
	s.record_answer("b", true, 100, _day(7))
	check("puis acquis", s.is_acquired("b"))
	s.record_answer("c", true, 60, _day(0))
	check("trouvé avec un indice : à revoir demain", s.stage("c") == SaveStore.STAGE_REVIEW and s.return_day("c") == _day(1))
	s.record_answer("b", false, 0, _day(8))
	check("un acquis manqué repart à zéro : à revoir demain", s.stage("b") == SaveStore.STAGE_REVIEW and s.return_day("b") == _day(9))
	check("jamais joué : à découvrir", s.stage("z") == SaveStore.STAGE_NEW)
	var reloaded := SaveStore.new(STORE)
	check("les boîtes survivent au rechargement", reloaded.is_acquired("a") and reloaded.stage("b") == SaveStore.STAGE_REVIEW and reloaded.return_day("c") == _day(1))
	var legacy := SaveStore.new("user://test_carnet_legacy.json")
	legacy._apply({"dossiers": {"x": {"best": 100, "plays": 1, "wins": 1}, "y": {"best": 60, "plays": 1, "wins": 1, "revoir": _day(1)}}})
	check("ancienne sauvegarde : un sans-faute revient une fois pour devenir acquis", legacy.stage("x") == SaveStore.STAGE_CONSOLIDATE and legacy.is_due("x"))
	check("ancienne sauvegarde : un dossier à revoir garde sa date", legacy.stage("y") == SaveStore.STAGE_REVIEW and legacy.return_day("y") == _day(1))
	DirAccess.remove_absolute("user://test_carnet_legacy.json")

	# --- Quand reviennent-ils ?
	var qs := [{"id": "a"}, {"id": "b"}, {"id": "c"}]
	check("« demain » quand tout revient demain", s.return_words([{"id": "c"}], _day(0)) == "demain", s.return_words([{"id": "c"}], _day(0)))
	var t := SaveStore.new("user://test_carnet_t.json")
	t.record_answer("p", true, 100, _day(0))
	check("« dans 7 jours »", t.return_words([{"id": "p"}], _day(0)) == "dans 7 jours", t.return_words([{"id": "p"}], _day(0)))
	t.record_answer("q", false, 0, _day(0))
	check("« à partir de demain » quand les retours s'étalent", t.return_words([{"id": "p"}, {"id": "q"}], _day(0)) == "à partir de demain")
	check("deux dossiers mis de côté", t.waiting_in([{"id": "p"}, {"id": "q"}], _day(0)) == 2)
	DirAccess.remove_absolute("user://test_carnet_t.json")

	# --- Favoris
	s.set_favorite("a", true)
	check("favori gardé", SaveStore.new(STORE).is_favorite("a"))
	var code := s.export_code()
	var other := SaveStore.new("user://test_carnet_other.json")
	check("favori transmis par le code de sauvegarde", other.import_code(code) and other.is_favorite("a"))
	s.set_favorite("a", false)
	check("favori retiré", not SaveStore.new(STORE).is_favorite("a"))
	DirAccess.remove_absolute("user://test_carnet_other.json")

	# --- Le carnet dans le jeu
	var main: Control = load("res://main.tscn").instantiate()
	main.save_path = SAVE
	main.settings_path = SETTINGS
	root.add_child(main)
	if not main.is_node_ready():
		await main.ready
	main._settings.rules_seen = true
	await create_timer(1.0).timeout
	var carnet: CarnetScreen = main._carnet
	var links: Array = main._cover.find_children("*", "Button", true, false).map(func(b): return (b as Button).text)
	check("couverture : un lien « Carnet » à côté de « Mes résultats » et « Réglages »", links.has("Carnet") and links.has("Mes résultats") and links.has("Réglages"))
	main._cover.open_carnet.emit()
	await create_timer(0.6).timeout
	check("carnet vide : « 0 découverte pour l’instant » et une phrase qui dit comment le remplir", main._current == carnet
			and carnet._count.text == "0" and _labels(carnet).contains("Votre carnet se remplit à chaque dossier joué"))
	carnet.back()
	await create_timer(0.6).timeout
	check("la flèche ramène à la couverture", main._current == main._cover)

	var astro: Array = main._pack.questions_in("Astronomie")
	main._save.record_answer(astro[0]["id"], true, 100)
	main._save.record_answer(astro[1]["id"], false, 0)
	main._save.record_answer(astro[2]["id"], true, 60)
	main._save.record_answer(astro[3]["id"], true, 100, _day(-20))
	main._save.record_answer(astro[3]["id"], true, 100, _day(-10))
	var hist: Dictionary = main._pack.questions_in("Histoire")[0]
	main._save.record_answer(hist["id"], true, 100, _day(-20))
	main._save.record_answer(hist["id"], true, 100, _day(-10))
	main._cover.open_carnet.emit()
	await create_timer(0.6).timeout
	var text := _labels(carnet)
	check("5 découvertes, dont 2 acquises", carnet._count.text == "5" and carnet._count_caption.text == "découvertes, dont 2 acquises", carnet._count_caption.text)
	check("rangé par discipline, dans l'ordre du jeu : Astronomie avant Histoire", text.find("Astronomie") >= 0 and text.find("Astronomie") < text.find("Histoire"))
	check("en-tête de discipline : « 4, dont 1 acquis »", text.contains("4, dont 1 acquis"))
	check("chaque ligne dit son état", text.contains("à revoir") and text.contains("à consolider") and text.contains("acquis"))
	var rows: Array = carnet._body.get_children().filter(func(c): return c is Button)
	check("une ligne par dossier joué", rows.size() == 5, str(rows.size()))
	check("les dossiers jamais joués n'y sont pas", not text.contains(str(astro[5].get("titre", "§"))))
	carnet._set_tab(CarnetScreen.Tab.REVIEW)
	await create_timer(0.3).timeout
	check("onglet « À revoir » : les 3 dossiers pas encore acquis", carnet._body.get_children().filter(func(c): return c is Button).size() == 3)
	carnet._set_tab(CarnetScreen.Tab.ACQUIRED)
	await create_timer(0.3).timeout
	check("onglet « Acquis » : 2 dossiers", carnet._body.get_children().filter(func(c): return c is Button).size() == 2)
	carnet._set_tab(CarnetScreen.Tab.FAVORITES)
	await create_timer(0.3).timeout
	check("onglet « Favoris » vide : il dit comment en ajouter", _labels(carnet).contains("touchez l’étoile d’un dossier"))
	carnet._set_tab(CarnetScreen.Tab.ALL)
	await create_timer(0.3).timeout

	# La fiche d'un dossier : tout ce qu'on a lu en jouant, et l'étoile.
	carnet._show_detail(astro[1]["id"])
	await create_timer(0.4).timeout
	var detail := _labels(carnet)
	check("fiche : la question, la réponse, l'explication", detail.contains(str(astro[1]["question"])) and detail.contains(str(astro[1]["reponse_courte"]))
			and detail.contains(str(astro[1]["explication"]).left(40)))
	check("fiche : « À revoir : il revient demain. »", detail.contains("À revoir : il revient demain."))
	check("fiche : le résumé et les onglets s'effacent", not carnet._top.visible)
	carnet._favorite_button.pressed.emit()
	check("l'étoile : en favori", main._save.is_favorite(astro[1]["id"]) and carnet._favorite_star.filled and carnet._favorite_button.text.contains("Dans vos favoris"))
	carnet.back()
	await create_timer(0.4).timeout
	check("retour de la fiche : la liste, avec son résumé", carnet.detail_id == "" and carnet._top.visible and main._current == carnet)
	carnet._set_tab(CarnetScreen.Tab.FAVORITES)
	await create_timer(0.3).timeout
	check("onglet « Favoris » : le dossier gardé", carnet._body.get_children().filter(func(c): return c is Button).size() == 1)
	carnet._show_detail(astro[3]["id"])
	await create_timer(0.3).timeout
	check("fiche d'un acquis : « Acquis : … »", _labels(carnet).contains("Acquis : vous l’avez retrouvé sans indice"))
	main._unhandled_input(_cancel())
	await create_timer(0.3).timeout
	check("bouton Retour d'Android : de la fiche à la liste", carnet.detail_id == "" and main._current == carnet)
	main._unhandled_input(_cancel())
	await create_timer(0.6).timeout
	check("puis de la liste à la couverture", main._current == main._cover)

	# Dans une fiche, les dossiers à consolider reviennent à leur date, les acquis passent en révision.
	var order: Array = main._save.draw(astro, astro.size())
	var ids: Array = order.map(func(q): return q["id"])
	check("fiche : un dossier à consolider attend sa date (pas dans la file)", not ids.has(astro[0]["id"]) and not ids.has(astro[1]["id"]) and not ids.has(astro[2]["id"]))
	check("fiche : un acquis vient en révision, à la fin", ids.back() == astro[3]["id"])

	# La révision d'une fiche : son premier dossier dit quand reviennent les autres.
	main._start_fiche("Astronomie", main._cover)
	await create_timer(0.6).timeout
	var play: PlayScreen = main._play
	check("fiche d'astronomie : la révision commence après les 26 dossiers pas encore joués", play.revision_from == 26 and play.waiting == 3,
			"%d, %d" % [play.revision_from, play.waiting])
	for k in 25:
		main._session_played[play._questions[k]["id"]] = true
	play._index = 25
	play._next.pressed.emit()
	await create_timer(0.3).timeout
	check("« Révision : les 3 dossiers à revoir reviendront à partir de demain. »",
			play._feedback.text == "Révision : les 3 dossiers à revoir reviendront à partir de demain.", play._feedback.text)
	play.closed.emit()
	await create_timer(0.6).timeout

	for p in [SAVE, SETTINGS, STORE]:
		DirAccess.remove_absolute(p)
	print("--- ", "TOUT EST OK" if fails == 0 else "%d ÉCHEC(S)" % fails)
	quit(1 if fails > 0 else 0)


func _cancel() -> InputEventAction:
	var e := InputEventAction.new()
	e.action = "ui_cancel"
	e.pressed = true
	return e
