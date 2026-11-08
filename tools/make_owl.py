#!/usr/bin/env python3
"""Dessine la chouette du jeu Chevêche (le logo) et écrit les SVG dans assets/brand/.

Le logo reprend la chouette de l'illustration du jeu (assets/brand/owl_illustration.png, page « Comment jouer »)
en version simplifiée et de face : aigrettes, contour brun sombre, disques clairs autour de grands yeux
jaunes, bec gris, poitrine en triangles, ailes orangées. Des aplats à facettes, pas de dégradé ; ni livres,
ni feuillage, ni petits traits : il doit rester lisible à la taille d'une icône.

Une seule source de dessin (ce fichier), trois « tailles optiques » : plus l'image est petite,
moins elle a de détails, pour rester lisible.
  owl_full.svg  (détaillée, à partir de ~80 px)   owl_mark.svg (moyenne, 44 à 80 px)
  owl_icon.svg  (minimale, sous 44 px)            app_icon.svg (icône d'application, carrée : la chouette en buste)
Icône Android (calques « adaptatifs ») : launcher/premier_plan.svg, la chouette entière sur fond transparent,
dans le cercle de 66 dp sur 108 que tous les lanceurs gardent visible ; le fond est un aplat olive (launcher/fond.png).
L'icône du Play Store (512 px) est produite aussi : launcher/play_store_512.png (à téléverser dans la Play Console).
Si rsvg-convert est installé, les PNG demandés par l'export Android sont produits aussi (launcher/*.png).
Couleurs : celles de l'illustration, à peine adoucies vers la terre cuite du design system (ds/ds.gd).
Usage : python3 tools/make_owl.py [dossier_de_sortie]
"""
import os
import re
import shutil
import subprocess
import sys


def mix(a, b, t):
    """Mélange de deux couleurs #RRGGBB (t = 0 : a, t = 1 : b)."""
    ca = [int(a[i:i + 2], 16) for i in (1, 3, 5)]
    cb = [int(b[i:i + 2], 16) for i in (1, 3, 5)]
    return "#" + "".join(f"{round(x + (y - x) * t):02X}" for x, y in zip(ca, cb))


# Le design system.
INK, IVORY, CARD = "#292D2A", "#F1EDE3", "#F8F5EC"
SAGE, TERRA, OCHRE = "#687B70", "#B66F55", "#C2A66D"
# Les couleurs de l'illustration, adoucies d'un quart vers la terre cuite.
DARK = mix("#6A2612", INK, 0.15)        # contours, aigrettes, doigts
RUST = mix("#AB410C", TERRA, 0.25)      # plans dans l'ombre
ORANGE = mix("#D86A1E", TERRA, 0.25)    # plumage
FLAME = mix("#E36710", TERRA, 0.2)      # ailes
AMBER = mix("#EFAF66", OCHRE, 0.15)     # plans dans la lumière, rayures des ailes
LIGHT = mix("#F2C691", CARD, 0.2)       # poitrine
CREAM = mix("#FCE6BF", CARD, 0.35)      # disques des yeux, front
EYE = "#EFA22A"                         # iris
BEAK, BEAK_LIGHT = "#3A3431", "#5C5550"
OLIVE = mix("#D4CA97", SAGE, 0.12)      # le disque derrière la chouette, comme sur l'illustration

HEAD = "M50,10 C71,10 85,21 85,37 C85,54 70,63 50,63 C30,63 15,54 15,37 C15,21 29,10 50,10 Z"
BODY = "M50,98 C29,98 19,86 19,70 C19,52 31,44 50,44 C69,44 81,52 81,70 C81,86 71,98 50,98 Z"
CHEST = "M50,56 C61,56 70,64 70,76 C70,88 61,96 50,96 C39,96 30,88 30,76 C30,64 39,56 50,56 Z"
WING_L = "M29,50 C17,54 12,70 16,93 C26,86 32,73 33,61 C33,56 32,52 29,50 Z"
WING_L_STRIPE = "M27,57 C21,63 18,73 19,86 C24,79 27,70 28,59 Z"
# L'aigrette : une touffe de plumes à deux pointes, qui part du haut de la tête vers l'extérieur.
TUFT_L = ["M17,30 Q12,17 6,8 Q15,11 21,16 Q21,9 23,2 Q31,8 40,13 Z",
          "M22,20 Q20,14 21,8 Q27,11 33,14 Z"]
