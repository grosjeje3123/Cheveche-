class_name PlayScreen
extends Control
## Écran de jeu : une carte d'archive centrale (question, image à gratter, deux indices), puis un QCM.
## On peut répondre tout de suite ; gratter est une aide : l'image se révèle au frottement et les indices
## se débloquent à 25 et 50 % gratté (RevealRules), au prix de points (Scoring).
##
## Deux façons de jouer :
## - en continu (une fiche de la couverture) : les dossiers s'enchaînent, on s'arrête quand on veut ;
##   en haut, les dossiers trouvés dans la fiche (show_found) ;
## - en série numérotée (le défi du jour) : « 3 sur 5 », puis la page de résultat.

signal closed
## Une réponse vient d'être donnée (pour sauvegarder la progression tout de suite).
signal answered(question_id: String, correct: bool, clues: int, points: int)
## Dernier dossier traité : `results` contient une entrée {id, correct, clues, points} par dossier.
signal finished(results: Array)
## Le dixième dossier d'une série de fiche est joué et « Voir le bilan » touché (voir end_series_here).
signal series_done
## Le joueur veut passer au dossier suivant alors que `hold_next` est vrai (une fiche vient d'être complétée) :
## l'écran attend ; resume() reprend là où on en était.
signal held
## L'explication du premier dossier en image vient d'être lue (« C'est parti ») : elle ne reviendra plus.
signal visual_intro_seen

const LETTERS := ["A", "B", "C", "D"]
## Hauteur de l'image : toujours comprise entre ces deux valeurs, quelle que soit la longueur de l'écran
## (sur un téléphone très allongé, la place en trop va aux réponses puis à l'air autour de la carte).
const ZONE_MIN := 260.0
const ZONE_MAX := 330.0
## Dossier en image : pas d'indices écrits sous l'image, elle prend leur place.
const VISUAL_ZONE_MIN := 320.0
const VISUAL_ZONE_MAX := 460.0
## Hauteur d'une ligne de réponse, mini et maxi.
const ROW_MIN := 72.0
const ROW_MAX := 96.0
## Respiration autour de la carte : minimum, et maximum quand l'écran est très haut.
const GAP_TOP_MIN := 16.0
const GAP_TOP_MAX := 72.0
const GAP_MID_MIN := 8.0
const GAP_MID_MAX := 64.0
## Après la réponse, l'explication peut gagner jusqu'à cette hauteur sur l'image (en plus de l'air libre en bas),
## qui garde au moins la hauteur ci-dessous.
const EXPLAIN_MAX_EXTRA := 120.0
const EXPLAIN_MIN_IMAGE_HEIGHT := 200.0
## Largeur du compteur en haut à droite, et de la flèche retour en face (le titre reste au centre).
## Avec le titre au milieu, la barre doit tenir dans 720 − 2 × Ds.MARGIN = 640 : au-delà, toute la colonne
## débordait à droite (la marge de droite disparaissait).
const COUNTER_WIDTH := 186.0
## Taille du compteur, réduite au besoin pour qu'un texte long (« 270 / 270 sans indice ») tienne dans sa largeur.
const COUNTER_FONT_SIZE := 24
const COUNTER_FONT_MIN := 16
var _pack: QuestionPack
var _questions: Array = []
var _index := 0
var _answered := false
var _correct_text := ""
var _clues_found := 0
var _q: Dictionary = {}
var _results: Array = []
## Jeu continu (fiche) plutôt que série numérotée (défi).
var _continuous := false
## Vrai : le prochain « Dossier suivant » émet `held` au lieu d'avancer (voir main.gd, page « Fiche complète »).
var hold_next := false
## Jeu continu : indice du premier dossier de révision (déjà trouvé sans indice), -1 s'il n'y en a pas ;
## et nombre de dossiers mis de côté jusqu'à demain dans la fiche (ratés ou trouvés avec un indice).
var revision_from := -1
## À partir de cette difficulté, un dossier est « difficile » : trouvé sans indice du premier coup, c'est une pépite.
const HARD := 4
const PEPITE_SIZE := 168.0
## Vrai quand le dossier à l'écran ferme une série de fiche (end_series_here).
var series_end := false
var _pepite: DsStamp
## Le dossier à l'écran est un dossier en image (pas d'indice écrit, les points suivent la part grattée).
var visual := false
## Part de l'image dévoilée à l'instant (dossier en image), puis au moment de répondre.
var revealed := 0.0
## Montrer l'explication du dossier en image au premier qui vient (main.gd le règle d'après les réglages).
var explain_visual := false
var _visual_intro: Control
var _gauge: RevealGauge
var waiting := 0
## Quand reviennent les dossiers mis de côté : « demain », « dans 3 jours »… (SaveStore.return_words).
var return_words := "demain"
## Une phrase qui prend la place de la consigne tant qu'on n'a rien gratté (début de la révision).
var _notice := ""

