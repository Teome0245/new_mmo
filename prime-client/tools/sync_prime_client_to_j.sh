#!/usr/bin/env bash
# Sync complet prime-client (WSL) → J: + tampon build_info.json
set -euo pipefail

SRC="${PRIME_SRC:-/home/sdesh/projects/new_mmo/prime-client}"
DST="${PRIME_DST:-/mnt/j/swgemu/clients/prime-client}"

if [[ ! -d "$SRC" ]]; then
  echo "SRC absent: $SRC" >&2
  exit 1
fi
if [[ ! -d "$(dirname "$DST")" ]]; then
  echo "J: non monté — DST=$DST" >&2
  exit 1
fi

STAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
SCHEMA="$(python3 -c "import json; print(json.load(open('$SRC/assets/maps/tatooine_map_config.json')).get('schema_version',0))" 2>/dev/null || echo 0)"

export STAMP SRC SCHEMA
mkdir -p "$SRC/assets"
python3 - <<'PY'
import json, os
out = {
    "client_id": "prime-client",
    "synced_at": os.environ["STAMP"],
    "sync_source": os.environ["SRC"],
    "expected_launch_path_windows": "J:\\\\swgemu\\\\clients\\\\prime-client",
    "launchpad_profile": "prime",
    "map_config_schema": int(os.environ.get("SCHEMA") or 0),
}
path = os.path.join(os.environ["SRC"], "assets", "build_info.json")
with open(path, "w", encoding="utf-8") as f:
    json.dump(out, f, indent=2)
    f.write("\n")
print("OK build_info.json", out["synced_at"])
PY

export STAMP SRC SCHEMA

rsync -a --delete \
  --exclude '.git/' \
  --exclude '.godot/' \
  --exclude '*.import' \
  "$SRC/" "$DST/"

echo "OK rsync → $DST"
echo "Relance via LBG Launchpad (profil Prime) ou Godot --path J:\\swgemu\\clients\\prime-client"
