# Sprites 2D top-down — Prime Client

Générés par **Infographiste_IA** (ComfyUI + LoRA `mmorpg_insp`), déployés via `deploy_sprites_to_prime.sh`.

```
assets/sprites/
  units/
    player_bot.png      # bots Nix, Lia, Mira…
    player_official.png
    npc_default.png
    npc_guard.png
```

Mapping : `config/sprite_manifest.json` → `SpriteRegistry.gd`

Si un PNG est absent, l'entité reste un **cercle coloré** (fallback).
