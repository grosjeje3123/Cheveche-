class_name SaveStore
extends RefCounted
## Progression du joueur, gardée sur l'appareil (user://progress.json). Rien n'est envoyé nulle part.
## Une « connaissance collectée » est un dossier trouvé au moins une fois.
## Le fichier est écrit en entier à chaque réponse (quelques ko) : on peut quitter à tout moment.
## À chaque lancement réussi, le fichier lu est recopié à côté (.bak). Si la sauvegarde est illisible, elle est
## mise de côté (.bad) et la copie prend sa place ; sans copie, on repart de zéro.
## Un fichier présent mais impossible à ouvrir n'est jamais écrasé : la partie continue sans écrire.
## Un échec d'écriture ne bloque jamais le jeu.
## Pour changer d'appareil sans compte ni serveur : export_code() donne un texte de quelques ko (la progression
## compressée), que le joueur copie et garde lui-même ; import_code() le relit et remplace la progression.

## Version du format écrit. Les versions 1 à 3 se lisent telles quelles (voir _migrate) ; un code de sauvegarde
## d'une version plus récente que celle-ci est refusé (le jeu doit d'abord être mis à jour).
const VERSION := 3
const DEFAULT_PATH := "user://progress.json"
## Copie du dernier fichier lu sans erreur, et fichier illisible mis de côté.
const BACKUP_SUFFIX := ".bak"
const BAD_SUFFIX := ".bad"
## Défis du jour dont on garde le détail des réponses (les plus récents) ; des autres, terminés, on ne garde
## que « fait » et les points : c'est tout ce que lisent les jours de suite, et le code de sauvegarde reste court.
const KEEP_DAILY_DETAILS := 2
## Nombre de jours d'historique gardés (le bilan de la semaine n'en demande que 14).
const KEEP_DAYS := 120
## Défis du jour gardés (pour compter les jours de suite).
const KEEP_DAILY := 400
## Révision espacée : jours avant le retour d'un dossier, selon sa boîte (0 : à revoir ; 1, 2 : à consolider).
## Trouvé sans indice, un dossier monte d'une boîte ; manqué ou trouvé avec un indice, il retourne à la boîte 0.
## Trouvé sans indice dès la première fois : il saute en boîte 2 (on le vérifie une fois, une semaine plus tard).
const RETURN_DAYS := [1, 3, 7]
const ACQUIRED := 3
## Clé du meilleur défi du jour dans les records (les autres clés : nombre de dossiers de la série).
const BEST_DAILY := "defi"
## Début du code de sauvegarde : le reconnaître dans un texte collé, et changer de format un jour (CHEVECHE2-…).
const CODE_PREFIX := "CHEVECHE1-"
## Taille maximale acceptée une fois décompressé (une progression complète fait quelques dizaines de ko).
const CODE_MAX_BYTES := 4 * 1024 * 1024

var path: String

## Ce qui s'est passé au dernier chargement.
enum LoadState { NEW, READ, RESTORED, UNREADABLE }
var load_state := LoadState.NEW
# Vrai quand le fichier existe mais n'a pas pu être ouvert : on ne l'écrase pas (voir save).
var _write_locked := false

## id du dossier -> {"best": int, "plays": int, "wins": int, "first": int, "boite": int, "revoir": "AAAA-MM-JJ" (facultatif)}
## « boite » : la révision espacée (voir RETURN_DAYS). 0 : à revoir demain (manqué, ou trouvé avec un indice) ;
## 1 et 2 : à consolider (trouvé sans indice, revient dans 3 puis 7 jours) ; 3 : acquis (ne revient plus qu'en révision).
## « first » : les points de la toute première réponse (c'est elle qui mesure ce que le joueur savait : voir Mastery).
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
## Dossiers gardés en favori dans le carnet (id -> true).
var _favorites := {}


func _init(save_path := DEFAULT_PATH) -> void:
	path = save_path
	load_from_disk()


