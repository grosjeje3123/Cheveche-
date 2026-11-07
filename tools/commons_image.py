#!/usr/bin/env python3
"""Banque d'images de Chevêche : intègre des images de Wikimedia Commons à un pack, métadonnées comprises.

À lancer sur VOTRE ordinateur (il faut un accès à commons.wikimedia.org). Python 3.8+, aucune dépendance.

Principe : l'outil ne devine rien. Auteur, licence et adresses sont lus sur Commons (API officielle) ;
s'il manque l'auteur, ou si la licence n'est pas autorisée (CC BY, CC BY-SA, CC0, domaine public), il refuse.
Rien n'est écrit dans le pack sans votre confirmation.

Commandes (depuis le dossier du projet) :
  python3 tools/commons_image.py liste   data/packs/svt_01.json
  python3 tools/commons_image.py modele  data/packs/svt_01.json images_a_remplir.txt
  python3 tools/commons_image.py lot     data/packs/svt_01.json images_a_remplir.txt
  python3 tools/commons_image.py ajouter data/packs/svt_01.json svt01-q08 "https://commons.wikimedia.org/wiki/File:....jpg"

Options utiles : --dry-run (ne rien écrire), --yes (ne pas demander confirmation), --remplacer,
--auteur "..." / --licence "..." (à n'utiliser qu'après avoir vérifié à la main sur la page de l'image).
"""
import argparse
import html
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from html.parser import HTMLParser

API = "https://commons.wikimedia.org/w/api.php"
LARGEUR = 1600  # largeur demandée à Commons pour la miniature (assez pour un écran de téléphone)
LARGEUR_MIN_CONSEILLEE = 1000
EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}
MIME_EXT = {"image/jpeg": ".jpg", "image/png": ".png", "image/webp": ".webp"}
# Même règle que tools/validate_pack.py et core/question_pack.gd.
LICENCE_RE = re.compile(r"^(CC BY-SA|CC BY|CC0|Domaine public)(?: \d(?:\.\d)?(?: [A-Za-z]{2,3})?)?$")
LICENCE_COMMONS_RE = re.compile(r"^CC BY(?:-SA)?(?: \d(?:\.\d)?(?: [A-Za-z]{2,3})?)?$|^CC0(?: \d(?:\.\d)?)?$")
CONTENU_IMAGE = (b"\xff\xd8\xff", b"\x89PNG\r\n\x1a\n")


class Refus(Exception):
    """Une image ne peut pas être intégrée : le message dit pourquoi."""


# ---------------------------------------------------------------- lecture des métadonnées


class _Texte(HTMLParser):
    """Le texte visible d'un fragment HTML de Commons : sans <style> ni <script>, ni ce qui est caché
    (« display: none », par exemple la traduction anglaise glissée après « Auteur inconnu »)."""
    VIDES = {"br", "img", "hr", "meta", "link", "input", "wbr", "source", "col"}
    BLOCS = {"p", "div", "td", "th", "tr", "li", "br", "table", "tbody", "ul", "ol"}

    def __init__(self):
        super().__init__()
        self.morceaux = []
        self.pile = []
        self.masque = 0

    def handle_starttag(self, tag, attrs):
        if tag in self.BLOCS and not self.masque:
            self.morceaux.append(" ")
        if tag in self.VIDES:
            return
        a = dict(attrs)
        style = (a.get("style") or "").replace(" ", "").lower()
        classes = (a.get("class") or "").split()
        # Les encadrés des modèles (« Wikidata possède l'entrée… ») ne font pas partie du nom de l'auteur.
        encadre = any(c in ("messagebox", "noprint", "metadata") or c.startswith("mbox") for c in classes)
        cache = tag in ("style", "script") or "display:none" in style or encadre
        self.pile.append((tag, cache))
        if cache:
            self.masque += 1

    def handle_endtag(self, tag):
        if tag in self.BLOCS and not self.masque:
            self.morceaux.append(" ")
        for i in range(len(self.pile) - 1, -1, -1):  # le HTML de Commons n'est pas toujours bien refermé
            if self.pile[i][0] == tag:
                self.masque -= sum(1 for _, c in self.pile[i:] if c)
                del self.pile[i:]
                return

    def handle_data(self, data):
        if not self.masque:
            self.morceaux.append(data)


