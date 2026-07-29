#!/usr/bin/env bash
# Publie le client Godot prime-client sur le serveur de patches Prime (246:8080).
#
# Cible : http://192.168.0.246:8080/patches/prime/
# L'ancien canal TRE/lbgemu est archive une fois en patches/prime-lbgemu/ si encore present.
#
# Usage :
#   bash tools/deploy_prime_client_patch_246.sh
#   VM_HOST=192.168.0.246 CHANNEL=prime bash tools/deploy_prime_client_patch_246.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VM_HOST="${VM_HOST:-192.168.0.246}"
VM_USER="${VM_USER:-lbg}"
REMOTE_ROOT="${REMOTE_ROOT:-/home/lbg/lbg-client-patches}"
CHANNEL="${CHANNEL:-prime}"
LEGACY_CHANNEL="${LEGACY_CHANNEL:-prime-lbgemu}"
STAGE="${STAGE:-${ROOT}/dist/prime-patch}"
PORT="${LBG_CLIENT_PATCH_PORT:-8080}"

echo "==> Generation manifeste + staging"
python3 "${ROOT}/tools/generate_prime_patch_manifest.py" "${STAGE}"

echo "==> SSH ${VM_USER}@${VM_HOST}"
ssh -o BatchMode=yes -o ConnectTimeout=8 "${VM_USER}@${VM_HOST}" bash -s <<REMOTE
set -euo pipefail
mkdir -p "${REMOTE_ROOT}/patches"
if [[ -f "${REMOTE_ROOT}/patches/${CHANNEL}/lbgemu.exe" ]] && [[ ! -d "${REMOTE_ROOT}/patches/${LEGACY_CHANNEL}" ]]; then
  echo "Archive canal TRE → patches/${LEGACY_CHANNEL}"
  mv "${REMOTE_ROOT}/patches/${CHANNEL}" "${REMOTE_ROOT}/patches/${LEGACY_CHANNEL}"
fi
mkdir -p "${REMOTE_ROOT}/patches/${CHANNEL}"
REMOTE

echo "==> rsync → ${VM_HOST}:${REMOTE_ROOT}/patches/${CHANNEL}/"
rsync -a --delete \
  --exclude '.git/' \
  --exclude '.godot/' \
  --exclude 'cache/' \
  --exclude 'dist/' \
  "${STAGE}/" \
  "${VM_USER}@${VM_HOST}:${REMOTE_ROOT}/patches/${CHANNEL}/"

ssh -o BatchMode=yes "${VM_USER}@${VM_HOST}" bash -s <<REMOTE
set -euo pipefail
python3 - <<'PY'
import json
from pathlib import Path
root = Path("${REMOTE_ROOT}")
root.mkdir(parents=True, exist_ok=True)
channels = sorted(p.name for p in (root / "patches").iterdir() if p.is_dir())
(root / "manifest.json").write_text(
    json.dumps({"service": "lbg-client-patches", "channels": channels}, indent=2) + "\n",
    encoding="utf-8",
)
print("channels:", ", ".join(channels))
PY
if systemctl is-active --quiet lbg-client-patch.service 2>/dev/null; then
  echo "lbg-client-patch.service: active"
else
  echo "WARN: lbg-client-patch.service inactif — demarrage…"
  sudo systemctl enable --now lbg-client-patch.service || true
fi
REMOTE

echo "==> Verification HTTP"
BASE="http://${VM_HOST}:${PORT}"
for path in \
  "/patches/${CHANNEL}/manifest.json" \
  "/patches/${CHANNEL}/build_info.json" \
  "/patches/${CHANNEL}/assets/build_info.json" \
  "/patches/${CHANNEL}/project.godot"
do
  code="$(curl -sS -o /tmp/lbg_patch_probe.bin -w '%{http_code}' -m 8 "${BASE}${path}" || echo fail)"
  echo "  ${code}  ${BASE}${path}"
done
export LBG_PATCH_BASE="${BASE}" LBG_PATCH_CHANNEL="${CHANNEL}"
python3 - <<'PY'
import json
import os
import urllib.request

base = os.environ["LBG_PATCH_BASE"]
channel = os.environ["LBG_PATCH_CHANNEL"]
raw = urllib.request.urlopen(f"{base}/patches/{channel}/manifest.json", timeout=8).read()
man = json.loads(raw)
print(f"OK canal={man.get('channel')} version={man.get('version')} files={len(man.get('files', []))}")
PY

echo ""
echo "Reference publique :"
echo "  ${BASE}/patches/${CHANNEL}/manifest.json"
echo "Launchpad : patchServerUrl=${BASE}  patchChannel=${CHANNEL}"
