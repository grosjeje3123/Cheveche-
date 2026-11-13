extends SceneTree
## Dossiers en image : le pack (32 dossiers qui reprennent l'image d'un autre dossier), le barème par tiers, leur place
## dans les séries (le sixième, pas au tout début d'une discipline, un seul par série), l'explication la première fois,
## la jauge, le bilan ; ils ne comptent ni dans le niveau, ni dans les fiches, ni dans le défi du jour.

const SAVE := "user://test_visuels.json"
const SETTINGS := "user://test_visuels_settings.json"
var fails := 0

func check(label: String, ok: bool, extra := "") -> void:
	print(("OK   " if ok else "FAIL ") + label + ("  " + extra if extra != "" else ""))
	if not ok:
		fails += 1

func _labels(node: Node) -> String:
	return " | ".join(node.find_children("*", "Label", true, false).filter(func(l): return (l as Label).is_visible_in_tree()).map(func(l): return (l as Label).text))

func _answer(play: PlayScreen, want_correct: bool) -> void:
	for b in play._options:
		if (b.text == play._correct_text) == want_correct:
			b.pressed.emit()
			break
	await create_timer(0.15).timeout

func _next(play: PlayScreen) -> void:
	play._next.pressed.emit()
	await create_timer(0.3).timeout

func _initialize() -> void:
	for p in [SAVE, SETTINGS]:
		DirAccess.remove_absolute(p)
	var pack := QuestionPack.load_files(load("res://main.gd").PACK_PATHS)
	# --- Le pack
	check("32 dossiers en image chargés, aucun écarté", pack.visuals.size() == 32 and pack.ignored == 0, "%d, %d" % [pack.visuals.size(), pack.ignored])
	var per := {}
	for v in pack.visuals:
		per[pack.collection_of(v)] = int(per.get(pack.collection_of(v), 0)) + 1
	check("quatre par discipline", per.size() == 8 and per.values().all(func(n): return n == 4), str(per))
	var same := true
	for v in pack.visuals:
		var src: Dictionary = pack.by_id(v["_source"])
		same = same and pack.has_verified_image(v) and v["image"]["fichier"] == src["image"]["fichier"] \
				and v["image"]["auteur"] == src["image"]["auteur"] and pack.image_path(v) == pack.image_path(src) \
				and pack.credit_line(v) == pack.credit_line(src) and pack.collection_of(v) == pack.collection_of(src)
	check("chacun reprend l'image vérifiée de son dossier (mêmes auteurs, même licence, même discipline)", same)
	check("à part : ni dans les fiches, ni dans « Au hasard »", not pack.questions.any(func(q): return QuestionPack.is_visual(q))
			and not pack.expert.any(func(q): return QuestionPack.is_visual(q)))
	check("la bonne réponse n'est jamais parmi les leurres", pack.visuals.all(func(v): return not (v["distracteurs"] as Array).has(v["reponse_courte"])))
	check("by_id les trouve", pack.by_id("visuels01-q01").get("reponse_courte", "") == "Mars")
	# --- Le barème
	check("barème : 100 sous un tiers, 60 jusqu'aux deux tiers, 30 au-delà", Scoring.points_for(true, RevealRules.visual_tier(0.2)) == 100
			and Scoring.points_for(true, RevealRules.visual_tier(0.34)) == 60 and Scoring.points_for(true, RevealRules.visual_tier(0.7)) == 30
			and Scoring.points_for(false, RevealRules.visual_tier(0.1)) == 0)

	var main: Control = load("res://main.tscn").instantiate()
	main.save_path = SAVE
	main.settings_path = SETTINGS
	root.add_child(main)
	if not main.is_node_ready():
		await main.ready
	main._settings.rules_seen = true
	await create_timer(1.0).timeout
	var play: PlayScreen = main._play
	var result: ResultScreen = main._result

	# --- Tout début d'une discipline : pas de dossier en image dans la première série.
	main._start_fiche("Animaux", main._cover)
	await create_timer(0.8).timeout
	var seen_visual := false
	for i in 7:
		seen_visual = seen_visual or play.visual
		await _answer(play, true)
		await _next(play)
	check("première série d'une discipline : aucun dossier en image", not seen_visual)
	play.closed.emit()
	await create_timer(0.6).timeout

	# --- Une discipline déjà bien jouée : le sixième dossier de la série est en image.
	for q in main._pack.questions_in("Astronomie").slice(0, 12):
		main._save.record_answer(q["id"], true, 100, Week.key(Week.shifted(Week.today(), -30)))
	var mastery_before: Dictionary = main._mastery_of("Astronomie")
	main._start_fiche("Astronomie", main._cover)
	await create_timer(0.8).timeout
	for i in 5:
		check("dossiers 1 à 5 : pas en image", not play.visual) if i == 0 else null
		await _answer(play, i != 2)
		await _next(play)
	check("sixième dossier : en image", play.visual and QuestionPack.is_visual(play._q), str(play._q.get("id")))
	check("bandeau « Dossier en image », pas de numéro", _labels(play._card).contains("Dossier en image") and not _labels(play._card).contains("nº"))
	check("pas d'indice écrit, la jauge à la place", not play._clues.visible and play._gauge.visible)
	check("la première fois : l'explication, par-dessus le dossier", play.visual_intro_open()
			and _labels(play).contains("Grattez juste ce qu’il faut pour la reconnaître") and _labels(play).contains("Jusqu’aux deux tiers : 60"))
	var go: Button = play._visual_intro.find_children("*", "Button", true, false)[0]
	go.pressed.emit()
	await create_timer(0.4).timeout
	check("« C’est parti » : l'explication s'en va et ne reviendra plus", not play.visual_intro_open() and main._settings.visual_seen
			and Settings.new(SETTINGS).visual_seen)
	check("avant de gratter : « Dossier en image : pas d’indice, l’image seule. », 100 pts", play._feedback.text == "Dossier en image : pas d’indice, l’image seule."
			and play._points.text == "100 pts", play._feedback.text)
	play._on_progress(0.2)
	check("20 % dévoilé : la jauge, « Image dévoilée à 20 %. », toujours 100 pts", play._gauge.fraction == 0.2
			and play._feedback.text == "Image dévoilée à 20 %." and play._points.text == "100 pts", play._feedback.text)
	play._on_progress(0.42)
	check("42 % : 60 pts", play._points.text == "60 pts" and play._feedback.text == "Image dévoilée à 42 %.")
	var visual_id: String = play._q["id"]
	await _answer(play, true)
	check("trouvé : « Exact, avec 42 % de l’image dévoilée. », +60", play._feedback.text == "Exact, avec 42 % de l’image dévoilée." and play._points.text == "+60",
			play._feedback.text + " " + play._points.text)
	check("pas de pépite pour un dossier en image", not is_instance_valid(play._pepite))
	check("noté dans la série et dans la sauvegarde", main._series_results.back().get("visual", false) and absf(float(main._series_results.back()["revealed"]) - 0.42) < 0.001
			and main._save.best_points(visual_id) == 60)
	check("le niveau ne compte pas les dossiers en image", int(main._mastery_of("Astronomie")["n"]) == int(mastery_before["n"]) + 5)
	check("l'explication : la réponse, et le crédit de l'image", _labels(play).contains(str(play._q["explication"]).left(30)) and _labels(play).contains(main._pack.credit_line(play._q)))
	await _next(play)
	check("septième dossier : de nouveau un dossier ordinaire", not play.visual and play._clues.visible and not play._gauge.visible)
	for i in 4:
		await _answer(play, true)
		if i < 3:
			await _next(play)
	check("dixième : « Voir le bilan » (le dossier en image compte dans les dix)", play._next.text == "Voir le bilan" and main._series_results.size() == 10, play._next.text)
	await _next(play)
	await create_timer(0.4).timeout
	var text := _labels(result)
	check("bilan : « Dossier en image, 42 % dévoilé »", text.contains("Dossier en image, 42 % dévoilé"), text.left(300))
	check("bilan : 9 trouvés sur 10", text.contains("9 dossiers trouvés sur 10"))
	# --- Série suivante : un autre dossier en image, sans explication.
	result.next_pressed.emit()
	await create_timer(0.6).timeout
	for i in 5:
		await _answer(play, true)
		await _next(play)
	check("série suivante : le sixième est en image, un autre, sans l'explication", play.visual and play._q["id"] != visual_id and not play.visual_intro_open())
	await _answer(play, false)
	check("manqué : « Pas tout à fait. » (pas de « Peu de gens le savent »)", play._feedback.text == "Pas tout à fait.", play._feedback.text)
	play.closed.emit()
	await create_timer(0.6).timeout
	check("la flèche en cours de série : retour à la couverture (les réponses sont gardées)", main._current == main._cover)

	# --- Le défi du jour : jamais de dossier en image.
	main._start_daily()
	await create_timer(0.8).timeout
	var daily_visual := false
	for i in 5:
		daily_visual = daily_visual or play.visual
		await _answer(play, true)
		await _next(play)
	check("défi du jour : aucun dossier en image", not daily_visual)

	for p in [SAVE, SETTINGS]:
		DirAccess.remove_absolute(p)
	print("--- ", "TOUT EST OK" if fails == 0 else "%d ÉCHEC(S)" % fails)
	quit(1 if fails > 0 else 0)
