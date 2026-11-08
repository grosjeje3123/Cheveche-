extends SceneTree
## « Comment jouer » : la page s'ouvre avant la toute première série (fiche ou défi du jour), une seule fois,
## et reste accessible depuis les Réglages.

const SAVE := "user://test_regles.json"
const SETTINGS := "user://test_regles_settings.json"
var fails := 0

func check(label: String, ok: bool, extra := "") -> void:
	print(("OK   " if ok else "FAIL ") + label + ("  " + extra if extra != "" else ""))
	if not ok:
		fails += 1

func _initialize() -> void:
	for p in [SAVE, SETTINGS]:
		DirAccess.remove_absolute(p)
	var main: Control = load("res://main.tscn").instantiate()
	main.save_path = SAVE
	main.settings_path = SETTINGS
	root.add_child(main)
	await create_timer(1.0).timeout
	var rules: RulesScreen = main._rules
	check("premier lancement : la page n'est pas encore vue", not main._settings.rules_seen)

	# Première fiche : la page passe avant le jeu, avec « Commencer ».
	main._start_fiche("Histoire", main._cover)
	await create_timer(0.6).timeout
	check("première fiche : « Comment jouer » s'ouvre d'abord", main._current == rules and rules.start_button.visible)
	var texts := rules.find_children("*", "Label", true, false).map(func(l): return (l as Label).text)
	check("la page dit les trois règles (100, 60, 30 points ; le défi du jour)", " ".join(texts).contains("100 sans indice, 60 avec un, 30 avec deux")
			and " ".join(texts).contains("défi de cinq dossiers"))
	# Retour sans commencer : on revient à la couverture, la page reviendra.
	main._close_rules()
	await create_timer(0.6).timeout
	check("retour sans commencer : couverture, page toujours à voir", main._current == main._cover and not main._settings.rules_seen)

	main._start_daily()
	await create_timer(0.6).timeout
	check("défi du jour en premier : la page passe aussi avant", main._current == rules)
	rules.start_button.pressed.emit()
	await create_timer(0.6).timeout
	check("« Commencer » : on entre dans le défi", main._current == main._play and main._series_kind == "daily")
	check("la page est notée comme vue, et gardée sur le disque", main._settings.rules_seen and Settings.new(SETTINGS).rules_seen)
	main._on_play_closed()
	await create_timer(0.6).timeout

	main._start_fiche("Astronomie", main._cover)
	await create_timer(0.6).timeout
	check("série suivante : directement dans le jeu", main._current == main._play)
	main._on_play_closed()
	await create_timer(0.6).timeout

	# Depuis les Réglages : la page, sans « Commencer » ; la flèche ramène aux Réglages.
	main._cover.open_settings.emit()
	await create_timer(0.6).timeout
	var ss: SettingsScreen = main._settings_screen
	var rows := ss.find_children("*", "Button", true, false).filter(func(x): return x.theme_type_variation == "RowButton")
	(rows[5] as Button).pressed.emit()
	await create_timer(0.6).timeout
	check("Réglages > Comment jouer : la page, sans bouton « Commencer »", main._current == rules and not rules.start_button.visible)
	rules.closed.emit()
	await create_timer(0.6).timeout
	check("la flèche ramène aux Réglages", main._current == ss)

	# La remise à zéro de la progression ne fait pas revenir la page.
	ss._on_reset_pressed()
	ss._on_reset_pressed()
	check("remise à zéro : la page reste vue", Settings.new(SETTINGS).rules_seen)

	for p in [SAVE, SETTINGS]:
		DirAccess.remove_absolute(p)
	print("--- ", "TOUT EST OK" if fails == 0 else "%d ÉCHEC(S)" % fails)
	quit(1 if fails > 0 else 0)