func load_from_disk() -> void:
	_clear()
	load_state = LoadState.NEW
	_write_locked = false
	var backup := path + BACKUP_SUFFIX
	if not FileAccess.file_exists(path):
		# Pas de sauvegarde : une copie restée là viendrait d'une autre vie du fichier, on ne la reprend pas.
		DirAccess.remove_absolute(backup)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		# Le fichier est là mais ne s'ouvre pas (disque, droits) : on joue avec la copie si elle existe,
		# et on n'écrit rien par-dessus un fichier qu'on n'a pas pu lire.
		push_warning("Sauvegarde illisible, laissée telle quelle : %s" % path)
		_write_locked = true
		load_state = LoadState.RESTORED if _restore_backup() else LoadState.UNREADABLE
		return
	var data = _parse(file.get_as_text())
	file.close()
	if not _is_valid(data):
		push_warning("Sauvegarde invalide, mise de côté : %s" % path)
		_set_aside()
		if _restore_backup():
			load_state = LoadState.RESTORED
			save()
		else:
			load_state = LoadState.UNREADABLE
		return
	_apply(_migrate(data))
	load_state = LoadState.READ
	# Le fichier vient d'être lu sans erreur : c'est lui la nouvelle copie de secours.
	DirAccess.copy_absolute(path, backup)


static func _parse(text: String):
	var json := JSON.new()
	return json.data if json.parse(text) == OK else null


# Reprend la copie de secours. Faux s'il n'y en a pas de valide.
func _restore_backup() -> bool:
	var file := FileAccess.open(path + BACKUP_SUFFIX, FileAccess.READ)
	if file == null:
		return false
	var data = _parse(file.get_as_text())
	file.close()
	if not _is_valid(data):
		return false
	_apply(_migrate(data))
	return true


# Met le fichier illisible de côté, sans écraser celui d'un incident précédent.
func _set_aside() -> void:
	var target := path + BAD_SUFFIX
	if FileAccess.file_exists(target):
		target += "-" + Time.get_datetime_string_from_system().replace(":", "").replace("-", "")
	DirAccess.rename_absolute(path, target)


## Version du format d'une progression lue (les toutes premières sauvegardes n'en portaient pas : 1).
static func version_of(data: Dictionary) -> int:
	return maxi(1, int(data.get("version", 1)))


# Amène une progression lue au format courant. Les versions 1 à 3 ont les mêmes champs, lus avec leurs valeurs
# par défaut dans _apply : rien à convertir. Une prochaine version ajoute ici sa conversion, par numéro.
static func _migrate(data: Dictionary) -> Dictionary:
	return data


func _clear() -> void:
	_dossiers = {}
	_best_series = {}
	_series_played = 0
	_days = {}
	_daily = {}
	_favorites = {}


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
			if d.has("first"):
				_dossiers[str(id)]["first"] = clampi(int(d["first"]), 0, Scoring.MAX_POINTS)
			# Sauvegardes d'avant la révision espacée : trouvé sans indice, il revient une fois pour devenir acquis.
			if d.has("boite"):
				_dossiers[str(id)]["boite"] = clampi(int(d["boite"]), 0, ACQUIRED)
			elif int(d.get("best", 0)) >= Scoring.MAX_POINTS and not d.has("revoir"):
				_dossiers[str(id)]["boite"] = 2
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
	var favorites = data.get("favoris", [])
	if favorites is Array:
		for id in favorites:
			_favorites[str(id)] = true
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
		"favoris": _favorites.keys(),
	}


## Écrit la sauvegarde. Renvoie faux (sans planter) si le disque refuse.
func save() -> bool:
	if _write_locked:
		return false
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
	if int(d["plays"]) == 0:
		d["first"] = points
	if correct:
		d["wins"] = int(d["wins"]) + 1
	var first_time := int(d["plays"]) == 0
	d["plays"] = int(d["plays"]) + 1
	d["best"] = maxi(int(d["best"]), points)
	# La révision espacée : sans indice, une boîte de plus (deux d'un coup la toute première fois) ; sinon, retour à 0.
	var box := int(d.get("boite", 0))
	if correct and points >= Scoring.MAX_POINTS:
		box = mini(ACQUIRED, 2 if first_time else box + 1)
	else:
		box = 0
	d["boite"] = box
	if box >= ACQUIRED:
		d.erase("revoir")
	else:
		d["revoir"] = Week.key(Week.shifted(Week.from_key(day if day != "" else Week.today_key()), RETURN_DAYS[box]))
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


