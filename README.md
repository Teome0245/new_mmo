# new_mmo — sources LBG (Core3 SWG PreCU + LBG Prime)

Dépôt Git des **sources serveur** et outils client LBG. Les patches gameplay/IA (Lua, JSON) vivent dans le monorepo **`LBG_IA_MMO/content/core3/`** et sont déployés séparément.

## Arborescence versionnée

| Chemin | Rôle | VM cible |
|--------|------|----------|
| `lbg-mmo/Core3/MMOCoreORB/` | **PreCU** stock SWGEmu (C++ + SQL + scripts) | **245** → `/opt/lbg-new-mmo/MMOCoreORB` |
| `lbg-mmo/server-core3/` | **Prime** (fork clean + patches LBG) | **246** → `/opt/lbg-Prime/lbg-mmo/server-core3` |
| `lbg-mmo/MMOEngine/` | Moteur partagé | **246** (build Prime) |
| `launchpad/` | LBG Launchpad (sources Electron) | postes joueurs |
| `modding_tools/swb-repo-cli/` | Outils modding légers | dev |

## Tags de déploiement

- `deploy/245-precu` — snapshot aligné PreCU VM 245
- `deploy/246-prime` — snapshot aligné Prime VM 246

## Sync vers les VM (depuis `LBG_IA_MMO/`)

```bash
# SWG PreCU → 245
LBG_NEW_MMO_VM_HOST=192.168.0.245 bash infra/scripts/rsync_new_mmo_core3_orb.sh

# LBG Prime → 246
LBG_NEW_MMO_VM_HOST=192.168.0.246 bash infra/scripts/rsync_lbg_mmo_vm.sh
bash infra/scripts/build_core3_vm.sh --sync   # compile sur VM
```

## Récupérer depuis une VM (si patch manuel sur serveur)

```bash
bash LBG_IA_MMO/infra/scripts/pull_core3_from_vm.sh precu   # 245 → local
bash LBG_IA_MMO/infra/scripts/pull_core3_from_vm.sh prime   # 246 → local
```

## Hors Git (local uniquement)

- `Core3/` — clone de référence `github.com/swgemu/Core3` (upstream)
- `StarWarsGalaxies/` — fichiers client `.tre` (disponnible sur demande, trop lourd pour git)
- Builds : `lbg-mmo/**/build/`, `lbg-mmo/**/bin/`

## Prérequis build (Ubuntu 22.04)

```bash
sudo apt install build-essential cmake git libmariadb-dev liblua5.3-dev \
  libdb5.3-dev libssl-dev zlib1g-dev libboost-all-dev default-jre libgmock-dev
```

Voir `LBG_IA_MMO/docs/core3_mmoorb_vm.md` et `LBG_IA_MMO/docs/new_mmo_git_versioning.md`.
