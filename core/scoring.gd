class_name Scoring
extends RefCounted
## Les points d'un dossier : 100 si l'on répond sans aucun indice, 60 avec un indice, 30 avec les deux.
## Une mauvaise réponse ne rapporte rien ; on ne perd jamais de points.

const POINTS_BY_CLUES := [100, 60, 30]
const MAX_POINTS := 100


static func points_for(correct: bool, clues: int) -> int:
	if not correct:
		return 0
	return POINTS_BY_CLUES[clampi(clues, 0, POINTS_BY_CLUES.size() - 1)]


## Points qu'un dossier vaut en ce moment (avant de répondre), selon les indices déjà dévoilés.
static func points_at(clues: int) -> int:
	return points_for(true, clues)


## `results` : une entrée par dossier joué, au format {id, correct, clues, points}.
static func total(results: Array) -> int:
	var sum := 0
	for r in results:
		sum += int(r.get("points", 0))
	return sum


static func correct_count(results: Array) -> int:
	var n := 0
	for r in results:
		if r.get("correct", false):
			n += 1
	return n


static func max_total(count: int) -> int:
	return count * MAX_POINTS


## Le petit jingle de fin du défi (effet de Feedback), selon la part des points possibles obtenue :
## « series_great » à partir de 90 %, « series_good » à partir de 30 %, « series_low » en dessous.
static func finish_effect(results: Array) -> String:
	if results.is_empty():
		return ""
	var ratio := float(total(results)) / float(max_total(results.size()))
	if ratio >= 0.9:
		return "series_great"
	if ratio >= 0.3:
		return "series_good"
	return "series_low"


## Une phrase sobre pour conclure le défi, selon la part des points possibles obtenue.
static func verdict(results: Array) -> String:
	if results.is_empty():
		return ""
	var ratio := float(total(results)) / float(max_total(results.size()))
	if ratio >= 0.9:
		return "Excellent."
	if ratio >= 0.6:
		return "Très bien."
	if ratio >= 0.3:
		return "Honorable."
	return "On progresse, dossier après dossier."
