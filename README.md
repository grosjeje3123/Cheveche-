# Chevêche – prototype (Godot 4.4)

Le jeu s’est appelé L’INDICE jusqu’à la version 0.9.17 ; le dossier et les fichiers internes gardent parfois ce nom (« lindice »).

État : design system, couverture, « Mes résultats », QCM à quatre choix, grattage **facultatif** de l’image (deux indices à la clé),
points, explication après chaque réponse, fiches jouées en continu, défi du jour avec sa page de résultat, progression sauvegardée sur l’appareil, 270 dossiers en seize packs : 30 par discipline (Nature, Animaux, Sciences, Astronomie, Histoire, Arts, Géographie, Littérature), plus 30 dossiers experts pour le niveau 2 de l’Astronomie
(questions qui se comprennent sans l’image).
Tablettes : le jeu s’installe et se joue tel quel, en portrait (étirement « expand » : sur une tablette 16:10 l’écran fait
800 × 1280 unités, sur une 4:3, 960 × 1280 ; la mise en page s’élargit, rien ne déborde). Pas de mode paysage pour l’instant.
Pas encore : publication sur le Play Store, autres disciplines.

## Lancer
Ouvrir le dossier dans Godot 4 (`project.godot`), puis F5 : l’application démarre sur l’accueil.
Guide de style seul : ouvrir `styleguide.tscn` et lancer la scène (F6).
Portrait 720 × 1280 ; souris et tactile (Godot convertit le tactile en souris par défaut).
L’orientation portrait est demandée deux fois : réglage du projet (Affichage > Fenêtre > Handheld > Orientation) et, sur mobile,
au lancement dans `main.gd`. Il faut **réexporter** l’application après tout changement de ce réglage.

## Tester sur téléphone (Android)
- **Le plus simple : installer le fichier `cheveche.apk`** fourni à côté du projet (signé avec une clé de test). Sur le
  téléphone : ouvrir le fichier, autoriser l’installation d’applications inconnues pour l’appli qui l’ouvre, installer.
  Une nouvelle version s’installe par-dessus l’ancienne et garde la progression.
- **L’exporter soi-même depuis Godot** : préréglage « Android » déjà fourni (`export_presets.cfg` : portrait, plein écran,
  autorisation VIBRATE, nom « Chevêche », identifiant définitif `fr.hosdez.cheveche` depuis la 0.9.27 (avant : `fr.lindice.prototype`), ARMv7 et ARM64). Il faut installer dans
  Godot les modèles d’export 4.4.1 (Éditeur > Gérer les modèles d’export), un JDK 17 et le SDK Android (outils
  « platform-tools » et « build-tools »), puis renseigner leurs chemins dans Éditeur > Paramètres de l’éditeur > Export > Android.
  Avec le téléphone branché en USB (débogage USB activé), le bouton « déployer » de Godot installe et lance le jeu directement.
- Le réglage `rendering/textures/vram_compression/import_etc2_astc` est activé : Godot l’exige pour Android.
- Pour le Play Store, plus tard : compte développeur Google, clé de signature définitive (à garder précieusement), format AAB.

## Règles du jeu (dans `core/reveal_rules.gd`)
- On peut **répondre tout de suite**, sans rien gratter : les quatre réponses sont ouvertes dès le départ et le dossier vaut 100 points.
- Gratter est une **aide** qui coûte des points : on gratte l’image du dossier, et **deux indices** se débloquent à **25 %** et **50 %**
  de surface grattée. L’image se révèle au fil du grattage (elle illustre le sujet, elle n’est pas indispensable).
- La réponse donnée, la couche s’effrite et les deux indices deviennent lisibles.
- **Difficulté** : chaque dossier a une difficulté de 1 (très accessible) à 5 (pour spécialistes) (champ `difficulte` des
  packs, schéma 4 ; les anciens mots « facile », « moyenne », « difficile » se lisent 2, 3 et 4). Sur 270 dossiers : 86 de
  difficulté 1, 93 de 2, 66 de 3, 23 de 4, 2 de 5 (ceux-là dans le niveau 2 de l’Astronomie). Le bandeau de la carte la montre
  par cinq barres montantes avant le numéro (`ds/ds_level.gd`). Un dossier de difficulté 4 ou 5 manqué fait dire
  « Pas tout à fait. Peu de gens le savent. » ; trouvé sans indice du premier coup, c’est une pépite (plus bas).
