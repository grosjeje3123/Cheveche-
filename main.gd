extends Control
## Point d'entrée : charge le pack et la progression, installe le fond de papier
## et fait passer d'un écran à l'autre (couverture, mes résultats, réglages, crédits, comment jouer, jeu, fin du défi).

## Les packs du jeu, dans l'ordre. Un nouveau pack s'ajoute ici (et ses disciplines dans ProgressScreen.DISCIPLINES).
const PACK_PATHS := ["res://data/packs/svt_01.json", "res://data/packs/astro_01.json", "res://data/packs/animaux_01.json",
		"res://data/packs/histoire_01.json", "res://data/packs/arts_01.json",
		"res://data/packs/geographie_01.json", "res://data/packs/litterature_01.json",
		"res://data/packs/nature_01.json", "res://data/packs/sciences_01.json", "res://data/packs/astro_02.json",
		"res://data/packs/animaux_02.json", "res://data/packs/histoire_02.json", "res://data/packs/arts_02.json",
		"res://data/packs/geographie_02.json", "res://data/packs/litterature_02.json",
		# Niveau 2 (dossiers pointus, ouverts une fois la fiche complète) : le champ « niveau » du pack le dit.
		"res://data/packs/astro_n2_01.json",
		# Dossiers en image (un par série de dix, en bonus) : ils reprennent les images des dossiers ci-dessus.
		"res://data/packs/visuels_01.json"]

## Où la progression est écrite. Les tests le changent avant d'ajouter le nœud à la scène.
var save_path := SaveStore.DEFAULT_PATH
## Où les réglages sont écrits (même remarque).
var settings_path := Settings.DEFAULT_PATH

var _pack: QuestionPack
var _save: SaveStore
var _settings: Settings
var _feedback: Feedback
var _settings_screen: SettingsScreen
var _credits: CreditsScreen
## L'écran d'où l'on a ouvert les crédits (réglages ou résultat).
var _credits_origin: Control
var _cover: CoverScreen
var _progress: ProgressScreen
var _play: PlayScreen
var _result: ResultScreen
var _complete: CompleteScreen
var _rules: RulesScreen
var _carnet: CarnetScreen
## La page « Comment jouer » s'est ouverte avant la première série (et non depuis les Réglages).
var _rules_before_play := false
## Fiche que la dernière réponse vient de compléter (page « Fiche complète » à montrer), sinon « »,
## et le niveau complété (1 ou 2).
var _pending_complete := ""
var _pending_level := 1
## La discipline de la dernière page « Fiche complète » (pour « Jouer le niveau 2 »).
var _complete_discipline := ""
## Après la page « Fiche complète » : reprendre le jeu (« play ») ou revenir à la couverture (« cover »).
var _complete_then := "play"
var _current: Control
## L'écran d'où l'on est venu pour jouer : la flèche retour y ramène.
var _play_origin: Control
## Discipline de la fiche en cours (« » = « Au hasard », tout le pack).
var _series_category := ""
## Dossiers déjà joués dans la fiche en cours (la file s'adapte après chaque réponse sans les reproposer).
var _session_played := {}
## Une fiche se joue par séries de SERIES_LENGTH dossiers, chacune fermée par son bilan.
const SERIES_LENGTH := 10
## Dossier en image : le sixième de chaque série de fiche, une fois joués au moins VISUAL_AFTER dossiers de la fiche
## (jamais au tout début d'une discipline).
const VISUAL_SLOT := 6
const VISUAL_AFTER := 10
## Les réponses de la série en cours ({id, correct, clues, points, pepite}) et le niveau au début de la série.
var _series_results: Array = []
var _series_mastery_before := {}
## « free » (une fiche de la couverture) ou « daily » (défi du jour), et la date du défi en cours.
var _series_kind := "free"
var _daily_key := ""


