#!/usr/bin/env python3
"""Intègre au jeu le zip produit par la page de choix des images (tools/make_choice_page.py).

Usage (depuis le dossier du projet) :
  python3 tools/integrer_images.py cheveche_images_XXXX.zip [--dry-run]

Le zip contient choix.json (la réponse de l'API Commons pour chaque image choisie) et les images.
Rien n'est deviné : les contrôles sont ceux de tools/commons_image.py (licence autorisée, auteur indiqué,
format), refaits ici sur les métadonnées de Commons. Une image refusée n'est pas intégrée ; le dossier
garde alors son image provisoire. Pour chaque image retenue :
- l'original reçu de Commons est rangé dans images_sources/<pack>/ (Godot l'ignore : il n'entre pas dans l'appli) ;
- la version du jeu va dans assets/images/<pack>/ : seulement la partie que le jeu peut montrer (sa zone d'image
  fait 584 px de large et de 200 à 330 px de haut), 1024 px de large au plus, avec un import compressé ;
- ses métadonnées (et ces modifications) sont écrites dans le pack, contrôlé ensuite par validate_pack.py.
"""
import argparse
import glob
import io
import json
import os
import subprocess
import sys
import zipfile

ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ICI)
import commons_image as ci  # noqa: E402

PROJET = os.path.dirname(ICI)
try:  # certains PNG de Commons portent d'énormes métadonnées texte (inutiles ici : la version du jeu les retire)
    from PIL import PngImagePlugin
    PngImagePlugin.MAX_TEXT_CHUNK = 64 * 1024 * 1024
except ImportError:
    pass
