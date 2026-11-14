extends SceneTree
## Code de sauvegarde (copier, restaurer) et résultat du défi à partager.

const SAVE := "user://test_sauvegarde.json"
const SAVE_B := "user://test_sauvegarde_b.json"
const SETTINGS := "user://test_sauvegarde_settings.json"
const REF := "user://test_sauvegarde_ref.json"
const FIX := "res://tests/fixtures/"
var fails := 0

func check(label: String, ok: bool, extra := "") -> void:
	print(("OK   " if ok else "FAIL ") + label + ("  " + extra if extra != "" else ""))
	if not ok:
		fails += 1

func _same(a: SaveStore, b: SaveStore) -> bool:
	return JSON.stringify(a._data(), "", true) == JSON.stringify(b._data(), "", true)

# Les chiffres que le jeu tire d'une progression : ceux que la 0.9.35 a notés dans tests/fixtures/attendu_0_9_35.json.
func _figures(pack: QuestionPack, s: SaveStore) -> Dictionary:
	var all: Array = pack.questions + pack.expert
	var out := {"par_discipline": {}}
	for d in ProgressScreen.DISCIPLINES:
		var l1: Array = pack.questions_in(d)
		var l2: Array = pack.questions_in(d, 2)
		var m := Mastery.rating(s, l1 + l2)
		out["par_discipline"][d] = {
			"trouves": s.collected_in(l1), "sans_indice": s.flawless_in(l1), "acquis": s.acquired_in(l1),
			"joues": s.played_in(l1 + l2).size(), "trouves_n2": s.collected_in(l2), "points": s.best_total_in(l1),
			"maitrise_n": int(m["n"]), "maitrise_rang": Mastery.rank_of(float(m["r"])),
		}
	out["trouves"] = s.collected_in(pack.questions)
	out["joues"] = s.played_in(all).size()
	out["series_jouees"] = s.series_played()
	out["meilleure_serie_10"] = s.best_series(10)
	out["meilleur_defi"] = s.best_daily()
	out["jours_de_suite_au_2026_11_10"] = s.daily_streak("2026-11-10")
	out["jours_de_suite_au_2026_11_12"] = s.daily_streak("2026-11-12")
	out["defi_2026_11_11_en_cours"] = s.daily_state("2026-11-11")["results"].size()
	out["defi_2026_11_12_fait"] = s.daily_done("2026-11-12")
	var favorites: Array = s._favorites.keys()
	favorites.sort()
	out["favoris"] = favorites
	out["a_revoir_au_2026_11_13"] = s.waiting_in(all, "2026-11-13")
	var w := s.week_summary(Week.from_key("2026-11-12"))
	out["semaine_du_2026_11_12"] = {"points": w["points"], "reponses": w["answers"], "justes": w["correct"], "jours": w["days_played"]}
	return out


# Même écriture pour des chiffres calculés (entiers) et relus d'un JSON (décimaux).
func _norm(figures: Dictionary) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(figures)), "", true)


