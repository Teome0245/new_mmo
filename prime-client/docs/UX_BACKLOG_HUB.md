# Backlog UX — Hub Lost Heaven (Prime Client)

État après correctifs client **2026-07-27** (carte, hotbar, PNJ, échelle bâtiments).

## Corrigé côté client (lot 2026-07-27 b)

| Sujet | Changement |
|--------|------------|
| Fond Tatooine WebP | `tatooine_satellite.webp` + `MapTextureLoader` / `world_texture` dans config |
| Sol hub opaque | `hub_fill_alpha` ~0.18 — la planète visible sous Lost Heaven |
| Collisions hub | Palissade + boîtes bâtiments + clamp locomotion (`ZoneLayers` / `PlayerController`) |
| Extraction 245 | `tools/retail/extract_precu_tatooine_assets.sh` → `docs/reference/retail_245/` |
| Sprites overhead | `generate_sprites_prime_overhead.sh` + deploy vers `assets/sprites/units/` |

Doc détaillée : `docs/MAP_TEXTURES_AND_RETAIL.md`

| Sujet | Changement |
|--------|------------|
| Carte décalée à l’ouverture | Vue **planète entière** (`pan=0`, `zoom=1`) ; **F** sur la carte = centrer Lost Heaven |
| Labels « Lost Heaven » empilés | Plus de marqueur `locations` pour `kind=hub` (POI unique) |
| PNJ qui « rebondissent » | Bob désactivé par défaut ; micro-orbit des bots retirée |
| Hotbar / inventaire inactifs | `ModalLayer` ne bloque plus les clics ; feedback dans le bandeau CONNECTED |
| Inventaire | Clic sur un objet → message stub dans le panneau |
| Bâtiments trop petits | `HubBuildingsLayer.size_multiplier` ≈ 1.75 |

## À faire — équipe (priorité)

### Pygmalion / art
- **Sprites top-down overhead** (pas portraits ¾) : tokens ~12 px monde, ombre au sol cohérente.
- **Tuiles bâtiments** SVG/PNG par `kind` (banque, cantina, mairie…) alignées sur `lost_heaven_buildings.json`.
- **Fond hub** : sol / palissade moins « placeholder » (texture légère, dégradé sable).
- **Carte planétaire** : texture `tatooine.png` + POI lisibles sans glow qui masque le réseau.

### Iris / UI
- Brancher hotbar 1–4, 8–0 sur vrais panneaux (combat, chat, menu).
- Inventaire : sync gateway / `inventory` WS, drag & drop, utilisation objet.
- Toasts HUD dédiés (ne pas écraser l’état locomotion sur `StateLabel` long terme).

### Gameplay / gateway
- Patrol PNJ : uniquement via ancre JSON `_patrol` + flag `enabled` (pas de mouvement client si position serveur figée).
- Taille bâtiments : valider en jeu `size_m` dans JSON vs mesh/SWG ref.

## Tests manuels rapides

1. Lancer hub → hotbar clic slot 7 : inventaire s’ouvre, bandeau affiche le libellé.
2. Ctrl+M : planète centrée dans le cadre doré ; F = focus LH.
3. PNJ / bots : plus de oscillation visible au repos.
4. Bâtiments : carrés/tuiles nettement plus grands que les tokens perso.
