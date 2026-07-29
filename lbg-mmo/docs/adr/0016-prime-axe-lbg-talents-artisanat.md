# ADR 0016 — Prime LBG : axe talents + artisanat, indépendance produit

## Statut

**Proposé** — 2026-07-14  
**Décideurs** : Pilote, @dedale (Dédale), @themis (Thémis)  
**Contexte** : question produit — conserver Core3 tout en visant un monde **LBG** (pas Star Wars), centré **talents Pre-CU + artisanat**.

---

## Contexte

1. **Prime 246** tourne en prod sur Core3 fork (`server-core3`, binaire `core3-clean`).
2. Les données gameplay passent par archives **SOE `.tre`** / IFF (`TemplateManager`) — voir [`inventaire_tre_prime_246.md`](../inventaire_tre_prime_246.md).
3. Un plan de **neutralisation IP Star Wars** existe déjà : [`core3_cleanup_plan.md`](../core3_cleanup_plan.md).
4. L’équipe souhaite un produit **« LBG »** — pas un émulateur SWG retail rebrandé minimal.

---

## Question centrale

> En gardant le **serveur Core3**, peut-on se libérer **complètement** de SOE et Star Wars ?

---

## Décision — lecture en trois couches

### Couche 1 — Marque et univers (Star Wars) → **Oui, progressivement**

| Élément | Libération possible ? | Piste |
|---------|----------------------|-------|
| Noms planètes, factions Empire/Rebelle | **Oui** | Remplacer datatables + Lua (`core3_cleanup_plan` phases 1–4) |
| Espèces jouables SW | **Oui** | `datatables/creation/` LBG |
| Screenplays, quêtes, PNJ IP | **Oui** | Supprimer / remplacer par `content/core3/` LBG |
| Jedi, GCW, FRS, holocrons | **Oui** | Déjà ciblés suppression C++ |
| Strings UI `@sui:swg`, STF retail | **Oui** | Patches client LBG + STF custom |
| Hub artisan, économie MVP LBG | **Oui** | Déjà en cours (`core3_artisan_hub`) |

**Verdict** : un produit **« LBG Prime »** thématiquement indépendant de Star Wars est **réaliste** sur Core3 — c’est un programme **contenu + code**, pas un nouveau moteur.

### Couche 2 — Formats et protocole SOE → **Non pas « complètement » à court terme**

| Élément | Garder Core3 = garder… | Alternative |
|---------|------------------------|-------------|
| Archives `.tre` / IFF **format SOE** | **Oui** (moteur `tre3/`) | Réécriture `TemplateManager` → JSON/SQL (années) |
| Protocole réseau **SOE3** UDP | **Oui** si client **SWGEmu** | Client Godot/custom + nouveau protocole |
| Opcodes paquets, login SWG | **Oui** avec client natif | Pont `lbg-ws/2` (jalon Hermès) |

**Verdict** : « Se libérer de SOE » au sens **technique strict** (formats + wire protocol) = **nouveau client + gros fork** ou abandon progressif du client SWG. Ce n’est **pas** l’horizon immédiat.

### Couche 3 — Axe produit talents + artisanat → **Oui, c’est l’Étoile du nord Prime**

Prime = monde où la boucle centrale est :

```
compétences (skills.iff) → schémas → ressources → craft → experiment → économie
```

Tout le reste (JTL, GCW, quêtes retail, sandbox Python) est **secondaire ou gelé**.

---

## Décisions formelles

1. **Prime** est positionné comme **« LBG — talents Pre-CU + artisanat »**, pas comme émulateur SWG généraliste.

2. **Indépendance Star Wars (IP)** : objectif **accepté** — exécution via `core3_cleanup_plan` + catalogues `content/core3/` + patches client LBG. Jalons mesurables (pas de Tatooine en prod LBG, pas de faction Empire, etc.).

3. **Indépendance SOE (format)** : **non requise** pour la phase courante ; les `.tre` restent le bus de données **interne** jusqu’à extraction IFF minimale ([`inventaire_tre_prime_246.md`](../inventaire_tre_prime_246.md) phases B–C).

4. **Client joueur cible** : **`prime-client` Godot** — seul client produit à terme ; client SWGEmu = **transition** jusqu'à M5/M6 craft+réseau Godot (jalon Hermès).

