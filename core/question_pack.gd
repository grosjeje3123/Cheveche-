class_name QuestionPack
extends RefCounted
## Un pack de questions chargé depuis un fichier JSON (data/packs/), ou plusieurs packs réunis (load_files).
## Chaque question retient le pack dont elle vient (clé « _pack », pour ses images et ses licences), son numéro
## de dossier (clé « _numero » : premier_numero du pack + numéro de la question - 1) et son niveau (clé « _niveau »,
## d'après le champ « niveau » du pack : 1 par défaut, 2 pour les dossiers pointus qui s'ouvrent une fois la fiche complète).
## Aucune dépendance à l'interface : on peut l'utiliser et le tester sans écran.

const IMAGES_ROOT := "res://assets/images"
## Difficulté d'un dossier (champ « difficulte », schéma 4) : de 1 (très accessible) à 5 (pour spécialistes).
const DIFFICULTY_MAX := 5
## Anciens packs (schéma 3) : la difficulté était un mot.
const LEGACY_DIFFICULTY := {"facile": 2, "moyenne": 3, "difficile": 4}
const REQUIRED_KEYS := ["id", "categorie", "difficulte", "question", "indices", "reponse",
		"reponse_courte", "distracteurs", "explication", "image"]

var id := ""
var title := ""
## Les dossiers du jeu de base (niveau 1) : les fiches, « Au hasard », le défi du jour.
var questions: Array = []
## Les dossiers du niveau 2, à part : ils ne comptent ni dans les 30 dossiers d'une fiche, ni dans « Au hasard »,
## ni dans le défi du jour.
var expert: Array = []
var allowed_licences: Array = []
## Nombre de questions écartées au chargement parce qu'elles étaient incomplètes.
var ignored := 0

var _collection_of_category := {}
## Licences autorisées, par identifiant de pack.
var _licences_of_pack := {}


static func load_file(path: String) -> QuestionPack:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Pack introuvable : %s" % path)
		return null
	var data = JSON.parse_string(file.get_as_text())
	if not (data is Dictionary) or not data.has("pack") or not data.has("questions"):
		push_error("Pack invalide : %s" % path)
		return null
	var pack := QuestionPack.new()
	pack.id = data["pack"].get("id", "")
	pack.title = data["pack"].get("titre", "")
	pack.allowed_licences = data["pack"].get("licences_autorisees", [])
	pack._collection_of_category = data["pack"].get("collection_par_categorie", {})
	pack._licences_of_pack[pack.id] = pack.allowed_licences
	var first := int(data["pack"].get("premier_numero", 1))
	var level := maxi(1, int(data["pack"].get("niveau", 1)))
	var number_re := RegEx.create_from_string("(\\d+)$")
	for q in data["questions"]:
		var problems := check_question(q)
		if problems.is_empty():
			q["_pack"] = pack.id
			q["_niveau"] = level
			var m := number_re.search(String(q["id"]))
			q["_numero"] = first + (int(m.get_string()) if m else 1) - 1
			(pack.questions if level == 1 else pack.expert).append(q)
		else:
			pack.ignored += 1
			push_error("Question ignorée (%s) : %s" % [q.get("id", "?"), ", ".join(problems)])
	return pack


## Plusieurs packs réunis en un seul (dans l'ordre donné). Les packs introuvables ou invalides sont signalés et sautés.
static func load_files(paths: Array) -> QuestionPack:
	var all := QuestionPack.new()
	var titles: Array[String] = []
	var seen := {}
	for path in paths:
		var p := load_file(path)
		if p == null:
			continue
		titles.append(p.title)
		all.ignored += p.ignored
		for c in p._collection_of_category:
			all._collection_of_category[c] = p._collection_of_category[c]
		all._licences_of_pack[p.id] = p.allowed_licences
		for q in p.questions + p.expert:
			if seen.has(q["id"]):
				push_error("Question en double ignorée : %s" % q["id"])
				all.ignored += 1
				continue
			seen[q["id"]] = true
			(all.questions if level_of(q) == 1 else all.expert).append(q)
	all.id = "" if all._licences_of_pack.size() != 1 else all._licences_of_pack.keys()[0]
	all.title = ", ".join(titles)
	return all


