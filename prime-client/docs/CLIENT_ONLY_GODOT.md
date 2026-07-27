# Client Godot seul — vision & migration

**Décision produit** : le joueur n’installe **que** `prime-client` (Godot).  
Plus de client retail SWG, plus de `.tre` LucasArts, plus de `lbgemu.exe` / `prime-lbg` sur le poste.

**Ce qui persiste** : le **serveur Core3 Prime** (VM 246, galaxie 3) — simulation, comptes, zone, craft.

Référence : ADR 0016 (`new_mmo/lbg-mmo/docs/adr/0016-prime-axe-lbg-talents-artisanat.md`).

---

## Ce qu’on abandonne (côté joueur)

| Élément | Statut |
|---------|--------|
| Client retail `lbgemu.exe` / `prime-lbg` | **Deprecated** — ne plus documenter comme chemin principal |
| Patches `.tre` client (splash SW, STF retail, musique) | **Hors scope** joueur |
| Launchpad → copie `StarWarsGalaxies/` | **Retrait** post-M12 |
| Mirroring « Teome sur retail + Godot observe » | **Legacy debug** — retiré de la doc joueur |
| Assets visuels LucasArts | Remplacés par sprites/tuiles **Prime** (`assets/sprites/`, `assets/world/`) |

---

## Ce qu’on garde

| Élément | Rôle |
|---------|------|
| **Core3** | Serveur autoritaire (zone, combat, inventaire, craft) |
| **Sidecar IA** `:8791` | Snapshots, talents, craft (lecture HTTP) |
| **Comptes LBG** (ex. Teome) | DB `swgemu` sur 246 — pas le launcher retail |
| **Protocole wire SOE3** (serveur) | Format parlé par Core3 — **interne serveur**, pas « client LucasArts » |

---

## Architecture cible

```
┌─────────────────────┐
│  prime-client       │  ← seul binaire joueur (Godot 4.6)
│  HUD, carte, ZQSD   │
└──────────┬──────────┘
           │  M12 : WebSocket lbg-ws/2 (JSON LBG)
           │  M11 : login gateway (compte LBG, sans lbgemu)
           ▼
┌─────────────────────┐
│  lbg_gateway        │  ← couche réseau LBG (Hermès)
│  + LbgZoneBridge    │     hook C++ dans ZoneServer
└──────────┬──────────┘
           │  SOE3 UDP (interne VM)
           ▼
┌─────────────────────┐
│  Core3 Prime        │
│  Login :44553       │
│  Zone  :44563       │
└─────────────────────┘
```

Le joueur ne voit **jamais** SOE : il parle **lbg-ws/2** à notre gateway.

---

## Transition actuelle (2026-07)

Aujourd’hui le gameplay live passe encore par un **pont Python headless** — ce n’est **pas** le client retail :

| Composant | Chemin | Nature |
|-----------|--------|--------|
| `soe_handshake.py` | `new_mmo/client-prime-lbg/` | Notre implémentation SOE → Core3 (UDP) |
| `prime_controller.py` | idem | ZQSD Godot → DataTransform serveur |
| `network_bridge.gd` | `prime-client/scripts/` | UDP JSON local `:12345` / `:12346` |

**Flux joueur Teome sans retail :**

1. Godot `prime-client`
2. `soe_handshake.py --play --user Teome …`
3. Core3 246

→ **Aucun `lbgemu.exe` requis.**

Ce pont est **temporaire** jusqu’au jalon **M12 (Hermès)**.

---

## Jalons pour supprimer le pont Python

| Jalon | Livrable | Retire |
|-------|----------|--------|
| **M10** | UI talents/craft Godot (sidecar HTTP) | UI craft retail |
| **M11** | Login compte LBG (gateway, token) dans Godot | Login via terminal Python |
| **M12** | `lbg-ws/2` : état zone + commandes `move` | `soe_handshake --play`, `prime_controller` |
| **Fin** | Launchpad + dossier patches client | Tout le stack SWG retail |

Handoff one-shot M11+M12 : `LBG_IA_MMO/infra/scripts/spawn_team_m11_m12.sh` · doc : `LBG_IA_MMO/docs/HANDOFF_SPAWN_M11_M12.md`

Docs techniques M12 :  
`LBG_IA_MMO/docs/core3_zone_bridge_spec.md`,  
`LBG_IA_MMO/docs/jalon_godot_client_live_team.md`,  
agent Hermès : `agents/declarations/godot_dev_hermes.json`.

---

## Frontière IP / technique

- **Star Wars / LucasArts** : noms, visuels, `.tre` retail → **sortie progressive** (Prime = space western LBG).
- **Format SOE côté serveur** : reste tant que Core3 est le moteur — ce n’est pas « dépendre de LucasArts », c’est le wire protocol du fork SWGEmu.
- **Remplacement client** : notre code (GDScript + gateway LBG), pas un exe tiers.

---

## Checklist « poste joueur minimal »

- [ ] Godot 4.6 + `prime-client`
- [ ] (Transition) Python 3 + `client-prime-lbg` pour `--play`
- [ ] Compte LBG sur Prime (admin Core3 ou `ensure_teome_prime_account.sh`)
- [ ] ~~Install SWG retail~~
- [ ] ~~Patches `.tre` client~~
- [ ] ~~Launchpad prime-lbg~~