var _col: VBoxContainer
var _gap_top: Control
var _gap_mid: Control
var _flex: Control
var _segments: DsSegments
var _counter: Label
var _card: ArchiveCard
var _zone: ImageZone
var _clues: ClueList
var _hint: Label
var _hint_tween: Tween
var _feedback: Label
var _points: Label
var _options: Array[Button] = []
var _slot: Control
var _slot_tween: Tween
var _explain: ScrollContainer
var _explain_box: VBoxContainer
var _more: TextureRect
var _next: Button


func build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", Ds.MARGIN)
	margin.add_theme_constant_override("margin_right", Ds.MARGIN)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	margin.add_child(col)
	_col = col
	col.resized.connect(_fit_layout)

	# Barre supérieure : retour, titre, puis les dossiers trouvés (fiche) ou la position dans la série (défi).
	var top := HBoxContainer.new()
	top.custom_minimum_size = Vector2(0, 56)
	col.add_child(top)
	var back := Button.new()
	back.theme_type_variation = "FlatButton"
	# Même largeur que le compteur, à droite : le titre reste au centre de l'écran.
	back.custom_minimum_size = Vector2(COUNTER_WIDTH, 56)
	back.pressed.connect(func() -> void: closed.emit())
	var chev := DsIcon.new(DsIcon.Kind.CHEVRON_LEFT, Ds.INK, 40)
	chev.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	chev.offset_left = 0
	chev.offset_right = 40
	chev.offset_top = -20
	chev.offset_bottom = 20
	back.add_child(chev)
	top.add_child(back)
	var brand := HBoxContainer.new()
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand.alignment = BoxContainer.ALIGNMENT_CENTER
	brand.add_theme_constant_override("separation", Ds.S2)
	top.add_child(brand)
	brand.add_child(OwlMark.new(44))
	var title := Ds.label("CHEVÊCHE", Ds.Role.HEADING, Ds.INK)
	title.add_theme_font_override("font", Ds.spaced(Ds.SERIF_MEDIUM, 5))
	title.add_theme_font_size_override("font_size", 28)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	brand.add_child(title)
	_counter = Ds.label("", Ds.Role.OVERLINE, Ds.INK_SOFT)
	_counter.custom_minimum_size = Vector2(COUNTER_WIDTH, 0)
	_counter.clip_text = true  # sa largeur ne dépend jamais du texte : la barre ne peut pas s'élargir
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(_counter)

	col.add_child(Ds.spacer(Ds.S2))
	_segments = DsSegments.new()
	col.add_child(_segments)
	_gap_top = Ds.spacer(int(GAP_TOP_MIN))
	col.add_child(_gap_top)

	# Carte d'archive : question, image à gratter (hauteur réglée par _fit_layout), puis les deux indices.
	_card = ArchiveCard.new()
	col.add_child(_card)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", Ds.S3)
	_card.body.add_child(inner)
	_zone = ImageZone.new()
	_zone.size_flags_vertical = Control.SIZE_FILL  # ne s'étire pas : _fit_layout règle sa hauteur
	_zone.custom_minimum_size = Vector2(0, ZONE_MIN)
	_zone.resized.connect(_place_pepite)
	inner.add_child(_zone)
	_clues = ClueList.new()
	inner.add_child(_clues)
	_gauge = RevealGauge.new()
	_gauge.visible = false
	inner.add_child(_gauge)
	_zone.cover.progress_changed.connect(_on_progress)
	_zone.cover.scratch_started.connect(_on_scratch_started)
	# Le frottement s'entend pendant chaque geste de grattage.
	_zone.cover.gui_input.connect(func(e: InputEvent) -> void:
		var b := e as InputEventMouseButton
		if b and b.button_index == MOUSE_BUTTON_LEFT and b.pressed and not _answered:
			Feedback.scratch_start())
	_zone.cover.scratch_ended.connect(func() -> void: Feedback.scratch_stop())

	_hint = Ds.label("Grattez pour découvrir l’image", Ds.Role.NUMERAL, Color(Ds.IVORY, 0.92))
	_hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zone.add_child(_hint)

	# Consigne vivante, une ligne.
	_gap_mid = Ds.spacer(int(GAP_MID_MIN))
	col.add_child(_gap_mid)
	var feedback_row := HBoxContainer.new()
	feedback_row.custom_minimum_size = Vector2(0, 48)
	col.add_child(feedback_row)
	_feedback = Ds.fill_h(Ds.label("", Ds.Role.NUMERAL, Ds.INK_SOFT))
	_feedback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_feedback.clip_text = true
	feedback_row.add_child(_feedback)
	# Ce que vaut le dossier : baisse à mesure que les indices se dévoilent, puis points gagnés.
	_points = Ds.label("", Ds.Role.NUMERAL, Ds.INK_SOFT)
	_points.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_points.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	feedback_row.add_child(_points)

	# Réponses : lignes sur filets.
	col.add_child(Ds.rule(Ds.INK_STRONG, 1))
	for i in 4:
		var b := _make_option(LETTERS[i])
		col.add_child(b)
		_options.append(b)

	# Après la réponse, l'explication prend exactement la place des quatre lignes.
	_slot = Control.new()
	_slot.visible = false
	_slot.clip_contents = true
	col.add_child(_slot)
	_explain = ScrollContainer.new()
	_explain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_explain.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_explain.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER  # défile au doigt, sans barre grise
	_slot.add_child(_explain)
	_explain_box = VBoxContainer.new()
	_explain_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_explain_box.add_theme_constant_override("separation", Ds.S2)
	_explain.add_child(_explain_box)
	# Léger fondu en bas quand il reste du texte à lire en faisant défiler.
	var gradient := Gradient.new()
	gradient.set_color(0, Color(Ds.IVORY, 0.0))
	gradient.set_color(1, Ds.IVORY)
	var gt := GradientTexture2D.new()
	gt.gradient = gradient
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	_more = TextureRect.new()
	_more.texture = gt
	_more.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_more.stretch_mode = TextureRect.STRETCH_SCALE
	_more.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_more.anchor_left = 0.0
	_more.anchor_right = 1.0
	_more.anchor_top = 1.0
	_more.anchor_bottom = 1.0
	_more.offset_top = -56
	_more.visible = false
	_slot.add_child(_more)
	_explain.get_v_scroll_bar().value_changed.connect(func(_v: float) -> void: _update_more())

	# Ce que l'écran a de trop (téléphone très allongé) s'étale ici, au-dessus du bouton.
	_flex = Control.new()
	_flex.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_flex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_flex)
	col.add_child(Ds.spacer(Ds.S3))
	_next = Button.new()
	_next.theme_type_variation = "PrimaryButton"
	_next.custom_minimum_size = Vector2(0, 72)
	_next.pressed.connect(_on_next_pressed)
	col.add_child(_next)