# Caractères invisibles (espace sans chasse, liant de mots, marques de sens…) : la police du jeu les montrerait en carrés.
INVISIBLES_RE = re.compile("[\u00ad\u200b-\u200f\u202a-\u202e\u2060-\u2064\ufeff]")


def sans_invisibles(t):
    return INVISIBLES_RE.sub("", t or "")


def texte_brut(fragment_html):
    p = _Texte()
    p.feed(fragment_html or "")
    return re.sub(r"\s+", " ", sans_invisibles(html.unescape("".join(p.morceaux)))).strip()


def titre_depuis_url(entree):
    """Accepte une page Commons, un titre « File:... » ou l'adresse d'un fichier upload.wikimedia.org."""
    e = entree.strip()
    if not e:
        raise Refus("adresse vide")
    if not re.match(r"^https?://", e):
        nom = urllib.parse.unquote(e)
    else:
        u = urllib.parse.urlsplit(e)  # urlsplit : ne coupe pas au « ; » (fréquent dans les noms de fichiers)
        if u.netloc.endswith("upload.wikimedia.org"):
            parts = [p for p in u.path.split("/") if p]
            nom = "File:" + urllib.parse.unquote(parts[-2] if "thumb" in parts else parts[-1])
        elif u.path.startswith("/wiki/"):
            nom = urllib.parse.unquote(u.path[len("/wiki/"):])
        else:
            q = urllib.parse.parse_qs(u.query)
            nom = (q.get("title") or [""])[0]
    nom = nom.replace("_", " ").strip()
    nom = re.sub(r"^(Fichier|Image|File)\s*:", "File:", nom, flags=re.I)
    if not nom.startswith("File:") or len(nom) <= 5:
        raise Refus(f"« {entree} » n'est pas une page de fichier Commons (attendu : …/wiki/File:Nom.jpg)")
    return nom


def famille_licence(nom_commons):
    """Traduit le nom de licence donné par Commons. Renvoie la licence à enregistrer, ou lève Refus."""
    s = (nom_commons or "").strip()
    bas = s.lower()
    if not s:
        raise Refus("Commons ne donne aucune licence pour ce fichier")
    if re.search(r"(^|[\s-])(nc|nd)([\s-]|$)", bas) or "noncommercial" in bas or "noderiv" in bas:
        raise Refus(f"licence non autorisée : « {s} » (usage commercial ou modifications interdits)")
    if LICENCE_COMMONS_RE.match(s):
        return s
    if bas in ("public domain", "pd") or bas.startswith(("public domain", "pd-", "pd ")):
        return "Domaine public"
    raise Refus(f"licence non reconnue ou non autorisée : « {s} ». Vérifiez la page de l'image ; "
                "si elle est bien CC BY, CC BY-SA, CC0 ou domaine public, relancez avec --licence.")


# « Auteur inconnu », « Unknown author », « Anonyme »… : Commons déclare lui-même que l'auteur n'est pas connu.
INCONNU_RE = re.compile(r"^(?:(?:auteur|artiste|photographe|author|artist)s?\s+(?:inconnu|unknown)|unknown|anonym|inconnu|"
                        r"not provided|n/a)", re.I)
# Modèle de Commons quand l'auteur n'est pas lisible par machine : il le présume d'après la revendication de droits.
PRESUME_RE = re.compile(r"(?:Il est supposé qu.il s.agit de\s*:\s*(.+?)\s*\(étant donné|"
                        r"No machine-readable author provided\.\s*(.+?)\s+assumed\s*\(based on)", re.I)
# Quelques auteurs dont Commons donne un long texte : la reformulation fidèle, par titre de fichier.
AUTEURS_REFORMULES = os.path.join(os.path.dirname(os.path.abspath(__file__)), "auteurs_reformules.json")


# Signature de wiki collée au nom (« (talk) 17:52, 31 May 2009 (UTC) ») : ce n'est pas l'auteur, on la retire.
SIGNATURE_RE = re.compile(r"\s*\((?:talk|discussion|disc\.)\)\s*(?:\d{1,2}:\d{2},?\s*\d{1,2}\s+\w+\.?\s+\d{4}\s*\((?:UTC|CET|CEST)\))?\s*$", re.I)


