#!/usr/bin/env python3
"""Valide un pack de questions de Chevêche.

Règles du brief : jamais d'auteur ni de licence inventés ; une image n'est « verifie »
que si toutes ses métadonnées sont présentes, la licence est autorisée et le fichier existe.
Règles de jeu (schéma 4) : on peut répondre sans gratter, donc chaque question doit se comprendre sans
l'image ; deux indices par dossier, qui ne doivent pas nommer la réponse ; une difficulté de 1 (très accessible)
à 5 (pour spécialistes).
Un pack de type « visuels » (dossiers en image) est contrôlé à part : chaque dossier reprend l'image vérifiée
d'un dossier d'un autre pack du même dossier (champ image_de).
Usage : python3 validate_pack.py pack_svt_01.json [dossier_des_images]
"""
import json, os, re, sys

DIFFICULTES = {1, 2, 3, 4, 5}
STATUTS = {"a_trouver", "verifie"}
CHAMPS_Q = ["id", "titre", "categorie", "difficulte", "question", "indices", "reponse",
            "reponse_courte", "distracteurs", "variantes_acceptees", "explication", "anecdote", "image"]
MAX_LIBELLE = 40  # un choix de QCM doit tenir sur une ligne d’écran
MAX_QUESTION = 110  # au-delà, la carte mange la place de l’image
NB_INDICES = 2
SCHEMA = 4
# Une question qui renvoie à l'image (« cet insecte », « cette image »...) ne tient pas sans elle.
DEPEND_IMAGE_RE = re.compile(r"\b(cet|cette|ces|ci-dessus|ci-dessous|image|photo|illustration|cliché)\b", re.I)
MOTS_VIDES = {"dans", "avec", "pour", "sont", "leur", "leurs", "cette", "entre", "elles", "grand", "grande", "autre", "autres"}
CHAMPS_IMG_VERIFIE = ["fichier", "auteur", "licence", "url_page", "url_fichier", "modifications"]
# La licence est notée exactement (« CC BY-SA 4.0 ») ; sa famille doit être dans licences_autorisees.
LICENCE_RE = re.compile(r"^(CC BY-SA|CC BY|CC0|Domaine public)(?: \d(?:\.\d)?(?: [A-Za-z]{2,3})?)?$")


def famille(licence):
    m = LICENCE_RE.match(licence or "")
    return m.group(1) if m else None


CHAMPS_VISUEL = ["id", "image_de", "difficulte", "question", "reponse_courte", "distracteurs", "explication"]


def main_visuels(path, pack):
    """Pack de dossiers en image : chacun reprend l'image vérifiée d'un dossier d'un autre pack (image_de)."""
    sources = {}
    for autre in os.listdir(os.path.dirname(os.path.abspath(path))):
        if autre.endswith(".json") and os.path.join(os.path.dirname(os.path.abspath(path)), autre) != os.path.abspath(path):
            data = json.load(open(os.path.join(os.path.dirname(os.path.abspath(path)), autre), encoding="utf-8"))
            for q in data.get("questions", []):
                sources[q.get("id")] = q
    erreurs, ids = [], set()
    for q in pack["questions"]:
        qid = q.get("id", "?")
        for c in CHAMPS_VISUEL:
            if c not in q:
                erreurs.append(f"{qid}: champ manquant « {c} »")
        if qid in ids:
            erreurs.append(f"{qid}: identifiant en double")
        ids.add(qid)
        if type(q.get("difficulte")) is not int or q.get("difficulte") not in DIFFICULTES:
            erreurs.append(f"{qid}: difficulté invalide « {q.get('difficulte')} »")
        src = sources.get(q.get("image_de"))
        if src is None:
            erreurs.append(f"{qid}: dossier source « {q.get('image_de')} » introuvable")
        elif src.get("image", {}).get("statut") != "verifie":
            erreurs.append(f"{qid}: l’image de « {q.get('image_de')} » n’est pas vérifiée")
        distr = q.get("distracteurs", [])
        if len(distr) != 3 or len(set(distr)) != 3:
            erreurs.append(f"{qid}: 3 distracteurs différents attendus")
        if q.get("reponse_courte") in distr:
            erreurs.append(f"{qid}: la réponse est parmi les distracteurs")
        for libelle in [q.get("reponse_courte", "")] + distr:
            if len(libelle) > MAX_LIBELLE:
                erreurs.append(f"{qid}: choix trop long ({len(libelle)} caractères) « {libelle} »")
        if len(q.get("question", "")) > MAX_QUESTION:
            erreurs.append(f"{qid}: question trop longue")
    print(f"{len(pack['questions'])} dossiers en image")
    for e in erreurs:
        print("  ERREUR :", e)
    print("OK" if not erreurs else f"{len(erreurs)} erreur(s)")
    return 1 if erreurs else 0


