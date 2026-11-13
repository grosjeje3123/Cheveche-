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


## Dossier en image : pas d'indice écrit, ce qu'on gratte de l'image fait baisser les points. Moins d'un tiers
## dévoilé : 100 points ; jusqu'aux deux tiers : 60 ; au-delà : 30 (le même barème que zéro, un ou deux indices).
const VISUAL_THRESHOLDS := [1.0 / 3.0, 2.0 / 3.0]


## Palier d'un dossier en image : 0, 1 ou 2, comme un nombre d'indices (Scoring.points_for s'en sert tel quel).
static func visual_tier(fraction: float) -> int:
	var n := 0
	for t in VISUAL_THRESHOLDS:
		if fraction >= t:
			n += 1
	return n