func _ready() -> void:
	# Portrait, quoi qu'ait écrit l'export dans l'application : la mise en page est faite pour 720 × 1280.
	# (Le réglage du projet, Affichage > Fenêtre > Handheld > Orientation, le demande déjà ; ceci le garantit au lancement.)
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
	theme = Ds.build_theme()
	add_child(Ds.paper_background())
	_pack = QuestionPack.load_files(PACK_PATHS)
	if _pack == null or _pack.questions.is_empty():
		push_error("Aucune question exploitable dans %s" % ", ".join(PACK_PATHS))
		return
	_save = SaveStore.new(save_path)
	_settings = Settings.new(settings_path)
	_feedback = Feedback.new(_settings)
	add_child(_feedback)

	_cover = CoverScreen.new()
	_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_cover)
	_cover.setup(_pack, _save)
	_cover.open_results.connect(func() -> void: _go(_progress))
	_cover.open_carnet.connect(func() -> void:
		_carnet.open()
		_go(_carnet))
	_cover.open_category.connect(func(category: String) -> void: _start_fiche(category, _cover))
	_cover.play_pressed.connect(func() -> void: _start_fiche("", _cover))
	_cover.daily_pressed.connect(_start_daily)
	_cover.open_settings.connect(func() -> void:
		_settings_screen.reopen()
		_go(_settings_screen))

	_settings_screen = SettingsScreen.new()
	_settings_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_screen.visible = false
	add_child(_settings_screen)
	_settings_screen.setup(_settings, _save)
	_settings_screen.closed.connect(_back_to_cover)
	_settings_screen.open_credits.connect(func() -> void: _open_credits(_settings_screen))
	_settings_screen.open_rules.connect(func() -> void: _open_rules(false))
	_settings_screen.progress_reset.connect(func() -> void:
		_cover.refresh()
		_progress.refresh())

	_credits = CreditsScreen.new()
	_credits.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_credits.visible = false
	add_child(_credits)
	_credits.setup(_pack)
	_credits.closed.connect(func() -> void: _go(_credits_origin if _credits_origin != null else _cover))

	_progress = ProgressScreen.new()
	_progress.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_progress.visible = false
	add_child(_progress)
	_progress.setup(_pack, _save)
	_progress.closed.connect(_back_to_cover)

	_play = PlayScreen.new()
	_play.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_play.visible = false
	add_child(_play)
	_play.build()
	_play.closed.connect(_on_play_closed)
	_play.answered.connect(_on_answered)
	_play.finished.connect(_on_series_finished)
	_play.held.connect(func() -> void: _show_complete("play"))

	_result = ResultScreen.new()
	_result.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result.visible = false
	add_child(_result)
	_result.back.connect(_leave_play)
	_result.next_pressed.connect(_next_series)
	_play.series_done.connect(func() -> void: _show_series_result(false))
	_play.visual_intro_seen.connect(func() -> void: _settings.set_visual_seen(true))
	_result.open_credits.connect(func() -> void: _open_credits(_result))

	_complete = CompleteScreen.new()
	_complete.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_complete.visible = false
	add_child(_complete)
	_complete.continue_pressed.connect(_after_complete)
	_complete.back.connect(_leave_play)
	_complete.play_next_level.connect(func() -> void: _start_fiche(_complete_discipline, _cover))

	_carnet = CarnetScreen.new()
	_carnet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_carnet.visible = false
	add_child(_carnet)
	_carnet.setup(_pack, _save)
	_carnet.closed.connect(_back_to_cover)

	_rules = RulesScreen.new()
	_rules.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rules.visible = false
	add_child(_rules)
	_rules.build()
	_rules.start_pressed.connect(func() -> void:
		_settings.set_rules_seen(true)
		_go(_play))
	_rules.closed.connect(_close_rules)

	_current = _cover
	# Laisser libre le haut de l'écran (caméra, encoche) : tous les écrans descendent d'autant.
	# Android ne connaît la caméra qu'une fois la fenêtre affichée : on recalcule aussi un peu après.
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)
	get_tree().create_timer(0.3).timeout.connect(_apply_safe_area)
	_cover.play_intro(true)


func _apply_safe_area() -> void:
	var insets := SafeArea.insets(get_viewport())
	for screen: Control in [_cover, _settings_screen, _credits, _progress, _play, _result, _complete, _rules, _carnet]:
		screen.offset_top = insets.x
		screen.offset_bottom = -insets.y