def auteur_de(texte_commons, licence, titre=""):
    """L'auteur à afficher, d'après ce que Commons déclare. Rien n'est inventé : « Auteur inconnu » n'est accepté
    que pour le domaine public et CC0 (aucune attribution exigée) ; une licence CC BY sans auteur est refusée."""
    try:
        with open(AUTEURS_REFORMULES, encoding="utf-8") as f:
            reformule = json.load(f).get(titre)
    except (OSError, ValueError):
        reformule = None
    if reformule:
        return reformule
    a = (texte_commons or "").strip()
    a = SIGNATURE_RE.sub("", a).strip()  # « Esby (talk) 17:52, 31 May 2009 (UTC) » -> « Esby »
    m = PRESUME_RE.search(a)
    if m:
        a = f"{(m.group(1) or m.group(2)).strip()} (auteur présumé)"
    if not a or INCONNU_RE.match(a):
        if licence == "Domaine public" or licence.startswith("CC0"):
            return "Auteur inconnu"
        raise Refus(f"auteur inconnu sur Commons, alors que la licence {licence} demande de le citer. "
                    "Si la page de l'image donne un auteur, relancez avec --auteur \"…\".")
    if len(a) > 160:  # un long texte de modèle : sa première phrase suffit (pas une abréviation comme « SS. »)
        fins = [m.end() - 1 for m in re.finditer(r"\w{4,}\. ", a) if 20 < m.end() < 160]
        a = a[:fins[0]] if fins else a[:157].rstrip() + "…"
    return a


def sans_suivi(url):
    """Retire les paramètres de suivi (utm_…) que Commons ajoute désormais à ses adresses."""
    if not url:
        return url
    p = urllib.parse.urlsplit(url)
    q = [(k, v) for k, v in urllib.parse.parse_qsl(p.query, keep_blank_values=True) if not k.startswith("utm_")]
    return urllib.parse.urlunsplit(p._replace(query=urllib.parse.urlencode(q)))


def analyser(page, auteur_force=None, licence_force=None):
    """Extrait ce dont le pack a besoin d'une réponse de l'API (une page). Lève Refus si ce n'est pas sûr."""
    if page.get("missing") or "imageinfo" not in page:
        raise Refus("fichier introuvable sur Commons")
    info = page["imageinfo"][0]
    em = info.get("extmetadata", {})

    def champ(nom):
        return texte_brut(em.get(nom, {}).get("value", ""))

    nom_licence = champ("LicenseShortName")
    if licence_force:
        licence = licence_force.strip()
        if not LICENCE_RE.match(licence):
            raise Refus(f"--licence « {licence} » : non autorisée ou mal écrite (ex. « CC BY-SA 4.0 »)")
    else:
        licence = famille_licence(nom_licence)
        if licence == "Domaine public" and champ("Copyrighted").lower() == "true":
            raise Refus("Commons indique « Copyrighted: True » alors que la licence se dit domaine public")

    auteur = auteur_force.strip() if auteur_force else auteur_de(champ("Artist"), licence, page.get("title", ""))

    url_fichier = sans_suivi(info.get("url"))
    url_page = sans_suivi(info.get("descriptionurl"))
    if not url_fichier or not url_page:
        raise Refus("adresses du fichier absentes de la réponse de Commons")
    miniature = sans_suivi(info.get("thumburl")) or url_fichier
    ext = os.path.splitext(urllib.parse.urlparse(miniature).path)[1].lower()
    if ext not in EXTENSIONS:
        # Pas d'extension lisible dans l'adresse : le type déclaré par Commons (la miniature, sinon l'original).
        ext = MIME_EXT.get(info.get("thumbmime") or "") or MIME_EXT.get(info.get("mime") or "") or ext
    if ext not in EXTENSIONS:
        type_ = info.get("thumbmime") or info.get("mime") or ext or "?"
        raise Refus(f"format « {type_} » non pris en charge (jpg, png ou webp attendus)")
    largeur_origine = info.get("width") or 0
    largeur = info.get("thumbwidth") or largeur_origine
    # Commons arrondit parfois la miniature à une largeur standard plus petite que celle annoncée
    # (« …/lossy-page1-960px-….jpg » pour 1280 demandés) : la largeur réelle est celle de l'adresse.
    if miniature != url_fichier:
        dans_adresse = re.search(r"(?:^|-)(\d+)px-", urllib.parse.urlparse(miniature).path.rsplit("/", 1)[-1])
        if dans_adresse:
            largeur = int(dans_adresse.group(1))
    # Image plus petite que la largeur demandée : Commons envoie l'original tel quel (« thumbnail_unscaled »),
    # tout en annonçant la largeur demandée. L'image n'est alors pas modifiée.
    originale = miniature == url_fichier or (largeur_origine and largeur_origine <= largeur)
    if originale:
        largeur = largeur_origine
    return {
        "titre": sans_invisibles(page.get("title", "")),
        "auteur": auteur,
        "licence": licence,
        "licence_source": nom_licence,
        "licence_url": sans_suivi(champ("LicenseUrl")) or None,
        "url_page": url_page,
        "url_fichier": url_fichier,
        "miniature": miniature,
        "extension": ".jpg" if ext == ".jpeg" else ext,
        "largeur_origine": info.get("width", 0),
        "hauteur_origine": info.get("height", 0),
        "largeur": largeur,
        "modifications": ("Aucune" if originale else
                          f"Redimensionnée à {largeur} px de large (miniature produite par Wikimedia Commons)"),
        "description": champ("ImageDescription"),
    }


