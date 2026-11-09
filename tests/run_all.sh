#!/bin/bash
# Lance tous les tests du jeu en mode sans écran.
# Usage : tests/run_all.sh /chemin/vers/Godot   (depuis la racine du projet)
G="${1:-godot}"
P="$(cd "$(dirname "$0")/.." && pwd)"
D="$P/assets/images/svt_01"
cleanup() { rm -f "$D"/_test_photo.png* "$P"/.godot/imported/_test_photo* ; }
trap cleanup EXIT
python3 "$P/tests/make_fixture.py" "$D/_test_photo.png" || exit 2
timeout 600 "$G" --headless --path "$P" --import > /dev/null 2>&1
rc=0
run() {
  local name="$1"; shift
  local out
  out=$(timeout 400 "$G" --headless "$@" --path "$P" --script "res://tests/$name.gd" 2>&1)
  if echo "$out" | grep -q "TOUT EST OK"; then
    echo "OK    $name"
  else
    echo "ÉCHEC $name"; echo "$out" | grep -E "FAIL|ERROR|ÉCHEC|Parse" | head -20; rc=1
  fi
}
for t in test_complete test_images test_nav test_play test_sauvegarde test_week test_features test_step6 test_regles test_maitrise test_carnet; do run "$t"; done
run test_marges --resolution 720x1600
exit $rc