# Une fiche (une discipline, ou « Au hasard » pour tout le pack) se joue en continu : tous ses dossiers à la file,
# ceux qu'on n'a pas encore trouvés d'abord (dans le désordre). Pas de fin de série : on s'arrête quand on veut,
# chaque réponse est déjà enregistrée. Au bout de la file, retour à la couverture.
func _start_fiche(category: String, origin: Control) -> void:
	var pool := _fiche_pool(category)
	if pool.is_empty():
		return
	var queue := _save.draw(pool, pool.size(), "", Mastery.start_level(_mastery_of(category)))
	if queue.is_empty():
		# Tout ce qui reste revient plus tard (et rien n'est encore acquis) : on le dit, sans ouvrir le jeu.
		var waiting := _save.waiting_in(pool)
		var name := category if category != "" else "Au hasard"
		_cover.show_note("%s : %s %s." % [name, _waiting_words(waiting), _save.return_words(pool)])
		return
	_series_category = category
	_series_kind = "free"
	_session_played = {}
	_series_results = []
	_series_mastery_before = _mastery_of(category) if category != "" else {}
	_play.explain_visual = not _settings.visual_seen
	_play.start(_pack, queue, [], true)
	# Où commence la révision (dossiers acquis), pour dire quand les autres reviendront.
	var revision := -1
	for i in queue.size():
		if _save.is_acquired(queue[i]["id"]):
			revision = i
			break
	_play.revision_from = revision
	_show_found()
	_play.refresh_notice()
	_play_origin = origin
	_enter_play()


# Le niveau du joueur sur une fiche : la discipline entière (niveaux 1 et 2) ; « Au hasard » : tout le jeu de base.
func _mastery_of(category: String) -> Dictionary:
	var qs: Array = _pack.questions if category == "" else _pack.questions_in(category) + _pack.questions_in(category, 2)
	return Mastery.rating(_save, qs)


# Après chaque réponse d'une fiche : la suite de la file est retirée selon le niveau du moment (les dossiers déjà
# joués dans la partie restent de côté).
func _adapt_queue() -> void:
	var pool := _fiche_pool(_series_category)
	var rest := _save.draw(pool, pool.size(), "", Mastery.start_level(_mastery_of(_series_category)), _session_played)
	var revision := -1
	for i in rest.size():
		if _save.is_acquired(rest[i]["id"]):
			revision = i
			break
	var shown := _visual_for_series(rest)
	if not shown.is_empty():
		rest.insert(0, shown)
		if revision >= 0:
			revision += 1
	_play.set_upcoming(rest, revision)
	# Bout de la file : ce qui n'est pas encore acquis reviendra à sa date.
	var waiting := _save.waiting_in(pool)
	if rest.is_empty() and waiting > 0:
		_play.add_note("La suite %s : %s." % [_save.return_words(pool), _waiting_words(waiting)])


# Le dossier en image à glisser juste après le dossier qu'on vient de jouer, ou {} : seulement dans une fiche,
# comme sixième dossier de la série, une fois joués VISUAL_AFTER dossiers de la fiche, un seul par série. On prend
# d'abord un dossier en image jamais vu, sinon un qui est de retour ; jamais un dont l'image vient d'un dossier
# de la série en cours ou qui arrive juste après.
func _visual_for_series(rest: Array) -> Dictionary:
	if _series_kind != "free" or rest.is_empty() or _series_results.size() != VISUAL_SLOT - 1:
		return {}
	if _series_results.any(func(r): return bool(r.get("visual", false))):
		return {}
	if _save.played_in(_fiche_pool(_series_category)).size() < VISUAL_AFTER:
		return {}
	# Les dossiers de la série en cours et les quatre suivants : leur image ne doit pas revenir tout de suite.
	var near := {}
	for q in _series_results + rest.slice(0, 4):
		near[q["id"]] = true
	var ok: Array = []
	for v in _pack.visuals_in(_series_category):
		if not _session_played.has(v["id"]) and not near.has(v["_source"]):
			ok.append(v)
	var fresh := ok.filter(func(v): return _save.plays(v["id"]) == 0)
	var back := ok.filter(func(v): return _save.plays(v["id"]) > 0 and _save.is_due(v["id"]) and not _save.is_acquired(v["id"]))
	var pick: Array = fresh if not fresh.is_empty() else back
	return {} if pick.is_empty() else pick.pick_random()


# Une ligne sous l'explication quand le niveau d'une discipline s'annonce ou monte (jamais quand il baisse).
static func _level_note(discipline: String, before: Dictionary, after: Dictionary) -> String:
	if discipline == "" or not Mastery.known(after):
		return ""
	var name := Mastery.name_of(after["r"])
	if not Mastery.known(before):
		return "%s : votre niveau est %s." % [discipline, name]
	if Mastery.rank_of(after["r"]) > Mastery.rank_of(before["r"]):
		return "%s : vous passez %s." % [discipline, name]
	return ""


# « 1 dossier à revoir », « 4 dossiers à revoir ».
static func _waiting_words(n: int) -> String:
	return "%d dossier%s à revoir" % [n, "s" if n > 1 else ""]


