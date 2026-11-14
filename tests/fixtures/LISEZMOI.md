# Sauvegarde de référence

Ces trois fichiers ont été écrits par la version 0.9.35 du jeu (commit `c67ca83`), avant toute retouche de `core/save_store.gd` :

- `progress_0_9_35.json` : une progression de trois semaines (132 dossiers joués, défis du jour, favoris) ;
- `code_0_9_35.txt` : le code de sauvegarde « CHEVECHE1-… » de cette même progression ;
- `attendu_0_9_35.json` : les chiffres que la 0.9.35 en tirait (dossiers trouvés, niveaux, jours de suite, semaine…).

`tests/test_sauvegarde.gd` les relit à chaque version : tant qu'il passe, une sauvegarde de joueur de la 0.9.35 donne
exactement les mêmes chiffres. **Ne pas les régénérer** : c'est leur ancienneté qui fait leur valeur. Pour une future
version du format, ajouter une nouvelle série de fichiers à côté de celle-ci.