- **Niveau par discipline** (`core/mastery.gd`), calculé sur l’appareil à partir de la *première* réponse à chaque dossier
  (champ `first` de la sauvegarde ; déduit pour les anciennes sauvegardes) : Découverte, Curieux, Érudit, Expert, Grand Hibou.
  Un modèle simple (la chance de réussir un dossier dépend de l’écart entre le niveau du joueur et la difficulté) pèse chaque
  réponse par ses points : réussir sans indice un dossier difficile fait beaucoup monter, rater un facile fait un peu baisser.
  Pour être Expert, il faut au moins deux dossiers de difficulté 4 réussis (60 points ou plus) ; pour Grand Hibou, deux de
  difficulté 5. Le niveau s’annonce après 6 dossiers d’une discipline : « Mes résultats » l’écrit sous chaque discipline, et
  l’explication d’un dossier ajoute « Astronomie : votre niveau est Curieux. », puis « Astronomie : vous passez Érudit. »
  quand il monte (rien quand il baisse).
- **Points** (`core/scoring.gd`) : 100 sans indice, 60 avec un, 30 avec deux ; 0 si la réponse est fausse
  (jamais de points en moins). Seuls comptent les indices lus *avant* de répondre. Le total possible du défi du jour (5 dossiers) est 500.
- **Mise en page** (constantes en tête de `screens/play_screen.gd`) : l’image fait de 260 à 330 px de haut et les lignes de réponse de
  72 à 96 px ; sur un téléphone allongé, la place en trop va d’abord aux réponses, puis à l’air autour de la carte, puis au bas de l’écran.
- Après la réponse, l’explication, l’anecdote et le crédit de l’image prennent la place des quatre réponses : elle occupe d’abord l’air
  libre en bas, puis la carte cède jusqu’à 120 px, l’image gardant au moins 200 px ; le texte défile au doigt s’il est plus long.
- Les **fiches** (« Au hasard » et les 8 disciplines) se jouent **par séries de 10 dossiers** (`main.SERIES_LENGTH`) : les dossiers
  s’enchaînent (« Dossier suivant ») ; au dixième, le bouton devient « Voir le bilan ». On peut aussi s’arrêter avant avec la flèche
  retour (chaque réponse est déjà enregistrée) : le bilan vient alors pour les dossiers joués. En haut de l’écran : les dossiers
  trouvés dans la fiche (« 12 / 30 trouvés », 240 pour « Au hasard ») et une barre fine remplie d’autant.
- **Bilan de série** (`screens/result_screen.gd`, `main._show_series_result`) : la chouette sur ses livres, une courte pluie de
  papier découpé aux couleurs du carnet (`ds/paper_confetti.gd`, 2,6 s, seulement si au moins la moitié des dossiers est trouvée),
  les points, « 8 dossiers trouvés sur 10, dont 1 pépite. », le niveau dans la discipline (« Astronomie : vous passez Érudit ! »),
  puis chaque dossier avec ses cinq barres de difficulté, ses points et, s’il y a lieu, « pépite ». « Série suivante » reprend la
  file au onzième dossier ; « Retour à la couverture ». Au bout de la file (tous les dossiers de la fiche vus), le bilan n’a que
  le retour. Le défi du jour finit sur le même bilan (chouette et papier), avec son tampon dateur.
- **Pépite** (`main.is_pepite`, `PlayScreen.show_pepite`) : un dossier de difficulté 4 ou 5, trouvé sans indice la toute première
  fois qu’on le rencontre. Le jeu dit « Exact, sans aucun indice. Une pépite ! » et un tampon ocre « Pépite · peu le savent »
  tombe dans le coin de l’image ; le bilan compte les pépites de la série.
- **Ordre** (`SaveStore.draw`) : toute la fiche, en trois paquets : les dossiers pas encore trouvés, puis ceux
  trouvés avec un indice, puis ceux trouvés sans indice. Dans chaque paquet, **la difficulté monte**, mélangée à l’intérieur
  de chaque difficulté ; « Au hasard » mêle ainsi toutes les disciplines. **La fiche s’adapte au joueur** : les dossiers pas
  encore trouvés commencent à la difficulté qui lui convient (`Mastery.start_level`, un peu au-dessus de son niveau ; le tout
  premier dossier d’une discipline est le plus accessible), les plus faciles passant à la fin ; et la suite de la file est
  retirée après chaque réponse (`main._adapt_queue`, `PlayScreen.set_upcoming`), sans reproposer les dossiers déjà joués.