func _text(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f != null else ""


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _clean(path: String) -> void:
	var dir := DirAccess.open(path.get_base_dir())
	if dir == null:
		return
	for name in dir.get_files():
		if name.begins_with(path.get_file()):
			dir.remove(name)


func _reference() -> void:
	# ---------- Sauvegarde de référence : écrite par la 0.9.35, elle doit toujours donner les mêmes chiffres ----------
	var pack := QuestionPack.load_files(load("res://main.gd").PACK_PATHS)
	var expected: Dictionary = JSON.parse_string(_text(FIX + "attendu_0_9_35.json"))
	var wanted := _norm(expected)
	_clean(REF)
	_write(REF, _text(FIX + "progress_0_9_35.json"))
	var ref := SaveStore.new(REF)
	check("référence 0.9.35 : lue", ref.load_state == SaveStore.LoadState.READ)
	check("référence 0.9.35 : mêmes chiffres qu'à l'époque", _norm(_figures(pack, ref)) == wanted)
	ref.save()
	check("référence 0.9.35 : mêmes chiffres après réécriture", _norm(_figures(pack, SaveStore.new(REF))) == wanted)
	var old_code := _text(FIX + "code_0_9_35.txt")
	_clean(SAVE_B)
	var from_code := SaveStore.new(SAVE_B)
	check("code 0.9.35 : accepté", from_code.import_code(old_code))
	check("code 0.9.35 : mêmes chiffres", _norm(_figures(pack, from_code)) == wanted)
	var new_code := ref.export_code()
	check("code : plus court qu'avant (le détail des anciens défis n'y est plus)", new_code.length() < old_code.length(),
			"%d contre %d" % [new_code.length(), old_code.length()])
	check("code : le dernier défi garde son détail", ref.daily_state("2026-11-11")["results"].size() == 2
			and ref.daily_state("2026-11-10")["results"].size() == 5 and ref.daily_state("2026-11-05")["results"].is_empty()
			and ref.daily_done("2026-11-05"))

	# ---------- Copie de secours ----------
	check("copie : faite au chargement réussi", FileAccess.file_exists(REF + SaveStore.BACKUP_SUFFIX))
	_write(REF, "{ ceci n'est pas du json")
	var back := SaveStore.new(REF)
	check("fichier abîmé : la copie est reprise", back.load_state == SaveStore.LoadState.RESTORED
			and _norm(_figures(pack, back)) == wanted)
	check("fichier abîmé : mis de côté en .bad, et le bon fichier est de retour", FileAccess.file_exists(REF + SaveStore.BAD_SUFFIX)
			and SaveStore.new(REF).load_state == SaveStore.LoadState.READ)
	_write(REF, "encore abîmé")
	var again := SaveStore.new(REF)
	var aside := 0
	for name in DirAccess.open(REF.get_base_dir()).get_files():
		if name.begins_with(REF.get_file() + SaveStore.BAD_SUFFIX):
			aside += 1
	check("second incident : repris de nouveau, le premier .bad n'est pas écrasé", again.load_state == SaveStore.LoadState.RESTORED
			and aside == 2 and _text(REF + SaveStore.BAD_SUFFIX) == "{ ceci n'est pas du json", str(aside))
	_write(REF, "abîmé")
	_write(REF + SaveStore.BACKUP_SUFFIX, "abîmée aussi")
	var lost := SaveStore.new(REF)
	check("fichier et copie abîmés : on repart de zéro, et on peut écrire", lost.load_state == SaveStore.LoadState.UNREADABLE
			and lost.collected_in(pack.questions) == 0 and lost.save())
	DirAccess.remove_absolute(REF)
	_write(REF + SaveStore.BACKUP_SUFFIX, _text(FIX + "progress_0_9_35.json"))
	var fresh := SaveStore.new(REF)
	check("pas de sauvegarde : une vieille copie n'est pas reprise", fresh.load_state == SaveStore.LoadState.NEW
			and fresh.collected_in(pack.questions) == 0 and not FileAccess.file_exists(REF + SaveStore.BACKUP_SUFFIX))

	# Fichier présent mais impossible à ouvrir : on ne l'écrase pas. (Sans effet pour un compte administrateur,
	# qui ouvre tout : le contrôle est alors sauté.)
	_clean(REF)
	_write(REF, _text(FIX + "progress_0_9_35.json"))
	SaveStore.new(REF)
	FileAccess.set_unix_permissions(REF, 0)
	if FileAccess.open(REF, FileAccess.READ) == null:
		var locked := SaveStore.new(REF)
		locked.record_answer("svt01-q01", true, 100, "2026-11-13")
		FileAccess.set_unix_permissions(REF, FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_WRITE_OWNER)
		check("fichier fermé à la lecture : la copie sert à jouer, le fichier n'est pas touché",
				locked.load_state == SaveStore.LoadState.RESTORED and not locked.save()
				and _text(REF) == _text(FIX + "progress_0_9_35.json"))
	else:
		FileAccess.set_unix_permissions(REF, FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_WRITE_OWNER)
		print("IGNORÉ fichier fermé à la lecture (ce compte ouvre tout)")

	# ---------- Code d'une version plus récente du jeu ----------
	_clean(REF)
	var future: Dictionary = JSON.parse_string(_text(FIX + "progress_0_9_35.json"))
	future["version"] = SaveStore.VERSION + 1
	var future_code := SaveStore.CODE_PREFIX + Marshalls.raw_to_base64(JSON.stringify(future).to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
	var careful := SaveStore.new(REF)
	check("code d'une version plus récente : reconnu et refusé, rien ne change", SaveStore.code_is_newer(future_code)
			and not SaveStore.code_is_newer(old_code) and not careful.import_code(future_code)
			and careful.collected_in(pack.questions) == 0)
	_clean(REF)
	_clean(SAVE_B)


func _initialize() -> void:
	for p in [SAVE, SAVE_B, SETTINGS]:
		DirAccess.remove_absolute(p)
	_reference()

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
	var newer: Dictionary = main._save._data().duplicate(true)
	newer["version"] = SaveStore.VERSION + 1
	var kept: String = clip["text"]
	clip["text"] = SaveStore.CODE_PREFIX + Marshalls.raw_to_base64(JSON.stringify(newer).to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
	restore.pressed.emit()
	check("restaurer un code plus récent que le jeu : message, pas de confirmation demandée",
			ss._restore_state.text == "Mettez d’abord le jeu à jour" and ss._armed == null)
	clip["text"] = kept
	check("réglages : le numéro de version vient du projet, sans « prototype »", not ("prototype" in SettingsScreen.VERSION_TEXT)
			and str(ProjectSettings.get_setting("application/config/version")) in SettingsScreen.VERSION_TEXT
			and str(ProjectSettings.get_setting("application/config/version")) != "", SettingsScreen.VERSION_TEXT)
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
		_clean(p)
	print("--- ", "TOUT EST OK" if fails == 0 else "%d ÉCHEC(S)" % fails)
	quit(1 if fails > 0 else 0)
