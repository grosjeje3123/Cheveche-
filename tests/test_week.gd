extends SceneTree
## Calendrier de la semaine et historique par jour dans la sauvegarde.

var fails := 0
const SAVE := "user://test_week_progress.json"

func check(label: String, ok: bool, extra := "") -> void:
	print(("OK   " if ok else "FAIL ") + label + ("  " + extra if extra != "" else ""))
	if not ok:
		fails += 1

func _d(y: int, m: int, d: int) -> Dictionary:
	return {"year": y, "month": m, "day": d}

func _initialize() -> void:
	# ---------- Calendrier ----------
	check("clé de jour", Week.key(_d(2026, 11, 3)) == "2026-11-03")
	check("clé de jour : zéros de tête", Week.key(_d(2027, 1, 5)) == "2027-01-05")
	check("is_key : valide", Week.is_key("2026-11-03"))
	check("is_key : refuse le reste", not Week.is_key("2026-1-3") and not Week.is_key("hier") and not Week.is_key("2026-11-03x") and not Week.is_key(""))
	check("mardi 3 nov. 2026 = rang 1", Week.weekday_index(_d(2026, 11, 3)) == 1)
	check("lundi 2 nov. 2026 = rang 0", Week.weekday_index(_d(2026, 11, 2)) == 0)
	check("dimanche 8 nov. 2026 = rang 6", Week.weekday_index(_d(2026, 11, 8)) == 6)
	check("lundi de la semaine du 3 nov.", Week.key(Week.monday_of(_d(2026, 11, 3))) == "2026-11-02")
	check("lundi de la semaine du dimanche 8 nov.", Week.key(Week.monday_of(_d(2026, 11, 8))) == "2026-11-02")
	check("un lundi est son propre lundi", Week.key(Week.monday_of(_d(2026, 11, 2))) == "2026-11-02")
	check("semaine à cheval sur deux mois (mer. 28 oct.)", Week.key(Week.monday_of(_d(2026, 10, 28))) == "2026-10-26")
	check("semaine à cheval sur deux années (ven. 1er janv. 2027)", Week.key(Week.monday_of(_d(2027, 1, 1))) == "2026-12-28")
	check("29 février 2028 : mardi, lundi 28 février", Week.key(Week.monday_of(_d(2028, 2, 29))) == "2028-02-28")
	check("1er mars 2026 - 1 jour = 28 février (année non bissextile)", Week.key(Week.shifted(_d(2026, 3, 1), -1)) == "2026-02-28")
	check("1er mars 2028 - 1 jour = 29 février (bissextile)", Week.key(Week.shifted(_d(2028, 3, 1), -1)) == "2028-02-29")
	var keys: Array = []
	for d in Week.days_of(_d(2026, 11, 5)):
		keys.append(Week.key(d))
	check("les sept jours de la semaine du 5 nov.", keys == ["2026-11-02", "2026-11-03", "2026-11-04", "2026-11-05", "2026-11-06", "2026-11-07", "2026-11-08"], str(keys))
	check("intitulé : même mois", Week.range_label(_d(2026, 11, 3)) == "2 – 8 nov.", Week.range_label(_d(2026, 11, 3)))
	check("intitulé : deux mois", Week.range_label(_d(2026, 10, 28)) == "26 oct. – 1 nov.", Week.range_label(_d(2026, 10, 28)))
	check("intitulé : deux années", Week.range_label(_d(2027, 1, 1)) == "28 déc. – 3 janv.", Week.range_label(_d(2027, 1, 1)))
	check("intitulé : février bissextile", Week.range_label(_d(2028, 2, 29)) == "28 févr. – 5 mars", Week.range_label(_d(2028, 2, 29)))
	var wk := Week.shifted(_d(2026, 11, 3), -7)
	check("semaine précédente : lundi 26 oct.", Week.key(Week.monday_of(wk)) == "2026-10-26")

	# ---------- Historique ----------
	DirAccess.remove_absolute(SAVE)
	var s := SaveStore.new(SAVE)
	var empty := s.week_summary(_d(2026, 11, 4))
	check("semaine vide : rien de joué, pas de meilleur jour", empty["answers"] == 0 and empty["points"] == 0 and empty["days_played"] == 0 and empty["best_index"] == -1)
	check("semaine vide : sept fiches", empty["days"].size() == 7)

	# semaine du 2 au 8 nov. : lundi 2 réponses (100 + faux), mardi 1 réponse (75) ; semaine d'avant : mardi 3 réponses
	s.record_answer("q1", true, 100, "2026-11-02")
	s.record_answer("q2", false, 0, "2026-11-02")
	s.record_answer("q3", true, 75, "2026-11-03")
	s.record_series(3, 175, "2026-11-03")
	s.record_answer("q4", true, 100, "2026-10-27")
	s.record_answer("q5", true, 100, "2026-10-27")
	s.record_answer("q6", true, 50, "2026-10-27")
	var w := s.week_summary(_d(2026, 11, 4))
	check("lundi : 2 réponses, 1 trouvée, 100 points", w["days"][0] == {"answers": 2, "correct": 1, "points": 100, "series": 0}, str(w["days"][0]))
	check("mardi : 1 réponse, 75 points, 1 série", w["days"][1] == {"answers": 1, "correct": 1, "points": 75, "series": 1}, str(w["days"][1]))
	check("mercredi : rien", w["days"][2]["answers"] == 0)
	check("totaux de la semaine : 3 réponses, 2 trouvées, 175 points, 1 série", w["answers"] == 3 and w["correct"] == 2 and w["points"] == 175 and w["series"] == 1, str(w))
	check("2 jours joués", w["days_played"] == 2)
	check("meilleur jour : lundi (100 > 75)", w["best_index"] == 0, str(w["best_index"]))
	var before := s.week_summary(Week.shifted(_d(2026, 11, 4), -7))
	check("semaine d'avant : 250 points, 3 réponses, 1 jour joué", before["points"] == 250 and before["answers"] == 3 and before["days_played"] == 1, str(before))
	check("n'importe quel jour de la semaine donne le même bilan", s.week_summary(_d(2026, 11, 8))["points"] == 175 and s.week_summary(_d(2026, 11, 2))["points"] == 175)
	check("la semaine suivante est vide", s.week_summary(_d(2026, 11, 9))["answers"] == 0)
	s.record_answer("q7", false, 0, "2026-11-04")
	check("jour joué à zéro point compté comme joué", s.week_summary(_d(2026, 11, 4))["days_played"] == 3)
	s.record_answer("q8", true, 100, "2026-11-05")
	check("égalité de points : le premier jour l'emporte", s.week_summary(_d(2026, 11, 4))["best_index"] == 0)
	s.record_answer("q9", true, 100, "2026-11-05")
	check("meilleur jour change quand un autre dépasse", s.week_summary(_d(2026, 11, 4))["best_index"] == 3, str(s.week_summary(_d(2026, 11, 4))["best_index"]))

	# sans date : aujourd'hui
	var today_before := s.day_stats(Week.today_key())
	s.record_answer("z", true, 100)
	var today_after := s.day_stats(Week.today_key())
	check("sans date, la réponse est comptée aujourd'hui",
			int(today_after["answers"]) == int(today_before["answers"]) + 1 and int(today_after["points"]) == int(today_before["points"]) + 100)

	# relecture
	var again := SaveStore.new(SAVE)
	check("relecture : mêmes jours", again.day_stats("2026-11-02") == s.day_stats("2026-11-02") and again.week_summary(_d(2026, 11, 4))["points"] == s.week_summary(_d(2026, 11, 4))["points"] + 0)
	check("relecture : la série du mardi est gardée", again.day_stats("2026-11-03")["series"] == 1)

	# élagage : 130 jours -> 120 gardés, les plus anciens partent
	var long := SaveStore.new("user://test_week_long.json")
	DirAccess.remove_absolute("user://test_week_long.json")
	long.load_from_disk()
	var day := _d(2026, 1, 1)
	for i in 130:
		long.record_answer("x", true, 100, Week.key(Week.shifted(day, i)))
	var reread := SaveStore.new("user://test_week_long.json")
	check("élagage : 120 jours gardés", int(reread.get("_days").size()) == SaveStore.KEEP_DAYS, str(reread.get("_days").size()))
	check("élagage : le plus ancien est parti, le plus récent reste",
			reread.day_stats(Week.key(Week.shifted(day, 0)))["answers"] == 0 and reread.day_stats(Week.key(Week.shifted(day, 129)))["answers"] == 1)
	check("élagage : le 11e jour (rang 10) est le premier gardé", reread.day_stats(Week.key(Week.shifted(day, 10)))["answers"] == 1 and reread.day_stats(Week.key(Week.shifted(day, 9)))["answers"] == 0)
	DirAccess.remove_absolute("user://test_week_long.json")

	# ancienne sauvegarde (version 1, sans historique) : lue sans problème
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string('{"version": 1, "dossiers": {"a": {"best": 100, "plays": 2, "wins": 1}}, "best_series": {"5": 300}, "series_played": 2}')
	f.close()
	var old := SaveStore.new(SAVE)
	check("ancienne sauvegarde : dossiers et séries conservés", old.is_collected("a") and old.best_series(5) == 300 and old.series_played() == 2)
	check("ancienne sauvegarde : historique vide", old.week_summary(_d(2026, 11, 4))["answers"] == 0)
	old.record_answer("b", true, 50, "2026-11-04")
	check("ancienne sauvegarde : on peut continuer d'y écrire", SaveStore.new(SAVE).day_stats("2026-11-04")["points"] == 50)

	# historique abîmé : assaini
	var bad := FileAccess.open(SAVE, FileAccess.WRITE)
	bad.store_string('{"dossiers": {}, "days": {"x": {"answers": 3}, "2026-11-03": {"answers": -5, "points": "abc", "correct": 2}, "2026-11-04": 7, "2026-11-05": {"answers": 2, "points": 40}}}')
	bad.close()
	var odd := SaveStore.new(SAVE)
	check("historique abîmé : clé invalide ignorée", odd.day_stats("x")["answers"] == 0)
	check("historique abîmé : valeurs négatives ou illisibles ramenées à zéro", odd.day_stats("2026-11-03") == {"answers": 0, "correct": 2, "points": 0, "series": 0}, str(odd.day_stats("2026-11-03")))
	check("historique abîmé : entrée qui n'est pas une fiche ignorée", odd.day_stats("2026-11-04")["answers"] == 0)
	check("historique abîmé : fiche correcte gardée", odd.day_stats("2026-11-05")["points"] == 40)

	# remise à zéro
	odd.reset()
	check("remise à zéro : l'historique aussi", SaveStore.new(SAVE).week_summary(_d(2026, 11, 4))["answers"] == 0)

	DirAccess.remove_absolute(SAVE)
	print("--- ", "TOUT EST OK" if fails == 0 else "%d ÉCHEC(S)" % fails)
	quit(1 if fails > 0 else 0)
