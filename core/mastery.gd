class_name Mastery
extends RefCounted
## Le niveau du joueur dans une discipline, calculé sur l'appareil, à partir de ses premières réponses :
## la première fois qu'on rencontre un dossier, on ne connaît pas encore la réponse ; les fois suivantes, on s'en
## souvient. Rien n'est envoyé nulle part, rien n'est stocké à part : on recalcule à partir de la sauvegarde.
##
## Le modèle : un joueur de niveau R réussit un dossier de difficulté d avec la probabilité 1 / (1 + e^(-k (R - d))).
## Chaque réponse compte pour ses points (100, 60, 30 ou 0, ramenés à 1 ; 0,6 ; 0,3 ; 0) : trouver sans indice un
## dossier difficile fait beaucoup monter, rater un dossier facile fait un peu baisser. R est la valeur qui explique
## le mieux les réponses, tirée vers PRIOR tant qu'il y en a peu (on part de « Curieux » plutôt que de rien).
## Mais réussir beaucoup de dossiers faciles ne fait pas un expert : pour être Expert, il faut avoir réussi au moins
## deux dossiers de difficulté 4 ou plus ; pour être Grand Hibou, deux dossiers de difficulté 5.

const NAMES := ["Découverte", "Curieux", "Érudit", "Expert", "Grand Hibou"]
## Bornes entre les noms (Curieux à partir de 2, Érudit de 3, Expert de 3,8, Grand Hibou de 4,6).
const THRESHOLDS := [2.0, 3.0, 3.8, 4.6]
## Nombre de dossiers rencontrés dans la discipline avant d'annoncer un niveau.
const MIN_ANSWERS := 6
## Le point de départ et sa force (écart type), la pente du modèle.
const PRIOR := 2.2
const PRIOR_SPREAD := 1.2
const SLOPE := 1.2
const R_MIN := 0.5
const R_MAX := 5.5
## Une réussite qui compte pour monter de rang : au moins 60 points (trouvé avec un indice au plus).
const SOLID := 0.6


## Le niveau d'un joueur sur ces dossiers : {"r": float, "n": int (dossiers rencontrés)}.
static func rating(save: SaveStore, questions: Array) -> Dictionary:
	var obs: Array = []
	for q in questions:
		var p := save.first_points(q["id"])
		if p >= 0:
			obs.append([QuestionPack.difficulty_of(q), clampf(p / float(Scoring.MAX_POINTS), 0.0, 1.0)])
	return {"r": estimate(obs), "n": obs.size()}


## R à partir des réponses [[difficulté, résultat entre 0 et 1], …] (sans sauvegarde : sert aux tests).
static func estimate(obs: Array) -> float:
	var lo := R_MIN
	var hi := R_MAX
	for _i in 40:  # la fonction décroît avec R : dichotomie
		var r := (lo + hi) / 2.0
		var f := -(r - PRIOR) / (PRIOR_SPREAD * PRIOR_SPREAD)
		for o in obs:
			f += SLOPE * (float(o[1]) - 1.0 / (1.0 + exp(-SLOPE * (r - float(o[0])))))
		if f > 0.0:
			lo = r
		else:
			hi = r
	var r := (lo + hi) / 2.0
	if _solid_at(obs, 4) < 2:
		r = minf(r, THRESHOLDS[2] - 0.01)
	if _solid_at(obs, 5) < 2:
		r = minf(r, THRESHOLDS[3] - 0.01)
	return r


static func _solid_at(obs: Array, difficulty: int) -> int:
	var n := 0
	for o in obs:
		if int(o[0]) >= difficulty and float(o[1]) >= SOLID:
			n += 1
	return n


## Rang de 0 (Découverte) à 4 (Grand Hibou).
static func rank_of(r: float) -> int:
	var k := 0
	for t in THRESHOLDS:
		if r >= t:
			k += 1
	return k


static func name_of(r: float) -> String:
	return NAMES[rank_of(r)]


## Vrai si on en sait assez pour annoncer un niveau.
static func known(info: Dictionary) -> bool:
	return int(info.get("n", 0)) >= MIN_ANSWERS


## La difficulté par laquelle commencer les dossiers pas encore vus : un peu au-dessus du niveau estimé,
## pour aller vite chercher ce que le joueur ne sait pas (les plus faciles passent à la fin de la file).
## Tout premier dossier d'une discipline : par le plus accessible.
static func start_level(info: Dictionary) -> int:
	if int(info.get("n", 0)) == 0:
		return 1
	return clampi(floori(float(info.get("r", PRIOR)) + 0.3), 1, QuestionPack.DIFFICULTY_MAX)
