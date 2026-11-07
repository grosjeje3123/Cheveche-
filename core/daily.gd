class_name Daily
extends RefCounted
## La date du jour et le défi du jour : une seule définition pour la couverture et le jeu.

const WEEKDAYS := ["dimanche", "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"]
const MONTHS := ["janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août",
		"septembre", "octobre", "novembre", "décembre"]


static func day_of_year(d: Dictionary) -> int:
	var days := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	var year: int = d["year"]
	if (year % 4 == 0 and year % 100 != 0) or year % 400 == 0:
		days[1] = 29
	var n: int = d["day"]
	for m in range(int(d["month"]) - 1):
		n += days[m]
	return n


## « mardi 3 novembre 2026 ». `d` peut venir de Time (avec « weekday ») ou de Week.from_key (sans).
static func date_label(d: Dictionary) -> String:
	var weekday: int = d["weekday"] if d.has("weekday") else (Week.weekday_index(d) + 1) % 7
	return "%s %d %s %d" % [WEEKDAYS[weekday], d["day"], MONTHS[int(d["month"]) - 1], d["year"]]


## Nombre de dossiers du défi du jour.
const CHALLENGE_LENGTH := 5
## Un signe par dossier dans le résultat à partager : trouvé sans indice, trouvé avec un ou deux indices, manqué.
const SHARE_MARKS := {"net": "●", "aide": "◐", "manque": "○"}


## Le résultat du défi à coller dans un message, sans rien dévoiler des réponses :
## « Chevêche, défi du vendredi 6 novembre » puis « ●◐●○●  4/5, 380 points ».
static func share_text(d: Dictionary, results: Array) -> String:
	var weekday: int = d["weekday"] if d.has("weekday") else (Week.weekday_index(d) + 1) % 7
	var marks := ""
	for r in results:
		if not bool(r.get("correct", false)):
			marks += SHARE_MARKS["manque"]
		elif int(r.get("clues", 0)) > 0:
			marks += SHARE_MARKS["aide"]
		else:
			marks += SHARE_MARKS["net"]
	var total := Scoring.total(results)
	return "Chevêche, défi du %s %d %s\n%s  %d/%d, %d point%s" % [WEEKDAYS[weekday], d["day"],
			MONTHS[int(d["month"]) - 1], marks, Scoring.correct_count(results), results.size(), total,
			"s" if total > 1 else ""]


## Graine du tirage d'un jour : FNV-1a 32 bits de la clé « AAAA-MM-JJ ». Calcul fixé ici (et non String.hash())
## pour rester le même d'une version de Godot à l'autre : tout le monde a le même défi le même jour.
static func seed_of(key: String) -> int:
	var h := 2166136261
	for b in key.to_utf8_buffer():
		h = ((h ^ b) * 16777619) & 0xFFFFFFFF
	return h


## La courbe du défi : deux dossiers faciles pour se mettre en route, deux moyens, un difficile pour finir.
const CURVE := ["facile", "facile", "moyenne", "moyenne", "difficile"]
## Si une discipline n'a pas le niveau voulu : le niveau le plus proche d'abord.
const NEAREST := {"facile": ["facile", "moyenne", "difficile"], "moyenne": ["moyenne", "facile", "difficile"],
		"difficile": ["difficile", "moyenne", "facile"]}


## Le défi d'un jour : CHALLENGE_LENGTH dossiers, chacun d'une discipline différente (tant qu'il y en a assez),
## de plus en plus difficiles (CURVE), tirés à partir de la date seule. Il ne dépend pas de la progression du joueur :
## à pack égal, tout le monde joue les mêmes dossiers le même jour.
static func challenge(pack: QuestionPack, key: String, count := CHALLENGE_LENGTH) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_of(key)
	# discipline -> niveau -> dossiers (triés par identifiant : l'ordre ne dépend pas du chargement)
	var groups := {}
	for q in pack.questions:
		var g := pack.collection_of(q)
		if not groups.has(g):
			groups[g] = {"facile": [], "moyenne": [], "difficile": []}
		var level := str(q.get("difficulte", "moyenne"))
		(groups[g].get(level, groups[g]["moyenne"]) as Array).append(q)
	var names: Array = groups.keys()
	names.sort()
	for i in range(names.size() - 1, 0, -1):  # mélange de Fisher-Yates, avec le générateur du jour
		var j := rng.randi_range(0, i)
		var t = names[i]
		names[i] = names[j]
		names[j] = t
	for g in names:
		for level in groups[g]:
			(groups[g][level] as Array).sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["id"]) < String(b["id"]))
	var out: Array = []
	var wanted := mini(count, pack.questions.size())
	var slot := 0
	while out.size() < wanted and slot < count * 20:
		var g: String = names[slot % names.size()]
		var want: String = CURVE[mini(out.size(), CURVE.size() - 1)]
		for level in NEAREST[want]:
			var list: Array = (groups[g][level] as Array).filter(func(q): return not out.has(q))
			if not list.is_empty():
				out.append(list[rng.randi_range(0, list.size() - 1)])
				break
		slot += 1
	return out


## Le dossier du jour : change chaque jour, parcourt le pack en boucle.
static func pick(pack: QuestionPack, d: Dictionary) -> Dictionary:
	return pack.questions[day_of_year(d) % pack.questions.size()]