# ---------------------------------------------------------------- réseau


def _requete(url, contact):
    ua = "Cheveche-outil-images/0.1 (prototype personnel; outil local)"
    if contact:
        ua += f" {contact}"
    return urllib.request.Request(url, headers={"User-Agent": ua})


def recuperer(titre, contact=None):
    params = {"action": "query", "format": "json", "formatversion": "2", "titles": titre,
              "prop": "imageinfo", "iiprop": "url|size|mime|extmetadata", "iiurlwidth": str(LARGEUR),
              "iiextmetadatalanguage": "fr"}
    url = API + "?" + urllib.parse.urlencode(params)
    try:
        with urllib.request.urlopen(_requete(url, contact), timeout=30) as r:
            data = json.loads(r.read().decode("utf-8"))
    except urllib.error.URLError as e:
        raise Refus(f"Commons injoignable ({e})")
    pages = data.get("query", {}).get("pages", [])
    if not pages:
        raise Refus("réponse vide de Commons")
    return pages[0]


def telecharger(url, destination, contact=None):
    try:
        with urllib.request.urlopen(_requete(url, contact), timeout=60) as r:
            contenu = r.read()
    except urllib.error.URLError as e:
        raise Refus(f"téléchargement impossible ({e})")
    est_image = contenu.startswith(CONTENU_IMAGE) or (contenu[:4] == b"RIFF" and contenu[8:12] == b"WEBP")
    if not est_image:
        raise Refus("le fichier reçu n'est pas une image jpg, png ou webp")
    os.makedirs(os.path.dirname(destination), exist_ok=True)
    tmp = destination + ".part"
    with open(tmp, "wb") as f:
        f.write(contenu)
    os.replace(tmp, destination)
    return len(contenu)


# ---------------------------------------------------------------- pack


def charger(chemin):
    with open(chemin, encoding="utf-8") as f:
        return json.load(f)


def enregistrer(chemin, pack):
    sauvegarde = chemin + ".bak"
    if not os.path.exists(sauvegarde):
        with open(chemin, "rb") as src, open(sauvegarde, "wb") as dst:
            dst.write(src.read())
    tmp = chemin + ".part"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(pack, f, ensure_ascii=False, indent=2)
    os.replace(tmp, chemin)


def trouver(pack, qid):
    for q in pack["questions"]:
        if q["id"] == qid:
            return q
    raise Refus(f"identifiant inconnu : « {qid} »")


def appliquer(q, meta, fichier):
    """Passe l'image du dossier à « verifie » avec TOUTES ses métadonnées."""
    q["image"].update({
        "statut": "verifie",
        "fichier": fichier,
        "auteur": meta["auteur"],
        "licence": meta["licence"],
        "licence_source": meta["licence_source"] or None,
        "licence_url": meta["licence_url"],
        "url_page": meta["url_page"],
        "url_fichier": meta["url_fichier"],
        "modifications": meta["modifications"],
    })