5. **Pack TRE serveur** : réduire de **~2,8 Go → ~1,2 Go** (phase A inventaire) — validé par smoke sans assets visuels ; le serveur n'alimente plus le client SWG retail.

6. **Hors scope immédiat** : réécriture complète TemplateManager ; redistribution assets retail SWG.

### Amendement 2026-07-14 — Client Godot unique

| Avant | Après |
|-------|-------|
| SWGEmu + Godot en parallèle indéfiniment | **Godot = client LBG** ; SWGEmu **décommissionné** après parité craft/réseau |
| Patches `.tre` client LBG long terme | **Abandonnés** avec le client SWG |
| Protocole SOE3 côté joueur | **Transition** : sidecar/snapshots → puis pont Godot↔Core3 (UDP/WS) |

**Phases client Godot** :

| Phase | Livrable | Dépendance serveur |
|-------|----------|-------------------|
| **M9** (fait) | Carte, minimap, sidecar mirror | Aucun TRE client |
| **M10** | UI talents + craft (2D) | Commandes / sidecar `:8791` |
| **M11** | Login + perso LBG (sans SOE login) | API ou pont léger |
| **M12** | Réseau autoritaire Godot (Hermès) | `lbg-ws/2` ou protocole documenté |
| **Fin SWG** | Retrait launchpad + patches `.tre` client | Serveur TreFiles minimal OK |


---

## Conséquences

| Composant | Action |
|-----------|--------|
| `server-core3` | Poursuivre fork clean ; retirer modules SW (Jedi, GCW…) |
| `content/core3/` | Catalogues LBG (ressources, quêtes data-driven, hub artisan) |
| **`prime-client` (Godot)** | **Client LBG cible** — talents, craft, réseau ; remplace SWGEmu |
| Client SWGEmu | **Transition** — retirer après M10–M12 |
| VM 246 | TreFiles minimal serveur (smoke) ; pas de pack visuel pour SWG |
| `Infographiste_IA` | Sprites/stations PNG pour Godot (pas `.tre` retail) |

---

## Critères de succès

### IP / produit LBG

- [ ] Aucune planète / faction / espèce SWG retail requise pour jouer artisan
- [ ] Branding login et UI : **LBG**, pas « Star Wars Galaxies »
- [ ] Documentation opérateur : distinction **moteur Core3** vs **univers LBG**

### Gameplay axe artisan

- [ ] Parcours novice → master artisan validé sur 246
- [ ] Hub artisan LBG opérationnel (Mod+)
- [ ] Smoke craft : survey → schematic → experiment

### Données

- [ ] Inventaire TRE minimal validé par boot + craft
- [ ] Liste `TreFiles` réduite documentée
- [ ] (Optionnel) IFF skills/craft dans `bin/datatables/` versionnés

---

## Réponse courte à la question posée

**Oui** pour un produit **LBG** (univers, gameplay, marque) en gardant Core3.  
**Non** pour une libération **totale et immédiate** des formats et protocoles SOE — sauf à changer de client et réécrire le chargement de données, ce qui est une **autre phase produit**.

En pratique : **moteur SWGEmu, monde LBG**.

---

## Références

- [`prime_axis_talents_artisanat.md`](../prime_axis_talents_artisanat.md)
- [`inventaire_tre_prime_246.md`](../inventaire_tre_prime_246.md)
- [`core3_cleanup_plan.md`](../core3_cleanup_plan.md)
- `LBG_IA_MMORPG/.../docs/adr/0005-new-mmo-core3-coexistence.md`
- `LBG_IA_MMORPG/.../docs/core3_artisan_hub.md`
- **ADR 0017** — Core3 spatial + peel services (anti techno-tourisme) : [`0017-core3-spatial-peel-services.md`](0017-core3-spatial-peel-services.md) → texte canonique monorepo IA

---

## Historique

| Date | Événement |
|------|-----------|
| 2026-07-14 | Rédaction ADR + inventaire TRE 246 |
| 2026-07-14 | Amendement client **Godot unique** ; SWGEmu transition ; smoke TreFiles minimal serveur |
| 2026-07-28 | Renvoi ADR **0017** (garde Core3 spatial + sidecar transactionnel) |
