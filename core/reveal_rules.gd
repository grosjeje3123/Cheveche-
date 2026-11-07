class_name RevealRules
extends RefCounted
## Règles de révélation : à quelle part grattée chaque indice se débloque.
## On peut répondre à tout moment, sans rien gratter : les indices sont une aide qui coûte des points (Scoring).
## Fonctions pures, sans interface : faciles à tester et à régler.

## Part de la surface grattée (0 à 1) qui débloque l'indice I, puis l'indice II.
const CLUE_THRESHOLDS := [0.25, 0.50]


## Nombre d'indices que contient un dossier.
static func clue_count() -> int:
	return CLUE_THRESHOLDS.size()


static func clues_unlocked(fraction: float) -> int:
	var n := 0
	for t in CLUE_THRESHOLDS:
		if fraction >= t:
			n += 1
	return n