## Contrôle minimal à l'exécution. Le contrôle complet (licences, doublons...) est tools/validate_pack.py.
static func check_question(q: Dictionary) -> PackedStringArray:
	var problems := PackedStringArray()
	for k in REQUIRED_KEYS:
		if not q.has(k):
			problems.append("champ manquant « %s »" % k)
	if not problems.is_empty():
		return problems
	if not (q["indices"] is Array) or q["indices"].size() != RevealRules.clue_count():
		problems.append("%d indices attendus" % RevealRules.clue_count())
	if not (q["distracteurs"] is Array) or q["distracteurs"].size() != 3:
		problems.append("3 distracteurs attendus")
	var d = q["difficulte"]
	if not (LEGACY_DIFFICULTY.has(d) or ((d is int or d is float) and int(d) >= 1 and int(d) <= DIFFICULTY_MAX)):
		problems.append("difficulté inconnue")
	if not (q["image"] is Dictionary) or not ["a_trouver", "verifie"].has(q["image"].get("statut", "")):
		problems.append("statut d'image inconnu")
	return problems


## Les quatre choix du QCM, dans un ordre aléatoire. La bonne réponse est q["reponse_courte"].
static func choices_for(q: Dictionary) -> Array:
	var list: Array = [q["reponse_courte"]]
	list.append_array(q["distracteurs"])
	list.shuffle()
	return list


func by_id(question_id: String) -> Dictionary:
	for q in questions + expert:
		if q["id"] == question_id:
			return q
	return {}


## 1 : jeu de base ; 2 : dossier pointu, ouvert une fois la fiche complète.
static func level_of(q: Dictionary) -> int:
	return int(q.get("_niveau", 1))


func collection_of(q: Dictionary) -> String:
	return _collection_of_category.get(q["categorie"], "")


## Les dossiers d'une discipline, au niveau demandé (1 par défaut : la fiche de base).
func questions_in(collection: String, level := 1) -> Array:
	var source: Array = questions if level == 1 else expert
	return source.filter(func(q: Dictionary) -> bool: return collection_of(q) == collection and level_of(q) == level)


## Numéro de dossier affiché sur la carte : premier_numero du pack + numéro de la question - 1
## (svt01-q07 donne 7 ; astro01-q01 donne 101 si le pack commence à 101).
func dossier_number(q: Dictionary) -> int:
	if q.has("_numero"):
		return int(q["_numero"])
	var m := RegEx.create_from_string("(\\d+)$").search(String(q["id"]))
	return int(m.get_string()) if m else 0


## La difficulté d'un dossier, de 1 à DIFFICULTY_MAX (3 si elle manque).
static func difficulty_of(q: Dictionary) -> int:
	var d = q.get("difficulte", 3)
	if d is String:
		return int(LEGACY_DIFFICULTY.get(d, 3))
	return clampi(int(d), 1, DIFFICULTY_MAX)


func difficulty_level(q: Dictionary) -> int:
	return difficulty_of(q)


func image_path(q: Dictionary) -> String:
	return "%s/%s/%s" % [IMAGES_ROOT, q.get("_pack", id), q["image"].get("fichier", "")]


## Famille d'une licence notée exactement (« CC BY-SA 4.0 » donne « CC BY-SA »). Vide si la forme n'est pas reconnue.
static func licence_family(licence: String) -> String:
	var re := RegEx.create_from_string("^(CC BY-SA|CC BY|CC0|Domaine public)(?: \\d(?:\\.\\d)?(?: [A-Za-z]{2,3})?)?$")
	var m := re.search(licence)
	return m.get_string(1) if m else ""


## Vrai si toutes les métadonnées exigées sont présentes et la licence autorisée (le fichier n'est pas regardé).
func image_metadata_complete(q: Dictionary) -> bool:
	var im: Dictionary = q["image"]
	if im.get("statut", "") != "verifie":
		return false
	for k in ["fichier", "auteur", "licence", "url_page", "url_fichier", "modifications"]:
		if str(im.get(k, "")).strip_edges() == "":
			return false
	var allowed: Array = _licences_of_pack.get(q.get("_pack", id), allowed_licences)
	return allowed.has(licence_family(str(im["licence"])))


