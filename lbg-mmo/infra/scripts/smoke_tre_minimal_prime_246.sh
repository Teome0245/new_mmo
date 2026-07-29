#!/usr/bin/env bash
# Smoke TreFiles minimal — Prime 246 (serveur sans assets visuels client)
#
# Objectif : valider boot core3-clean avec TreFiles réduit (~1,2 Go gameplay, sans textures/meshes).
# Contexte : client cible = Godot prime-client (pas SWG retail) → serveur n'a pas besoin du pack visuel.
#
# Usage :
#   bash smoke_tre_minimal_prime_246.sh --dry-run
#   bash smoke_tre_minimal_prime_246.sh --apply
#   bash smoke_tre_minimal_prime_246.sh --rollback
#
# Prérequis : SSH lbg@192.168.0.246, service lbg-core3-prime.service

set -euo pipefail

HOST="${LBG_PRIME_HOST:-192.168.0.246}"
USER="${LBG_PRIME_USER:-lbg}"
BIN="/opt/lbg-new-mmo-clean/MMOCoreORB/bin"
CONF="${BIN}/conf/config-local.lua"
BACKUP_SUFFIX=".bak.tre-minimal-$(date +%Y%m%d%H%M%S)"
LOG="/tmp/core3-clean.log"
SERVICE="lbg-core3-prime.service"
BOOT_WAIT="${BOOT_WAIT_SEC:-180}"

TRE_MINIMAL_MARKER="LBG_TRE_MINIMAL_SERVER=1"

ssh_cmd() {
  ssh -o ConnectTimeout=15 "${USER}@${HOST}" "$@"
}

dry_run() {
  echo "=== Dry-run TreFiles minimal sur ${HOST} ==="
  echo "Config: ${CONF}"
  echo "Exclus: data_texture_*, data_static_mesh_*, data_skeletal_mesh_*, data_animation_*, data_sample_*, data_music_*"
  echo "Conservés: bottom.tre, patch_*, data_sku1_*, data_other_00, default_patch"
  ssh_cmd "grep -c TreFiles ${BIN}/conf/config.lua; du -sh /opt/lbg-new-mmo/tre"
}

apply() {
  echo "=== Apply TreFiles minimal sur ${HOST} ==="
  ssh_cmd "bash -s" <<REMOTE
set -euo pipefail
CONF="${CONF}"
BIN="${BIN}"
BACKUP="\${CONF}${BACKUP_SUFFIX}"
MARKER="${TRE_MINIMAL_MARKER}"

if grep -q "\${MARKER}" "\${CONF}" 2>/dev/null; then
  echo "Déjà en mode TreFiles minimal (\${MARKER})"
  exit 0
fi

cp -a "\${CONF}" "\${BACKUP}"
echo "Backup: \${BACKUP}"

cat >> "\${CONF}" <<'LUA'

-- LBG_TRE_MINIMAL_SERVER=1 — smoke serveur sans assets visuels (client cible Godot)
-- Généré par smoke_tre_minimal_prime_246.sh — rollback via --rollback
Core3.TreFiles = {
	"default_patch.tre",
	"patch_sku1_14_00.tre",
	"patch_14_00.tre",
	"patch_sku1_13_00.tre",
	"patch_13_00.tre",
	"patch_sku1_12_00.tre",
	"patch_12_00.tre",
	"patch_11_03.tre",
	"data_sku1_07.tre",
	"patch_11_02.tre",
	"data_sku1_06.tre",
	"patch_11_01.tre",
	"patch_11_00.tre",
	"data_sku1_05.tre",
	"data_sku1_04.tre",
	"data_sku1_03.tre",
	"data_sku1_02.tre",
	"data_sku1_01.tre",
	"data_sku1_00.tre",
	"patch_10.tre",
	"patch_09.tre",
	"patch_08.tre",
	"patch_07.tre",
	"patch_06.tre",
	"patch_05.tre",
	"patch_04.tre",
	"patch_03.tre",
	"patch_02.tre",
	"patch_01.tre",
	"patch_00.tre",
	"data_other_00.tre",
	"bottom.tre"
}
LUA

echo "Redémarrage lbg-core3-prime.service..."
sudo systemctl restart lbg-core3-prime.service

echo "Attente boot (\${BOOT_WAIT}s max)..."
for i in \$(seq 1 ${BOOT_WAIT}); do
  if pgrep -x core3-clean >/dev/null 2>&1; then
    if grep -qE "ZoneServer.*started|Server started|Loading complete" "\${LOG}" 2>/dev/null; then
      echo "Boot signal détecté après \${i}s"
      break
    fi
  fi
  sleep 1
done

sleep 5

ERRS=\$(grep -ciE "TreeFile|error loading tre|failed to load.*tre|Could not load.*tre" "\${LOG}" 2>/dev/null | tail -1 || echo 0)
SKILL=\$(grep -ci "SkillManager" "\${LOG}" 2>/dev/null | tail -1 || echo 0)
RUNNING=\$(pgrep -x core3-clean >/dev/null && echo yes || echo no)

echo "=== Résultat ==="
echo "core3-clean running: \${RUNNING}"
echo "tre errors (log): \${ERRS}"
echo "skill mentions (log): \${SKILL}"

if [[ "\${RUNNING}" != "yes" ]]; then
  echo "FAIL: processus absent — rollback"
  cp -a "\${BACKUP}" "\${CONF}"
  sudo systemctl restart lbg-core3-prime.service
  exit 1
fi

if grep -qiE "TreeFile.*error|ERROR.*tre" "\${LOG}" 2>/dev/null; then
  echo "WARN: erreurs TRE dans le log — vérifier manuellement"
  tail -30 "\${LOG}"
fi

echo "OK — TreFiles minimal actif. Backup: \${BACKUP}"
REMOTE
}

rollback() {
  echo "=== Rollback TreFiles sur ${HOST} ==="
  ssh_cmd "bash -s" <<REMOTE
set -euo pipefail
CONF="${CONF}"
LATEST=\$(ls -t \${CONF}.bak.tre-minimal-* 2>/dev/null | head -1)
if [[ -z "\${LATEST}" ]]; then
  echo "Aucun backup .bak.tre-minimal-* trouvé"
  # Retirer bloc TreFiles minimal si présent
  if grep -q "${TRE_MINIMAL_MARKER}" "\${CONF}"; then
    sed -i '/${TRE_MINIMAL_MARKER}/,\$d' "\${CONF}" 2>/dev/null || true
    echo "Bloc minimal retiré"
    sudo systemctl restart lbg-core3-prime.service
  fi
  exit 0
fi
cp -a "\${LATEST}" "\${CONF}"
echo "Restauré: \${LATEST}"
sudo systemctl restart ${SERVICE}
echo "Service redémarré"
REMOTE
}

case "${1:-}" in
  --dry-run) dry_run ;;
  --apply) apply ;;
  --rollback) rollback ;;
  *)
    echo "Usage: $0 --dry-run | --apply | --rollback"
    exit 1
    ;;
esac
