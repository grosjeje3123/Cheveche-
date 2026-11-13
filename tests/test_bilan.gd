extends SceneTree
## Séries de dix dossiers dans une fiche, leur bilan (la chouette, la pluie de papier, la difficulté de chaque
## dossier, les pépites, le niveau), « Série suivante », et la fête de fin du défi du jour.

const SAVE := "user://test_bilan.json"
const SETTINGS := "user://test_bilan_settings.json"
var fails := 0

func check(label: String, ok: bool, extra := "") -> void:
	print(("OK   " if ok else "FAIL ") + label + ("  " + extra if extra != "" else ""))
	if not ok:
		fails += 1

func _answer(play: PlayScreen, want_correct: bool) -> void:
	for b in play._options:
		if (b.text == play._correct_text) == want_correct:
			b.pressed.emit()
			break
	await create_timer(0.15).timeout

func _labels(node: Node) -> String:
	return " | ".join(node.find_children("*", "Label", true, false).map(func(l): return (l as Label).text))

func _initialize() -> void:
	for p in [SAVE, SETTINGS]:
		DirAccess.remove_absolute(p)
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

	# --- Une série de dix dossiers d'Histoire : 7 trouvés, 3 manqués
	main._start_fiche("Histoire", main._cover)
	await create_timer(0.8).timeout
	var queue_size: int = play._questions.size()
	for i in 10:
		await _answer(play, i % 3 != 2 or i == 9)
		if i < 9:
			check("dossier %d : « Dossier suivant »" % (i + 1), play._next.text == "Dossier suivant", play._next.text) if i == 0 else null
			play._next.pressed.emit()
			await create_timer(0.3).timeout
	check("dixième dossier : « Voir le bilan »", play._next.text == "Voir le bilan", play._next.text)
	play._next.pressed.emit()
	await create_timer(0.6).timeout
	check("bilan à l'écran", main._current == result and result.visible)
	var text := _labels(result)
	check("bilan : « Série terminée », la discipline", text.contains("Série terminée") and text.contains("Histoire"))
	check("bilan : « 7 dossiers trouvés sur 10. »", text.contains("7 dossiers trouvés sur 10."), text.left(300))
	check("bilan : la chouette sur ses livres", result.owl != null and result.owl.texture == RulesScreen.SCENE)
	check("bilan : la pluie de papier (au moins la moitié trouvée)", result.confetti != null and result.confetti.is_running())
	var levels := result.find_children("*", "DsLevel", true, false)
	check("bilan : la difficulté de chacun des 10 dossiers", levels.size() == 10)
	check("bilan : le niveau en Histoire (10 dossiers joués)", text.contains("Histoire : votre niveau est") or text.contains("Histoire : niveau"), text)
	var buttons := result.find_children("*", "Button", true, false).map(func(b): return (b as Button).text)
	check("bilan : « Série suivante » et « Retour à la couverture »", buttons.has("Série suivante") and buttons.has("Retour à la couverture"), str(buttons))
	await create_timer(2.8).timeout
	check("la pluie de papier s'arrête d'elle-même", not result.confetti.is_running())

	# --- « Série suivante » : la file reprend au onzième dossier
	result.next_pressed.emit()
	await create_timer(0.6).timeout
	check("série suivante : retour au jeu, au onzième dossier", main._current == play and play._index == 10 and not play._answered, str(play._index))
	check("série suivante : une série neuve", main._series_results.is_empty())
	await _answer(play, true)
	check("série suivante : « Dossier suivant » après le premier", play._next.text == "Dossier suivant", play._next.text)

	# --- Une pépite : un dossier de difficulté 4, trouvé sans indice du premier coup
	play.closed.emit()
	await create_timer(0.6).timeout
	var hard: Dictionary = main._pack.questions_in("Arts").filter(func(q): return QuestionPack.difficulty_of(q) >= 4)[0]
	check("pépite : la règle", main.is_pepite(hard, true, true, 100) and not main.is_pepite(hard, false, true, 100)
			and not main.is_pepite(hard, true, true, 60) and not main.is_pepite(main._pack.questions_in("Arts")[0], true, true, 100))
	main._start_fiche("Arts", main._cover)
	await create_timer(0.8).timeout
	await _answer(play, false)
	play.set_upcoming([hard])  # le dossier difficile tout de suite après le premier
	play._next.pressed.emit()
	await create_timer(0.4).timeout
	check("pépite : le dossier difficile à l'écran", play._q["id"] == hard["id"])
	await _answer(play, true)
	await create_timer(0.5).timeout
	check("pépite : « Une pépite ! » et le tampon ocre sur l'image", play._feedback.text == "Exact, sans aucun indice. Une pépite !"
			and is_instance_valid(play._pepite) and play._pepite.top_text == "Pépite" and play._pepite.modulate.a > 0.9)
	check("pépite : notée dans la série", main._series_results.back()["pepite"] == true)
	play.end_series_here()  # on ferme la série ici (comme au dixième dossier)
	check("série fermée : « Voir le bilan »", play._next.text == "Voir le bilan", play._next.text)
	play._next.pressed.emit()
	await create_timer(0.6).timeout
	text = _labels(result)
	check("bilan : « 1 dossier trouvé sur 2, dont 1 pépite. »", text.contains("1 dossier trouvé sur 2, dont 1 pépite."), text.left(200))
	check("bilan : la ligne du dossier dit « pépite »", text.contains("pépite |") or text.ends_with("pépite"))
	result.back.emit()
	await create_timer(0.6).timeout
	check("retour : la couverture", main._current == main._cover)

	# --- Le défi du jour : la chouette aussi
	main._start_daily()
	await create_timer(0.8).timeout
	for i in 5:
		await _answer(play, true)
		play._next.pressed.emit()
		await create_timer(0.4).timeout
	check("défi : bilan avec la chouette et la pluie de papier", main._current == result and result.owl != null and result.confetti != null)
	check("défi : le tampon dateur toujours là", result.stamp != null)

	for p in [SAVE, SETTINGS]:
		DirAccess.remove_absolute(p)
	print("--- ", "TOUT EST OK" if fails == 0 else "%d ÉCHEC(S)" % fails)
	quit(1 if fails > 0 else 0)
