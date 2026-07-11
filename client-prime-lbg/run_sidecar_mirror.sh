#!/usr/bin/env bash
# Lance le miroir sidecar 246:8791 → prime-client/cache (Godot SnapshotBridge).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SIDECAR_URL="${SIDECAR_URL:-http://192.168.0.246:8791}"
export CACHE_DIR="${CACHE_DIR:-${ROOT}/../prime-client/cache}"
export BOTS="${BOTS:-lia,nix,mira}"
exec python3 "${ROOT}/sidecar_mirror.py" "$@"