def main(path, img_dir):
    pack = json.load(open(path, encoding="utf-8"))
    if pack["pack"].get("type") == "visuels":
        return main_visuels(path, pack)
    autorisees = set(pack["pack"]["licences_autorisees"])
    erreurs, alertes = [], []
    ids = set()
    nb_verifie = 0
    if pack["pack"].get("schema") != SCHEMA:
        erreurs.append(f"schéma {pack['pack'].get('schema')} (schéma {SCHEMA} attendu)")

    for q in pack["questions"]:
        qid = q.get("id", "?")
        for c in CHAMPS_Q:
            if c not in q:
                erreurs.append(f"{qid}: champ manquant « {c} »")
        if qid in ids:
            erreurs.append(f"{qid}: identifiant en double")
        ids.add(qid)
        if type(q.get("difficulte")) is not int or q.get("difficulte") not in DIFFICULTES:
            erreurs.append(f"{qid}: difficulté invalide « {q.get('difficulte')} »")
        if len(q.get("indices", [])) != NB_INDICES:
            erreurs.append(f"{qid}: {len(q.get('indices', []))} indices ({NB_INDICES} attendus)")
        enonce = q.get("question", "")
        if DEPEND_IMAGE_RE.search(enonce):
            alertes.append(f"{qid}: la question semble renvoyer à l'image (« {DEPEND_IMAGE_RE.search(enonce).group(0)} ») : "
                           "elle doit se comprendre sans elle")
        if len(enonce) > MAX_QUESTION:
            alertes.append(f"{qid}: question de {len(enonce)} caractères (> {MAX_QUESTION})")
        mots_reponse = {m for m in re.findall(r"[a-zà-ÿ]{5,}", q.get("reponse_courte", "").lower()) if m not in MOTS_VIDES}
        for i, ind in enumerate(q.get("indices", []), 1):
            commun = mots_reponse & set(re.findall(r"[a-zà-ÿ]{5,}", ind.lower()))
            if commun:
                alertes.append(f"{qid}: l'indice {i} contient un mot de la réponse ({', '.join(sorted(commun))})")
        labels = [q.get("reponse_courte", "")] + list(q.get("distracteurs", []))
        if len(q.get("distracteurs", [])) != 3:
            erreurs.append(f"{qid}: {len(q.get('distracteurs', []))} distracteurs (3 attendus)")
        norm = [l.strip().lower() for l in labels]
        if len(set(norm)) != len(norm) or "" in norm:
            erreurs.append(f"{qid}: choix du QCM vides ou en double")
        for l in labels:
            if len(l) > MAX_LIBELLE:
                alertes.append(f"{qid}: libellé de {len(l)} caractères (> {MAX_LIBELLE}) : « {l} »")
        if q.get("categorie") not in pack["pack"].get("collection_par_categorie", {}):
            erreurs.append(f"{qid}: catégorie « {q.get('categorie')} » absente de collection_par_categorie")
        if not q.get("variantes_acceptees"):
            erreurs.append(f"{qid}: aucune variante acceptée")
        if not q.get("anecdote"):
            alertes.append(f"{qid}: pas d'anecdote (facultatif)")

        im = q.get("image", {})
        st = im.get("statut")
        if st not in STATUTS:
            erreurs.append(f"{qid}: statut d'image invalide « {st} »")
        elif st == "a_trouver":
            for c in ["auteur", "licence", "url_page", "url_fichier", "fichier"]:
                if im.get(c):
                    erreurs.append(f"{qid}: image « a_trouver » mais « {c} » est renseigné (non vérifié)")
            if not im.get("recherche"):
                erreurs.append(f"{qid}: image « a_trouver » sans description de recherche")
        else:
            nb_verifie += 1
            for c in CHAMPS_IMG_VERIFIE:
                if not im.get(c):
                    erreurs.append(f"{qid}: image « verifie » sans « {c} »")
            if im.get("licence") and famille(im["licence"]) not in autorisees:
                erreurs.append(f"{qid}: licence non autorisée « {im['licence']} »")
            if im.get("fichier") and not os.path.isfile(os.path.join(img_dir, im["fichier"])):
                erreurs.append(f"{qid}: fichier introuvable « {im['fichier']} »")

    print(f"{len(pack['questions'])} questions · {nb_verifie} images vérifiées · "
          f"{len(pack['questions']) - nb_verifie} à trouver")
    for a in alertes:
        print("  alerte :", a)
    for e in erreurs:
        print("  ERREUR :", e)
    print("OK" if not erreurs else f"{len(erreurs)} erreur(s)")
    return 1 if erreurs else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else "images"))