## Vrai seulement si l'image est vérifiée (métadonnées complètes, licence autorisée) ET le fichier existe.
func has_verified_image(q: Dictionary) -> bool:
	return image_metadata_complete(q) and ResourceLoader.exists(image_path(q))


## Mention courte de l'image affichée (sous l'explication) : auteur et licence, d'après les seules métadonnées
## vérifiées du pack. Le titre, les liens et les modifications sont sur la page Crédits.
## Vide si l'image n'est pas une photo vérifiée : on n'invente jamais un auteur ni une licence.
func credit_line(q: Dictionary) -> String:
	if not has_verified_image(q):
		return ""
	var im: Dictionary = q["image"]
	return "Image : %s, %s." % [str(im["auteur"]).strip_edges(), str(im["licence"]).strip_edges()]


## Les modifications d'une image, en bref pour la page Crédits (la page explique les deux mots) :
## « Recadrée et réduite », « Recadrée », « Réduite », ou « » si aucune. Un autre texte est rendu tel quel.
static func changes_short(modifications: String) -> String:
	var m := modifications.strip_edges()
	var low := m.to_lower()
	if m == "" or low == "aucune":
		return ""
	var cropped := "recadr" in low
	var reduced := "rédui" in low or "redimension" in low
	if cropped and reduced:
		return "Recadrée et réduite"
	if cropped:
		return "Recadrée"
	if reduced:
		return "Réduite"
	return m.trim_suffix(".")


## Adresse de l'acte de licence (en français) d'une licence notée exactement, ou "" (domaine public, forme inconnue).
## « CC BY-SA 4.0 » -> https://creativecommons.org/licenses/by-sa/4.0/deed.fr ; « CC BY 3.0 FR » -> …/by/3.0/fr/deed.fr
static func licence_url(licence: String) -> String:
	var m := RegEx.create_from_string("^(CC BY-SA|CC BY|CC0)(?: (\\d(?:\\.\\d)?)(?: ([A-Za-z]{2,3}))?)?$").search(licence.strip_edges())
	if m == null:
		return ""
	if m.get_string(1) == "CC0":
		return "https://creativecommons.org/publicdomain/zero/1.0/deed.fr"
	var kind := "by-sa" if m.get_string(1) == "CC BY-SA" else "by"
	var version := m.get_string(2)
	if version == "":
		return "https://creativecommons.org/licenses/%s/4.0/deed.fr" % kind
	var port := m.get_string(3).to_lower()
	return "https://creativecommons.org/licenses/%s/%s/%sdeed.fr" % [kind, version, (port + "/") if port != "" else ""]


## Titre lisible d'un fichier Commons d'après l'adresse de sa page :
## « …/wiki/File:Bee_on_lavender%2C_Provence.jpg » -> « Bee on lavender, Provence ».
static func source_title(url_page: String) -> String:
	var last := url_page.get_slice("?", 0).rstrip("/").get_file().uri_decode()
	for prefix in ["File:", "Fichier:", "Datei:"]:
		if last.begins_with(prefix):
			last = last.substr(prefix.length())
	return last.get_basename().replace("_", " ").strip_edges()


## Les crédits complets des images vérifiées et présentes, dans l'ordre des dossiers :
## [{dossier: int, title, author, licence, licence_url, source_url, changes}].
func credit_entries() -> Array:
	var out: Array = []
	for q in questions + expert:
		if not has_verified_image(q):
			continue
		var im: Dictionary = q["image"]
		var mod := str(im.get("modifications", "")).strip_edges()
		out.append({
			"dossier": dossier_number(q),
			"title": source_title(str(im["url_page"])),
			"author": str(im["auteur"]).strip_edges(),
			"licence": str(im["licence"]).strip_edges(),
			"licence_url": licence_url(str(im["licence"])),
			"source_url": str(im["url_page"]).strip_edges(),
			"changes": "" if mod.to_lower() == "aucune" else mod,
			"changes_short": changes_short(mod),
			"dossier_title": str(q.get("titre", "")),
			"discipline": collection_of(q),
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["dossier"]) < int(b["dossier"]))
	return out
