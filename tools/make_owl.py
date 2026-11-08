#!/usr/bin/env python3
"""Dessine la chevêche, la chouette du jeu Chevêche, et écrit les SVG dans assets/brand/.

Une chevêche d'Athéna : tête large et ronde, sans aigrettes (c'est une chouette, pas un hibou), calotte
tachetée de blanc, sourcils blancs qui se rejoignent au-dessus du bec, yeux jaunes, moustache blanche,
plumage brun moucheté. Dessin à facettes : des aplats, quelques plans plus clairs ou plus sombres,
la poitrine en triangles. Pas de dégradé, pas de reflet.

Une seule source de dessin (ce fichier), trois « tailles optiques » : plus l'image est petite,
moins elle a de détails, pour rester lisible.
  owl_full.svg  (détaillée, à partir de ~80 px)   owl_mark.svg (moyenne, 44 à 80 px)
  owl_icon.svg  (minimale, sous 44 px)            owl_scene.svg (la chouette sur ses livres : « Comment jouer »)
  app_icon.svg  (icône d'application, carrée : la chouette en buste sur l'ardoise)
Icône Android (calques « adaptatifs ») : launcher/premier_plan.svg, la chouette en buste sur fond transparent, la tête
dans le cercle de 66 dp sur 108 que tous les lanceurs gardent visible ; le fond est un aplat ardoise (launcher/fond.png).
L'icône du Play Store (512 px) est produite aussi : launcher/play_store_512.png (à téléverser dans la Play Console).
Si rsvg-convert est installé, les PNG demandés par l'export Android sont produits aussi (launcher/*.png).
Couleurs : celles du design system (ds/ds.gd), plus une gamme de bruns tirée de la terre cuite.
Usage : python3 tools/make_owl.py [dossier_de_sortie]
"""
import math
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
INK, IVORY, CARD, IVORY_DEEP = "#292D2A", "#F1EDE3", "#F8F5EC", "#E7E1D1"
SAGE, TERRA, OCHRE, SLATE = "#687B70", "#B66F55", "#C2A66D", "#34423A"
# Les bruns de la chouette, tirés de la terre cuite.
BROWN_DARK = mix(TERRA, INK, 0.62)      # contours, doigts, cercle des yeux
BROWN = mix(TERRA, INK, 0.30)           # plans dans l'ombre, ailes
BROWN_LIGHT = mix(TERRA, OCHRE, 0.55)   # plans dans la lumière
SAND = mix(mix(OCHRE, TERRA, 0.25), CARD, 0.5)  # disque facial, poitrine
EYE = "#E2AA3C"                         # le jaune de la chevêche : un ocre vif
BEAK_LIGHT = mix(INK, CARD, 0.22)
SAGE_PALE = mix(SAGE, IVORY, 0.68)
SAGE_DARK = mix(SAGE, INK, 0.30)
BOOK_RED = mix(TERRA, INK, 0.18)

HEAD = "M50,8 C71,8 85,19 85,35 C85,52 70,62 50,62 C30,62 15,52 15,35 C15,19 29,8 50,8 Z"
BODY = "M50,98 C29,98 19,86 19,70 C19,52 31,43 50,43 C69,43 81,52 81,70 C81,86 71,98 50,98 Z"
CHEST = "M50,55 C61,55 70,63 70,75 C70,88 61,96 50,96 C39,96 30,88 30,75 C30,63 39,55 50,55 Z"
WING_L = "M29,49 C17,53 12,69 16,93 C26,86 32,73 33,61 C33,55 32,51 29,49 Z"
WING_L_LIGHT = "M27,55 C20,61 17,72 18,86 C24,79 28,69 29,57 Z"
EYES = ((36, 36), (64, 36))
BROW_L = "M21,27.5 Q33,15.5 48.5,30 Q35,22 21,27.5 Z"
BEAK_L, BEAK_R = "M46.6,37.5 L50,37.5 L50,49 Z", "M50,37.5 L53.4,37.5 L50,49 Z"
CROWN_SPOTS = {  # taches blanches de la calotte (x, y, rayon)
    2: [(50, 12.8, 1.5), (42, 13.8, 1.25), (58, 13.8, 1.25), (34.5, 16.6, 1.1), (65.5, 16.6, 1.1),
        (46, 18.2, 0.9), (54, 18.2, 0.9), (28.5, 21, 0.9), (71.5, 21, 0.9)],
    1: [(50, 13.2, 1.9), (41, 14.6, 1.6), (59, 14.6, 1.6)],
    0: [],
}
WING_SPOTS = [(21.5, 62, 1.1), (19.5, 70, 1.1), (24.5, 68, 1.0), (21, 78, 1.0)]


def mirror(d):
    """Le même tracé, retourné autour de l'axe vertical x = 50 (les points sont écrits « x,y »)."""
    return re.sub(r"(-?[\d.]+),(-?[\d.]+)", lambda m: f"{100 - float(m.group(1)):g},{m.group(2)}", d)


