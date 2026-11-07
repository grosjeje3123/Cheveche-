extends SceneTree

var fails := 0

func check(label: String, ok: bool, extra := "") -> void:
	print(("OK   " if ok else "FAIL ") + label + ("  " + extra if extra != "" else ""))
	if not ok:
		fails += 1

func _initialize() -> void:
	for pair in [["CC BY-SA 4.0", "CC BY-SA"], ["CC BY 3.0", "CC BY"], ["CC BY-SA 3.0 de", "CC BY-SA"],
			["CC0", "CC0"], ["CC0 1.0", "CC0"], ["Domaine public", "Domaine public"],
			["CC BY-NC 4.0", ""], ["CC BY-ND 2.0", ""], ["GFDL 1.2", ""], ["CC BY", "CC BY"], ["", ""],
			["CC BY-SA 4.0 et plus", ""]]:
		check("famille « %s »" % pair[0], QuestionPack.licence_family(pair[0]) == pair[1], QuestionPack.licence_family(pair[0]))

	var pack := QuestionPack.load_file("res://data/packs/svt_01.json")
	check("licences autorisées lues dans le pack", pack.allowed_licences.size() == 4, str(pack.allowed_licences))
	var q: Dictionary = pack.questions[0].duplicate(true)
	q["image"] = {"statut": "a_trouver", "recherche": "test"}  # un dossier encore sans image
	check("a_trouver : métadonnées incomplètes", not pack.image_metadata_complete(q))
	q["image"] = {"statut": "verifie", "fichier": "a.jpg", "auteur": "X", "licence": "CC BY-SA 4.0",
		"url_page": "https://exemple/page", "url_fichier": "https://exemple/fichier", "modifications": "Aucune"}
	check("verifie complet : accepté", pack.image_metadata_complete(q))
	for champ in ["fichier", "auteur", "licence", "url_page", "url_fichier", "modifications"]:
		var cas: Dictionary = q.duplicate(true)
		cas["image"][champ] = ""
		check("champ « %s » vide : refusé" % champ, not pack.image_metadata_complete(cas))
		cas["image"].erase(champ)
		check("champ « %s » absent : refusé" % champ, not pack.image_metadata_complete(cas))
	var nc: Dictionary = q.duplicate(true)
	nc["image"]["licence"] = "CC BY-NC 4.0"
	check("licence NC : refusée", not pack.image_metadata_complete(nc))
	var fic: Dictionary = q.duplicate(true)
	check("métadonnées OK mais fichier absent : pas d'image affichée", not pack.has_verified_image(fic))
	print("--- ", "TOUT EST OK" if fails == 0 else "%d ÉCHEC(S)" % fails)
	quit(1 if fails > 0 else 0)
