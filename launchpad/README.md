# LBG Launchpad (Electron) v2.1

Lanceur dual-client :

| Profil | Client | Exécutable | Cible |
|--------|--------|------------|--------|
| `precu` | SWG retail | `SWGEmu.exe` | Login PreCu `:44453` (245) |
| `prime` | **Godot 4.6** `prime-client` | `Godot_v4.6-*.exe --path …` | Gateway Prime `246:8765` / `:50000` |

**Prime ne lance plus `lbgemu.exe`.** À l’ouverture, une config encore pointée sur `prime-lbg` / `lbgemu.exe` est migrée automatiquement vers Godot.

## Chemins déployés (PC sdesh / J:)

| Clé | Chemin réel |
|-----|-------------|
| Projet | `J:\swgemu\clients\prime-client` |
| Godot | `J:\mmmorpg\Godot_v4.6.1-stable_win64\Godot_v4.6.1-stable_win64.exe` |
| Launchpad | `J:\swgemu\dist\win-unpacked\LBG Launchpad.exe` |
| Config | `J:\swgemu\dist\launchpad.config.json` (aussi à côté de l’exe) |

Sync projet depuis WSL :

```bash
rsync -a --delete --exclude '.godot/' --exclude '.git/' \
  /home/sdesh/projects/new_mmo/prime-client/ \
  /mnt/j/swgemu/clients/prime-client/
```

## Build Windows

```bash
cd launchpad
npm install
npm run build:win
```

Copier `dist/win-unpacked/` vers `J:\swgemu\dist\` et placer **`launchpad.config.json`** à côté de **LBG Launchpad.exe**.

## Config (`launchpad.config.json`)

- `profiles[].clientKind` : `godot` | `swgemu`
- `profiles[].launchArgs` : (SWGEmu) arguments exe ; **Godot** : ignoré — voir `godotFullscreen` + `launchArgsExtra`
- `profiles[].godotPatchEnabled` : `false` pour désactiver le patch Prime via le bouton
- `patchServerUrl` : **Prime Godot** → `http://192.168.0.246:8080` (PreCu TRE reste aussi sur 245 en miroir `patchServerUrlNas`)
- **Prime — publier la référence sur 246** :
  ```bash
  bash /home/sdesh/projects/new_mmo/prime-client/tools/deploy_prime_client_patch_246.sh
  # → http://192.168.0.246:8080/patches/prime/manifest.json
  ```
- Le bouton **Vérifier mises à jour** (galaxie Prime) compare MD5 locaux vs manifeste et télécharge les diffs.
- `profiles[].skipPatch` : `true` pour Godot (pas de TRE)
- `statusApiUrl` : pastilles serveur (`:8792`)

Doc produit : `new_mmo/prime-client/docs/CLIENT_ONLY_GODOT.md`

## Mauvaise version / ancien client ?

Le Launchpad **ne lit pas** le dépôt WSL : il lance exactement :

- **Exe** : `launchpad.config.json` **à côté de** `LBG Launchpad.exe` (souvent `J:\swgemu\dist\win-unpacked\`)
- **Godot** : `--path` = `profiles[prime].gameDir` (attendu : `J:\swgemu\clients\prime-client`)

Pièges fréquents :

| Symptôme | Cause |
|----------|--------|
| Retail / PreCu au lieu du hub Godot | Galaxie **PreCu** sélectionnée → `SWGEmu.exe` |
| Ancien fond / pas de login WS | Godot ouvert sur **un autre dossier** (éditeur, raccourci `\\wsl$\…`) |
| Scripts récents absents sur J: | **rsync partiel** (quelques `.gd` seulement) |

**Sync complète (WSL)** :

```bash
bash /home/sdesh/projects/new_mmo/prime-client/tools/sync_prime_client_to_j.sh
```

**Vérification (PowerShell)** :

```powershell
cd J:\swgemu\clients\prime-client\tools
.\verify_launchpad_prime.ps1
```

Dans Godot (DEBUG), le HUD affiche `build … · map v2` si `assets/build_info.json` est à jour.
