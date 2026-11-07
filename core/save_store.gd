class_name SaveStore
extends RefCounted
## Progression du joueur, gardée sur l'appareil (user://progress.json). Rien n'est envoyé nulle part.
## Une « connaissance collectée » est un dossier trouvé au moins une fois.
## Le fichier est écrit en entier à chaque réponse (quelques ko) : on peut quitter à tout moment.
## Si la sauvegarde est illisible, on repart de zéro (l'ancien fichier est mis de côté en .bad)
## et un échec d'écriture ne bloque jamais le jeu.
## Pour changer d'appareil sans compte ni serveur : export_code() donne un texte de quelques ko (la progression
## compressée), que le joueur copie et garde lui-même ; import_code() le relit et remplace la progression.

const VERSION := 3
const DEFAULT_PATH := "user://progress.json"
## Nombre de jours d'historique gardés (le bilan de la semaine n'en demande que 14).
const KEEP_DAYS := 120
## Défis du jour gardés (pour compter les jours de suite).
const KEEP_DAILY := 400
## Clé du meilleur défi du jour dans les records (les autres clés : nombre de dossiers de la série).
const BEST_DAILY := "defi"
## Début du code de sauvegarde : le reconnaître dans un texte collé, et changer de format un jour (CHEVECHE2-…).
const CODE_PREFIX := "CHEVECHE1-"
## Taille maximale acceptée une fois décompressé (une progression complète fait quelques dizaines de ko).
const CODE_MAX_BYTES := 4 * 1024 * 1024

var path: String

## id du dossier -> {"best": int, "plays": int, "wins": int, "revoir": "AAAA-MM-JJ" (facultatif)}
## « revoir » : un dossier raté, ou trouvé avec un indice, ne revient dans les fiches qu'à partir de ce jour-là
## (le lendemain de la réponse) : on ne le rejoue pas en ayant encore la réponse en tête.
var _dossiers := {}
## nombre de dossiers de la série (texte), ou BEST_DAILY -> meilleur total
var _best_series := {}
var _series_played := 0
## « AAAA-MM-JJ » -> {"answers": int, "correct": int, "points": int, "series": int}
var _days := {}
## Défi du jour : « AAAA-MM-JJ » -> {"results": [{id, correct, clues, points}], "done": bool, "points": int}
var _daily := {}


func _init(save_path := DEFAULT_PATH) -> void:
	path = save_path
	load_from_disk()


func load_from_disk() -> void:
	_clear()
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Sauvegarde illisible : %s" % path)
		return
	var json := JSON.new()
	var parsed := json.parse(file.get_as_text())
	file.close()
	var data = json.data if parsed == OK else null
	if not _is_valid(data):
		push_warning("Sauvegarde invalide, on repart de zéro : %s" % path)
		DirAccess.rename_absolute(path, path + ".bad")
		return
	_apply(data)


func _clear() -> void:
	_dossiers = {}
	_best_series = {}
	_series_played = 0
	_days = {}
	_daily = {}


static func _is_valid(data) -> bool:
	return data is Dictionary and data.get("dossiers", {}) is Dictionary


# Reprend une progression lue (fichier ou code), champ par champ, sans faire confiance aux valeurs.
func _apply(data: Dictionary) -> void:
	_clear()
	for id in data["dossiers"]:
		var d = data["dossiers"][id]
		if d is Dictionary:
			_dossiers[str(id)] = {
				"best": maxi(0, int(d.get("best", 0))),
				"plays": maxi(0, int(d.get("plays", 0))),
				"wins": maxi(0, int(d.get("wins", 0))),
			}
			if Week.is_key(str(d.get("revoir", ""))):
				_dossiers[str(id)]["revoir"] = str(d["revoir"])
	var best = data.get("best_series", {})
	if best is Dictionary:
		for k in best:
			_best_series[str(k)] = maxi(0, int(best[k]))
	_series_played = maxi(0, int(data.get("series_played", 0)))
	# Historique par jour (absent des sauvegardes de la version 1 : on l'ignore alors).
	var days = data.get("days", {})
	if days is Dictionary:
		for k in days:
			var d = days[k]
			if d is Dictionary and Week.is_key(str(k)):
				_days[str(k)] = {
					"answers": maxi(0, int(d.get("answers", 0))),
					"correct": maxi(0, int(d.get("correct", 0))),
					"points": maxi(0, int(d.get("points", 0))),
					"series": maxi(0, int(d.get("series", 0))),
				}
	# Défis du jour (absents avant la version 3).
	var daily = data.get("daily", {})
	if daily is Dictionary:
		for k in daily:
			var d = daily[k]
			if d is Dictionary and Week.is_key(str(k)) and d.get("results", []) is Array:
				var results: Array = []
				for r in d["results"]:
					if r is Dictionary and r.has("id"):
						results.append({"id": str(r["id"]), "correct": bool(r.get("correct", false)),
								"clues": int(r.get("clues", 0)), "points": maxi(0, int(r.get("points", 0)))})
				_daily[str(k)] = {"results": results, "done": bool(d.get("done", false)), "points": maxi(0, int(d.get("points", 0)))}