def path(d, fill, extra=""):
    return f'<path d="{d}" fill="{fill}"{extra}/>'


def circle(x, y, r, fill):
    return f'<circle cx="{x:g}" cy="{y:g}" r="{r:g}" fill="{fill}"/>'


def chest_triangles(rows=6, w=8.0, h=7.0, top=56.0):
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


def owl(level, uid, tilt=0.0, look=(0.0, 0.0)):
    """level 0 = icône minimale, 1 = moyenne, 2 = détaillée. Éléments SVG, viewBox 0 0 100 100.
    `tilt` : la tête penchée (degrés) ; `look` : décalage des pupilles. `uid` : préfixe des découpes."""
    out = [f'<defs><clipPath id="{uid}h"><path d="{HEAD}"/></clipPath>'
           f'<clipPath id="{uid}b"><path d="{BODY}"/></clipPath>'
           f'<clipPath id="{uid}c"><path d="{CHEST}"/></clipPath></defs>']
    # Le corps, avec un plan dans l'ombre à gauche.
    out.append(path(BODY, TERRA))
    if level >= 1:
        out.append(f'<g clip-path="url(#{uid}b)">{path("M0,40 L44,40 L30,100 L0,100 Z", BROWN)}</g>')
    # La poitrine : claire, en triangles.
    if level >= 1:
        out.append(path(CHEST, SAND))
    if level == 2:
        out.append(f'<g clip-path="url(#{uid}c)">{path(chest_triangles(), BROWN_LIGHT)}</g>')
    elif level == 1:
        out.append(f'<g clip-path="url(#{uid}c)">{path(chest_triangles(rows=3, w=10, h=9, top=66), BROWN_LIGHT)}</g>')
    # Les ailes, posées sur les flancs.
    if level >= 1:
        for d in (WING_L, mirror(WING_L)):
            out.append(path(d, BROWN))
        for d in (WING_L_LIGHT, mirror(WING_L_LIGHT)):
            out.append(path(d, TERRA))
    if level == 2:
        for x, y, r in WING_SPOTS:
            out += [circle(x, y, r, CARD), circle(100 - x, y, r, CARD)]
        for x in (35.5, 39.5, 43.5):  # les doigts, posés devant
            out += [circle(x, 97, 2.5, BROWN_DARK), circle(100 - x, 97, 2.5, BROWN_DARK)]
    # La tête.
    head = [path(HEAD, TERRA)]
    if level >= 1:
        head.append(f'<g clip-path="url(#{uid}h)">'
                    + path("M0,0 L36,0 L24,30 L14,70 L0,70 Z", BROWN)
                    + path("M62,0 L100,0 L100,44 L76,17 Z", BROWN_LIGHT) + "</g>")
    for x, y, r in CROWN_SPOTS[level]:
        head.append(circle(x, y, r, CARD))
    for cx, cy in EYES:  # le disque facial : deux cercles qui se recouvrent
        head.append(circle(cx, cy, 15.5, SAND))
    lx, ly = look
    for cx, cy in EYES:
        head += [circle(cx, cy, 11.2 if level else 12, BROWN_DARK), circle(cx, cy, 8.2 if level else 9, EYE),
                 circle(cx + lx, cy + ly, 4.5 if level else 5.2, INK)]
        if level >= 1:
            head.append(circle(cx + lx + 1.7, cy + ly - 1.9, 1.5, CARD))
    for d in (BROW_L, mirror(BROW_L)):  # sourcils blancs : le regard sévère de la chevêche
        head.append(path(d, CARD))
    head += [path(BEAK_L, INK), path(BEAK_R, BEAK_LIGHT if level else INK)]
    if tilt:
        out.append(f'<g transform="rotate({tilt:g} 50 58)">' + "".join(head) + "</g>")
    else:
        out += head
    return "\n  ".join(out)


def svg(level, px):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{px}" height="{px}" viewBox="0 0 100 100">\n'
            f'  {owl(level, "o")}\n</svg>\n')


def leaf(x, y, angle, length, width):
    """Une feuille en amande, coupée en deux le long de la nervure : une moitié claire, une sombre."""
    a = math.radians(angle)
    ux, uy = math.cos(a), math.sin(a)
    nx, ny = -uy, ux
    tx, ty = x + ux * length, y + uy * length
    mx, my = x + ux * length * 0.45, y + uy * length * 0.45
    p1 = (mx + nx * width, my + ny * width)
    p2 = (mx - nx * width, my - ny * width)
    half = lambda p, c: path(f"M{x:.1f},{y:.1f} Q{p[0]:.1f},{p[1]:.1f} {tx:.1f},{ty:.1f} Z", c)
    return half(p1, SAGE) + half(p2, SAGE_DARK)