## Vrai si le texte contient un code valide, mais écrit par une version du jeu plus récente que celle-ci.
static func code_is_newer(text: String) -> bool:
	var data := decode_code(text)
	return not data.is_empty() and version_of(data) > VERSION


## Remplace la progression par celle du code. Faux (et rien de changé) si le code n'est pas valide,
## ou s'il vient d'une version plus récente du jeu.
func import_code(text: String) -> bool:
	var data := decode_code(text)
	if data.is_empty() or version_of(data) > VERSION:
		return false
	_apply(_migrate(data))
	save()
	return true


# La fiche d'un jour (créée si besoin, et gardée dans l'historique).
func _day(key: String) -> Dictionary:
	if not _days.has(key):
		_days[key] = {"answers": 0, "correct": 0, "points": 0, "series": 0}
	return _days[key]


# On ne garde que les KEEP_DAYS derniers jours (les clés se trient comme les dates), et KEEP_DAILY défis.
# Des défis terminés, seuls les KEEP_DAILY_DETAILS plus récents gardent le détail de leurs réponses.
func _prune_days() -> void:
	for pair in [[_days, KEEP_DAYS], [_daily, KEEP_DAILY]]:
		var table: Dictionary = pair[0]
		if table.size() <= int(pair[1]):
			continue
		var keys := table.keys()
		keys.sort()
		for k in keys.slice(0, keys.size() - int(pair[1])):
			table.erase(k)
	var daily_keys := _daily.keys()
	daily_keys.sort()
	for k in daily_keys.slice(0, maxi(0, daily_keys.size() - KEEP_DAILY_DETAILS)):
		var d: Dictionary = _daily[k]
		if bool(d.get("done", false)) and not (d["results"] as Array).is_empty():
			d["results"] = []


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


## Points de la première réponse à ce dossier, ou -1 s'il n'a jamais été joué. Les sauvegardes d'avant ne la
## gardaient pas : on la déduit alors au mieux (joué une fois : son meilleur score ; plusieurs fois : le meilleur
## score, au prorata des réussites).
func first_points(question_id: String) -> int:
	var d: Dictionary = _dossiers.get(question_id, {})
	var n := int(d.get("plays", 0))
	if n == 0:
		return -1
	if d.has("first"):
		return int(d["first"])
	if n == 1:
		return int(d.get("best", 0))
	return roundi(int(d.get("best", 0)) * float(d.get("wins", 0)) / float(n))


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


## Où en est un dossier : STAGE_NEW (jamais joué), STAGE_REVIEW (à revoir : manqué ou trouvé avec un indice la
## dernière fois), STAGE_CONSOLIDATE (trouvé sans indice, à vérifier dans 3 ou 7 jours), STAGE_ACQUIRED (acquis).
const STAGE_NEW := 0
const STAGE_REVIEW := 1
const STAGE_CONSOLIDATE := 2
const STAGE_ACQUIRED := 3


func stage(question_id: String) -> int:
	var d: Dictionary = _dossiers.get(question_id, {})
	if int(d.get("plays", 0)) == 0:
		return STAGE_NEW
	var box := int(d.get("boite", 0))
	if box >= ACQUIRED:
		return STAGE_ACQUIRED
	return STAGE_CONSOLIDATE if box > 0 else STAGE_REVIEW


func is_acquired(question_id: String) -> bool:
	return stage(question_id) == STAGE_ACQUIRED


func acquired_in(questions: Array) -> int:
	var n := 0
	for q in questions:
		if is_acquired(q["id"]):
			n += 1
	return n