- **Délai avant le retour** (`SaveStore.is_due`, champ `revoir` de la sauvegarde) : un dossier raté, ou trouvé avec un indice,
  ne revient dans les fiches qu’à partir du lendemain : on ne le rejoue pas avec la réponse encore en tête (le défi du jour,
  lui, ne change pas). Trouvé sans indice, il n’a plus de date de retour. Au début de la révision (dossiers déjà trouvés
  sans indice), la consigne dit « Révision : les 4 dossiers à revoir reviendront demain. » ; au bout de la file, l’explication
  finit par « La suite demain : … ». Une fiche où tout est à revoir demain ne s’ouvre pas : la couverture l’écrit sous le titre.
- **Fiche complète** (`screens/complete_screen.gd`) : la réponse qui fait trouver le 30e dossier d’une discipline (dans une fiche,
  « Au hasard » ou le défi) fait venir, au lieu du dossier suivant, une page tamponnée (`ds/ds_stamp.gd`, terre cuite,
  qui tombe sur la page avec un « tchok » de tampon synthétisé, `stamp.wav`, et une courte vibration, puis le jingle de fin) : points de la fiche (meilleur score de chaque dossier, sur 3 000), dossiers trouvés sans indice,
  et le nouvel objectif. « Continuer » reprend le jeu ; la flèche retour, juste après la réponse, montre la page puis ramène à la
  couverture. Second objectif : trouver chaque dossier **sans indice** (meilleur score de 100, `SaveStore.is_flawless`) ;
  la fiche complète affiche alors « 18 / 30 sans indice » en haut du jeu, et le 30e sans indice donne la page « Sans faute »
  (tampon plein). Sur la couverture, une fiche complète porte un petit tampon en haut à droite (plein si sans faute) ;
  « Mes résultats » indique « Complète, 18 sans indice » ou « Sans faute ».
- Un dossier est **trouvé** dès qu’on y répond juste une fois (avec ou sans indice). « Mes résultats » et la couverture comptent
  les dossiers trouvés ; ceux qui ne le sont pas encore passent en premier quand on joue une fiche (texte affiché sur « Mes résultats »).
- **Bilan de la semaine** (écran « Mes résultats », section « Cette semaine ») : points de chaque jour du lundi au dimanche, total de
  points, dossiers trouvés sur joués, jours joués, meilleure journée et total de la semaine précédente. Il se calcule
  à partir de l’historique par jour de la sauvegarde (120 derniers jours gardés ; `core/week.gd` pour le calendrier).
  Les sauvegardes d’avant cette version restent lisibles ; leur historique commence au premier jeu.
- **Sauvegarde** (`core/save_store.gd`) : `user://progress.json`, écrite à chaque réponse (écriture dans un fichier
  temporaire puis renommage). Une sauvegarde illisible est mise de côté (`.bad`) et on repart de zéro. Rien n’est envoyé.
  Pour tout remettre à zéro : supprimer ce fichier (Éditeur Godot → Projet → Ouvrir le dossier des données utilisateur).

## Niveau 2
- Un pack dont l’en-tête porte `"niveau": 2` contient des dossiers pointus d’une discipline (premier : `astro_n2_01.json`,
  Astronomie, nº 131 à 160). Ils sont à part (`QuestionPack.expert`) : ils ne comptent ni dans les 30 dossiers de la fiche,
  ni dans « Au hasard », ni dans le défi du jour, ni dans le total de « Mes résultats ».
- Le niveau 2 s’ouvre quand la fiche de base est complète : la page « Fiche complète » l’annonce et propose « Jouer le
  niveau 2 » (« Plus tard » reprend le jeu). La fiche s’agrandit alors de ses 30 dossiers pointus, qui passent en tête
  (pas encore trouvés), à partir de la difficulté qui convient au joueur (champ `difficulte`, sur la même échelle de 1 à 5).
- En haut du jeu : « 4 / 30 niveau 2 », puis « sans indice ». Sur la carte, « niveau 2 » remplace les barres de niveau.
  Sur la couverture, la fiche porte « niveau 2 » et sa barre suit le niveau 2 ; « Mes résultats » dit « Niveau 2 : … ».
  Le niveau 2 terminé a sa propre page, au tampon anthracite.
- Ajouter un niveau 2 ailleurs : un pack `xxx_n2_01.json` (`"niveau": 2`, numéros libres), ajouté à `PACK_PATHS` dans `main.gd`.

## Défi du jour
- Carte « Défi du jour » sur la couverture : 5 dossiers, dans 5 disciplines différentes, en escalier, de la difficulté 1
  à la 5 (`Daily.CURVE` ; la plus proche si une discipline n’a pas la bonne, puis rangés du plus accessible au plus difficile), **les mêmes pour tout le monde**
  le même jour (à pack égal) : le tirage ne dépend que de la date (`Daily.challenge`, graine FNV-1a de « AAAA-MM-JJ »),
  pas de la progression.