func _make_option(letter: String) -> Button:
	var b := Button.new()
	b.theme_type_variation = "RowButton"
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.custom_minimum_size = Vector2(0, ROW_MIN)
	b.pressed.connect(_on_option_pressed.bind(b))
	var l := Ds.label(letter, Ds.Role.NUMERAL, Ds.TERRACOTTA)
	l.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	l.offset_left = 20
	l.offset_right = 60
	l.offset_top = -24
	l.offset_bottom = 24
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(l)
	b.set_meta("letter", l)
	return b


## `already` : résultats des premiers dossiers de `questions`, déjà joués (reprise du défi du jour).
## `continuous` : jeu continu d'une fiche ; l'appelant donne alors les dossiers trouvés avec show_found().
func start(pack: QuestionPack, questions: Array, already: Array = [], continuous := false) -> void:
	_pack = pack
	_questions = questions
	_results = already.duplicate(true)
	_continuous = continuous
	hold_next = false
	revision_from = -1
	waiting = 0
	_index = mini(_results.size(), questions.size() - 1)
	if not _continuous:
		_segments.fills = PackedFloat32Array()  # retour au mode « étapes »
	_show_question()


## Jeu continu : « 12 / 30 trouvés » en haut, et la barre fine remplie d'autant. Fiche complète :
## le second objectif prend la place, « 18 / 30 sans indice ». `level` 2 : les chiffres sont ceux du niveau 2
## (« 4 / 30 niveau 2 », puis « sans indice »).
func show_found(found: int, total: int, flawless := 0, level := 1) -> void:
	var complete := found >= total
	var shown := flawless if complete else found
	var found_text := "%d / %d niveau 2" if level >= 2 else "%d / %d trouvés"
	_set_counter(("%d / %d sans indice" if complete else found_text) % [shown, total])
	_segments.fills = PackedFloat32Array([float(shown) / float(maxi(total, 1))])


