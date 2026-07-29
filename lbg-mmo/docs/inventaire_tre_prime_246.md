# Inventaire TRE — Prime VM 246

**Date** : 2026-07-14  
**Hôte** : `192.168.0.246`  
**Chemin actif** : `/opt/lbg-new-mmo/tre` (via `Core3.TrePath` dans `config-local.lua`)  
**Mesures** : SSH réelles (`du`, `find`)

---

## Synthèse

| Métrique | Valeur |
|----------|--------|
| Fichiers `.tre` | **53** |
| Taille totale | **2,8 Go** |
| Estimation **visuel client** (textures, meshes, musique, samples…) | **~1,7 Go** |
| Estimation **données gameplay** (bottom, patch_*, sku, other) | **~1,2 Go** |
| Overrides `bin/datatables/` sur clean | **0** (aucun IFF extrait aujourd’hui) |
| Disque `/opt` | **87 %** utilisé |

---

## Configuration serveur (246)

```lua
Core3.TrePath = "/opt/lbg-new-mmo/tre"
```

`TreFiles` : **53 entrées** (liste complète dans `config.lua` — `bottom.tre` en dernier, patches `patch_00`…`patch_14`, `data_sku1_*`, assets visuels).

Référence dev obsolète dans `config.lua` : `TrePath = "/home/sdesh/projects/new_mmo/StarWarsGalaxies"` — **non utilisée** en prod (overridée par `config-local.lua`).

---

## Top fichiers (taille)

| Fichier | Taille | Catégorie probable |
|---------|--------|-------------------|
| `data_texture_*.tre` (×8) | ~800 Mo | **Visuel client** |
| `data_sample_*.tre` (×5) | ~500 Mo | **Visuel / audio** |
| `data_sku1_*.tre` (×8) | ~700 Mo | **Mixte** (objets + assets) |
| `data_static_mesh_*.tre` | ~191 Mo | **Visuel** |
| `data_skeletal_mesh_*.tre` | ~141 Mo | **Visuel** |
| `patch_11_00.tre` | 99 Mo | Gameplay / contenu |
| `data_music_00.tre` | 74 Mo | **Visuel client** |
| `data_animation_00.tre` | 57 Mo | **Visuel** |
| `patch_09` … `patch_14` | 35–55 Mo chacun | Gameplay / contenu |
| `bottom.tre` | **16 Mo** | **Datatables cœur** |
| `patch_00.tre` | 18 Mo | Gameplay / contenu |
| `data_other_00.tre` | 45 Mo | Mixte |
| `default_patch.tre` | 60 Ko | Config |

---

## Pack minimal proposé — talents + artisanat (serveur)

### Hypothèse

Le serveur Prime n’a **pas besoin du rendu** (textures/musique/samples) si les IFF logiques (skills, schematics, templates objets craft) sont accessibles via `bottom.tre`, patches et/ou `bin/datatables/`.

### Phase A — candidats à retirer du **serveur** (après smoke boot)

> ⚠️ À valider par un **boot + login + craft test** avant suppression définitive.

| Groupe | Fichiers | Taille estimée | Risque boot |
|--------|----------|----------------|-------------|
| Textures | `data_texture_00` … `07` | ~800 Mo | Faible si pas de mesh server-side |
| Samples | `data_sample_00` … `04` | ~500 Mo | Faible |
| Musique | `data_music_00.tre` | 74 Mo | Nul serveur |
| Animation | `data_animation_00.tre` | 57 Mo | Faible |
| Meshes statiques/squelettiques | `data_static_mesh_*`, `data_skeletal_mesh_*` | ~330 Mo | **Moyen** — certains templates objets peuvent y référencer |

**Gain potentiel serveur** : **~1,4–1,7 Go** si boot OK sans meshes retail.

### Phase B — noyau gameplay à **conserver** (court terme)

| Fichier / famille | Rôle talents + craft |
|-------------------|----------------------|
| `bottom.tre` | Datatables racine (skills, crafting, resource…) |
| `patch_00.tre` … `patch_14*.tre` | Contenu PreCU cumulé |
| `data_sku1_*.tre` | Extensions objets / SKU |
| `data_other_00.tre` | Divers datatables |
| `default_patch.tre`, `hotfix_*.tre` | Correctifs |

### Phase C — extraction vers `bin/datatables/` (moyen terme)

Extraire et versionner (ou déployer) :

```
datatables/skill/skills.iff
datatables/skill/xp_limits.iff
datatables/crafting/schematic_group.iff
datatables/crafting/component.iff
datatables/resource/resource_tree.iff
```

Puis réduire `TreFiles` au minimum validé par QA.

---

## Procédure de test (avant toute suppression)

```bash
# Sur 246 — dry-run : copie config TreFiles réduite dans config-local.lua
# 1. Backup
sudo cp -a /opt/lbg-new-mmo/tre /opt/lbg-new-mmo/tre.bak

# 2. Redémarrer core3-clean après modification TreFiles
# 3. Smoke :
#    - boot sans TreeFile error dans core3.log
#    - SkillManager loaded
#    - login compte test
#    - /grant skill crafting_artisan_novice (ou équivalent)
#    - craft test via station
```

---

## Client vs serveur

| Cible | TRE requis ? |
|-------|--------------|
| **Serveur 246** (pack minimal) | Réductible (~1,2 Go → moins si extraction IFF) |
| **Client SWGEmu Prime** | **Oui** — `searchTree` complet + `patch_fr` + `patch_lbg` |
| **Godot prime-client** | **Non** |

---

## Liens

- ADR : [`adr/0016-prime-axe-lbg-talents-artisanat.md`](adr/0016-prime-axe-lbg-talents-artisanat.md)
- Vision : [`prime_axis_talents_artisanat.md`](prime_axis_talents_artisanat.md)
- Nettoyage IP SW : [`core3_cleanup_plan.md`](core3_cleanup_plan.md)

---

## Historique

| Date | Action |
|------|--------|
| 2026-07-14 | Inventaire SSH initial 246 |
| 2026-07-14 | **Smoke TreFiles minimal appliqué** — boot OK, UDP 44553/44562, sidecar `:8791` OK ; warnings meshes attendus (pas de pack visuel) ; config `config-local.lua` + marker `LBG_TRE_MINIMAL_SERVER=1` |

## Résultat smoke (2026-07-14)

| Check | Résultat |
|-------|----------|
| `core3-clean` running | ✅ |
| Login UDP 44553 | ✅ |
| Sidecar 8791 | ✅ |
| TreeArchive mesh WARNING | ⚠️ attendu sans `data_static_mesh_*` |
| CellProperty mesh errors | ⚠️ bâtiments — acceptable serveur Godot-only |
| Rollback | `bash smoke_tre_minimal_prime_246.sh --rollback` |
