class_name SafeArea
## Les marges à laisser libres en haut et en bas de l'écran du téléphone (caméra, encoche, coins arrondis),
## en unités de la mise en page (720 de large). En plein écran (mode immersif), Android dessine le jeu
## jusque sous la caméra : main.gd décale donc tous les écrans de ces marges ; le fond de papier, lui,
## reste en dessous, sur tout l'écran.

## Sur téléphone, au moins cet espace en haut, même si Android ne signale aucune caméra
## (certains appareils ne la déclarent pas) : de quoi ne jamais coller le titre au bord.
const MIN_TOP_MOBILE := 32.0

## Pour les tests et les captures : des marges imposées (x = haut, y = bas). Négatif = non utilisé.
static var simulated := Vector2(-1.0, -1.0)


## x = marge du haut, y = marge du bas.
static func insets(viewport: Viewport) -> Vector2:
	if simulated.x >= 0.0:
		return simulated
	# Sur ordinateur, la « zone sûre » de l'écran est celle hors barre des tâches : sans rapport avec la fenêtre.
	if not OS.has_feature("mobile") or viewport == null:
		return Vector2.ZERO
	var window := DisplayServer.window_get_size()
	if window.y <= 0:
		return Vector2(MIN_TOP_MOBILE, 0.0)
	var safe := DisplayServer.get_display_safe_area()
	var units_per_pixel := viewport.get_visible_rect().size.y / float(window.y)
	var top := maxf(0.0, float(safe.position.y)) * units_per_pixel
	var bottom := 0.0
	if safe.size.y > 0:
		bottom = maxf(0.0, float(window.y - safe.end.y)) * units_per_pixel
	return Vector2(ceilf(maxf(top, MIN_TOP_MOBILE)), ceilf(bottom))