def sprig(x0, y0, x1, y1, bend, leaves):
    """Un rameau : une tige courbe et des feuilles alternées (position 0 à 1, côté, longueur)."""
    cx, cy = (x0 + x1) / 2 + bend, (y0 + y1) / 2
    out = [f'<path d="M{x0},{y0} Q{cx:.1f},{cy:.1f} {x1},{y1}" fill="none" stroke="{SAGE_DARK}" '
           f'stroke-width="1.6" stroke-linecap="round"/>']
    for t, side, ln in leaves:
        px = (1 - t) ** 2 * x0 + 2 * (1 - t) * t * cx + t * t * x1
        py = (1 - t) ** 2 * y0 + 2 * (1 - t) * t * cy + t * t * y1
        dx = 2 * (1 - t) * (cx - x0) + 2 * t * (x1 - cx)
        dy = 2 * (1 - t) * (cy - y0) + 2 * t * (y1 - cy)
        ang = math.degrees(math.atan2(dy, dx)) + side * 48
        out.append(leaf(px, py, ang, ln, ln * 0.3))
    tip = math.degrees(math.atan2(y1 - cy, x1 - cx))
    out.append(leaf(x1, y1, tip, 15, 4.6))
    return "".join(out)


def book(x, y, w, h, cover):
    """Un livre couché, dos vers nous : la couverture, deux filets dorés, la tranche des pages à droite."""
    pw = min(24, w * 0.24)
    lines = "".join(f'<path d="M{x + w - pw:g},{y + h * f:.1f} L{x + w - 1.2:g},{y + h * f:.1f}" '
                    f'stroke="{IVORY_DEEP}" stroke-width="0.8"/>' for f in (0.38, 0.62))
    return (f'<rect x="{x:g}" y="{y:g}" width="{w:g}" height="{h:g}" rx="2.2" fill="{cover}"/>'
            f'<rect x="{x + w - pw:g}" y="{y + 2.4:g}" width="{pw - 1.2:g}" height="{h - 4.8:g}" fill="{CARD}"/>'
            + lines
            + "".join(f'<rect x="{x + d:g}" y="{y:g}" width="1.8" height="{h:g}" fill="{OCHRE}"/>' for d in (9, 14))
            + f'<rect x="{x:g}" y="{y + h - 1.6:g}" width="{w - pw:g}" height="1.6" fill="{mix(cover, INK, 0.35)}"/>')


def scene(px=720):
    """La chouette sur deux livres, devant un disque sauge et deux rameaux (page « Comment jouer »)."""
    s = 1.32
    tx, ty = 100 - 50 * s, 153.5 - 98 * s
    parts = [
        circle(100, 90, 74, SAGE_PALE),
        sprig(50, 158, 18, 70, -10, [(0.18, -1, 20), (0.36, 1, 20), (0.54, -1, 19), (0.72, 1, 17), (0.88, -1, 15)]),
        sprig(150, 162, 188, 100, 12, [(0.22, 1, 19), (0.45, -1, 18), (0.68, 1, 16), (0.86, -1, 14)]),
        f'<ellipse cx="102" cy="187" rx="64" ry="4" fill="{IVORY_DEEP}"/>',
        book(52, 168, 100, 17, BOOK_RED),
        book(60, 152, 84, 16, SLATE),
        f'<g transform="translate({tx:.2f} {ty:.2f}) scale({s})">\n  {owl(2, "s", tilt=-7, look=(1.4, -1.2))}\n  </g>',
    ]
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{px}" height="{px}" viewBox="0 0 200 200">\n  '
            + "\n  ".join(parts) + "\n</svg>\n")


def bust(s, eyes_y, uid):
    """La chouette en buste : les yeux à la hauteur `eyes_y`, le corps coupé par le bord de l'image."""
    tx, ty = 50 - 50 * s, eyes_y - EYES[0][1] * s
    return f'<g transform="translate({tx:.2f} {ty:.2f}) scale({s})">\n  {owl(1, uid)}\n  </g>'


def app_icon(px=1024):
    """Icône carrée (Play Store, anciens lanceurs) : la chouette en buste sur l'ardoise, le vert profond
    de la couche à gratter. Pas de coins arrondis : le Play Store et le système les appliquent."""
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{px}" height="{px}" viewBox="0 0 100 100">\n'
            f'  <rect width="100" height="100" fill="{SLATE}"/>\n  {bust(1.0, 45, "i")}\n</svg>\n')


def launcher_foreground(px=432):
    """Premier plan de l'icône adaptative Android (108 dp de côté, fond transparent). La tête tient dans le
    cercle de sécurité de 66 dp au centre ; le corps descend jusqu'au bord, que le lanceur découpe."""
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{px}" height="{px}" viewBox="0 0 108 108">\n'
            f'  <g transform="translate(4 4)">{bust(0.78, 47, "l")}</g>\n</svg>\n')


def launcher_background(px=432):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{px}" height="{px}" viewBox="0 0 108 108">'
            f'<rect width="108" height="108" fill="{SLATE}"/></svg>\n')


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
                "owl_scene.svg": scene(), "app_icon.svg": app_icon(),
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
