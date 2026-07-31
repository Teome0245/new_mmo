# AGENTS.md

Dépôt des **sources serveur MMO Core3 (SWGEmu PreCU + fork LBG Prime)** en C++, plus des outils client/dev. Voir `README.md`.

Composants principaux :
- `lbg-mmo/Core3/`, `lbg-mmo/server-core3/`, `lbg-mmo/MMOEngine/` — serveur **Core3** en **C++** (cible VM 245/246).
- `launchpad/` — lanceur de jeu **Electron** (LBG Launchpad, orienté Windows).
- `modding_tools/` — scripts Python de modding SWG (`.stf` / `.tre`).
- Scripts Python racine (`clean_phase2.py`, `neutralize_calls.py`, …) — codemods sur l'arbre Core3.

## Cursor Cloud specific instructions

### Ce qui est exerçable dans le cloud VM

- **Launchpad (Electron)** — dev-ready :
  - Installer : `cd launchpad && npm install`.
  - Lancer : `DISPLAY=:1 ./node_modules/.bin/electron . --no-sandbox` (affichage principal `:1`), ou headless via `xvfb-run -a ./node_modules/.bin/electron . --no-sandbox`.
  - L'app démarre et rend son UI (« NOUVEL UNIVERS », bouton JOUER, sélecteurs PreCu/Prime). Le statut serveurs affiche **Hors ligne** car les serveurs de jeu LAN (`192.168.0.245/246`) sont injoignables — comportement attendu.
  - Sa fonction réelle (lancer le client SWG Windows `.exe` depuis `J:\swgemu`) n'est pas exerçable hors Windows + client installé.

### Hors périmètre du cloud VM

- **Build du serveur Core3 (C++)** : nécessite `build-essential cmake libmariadb-dev liblua5.3-dev libdb5.3-dev libssl-dev zlib1g-dev libboost-all-dev default-jre libgmock-dev`, une base **MariaDB**, et les fichiers client `.tre` (**hors git**, trop lourds). Non réalisable ici. Procédure : `LBG_IA_MMO/docs/core3_mmoorb_vm.md`.
- **`modding_tools/`** : opèrent sur des fichiers client `.tre`/`.stf` non versionnés (absents du dépôt).