## Dossiers déjà joués (trouvés ou manqués) : ceux du carnet.
func played_in(questions: Array) -> Array:
	return questions.filter(func(q: Dictionary) -> bool: return plays(q["id"]) > 0)


## Date de retour d'un dossier (« AAAA-MM-JJ »), vide s'il n'en a pas (jamais joué, ou acquis).
func return_day(question_id: String) -> String:
	return str(_dossiers.get(question_id, {}).get("revoir", ""))


## Dans combien de jours reviennent les dossiers mis de côté : [le plus tôt, le plus tard] (0 s'il n'y en a pas).
func return_span(questions: Array, today := "") -> Array:
	var t := Week.from_key(today if today != "" else Week.today_key())
	var lo := 0
	var hi := 0
	for q in questions:
		if not is_acquired(q["id"]) and not is_due(q["id"], today):
			var days := Week.days_between(t, Week.from_key(return_day(q["id"])))
			lo = days if lo == 0 else mini(lo, days)
			hi = maxi(hi, days)
	return [lo, hi]


## « demain », « dans 3 jours », ou « dans les prochains jours » quand les retours s'étalent.
func return_words(questions: Array, today := "") -> String:
	var span := return_span(questions, today)
	if span[0] != span[1]:
		return "à partir de demain" if span[0] == 1 else "dans les prochains jours"
	return "demain" if span[0] <= 1 else "dans %d jours" % span[0]


func is_favorite(question_id: String) -> bool:
	return _favorites.has(question_id)


func set_favorite(question_id: String, on: bool) -> void:
	if on:
		_favorites[question_id] = true
	else:
		_favorites.erase(question_id)
	save()


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


## Dossiers mis de côté jusqu'à leur date de retour (demain, ou dans 3 ou 7 jours) : pas encore acquis.
func waiting_in(questions: Array, today := "") -> int:
	var n := 0
	for q in questions:
		if not is_acquired(q["id"]) and not is_due(q["id"], today):
			n += 1
	return n


## Ordre de jeu d'une fiche, en trois paquets : les dossiers pas encore trouvés, puis ceux à consolider dont c'est
## le jour (à retrouver sans indice), puis les acquis (la révision). Un dossier pas encore acquis ne revient qu'à
## sa date de retour (is_due : demain, ou dans 3 ou 7 jours) : d'ici là, il reste hors de la file. Dans chaque paquet,
## la difficulté monte (de 1 à 5, mélangés à l'intérieur de chaque difficulté). `start` : pour les dossiers pas encore
## trouvés, la difficulté par laquelle commencer (Mastery.start_level) ; les plus faciles passent alors à la fin.
## `skip` : identifiants à laisser de côté (déjà joués dans la partie en cours).
func draw(questions: Array, count: int, today := "", start := 1, skip := {}) -> Array:
	var tiers := [[], [], []]
	for q in questions:
		if skip.has(q["id"]):
			continue
		var acquired := is_acquired(q["id"])
		if not acquired and not is_due(q["id"], today):
			continue
		var tier := 0 if not is_collected(q["id"]) else (2 if acquired else 1)
		(tiers[tier] as Array).append(q)
	var out: Array = []
	for i in tiers.size():
		out.append_array(_by_rising_difficulty(tiers[i], start if i == 0 else 1))
	return out.slice(0, count)


# De la difficulté `start` à 5, puis les plus faciles (de 1 à start - 1) ; chaque difficulté mélangée.
static func _by_rising_difficulty(questions: Array, start := 1) -> Array:
	var levels: Array = []
	for _i in QuestionPack.DIFFICULTY_MAX:
		levels.append([])
	for q in questions:
		(levels[QuestionPack.difficulty_of(q) - 1] as Array).append(q)
	var out: Array = []
	var first := clampi(start, 1, QuestionPack.DIFFICULTY_MAX) - 1
	for i in range(first, levels.size()) + range(0, first):
		(levels[i] as Array).shuffle()
		out.append_array(levels[i])
	return out
