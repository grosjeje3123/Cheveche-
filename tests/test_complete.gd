extends SceneTree
## Fiche complète : page tamponnée au 30e dossier trouvé, second objectif « sans indice »,
## tampons sur la couverture, « Sans faute », et sortie par la flèche retour.

const SAVE := "user://test_complete.json"
var fails := 0

func check(label: String, ok: bool, extra := "") -> void:
	print(("OK   " if ok else "FAIL ") + label + ("  " + extra if extra != "" else ""))
	if not ok:
		fails += 1

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _answer(play: PlayScreen, want_correct: bool) -> void:
	for b in play._options:
		if (b.text == play._correct_text) == want_correct:
			b.pressed.emit()
			break
	await _frames(3)

func _labels(n: Node, out: Array) -> void:
	if n is Label:
		out.append(n.text)
	for c in n.get_children():
		_labels(c, out)

# Un dossier acquis : trouvé sans indice deux fois, à dix jours d'écart (révision espacée).
func _acquire(save: SaveStore, id: String) -> void:
	save.record_answer(id, true, 100, Week.key(Week.shifted(Week.today(), -20)))
	save.record_answer(id, true, 100, Week.key(Week.shifted(Week.today(), -10)))


func _initialize() -> void:
	# ---------- Sauvegarde : sans indice, total, ordre en trois paquets ----------
	var s := SaveStore.new("user://test_complete_unit.json")
	s.reset()
	var qs := [{"id": "a"}, {"id": "b"}, {"id": "c"}, {"id": "d"}]
	var yesterday := Week.key(Week.shifted(Week.today(), -1))
	# « a » : trouvé sans indice deux fois, à dix jours d'écart : acquis (il passe en révision, à la fin).
	s.record_answer("a", true, 100, Week.key(Week.shifted(Week.today(), -20)))
	s.record_answer("a", true, 100, Week.key(Week.shifted(Week.today(), -10)))
	s.record_answer("b", true, 60, yesterday)
	s.record_answer("b", true, 30, yesterday)
	s.record_answer("c", false, 0, yesterday)
	check("sans indice : seul le dossier à 100 points", s.is_flawless("a") and not s.is_flawless("b") and not s.is_flawless("c") and s.flawless_in(qs) == 1)
	check("total d'une fiche : somme des meilleurs scores (100 + 60)", s.best_total_in(qs) == 160, str(s.best_total_in(qs)))
	var order_ok := true
	for i in 30:
		var ids: Array = s.draw(qs, 4).map(func(q): return q["id"])
		if not ((ids[0] in ["c", "d"]) and (ids[1] in ["c", "d"]) and ids[2] == "b" and ids[3] == "a"):
			order_ok = false
	check("ordre d'une fiche : pas trouvés, puis à consolider, puis les acquis", order_ok)
	s.record_answer("d", false, 0)
	s.record_answer("b", true, 60)
	var today_ids: Array = s.draw(qs, 4).map(func(q): return q["id"])
	check("raté ou trouvé avec un indice aujourd'hui : pas avant demain", today_ids == ["c", "a"] and s.waiting_in(qs) == 2, str(today_ids))
	s.record_answer("b", true, 100)
	check("retrouvé sans indice : à consolider, de retour dans 3 jours", s.stage("b") == SaveStore.STAGE_CONSOLIDATE
			and s.return_day("b") == Week.key(Week.shifted(Week.today(), 3)) and s.waiting_in(qs) == 2)
	DirAccess.remove_absolute("user://test_complete_unit.json")
	check("nombres groupés par trois", Ds.thousands(2640) == "2 640" and Ds.thousands(300) == "300" and Ds.thousands(1234567) == "1 234 567")

	# ---------- Parcours ----------
	DirAccess.remove_absolute(SAVE)
	var main: Control = load("res://main.tscn").instantiate()
	main.save_path = SAVE
	root.add_child(main)
	if not main.is_node_ready():
		await main.ready
	main._settings.rules_seen = true  # « Comment jouer » déjà vue : on entre directement dans le jeu
	await _frames(8)
	await create_timer(0.6).timeout
	var pack: QuestionPack = main._pack
	var save: SaveStore = main._save
	var play: PlayScreen = main._play
	var complete: CompleteScreen = main._complete
	check("couverture : aucun tampon au départ", main._cover._stamps.size() == 8 and main._cover._stamps.values().all(func(x): return not x.visible))

	# Histoire (pas de niveau 2) : 29 dossiers trouvés d'avance, un sur trois avec un indice aujourd'hui (60 points,
	# à revoir demain), les autres acquis.
	var astro := pack.questions_in("Histoire")
	var helped := 0
	for i in range(1, astro.size()):
		if i % 3 == 0:
			save.record_answer(astro[i]["id"], true, 60)
		else:
			_acquire(save, astro[i]["id"])
		helped += 1 if i % 3 == 0 else 0
	main._cover.refresh()
	check("29 / 30 : pas encore de tampon", not main._cover._stamps["Histoire"].visible)

	main._start_fiche("Histoire", main._cover)
	await create_timer(0.7).timeout
	check("la fiche commence par le seul dossier pas encore trouvé", play._questions[0]["id"] == astro[0]["id"])
	check("en haut : « 29 / 30 trouvés »", play._counter.text == "29 / 30 trouvés", play._counter.text)
	await _answer(play, true)
	check("30e dossier trouvé : le prochain « Dossier suivant » est retenu", play.hold_next and main._pending_complete == "Histoire")
	play._next.pressed.emit()
	await create_timer(1.2).timeout
	check("page « Fiche complète » affichée", main._current == complete and complete.visible and not play.visible)
	var l: Array = []
	_labels(complete, l)
	var flawless := 30 - helped
	check("page : « Fiche complète », la discipline, « Les 30 dossiers sont trouvés. »", "Fiche complète" in l and "Histoire" in l and "Les 30 dossiers sont trouvés." in l, str(l))
	var points := save.best_total_in(astro)
	check("page : les points de la fiche sur 3 000", Ds.thousands(points) in l and "points sur 3 000" in l, str(l))
	check("page : %d sans indice, sur 30" % flawless, str(flawless) in l and "sans indice, sur 30" in l)
	check("page : le nouvel objectif", l.any(func(t): return t.begins_with("Nouvel objectif : trouver les %d autres sans indice." % helped)), str(l))
	check("page : tampon « Fiche complète », non plein", complete.stamp.top_text == "Fiche complète" and complete.stamp.bottom_text == "Histoire" and not complete.stamp.filled)
	check("page : le tampon puis le jingle", main._feedback.history.slice(-2) == ["stamp", "complete"], str(main._feedback.history))
	check("couverture : tampon de la fiche Histoire (non plein)", main._cover._stamps["Histoire"].visible and not main._cover._stamps["Histoire"].filled)
	check("« Mes résultats » : « Complète, %d sans indice »" % flawless, (main._progress._category_meta["Histoire"] as Label).text == "Complète, %d sans indice" % flawless,
			(main._progress._category_meta["Histoire"] as Label).text)

	complete.continue_pressed.emit()
	await create_timer(0.7).timeout
	check("Continuer : retour au jeu, dossier suivant", main._current == play and play._index == 1 and not play._answered)
	check("fiche complète : l'en-tête passe à « %d / 30 sans indice »" % flawless, play._counter.text == "%d / 30 sans indice" % flawless
			and is_equal_approx(play._segments.fills[0], float(flawless) / 30.0), play._counter.text)
	await _answer(play, true)
	check("réponse suivante : rien n'est retenu", not play.hold_next)
	play.closed.emit()
	await create_timer(0.7).timeout
	check("flèche retour : couverture", main._current == main._cover)

	# Rejouer la fiche complète le jour même : ceux trouvés avec un indice attendent demain ; on révise les autres
	main._start_fiche("Histoire", main._cover)
	await create_timer(0.6).timeout
	var still_waiting := 30 - save.acquired_in(astro)
	check("fiche rejouée le jour même : seulement la révision des acquis, les autres attendent leur date",
			still_waiting > 0 and play._questions.size() == 30 - still_waiting and play._questions.all(func(q): return save.is_acquired(q["id"]))
			and play.revision_from == 0 and play.waiting == still_waiting, "%d / %d" % [play._questions.size(), still_waiting])
	check("la révision le dit : « … reviendront à partir de demain. »", play._feedback.text == "Révision : les %d dossiers à revoir reviendront à partir de demain." % still_waiting, play._feedback.text)
	var tomorrow := Week.key(Week.shifted(Week.today(), 1))
	var next_day := save.draw(astro, 30, tomorrow)
	var due_tomorrow := next_day.filter(func(q): return not save.is_acquired(q["id"]))
	check("demain : les dossiers trouvés avec un indice passent en premier, avant la révision", due_tomorrow.size() == helped
			and next_day.slice(0, helped).all(func(q): return not save.is_acquired(q["id"])) and next_day.size() == 30 - 1, "%d, %d" % [due_tomorrow.size(), next_day.size()])
	play.closed.emit()
	await create_timer(0.6).timeout

	# Arts : sans faute d'un coup, et sortie par la flèche retour avant « Dossier suivant »
	var arts := pack.questions_in("Arts")
	for i in range(1, arts.size()):
		_acquire(save, arts[i]["id"])
	main._cover.refresh()
	main._start_fiche("Arts", main._cover)
	await create_timer(0.6).timeout
	await _answer(play, true)
	check("Arts : 30 dossiers trouvés sans indice", save.flawless_in(arts) == 30)
	play.closed.emit()
	await create_timer(1.0).timeout
	check("flèche retour juste après : la page vient quand même", main._current == complete)
	var l2: Array = []
	_labels(complete, l2)
	check("page : « Sans faute », « Les 30 dossiers trouvés sans aucun indice. », 3 000 points", "Sans faute" in l2
			and "Les 30 dossiers trouvés sans aucun indice." in l2 and "3 000" in l2, str(l2))
	check("page : tampon plein « Sans faute »", complete.stamp.filled and complete.stamp.top_text == "Sans faute")
	complete.continue_pressed.emit()
	await create_timer(0.7).timeout
	check("venu par la flèche retour : Continuer mène à la couverture", main._current == main._cover)
	check("couverture : tampon plein sur Arts", main._cover._stamps["Arts"].visible and main._cover._stamps["Arts"].filled)
	check("« Mes résultats » : Arts « Sans faute »", (main._progress._category_meta["Arts"] as Label).text == "Sans faute")

	# Un dossier déjà trouvé, retrouvé avec un indice : rien ne change, pas de page
	main._start_fiche("Arts", main._cover)
	await create_timer(0.6).timeout
	for b in play._options:
		if b.text == play._correct_text:
			play._clues_found = 1
			b.pressed.emit()
	await _frames(3)
	check("fiche déjà sans faute : pas de nouvelle page", not play.hold_next and main._pending_complete == "")
	play.closed.emit()
	await create_timer(0.6).timeout

	# Échap sur la page : couverture
	save._dossiers[arts[0]["id"]] = {"best": 60, "plays": 1, "wins": 1}
	main._start_fiche("Arts", main._cover)
	await create_timer(0.6).timeout
	await _answer(play, true)
	play._next.pressed.emit()
	await create_timer(0.8).timeout
	check("de nouveau sans faute : la page revient", main._current == complete)
	var ev := InputEventAction.new()
	ev.action = "ui_cancel"
	ev.pressed = true
	main._unhandled_input(ev)
	await create_timer(0.7).timeout
	check("Échap sur la page : couverture", main._current == main._cover)

	# ---------- Niveau 2 (Astronomie) ----------
	check("niveau 2 : 30 dossiers d'Astronomie à part, hors du jeu de base", pack.questions_in("Astronomie", 2).size() == 30
			and pack.questions.size() == 240 and pack.questions_in("Astronomie").size() == 30 and pack.expert.size() == 30)
	check("niveau 2 : numéros 131 à 160, retrouvés par identifiant", pack.dossier_number(pack.by_id("astron2-q01")) == 131
			and pack.dossier_number(pack.by_id("astron2-q30")) == 160 and QuestionPack.level_of(pack.by_id("astron2-q05")) == 2)
	check("niveau 2 : jamais dans le défi du jour", range(1, 31).all(func(d): return Daily.challenge(pack, "2026-12-%02d" % d).all(func(q): return QuestionPack.level_of(q) == 1)))
	main._start_fiche("", main._cover)
	await create_timer(0.5).timeout
	check("niveau 2 : jamais dans « Au hasard »", play._questions.size() == 240 - save.waiting_in(pack.questions)
			and play._questions.all(func(q): return QuestionPack.level_of(q) == 1), str(play._questions.size()))
	play.closed.emit()
	await create_timer(0.5).timeout
	main._start_fiche("Astronomie", main._cover)
	await create_timer(0.5).timeout
	check("niveau 2 : fermé tant que la fiche n'est pas complète", play._questions.size() == 30 and not main._level2_open("Astronomie"))
	play.closed.emit()
	await create_timer(0.5).timeout
	var astro_base: Array = pack.questions_in("Astronomie")
	for i in range(1, astro_base.size()):
		_acquire(save, astro_base[i]["id"])
	main._start_fiche("Astronomie", main._cover)
	await create_timer(0.6).timeout
	await _answer(play, true)
	play._next.pressed.emit()
	await create_timer(1.2).timeout
	var l5: Array = []
	_labels(complete, l5)
	check("fiche Astronomie complète : la page annonce le niveau 2", main._current == complete and l5.has("Le niveau 2 est ouvert : 30 dossiers plus pointus vous attendent dans cette fiche."), str(l5))
	var buttons: Array = complete.find_children("*", "Button", true, false).map(func(b): return b.text)
	check("page : « Jouer le niveau 2 » et « Plus tard »", buttons == ["Jouer le niveau 2", "Plus tard"], str(buttons))
	check("couverture : la fiche Astronomie affiche « niveau 2 », barre vide", main._cover._level_tags["Astronomie"].modulate.a > 0.9
			and main._cover._bars["Astronomie"].fills[0] == 0.0 and main._cover._level_tags["Histoire"].modulate.a < 0.1)
	check("« Mes résultats » : « Niveau 2 : 30 dossiers »", (main._progress._category_meta["Astronomie"] as Label).text == "Niveau 2 : 30 dossiers",
			(main._progress._category_meta["Astronomie"] as Label).text)
	complete.play_next_level.emit()
	await create_timer(0.7).timeout
	check("« Jouer le niveau 2 » : la fiche s'agrandit, les 30 dossiers du niveau 2 en tête", main._current == play
			and play._questions.size() == 30 + save.acquired_in(astro_base)
			and play._questions.slice(0, 30).all(func(q): return QuestionPack.level_of(q) == 2))
	# Le niveau 2 commence à la difficulté qui convient au joueur (Mastery.start_level), les plus faciles à la fin.
	var start2 := Mastery.start_level(main._mastery_of("Astronomie"))
	var level2: Array = play._questions.slice(0, 30).map(func(q): return pack.difficulty_level(q))
	var expected_first: int = level2.filter(func(d): return d >= start2).min() if level2.any(func(d): return d >= start2) else level2.min()
	check("niveau 2 : on commence à la difficulté qui convient au joueur (%d)" % start2, level2[0] == expected_first, str(level2))
	check("en-tête : « 0 / 30 niveau 2 »", play._counter.text == "0 / 30 niveau 2", play._counter.text)
	check("carte : « niveau 2 » à la place des barres", play._card._tier.visible and not play._card._level.visible)
	await _answer(play, true)
	check("bonne réponse au niveau 2 : « 1 / 30 niveau 2 »", play._counter.text == "1 / 30 niveau 2", play._counter.text)
	check("couverture : la barre suit le niveau 2", is_equal_approx(main._cover._bars["Astronomie"].fills[0], 1.0 / 30.0))
	check("« Mes résultats » : « Niveau 2 : 1 trouvé sur 30 »", (main._progress._category_meta["Astronomie"] as Label).text == "Niveau 2 : 1 trouvé sur 30",
			(main._progress._category_meta["Astronomie"] as Label).text)
	play.closed.emit()
	await create_timer(0.6).timeout
	var expert: Array = pack.questions_in("Astronomie", 2)
	var left_id := ""
	for q in expert:
		if not save.is_collected(q["id"]):
			if left_id == "":
				left_id = q["id"]
			else:
				save.record_answer(q["id"], true, 60)
	main._start_fiche("Astronomie", main._cover)
	await create_timer(0.6).timeout
	check("il ne reste qu'un dossier du niveau 2 : il vient en premier", play._questions[0]["id"] == left_id)
	await _answer(play, true)
	play._next.pressed.emit()
	await create_timer(1.2).timeout
	var l6: Array = []
	_labels(complete, l6)
	check("niveau 2 complet : sa page, tampon anthracite « Niveau 2 »", main._current == complete and "Niveau 2 complet" in l6
			and "Astronomie, niveau 2" in l6 and complete.stamp.top_text == "Niveau 2" and complete.stamp.color == Ds.INK, str(l6))
	var buttons2: Array = complete.find_children("*", "Button", true, false).map(func(b): return b.text)
	check("niveau 2 complet : « Continuer » et « Retour à la couverture »", buttons2 == ["Continuer", "Retour à la couverture"], str(buttons2))
	complete.continue_pressed.emit()
	await create_timer(0.6).timeout
	check("niveau 2 complet : l'en-tête passe au « sans indice » du niveau 2", play._counter.text == "%d / 30 sans indice" % save.flawless_in(expert), play._counter.text)
	check("« Mes résultats » : « Niveau 2 complet, n sans indice »", (main._progress._category_meta["Astronomie"] as Label).text == "Niveau 2 complet, %d sans indice" % save.flawless_in(expert),
			(main._progress._category_meta["Astronomie"] as Label).text)
	play.closed.emit()
	await create_timer(0.5).timeout

	# Une fiche où tout est à revoir demain : on ne l'ouvre pas, la couverture le dit.
	for q in pack.questions_in("Littérature"):
		save.record_answer(q["id"], false, 0)
	main._cover.refresh()
	main._start_fiche("Littérature", main._cover)
	await create_timer(0.6).timeout
	check("tout est à revoir demain : la fiche ne s'ouvre pas, la couverture le dit", main._current == main._cover
			and main._cover._info.visible and main._cover._info.text == "Littérature : 30 dossiers à revoir demain.", main._cover._info.text)
	await create_timer(4.3).timeout
	check("le mot s'efface ensuite", not main._cover._info.visible)

	DirAccess.remove_absolute(SAVE)
	print("--- ", "TOUT EST OK" if fails == 0 else "%d ÉCHEC(S)" % fails)
	quit(1 if fails > 0 else 0)
