# Prime Client — Godot 4 Top-Down + pont SOE headless

Projet expérimental (plan *Boîte à idées 20260624*) : visualiser le monde Prime en 2D sans le client SWG legacy.

## Composants

| Chemin | Rôle | Jalons plan |
|--------|------|-------------|
| `../client-prime-lbg/soe_handshake.py` | Client UDP SOE headless (login + zone + console Delta) | M1.1–M1.3, M3.1 |
| `../client-prime-lbg/ws_parser.py` | Parseur snapshots `.ws` → JSON | M3.3 |
| `../client-prime-lbg/prime_controller.py` | Contrôles ZQSD / saut (WIP) | M4 |
| `prime-client/` (ce dossier) | Godot 4.6 — EntityManager, projection Core3→2D, minimap | M2–M3 |

## Lancer (mirroring live)

Terminal 1 — Godot :

```bash
godot4 --path /home/sdesh/projects/new_mmo/prime-client
```

Terminal 2 — pont Python (compte bot ou perso test) :

```bash
python3 ../client-prime-lbg/soe_handshake.py \
  --host 192.168.0.246 --port 44553 \
  --user Bot_IA --password lbgiabot \
  --godot-port 12345
```

Le `NetworkBridge` Godot écoute `127.0.0.1:12345` (JSON compact : `mv`, `sp`, `dp`, `zc`, `cn`).

## Projection Core3 → Godot

- `Screen.x = Core3.x`
- `Screen.y = Core3.z`
- `Sprite.offset_y = -Core3.y`

Voir `scripts/projection.gd`.

## Minimap (M3.3)

Placer une texture `tatooine_map.tga` (client SWG `ui/map/`) et lancer `ws_parser.py` pour les bâtiments statiques.

## GLM-5.2 (axe orchestrateur)

Configuré dans `LBG_IA_MMO` via palier `glm` — voir `infra/secrets/lbg.env.example` et `agents/src/lbg_agents/dialogue_llm.py`.
