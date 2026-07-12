# Prime Client — Godot 4 Top-Down (M2) + pont SOE (M3+)

Client 2D pour Core3 Prime. Projet dans `new_mmo/prime-client/`.

## Jalons

| Jalon | Composant | Statut |
|-------|-----------|--------|
| **M1** | `LBG_IA_MMO/tools/zone_observer/zone_feed.py` | CLI snapshots |
| **M2** | Ce dossier — EntityManager, projection, demo JSON | OK |
| **M3** | `zone_feed.py --mirror` + bots Lia/Nix/Mira | ✓ |
| **M4** | Carte + POI + eau/collision + bâtiments .ws | ✓ |
| **M5** | ZQSD `--play` + `run_m5_play.sh` | ✓ (code) |
| **M9** | Scrapaltai planète + minimap + carte M | ✅ M9a/b/c |

## Lancer Godot (M2)

```bash
godot4 --path /home/sdesh/projects/new_mmo/prime-client
```

Sans snapshots live → **3 ronds demo** (`assets/demo_entities.json`).

## Différenciation joueurs

- **Teintes** : Lia (vert), Nix (bleu), Mira (rose), Teome (bleu officiel)… — `sprite_manifest.json` → `player_tints`
- **Sprites dédiés** : `player_lia.png`, `player_nix.png`, … (générés par Infographiste, fallback `player_bot.png`)
- **Hub** : léger écartement (`jitter`) si plusieurs bots au même point

Regénérer overhead strict : voir `Infographiste_IA/pipelines/2d/BACKLOG_sprites_prime.md`.

## Sprites 2D (Infographiste_IA)

Entités : **sprite PNG** si présent dans `assets/sprites/units/`, sinon cercle coloré (fallback).

```bash
# Générer (ComfyUI + LoRA mmorpg_insp)
cd ~/projects/Infographiste_IA
./scripts/generate_sprites_prime_topdown.sh
./scripts/deploy_sprites_to_prime.sh
```

Mapping : `config/sprite_manifest.json` — voir `assets/sprites/README.md`.

## M1 + M2 ensemble (mirroring fichiers)

Terminal 1 — export snapshots (VM Prime ou repo local) :

```bash
cd ~/projects/LBG_IA_MMORPG/LBG_IA_MMO
python3 tools/zone_observer/zone_feed.py --watch --json-out /tmp/zone_feed.json --quiet --interval 1
```

Terminal 2 — Godot :

```bash
godot4 --path /home/sdesh/projects/new_mmo/prime-client
```

Configurer les chemins dans `config/snapshot_paths.json` (`zone_feed_json`, `player_snapshots`, `npc_snapshots`).

Sur VM Prime :

```bash
IA_BRIDGE_DIR=/opt/lbg-new-mmo-clean/MMOCoreORB/bin/ia_bridge \
  python3 tools/zone_observer/zone_feed.py --watch --interval 1
```

## M3 — Mirroring retail ↔ 2D (snapshots → UDP)

**Prérequis** : Teome (ou autre) connecté sur `lbgemu` ; sidecar Core3 écrit `ia_bridge/player_snapshots.json`.

Terminal 1 — Godot :

```bash
godot4 --path /home/sdesh/projects/new_mmo/prime-client
```

Terminal 2 — pont M3 :

```bash
cd ~/projects/LBG_IA_MMORPG/LBG_IA_MMO
IA_BRIDGE_DIR=/opt/lbg-new-mmo-clean/MMOCoreORB/bin/ia_bridge \
  bash tools/zone_observer/run_m3_mirror.sh
```

**Validation** : bouger Teome sur le retail → rond **bleu** bouge sur la carte 2D en < 2 s.

## M4 — Carte Tatooine

Export carte + POI vers Godot :

```bash
cd ~/projects/LBG_IA_MMORPG/LBG_IA_MMO
python3 tools/map_export/export_tatooine_for_godot.py
```

Dans Godot : fond désert Tatooine, **Ctrl+M** affiche/masque la carte, **Ctrl+P** les POI (Mos Eisley, Lost Heaven…). **F2** sur Nix doit tomber près du point **Mos Eisley** sur la carte.

**Ctrl+W** eau · **Ctrl+C** collision · **Ctrl+B** bâtiments `.ws`

## M5 — Jouer (ZQSD)

Compte dédié (pas Lia/Nix en même temps) :

```bash
# Terminal 1 — Godot
godot4 --path ~/projects/new_mmo/prime-client

# Terminal 2 — SOE + contrôleur
cd ~/projects/LBG_IA_MMORPG/LBG_IA_MMO
SWG_USER=Bot_IA SWG_PASS=lbgiabot bash tools/zone_observer/run_m5_play.sh
```

Godot Windows : `config/play_mode.json` → `cmd_host` = IP WSL.

Mode **PLAY** : ZQSD déplace le perso (plus la caméra). **Shift** course, **Espace** saut.

## Mirroring live SOE (M3 alternatif)

Terminal 2 — pont Python :

```bash
python3 ../client-prime-lbg/soe_handshake.py \
  --host 192.168.0.246 --port 44553 \
  --user Bot_IA --password lbgiabot \
  --godot-port 12345
```

`NetworkBridge` écoute `127.0.0.1:12345` (prioritaire sur snapshots si connecté).

## Projection Core3 → Godot

- `Screen.x = Core3.x`
- `Screen.y = Core3.z`
- `Sprite.offset_y = -Core3.y`

Voir `scripts/projection.gd`.

## Fichiers clés

| Fichier | Rôle |
|---------|------|
| `scripts/snapshot_bridge.gd` | Poll snapshots / zone_feed.json |
| `scripts/network_bridge.gd` | UDP live soe_handshake |
| `scripts/entity_manager.gd` | Spawn / move entités |
| `config/snapshot_paths.json` | Chemins ia_bridge |
| `assets/demo_entities.json` | Données demo offline |
