#!/usr/bin/env python3
"""
Miroir HTTP sidecar Core3 Prime (:8791) → cache Godot (prime-client).

Poll le sidecar IA sur VM 246 et écrit :
  - player_snapshots.json (format ia_bridge)
  - zone_feed.json (format EntityManager / SnapshotBridge)

Usage :
  python3 sidecar_mirror.py
  SIDECAR_URL=http://192.168.0.246:8791 \\
    CACHE_DIR=../prime-client/cache \\
    BOTS=lia,nix,mira python3 sidecar_mirror.py --once

  python3 sidecar_mirror.py --interval 1.0   # boucle (défaut 1 s)
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any


def sidecar_url() -> str:
    return os.environ.get("SIDECAR_URL", "http://192.168.0.246:8791").strip().rstrip("/")


def cache_dir() -> Path:
    raw = os.environ.get("CACHE_DIR", "").strip()
    if raw:
        return Path(raw)
    here = Path(__file__).resolve().parent
    return here.parent / "prime-client" / "cache"


def bot_ids() -> list[str]:
    raw = os.environ.get("BOTS", "lia,nix,mira,kael").strip()
    return [p.strip().lower() for p in raw.split(",") if p.strip()]


def http_get_json(url: str, *, timeout: float = 8.0) -> tuple[int, dict[str, Any]]:
    req = urllib.request.Request(url, method="GET")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = resp.read().decode("utf-8", errors="replace")
            code = resp.status
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace") if e.fp else ""
        code = e.code
    data: dict[str, Any] = {}
    if body.strip():
        try:
            parsed = json.loads(body)
            if isinstance(parsed, dict):
                data = parsed
        except json.JSONDecodeError:
            pass
    return code, data


def fetch_health(base: str) -> bool:
    code, data = http_get_json(f"{base}/healthz")
    if code != 200:
        return False
    return data.get("ok") is not False


def fetch_player_snapshot(base: str, bot: str) -> dict[str, Any]:
    q = urllib.parse.urlencode({"player": bot.capitalize()})
    code, data = http_get_json(f"{base}/v1/player-snapshot?{q}")
    snap: dict[str, Any] = {}
    if isinstance(data.get("snapshot"), dict):
        snap = data["snapshot"]
    elif isinstance(data, dict) and data.get("x") is not None:
        snap = data
    snap.setdefault("player", bot)
    snap["online"] = bool(snap.get("online") or snap.get("connected") or (code == 200 and data.get("ok")))
    return snap


def build_player_snapshots(players: dict[str, dict[str, Any]]) -> dict[str, Any]:
    return {"players": players, "ts": time.time(), "source": "sidecar_mirror"}


def build_zone_feed(players: dict[str, dict[str, Any]]) -> dict[str, Any]:
    entities: list[dict[str, Any]] = []
    for bot, snap in players.items():
        if not snap.get("online"):
            continue
        name = str(snap.get("firstname") or snap.get("player") or bot).capitalize()
        entities.append(
            {
                "id": f"player:{name}",
                "kind": "player",
                "name": name,
                "x": float(snap.get("x", 0.0)),
                "y": float(snap.get("y", 0.0)),
                "z": float(snap.get("z", 0.0)),
                "online": True,
                "zone": str(snap.get("zone", "")),
            }
        )
    return {"entities": entities, "ts": time.time(), "source": "sidecar_mirror", "sidecar": sidecar_url()}


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    tmp.replace(path)


def mirror_once(*, verbose: bool = True) -> dict[str, Any]:
    base = sidecar_url()
    out_dir = cache_dir()
    health_ok = fetch_health(base)
    players: dict[str, dict[str, Any]] = {}
    for bot in bot_ids():
        players[bot] = fetch_player_snapshot(base, bot)

    player_doc = build_player_snapshots(players)
    zone_doc = build_zone_feed(players)
    write_json(out_dir / "player_snapshots.json", player_doc)
    write_json(out_dir / "zone_feed.json", zone_doc)

    online = sum(1 for s in players.values() if s.get("online"))
    result = {
        "ok": health_ok and online > 0,
        "sidecar": base,
        "cache_dir": str(out_dir),
        "health_ok": health_ok,
        "online_count": online,
        "bots": list(players.keys()),
    }
    if verbose:
        print(json.dumps(result, ensure_ascii=False))
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description="Miroir sidecar :8791 → cache Godot prime-client")
    parser.add_argument("--once", action="store_true", help="Une seule itération puis quitter")
    parser.add_argument("--interval", type=float, default=1.0, help="Intervalle boucle (s)")
    args = parser.parse_args()

    if args.once:
        res = mirror_once()
        return 0 if res.get("ok") else 2

    print(f"[sidecar_mirror] {sidecar_url()} → {cache_dir()} (Ctrl+C pour arrêter)", flush=True)
    try:
        while True:
            mirror_once(verbose=False)
            time.sleep(max(0.25, args.interval))
    except KeyboardInterrupt:
        print("\n[sidecar_mirror] arrêt.", flush=True)
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