def dossier_images(chemin_pack, pack, option):
    if option:
        return option
    # projet/data/packs/x.json -> projet
    racine = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(chemin_pack))))
    return os.path.join(racine, "assets", "images", pack["pack"]["id"])


# ---------------------------------------------------------------- commandes


def traiter(args, chemin_pack, pack, qid, entree, dossier):
    q = trouver(pack, qid)
    if q["image"].get("statut") == "verifie" and not args.remplacer:
        raise Refus("ce dossier a déjà une image vérifiée (ajoutez --remplacer pour la changer)")
    titre = titre_depuis_url(entree)
    meta = analyser(recuperer(titre, args.contact), args.auteur, args.licence)
    print(f"\n{qid} · {q['titre']}")
    print(f"  fichier   : {meta['titre']}")
    print(f"  auteur    : {meta['auteur']}")
    print(f"  licence   : {meta['licence']}  (Commons : « {meta['licence_source']} »)")
    print(f"  taille    : {meta['largeur_origine']}×{meta['hauteur_origine']} px, "
          f"copie utilisée {meta['largeur']} px — {meta['modifications']}")
    print(f"  page      : {meta['url_page']}")
    if meta["description"]:
        print(f"  décrit    : {meta['description'][:160]}")
    if meta["largeur_origine"] and meta["largeur_origine"] < LARGEUR_MIN_CONSEILLEE:
        print(f"  ATTENTION : image petite (< {LARGEUR_MIN_CONSEILLEE} px de large), risque de flou à l'écran")
    if args.dry_run:
        print("  (--dry-run : rien n'est écrit)")
        return False
    if not args.yes and input("  Intégrer cette image ? [o/N] ").strip().lower() not in ("o", "oui", "y", "yes"):
        print("  ignorée")
        return False
    fichier = f"{qid}{meta['extension']}"
    octets = telecharger(meta["miniature"], os.path.join(dossier, fichier), args.contact)
    appliquer(q, meta, fichier)
    enregistrer(chemin_pack, pack)
    print(f"  OK : {fichier} ({octets // 1024} Ko) enregistré, métadonnées écrites dans le pack")
    return True


def valider(chemin_pack, dossier, script=None):
    """Lance validate_pack.py et affiche son verdict. Ne doit jamais faire échouer l'ajout des images."""
    script = script or os.path.join(os.path.dirname(os.path.abspath(__file__)), "validate_pack.py")
    print("\nContrôle du pack :")
    try:
        # « -X utf8 » (et non la variable PYTHONIOENCODING, ignorée avec -I) : sortie en UTF-8 sous Windows.
        r = subprocess.run([sys.executable, "-I", "-X", "utf8", script, chemin_pack, dossier], capture_output=True)
        sortie = (r.stdout or b"") + (r.stderr or b"")
        print(sortie.decode("utf-8", errors="replace").rstrip())
    except OSError as e:
        print(f"  (contrôle impossible : {e}) — vos images et le pack sont enregistrés.")


def cmd_liste(args):
    pack = charger(args.pack)
    for q in pack["questions"]:
        im = q["image"]
        etat = "OK " if im.get("statut") == "verifie" else "à trouver"
        lien = "https://commons.wikimedia.org/w/index.php?" + urllib.parse.urlencode(
            {"search": im.get("recherche", q["titre"]), "ns6": "1", "fulltext": "1"})
        print(f"{q['id']}  [{etat}]  {q['titre']}\n    cherche : {im.get('recherche', '')}\n    {lien}")


def cmd_modele(args):
    pack = charger(args.pack)
    lignes = ["# Une ligne par image : « identifiant  adresse de la page Commons ».",
              "# Les lignes qui commencent par # et les lignes sans adresse sont ignorées.",
              "# Exemple : svt01-q08  https://commons.wikimedia.org/wiki/File:Nom_du_fichier.jpg", ""]
    for q in pack["questions"]:
        if q["image"].get("statut") == "verifie":
            continue
        lien = "https://commons.wikimedia.org/w/index.php?" + urllib.parse.urlencode(
            {"search": q["image"].get("recherche", q["titre"]), "ns6": "1", "fulltext": "1"})
        lignes += [f"# {q['id']} · {q['titre']} : {q['image'].get('recherche', '')}", f"# recherche : {lien}",
                   f"{q['id']}  ", ""]
    with open(args.sortie, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lignes))
    print(f"Modèle écrit : {args.sortie}")


