#!/bin/bash
# Installe le modèle de compilation Android (Gradle) dans android/build, comme le fait Godot
# (« Projet > Installer le modèle de compilation Android »), puis vide l'écran de démarrage d'Android :
# le papier ivoire, sans icône, pour que rien d'autre que la couverture n'apparaisse au lancement.
# Usage : tools/android_template.sh <dossier des modèles d'export>   (ex. ~/.local/share/godot/export_templates/4.4.1.stable)
set -euo pipefail
T="${1:?dossier des modèles d’export}"
P="$(cd "$(dirname "$0")/.." && pwd)"
rm -rf "$P/android"
mkdir -p "$P/android/build"
unzip -q "$T/android_source.zip" -d "$P/android/build"
head -n1 "$T/version.txt" > "$P/android/.build_version"   # Godot refuse un modèle d'une autre version
echo > "$P/android/build/.gdignore"                         # pour que Godot n'importe pas ce dossier
python3 "$P/tools/android_splash.py" "$P/android/build/res"