# Le texte du compteur, en plus petit s'il ne tient pas dans COUNTER_WIDTH (sans jamais le couper).
func _set_counter(text: String) -> void:
	_counter.text = text
	var font := _counter.get_theme_font("font")
	var size := COUNTER_FONT_SIZE
	while size > COUNTER_FONT_MIN and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > COUNTER_WIDTH:
		size -= 1
	_counter.add_theme_font_size_override("font_size", size)


func _show_question() -> void:
	_q = _questions[_index]
	_answered = false
	series_end = false
	if is_instance_valid(_visual_intro):
		_visual_intro.queue_free()
		_visual_intro = null
	if is_instance_valid(_pepite):
		_pepite.queue_free()
	_pepite = null
	_correct_text = _q["reponse_courte"]
	var choices := QuestionPack.choices_for(_q)

	if not _continuous:
		_set_counter("%d sur %d" % [_index + 1, _questions.size()])
		_segments.total = _questions.size()
		_segments.current = _index
	_notice = _revision_notice()
	visual = QuestionPack.is_visual(_q)
	revealed = 0.0
	if visual:
		_card.setup_visual(_q["question"], _pack.collection_of(_q), _pack.difficulty_level(_q))
	else:
		_card.setup(_pack.dossier_number(_q), _q["categorie"], _q["question"], _pack.collection_of(_q),
				_pack.difficulty_level(_q), QuestionPack.level_of(_q))
	_clues.visible = not visual
	_gauge.visible = visual
	_gauge.fraction = 0.0
	_hint.text = "Grattez le moins possible" if visual else "Grattez pour découvrir l’image"

	if _pack.has_verified_image(_q):
		_zone.show_photo(load(_pack.image_path(_q)))
	else:
		_zone.show_placeholder(_q["image"].get("recherche", ""))
	_clues.set_clues(_q["indices"])

	if _slot_tween:
		_slot_tween.kill()
	_slot.visible = false
	_slot.custom_minimum_size = Vector2.ZERO
	_more.visible = false
	for i in _options.size():
		var o := _options[i]
		o.visible = true
		o.text = choices[i]
		o.disabled = false
		o.remove_theme_stylebox_override("disabled")
		o.remove_theme_color_override("font_disabled_color")
		(o.get_meta("letter") as Label).add_theme_color_override("font_color", Ds.TERRACOTTA)

	_zone.cover.reset()  # émet progress_changed(0.0) : met à jour consigne, indices et réponses
	_set_next_visible(false)
	_start_hint_pulse()
	_animate_in()
	_fit_layout()
	if visual and explain_visual:
		_show_visual_intro()
	# Le texte de la question peut changer de hauteur une fois la mise en page refaite : on règle de nouveau.
	await get_tree().process_frame
	_fit_layout()


# Partage la hauteur libre de l'écran : l'image d'abord (au plus ZONE_MAX), puis les réponses (au plus ROW_MAX),
# puis de l'air autour de la carte ; le reste s'étale en bas. L'image ne devient jamais démesurée.
func _fit_layout() -> void:
	if _col == null or _col.size.y <= 0.0 or _slot.visible or _slot_tween != null and _slot_tween.is_running():
		return
	var zone_min := VISUAL_ZONE_MIN if visual else ZONE_MIN
	var zone_max := VISUAL_ZONE_MAX if visual else ZONE_MAX
	_zone.custom_minimum_size.y = zone_min
	for o in _options:
		o.custom_minimum_size.y = ROW_MIN
	_gap_top.custom_minimum_size.y = GAP_TOP_MIN
	_gap_mid.custom_minimum_size.y = GAP_MID_MIN
	var free := floorf(_col.size.y - _col.get_combined_minimum_size().y)
	if free <= 0.0:
		return
	var zone_extra := minf(floorf(free * 0.6), zone_max - zone_min)
	free -= zone_extra
	var row_extra := minf(floorf(free / _options.size()), ROW_MAX - ROW_MIN)
	free -= row_extra * _options.size()
	var top_extra := minf(floorf(free * 0.5), GAP_TOP_MAX - GAP_TOP_MIN)
	free -= top_extra
	var mid_extra := minf(floorf(free * 0.5), GAP_MID_MAX - GAP_MID_MIN)
	_zone.custom_minimum_size.y = zone_min + zone_extra
	for o in _options:
		o.custom_minimum_size.y = ROW_MIN + row_extra
	_gap_top.custom_minimum_size.y = GAP_TOP_MIN + top_extra
	_gap_mid.custom_minimum_size.y = GAP_MID_MIN + mid_extra


