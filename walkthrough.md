# Walkthrough - Traduction SWGEmu Core3

Les modifications de traduction en français pour SWGEmu Core3 ont été adaptées pour contourner les limitations du launcher et de la locale japonaise.

## Résolution des problèmes et nouvelle approche

### 1. Annulation des modifications du Launcher
Afin de rétablir un environnement 100 % stable et d'éviter tout blocage de lancement (notamment le problème de fermeture/Job Objects) :
- Le code source du launchpad personnalisé (`launchpad/main.js`) a été entièrement **restauré dans sa version d'origine**.
- Le launcher a été recompilé et remis à disposition dans `J:\swgemu\dist`.

### 2. Déverrouillage des fichiers locaux
- Les attributs de lecture seule (`attrib -r`) ont été retirés des fichiers `live_motd.stf`, `test_motd.stf`, et `ui_auc.stf` situés dans `J:\swgemu\StarWarsGalaxies\string\en\`.
- Cela permet au launcher officiel (ou personnalisé) d'effectuer ses scans de fichiers sans provoquer d'erreurs de droit d'accès ou de demandes de réparations en boucle.

### 3. Traduction directe sous la locale officielle (`fr`)
Pour éviter que les fichiers de patch soient écrasés par les versions anglaises téléchargées par le launcher, ou que le client ignore notre fichier patch de langue :
- Les **2 380 fichiers `.stf` traduits en français** ont été compilés sous le chemin officiel **`string/fr/...`** dans notre archive de patch.
- L'archive finale **`patch_fr_00.tre`** a été recompilée et déployée dans `J:\swgemu\StarWarsGalaxies\patch_fr_00.tre`.

### 4. Configuration de la locale de jeu
Pour forcer le jeu à charger les fichiers français sans modifier la police d'origine :
- Le fichier `options.cfg` et le fichier de surcharge finale `user.cfg` ont été modifiés pour y insérer les valeurs suivantes :
  ```cfg
  [SharedGame]
  	defaultLocale=fr
  	fontLocale=en
  ```
  *(La valeur `fontLocale=en` garantit que le jeu utilise les polices occidentales d'origine, supportant parfaitement tous les caractères accentués français, tandis que `defaultLocale=fr` indique au client de chercher les textes traduits dans le sous-dossier `fr`).*

### 5. Ajustement des priorités de recherche (limitation du moteur SWG)
- Le fichier `swgemu_live.cfg` a été configuré avec `maxSearchPriority=25` (valeur maximale supportée par défaut).
- Notre patch a été positionné à l'index maximal disponible et prioritaire : **`searchTree_00_24=patch_fr_00.tre`**.
- Les fichiers d'origine pré-existants à cet index (`default_patch.tre` et `patch_sku1_14_00.tre`) ont été déplacés vers les sous-index suivants de la même priorité (`searchTree_01_24` et `searchTree_02_24`).

## Vérification
1. **Restauration** : Le code source du launcher et les fichiers locaux sont revenus à leur état d'origine.
2. **Scan du Launcher** : Le launcher peut désormais lancer le jeu sans réclamer de réparation.
3. **Langue** : Le jeu démarre avec la locale `fr` et charge directement les fichiers français du patch au niveau 24 (index 00).