- Une fois par jour. On peut s’arrêter en route : la carte indique « À reprendre » et on repart au dossier suivant.
  Une fois fait, la carte se fait plus discrète (fond du papier, filet léger) et porte un petit tampon dateur vert sauge
  (plein si 500 / 500) ; elle affiche les points, et la toucher rouvre la page de résultat (sans tampon qui retombe ni jingle),
  jusqu’au lendemain. On ne rejoue pas le défi du jour.
- Seul le défi a une page de résultat (score, mot de conclusion, détail des 5 dossiers, jours de suite, lien « Crédits des images »),
  tamponnée à l’ouverture d’un tampon dateur vert sauge (« Défi du jour », le jour, le mois, l’année ; plein si 500 / 500), avec le même « tchok » ;
  son meilleur score s’affiche dans « Mes résultats » (« Meilleur défi du jour », `SaveStore.best_daily`).
  « Copier mon résultat » met dans le presse-papiers un texte à coller dans un message, sans rien des réponses :
  « Chevêche, défi du vendredi 6 novembre », puis un signe par dossier (● sans indice, ◐ avec indice, ○ manqué), « 4/5, 380 points »
  (`Daily.share_text`).
- **Jours de suite** : nombre de jours consécutifs où le défi a été terminé (jusqu’à hier si celui du jour reste à faire).
  Les réponses du défi comptent aussi pour la collection et la semaine.

## Lancement
- Au démarrage, rien d'autre que le papier : l'écran de démarrage d'Android est vidé (fond ivoire #F1EDE3, sans
  icône), l'écran de chargement de Godot aussi (même couleur, sans image), puis la couverture s'ouvre.
  Pour l'AAB (Gradle), `tools/android_template.sh` installe le modèle Android et règle son thème
  (`tools/android_splash.py`) ; pour un APK exporté sans Gradle, `tools/apk_splash.py` corrige l'APK avant signature.

## Carnet et révision espacée
- **Révision espacée** (`SaveStore.record_answer`, champ `boite` de la sauvegarde ; `RETURN_DAYS`) : un dossier manqué, ou
  trouvé avec un indice, revient le lendemain (boîte 0, « à revoir ») ; trouvé sans indice, il monte d’une boîte et revient
  dans 3 puis 7 jours (« à consolider »), puis il est **acquis** (boîte 3) et ne revient plus qu’en révision, à la fin des
  fiches. Trouvé sans indice du premier coup, il saute en boîte 2 : on le vérifie une fois, une semaine plus tard. Un acquis
  manqué repart à zéro. Les anciennes sauvegardes : un dossier trouvé sans indice revient une fois pour devenir acquis.
  Les phrases disent la vraie date : « La suite demain », « dans 3 jours », « à partir de demain » quand les retours s’étalent
  (`SaveStore.return_words`).
- **Carnet** (`screens/carnet_screen.gd`, lien « Carnet » de la couverture) : tous les dossiers joués, trouvés ou manqués
  (on en a déjà vu la réponse), rangés par discipline, avec leur vignette, leur titre, leur réponse et leur état (à revoir,
  à consolider, acquis). Onglets : Tout, À revoir, Acquis, Favoris. Toucher une ligne ouvre la fiche du dossier : l’image,
  la question, la réponse, l’explication, l’anecdote, le crédit, la date de retour, et l’étoile « Garder en favori »
  (champ `favoris` de la sauvegarde, transmis par le code de sauvegarde). La flèche ramène de la fiche à la liste, puis à la couverture.
- **Vignettes** : `tools/make_thumbs.py` fait un carré de 176 px, recadré au centre, de chaque image vérifiée
  (`assets/thumbs/<pack>/<fichier>.webp`, environ 2 Mo en tout) : le carnet ne charge jamais les grandes images dans la liste.
  À relancer après l’ajout d’images.

## Poids
- Les 270 images sont importées à 900 px au plus sur leur grand côté, en WebP avec perte (qualité 0,7) : `process/size_limit`
  et `compress/lossy_quality` dans les `.import` de `assets/images/`. Une image fait environ 960 px de large à l’écran d’un
  téléphone 1080p : la différence ne se voit pas, et les images passent de 28 à 18 Mo. L’APK de test (deux processeurs) fait
  72 Mo ; depuis le Play Store (AAB, un seul processeur par téléphone), le téléchargement tourne autour de 45 Mo.
  Prochain levier, s’il le faut : un moteur Godot recompilé sans la 3D (environ la moitié du moteur).

