# Style Prime UI — HUD / panels (multivers)

**Cible** : sci-fi clean · space western · steampunk léger

## Palette
| Rôle | Usage |
|------|--------|
| Métal usé / noir chaud | panels |
| Cuivre | bordures modals, badges hotbar |
| Cyan froid | pressed / focus |
| Sable clair | texte |

## HUD
- Hotbar : slots `HotbarSlot` + badge touche
- Inventaire : grille fixe, tooltips, poids stub
- Talents : mock local si sidecar KO
- **L** : bascule nameplates (labels courts, sans « PNJ IA »)

## Couches
```
HudLayer → hotbar, state, minimap, info
ModalLayer → talents, inventaire, carte (un modal à la fois T/I)
```

## Icônes flat
- Dossier : `assets/ui/icons/*.svg`
- Hotbar / inventaire via `UiIconRegistry`
- Debug HUD : masqué par défaut · **F9** pour afficher InfoPanel