func _on_scratch_started() -> void:
	_hide_hint()


# La consigne « Grattez… » s'efface dès qu'on gratte, ou quand la réponse dévoile l'image.
func _hide_hint() -> void:
	if _hint_tween:
		_hint_tween.kill()
	_hint_tween = create_tween()
	_hint_tween.tween_property(_hint, "modulate:a", 0.0, 0.3)


func _on_progress(fraction: float) -> void:
	if _answered:
		return
	if visual:
		_on_visual_progress(fraction)
		return
	var before := _clues_found
	_clues_found = RevealRules.clues_unlocked(fraction)
	_clues.unlock(_clues_found)
	if fraction > 0.0:
		Feedback.scratch_ping()
	if _clues_found > before and fraction > 0.0:
		Feedback.say("clue")
	_show_points(Scoring.points_at(_clues_found), Ds.INK_SOFT)
	for o in _options:
		o.disabled = false  # on peut répondre à tout moment, sans rien gratter
	if _clues_found == 0 and _notice != "":
		_feedback.text = _notice
	elif _clues_found == 0:
		_feedback.text = "Répondez, ou grattez pour un indice."
	elif _clues_found < RevealRules.clue_count():
		_feedback.text = "Un indice de plus en grattant encore."
	else:
		_feedback.text = "Choisissez votre réponse."


# Dossier en image : la jauge suit la part dévoilée ; les points baissent à un tiers, puis aux deux tiers.
func _on_visual_progress(fraction: float) -> void:
	revealed = fraction
	var before := _clues_found
	_clues_found = RevealRules.visual_tier(fraction)
	_gauge.fraction = fraction
	if fraction > 0.0:
		Feedback.scratch_ping()
	if _clues_found > before and fraction > 0.0:
		Feedback.say("clue")
	_show_points(Scoring.points_at(_clues_found), Ds.INK_SOFT)
	for o in _options:
		o.disabled = false
	if fraction <= 0.0:
		_feedback.text = "Dossier en image : pas d’indice, l’image seule."
	else:
		_feedback.text = "Image dévoilée à %d %%." % percent(fraction)


## Une part dévoilée en pour cent, arrondie (jamais 0 % dès qu'on a gratté un peu).
static func percent(fraction: float) -> int:
	return 0 if fraction <= 0.0 else clampi(roundi(fraction * 100.0), 1, 100)


func _on_option_pressed(button: Button) -> void:
	if _answered:
		return
	_answered = true
	Feedback.scratch_stop()
	var correct := button.text == _correct_text
	Feedback.say("right" if correct else "wrong")
	var clues := _clues_found  # les indices lus avant de répondre : eux seuls font baisser les points
	var points := Scoring.points_for(correct, clues)
	for o in _options:
		o.disabled = true
		if o.text == _correct_text:
			_mark(o, Ds.SAGE)
	var hard := QuestionPack.difficulty_of(_q) >= HARD and not visual
	if correct and visual:
		_feedback.text = "Exact, sans rien gratter !" if revealed <= 0.0 else "Exact, avec %d %% de l’image dévoilée." % percent(revealed)
		_points.text = "+%d" % points
		_points.add_theme_color_override("font_color", Ds.SAGE)
	elif correct:
		if clues == 0:
			_feedback.text = "Exact, sans aucun indice."  # main.gd en fait une pépite (show_pepite) la première fois
		else:
			_feedback.text = "Exact, avec %d indice%s." % [clues, "s" if clues > 1 else ""]
		_points.text = "+%d" % points
		_points.add_theme_color_override("font_color", Ds.SAGE)
	else:
		_mark(button, Ds.TERRACOTTA)
		# Un dossier difficile manqué n'est pas un échec : on vient d'apprendre ce que peu de gens savent.
		_feedback.text = "Pas tout à fait. Peu de gens le savent." if hard else "Pas tout à fait."
		_points.text = "0"
		_points.add_theme_color_override("font_color", Ds.INK_FAINT)
	if not visual:
		_clues.unlock(RevealRules.clue_count())  # la réponse donnée, on lit les deux indices
	_hide_hint()
	_zone.cover.reveal_all()
	var last := _index >= _questions.size() - 1
	# (Bout de la file d'une fiche : « La suite demain : … », ajouté par main.gd une fois la réponse enregistrée.)
	_show_explanation(correct, button.text)
	if _continuous:
		_next.text = "Dossier suivant" if not last else "Retour à la couverture"
	else:
		_next.text = "Continuer" if not last else ("Voir le résultat" if _questions.size() > 1 else "Terminer")
	_set_next_visible(true)
	var result := {"id": _q["id"], "correct": correct, "clues": clues, "points": points}
	if visual:
		result["visual"] = true
		result["revealed"] = revealed
	_results.append(result)
	answered.emit(_q["id"], correct, clues, points)