EYES = ((35.5, 38), (64.5, 38))
FOREHEAD = "M43,11.5 L57,11.5 L50,34 Z"                 # le front clair, en pointe entre les yeux
BEAK_L, BEAK_R = "M45.4,40.5 L50,40.5 L50,54 Z", "M50,40.5 L54.6,40.5 L50,54 Z"
STROKE = {0: 3.4, 1: 2.8, 2: 2.3}


def mirror(d):
    """Le même tracé, retourné autour de l'axe vertical x = 50 (les points sont écrits « x,y »)."""
    return re.sub(r"(-?[\d.]+),(-?[\d.]+)", lambda m: f"{100 - float(m.group(1)):g},{m.group(2)}", d)


def path(d, fill, extra=""):
    return f'<path d="{d}" fill="{fill}"{extra}/>'


def outline(d, w):
    return f'<path d="{d}" fill="none" stroke="{DARK}" stroke-width="{w}" stroke-linejoin="round"/>'


def circle(x, y, r, fill):
    return f'<circle cx="{x:g}" cy="{y:g}" r="{r:g}" fill="{fill}"/>'


def chest_triangles(rows=6, w=8.0, h=7.0, top=57.0):
    """La poitrine en triangles : une rangée sur deux décalée d'un demi-triangle."""
    out = []
    for r in range(rows):
        y0, y1 = top + r * h, top + (r + 1) * h
        off = (r % 2) * w / 2
        x = 26 - off
        while x < 76:
            out.append(f"M{x:g},{y1:g} L{x + w / 2:g},{y0:g} L{x + w:g},{y1:g} Z")
            x += w
    return " ".join(out)


def owl(level, uid):
    """level 0 = icône minimale, 1 = moyenne, 2 = détaillée. Éléments SVG, viewBox 0 0 100 100.
    `uid` : préfixe des découpes (unique dans un même fichier)."""
    sw = STROKE[level]
    out = [f'<defs><clipPath id="{uid}h"><path d="{HEAD}"/></clipPath>'
           f'<clipPath id="{uid}b"><path d="{BODY}"/></clipPath>'
           f'<clipPath id="{uid}c"><path d="{CHEST}"/></clipPath></defs>']
    # Les aigrettes, derrière la tête.
    for i, d in enumerate(TUFT_L):
        c = DARK if i == 0 or level == 0 else mix(DARK, RUST, 0.45)
        out += [path(d, c), path(mirror(d), c)]
    # Le corps, un plan dans l'ombre à gauche, la poitrine claire en triangles.
    out.append(path(BODY, ORANGE))
    if level >= 1:
        out.append(f'<g clip-path="url(#{uid}b)">{path("M0,40 L42,40 L30,100 L0,100 Z", RUST)}</g>')
    out.append(path(CHEST, LIGHT))
    if level >= 1:
        tri = chest_triangles() if level == 2 else chest_triangles(rows=4, w=10, h=9, top=58)
        out.append(f'<g clip-path="url(#{uid}c)">{path(tri, AMBER if level == 1 else mix(AMBER, ORANGE, 0.45))}</g>')
    out.append(outline(BODY, sw))
    # Les ailes, sur les flancs.
    if level >= 1:
        for d, stripe in ((WING_L, WING_L_STRIPE), (mirror(WING_L), mirror(WING_L_STRIPE))):
            out += [path(d, FLAME), path(stripe, AMBER), outline(d, sw * 0.8)]
    if level == 2:
        for x in (37, 41.5, 46):  # les doigts, posés devant
            out += [circle(x, 97, 2.6, DARK), circle(100 - x, 97, 2.6, DARK)]
    # La tête : un plan clair en haut à droite, un plan sombre en bas à gauche, le front clair.
    out.append(path(HEAD, ORANGE))
    if level >= 1:
        out.append(f'<g clip-path="url(#{uid}h)">'
                   + path("M0,30 L26,60 L0,70 Z", RUST)
                   + path("M60,0 L100,0 L100,40 L74,20 Z", AMBER) + "</g>")
    out.append(path(FOREHEAD, CREAM))
    out.append(outline(HEAD, sw))
    # Les yeux : un disque clair cerclé de brun sur le côté, l'iris jaune, la pupille, un reflet.
    for (cx, cy), side in zip(EYES, (-1, 1)):
        out += [circle(cx, cy, 15, DARK), circle(cx - side * 2.2, cy + 0.6, 13.2, CREAM),
                circle(cx, cy, 9.6 if level else 10.5, EYE), circle(cx, cy, 5.2 if level else 6, INK)]
        if level >= 1:
            out.append(circle(cx + 2, cy - 2.2, 1.7, CARD))
    out += [path(BEAK_L, BEAK), path(BEAK_R, BEAK_LIGHT if level else BEAK)]
    return "\n  ".join(out)