## Comment jouer
- Avant la toute première série (une fiche ou le défi du jour), la page « Comment jouer » montre la chouette sur ses livres
  et donne les trois règles :
  une image et une question à quatre réponses ; gratter dévoile l’image et deux indices, qui font baisser les points
  (100, 60, 30) ; un dossier manqué ou trouvé avec des indices revient le lendemain, et le défi du jour est le même
  pour tous. « Commencer » lance la série ; la page ne revient plus d’elle-même (réglage `rules_seen`), elle reste
  dans Réglages > Comment jouer. La remise à zéro de la progression ne la fait pas revenir.

## Réglages, crédits, sons
- « Réglages » (lien en bas de la couverture) : son, vibrations, code de sauvegarde, remise à zéro de la progression
  (deux touchers pour confirmer, sans fenêtre surgissante ; les réglages sont gardés), crédits. Réglages dans `user://settings.json`.
- **Code de sauvegarde** : « Copier ma sauvegarde » met toute la progression dans le presse-papiers sous forme d’un texte
  « CHEVECHE1-… » (JSON compressé en gzip, en base 64 : quelques ko). Le joueur le garde où il veut ; « Restaurer une sauvegarde »
  relit le presse-papiers (le code peut être entouré d’autres mots ou coupé en lignes) et, au second toucher, remplace la progression.
  Un code tronqué ou altéré est refusé sans rien changer (`SaveStore.export_code`, `decode_code`, `import_code`).
  Rien n’est envoyé : sans compte ni serveur, c’est ce qui permet de changer de téléphone.
- « Crédits » : en tête, l’auteur du jeu (Jérôme Hosdez, avec son adresse en lien `mailto:`, constantes `AUTHOR` et
  `AUTHOR_EMAIL` de `screens/credits_screen.gd`) ; puis les images rangées par discipline (un sommaire de huit étiquettes en haut y mène), et pour chacune le
  dossier (titre et numéro), le titre du fichier (d’après la page Commons), l’auteur, la licence avec lien vers l’acte
  de licence, le lien vers la page source et les modifications en bref (« Recadrée », « Réduite », expliqués en tête de
  page ; le détail reste dans le pack) ; puis polices (OFL, avec lien), sons et dessins. Liens cliquables
  (`OS.shell_open`). Accessible depuis les Réglages et, par un lien, depuis l’écran de résultat.
- Sons (`assets/sounds/*.wav`, fabriqués par `tools/make_sounds.py`, à remplacer à volonté par des fichiers de même nom) :
  un petit thème de marimba à l’espagnole (original, trois secondes) au lancement de l’application (pas aux retours sur l’accueil), frottement feutré et discret pendant le grattage (il monte et s’éteint en fondu, volume réglé dans `core/feedback.gd`, `SCRATCH_DB`), petit tintement quand un indice se débloque, deux notes pour une bonne réponse,
  deux notes graves et sourdes pour une mauvaise, clic sur les fiches, et un court jingle de marimba sur l’écran de résultat
  (trois versions selon le score du défi : à partir de 90 % des points, à partir de 30 %, en dessous ; `Scoring.finish_effect`). Vibrations courtes (indice 15 ms, juste 35 ms,
  faux 70 ms). `core/feedback.gd` gère tout ; **l’export Android doit cocher l’autorisation VIBRATE**.

## Identité visuelle
- Couverture : sur le papier ivoire, l’illustration (la chouette sur ses livres, plus grande sur un écran allongé), le titre, puis neuf fiches pleines : « Au hasard »
  (anthracite, avec la chouette) et une par discipline, à sa couleur. Chaque fiche de discipline porte une fine barre : la part de ses
  dossiers trouvés. Pas de compteur global sur l’accueil ; au tout premier lancement, une consigne d’une ligne. (Le fond vert « cabinet », `Ds.FELT`, reste
  disponible dans le design system : `CoverEmblem.on_dark`, bouton `IvoryButton`.)
- Chaque discipline a **une couleur et un pictogramme** (`Ds.DISCIPLINE_COLORS`, `assets/icons/*.svg`, traits blancs teintés
  à l’affichage) : fiches de la couverture, bandeau de la carte de jeu, barres de « Mes résultats ».
- Sobriété typographique : pas de petites capitales espacées (les légendes sont en italique, en minuscules), pas de doubles
  filets, pas de points médians dans les textes ; seule la marque « CHEVÊCHE » reste en capitales.

