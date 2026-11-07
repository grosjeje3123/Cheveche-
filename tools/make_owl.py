#!/usr/bin/env python3
"""Dessine la chevêche, la chouette du jeu Chevêche, et écrit les SVG dans assets/brand/.

Une chevêche d'Athéna : tête ronde sans aigrettes, calotte tachetée de blanc, sourcils clairs, yeux jaunes ;
la nôtre porte en plus des lunettes anciennes.

Une seule source de dessin (ce fichier), trois « tailles optiques » : plus l'image est petite,
moins elle a de détails et plus les traits sont épais, pour rester lisible à 48 px.
  owl_full.svg  (détaillée, à partir de ~80 px)   owl_mark.svg (moyenne, 44 à 80 px)
  owl_icon.svg  (minimale, sous 44 px)            app_icon.svg (icône d'application, carrée)
Icône Android (calques « adaptatifs ») : launcher/premier_plan.svg, la chouette seule sur fond transparent, tenue dans
le cercle de 66 dp sur 108 que tous les lanceurs gardent visible ; le fond est un aplat papier (launcher/fond.png).
Si rsvg-convert est installé, les PNG demandés par l'export Android sont produits aussi (launcher/*.png).
Couleurs : celles du design system (ds/ds.gd). Aplats uniquement : pas de dégradé, pas de reflet.
Usage : python3 tools/make_owl.py [dossier_de_sortie]
"""
import math
import os
import shutil
import subprocess
import sys

INK, IVORY, CARD = "#292D2A", "#F1EDE3", "#F8F5EC"
SAGE, TERRA, OCHRE = "#687B70", "#B66F55", "#C2A66D"

BODY = "M50,97 C24,97 9,80 9,56 C9,31 23,12.5 50,12.5 C77,12.5 91,31 91,56 C91,80 76,97 50,97 Z"  # tête ronde
CROWN_SPOTS = {  # taches blanches de la calotte (x, y, rayon), selon la taille optique
    2: [(50, 19.5, 1.8), (42.5, 16.2, 1.3), (57.5, 16.2, 1.3), (34, 17.6, 1.15), (66, 17.6, 1.15)],
    1: [(50, 19.6, 2.1), (41.5, 16.4, 1.6), (58.5, 16.4, 1.6)],
    0: [],
}
EYES = ((35, 44), (65, 44))
BEAK = "M46,51 Q50,49.5 54,51 L50,64 Z"


def arc(cx, cy, r, a0, a1):
    """Arc de cercle de a0 à a1 degrés (sens horaire, y vers le bas)."""
    x0, y0 = cx + r * math.cos(math.radians(a0)), cy + r * math.sin(math.radians(a0))
    x1, y1 = cx + r * math.cos(math.radians(a1)), cy + r * math.sin(math.radians(a1))
    return f"M{x0:.2f},{y0:.2f} A{r},{r} 0 0 1 {x1:.2f},{y1:.2f}"


def chevron(cx, y, half=4.2, depth=4.2):
    return f"M{cx - half},{y} L{cx},{y + depth} L{cx + half},{y}"


def owl(level):
    """level 0 = icône minimale, 1 = moyenne, 2 = détaillée. Renvoie les éléments SVG (viewBox 0 0 100 100)."""
    ring = {0: 3.6, 1: 3.0, 2: 2.5}[level]
    eye_r = {0: 11.2, 1: 10.0, 2: 10.0}[level]
    pupil_r = {0: 6.2, 1: 5.4, 2: 5.4}[level]
    out = [f'<path d="{BODY}" fill="{INK}"/>']
    for x, y, r in CROWN_SPOTS[level]:
        out.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{CARD}"/>')
    if level >= 1:  # sourcils clairs, au-dessus du disque facial : le regard sévère de la chevêche
        d = f"{arc(35, 44, 24.2, 205, 292)} {arc(65, 44, 24.2, 248, 335)}"
        out.append(f'<path d="{d}" fill="none" stroke="{CARD}" stroke-width="{2.6 if level == 1 else 2.1}" '
                   f'stroke-linecap="round"/>')
    for cx, cy in EYES:  # disque facial : deux cercles qui se recouvrent
        out.append(f'<circle cx="{cx}" cy="{cy}" r="21" fill="{CARD}"/>')
    for cx, cy in EYES:
        out.append(f'<circle cx="{cx}" cy="{cy}" r="{eye_r}" fill="{OCHRE}"/>')
        out.append(f'<circle cx="{cx}" cy="{cy}" r="{pupil_r}" fill="{INK}"/>')
        if level >= 1:
            out.append(f'<circle cx="{cx + 2.2}" cy="{cy - 2.4}" r="1.7" fill="{CARD}"/>')
        out.append(f'<circle cx="{cx}" cy="{cy}" r="{eye_r + 3.2}" fill="none" stroke="{INK}" '
                   f'stroke-width="{ring}"/>')
    out.append(f'<path d="M48.6,41 Q50,39.2 51.4,41" fill="none" stroke="{INK}" stroke-width="{ring * 0.8:.2f}" '
               f'stroke-linecap="round"/>')  # pont des lunettes
    if level == 2:  # branches des lunettes
        out.append(f'<path d="M20,43 L11.5,40.5 M80,43 L88.5,40.5" fill="none" stroke="{OCHRE}" '
                   f'stroke-width="2" stroke-linecap="round"/>')
    out.append(f'<path d="{BEAK}" fill="{TERRA}"/>')
    if level == 2:  # plumage de la poitrine
        d = " ".join([chevron(x, 71) for x in (34, 50, 66)] + [chevron(x, 78.5) for x in (26, 42, 58, 74)]
                     + [chevron(x, 86) for x in (34, 50, 66)])
        out.append(f'<path d="{d}" fill="none" stroke="{SAGE}" stroke-width="1.4" stroke-linecap="round" '
                   f'stroke-linejoin="round"/>')
    elif level == 1:
        d = " ".join(chevron(x, 76) for x in (34, 50, 66))
        out.append(f'<path d="{d}" fill="none" stroke="{SAGE}" stroke-width="2.2" stroke-linecap="round" '
                   f'stroke-linejoin="round"/>')
    return "\n  ".join(out)