## Remplace la suite de la file (après le dossier à l'écran) : la partie s'adapte au fil des réponses.
## `revision_at` : position, dans `rest`, du premier dossier de la révision (-1 : pas de révision).
func set_upcoming(rest: Array, revision_at := -1) -> void:
	_questions = _questions.slice(0, _index + 1) + rest
	revision_from = _index + 1 + revision_at if revision_at >= 0 else -1
	if _answered and _continuous and not series_end:
		_next.text = "Dossier suivant" if not rest.is_empty() else "Retour à la couverture"


## Ajoute une ligne sous l'explication du dossier qu'on vient de jouer (un nouveau niveau, par exemple).
func add_note(text: String) -> void:
	if text == "" or _explain_box.get_child_count() == 0:
		return
	var label := Ds.label(text, Ds.Role.SMALL, Ds.SAGE, true)
	_explain_box.add_child(label)
	_explain_box.move_child(label, _explain_box.get_child_count() - 2)  # avant l'air sous le dernier paragraphe
	var gap := Ds.spacer(Ds.S2)
	_explain_box.add_child(gap)
	_explain_box.move_child(gap, label.get_index())


# Ce que vaut le dossier à cet instant : « 100 », « 60 » puis « 30 » points.
func _show_points(value: int, color: Color) -> void:
	_points.text = "%d pts" % value
	_points.add_theme_color_override("font_color", color)


func _revision_notice() -> String:
	if _continuous and _index == revision_from and waiting > 0:
		return "Révision : %s %s." % [_waiting_phrase(waiting), return_words]
	return ""


## À appeler après avoir donné revision_from et waiting (juste après start) : le mot de révision s'affiche
## si le dossier à l'écran est le premier de la révision.
func refresh_notice() -> void:
	_notice = _revision_notice()
	if not _answered and _clues_found == 0:
		_feedback.text = _notice if _notice != "" else "Répondez, ou grattez pour un indice."


# « les 4 dossiers à revoir reviendront » ; sans verbe : « 4 dossiers à revoir ».
static func _waiting_phrase(n: int, with_verb := true) -> String:
	var many := n > 1
	if not with_verb:
		return "%d dossier%s à revoir" % [n, "s" if many else ""]
	return ("les %d dossiers à revoir reviendront" % n) if many else "le dossier à revoir reviendra"