def svg(level, px):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{px}" height="{px}" viewBox="0 0 100 100">\n'
            f'  {owl(level, "o")}\n</svg>\n')


def bust(s, eyes_y, uid):
    """La chouette à l'échelle `s`, les yeux à la hauteur `eyes_y` (le corps peut sortir de l'image)."""
    tx, ty = 50 - 50 * s, eyes_y - EYES[0][1] * s
    return f'<g transform="translate({tx:.2f} {ty:.2f}) scale({s})">\n  {owl(1, uid)}\n  </g>'


def app_icon(px=1024):
    """Icône carrée (Play Store, anciens lanceurs) : la chouette en buste sur l'olive du disque de l'illustration.
    Pas de coins arrondis : le Play Store et le système les appliquent."""
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{px}" height="{px}" viewBox="0 0 100 100">\n'
            f'  <rect width="100" height="100" fill="{OLIVE}"/>\n  {bust(0.92, 48, "i")}\n</svg>\n')


def launcher_foreground(px=432):
    """Premier plan de l'icône adaptative Android (108 dp de côté, fond transparent) : la chouette entière,
    aigrettes comprises, dans le cercle de sécurité de 66 dp au centre que tous les lanceurs gardent visible."""
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{px}" height="{px}" viewBox="0 0 108 108">\n'
            f'  <g transform="translate(4 4)">{bust(0.58, 46, "l")}</g>\n</svg>\n')


def launcher_background(px=432):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{px}" height="{px}" viewBox="0 0 108 108">'
            f'<rect width="108" height="108" fill="{OLIVE}"/></svg>\n')


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
                "app_icon.svg": app_icon(),
                "launcher/premier_plan.svg": launcher_foreground(), "launcher/fond.svg": launcher_background()}
    for nom, contenu in fichiers.items():
        with open(os.path.join(dossier, nom), "w", encoding="utf-8", newline="\n") as f:
            f.write(contenu)
        print("écrit", os.path.join(dossier, nom))
    # Les images de l'export Android (export_presets.cfg, launcher_icons/…).
    l = os.path.join(dossier, "launcher")
    png(os.path.join(dossier, "app_icon.svg"), os.path.join(l, "icone_192.png"), 192)
    png(os.path.join(l, "premier_plan.svg"), os.path.join(l, "premier_plan_432.png"), 432)
    png(os.path.join(l, "fond.svg"), os.path.join(l, "fond_432.png"), 432)
    png(os.path.join(dossier, "app_icon.svg"), os.path.join(l, "play_store_512.png"), 512)


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "..", "assets", "brand"))