def svg(level, px):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{px}" height="{px}" viewBox="0 0 100 100">\n'
            f'  {owl(level)}\n</svg>\n')


def app_icon(px=1024):
    """Icône carrée (Play Store, anciens lanceurs) : fond papier et la chouette seule, sans cadre.
    Pas de coins arrondis : le Play Store et le système les appliquent."""
    s = 0.78  # la chouette occupe les deux tiers de la hauteur, centrée
    tx, ty = 50 - 50 * s, 50 - 54.75 * s
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{px}" height="{px}" viewBox="0 0 100 100">\n'
            f'  <rect width="100" height="100" fill="{IVORY}"/>\n'
            f'  <g transform="translate({tx:.2f} {ty:.2f}) scale({s})">\n  {owl(1)}\n  </g>\n</svg>\n')


def launcher_foreground(px=432):
    """Premier plan de l'icône adaptative Android (108 dp de côté) : la chouette seule, fond transparent,
    tenue dans le cercle de sécurité de 66 dp au centre (le lanceur découpe le reste)."""
    s = 0.60
    tx, ty = 54 - 50 * s, 54 - 54.75 * s
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{px}" height="{px}" viewBox="0 0 108 108">\n'
            f'  <g transform="translate({tx:.2f} {ty:.2f}) scale({s})">\n  {owl(1)}\n  </g>\n</svg>\n')


def launcher_background(px=432):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{px}" height="{px}" viewBox="0 0 108 108">'
            f'<rect width="108" height="108" fill="{IVORY}"/></svg>\n')


def png(svg_path, png_path, px):
    """SVG → PNG avec rsvg-convert, s'il est là ; sinon rien (les PNG du dépôt restent valables)."""
    if not shutil.which("rsvg-convert"):
        print("rsvg-convert absent :", png_path, "non régénéré")
        return
    subprocess.run(["rsvg-convert", "-w", str(px), "-h", str(px), "-o", png_path, svg_path], check=True)
    print("écrit", png_path)


def main(dossier):
    os.makedirs(os.path.join(dossier, "launcher"), exist_ok=True)
    fichiers = {"owl_full.svg": svg(2, 512), "owl_mark.svg": svg(1, 160), "owl_icon.svg": svg(0, 88),
                "app_icon.svg": app_icon(), "launcher/premier_plan.svg": launcher_foreground(),
                "launcher/fond.svg": launcher_background()}
    for nom, contenu in fichiers.items():
        with open(os.path.join(dossier, nom), "w", encoding="utf-8", newline="\n") as f:
            f.write(contenu)
        print("écrit", os.path.join(dossier, nom))
    # Les images de l'export Android (export_presets.cfg, launcher_icons/…).
    l = os.path.join(dossier, "launcher")
    png(os.path.join(dossier, "app_icon.svg"), os.path.join(l, "icone_192.png"), 192)
    png(os.path.join(l, "premier_plan.svg"), os.path.join(l, "premier_plan_432.png"), 432)
    png(os.path.join(l, "fond.svg"), os.path.join(l, "fond_432.png"), 432)


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "..", "assets", "brand"))