# Une fiche complète s'agrandit de son niveau 2 (s'il existe) : ses dossiers viennent alors en tête, puisqu'ils
# ne sont pas encore trouvés. « Au hasard » reste sur le jeu de base.
func _fiche_pool(category: String) -> Array:
	if category == "":
		return _pack.questions
	var pool := _pack.questions_in(category)
	if _level2_open(category):
		pool = pool + _pack.questions_in(category, 2)
	return pool


## Le niveau 2 d'une discipline est ouvert quand il existe et que sa fiche de base est complète.
func _level2_open(discipline: String) -> bool:
	var base := _pack.questions_in(discipline)
	return not base.is_empty() and not _pack.questions_in(discipline, 2).is_empty() and _save.collected_in(base) == base.size()


# En haut de l'écran de jeu : les dossiers trouvés dans la fiche en cours (puis, fiche complète, ceux trouvés sans indice) ;
# niveau 2 ouvert : les chiffres du niveau 2.
func _show_found() -> void:
	_play.waiting = _save.waiting_in(_fiche_pool(_series_category))
	_play.return_words = _save.return_words(_fiche_pool(_series_category))
	if _series_category != "" and _level2_open(_series_category):
		var expert := _pack.questions_in(_series_category, 2)
		_play.show_found(_save.collected_in(expert), expert.size(), _save.flawless_in(expert), 2)
		return
	var pool := _pack.questions if _series_category == "" else _pack.questions_in(_series_category)
	_play.show_found(_save.collected_in(pool), pool.size(), _save.flawless_in(pool))


# Le défi du jour : les mêmes dossiers pour tous, une fois par jour ; on reprend là où on s'était arrêté.
func _start_daily() -> void:
	_daily_key = Week.today_key()
	var state := _save.daily_state(_daily_key)
	if state["done"]:  # déjà fait aujourd'hui : on revoit le résultat (et on peut le copier), sans le rejouer
		_play_origin = _cover
		_show_daily_result(state["results"], true)
		return
	var challenge := Daily.challenge(_pack, _daily_key)
	# Les dossiers déjà joués d'abord (dans l'ordre joué), puis les autres.
	var done_ids := {}
	for r in state["results"]:
		done_ids[r["id"]] = true
	var ordered: Array = []
	for r in state["results"]:
		var q := _pack.by_id(r["id"])
		if not q.is_empty():
			ordered.append(q)
	for q in challenge:
		if not done_ids.has(q["id"]):
			ordered.append(q)
	# Si le tirage a changé depuis le début du défi (mise à jour du jeu dans la journée), on garde 5 dossiers.
	ordered = ordered.slice(0, Daily.CHALLENGE_LENGTH)
	_series_kind = "daily"
	_series_category = ""
	_play_origin = _cover
	if state["results"].size() >= ordered.size():  # tout est répondu mais le défi n'a pas été clos
		_on_series_finished(state["results"])
		return
	_play.start(_pack, ordered, state["results"])
	_enter_play()


# La progression est écrite à chaque réponse : on peut quitter le jeu à tout moment.
# Si cette réponse complète la fiche de sa discipline (30 dossiers trouvés, ou 30 sans indice), la page
# « Fiche complète » viendra au lieu du dossier suivant (ou en quittant le jeu).
func _on_answered(question_id: String, correct: bool, clues: int, points: int) -> void:
	var q := _pack.by_id(question_id)
	var discipline := _pack.collection_of(q)
	var level := QuestionPack.level_of(q)
	var pool := _pack.questions_in(discipline, level)
	var found_before := _save.collected_in(pool)
	var flawless_before := _save.flawless_in(pool)
	var mastery_before := _mastery_of(discipline) if discipline != "" else {}
	var first_time := _save.plays(question_id) == 0
	_save.record_answer(question_id, correct, points)
	# Un dossier difficile trouvé sans indice dès la première rencontre : une pépite.
	var visual := QuestionPack.is_visual(q)
	var pepite := not visual and is_pepite(q, first_time, correct, points)
	if pepite:
		_play.show_pepite()
	if discipline != "":
		_play.add_note(_level_note(discipline, mastery_before, _mastery_of(discipline)))
	var total := pool.size()
	if total > 0 and _save.collected_in(pool) == total and (found_before < total
			or _save.flawless_in(pool) == total and flawless_before < total):
		_pending_complete = discipline
		_pending_level = level
		_play.hold_next = true
	if _series_kind == "daily":
		_save.record_daily_answer(_daily_key, {"id": question_id, "correct": correct, "clues": clues, "points": points})
	else:
		_session_played[question_id] = true
		var entry := {"id": question_id, "correct": correct, "clues": clues, "points": points, "pepite": pepite}
		if visual:
			entry["visual"] = true
			entry["revealed"] = _play.revealed
		_series_results.append(entry)
		_adapt_queue()
		_show_found()
		# Dix dossiers, ou le bout de la file : le bouton mène au bilan.
		if _series_results.size() >= SERIES_LENGTH or not _play.has_next():
			_play.end_series_here()
	_cover.refresh()
	_progress.refresh()