## Organisation
- `core/` : logique sans interface.
  - `question_pack.gd` : charge et contrôle un pack JSON, fournit les quatre choix (mélangés), le chemin d’image,
    l’état « image vérifiée ».
  - `reveal_rules.gd` : seuils de déblocage des deux indices (25 % et 50 %).
  - `scoring.gd` : points d’un dossier, total et mot de conclusion du défi.
  - `save_store.gd` : progression sur l’appareil (dossiers trouvés, meilleurs scores, meilleur défi, historique par jour),
    ordre de jeu d’une fiche.
  - `week.gd` : semaine du lundi au dimanche, clés de jour, intitulés (« 2 – 8 nov. »).
- `ds/` : design system et composants.
  - `ds.gd` : jetons (palette, espacements, rôles typographiques), thème, fabriques. **Seul endroit où changer
    une couleur ou une taille.**
  - `week_bars.gd` (colonnes des sept jours), `archive_card.gd` (carte d’archive), `image_zone.gd` (image + couche à gratter), `clue_list.gd` (les indices I et II),
    `placeholder_art.gd` (gabarit « image provisoire »), `scratch_cover.gd/.gdshader` (couche d’ardoise),
    `rounded_photo.gdshader`, `ds_segments.gd`, `ds_icon.gd`, `ds_stamp.gd` (tampon de fiche complète), `paper.gdshader`.
- `screens/` : `cover_screen.gd` (couverture, au lancement), `progress_screen.gd` (« Mes résultats » : cabinet, semaine, jouer par discipline),
  `play_screen.gd` (jeu, explication), `result_screen.gd` (fin du défi du jour), `complete_screen.gd` (fiche complète). `main.gd` : charge le pack et la
  progression, passe d’un écran à l’autre.
  Navigation : un seul geste pour jouer, toucher une fiche de la couverture. « Au hasard » lance tous les dossiers mêlés,
  une fiche de discipline les siens, en continu. « Mes résultats »
  (lien discret, en bas, à côté de « Réglages ») est un simple bilan : dossiers trouvés, semaine, progression par discipline. La flèche retour, Échap (ordinateur) ou le
  bouton Retour (Android) ramène à l’écran d’origine.
- `core/mastery.gd` : niveau du joueur par discipline (calcul seul, sans état : il relit la sauvegarde).
- `core/daily.gd` : date du jour et dossier du jour (la couverture s’en sert pour la date ; le dossier du jour reviendra avec le futur défi du jour).
- `assets/brand/` : l’illustration du jeu, la chouette sur deux livres (`owl_illustration.png`, fond détouré, couverture
  et « Comment jouer ») ; le logo qui en est tiré, simplifié et de face (SVG générés par `tools/make_owl.py`, trois tailles
  optiques) ; l’icône d’application (le logo sur l’olive de l’illustration) et l’icône de 512 px à téléverser dans la
  Play Console (`launcher/play_store_512.png`, exclue de l’export) ;
  `ds/owl_mark.gd` choisit la bonne taille selon l’affichage.
- `data/packs/` : les packs, schéma 3 (deux indices par dossier, questions autonomes) :
  `svt_01.json` (dossiers 1 à 15, disciplines Nature et Sciences), `astro_01.json` (dossiers 101 à 115, Astronomie),
  `animaux_01.json` (dossiers 201 à 215, Animaux), `histoire_01.json` (301 à 315, Histoire), `arts_01.json` (401 à 415, Arts), `geographie_01.json` (501 à 515, Géographie), `litterature_01.json` (601 à 615, Littérature) ;
  puis `nature_01.json` (16 à 35), `sciences_01.json` (36 à 60), et les seconds packs `astro_02`, `animaux_02`, `histoire_02`,
  `arts_02`, `geographie_02`, `litterature_02` (116 à 130, 216 à 230, etc.). Soit 30 dossiers par discipline.
  Le jeu les réunit au lancement (`PACK_PATHS` dans `main.gd`).
  Chaque pack indique `premier_numero` (numéro du premier dossier, pour que les numéros ne se répètent pas) et relie
  ses catégories à une discipline (`collection_par_categorie`).
- **Ajouter un pack** : créer le JSON (mêmes champs, identifiants préfixés, par ex. `histoire01-q01`), le contrôler avec
  `tools/validate_pack.py`, l’ajouter à `PACK_PATHS`, et, si sa discipline est nouvelle, l’ajouter à `DISCIPLINES`
  dans `screens/progress_screen.gd`. Ses images vont dans `assets/images/<id du pack>/`.
