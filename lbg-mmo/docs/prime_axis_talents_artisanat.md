# Prime — axe talents Pre-CU + artisanat

**Date** : 2026-07-14  
**Statut** : proposition produit (à valider Thémis / Dédale)  
**Objectif** : faire de Prime un monde centré sur l’**arbre de compétences** et l’**artisanat SWG Pre-CU**, en réduisant la dépendance aux assets retail SWG là où c’est possible.

---

## Question posée

> Core3 peut-il fonctionner **sans fichiers TRE** ?  
> Conserver uniquement talents + artisanat Pre-CU comme axe Prime.

---

## Réponse courte

| Affirmation | Verdict |
|-------------|---------|
| Zéro TRE sur le **serveur** Core3, aujourd’hui | **Non** — le moteur lit les datatables gameplay via `TemplateManager` / archives SOE |
| Zéro TRE côté **client Godot** Prime | **Oui** — déjà le cas (`prime-client` = PNG/JSON) |
| Zéro TRE côté **client SWG** natif | **Non** pour l’UI craft/skills complète — sauf refonte client |
| **Scope produit** = talents + artisanat uniquement | **Oui, viable** — en élaguant le reste du contenu SWG |
| **Pack données minimal** (IFF extraits, pas tout le retail) | **Oui, à terme** — effort modéré à important |

---

## Ce que « TRE » signifie techniquement

Les `.tre` sont des **archives binaires SOE** (datatables IFF, templates objets, strings). Core3 ne les « affiche » pas : il les **parse** au boot.

**Indispensables pour talents + craft** (serveur) :

| Fichier / famille | Rôle |
|-------------------|------|
| `datatables/skill/skills.iff` | Arbre de compétences (`SkillManager`) |
| `datatables/skill/xp_limits.iff` | Coûts XP |
| `datatables/crafting/schematic_group.iff` | Schémas craft |
| `datatables/crafting/component.iff` | Composants |
| `datatables/resource/resource_tree.iff` | Arbre ressources |
| Templates objets | Stations, outils, produits craftés |
| Lua `scripts/skills/`, `scripts/managers/crafting/` | Surcharges LBG |

**Optionnels / client-only** : textures, musique, `patch_fr_00.tre`, `patch_lbg_00.tre`.

---

## Pistes (par ordre de pragmatisme)

### Piste 1 — Prime Scope Lock (recommandée, court terme)

**Garder Core3 + TRE serveur minimal**, figer le périmètre gameplay :

- Actif : professions artisan, survey, ressources, experiment, factories, hubs LBG
- Gelé / retiré : GCW, Jedi, FRS, screenplays SWG, quêtes retail (déjà partiellement fait sur fork clean)
- Client joueur : **SWGEmu + patches** pour UI craft native
- Client observateur : **Godot prime-client** (sans TRE)

**Effort** : configuration + Lua + docs — pas de réécriture moteur.  
**Doc** : `core3_cleanup_plan.md`, `core3_artisan_hub.md`.

### Piste 2 — Pack données « Prime Minimal » (moyen terme)

Extraire vers `bin/datatables/` uniquement les IFF listés ci-dessus + templates objets artisan, réduire `Core3.TreFiles` au strict nécessaire.

- Serveur : plus petit disque, boot plus lisible
- Toujours format IFF/SOE en interne — pas « sans TRE », mais **sans l’intégralité du retail**

**Effort** : tooling extraction + QA boot + tests craft bout-en-bout.

### Piste 3 — UI craft/talents hors client SWG (long terme)

Godot (ou web) parle au serveur via commandes / sidecar `:8791` pour skills + schematics.

- **Serveur** : garde TRE/IFF en interne
- **Joueur** : n’installe plus les `.tre` retail
- **Effort** : très important (UI + protocole + parité gameplay)

### Piste 4 — Moteur sans TemplateManager (hors scope actuel)

Réécrire le chargement datatables en JSON/SQL — fork Core3 profond.  
**Non recommandé** tant que Piste 1–2 ne sont pas épuisées.

---

## Alignement projets

| Projet | Évolution |
|--------|-----------|
| `new_mmo` | ADR + phases Piste 1–2 ; hub artisan LBG |
| `LBG_IA_MMORPG/content/core3/` | Catalogues JSON craft/ressources |
| `prime-client` | Carte / observateur — craft UI plus tard (Piste 3) |
| `Infographiste_IA` | Sprites/stations, pas les TRE |
| `LBG_Project_03` | Routage @dedale/@choeur → design (pas sonde Prime) |

---

## Critères « done » Piste 1

1. Personnage peut monter **artisan** de novice à master (skills.iff + Lua)
2. Boucle complète : survey → harvest → schematic → craft → experiment
3. Hub artisan LBG opérationnel sur 246 (Mod+ test)
4. Doc opérateur : quels TRE sont requis sur serveur vs client
5. Hors scope explicite listé (Jedi, GCW, etc.)

---

## Références code

- `server-core3/server/zone/managers/skill/SkillManager.cpp`
- `server-core3/server/zone/managers/crafting/schematicmap/SchematicMap.cpp`
- `LBG_IA_MMORPG/LBG_IA_MMO/docs/core3_artisan_hub.md`
- `lbg-mmo/docs/core3_cleanup_plan.md` §5–6 (Tre3 / TemplateManager)

## Documents associés

- **ADR** : [`adr/0016-prime-axe-lbg-talents-artisanat.md`](adr/0016-prime-axe-lbg-talents-artisanat.md) — produit LBG vs SOE/SW
- **Inventaire TRE 246** : [`inventaire_tre_prime_246.md`](inventaire_tre_prime_246.md)