## Pépite : difficulté 4 ou plus, trouvé sans indice, la toute première fois qu'on le rencontre.
static func is_pepite(q: Dictionary, first_time: bool, correct: bool, points: int) -> bool:
	return first_time and correct and points >= Scoring.MAX_POINTS and QuestionPack.difficulty_of(q) >= PlayScreen.HARD


# Le bilan d'une série de fiche. `ended` : la file est au bout (plus de « Série suivante »).
func _show_series_result(ended: bool) -> void:
	var results := _series_results.duplicate(true)
	var found := Scoring.correct_count(results)
	var pepites := results.filter(func(r): return bool(r.get("pepite", false))).size()
	var summary := "%d dossier%s trouvé%s sur %d" % [found, "s" if found > 1 else "", "s" if found > 1 else "", results.size()]
	if pepites > 0:
		summary += ", dont %d pépite%s" % [pepites, "s" if pepites > 1 else ""]
	_save.record_series(results.size(), Scoring.total(results))
	var waiting := _save.waiting_in(_fiche_pool(_series_category))
	var more := not ended and _play.has_next()
	var note := _series_level_line(_series_category, _series_mastery_before, _mastery_of(_series_category)) if _series_category != "" else ""
	if not more and waiting > 0:
		note += ("\n" if note != "" else "") + "La suite %s : %s." % [_save.return_words(_fiche_pool(_series_category)), _waiting_words(waiting)]
	_result.show_results(_pack, results, {
		"kicker": "Série terminée",
		"label": _series_category if _series_category != "" else "Au hasard",
		"back_text": "Retour à la couverture",
		"next_text": "Série suivante" if more else "",
		"note": note,
		"summary": summary + ".",
		"celebrate": true,
	})
	_cover.refresh()
	_progress.refresh()
	_go(_result)


# Le niveau à la fin d'une série : « Astronomie : vous passez Érudit ! », ou « Astronomie : niveau Curieux. »
static func _series_level_line(discipline: String, before: Dictionary, after: Dictionary) -> String:
	if not Mastery.known(after):
		var left: int = Mastery.MIN_ANSWERS - int(after.get("n", 0))
		return "%s : votre niveau sera connu dans %d dossier%s." % [discipline, left, "s" if left > 1 else ""]
	var name := Mastery.name_of(after["r"])
	if Mastery.known(before) and Mastery.rank_of(after["r"]) > Mastery.rank_of(before["r"]):
		return "%s : vous passez %s !" % [discipline, name]
	if not Mastery.known(before):
		return "%s : votre niveau est %s." % [discipline, name]
	return "%s : niveau %s." % [discipline, name]


# « Série suivante » : la file reprend là où elle s'était arrêtée.
func _next_series() -> void:
	_series_results = []
	_series_mastery_before = _mastery_of(_series_category) if _series_category != "" else {}
	_go(_play)
	_play.resume()


# Page « Fiche complète » : `then` dit où aller ensuite (« play » : reprendre le jeu ; « cover » : la couverture).
func _show_complete(then: String) -> void:
	var pool := _pack.questions_in(_pending_complete, _pending_level)
	var flawless := _save.flawless_in(pool)
	var expert := _pack.questions_in(_pending_complete, 2)
	_complete_then = then
	_complete_discipline = _pending_complete
	_complete.show_fiche({"discipline": _pending_complete, "total": pool.size(), "points": _save.best_total_in(pool),
			"flawless": flawless, "perfect": flawless == pool.size(), "level": _pending_level,
			# Le niveau 2 vient de s'ouvrir (ou reste à finir) : la page propose d'y aller tout de suite.
			"next_level": _pending_level == 1 and not expert.is_empty() and _save.collected_in(expert) < expert.size()})
	_pending_complete = ""
	_play.hold_next = false
	_go(_complete)


