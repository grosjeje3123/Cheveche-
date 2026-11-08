#!/usr/bin/env python3
"""Vide l'écran de démarrage d'Android dans le modèle Gradle de Godot (android/build/res).

Le modèle montre, au lancement, le premier plan de l'icône sur son fond (thème GodotAppSplashTheme).
Ici : fond ivoire (#F1EDE3, le papier du jeu), icône transparente, et la même couleur sous le jeu
le temps que Godot dessine sa première image. Usage : python3 tools/android_splash.py android/build/res
"""
import os
import sys

PAPIER = "#FFF1EDE3"


def main(res):
    with open(os.path.join(res, "values", "cheveche_couleurs.xml"), "w", encoding="utf-8") as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
                f'\t<color name="cheveche_papier">{PAPIER}</color>\n</resources>\n')
    p = os.path.join(res, "values", "themes.xml")
    s = open(p, encoding="utf-8").read()
    changes = [
        ('<item name="android:windowSplashScreenBackground">@mipmap/icon_background</item>',
         '<item name="android:windowSplashScreenBackground">@color/cheveche_papier</item>\n'
         '\t\t<item name="windowSplashScreenBackground">@color/cheveche_papier</item>'),
        ('<item name="windowSplashScreenAnimatedIcon">@mipmap/icon_foreground</item>',
         '<item name="windowSplashScreenAnimatedIcon">@android:color/transparent</item>'),
        ('<item name="android:windowSwipeToDismiss">false</item>',
         '<item name="android:windowSwipeToDismiss">false</item>\n'
         '\t\t<item name="android:windowBackground">@color/cheveche_papier</item>'),
    ]
    for old, new in changes:
        if old not in s:
            sys.exit(f"themes.xml : « {old} » introuvable (le modèle de Godot a changé ?)")
        s = s.replace(old, new, 1)
    with open(p, "w", encoding="utf-8") as f:
        f.write(s)
    print("écran de démarrage vide :", p)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "android/build/res")
