# LBG Launchpad (Electron) v2

Lanceur dual-client pour **PreCu (SWGEmu.exe)** et **Prime (lbgemu.exe)** — VM 245.

## v2.0 (P0) — profils client

| Profil | Dossier par défaut | Exécutable | Port login |
|--------|-------------------|------------|------------|
| `precu` | `J:\swgemu\StarWarsGalaxies` | `SWGEmu.exe` | 44453 |
| `prime` | `J:\swgemu\clients\prime-lbg` | `lbgemu.exe` | 44553 |

- Un **profil** = `gameDir` + `gameExe` + canal patch (`precu` / `prime`).
- La galaxie sélectionnée active le profil correspondant (chemins UI + lancement + patch).
- Avertissement **espace disque** (~40 Go recommandés pour 2 installs complètes).
- Migration auto depuis l’ancien `launchpad.config.json` (clé `gameDir` unique).

Patches : `http://<host>:8080/patches/<canal>/manifest.json` (repli sur `/manifest.json`).

## Build Windows

```bash
cd launchpad
npm install
npm run build:win
```

Copier `dist/win-unpacked/` vers `J:\swgemu\dist\` et placer **`launchpad.config.json`** à côté de **LBG Launchpad.exe**.

## Config (`launchpad.config.json`)

Voir `launchpad.config.json` à la racine du dépôt. Champs principaux :

- `profiles[]` : `id`, `gameDir`, `gameExe`, `patchChannel`, `servers[]`
- `diskSpaceWarningGb` : seuil d’avertissement (défaut 40)
- `statusApiUrl` : pastilles serveur (`:8792`)
- `patchServerUrl` : serveur de patches (`:8080`)

Doc projet : `LBG_IA_MMO/docs/client_dual_launchpad.md`

## Préparer les dossiers client (Windows)

```powershell
# Original PreCu (déjà en place si StarWarsGalaxies fonctionne)
# Optionnel : copie formelle
# xcopy /E /I J:\swgemu\StarWarsGalaxies J:\swgemu\clients\precu-original

# Prime : copie puis remplacer l'exécutable quand lbgemu.exe est prêt
mkdir J:\swgemu\clients\prime-lbg
xcopy /E /I J:\swgemu\StarWarsGalaxies J:\swgemu\clients\prime-lbg
# puis déployer lbgemu.exe + TRE custom dans prime-lbg uniquement
```
