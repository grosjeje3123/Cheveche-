#!/usr/bin/env python3
"""Vignettes du carnet : un carré de 176 px (affiché à 88), recadré au centre, pour chaque image vérifiée des packs.
Les vignettes sont des réductions recadrées des images de assets/images/ : mêmes auteurs, mêmes licences (les crédits
le disent). Les charger plutôt que les grandes images garde le carnet léger (270 vignettes, environ 2 Mo).
Usage : python3 tools/make_thumbs.py   (écrit assets/thumbs/<pack>/<fichier>.webp ; ne refait que ce qui manque ;
corrige aussi les réglages d'import des vignettes déjà importées par Godot : voir fix_imports)
"""
import json
import os
import sys

from PIL import Image, ImageOps

SIDE = 176
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")


def main(force=False):
    made = 0
    for name in sorted(os.listdir(os.path.join(ROOT, "data", "packs"))):
        if not name.endswith(".json"):
            continue
        pack = json.load(open(os.path.join(ROOT, "data", "packs", name), encoding="utf-8"))
        pid = pack["pack"]["id"]
        for q in pack["questions"]:
            img = q.get("image", {})
            if img.get("statut") != "verifie" or not img.get("fichier"):
                continue
            src = os.path.join(ROOT, "assets", "images", pid, img["fichier"])
            dst = os.path.join(ROOT, "assets", "thumbs", pid, os.path.splitext(img["fichier"])[0] + ".webp")
            if os.path.exists(dst) and not force:
                continue
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            im = ImageOps.fit(Image.open(src).convert("RGB"), (SIDE, SIDE), Image.LANCZOS)
            im.save(dst, "WEBP", quality=80, method=6)
            made += 1
    print(made, "vignette(s) écrite(s)")
    print(fix_imports(), "réglage(s) d'import corrigé(s)")


def fix_imports():
    """Godot importe une image WebP sans perte par défaut : 270 vignettes feraient alors 9 Mo dans le jeu. Avec perte
    (qualité 0,8), elles en font moins de 3. À relancer après que Godot a importé de nouvelles vignettes."""
    fixed = 0
    for dirpath, _dirs, files in os.walk(os.path.join(ROOT, "assets", "thumbs")):
        for name in files:
            if not name.endswith(".webp.import"):
                continue
            path = os.path.join(dirpath, name)
            text = open(path, encoding="utf-8").read()
            new = text.replace("compress/mode=0", "compress/mode=1").replace("compress/lossy_quality=0.7", "compress/lossy_quality=0.8")
            if new != text:
                open(path, "w", encoding="utf-8").write(new)
                fixed += 1
    return fixed


if __name__ == "__main__":
    main("--force" in sys.argv)
