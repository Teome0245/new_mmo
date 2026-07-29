# Jalon M10 — UI talents + craft (prime-client Godot)

**Date** : 2026-07-14  
**Statut** : Pilote via Cockpit Dev+Diff (autonomie sans dépendre de Cursor)  
**ADR** : [0016-prime-axe-lbg-talents-artisanat.md](adr/0016-prime-axe-lbg-talents-artisanat.md)

## Objectif

Écran **skills tree** + liste **schematics** dans `prime-client`, alimenté par le sidecar Prime `:8791`.

## Fichiers cibles (allowlist)

| Fichier | Rôle |
|---------|------|
| `prime-client/scripts/talents_craft_panel.gd` | Panneau HUD M10 (touche T) |
| `prime-client/scenes/ui/talents_craft_panel.tscn` | Scène Control (optionnel) |
| `prime-client/scripts/main.gd` | Instancier le panneau |

## Critères done pilote

- [x] `talents_craft_panel.gd` présent et parse sidecar `/v1/catalog/skills`
- [x] Patch appliqué via Cockpit **Dev** → dry-run **Diff** → apply L2
- [ ] Aucune *obligation* d’édition Cursor sur le poste `.10` pour ce jalon

## Preset Cockpit Dev

```
@iris M10 — talents craft panel prime-client sidecar 8791 skills schematics UI
```

Chemins hint : `new_mmo/prime-client/scripts/talents_craft_panel.gd`