func _data() -> Dictionary:
	return {
		"version": VERSION,
		"dossiers": _dossiers,
		"best_series": _best_series,
		"series_played": _series_played,
		"days": _days,
		"daily": _daily,
	}


## Écrit la sauvegarde. Renvoie faux (sans planter) si le disque refuse.
func save() -> bool:
	_prune_days()
	var data := _data()
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		push_warning("Sauvegarde impossible (%s) : %s" % [path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	# Écriture dans un fichier temporaire puis renommage : une coupure ne laisse jamais un fichier tronqué.
	if DirAccess.rename_absolute(tmp, path) != OK:
		DirAccess.remove_absolute(path)
		if DirAccess.rename_absolute(tmp, path) != OK:
			push_warning("Sauvegarde impossible (renommage) : %s" % path)
			return false
	return true


# ---------- Écriture ----------

## `day` : « AAAA-MM-JJ » ; vide = aujourd'hui (le paramètre sert aux tests).
func record_answer(question_id: String, correct: bool, points: int, day := "") -> void:
	var s := _day(day if day != "" else Week.today_key())
	s["answers"] = int(s["answers"]) + 1
	if correct:
		s["correct"] = int(s["correct"]) + 1
	s["points"] = int(s["points"]) + points
	var d: Dictionary = _dossiers.get(question_id, {"best": 0, "plays": 0, "wins": 0})
	d["plays"] = int(d["plays"]) + 1
	if correct:
		d["wins"] = int(d["wins"]) + 1
	d["best"] = maxi(int(d["best"]), points)
	# Raté ou trouvé avec un indice : à revoir, mais pas avant demain. Trouvé sans indice : plus rien à revoir.
	if correct and points >= Scoring.MAX_POINTS:
		d.erase("revoir")
	else:
		d["revoir"] = Week.key(Week.shifted(Week.from_key(day if day != "" else Week.today_key()), 1))
	_dossiers[question_id] = d
	save()


## Une série de `count` dossiers terminée avec `total` points. `kind` (par ex. BEST_DAILY) range le record
## à part, au lieu du nombre de dossiers.
func record_series(count: int, total: int, day := "", kind := "") -> void:
	_series_played += 1
	var s := _day(day if day != "" else Week.today_key())
	s["series"] = int(s["series"]) + 1
	var key := kind if kind != "" else str(count)
	_best_series[key] = maxi(int(_best_series.get(key, 0)), total)
	save()


func reset() -> void:
	_clear()
	save()


# ---------- Code de sauvegarde ----------

## Toute la progression en un texte : « CHEVECHE1- » puis le JSON compressé (gzip, qui porte sa somme de
## contrôle) en base 64. Rien n'est envoyé : le joueur copie ce texte et le garde où il veut.
func export_code() -> String:
	_prune_days()
	var raw := JSON.stringify(_data()).to_utf8_buffer()
	return CODE_PREFIX + Marshalls.raw_to_base64(raw.compress(FileAccess.COMPRESSION_GZIP))


## La progression contenue dans un texte collé (qui peut entourer le code d'autres mots ou le couper de retours
## à la ligne), ou {} si le texte n'en contient pas de valide.
static func decode_code(text: String) -> Dictionary:
	var at := text.find(CODE_PREFIX)
	if at < 0:
		return {}
	var b64 := ""
	for c in text.substr(at + CODE_PREFIX.length()):
		if c in " \t\r\n":
			continue
		if not ((c >= "A" and c <= "Z") or (c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c in "+/="):
			break
		b64 += c
	if b64.length() < 8 or b64.length() % 4 != 0:
		return {}
	var packed := Marshalls.base64_to_raw(b64)
	if packed.is_empty():
		return {}
	var raw := packed.decompress_dynamic(CODE_MAX_BYTES, FileAccess.COMPRESSION_GZIP)
	if raw.is_empty():
		return {}
	var json := JSON.new()
	if json.parse(raw.get_string_from_utf8()) != OK or not _is_valid(json.data):
		return {}
	return json.data


## Remplace la progression par celle du code. Faux (et rien de changé) si le code n'est pas valide.
func import_code(text: String) -> bool:
	var data := decode_code(text)
	if data.is_empty():
		return false
	_apply(data)
	save()
	return true


# La fiche d'un jour (créée si besoin, et gardée dans l'historique).
func _day(key: String) -> Dictionary:
	if not _days.has(key):
		_days[key] = {"answers": 0, "correct": 0, "points": 0, "series": 0}
	return _days[key]


# On ne garde que les KEEP_DAYS derniers jours (les clés se trient comme les dates), et KEEP_DAILY défis.
func _prune_days() -> void:
	for pair in [[_days, KEEP_DAYS], [_daily, KEEP_DAILY]]:
		var table: Dictionary = pair[0]
		if table.size() <= int(pair[1]):
			continue
		var keys := table.keys()
		keys.sort()
		for k in keys.slice(0, keys.size() - int(pair[1])):
			table.erase(k)


# ---------- Défi du jour ----------

## L'état du défi d'un jour (copie) : réponses déjà données, terminé ou non, points.
func daily_state(key: String) -> Dictionary:
	return _daily.get(key, {"results": [], "done": false, "points": 0}).duplicate(true)


## Une réponse du défi (en plus de record_answer, qui compte pour la collection et la semaine).
## Sans effet si le défi est déjà terminé ou si ce dossier y a déjà été joué.
func record_daily_answer(key: String, result: Dictionary) -> void:
	var d: Dictionary = _daily.get(key, {"results": [], "done": false, "points": 0})
	if d["done"]:
		return
	for r in d["results"]:
		if r["id"] == result["id"]:
			return
	d["results"].append({"id": str(result["id"]), "correct": bool(result["correct"]),
			"clues": int(result.get("clues", 0)), "points": int(result["points"])})
	_daily[key] = d
	save()


func finish_daily(key: String) -> void:
	var d: Dictionary = _daily.get(key, {"results": [], "done": false, "points": 0})
	d["done"] = true
	d["points"] = Scoring.total(d["results"])
	_daily[key] = d
	save()


func daily_done(key: String) -> bool:
	return bool(_daily.get(key, {}).get("done", false))


## Jours de suite où le défi a été terminé, jusqu'à aujourd'hui (ou jusqu'à hier si celui du jour reste à faire).
func daily_streak(today_key: String) -> int:
	var d := Week.from_key(today_key)
	if not daily_done(today_key):
		d = Week.shifted(d, -1)
	var n := 0
	while daily_done(Week.key(d)):
		n += 1
		d = Week.shifted(d, -1)
	return n


# ---------- Lecture ----------

func is_collected(question_id: String) -> bool:
	return int(_dossiers.get(question_id, {}).get("wins", 0)) > 0


func best_points(question_id: String) -> int:
	return int(_dossiers.get(question_id, {}).get("best", 0))


func plays(question_id: String) -> int:
	return int(_dossiers.get(question_id, {}).get("plays", 0))


func best_series(count: int) -> int:
	return int(_best_series.get(str(count), 0))


## Meilleur total à un défi du jour (0 si aucun défi terminé).
func best_daily() -> int:
	return int(_best_series.get(BEST_DAILY, 0))


func series_played() -> int:
	return _series_played


## Ce qui s'est joué un jour donné (des zéros si rien).
func day_stats(key: String) -> Dictionary:
	var s: Dictionary = _days.get(key, {})
	return {"answers": int(s.get("answers", 0)), "correct": int(s.get("correct", 0)),
			"points": int(s.get("points", 0)), "series": int(s.get("series", 0))}


## Bilan de la semaine (lundi à dimanche) qui contient `date` : une fiche par jour, puis les totaux.
## `best_index` : le jour aux meilleurs points (-1 si rien n'a été joué), le premier en cas d'égalité.
func week_summary(date: Dictionary) -> Dictionary:
	var days: Array = []
	var total := {"answers": 0, "correct": 0, "points": 0, "series": 0}
	var played := 0
	var best_index := -1
	var best_points := 0
	var dates := Week.days_of(date)
	for i in dates.size():
		var s := day_stats(Week.key(dates[i]))
		days.append(s)
		for k in total:
			total[k] = int(total[k]) + int(s[k])
		if int(s["answers"]) > 0:
			played += 1
			if best_index == -1 or int(s["points"]) > best_points:
				best_index = i
				best_points = int(s["points"])
	return {"days": days, "answers": total["answers"], "correct": total["correct"], "points": total["points"],
			"series": total["series"], "days_played": played, "best_index": best_index}


## Combien de ces questions sont collectées (les identifiants inconnus du pack ne comptent pas).
func collected_in(questions: Array) -> int:
	var n := 0
	for q in questions:
		if is_collected(q["id"]):
			n += 1
	return n


## Trouvé sans aucun indice (meilleur score = le maximum d'un dossier).
func is_flawless(question_id: String) -> bool:
	return best_points(question_id) >= Scoring.MAX_POINTS


func flawless_in(questions: Array) -> int:
	var n := 0
	for q in questions:
		if is_flawless(q["id"]):
			n += 1
	return n


## Somme des meilleurs scores des dossiers (le total d'une fiche : 3 000 au plus pour 30 dossiers).
func best_total_in(questions: Array) -> int:
	var n := 0
	for q in questions:
		n += best_points(q["id"])
	return n


## Vrai si le dossier peut revenir aujourd'hui (`today` : « AAAA-MM-JJ », aujourd'hui par défaut).
func is_due(question_id: String, today := "") -> bool:
	var due := str(_dossiers.get(question_id, {}).get("revoir", ""))
	return due == "" or due <= (today if today != "" else Week.today_key())


## Dossiers mis de côté jusqu'à demain (ou plus tard) : ratés ou trouvés avec un indice, pas encore revenus.
func waiting_in(questions: Array, today := "") -> int:
	var n := 0
	for q in questions:
		if not is_flawless(q["id"]) and not is_due(q["id"], today):
			n += 1
	return n


## Ordre de jeu d'une fiche, en trois paquets : les dossiers pas encore trouvés, puis ceux trouvés avec un indice
## (à retrouver sans), puis ceux déjà trouvés sans indice (la révision). Les dossiers ratés ou trouvés avec un indice
## ne reviennent qu'à partir du lendemain (is_due) : d'ici là, ils restent hors de la file. Dans chaque paquet,
## la difficulté monte : les faciles, puis les moyens, puis les difficiles, mélangés à l'intérieur de chaque niveau.
func draw(questions: Array, count: int, today := "") -> Array:
	var tiers := [[], [], []]
	for q in questions:
		var perfect := is_flawless(q["id"])
		if not perfect and not is_due(q["id"], today):
			continue
		var tier := 0 if not is_collected(q["id"]) else (2 if perfect else 1)
		(tiers[tier] as Array).append(q)
	var out: Array = []
	for tier in tiers:
		out.append_array(_by_rising_difficulty(tier))
	return out.slice(0, count)


# Faciles, puis moyens, puis difficiles ; chaque niveau mélangé.
static func _by_rising_difficulty(questions: Array) -> Array:
	var levels := [[], [], []]
	for q in questions:
		var rank: int = QuestionPack.DIFFICULTY_LEVELS.get(str(q.get("difficulte", "moyenne")), 2)
		(levels[clampi(rank, 1, 3) - 1] as Array).append(q)
	var out: Array = []
	for level in levels:
		level.shuffle()
		out.append_array(level)
	return out
