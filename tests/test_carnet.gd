extends SceneTree
## Révision espacée (boîtes 0 à 3 : demain, 3 jours, 7 jours, acquis) et carnets à feuilleter (l'étagère, un carnet
## par discipline et celui des favoris, le sommaire, les pages qu'on tourne du doigt ou par les flèches, l'étoile).

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
	check("couverture : un lien « Carnets » à côté de « Mes résultats » et « Réglages »", links.has("Carnets") and links.has("Mes résultats") and links.has("Réglages"))
	main._cover.open_carnet.emit()
	await create_timer(0.6).timeout
	check("carnets vides : « 0 découverte pour l’instant » et une phrase qui dit comment les remplir", main._current == carnet
			and carnet._count.text == "0" and _labels(carnet).contains("Vos carnets se remplissent à chaque dossier joué"))
	check("l'étagère : huit carnets et celui des favoris, tous vierges", carnet.covers.size() == 9 and carnet.covers.has("Favoris")
			and carnet.covers.values().all(func(b): return (b.get_child(0) as NotebookCover).blank))
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
	check("5 découvertes (sans parler d'acquis)", carnet._count.text == "5" and carnet._count_caption.text == "découvertes", carnet._count_caption.text)
	var astro_cover: NotebookCover = carnet.covers["Astronomie"].get_child(0)
	check("carnet d'astronomie : « 4 pages », pas vierge", astro_cover.caption == "4 pages" and not astro_cover.blank)
	check("carnet d'histoire : « 1 page » ; les sciences : vierge", (carnet.covers["Histoire"].get_child(0) as NotebookCover).caption == "1 page"
			and (carnet.covers["Sciences"].get_child(0) as NotebookCover).blank)
	check("l'étagère dans l'ordre du jeu, les favoris en dernier", carnet.covers.keys() == ProgressScreen.DISCIPLINES + ["Favoris"], str(carnet.covers.keys()))

	# Le carnet d'astronomie : la couverture s'ouvre sur le sommaire.
	carnet.covers["Astronomie"].pressed.emit()
	await create_timer(0.1).timeout
	check("la couverture s'ouvre (elle pivote autour du dos)", carnet._frame.get_children().any(func(c): return c is NotebookCover))
	await create_timer(0.6).timeout
	check("ouverte : plus de couverture par-dessus", not carnet._frame.get_children().any(func(c): return c is NotebookCover and not c.is_queued_for_deletion()))
	var text := _labels(carnet)
	check("sommaire : « Astronomie », « 4 pages. »", carnet.book == "Astronomie" and carnet.page_index == 0 and text.contains("4 pages."), text.left(200))
	check("sommaire : une ligne par dossier joué, sans état de révision", carnet._paper.find_children("*", "Button", true, false).size() == 4
			and not text.contains("à revoir") and not text.contains("consolider") and not text.contains("acquis"))
	check("sommaire : les dossiers jamais joués n'y sont pas", not text.contains(str(astro[5].get("titre", "§"))))
	check("en bas : « sommaire », la flèche de gauche éteinte", carnet._page_label.text == "sommaire" and carnet._prev.disabled and not carnet._next.disabled)
	# On tourne la page avec la flèche.
	carnet._next.pressed.emit()
	await create_timer(0.1).timeout
	check("la page tourne : l'ancienne se replie vers la reliure, la nouvelle est dessous", carnet._paper_area.get_child_count() >= 2)
	await create_timer(0.5).timeout
	check("page 1 : le premier dossier", carnet.page_index == 1 and carnet.detail_id == astro[0]["id"] and carnet._page_label.text == "page 1 sur 4")
	check("la page tournée est partie", carnet._paper_area.get_children().filter(func(c): return not c.is_queued_for_deletion()).size() == 1)
	# Du doigt : glisser vers la gauche, page suivante ; vers la droite, page précédente.
	_swipe(carnet, -200)
	await create_timer(0.5).timeout
	check("glissé vers la gauche : page 2", carnet.page_index == 2 and carnet.detail_id == astro[1]["id"], str(carnet.page_index))
	var page := _labels(carnet)
	check("page : la question, la réponse, l'explication, l'anecdote", page.contains(str(astro[1]["question"])) and page.contains(str(astro[1]["reponse_courte"]))
			and page.contains(str(astro[1]["explication"]).left(40)) and page.contains("Le saviez-vous ?"))
	check("page : pas d'état de révision, le tampon de la discipline et du numéro", not page.contains("À revoir") and not page.contains("consolider")
			and carnet._page_stamp.top_text == "Astronomie" and carnet._page_stamp.bottom_text == "nº %d" % main._pack.dossier_number(astro[1]))
	check("page : la photo scotchée et son crédit", page.contains(main._pack.credit_line(astro[1])) if main._pack.has_verified_image(astro[1]) else true)
	_swipe(carnet, 30)
	await create_timer(0.5).timeout
	check("un petit glissé ne tourne pas la page", carnet.page_index == 2)
	_swipe(carnet, 200)
	await create_timer(0.5).timeout
	check("glissé vers la droite : retour page 1", carnet.page_index == 1)
	# L'étoile.
	carnet._favorite_button.pressed.emit()
	check("l'étoile : en favori", main._save.is_favorite(astro[0]["id"]) and carnet._favorite_star.filled)
	# Le sommaire : toucher une ligne mène à sa page.
	carnet.prev_page()
	await create_timer(0.5).timeout
	var rows: Array = carnet._paper.find_children("*", "Button", true, false)
	check("sommaire : 4 lignes", rows.size() == 4, str(rows.size()))
	rows[3].pressed.emit()
	await create_timer(0.5).timeout
	check("une ligne du sommaire : sa page (page 4)", carnet.page_index == 4 and carnet.detail_id == astro[3]["id"])
	check("page d'un dossier acquis : rien sur la révision non plus", not _labels(carnet).contains("Acquis") and carnet._page_stamp.color == Ds.discipline_color("Astronomie"))
	carnet.next_page()
	await create_timer(0.5).timeout
	check("dernière page : on ne va pas plus loin", carnet.page_index == 4 and carnet._next.disabled)
	carnet.back()
	await create_timer(0.4).timeout
	check("retour : l'étagère", carnet.book == "" and carnet._shelf_view.visible and main._current == carnet)
	check("le carnet des favoris : « 1 page »", (carnet.covers["Favoris"].get_child(0) as NotebookCover).caption == "1 page")
	carnet.open_book("Favoris")
	await create_timer(0.6).timeout
	check("favoris : le dossier gardé", carnet.pages.size() == 1 and carnet.pages[0]["id"] == astro[0]["id"] and _labels(carnet).contains("1 page gardée."))
	carnet.back()
	carnet.open_book("Sciences")
	await create_timer(0.6).timeout
	check("carnet vierge : il dit comment il se remplit, pas de page à tourner", _labels(carnet).contains("Ce carnet est encore vierge") and carnet._next.disabled)
	carnet.back()
	carnet.open_book("Histoire")
	await create_timer(0.6).timeout
	carnet.next_page()
	await create_timer(0.5).timeout
	main._unhandled_input(_cancel())
	await create_timer(0.3).timeout
	check("bouton Retour d'Android : du carnet à l'étagère", carnet.book == "" and main._current == carnet)
	main._unhandled_input(_cancel())
	await create_timer(0.6).timeout
	check("puis de l'étagère à la couverture", main._current == main._cover)

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


func _swipe(carnet: CarnetScreen, dx: float) -> void:
	var a := InputEventMouseButton.new()
	a.button_index = MOUSE_BUTTON_LEFT
	a.pressed = true
	a.position = Vector2(360, 600)
	carnet._input(a)
	var b := InputEventMouseButton.new()
	b.button_index = MOUSE_BUTTON_LEFT
	b.pressed = false
	b.position = Vector2(360 + dx, 610)
	carnet._input(b)
