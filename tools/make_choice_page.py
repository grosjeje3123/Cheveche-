#!/usr/bin/env python3
"""Fabrique la page de choix des images (un seul fichier HTML, à ouvrir dans un navigateur).

Usage : python3 tools/make_choice_page.py [sortie.html] [--a-trouver]   (par défaut : choisir_images.html)
  --a-trouver : seulement les dossiers dont l'image reste à trouver (par exemple un nouveau pack).
  --dossiers=id1,id2,… : seulement ces dossiers (par exemple des images à remplacer).

La page lit les packs de data/packs et les recherches proposées dans tools/commons_recherches.json.
Les dossiers dont l'image est déjà vérifiée apparaissent avec leur image « dans le jeu » ; on peut la changer.
Le zip que la page produit s'intègre avec tools/integrer_images.py.
"""
import glob
import json
import os
import sys
import urllib.parse

ICI = os.path.dirname(os.path.abspath(__file__))
PROJET = os.path.dirname(ICI)
# Même ordre et mêmes couleurs que le jeu (ds/ds.gd, DISCIPLINE_COLORS).
DISCIPLINES = [("Nature", "#687B70"), ("Animaux", "#B0694F"), ("Sciences", "#5E7387"), ("Astronomie", "#3F4A63"),
               ("Histoire", "#957638"), ("Arts", "#8E4A4F"), ("Géographie", "#737A45"), ("Littérature", "#6E5643")]


def miniature(url_fichier, largeur=640):
    """Adresse d'une vignette Commons d'après l'adresse du fichier (pour les images déjà dans le jeu)."""
    nom = urllib.parse.unquote(url_fichier.rstrip("/").split("/")[-1])
    return "https://commons.wikimedia.org/wiki/Special:FilePath/" + urllib.parse.quote(nom) + f"?width={largeur}"


def dossiers(seulement_a_trouver=False, seulement=None):
    recherches = json.load(open(os.path.join(ICI, "commons_recherches.json"), encoding="utf-8"))
    couleurs = dict(DISCIPLINES)
    ordre = {nom: i for i, (nom, _) in enumerate(DISCIPLINES)}
    sortie = []
    for chemin in sorted(glob.glob(os.path.join(PROJET, "data", "packs", "*.json"))):
        pack = json.load(open(chemin, encoding="utf-8"))
        meta = pack["pack"]
        for i, q in enumerate(pack["questions"]):
            discipline = meta["collection_par_categorie"].get(q["categorie"], "")
            im = q["image"]
            d = {
                "id": q["id"], "pack": meta["id"], "discipline": discipline, "couleur": couleurs.get(discipline, "#292D2A"),
                "numero": meta["premier_numero"] + i, "titre": q["titre"], "question": q["question"],
                "reponse": q["reponse_courte"], "idee": im.get("recherche", ""),
                "requete": recherches.get(q["id"]) or im.get("recherche") or q["titre"],
            }
            if seulement_a_trouver and im.get("statut") == "verifie":
                continue
            if seulement is not None and q["id"] not in seulement:
                continue
            if im.get("statut") == "verifie" and im.get("url_page"):
                titre = "File:" + urllib.parse.unquote(im["url_page"].split("/wiki/File:")[-1]).replace("_", " ")
                d["actuel"] = {"titre": titre, "miniature": miniature(im["url_fichier"]), "url_page": im["url_page"],
                               "auteur": im["auteur"], "licence": im["licence"]}
            sortie.append(d)
    sortie.sort(key=lambda d: (ordre.get(d["discipline"], 99), d["numero"]))
    return sortie


def main(chemin_sortie, seulement_a_trouver=False, seulement=None):
    gabarit = open(os.path.join(ICI, "page_choix_images.html"), encoding="utf-8").read()
    donnees = {"dossiers": dossiers(seulement_a_trouver, seulement),
               "disciplines": [{"nom": n, "couleur": c} for n, c in DISCIPLINES]}
    texte = json.dumps(donnees, ensure_ascii=False).replace("</", "<\\/")
    page = gabarit.replace("/*DONNEES*/null", texte, 1)
    with open(chemin_sortie, "w", encoding="utf-8", newline="\n") as f:
        f.write(page)
    n = len(donnees["dossiers"])
    faits = sum(1 for d in donnees["dossiers"] if "actuel" in d)
    print(f"{chemin_sortie} : {n} dossiers, dont {faits} avec une image déjà dans le jeu")


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    choix = [a.split("=", 1)[1] for a in sys.argv[1:] if a.startswith("--dossiers=")]
    main(args[0] if args else "choisir_images.html", "--a-trouver" in sys.argv[1:],
         set(choix[0].split(",")) if choix else None)
