extends SceneTree
## Code de sauvegarde (copier, restaurer) et résultat du défi à partager.

const SAVE := "user://test_sauvegarde.json"
const SAVE_B := "user://test_sauvegarde_b.json"
const SETTINGS := "user://test_sauvegarde_settings.json"
var fails := 0

func check(label: String, ok: bool, extra := "") -> void:
	print(("OK   " if ok else "FAIL ") + label + ("  " + extra if extra != "" else ""))
	if not ok:
		fails += 1

func _same(a: SaveStore, b: SaveStore) -> bool:
	return JSON.stringify(a._data(), "", true) == JSON.stringify(b._data(), "", true)

func _initialize() -> void:
	for p in [SAVE, SAVE_B, SETTINGS]:
		DirAccess.remove_absolute(p)

	# ---------- Le code, seul ----------
	var a := SaveStore.new(SAVE)
	var ids := ["svt01-q01", "astro02-q13", "histoire01-q03", "arts02-q06", "astron2-q12"]
	for i in ids.size():
		a.record_answer(ids[i], i != 2, [100, 60, 0, 30, 100][i], "2026-11-0%d" % (i + 1))
	a.record_daily_answer("2026-11-05", {"id": "svt01-q01", "correct": true, "clues": 0, "points": 100})
	a.finish_daily("2026-11-05")
	a.record_series(5, 380, "2026-11-05", SaveStore.BEST_DAILY)
	var code := a.export_code()
	check("code : commence par CHEVECHE1-", code.begins_with(SaveStore.CODE_PREFIX), code.substr(0, 16))
	check("code : court (quelques centaines de caractères ici)", code.length() < 4000, str(code.length()))

	var b := SaveStore.new(SAVE_B)
	check("code : relu et appliqué", b.import_code(code))
	check("code : même progression après restauration", _same(a, b))
	check("code : la restauration est écrite sur le disque", _same(a, SaveStore.new(SAVE_B)))
	check("code : dossier trouvé et meilleur défi repris", b.is_collected("svt01-q01") and not b.is_collected("histoire01-q03")
			and b.best_daily() == 380 and b.daily_done("2026-11-05"))

	# Collé au milieu d'autres mots, coupé de retours à la ligne (comme dans une note ou un message).
	var wrapped := ""
	for i in range(0, code.length(), 50):
		wrapped += code.substr(i, 50) + "\n"
	var c := SaveStore.new(SAVE_B)
	c.reset()
	check("code : accepté entouré de texte et coupé en lignes", c.import_code("Ma sauvegarde Chevêche : " + wrapped + "à garder."))
	check("code : même progression depuis le texte coupé", _same(a, c))

	# Codes invalides : rien ne change.
	c.reset()
	var tampered := code.substr(0, 40) + ("A" if code[40] != "A" else "B") + code.substr(41)
	var bad := ["", "bonjour", "CHEVECHE1-", "CHEVECHE1-abcd", code.substr(0, code.length() - 8), tampered,
			"CHEVECHE1-" + Marshalls.utf8_to_base64("pas du gzip"),
			"CHEVECHE1-" + Marshalls.raw_to_base64("[1, 2, 3]".to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))]
	var refused := 0
	for t in bad:
		if not c.import_code(t) and SaveStore.decode_code(t).is_empty():
			refused += 1
	check("code : textes vides, tronqués, altérés ou d'un autre format refusés", refused == bad.size(), "%d / %d" % [refused, bad.size()])
	check("code : un refus ne touche pas à la progression", c.collected_in([{"id": "svt01-q01"}]) == 0)

	# ---------- Le résultat du défi à partager ----------
	var results := [
		{"id": "a", "correct": true, "clues": 0, "points": 100},
		{"id": "b", "correct": true, "clues": 1, "points": 60},
		{"id": "c", "correct": false, "clues": 2, "points": 0},
		{"id": "d", "correct": true, "clues": 2, "points": 30},
		{"id": "e", "correct": true, "clues": 0, "points": 100},
	]
	var share := Daily.share_text(Week.from_key("2026-11-06"), results)
	check("partage : date, un signe par dossier, score", share == "Chevêche, défi du vendredi 6 novembre\n●◐○◐●  4/5, 290 points", share)
	check("partage : rien des réponses", not ("a" in share.split("\n")[1]))

	# ---------- Dans le jeu : Réglages ----------
	var main: Control = load("res://main.tscn").instantiate()
	main.save_path = SAVE
	main.settings_path = SETTINGS
	root.add_child(main)
	for i in 6:
		await process_frame
	var clip := {"text": ""}
	var ss: SettingsScreen = main._settings_screen
	ss.clipboard_set = func(t: String) -> void: clip["text"] = t
	ss.clipboard_get = func() -> String: return clip["text"]
	var rows := ss.find_children("*", "Button", true, false).filter(func(x): return x.theme_type_variation == "RowButton")
	var copy: Button = rows[2]
	var restore: Button = rows[3]
	var reset: Button = rows[4]
	main._save.record_answer("svt01-q01", true, 100)
	main._save.record_answer("astro02-q13", true, 60)
	var found: int = main._save.collected_in(main._pack.questions)
	main._cover.open_settings.emit()
	await create_timer(0.6).timeout

	restore.pressed.emit()
	check("restaurer sans code copié : message, rien ne change", ss._restore_state.text == "Copiez d’abord un code"
			and main._save.collected_in(main._pack.questions) == found)
	copy.pressed.emit()
	check("copier : code dans le presse-papiers, « Copiée »", ss._copy_state.text == "Copiée" and clip["text"].begins_with("CHEVECHE1-")
			and ss._restore_state.text == "")
	reset.pressed.emit()
	reset.pressed.emit()
	check("remise à zéro après la copie", main._save.collected_in(main._pack.questions) == 0)
	restore.pressed.emit()
	check("restaurer : un premier toucher demande confirmation", ss._restore_state.text == "Toucher encore pour remplacer"
			and main._save.collected_in(main._pack.questions) == 0)
	restore.pressed.emit()
	check("restaurer : au second toucher, la progression revient", ss._restore_state.text == "Restaurée"
			and main._save.collected_in(main._pack.questions) == found and main._save.is_collected("astro02-q13"))
	check("restaurer : gardé sur le disque", SaveStore.new(SAVE).collected_in(main._pack.questions) == found)
	# Un toucher sur « Remettre à zéro » puis sur « Restaurer » : la remise à zéro n'est plus en attente.
	reset.pressed.emit()
	restore.pressed.emit()
	reset.pressed.emit()
	check("deux lignes à confirmer : une seule en attente à la fois", main._save.collected_in(main._pack.questions) == found
			and ss._reset_state.text == "Toucher encore pour tout effacer", ss._reset_state.text)
	await create_timer(SettingsScreen.CONFIRM_SECONDS + 0.4).timeout
	check("les messages s'effacent après quelques secondes", ss._reset_state.text == "" and ss._restore_state.text == "" and ss._copy_state.text == "")

	# ---------- Dans le jeu : copier le résultat du défi ----------
	var result: ResultScreen = main._result
	result.clipboard_set = func(t: String) -> void: clip["text"] = t
	result.show_results(main._pack, [], {"kicker": "Défi du jour", "share": share, "quiet": true})
	check("résultat : bouton « Copier mon résultat »", result.share_button != null and result.share_button.text == "Copier mon résultat")
	result.share_button.pressed.emit()
	check("résultat : le texte est copié, le bouton le dit", clip["text"] == share and result.share_button.text.begins_with("Copié"))
	await create_timer(3.3).timeout
	check("résultat : le bouton reprend son nom", result.share_button.text == "Copier mon résultat")
	result.show_results(main._pack, [], {"kicker": "Terminé"})
	check("résultat sans partage : pas de bouton", result.share_button == null)

	for p in [SAVE, SAVE_B, SETTINGS]:
		DirAccess.remove_absolute(p)
	print("--- ", "TOUT EST OK" if fails == 0 else "%d ÉCHEC(S)" % fails)
	quit(1 if fails > 0 else 0)
