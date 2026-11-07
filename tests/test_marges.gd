extends SceneTree
## Aucun écran ne déborde à droite sur un téléphone (720 unités de large) : les marges gauche et droite restent
## égales. Régression : avec le titre « CHEVÊCHE », la barre du haut du jeu dépassait de 40 et toute la colonne
## se décalait à droite.
## Usage : … --resolution 720x1600 --script test_marges.gd

const SAVE := "user://test_marges.json"
var fails := 0
var main: Control

func check(label: String, ok: bool, extra := "") -> void:
	print(("OK   " if ok else "FAIL ") + label + ("  " + extra if extra != "" else ""))
	if not ok:
		fails += 1

# Les éléments visibles qui sortent de l'écran à droite (ou à gauche), en unités.
func _overflow(screen: Control) -> Array:
	var vw := root.get_visible_rect().size.x
	var out := []
	for c in screen.find_children("*", "Control", true, false):
		var ctrl := c as Control
		if not ctrl.is_visible_in_tree() or ctrl.size.x <= 0.0:
			continue
		var r := ctrl.get_global_rect()
		if r.end.x > vw + 0.5 or r.position.x < -0.5:
			out.append("%s %s [%.0f → %.0f]" % [ctrl.get_class(), ctrl.name, r.position.x, r.end.x])
		# Une marge de page plus large que son parent : son contenu a poussé (c'était le bogue du titre).
		var parent := ctrl.get_parent() as Control
		if ctrl is MarginContainer and parent != null and not (parent is ScrollContainer) and ctrl.size.x > parent.size.x + 0.5:
			out.append("marge %s plus large que son parent (%.0f > %.0f)" % [ctrl.name, ctrl.size.x, parent.size.x])
	return out

func _check_screen(label: String, screen: Control) -> void:
	var bad := _overflow(screen)
	check(label + " : rien ne déborde", bad.is_empty(), ", ".join(bad.slice(0, 3)))

func _initialize() -> void:
	DirAccess.remove_absolute(SAVE)
	main = load("res://main.tscn").instantiate()
	main.save_path = SAVE
	root.add_child(main)
	await create_timer(2.6).timeout
	print("largeur visible : ", root.get_visible_rect().size)
	_check_screen("couverture", main._cover)

	main._start_fiche("Astronomie", main._cover)
	await create_timer(0.8).timeout
	var play: PlayScreen = main._play
	_check_screen("jeu, fiche", play)
	var vw := root.get_visible_rect().size.x
	var card := play._card.get_global_rect()
	check("jeu : marges gauche et droite égales", absf(card.position.x - (vw - card.end.x)) < 1.0,
			"%.0f / %.0f" % [card.position.x, vw - card.end.x])
	check("jeu : marge de %d de chaque côté" % Ds.MARGIN, absf(card.position.x - Ds.MARGIN) < 1.0, "%.0f" % card.position.x)
	var brand: Control = play._col.get_child(0).get_child(1)
	var title_center := brand.get_global_rect().get_center().x
	check("jeu : le titre est au centre de l'écran", absf(title_center - vw / 2.0) < 1.0, "%.1f" % title_center)
	for t in [[270, 270, 270, 1], [30, 30, 30, 1], [12, 30, 0, 2], [30, 30, 30, 2]]:
		play.show_found(t[0], t[1], t[2], t[3])
		await process_frame
		await process_frame
		var font := play._counter.get_theme_font("font")
		var fs := play._counter.get_theme_font_size("font_size")
		var w := font.get_string_size(play._counter.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		check("compteur « %s » : tient en entier (%d px de police)" % [play._counter.text, fs], w <= PlayScreen.COUNTER_WIDTH + 0.5
				and _overflow(play).is_empty(), "%.0f" % w)
	play.show_found(3, 30)
	await process_frame
	check("compteur court : taille normale", play._counter.get_theme_font_size("font_size") == PlayScreen.COUNTER_FONT_SIZE)
	play.closed.emit()
	await create_timer(0.6).timeout

	# Le défi du jour, jusqu'à sa page de résultat.
	main._start_daily()
	await create_timer(0.7).timeout
	_check_screen("jeu, défi", play)
	for i in 5:
		for b in play._options:
			if b.text == play._correct_text:
				b.pressed.emit()
				break
		await create_timer(0.2).timeout
		play._next.pressed.emit()
		await create_timer(0.3).timeout
	await create_timer(1.6).timeout
	check("défi terminé : page de résultat", main._current == main._result)
	_check_screen("résultat du défi", main._result)
	main._result.back.emit()
	await create_timer(0.6).timeout
	_check_screen("couverture, défi fait (tampon du jour)", main._cover)
	check("couverture : le tampon du jour est sur la carte", main._cover._daily_stamp.visible)

	# Fiche complète (niveau 2 proposé).
	main._pending_complete = "Astronomie"
	main._pending_level = 1
	main._show_complete("cover")
	await create_timer(1.6).timeout
	_check_screen("fiche complète", main._complete)
	main._complete.back.emit()
	await create_timer(0.6).timeout

	main._cover.open_results.emit()
	await create_timer(0.8).timeout
	_check_screen("mes résultats", main._progress)
	main._progress.closed.emit()
	await create_timer(0.6).timeout
	main._cover.open_settings.emit()
	await create_timer(0.8).timeout
	_check_screen("réglages", main._settings_screen)
	main._settings_screen.open_credits.emit()
	await create_timer(0.8).timeout
	_check_screen("crédits", main._credits)

	DirAccess.remove_absolute(SAVE)
	print("--- ", "TOUT EST OK" if fails == 0 else "%d ÉCHEC(S)" % fails)
	quit(1 if fails > 0 else 0)
