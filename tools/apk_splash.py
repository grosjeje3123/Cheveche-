#!/usr/bin/env python3
"""APK exporté par Godot sans Gradle (préréglage « Android ») : écran de démarrage d'Android vide.
Le thème du modèle montre l'icône (premier plan) sur le fond de l'icône ; on remplace, dans resources.arsc,
l'icône par @android:color/transparent et le fond par l'ivoire #F1EDE3 (le papier du jeu).
L'AAB, lui, passe par Gradle : tools/android_template.sh règle le même écran dans le modèle.
Les identifiants viennent du modèle de Godot 4.4.1 ; s'ils changent, le script s'arrête sans rien écrire.
L'APK produit n'est plus signé : le signer ensuite (apksigner, ou uber-apk-signer qui l'aligne aussi).
Usage : python3 tools/apk_splash.py entrée.apk sortie.apk"""
import struct, sys, zipfile

ICON_FG, ICON_BG = 0x7f0a0002, 0x7f0a0001          # @mipmap/icon_foreground, @mipmap/icon_background
ATTR_ICON, ATTR_BG = 0x7f030013, 0x0101062c         # windowSplashScreenAnimatedIcon, android:windowSplashScreenBackground
TRANSPARENT, IVORY = 0x0106000d, 0xFFF1EDE3         # @android:color/transparent, ivoire opaque
REF, ARGB8 = 0x01, 0x1c


def patch(b: bytes) -> bytes:
    b = bytearray(b)
    n = 0
    old = struct.pack("<IHBBI", ATTR_ICON, 8, 0, REF, ICON_FG)
    new = struct.pack("<IHBBI", ATTR_ICON, 8, 0, REF, TRANSPARENT)
    i = b.find(old)
    while i != -1:
        b[i:i + 12] = new; n += 1; i = b.find(old, i + 12)
    old = struct.pack("<IHBBI", ATTR_BG, 8, 0, REF, ICON_BG)
    new = struct.pack("<IHBBI", ATTR_BG, 8, 0, ARGB8, IVORY)
    i = b.find(old)
    while i != -1:
        b[i:i + 12] = new; n += 1; i = b.find(old, i + 12)
    if n < 2:
        sys.exit(f"thème de démarrage introuvable ({n} entrée(s) changée(s))")
    print(n, "entrées changées")
    return bytes(b)


src, dst = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(src) as zi:
    arsc = patch(zi.read("resources.arsc"))  # d'abord : en cas d'échec, rien n'est écrit
    with zipfile.ZipFile(dst, "w") as zo:
        for info in zi.infolist():
            if info.filename.startswith("META-INF/") and info.filename.rsplit(".", 1)[-1] in ("SF", "RSA", "MF", "EC", "DSA"):
                continue  # l'ancienne signature ne vaut plus
            data = zi.read(info.filename)
            if info.filename == "resources.arsc":
                data = arsc
                info.compress_type = zipfile.ZIP_STORED  # Android le veut non compressé
            zo.writestr(info, data)
