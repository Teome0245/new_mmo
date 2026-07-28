# Hub Lost Heaven — monde visible

## Couches (WorldMap, bas → haut)

| z | Layer | Rôle |
|---|--------|------|
| -7 | **HubGroundLayer** | Sol sable + plaza (emprise village) |
| -6 | **HubBuildingsLayer** | Footprints bâtiments (volume + labels) |
| -5 | **HubPropsLayer** | Chemins + props (caisses, étals, lampe…) |
| 0+ | EntityManager | Jetons joueurs / PNJ |

## Data

- `lost_heaven_buildings.json` — POI bâtiments
- `lost_heaven_props.json` — chemins + meubles
- `lost_heaven_npc_anchors.json` — placement PNJ (override visuel)

## Contrôles

- **H** — recentrer caméra hub (4749, -737)
- **Ctrl+H** — toggle sol + bâtiments + props
- **L** — nameplates entités (off par défaut)
- **F9** — panneau debug

## Joueur humain

Voir `docs/HUMAN_PLAYER.md` — packet `cn` UDP `:12345`.
