# Config client Prime (lbgemu)

Fichiers à déployer dans `J:\swgemu\clients\prime-lbg\` uniquement (pas PreCu).

| Fichier | Effet |
|---------|--------|
| `user.cfg` / `lbgemu_client.cfg` | `skipSplash=1` — saute les 3 écrans SOE / LucasArts |
| | `skipIntro=1` — saute l'écran titre « STAR WARS GALAXIES » (étoiles + logo) |
| | `splashTimeoutSeconds=0` — pas d'attente sur le splash résiduel |
| | `disableCutScenes=1` — coupe les cinématiques d'intro planète |
| `patch_lbg_00.tre` | Commande slash `/lbgwe` (World Editor) — voir `docs/client_patch_lbgwe.md` |
| `patch_11_03.tre` + `data_music_00.tre` (Prime) | Branding login + musique titre — `patch_prime_vanilla_branding.py` (backup `.bak.lbg`) |
| `swgemu_live.cfg` | `searchTree_00_25=patch_lbg_00.tre` (priorité au-dessus de patch_fr) |
| `swgemu_live.cfg` | Ligne `messageOfTheDayTable` commentée — pas de texte MOTD défilant au login |

Référence : [SWG Wiki — splash screens](https://swg.fandom.com/wiki/How_to_disable_the_splash_screens), [cutscenes](https://swg.fandom.com/wiki/How_to_disable_the_cutscenes).

Si un bandeau texte persiste, vider `live_motd` dans le patch FR (`patch_fr_00.tre` / `string/fr/live_motd.stf`).

---

## Pont Python SOE + Godot (prime-client)

| Fichier | Rôle |
|---------|------|
| `soe_handshake.py` | Client SOE headless → UDP Godot `:12345` |
| `prime_controller.py` | ZQSD M5 → ZoneServer `:44563` |
| `sidecar_mirror.py` | **Miroir sidecar IA** `http://192.168.0.246:8791` → `../prime-client/cache/` |
| `run_sidecar_mirror.sh` | Lance le miroir (1 poll/s par défaut) |

### Jalon : Godot reconnecté au sidecar 246

1. Vérifier le sidecar : `curl -s http://192.168.0.246:8791/healthz`
2. Terminal A — miroir :
   ```bash
   bash run_sidecar_mirror.sh
   ```
3. Terminal B — Godot :
   ```bash
   godot4 --path ../prime-client
   ```
4. Le `SnapshotBridge` lit `cache/zone_feed.json` et affiche Lia/Nix/Mira.

SOE live (optionnel, M3/M5) :
```bash
python3 soe_handshake.py --host 192.168.0.246 --godot-port 12345 --play
```

Référence orchestrateur : `LBG_IA_MMO/docs/jalon_client_godot_sidecar_246.md`