def cmd_ajouter(args):
    pack = charger(args.pack)
    dossier = dossier_images(args.pack, pack, args.images)
    try:
        traiter(args, args.pack, pack, args.id, args.url, dossier)
    except Refus as e:
        print(f"\n{args.id} · REFUSÉE : {e}")
        return 1
    valider(args.pack, dossier)
    return 0


def cmd_lot(args):
    pack = charger(args.pack)
    dossier = dossier_images(args.pack, pack, args.images)
    refus = 0
    with open(args.fichier, encoding="utf-8-sig") as f:
        lignes = [l.strip() for l in f if l.strip() and not l.lstrip().startswith("#")]
    a_traiter = [l.split(None, 1) for l in lignes]
    a_traiter = [(p[0], p[1].strip()) for p in a_traiter if len(p) == 2 and p[1].strip()]
    # Un même fichier de choix peut servir à plusieurs packs : on ne garde que les dossiers de celui-ci.
    ids = {q["id"] for q in pack["questions"]}
    autres = [qid for qid, _ in a_traiter if qid not in ids]
    a_traiter = [(qid, e) for qid, e in a_traiter if qid in ids]
    print(f"{pack['pack']['id']} : {len(a_traiter)} image(s) à traiter"
          + (f" ({len(autres)} ligne(s) d'autres packs laissée(s) de côté)" if autres else ""))
    if not a_traiter:
        return 0
    for i, (qid, entree) in enumerate(a_traiter):
        try:
            traiter(args, args.pack, pack, qid, entree, dossier)
        except Refus as e:
            refus += 1
            print(f"\n{qid} · REFUSÉE : {e}")
        if i < len(a_traiter) - 1:
            time.sleep(1)  # on reste poli avec Commons
    if not args.dry_run:
        valider(args.pack, dossier)
    return 1 if refus else 0


def main(argv=None):
    for flux in (sys.stdout, sys.stderr):
        try:
            flux.reconfigure(encoding="utf-8")  # accents lisibles même quand la console est en cp1252
        except (AttributeError, ValueError):
            pass
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)

    def options(sp):
        sp.add_argument("--images", help="dossier des images (par défaut assets/images/<id du pack>)")
        sp.add_argument("--dry-run", action="store_true", help="afficher sans rien écrire")
        sp.add_argument("--yes", action="store_true", help="ne pas demander de confirmation")
        sp.add_argument("--remplacer", action="store_true", help="remplacer une image déjà vérifiée")
        sp.add_argument("--contact", help="adresse de contact à joindre au User-Agent (facultatif)")

    s = sub.add_parser("liste", help="état des 15 dossiers et liens de recherche Commons")
    s.add_argument("pack")
    s.set_defaults(fn=cmd_liste)
    s = sub.add_parser("modele", help="écrit un fichier à remplir pour la commande « lot »")
    s.add_argument("pack")
    s.add_argument("sortie")
    s.set_defaults(fn=cmd_modele)
    s = sub.add_parser("ajouter", help="intègre une image à un dossier")
    s.add_argument("pack")
    s.add_argument("id")
    s.add_argument("url")
    s.add_argument("--auteur", help="auteur, si Commons ne le donne pas (à vérifier sur la page)")
    s.add_argument("--licence", help="licence, si Commons ne la donne pas clairement (à vérifier sur la page)")
    options(s)
    s.set_defaults(fn=cmd_ajouter)
    s = sub.add_parser("lot", help="intègre plusieurs images listées dans un fichier")
    s.add_argument("pack")
    s.add_argument("fichier")
    s.set_defaults(auteur=None, licence=None)
    options(s)
    s.set_defaults(fn=cmd_lot)

    args = p.parse_args(argv)
    return args.fn(args) or 0


if __name__ == "__main__":
    sys.exit(main())