- `assets/images/<id du pack>/` : les images du jeu. **Les 240 dossiers ont leur image** (choisies le 4 novembre 2026,
  zip `lindice_images_202611041418.zip`). Ce sont des versions allégées : seulement la partie que le jeu peut montrer,
  1024 px de large au plus (24 Mo dans l'appli au lieu de 60).
- `images_sources/<id du pack>/` : les originaux reçus de Commons, intacts (le fichier `.gdignore` les tient hors de
  l'appli). Avec les packs, qui portent les crédits, c'est le stock à garder.
- `tools/validate_pack.py` : contrôle d’un pack ; `tools/make_choice_page.py`, `tools/integrer_images.py` et
  `tools/commons_image.py` : choix et intégration des images (voir ci-dessous).
- `fonts/` : Newsreader et DM Sans (SIL OFL 1.1, textes joints).

## Banque d'images
Les métadonnées de chaque image vivent dans le pack (`data/packs/<pack>.json`, bloc `image` de chaque dossier) ;
les fichiers dans `assets/images/<id du pack>/<id du dossier>.jpg`. Deux statuts :
- `a_trouver` : aucune image, aucun auteur, aucune licence. L'écran affiche un gabarit **« IMAGE PROVISOIRE »**
  avec la description de la recherche à faire. Rien n'est inventé ni généré.
- `verifie` : fichier présent, auteur, licence **exacte** (ex. « CC BY-SA 4.0 »), page de description, URL du
  fichier d'origine, modifications (« Aucune » ou « Redimensionnée à 1600 px… »). Le jeu n'affiche l'image que si
  tout est là et si la licence est CC BY, CC BY-SA, CC0 ou domaine public.

### Choisir et intégrer les images : la page de choix (méthode conseillée)
1. `python3 tools/make_choice_page.py choisir_images.html` fabrique la page (tous les dossiers, d’après les packs et les
   recherches de `tools/commons_recherches.json`) ; avec `--a-trouver`, seulement ceux dont l’image reste à trouver
   (par exemple un nouveau pack). On l’ouvre dans un navigateur d’ordinateur ou de téléphone, connecté à Internet.
2. Chaque dossier interroge Commons quand on arrive dessus (API officielle, depuis le navigateur). Pour chaque image :
   vignette recadrée comme dans le jeu (16 : 9), auteur, licence et taille déclarés par Commons. Les images qui ne
   passeraient pas les contrôles de `commons_image.py` (licence NC, ND, GFDL, inconnue ; auteur absent ; format) sont
   grisées avec la raison. La recherche se modifie dans la page ; « Plus de résultats » donne la suite.
3. Les choix restent enregistrés dans le navigateur. « Télécharger » produit un zip : `choix.json` (réponse de Commons
   pour chaque image) et les images en 1280 px de large (miniatures produites par Commons). Le bouton ne reprend que
   les images pas encore téléchargées : on peut avancer par séries.
4. `python3 tools/integrer_images.py cheveche_images_XXXX.zip` (ajouter `--dry-run` pour un essai à blanc) refait les
   contrôles sur les métadonnées de Commons, range l'original dans `images_sources/<pack>/`, écrit la version du jeu
   dans `assets/images/<pack>/` (recadrée sur la bande que la zone d'image, 584 px de large et 200 à 330 px de haut,
   peut montrer ; 1024 px de large au plus ; import WebP avec pertes, qualité 0,8, sans mipmaps), écrit les
   métadonnées dans les packs, modifications comprises, puis lance `validate_pack.py`.
   Une image déjà dans le jeu n'est pas réécrite (`--forcer` pour tout réécrire). Ensuite, reconstruire l’application.
   - **Changer quelques images** : rouvrir la page (elle montre « Dans le jeu » pour chaque dossier), choisir les
     nouvelles, « Télécharger » : le zip ne contient que celles-là, et l'intégration ne touche qu'à elles.
   - **Images plus petites que 1280 px** : Commons envoie l'original tel quel (en annonçant 1280) ; il est accepté,
     avec « Modifications : Aucune ».
   - Si la mise en page de l'image change (zone plus haute), relancer l'intégration avec `--forcer` sur les zips
     reçus, après avoir ajusté `RAPPORT_MIN` / `LARGEUR_JEU` dans `tools/integrer_images.py`.
   - **Auteur** : le texte visible de Commons, sans ce qui est caché ni les encadrés de modèles ; « Auteur inconnu »
     n'est accepté que pour le domaine public et CC0 (aucune attribution exigée) ; un auteur que Commons « présume »
     est écrit « Nom (auteur présumé) » ; une signature de wiki collée au nom (« Esby (talk) 17:52, 31 May 2009 (UTC) »)
     est retirée ; les quelques longs textes de modèles sont reformulés fidèlement dans
     `tools/auteurs_reformules.json` (par titre de fichier).

### Autre méthode : l’outil en ligne de commande (sur votre ordinateur, avec accès à Internet)
**Windows, sans rien taper :** enregistrer le choix dans `images_choisies.txt` à côté de `project.godot`, puis
double-cliquer sur `ajouter_images.bat` (il passe sur tous les packs ; chacun ne prend que ses propres dossiers) (nécessite Python, python.org, case « Add Python to PATH »).
Le fichier lance l'étape 3 ci-dessous en acceptant automatiquement toute image qui passe les contrôles.

1. Écrire le modèle (un pack à la fois, ici SVT) : `python3 tools/commons_image.py modele data/packs/svt_01.json images_a_remplir.txt`
   (sous Windows, essayer `py` ou `python` à la place de `python3`). Chaque dossier y est décrit avec un lien de
   recherche Commons.
2. Choisir une image par dossier sur commons.wikimedia.org et coller l'adresse de sa page après l'identifiant.
3. Lancer : `python3 tools/commons_image.py lot data/packs/svt_01.json images_a_remplir.txt`.
   Pour chaque image, l'outil lit auteur, licence et adresses sur Commons, vous les montre, demande confirmation,
   télécharge une copie de 1600 px de large (miniature produite par Commons), écrit les métadonnées et relance le
   contrôle du pack. Une sauvegarde `svt_01.json.bak` est faite avant la première écriture.
   Un seul dossier : `… ajouter data/packs/svt_01.json svt01-q08 "<adresse de la page>"`.
4. L'outil **refuse** : licence non autorisée (NC, ND, GFDL seule…), auteur absent ou « inconnu » pour une licence
   CC BY / CC BY-SA (qui exige de le citer), fichier introuvable. Si l'auteur ou la licence est bien indiqué sur la page mais pas lisible par l'outil, on peut les
   donner à la main (`--auteur`, `--licence`) après vérification : c'est vous qui en répondez.

### Bien choisir une image (elle est grattée !)
- Un sujet lisible quand on n'en voit que 30 % ; format paysage d'environ 2 : 1 de préférence (l'image, large de 584 px et haute de 260 à 330 px, est recadrée au centre).
- Aucun texte, légende ou étiquette qui donne la réponse dans l'image elle-même.
- Au moins 1000 px de large ; l'outil prévient en dessous.
- L'image illustre la réponse, mais on peut répondre sans la voir : elle n'a pas à porter l'information de la question.
- Après la réponse, une ligne discrète donne l'auteur et la licence ; la page « Crédits » donne tout le reste (titre du
  fichier, liens vers la page source et vers la licence, modifications), comme CC BY / CC BY-SA le demandent.

## Contrôle du pack
`python3 -I tools/validate_pack.py data/packs/svt_01.json [dossier_images]` vérifie : schéma 3, champs obligatoires, deux
indices, trois distracteurs distincts, libellés ≤ 40 caractères, catégories présentes dans les collections,
cohérence du statut d’image. Il **signale** (sans bloquer) une question qui renvoie à l’image (« cet », « cette », « ces »,
« image », « photo »…), une question de plus de 110 caractères et un indice qui reprend un mot de la réponse.

## Écrire un dossier
- La question se comprend **sans l’image** : on la lit, on peut répondre. Pas de « cet insecte » ni de « ces cellules » ;
  on nomme le sujet. Une phrase, 110 caractères au plus.
- Une seule bonne réponse, trois distracteurs plausibles mais faux, libellés courts (≤ 40 caractères).
- Indice I : une piste large. Indice II : plus précis, mais sans nommer la réponse.
- L’explication et l’anecdote n’ont pas à répéter les indices.

## Réglages
- Grattage : `ds/scratch_cover.gd` (`brush_radius_ratio`, `brush_softness`, `brush_pressure`) et `ds/image_zone.gd`.
- Longueur du défi : `CHALLENGE_LENGTH` dans `core/daily.gd` (5 dossiers) ; points par nombre d’indices : `POINTS_BY_CLUES` (100 / 60 / 30) ; seuils des indices : `CLUE_THRESHOLDS` dans `core/reveal_rules.gd`.
- Dossier du jour (`core/daily.gd`) : choisi selon le jour de l’année ; plus affiché pour l’instant.

## À relire
Les explications et anecdotes du pack ont été rédigées pour ce prototype : à relire (chiffres, dates) avant diffusion.

## Crédits
Newsreader (Production Type) et DM Sans (Colophon Foundry, Indian Type Foundry), SIL OFL 1.1.
