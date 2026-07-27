# Retail City Layout

## PNJ serveur (snapshot gateway)

Dernière MAJ équipe LH CODE (2026-07-27).

- HTTP : `http://192.168.0.246:8765/v1/world/npcs_near?anchor_x=4749&anchor_z=-737&radius_m=800`
- Export client : `tools/retail/export_server_npcs_lost_heaven.sh`
- Carte : `tools/retail/build_prime_position_map.sh`
- Triangles **cyan** = entités fusionnées depuis le serveur (`retail_layout_layer`).

## Habillage Lost Heaven (pipeline art)

Checklist (2026-07-27).

- Pipeline : `tools/retail/habillage_lost_heaven.sh`
- Sprites overhead : copie `units_overhead` si NAS/B: indisponible → copie manuelle documentée.
- ComfyUI : pas de régression ; coordonner Iris (markers carte).