# Les quatre réponses laissent la place à l'explication : la réponse, pourquoi, une anecdote, le crédit de l'image,
# et `note` (la suite demain, au bout d'une fiche).
func _show_explanation(correct: bool, chosen: String, note := "") -> void:
	for c in _explain_box.get_children():
		_explain_box.remove_child(c)
		c.queue_free()
	_explain_box.add_child(Ds.spacer(Ds.S1))
	_explain_box.add_child(Ds.label("La réponse", Ds.Role.OVERLINE, Ds.INK_SOFT))
	_explain_box.add_child(Ds.label(_correct_text, Ds.Role.HEADING, Ds.INK, true))
	if not correct:
		var mine := Ds.label("Votre choix : %s" % chosen, Ds.Role.SMALL, Ds.TERRACOTTA, true)
		_explain_box.add_child(mine)
	_explain_box.add_child(Ds.spacer(Ds.S1))
	var why := Ds.label(str(_q["explication"]), Ds.Role.BODY, Ds.INK, true)
	why.add_theme_font_size_override("font_size", 25)
	_explain_box.add_child(why)
	var anecdote := str(_q.get("anecdote", "")).strip_edges()
	if anecdote != "":
		_explain_box.add_child(Ds.spacer(Ds.S2))
		_explain_box.add_child(Ds.rule())
		_explain_box.add_child(Ds.spacer(Ds.S1))
		_explain_box.add_child(Ds.label("Le saviez-vous ?", Ds.Role.OVERLINE, Ds.INK_SOFT))
		var fun := Ds.label(anecdote, Ds.Role.NUMERAL, Ds.INK, true)
		fun.add_theme_font_size_override("font_size", 26)
		_explain_box.add_child(fun)
	var credit := _pack.credit_line(_q)
	if credit != "":
		_explain_box.add_child(Ds.spacer(Ds.S1))
		_explain_box.add_child(Ds.label(credit, Ds.Role.CAPTION, Ds.INK_SOFT, true))
	if note != "":
		_explain_box.add_child(Ds.spacer(Ds.S2))
		_explain_box.add_child(Ds.label(note, Ds.Role.SMALL, Ds.SAGE, true))
	_explain_box.add_child(Ds.spacer(Ds.S4))  # de l'air sous le dernier paragraphe

	# La zone prend la hauteur exacte des quatre réponses : la carte au-dessus ne bouge pas d'un pixel.
	var rows_height := 0.0
	for o in _options:
		rows_height += maxf(o.size.y, o.get_combined_minimum_size().y)
		o.visible = false
	_slot.custom_minimum_size = Vector2(0, rows_height)
	_slot.visible = true
	_explain.scroll_vertical = 0
	await get_tree().process_frame
	await get_tree().process_frame
	_update_more()
	# Texte plus long que la zone : l'explication prend d'abord l'air libre en bas, puis l'image cède un peu de hauteur
	# (jamais sous sa taille minimale), en douceur, pour lire davantage sans faire défiler.
	var wanted := _explain_box.get_combined_minimum_size().y - rows_height
	var free_below := maxf(_flex.size.y, 0.0)
	var zone_height := _zone.custom_minimum_size.y
	var from_image := clampf(minf(wanted - free_below, zone_height - EXPLAIN_MIN_IMAGE_HEIGHT), 0.0, EXPLAIN_MAX_EXTRA)
	var extra := clampf(minf(wanted, free_below + from_image), 0.0, free_below + EXPLAIN_MAX_EXTRA)
	if extra < 8.0:
		return
	from_image = maxf(extra - free_below, 0.0)
	_slot_tween = create_tween()
	_slot_tween.tween_method(func(t: float) -> void:
		_slot.custom_minimum_size.y = rows_height + extra * t
		_zone.custom_minimum_size.y = zone_height - from_image * t, 0.0, 1.0, 0.4) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_slot_tween.finished.connect(_update_more)


# Le fondu n'apparaît que s'il reste du texte plus bas.
func _update_more() -> void:
	var bar := _explain.get_v_scroll_bar()
	_more.visible = _slot.visible and bar.max_value > bar.page + 2.0 and bar.value < bar.max_value - bar.page - 2.0


# Réponse donnée : la ligne se remplit (sauge = juste, terre cuite = fausse).
func _mark(o: Button, color: Color) -> void:
	o.add_theme_stylebox_override("disabled", Ds.row_box(color))
	o.add_theme_color_override("font_disabled_color", Ds.IVORY)
	(o.get_meta("letter") as Label).add_theme_color_override("font_color", Ds.IVORY)


func _on_next_pressed() -> void:
	if hold_next:
		hold_next = false
		held.emit()
		return
	if series_end:
		series_end = false
		series_done.emit()
		return
	resume()


## Le dossier qu'on vient de jouer ferme la série : le bouton mène au bilan (series_done) au lieu du dossier suivant.
func end_series_here() -> void:
	series_end = true
	if _answered:
		_next.text = "Voir le bilan"


# Le tampon dans le coin haut droit de l'image (et il y reste si la carte change de taille).
func _place_pepite() -> void:
	if is_instance_valid(_pepite):
		_pepite.position = Vector2(_zone.size.x - PEPITE_SIZE - Ds.S2, Ds.S2)


