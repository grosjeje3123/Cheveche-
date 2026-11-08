extends SceneTree
## Défi du jour, réglages, crédits, sons et vibrations.

const SAVE := "user://test_features.json"
const SETTINGS := "user://test_features_settings.json"
var fails := 0

func check(label: String, ok: bool, extra := "") -> void:
	print(("OK   " if ok else "FAIL ") + label + ("  " + extra if extra != "" else ""))
	if not ok:
		fails += 1

func _ids(list: Array) -> Array:
	var out: Array = []
	for q in list:
		out.append(q["id"])
	return out

func _answer(play: PlayScreen, want_correct: bool) -> void:
	for b in play._options:
		if (b.text == play._correct_text) == want_correct:
			b.pressed.emit()
			break
	await process_frame
	await process_frame

func _labels(n: Node, out: Array) -> void:
	if n is Label:
		out.append(n.text)
	for c in n.get_children():
		_labels(c, out)

func _initialize() -> void:
	for p in [SAVE, SETTINGS]:
		DirAccess.remove_absolute(p)

	# ---------- Réglages ----------
	var st := Settings.new(SETTINGS)
	check("réglages par défaut : son et vibrations activés", st.sound and st.vibration)
	st.set_sound(false)
	check("réglages : le son coupé est retrouvé au relancement", not Settings.new(SETTINGS).sound and Settings.new(SETTINGS).vibration)
	st.set_sound(true)

	# ---------- Défi du jour : tirage ----------
	var paths := ["res://data/packs/svt_01.json", "res://data/packs/astro_01.json", "res://data/packs/animaux_01.json",
		"res://data/packs/histoire_01.json", "res://data/packs/arts_01.json", "res://data/packs/geographie_01.json",
		"res://data/packs/litterature_01.json"]
	var pack := QuestionPack.load_files(paths)
	var a := Daily.challenge(pack, "2026-11-04")
	var b := Daily.challenge(pack, "2026-11-04")
	check("défi : 5 dossiers", a.size() == 5)
	check("défi : le même tirage pour la même date", _ids(a) == _ids(b), str(_ids(a)))
	var groups := {}
	for q in a:
		groups[pack.collection_of(q)] = true
	check("défi : 5 disciplines différentes", groups.size() == 5, str(groups.keys()))
	var differ := 0
	for d in range(5, 25):
		if _ids(Daily.challenge(pack, "2026-11-%02d" % d)) != _ids(a):
			differ += 1
	check("défi : il change d'un jour à l'autre", differ == 20, str(differ))
	var curve_ok := true
	for d in range(1, 31):
		var levels: Array = Daily.challenge(pack, "2026-11-%02d" % d).map(func(q): return pack.difficulty_level(q))
		if levels != [1, 1, 2, 2, 3]:
			curve_ok = false
			print("  courbe du ", d, " : ", levels)
	check("défi : la difficulté monte (facile, facile, moyen, moyen, difficile), 30 jours de suite", curve_ok)
	check("défi : graine fixe (FNV-1a), indépendante du moteur", Daily.seed_of("2026-11-04") == Daily.seed_of("2026-11-04") and Daily.seed_of("a") == 3826002220, str(Daily.seed_of("a")))
	var fresh := SaveStore.new("user://test_features_other.json")
	fresh.record_answer(a[0]["id"], true, 100)
	check("défi : il ne dépend pas de la progression du joueur", _ids(Daily.challenge(pack, "2026-11-04")) == _ids(a))
	DirAccess.remove_absolute("user://test_features_other.json")

	# ---------- Défi du jour : jours de suite ----------
	var s := SaveStore.new(SAVE)
	check("jours de suite : aucun au départ", s.daily_streak("2026-11-04") == 0)
	for k in ["2026-11-01", "2026-11-02", "2026-11-03"]:
		s.record_daily_answer(k, {"id": "x", "correct": true, "clues": 0, "points": 100})
		s.finish_daily(k)
	check("jours de suite : 3 (aujourd'hui pas encore joué, on compte jusqu'à hier)", s.daily_streak("2026-11-04") == 3, str(s.daily_streak("2026-11-04")))
	s.finish_daily("2026-11-04")
	check("jours de suite : 4 une fois celui du jour fait", s.daily_streak("2026-11-04") == 4)
	check("jours de suite : un trou remet à zéro", s.daily_streak("2026-11-06") == 0)
	check("jours de suite : relus depuis le disque", SaveStore.new(SAVE).daily_streak("2026-11-04") == 4)
	s.reset()
	check("remise à zéro : plus de défi", s.daily_streak("2026-11-04") == 0 and not s.daily_done("2026-11-03"))

	# ---------- Crédits : licences et titres ----------
	check("licence : CC BY-SA 4.0", QuestionPack.licence_url("CC BY-SA 4.0") == "https://creativecommons.org/licenses/by-sa/4.0/deed.fr")
	check("licence : CC BY 3.0 FR", QuestionPack.licence_url("CC BY 3.0 FR") == "https://creativecommons.org/licenses/by/3.0/fr/deed.fr", QuestionPack.licence_url("CC BY 3.0 FR"))
	check("licence : CC0", QuestionPack.licence_url("CC0") == "https://creativecommons.org/publicdomain/zero/1.0/deed.fr")
	check("licence : domaine public, pas de lien", QuestionPack.licence_url("Domaine public") == "")
	check("titre de la source", QuestionPack.source_title("https://commons.wikimedia.org/wiki/File:Bee_on_lavender%2C_Provence.jpg") == "Bee on lavender, Provence",
			QuestionPack.source_title("https://commons.wikimedia.org/wiki/File:Bee_on_lavender%2C_Provence.jpg"))
	check("crédits : toutes les images vérifiées y figurent", pack.credit_entries().size() == pack.questions.size(), str(pack.credit_entries().size()))
	var q7: Dictionary = pack.by_id("svt01-q07")
	var saved_image = q7["image"]
	q7["image"] = {"statut": "verifie", "recherche": "", "fichier": "_test_photo.png", "auteur": "Camille Test",
		"licence": "CC BY-SA 4.0", "url_page": "https://commons.wikimedia.org/wiki/File:Red_blood_cells.jpg",
		"url_file": "u", "url_fichier": "u", "modifications": "Recadrée"}
	var entries := pack.credit_entries().filter(func(e): return e["dossier"] == 7)
	check("crédits : l'image vérifiée apparaît, complète", entries.size() == 1 and entries[0]["title"] == "Red blood cells"
			and entries[0]["licence_url"].ends_with("/by-sa/4.0/deed.fr") and entries[0]["changes"] == "Recadrée", str(entries))

	root.size = Vector2i(720, 1280)
	var cs := CreditsScreen.new()
	cs.theme = Ds.build_theme()
	cs.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cs.dry_run = true
	root.add_child(cs)
	cs.setup(pack)
	await process_frame
	var rich: Array = cs.find_children("*", "RichTextLabel", true, false)
	var all_text := ""
	for r in rich:
		all_text += (r as RichTextLabel).text + "\n"
	check("page Crédits : dossier, titre, auteur, lien de licence et lien de la page", "nº 7" in all_text and "Globules rouges" in all_text and "Red blood cells" in all_text and "Camille Test" in all_text
			and "[url=https://creativecommons.org/licenses/by-sa/4.0/deed.fr]" in all_text and "[url=https://commons.wikimedia.org/wiki/File:Red_blood_cells.jpg]" in all_text)
	check("page Crédits : polices sous licence OFL, avec lien", "[url=https://openfontlicense.org]" in all_text)
	check("page Crédits : l'auteur du jeu et son adresse, en lien", "Jérôme Hosdez" in all_text and "[url=mailto:jerome.hosdez@gmail.com]" in all_text)
	check("page Crédits : modifications en bref", "Recadrée." in all_text or "Réduite." in all_text or "Recadrée et réduite." in all_text)
	check("page Crédits : rangée par discipline, sommaire compris", cs._sections.size() == 8 and cs._sections.has("Nature") and cs._sections.has("Littérature"), str(cs._sections.keys()))
	cs.scroll_to("Littérature")
	await process_frame
	check("page Crédits : le sommaire fait défiler jusqu'à la discipline", cs._scroll.scroll_vertical > 1000, str(cs._scroll.scroll_vertical))
	(rich[2] as RichTextLabel).meta_clicked.emit("https://creativecommons.org/licenses/by-sa/4.0/deed.fr")
	check("page Crédits : toucher un lien l'ouvre", cs.last_opened == "https://creativecommons.org/licenses/by-sa/4.0/deed.fr")
	q7["image"] = saved_image
	# Sans aucune image vérifiée, une phrase le dit.
	var saved_all := {}
	for qq in pack.questions:
		saved_all[qq["id"]] = qq["image"]
		qq["image"] = {"statut": "a_trouver", "recherche": "test"}
	cs.rebuild()
	await process_frame
	var empty_text := ""
	for r in cs.find_children("*", "RichTextLabel", true, false):
		empty_text += (r as RichTextLabel).text
	check("page Crédits : sans image, une phrase le dit", "Aucune image pour l’instant" in empty_text)
	for qq in pack.questions:
		qq["image"] = saved_all[qq["id"]]
	cs.queue_free()

	# ---------- Parcours complet dans le jeu ----------
	DirAccess.remove_absolute(SAVE)
	var main: Control = load("res://main.tscn").instantiate()
	main.save_path = SAVE
	main.settings_path = SETTINGS
	root.add_child(main)
	if not main.is_node_ready():
		await main.ready
	main._settings.rules_seen = true  # « Comment jouer » déjà vue : on entre directement dans le jeu
	await create_timer(1.0).timeout
	var cover: CoverScreen = main._cover
	var play: PlayScreen = main._play
	var today := Week.today_key()
	check("couverture : carte du défi à jouer", not cover._daily.disabled and cover._daily_sub.text == "Cinq dossiers, les mêmes pour tout le monde." and not cover._daily_streak.visible and not cover._daily_stamp.visible)

	# Sons et vibrations : demandés au bon moment
	var fb: Feedback = main._feedback
	check("sons : Feedback présent dans le jeu", Feedback.current == fb)
	check("son d'ouverture joué au lancement, une seule fois", fb.history.count("startup") == 1, str(fb.history))
	cover.daily_pressed.emit()
	await create_timer(0.6).timeout
	var expected := _ids(Daily.challenge(main._pack, today))
	check("défi : les 5 dossiers du jour, dans l'ordre", _ids(play._questions) == expected and play._index == 0)
	await _answer(play, true)
	check("sons : « juste » après une bonne réponse", fb.history.back() == "right", str(fb.history))
	play._next.pressed.emit()
	await process_frame
	await _answer(play, false)
	check("sons : « faux » après une mauvaise réponse", fb.history.back() == "wrong")
	check("défi : 2 réponses enregistrées", main._save.daily_state(today)["results"].size() == 2)
	main._play.closed.emit()
	await create_timer(0.6).timeout
	check("couverture : défi « à reprendre »", cover._daily_sub.text == "À reprendre : 2 dossiers sur 5." and not cover._daily.disabled, cover._daily_sub.text)

	cover.daily_pressed.emit()
	await create_timer(0.6).timeout
	check("défi repris au 3e dossier (« 3 sur 5 »)", play._index == 2 and play._counter.text == "3 sur 5" and _ids(play._questions) == expected, play._counter.text)
	for i in 3:
		await _answer(play, true)
		play._next.pressed.emit()
		await create_timer(0.3).timeout
	await create_timer(0.6).timeout
	var result: ResultScreen = main._result
	check("défi terminé : écran de résultat", main._current == result)
	var labels: Array = []
	_labels(result, labels)
	check("résultat du défi : étiquette, jours de suite, pas de « Rejouer »", "Défi du jour" in labels and "1 jour de suite. Prochain défi demain." in labels
			and not result.find_children("*", "Button", true, false).any(func(x): return x.text == "Rejouer" and x.visible), str(labels.slice(0, 8)))
	check("résultat du défi : 5 dossiers, dont les 2 joués avant la pause", Scoring.correct_count(play._results) == 4 and play._results.size() == 5)
	await create_timer(0.6).timeout
	check("jingle de fin : « series_good » pour 400 / 500", fb.history.back() == "series_good", str(fb.history))
	check("jingle de fin : seuils 90 % et 30 %", Scoring.finish_effect([{"points": 100}, {"points": 80}]) == "series_great"
			and Scoring.finish_effect([{"points": 30}, {"points": 30}]) == "series_good" and Scoring.finish_effect([{"points": 0}, {"points": 30}]) == "series_low"
			and Scoring.finish_effect([]) == "")
	result.back.emit()
	await create_timer(0.6).timeout
	check("couverture : défi fait, tampon du jour, on peut revoir son résultat, 1 jour de suite", not cover._daily.disabled
			and cover._daily_stamp.visible and cover._daily_stamp.center_text == str(Week.from_key(today)["day"])
			and cover._daily_sub.text.ends_with(" points. Voir le résultat.")
			and cover._daily_streak.visible and cover._daily_streak.text == "1" and cover._daily_streak_caption.text == "jour de suite", cover._daily_sub.text)
	var plays_before: int = main._save.series_played()
	var history_before: int = fb.history.size()
	cover.daily_pressed.emit()
	await create_timer(0.6).timeout
	check("défi fait : la carte rouvre le résultat, sans rejouer", main._current == result and main._save.series_played() == plays_before
			and main._save.daily_state(today)["results"].size() == 5)
	check("défi revu : pas de nouveau jingle ni de tampon qui retombe", not fb.history.slice(history_before).any(func(x): return x.begins_with("series_") or x == "stamp"),
			str(fb.history.slice(history_before)))
	check("défi revu : bouton « Copier mon résultat »", result.share_button != null and result.share_button.visible and result.share_button.text == "Copier mon résultat")
	result.back.emit()
	await create_timer(0.6).timeout
	check("défi revu -> couverture", main._current == cover)

	# Réglages
	cover.open_settings.emit()
	await create_timer(0.6).timeout
	var ss: SettingsScreen = main._settings_screen
	check("réglages : écran visible, son et vibrations « Activé »", main._current == ss and ss._sound_state.text == "Activé" and ss._vibration_state.text == "Activé")
	var all_rows := ss.find_children("*", "Button", true, false).filter(func(x): return x.theme_type_variation == "RowButton")
	# Les lignes dans l'ordre utilisé ici : son, vibrations, remise à zéro, crédits (le code de sauvegarde et
	# « Comment jouer » ont leur test).
	var rows: Array = [all_rows[0], all_rows[1], all_rows[4], all_rows[6]]
	check("réglages : sept lignes (son, vibrations, copier, restaurer, remise à zéro, comment jouer, crédits)", all_rows.size() == 7)
	(rows[0] as Button).pressed.emit()
	check("réglages : son coupé, et gardé", ss._sound_state.text == "Coupé" and not main._settings.sound and not Settings.new(SETTINGS).sound)
	(rows[0] as Button).pressed.emit()
	(rows[1] as Button).pressed.emit()
	check("réglages : vibrations coupées", ss._vibration_state.text == "Coupé" and not main._settings.vibration)
	(rows[1] as Button).pressed.emit()
	var found_before: int = main._save.collected_in(main._pack.questions)
	(rows[2] as Button).pressed.emit()
	check("remise à zéro : un premier toucher demande confirmation, rien n'est effacé", ss._reset_state.text == "Toucher encore pour tout effacer"
			and main._save.collected_in(main._pack.questions) == found_before and found_before > 0)
	(rows[2] as Button).pressed.emit()
	check("remise à zéro : au second toucher, tout est effacé", main._save.collected_in(main._pack.questions) == 0 and not main._save.daily_done(today)
			and ss._reset_state.text == "Effacée")
	check("remise à zéro : les réglages sont gardés", main._settings.sound and main._settings.vibration)
	check("remise à zéro : la couverture repart du début (consigne, défi à jouer)", cover._info.visible and not cover._daily.disabled)
	(rows[3] as Button).pressed.emit()
	await create_timer(0.6).timeout
	check("réglages -> crédits", main._current == main._credits)
	main._credits.closed.emit()
	await create_timer(0.6).timeout
	check("crédits -> retour aux réglages", main._current == ss)
	ss.closed.emit()
	await create_timer(0.6).timeout
	check("réglages -> couverture", main._current == cover)
	await create_timer(0.8).timeout
	check("pas de son d'ouverture en revenant sur la couverture", fb.history.count("startup") <= 1, str(fb.history))

	for p in [SAVE, SETTINGS]:
		DirAccess.remove_absolute(p)
	print("--- ", "TOUT EST OK" if fails == 0 else "%d ÉCHEC(S)" % fails)
	quit(1 if fails > 0 else 0)