# Import Godot de chaque image : compression avec pertes (WebP), sans mipmaps. Godot complète le reste.
IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=1
compress/high_quality=false
compress/lossy_quality=0.8
mipmaps/generate=false
"""


def contenu_image(octets):
    return octets.startswith(ci.CONTENU_IMAGE) or (octets[:4] == b"RIFF" and octets[8:12] == b"WEBP")


def extension_du_contenu(octets):
    """L'extension d'après le contenu réel du fichier (et non d'après son adresse)."""
    if octets.startswith(b"\xff\xd8\xff"):
        return ".jpg"
    if octets.startswith(b"\x89PNG\r\n\x1a\n"):
        return ".png"
    return ".webp"


# La version du jeu. La zone d'image fait 584 px de large et de 200 à 330 px de haut (screens/play_screen.gd) ;
# l'image y est recadrée au centre. On ne garde donc que ce que le jeu peut montrer, en 1024 px de large au plus.
LARGEUR_JEU = 1024
RAPPORT_MIN = 584 / 330   # la zone la plus haute : la bande la plus haute qu'on puisse voir
RAPPORT_MAX = 584 / 200   # la zone la plus basse (pendant l'explication)
SOURCES = os.path.join(PROJET, "images_sources")


def version_jeu(octets):
    """(octets, extension, note) : la version de l'image pour le jeu, et ce qui a été changé (« » si rien)."""
    from PIL import Image
    with Image.open(io.BytesIO(octets)) as im:
        im.load()
        alpha = im.mode in ("RGBA", "LA", "PA") or (im.mode == "P" and "transparency" in im.info)
        if im.mode in ("I;16", "I;16B", "I"):
            im = im.convert("I").point(lambda x: x * (1 / 256)).convert("L")
        im = im.convert("RGBA" if alpha else ("L" if im.mode in ("L", "1") else "RGB"))
        notes = []
        w, h = im.size
        if w / h < RAPPORT_MIN:
            nh = round(w / RAPPORT_MIN)
            haut = (h - nh) // 2
            im = im.crop((0, haut, w, haut + nh))
            notes.append("recadrée sur la bande que le jeu peut montrer")
        elif w / h > RAPPORT_MAX:
            nw = round(h * RAPPORT_MAX)
            gauche = (w - nw) // 2
            im = im.crop((gauche, 0, gauche + nw, h))
            notes.append("recadrée sur la partie que le jeu peut montrer")
        if im.width > LARGEUR_JEU:
            im = im.resize((LARGEUR_JEU, round(im.height * LARGEUR_JEU / im.width)), Image.LANCZOS)
            notes.append(f"réduite à {LARGEUR_JEU} px de large")
        sortie = io.BytesIO()
        if alpha:
            im.save(sortie, "PNG", optimize=True)
            ext = ".png"
        else:
            im.save(sortie, "JPEG", quality=92, optimize=True)  # Godot la recompresse ensuite (WebP)
            ext = ".jpg"
    return sortie.getvalue(), ext, " et ".join(notes)


def taille_image(octets):
    try:
        from PIL import Image
    except ImportError:
        return None
    with Image.open(io.BytesIO(octets)) as im:
        return im.size


def charger_packs():
    packs = {}
    for chemin in sorted(glob.glob(os.path.join(PROJET, "data", "packs", "*.json"))):
        pack = ci.charger(chemin)
        packs[pack["pack"]["id"]] = (chemin, pack)
    return packs


def integrer(chemin_zip, dry_run=False, forcer=False):
    z = zipfile.ZipFile(chemin_zip)
    choix = json.loads(z.read("choix.json").decode("utf-8"))
    if choix.get("format") not in ("cheveche-images", "lindice-images"):  # « lindice » : zips d’avant le changement de nom
        raise SystemExit("Ce zip ne vient pas de la page de choix des images (choix.json inattendu).")
    packs = charger_packs()
    modifies, faites, refus = set(), [], []
    for e in choix["images"]:
        qid, pack_id = e["id"], e["pack"]
        try:
            if pack_id not in packs:
                raise ci.Refus(f"pack inconnu « {pack_id} »")
            chemin_pack, pack = packs[pack_id]
            q = ci.trouver(pack, qid)
            meta = ci.analyser(e["page"])
            octets = z.read(e["fichier"])
            if not contenu_image(octets):
                raise ci.Refus("le fichier du zip n'est pas une image jpg, png ou webp")
            taille = taille_image(octets)
            if taille and meta["largeur"] and abs(taille[0] - meta["largeur"]) > 2:
                raise ci.Refus(f"l'image du zip fait {taille[0]} px de large, Commons en annonce {meta['largeur']}")
            ancienne = q["image"].get("url_page") if q["image"].get("statut") == "verifie" else None
            original, ext_original = octets, extension_du_contenu(octets)
            octets, ext_jeu, note = version_jeu(original)
            meta["extension"] = ext_jeu
            if note:
                meta["modifications"] = note[0].upper() + note[1:] if meta["modifications"] == "Aucune" \
                    else f"{meta['modifications']} ; puis {note}"
            if ancienne == meta["url_page"] and not forcer:
                print(f"{qid} : déjà dans le jeu, inchangée")
                continue
            dossier = os.path.join(PROJET, "assets", "images", pack_id)
            fichier = f"{qid}{meta['extension']}"
            print(f"\n{qid} · {q['titre']}{' (remplace l’image précédente)' if ancienne else ''}")
            print(f"  fichier : {meta['titre']}")
            print(f"  auteur  : {meta['auteur']}")
            print(f"  licence : {meta['licence']}  (Commons : « {meta['licence_source']} »)")
            print(f"  taille  : {meta['largeur_origine']}×{meta['hauteur_origine']} px, copie {meta['largeur']} px")
            if meta["largeur_origine"] and meta["largeur_origine"] < ci.LARGEUR_MIN_CONSEILLEE:
                print(f"  ATTENTION : image petite (< {ci.LARGEUR_MIN_CONSEILLEE} px de large), risque de flou")
            if dry_run:
                faites.append(qid)
                continue
            os.makedirs(dossier, exist_ok=True)
            # L'original, tel que reçu de Commons, à garder (hors de l'appli).
            sources = os.path.join(SOURCES, pack_id)
            os.makedirs(sources, exist_ok=True)
            ignore = os.path.join(SOURCES, ".gdignore")
            if not os.path.exists(ignore):
                open(ignore, "w").close()
            for vieux in glob.glob(os.path.join(sources, qid + ".*")):
                os.remove(vieux)
            with open(os.path.join(sources, qid + ext_original), "wb") as f:
                f.write(original)
            # Une ancienne image du même dossier sous une autre extension : on l'enlève (et son import).
            for vieux in glob.glob(os.path.join(dossier, qid + ".*")):
                if os.path.basename(vieux) not in (fichier, fichier + ".import"):
                    os.remove(vieux)
            with open(os.path.join(dossier, fichier), "wb") as f:
                f.write(octets)
            with open(os.path.join(dossier, fichier + ".import"), "w", encoding="utf-8", newline="\n") as f:
                f.write(IMPORT)
            ci.appliquer(q, meta, fichier)
            modifies.add(pack_id)
            faites.append(qid)
        except (ci.Refus, KeyError) as err:
            refus.append((qid, str(err)))
            print(f"\n{qid} · REFUSÉE : {err}")
    for pack_id in sorted(modifies):
        chemin_pack, pack = packs[pack_id]
        ci.enregistrer(chemin_pack, pack)
        ci.valider(chemin_pack, os.path.join(PROJET, "assets", "images", pack_id))
    for err in choix.get("erreurs", []):
        print(f"\n{err['id']} · non téléchargée par la page : {err['raison']}")
    print(f"\nBilan : {len(faites)} image(s) intégrée(s){' (essai à blanc)' if dry_run else ''}, {len(refus)} refusée(s), "
          f"{len(choix.get('erreurs', []))} absente(s) du zip.")
    return faites, refus


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("zip")
    p.add_argument("--dry-run", action="store_true", help="tout contrôler sans rien écrire")
    p.add_argument("--forcer", action="store_true", help="réécrire aussi les images déjà dans le jeu (mêmes fichiers)")
    args = p.parse_args(argv)
    faites, refus = integrer(args.zip, args.dry_run, args.forcer)
    return 1 if refus else 0


if __name__ == "__main__":
    sys.exit(main())