## Un dossier difficile trouvé sans indice du premier coup : une pépite. Un tampon ocre se pose sur l'image,
## avec son « tchok », et le résultat du dossier le garde (le bilan de la série les compte).
func show_pepite() -> void:
	_feedback.text = "Exact, sans aucun indice. Une pépite !"
	if not _results.is_empty():
		_results.back()["pepite"] = true
	if is_instance_valid(_pepite):
		_pepite.queue_free()
	_pepite = DsStamp.new(PEPITE_SIZE)
	_pepite.color = Color("8C7440")  # l'ocre foncé du bilan : il se lit sur le papier clair
	_pepite.backing = Color(Ds.IVORY, 0.86)
	_pepite.top_text = "Pépite"
	_pepite.bottom_text = "peu le savent"
	_pepite.arc_text_scale = 0.2
	_pepite.discipline = _pack.collection_of(_q)
	_pepite.tilt = 0.2
	_pepite.size = Vector2(PEPITE_SIZE, PEPITE_SIZE)
	_zone.add_child(_pepite)
	_place_pepite()
	_pepite.modulate.a = 0.0
	_pepite.scale = Vector2(1.5, 1.5)
	var st := create_tween()
	st.tween_interval(0.25)
	st.tween_property(_pepite, "modulate:a", 1.0, 0.06)
	st.parallel().tween_property(_pepite, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	st.tween_callback(func() -> void: Feedback.say("stamp"))
	st.tween_property(_pepite, "scale", Vector2(0.96, 0.96), 0.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	st.tween_property(_pepite, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Vrai s'il reste un dossier après celui à l'écran.
func has_next() -> bool:
	return _index < _questions.size() - 1


## Passe au dossier suivant (ou termine la file).
func resume() -> void:
	if _index < _questions.size() - 1:
		_index += 1
		_show_question()
	else:
		finished.emit(_results.duplicate(true))


func _set_next_visible(on: bool) -> void:
	# Le bouton garde sa place : la mise en page ne bouge pas quand il apparaît.
	_next.disabled = not on
	_next.mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	create_tween().tween_property(_next, "modulate:a", 1.0 if on else 0.0, 0.3 if on else 0.0)


func _animate_in() -> void:
	var tw := create_tween().set_parallel(true)
	_card.modulate.a = 0.0
	tw.tween_property(_card, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE)
	for i in _options.size():
		_options[i].modulate.a = 0.0
		tw.tween_property(_options[i], "modulate:a", 1.0, 0.3).set_delay(0.12 + i * 0.05)


func _start_hint_pulse() -> void:
	if _hint_tween:
		_hint_tween.kill()
	_hint.modulate.a = 1.0
	_hint_tween = create_tween().set_loops()
	_hint_tween.tween_property(_hint, "modulate:a", 0.62, 1.2).set_trans(Tween.TRANS_SINE)
	_hint_tween.tween_property(_hint, "modulate:a", 1.0, 1.2).set_trans(Tween.TRANS_SINE)


# ---------- Le premier dossier en image : une explication, une seule fois ----------

func _show_visual_intro() -> void:
	if is_instance_valid(_visual_intro):
		_visual_intro.queue_free()
	var veil := ColorRect.new()
	veil.color = Color(Ds.INK, 0.55)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP  # on ne gratte pas pendant qu'on lit
	add_child(veil)
	_visual_intro = veil
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Ds.box(Ds.IVORY_CARD, Color(Ds.INK, 0.22), 1, 36, 36, 32, 30))
	card.custom_minimum_size = Vector2(minf(size.x - Ds.MARGIN * 2, 600.0), 0)
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", Ds.S3)
	card.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", Ds.S2)
	col.add_child(head)
	var ic := Ds.icon_rect(_pack.collection_of(_q), 30, Ds.OCHRE)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(ic)
	head.add_child(Ds.label("Dossier en image", Ds.Role.HEADING, Ds.INK))
	col.add_child(Ds.label("De temps en temps, un dossier n’a pas d’indice : seulement une image, cachée sous la couche. "
			+ "Grattez juste ce qu’il faut pour la reconnaître, puis répondez.", Ds.Role.BODY, Ds.INK, true))
	var demo := RevealGauge.new()
	demo.fraction = 0.2
	col.add_child(demo)
	col.add_child(Ds.label("Moins d’un tiers de l’image dévoilé : 100 points. Jusqu’aux deux tiers : 60. Au-delà : 30.",
			Ds.Role.SMALL, Ds.INK_SOFT, true))
	col.add_child(Ds.spacer(Ds.S1))
	var go := Button.new()
	go.theme_type_variation = "PrimaryButton"
	go.custom_minimum_size = Vector2(0, 72)
	go.text = "C’est parti"
	go.pressed.connect(close_visual_intro)
	col.add_child(go)
	veil.modulate.a = 0.0
	create_tween().tween_property(veil, "modulate:a", 1.0, 0.25)


## « C'est parti » : l'explication s'efface et ne reviendra plus.
func close_visual_intro() -> void:
	explain_visual = false
	if is_instance_valid(_visual_intro):
		var veil := _visual_intro
		_visual_intro = null
		var tw := create_tween()
		tw.tween_property(veil, "modulate:a", 0.0, 0.2)
		tw.tween_callback(veil.queue_free)
	visual_intro_seen.emit()


## Vrai tant que l'explication du dossier en image est à l'écran.
func visual_intro_open() -> bool:
	return is_instance_valid(_visual_intro)
