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