func _after_complete() -> void:
	if _complete_then == "play" and _play.series_end:
		_play.series_end = false
		_show_series_result(false)  # la fiche complète fermait aussi la série : son bilan, puis la suite
	elif _complete_then == "play":
		_go(_play)
		_play.resume()
	else:
		_leave_play()


# Flèche retour pendant le jeu : si une fiche vient d'être complétée, sa page d'abord.
func _on_play_closed() -> void:
	if _pending_complete != "":
		_show_complete("cover")
	else:
		_leave_play()


# Fin de la file : page de résultat pour le défi du jour ; pour une fiche, simple retour à la couverture.
func _on_series_finished(results: Array) -> void:
	if _series_kind == "daily":
		_finish_daily(results)
	elif not _series_results.is_empty():
		_show_series_result(true)  # la file est au bout avant dix dossiers : le bilan de ce qui a été joué
	else:
		_leave_play()


func _finish_daily(results: Array) -> void:
	_save.finish_daily(_daily_key)
	_save.record_series(results.size(), Scoring.total(results), "", SaveStore.BEST_DAILY)
	_cover.refresh()
	_progress.refresh()
	_show_daily_result(results, false)


# La page de fin du défi. `again` : revue plus tard dans la journée (tampon déjà posé, pas de jingle).
func _show_daily_result(results: Array, again: bool) -> void:
	var streak := _save.daily_streak(_daily_key)
	var date := Week.from_key(_daily_key)
	_result.show_results(_pack, results, {
		"kicker": "Défi du jour",
		"label": Daily.date_label(date),
		"back_text": "Retour à la couverture",
		"note": "%d jour%s de suite. Prochain défi demain." % [streak, "" if streak == 1 else "s"],
		"stamp": _daily_stamp(_daily_key),
		"share": Daily.share_text(date, results),
		"quiet": again,
		"celebrate": true,
	})
	_go(_result)


# Le tampon dateur du défi : « Défi du jour » en arc, le jour et le mois au centre, l'année en bas.
func _daily_stamp(key: String) -> Dictionary:
	var d := Week.from_key(key)
	return {"top": "Défi du jour", "day": str(d["day"]), "month": Week.MONTHS_SHORT[int(d["month"]) - 1],
			"bottom": str(d["year"])}


func _open_credits(origin: Control) -> void:
	_credits_origin = origin
	_credits.rebuild()
	_go(_credits)


# Le jeu est prêt : on y entre, sauf la toute première fois, où « Comment jouer » passe avant.
func _enter_play() -> void:
	if _settings.rules_seen:
		_go(_play)
	else:
		_open_rules(true)


func _open_rules(before_play: bool) -> void:
	_rules_before_play = before_play
	_rules.open(before_play)
	_go(_rules)


# Flèche retour de « Comment jouer » : vers les Réglages, ou, avant la première série, vers d'où l'on venait
# (la page reviendra au prochain lancement d'une série, puisqu'on ne l'a pas validée).
func _close_rules() -> void:
	if _rules_before_play:
		_leave_play()
	else:
		_go(_settings_screen)


# Fondu enchaîné discret entre deux écrans.
func _go(target: Control) -> void:
	if target == _current:
		return
	var from := _current
	_current = target
	target.modulate.a = 0.0
	target.visible = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(from, "modulate:a", 0.0, 0.18)
	tw.tween_property(target, "modulate:a", 1.0, 0.28).set_delay(0.12)
	tw.finished.connect(func() -> void:
		if from != _current:
			from.visible = false)


# Échap (ordinateur) ou bouton Retour (Android) : on remonte d'un écran.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _current == _play:
		_on_play_closed()
	elif _current == _result or _current == _complete:
		_leave_play()
	elif _current == _progress or _current == _settings_screen:
		_back_to_cover()
	elif _current == _credits:
		_go(_credits_origin if _credits_origin != null else _cover)
	elif _current == _rules:
		_close_rules()
	elif _current == _carnet:
		_carnet.back()
	get_viewport().set_input_as_handled()


# Retour de « Mes résultats » à la couverture.
func _back_to_cover() -> void:
	_go(_cover)
	_cover.play_intro()


func _leave_play() -> void:
	_go(_play_origin if _play_origin != null else _cover)
	if _play_origin == _cover:
		_cover.play_intro()
