#!/usr/bin/env python3
"""Génère staging + manifest.json + build_info pour le patch Launchpad (canal prime / Godot).

Usage:
  python3 tools/generate_prime_patch_manifest.py [/chemin/sortie]

Par défaut : <prime-client>/dist/prime-patch/
Le staging contient l’arborescence client + manifest.json + build_info.json à la racine.
"""
from __future__ import annotations

import hashlib
import json
import os
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SKIP_DIRS = {".git", ".godot", "__pycache__", "cache", "dist"}
SKIP_SUFFIXES = {".swp", ".tmp", ".import"}


def md5_file(path: Path) -> str:
    h = hashlib.md5()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def iter_files(root: Path):
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = sorted(d for d in dirnames if d not in SKIP_DIRS)
        for name in sorted(filenames):
            if any(name.endswith(suf) for suf in SKIP_SUFFIXES):
                continue
            full = Path(dirpath) / name
            rel = full.relative_to(root).as_posix()
            if rel.startswith("tools/generate_prime_patch_manifest"):
                continue
            yield rel, full


def main() -> int:
    out_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "dist" / "prime-patch"
    if out_dir.exists():
        shutil.rmtree(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    stamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    schema = 0
    map_cfg = ROOT / "assets" / "maps" / "tatooine_map_config.json"
    if map_cfg.is_file():
        try:
            schema = int(json.loads(map_cfg.read_text(encoding="utf-8")).get("schema_version", 0))
        except (json.JSONDecodeError, TypeError, ValueError):
            schema = 0

    files = []
    for rel, full in iter_files(ROOT):
        dest = out_dir / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(full, dest)
        files.append({"name": rel, "hash": md5_file(full), "size": full.stat().st_size})

    build_info = {
        "client_id": "prime-client",
        "synced_at": stamp,
        "sync_source": str(ROOT),
        "expected_launch_path_windows": "J:\\swgemu\\clients\\prime-client",
        "launchpad_profile": "prime",
        "map_config_schema": schema,
        "file_count": len(files),
        "patch_channel": "prime",
        "patch_host_hint": "192.168.0.246:8080",
    }

    # build_info dans assets/ (lu par le client) + copie racine (lu par le launchpad)
    assets_bi = out_dir / "assets" / "build_info.json"
    assets_bi.parent.mkdir(parents=True, exist_ok=True)
    bi_text = json.dumps(build_info, indent=2, ensure_ascii=False) + "\n"
    assets_bi.write_text(bi_text, encoding="utf-8")
    (out_dir / "build_info.json").write_text(bi_text, encoding="utf-8")

    # Remplacer / ajouter hash build_info dans le manifeste
    bi_hash = md5_file(assets_bi)
    bi_size = assets_bi.stat().st_size
    files = [f for f in files if f["name"] != "assets/build_info.json"]
    files.append({"name": "assets/build_info.json", "hash": bi_hash, "size": bi_size})
    files.sort(key=lambda f: f["name"])

    manifest = {
        "channel": "prime",
        "version": stamp,
        "client_id": "prime-client",
        "map_config_schema": schema,
        "synced_at": stamp,
        "files": files,
    }

    (out_dir / "manifest.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    print(f"OK {len(files)} fichiers → {out_dir}")
    print(f"   version={stamp}")
    print("Publier :")
    print(f"  bash tools/deploy_prime_client_patch_246.sh")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
