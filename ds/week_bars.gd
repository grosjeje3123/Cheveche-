class_name DsWeekBars
extends Control
## Les sept jours de la semaine, du lundi au dimanche : une colonne de points par jour.
## Le jour courant est en anthracite, les autres en sauge ; un jour joué sans point reste un simple trait,
## un jour sans partie ne montre que la ligne de base. Un chiffre surmonte chaque colonne.

const HEIGHT := 176
const LABEL_ROW := 36
const NUMBER_ROW := 28
const BAR_WIDTH := 34.0

## Points par jour (7 valeurs), nombre de réponses par jour (7 valeurs), et rang du jour courant (-1 si la
## semaine affichée n'est pas la semaine en cours).
var points: Array = []
var answers: Array = []
var today_index := -1
## Les points qui remplissent une colonne entière : une série parfaite de cinq dossiers. Si un jour fait mieux,
## c'est lui qui devient la référence (aucune colonne n'est écrêtée).
var full_scale := 500


func _init() -> void:
	custom_minimum_size = Vector2(0, HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_week(new_points: Array, new_answers: Array, new_today_index: int) -> void:
	points = new_points
	answers = new_answers
	today_index = new_today_index
	queue_redraw()


func _draw() -> void:
	if size.x <= 0.0:
		return
	var cell := size.x / 7.0
	var base_y := size.y - LABEL_ROW
	var room := base_y - NUMBER_ROW
	var ceiling := float(maxi(full_scale, int(points.max()) if not points.is_empty() else 0))
	for i in 7:
		var cx := cell * i + cell / 2.0
		var is_today := i == today_index
		var future := today_index >= 0 and i > today_index
		var pts: int = int(points[i]) if i < points.size() else 0
		var played: bool = (int(answers[i]) if i < answers.size() else 0) > 0

		# Ligne de base de la colonne.
		draw_line(Vector2(cx - cell * 0.4, base_y), Vector2(cx + cell * 0.4, base_y),
				Color(Ds.INK, 0.10 if future else 0.22), 1.0)

		if played:
			var h := 4.0 if pts <= 0 else maxf(6.0, room * clampf(float(pts) / ceiling, 0.0, 1.0))
			var color := Ds.INK if is_today else Ds.SAGE
			if pts <= 0:
				color = Ds.INK_FAINT
			draw_rect(Rect2(cx - BAR_WIDTH / 2.0, base_y - h, BAR_WIDTH, h), color)
			var number := str(pts)
			draw_string(Ds.SANS_MEDIUM, Vector2(cx - cell / 2.0, base_y - h - 8.0), number,
					HORIZONTAL_ALIGNMENT_CENTER, cell, 21, Ds.INK if is_today else Ds.INK_SOFT)

		var letter: String = Week.DAY_LETTERS[i]
		draw_string(Ds.SANS_SEMIBOLD if is_today else Ds.SANS, Vector2(cx - cell / 2.0, base_y + 27.0), letter,
				HORIZONTAL_ALIGNMENT_CENTER, cell, 22, Ds.INK if is_today else Ds.INK_SOFT)
		if is_today:
			draw_rect(Rect2(cx - 3.0, base_y + 31.0, 6.0, 3.0), Ds.TERRACOTTA)
