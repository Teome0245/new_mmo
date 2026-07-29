#!/usr/bin/env python3
"""Vérifie l'heuristique Y/Z (miroir Projection3D2D.normalize_core3_pos)."""
from __future__ import annotations

import json
import sys
from pathlib import Path

AXIS_SWAP_Z_MAX = 50.0
AXIS_SWAP_Y_MIN = 100.0


def needs_yz_swap(x: float, y: float, z: float) -> bool:
    return abs(z) < AXIS_SWAP_Z_MAX and abs(y) > AXIS_SWAP_Y_MIN


def normalize(x: float, y: float, z: float) -> tuple[float, float, float]:
    if needs_yz_swap(x, y, z):
        return x, z, y
    return x, y, z


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    feed = root / "cache" / "zone_feed.json"
    buildings = root / "assets" / "maps" / "lost_heaven_buildings.json"
    if not feed.exists():
        print("SKIP: zone_feed.json absent")
        return 0

    zf = json.loads(feed.read_text())
    bh = json.loads(buildings.read_text()) if buildings.exists() else {"buildings": []}
    bzs = [float(b["z"]) for b in bh.get("buildings", [])]
    bz_mean = sum(bzs) / len(bzs) if bzs else -800.0

    swapped = 0
    hub_near = 0
    for e in zf.get("entities", []):
        x, y, z = float(e["x"]), float(e.get("y", 0)), float(e["z"])
        nx, ny, nz = normalize(x, y, z)
        if needs_yz_swap(x, y, z):
            swapped += 1
            # après remap, PNJ hub doivent être près des bâtiments en Z
            if 4500 < nx < 5100 and abs(nz - bz_mean) < 500:
                hub_near += 1
        # Lia (déjà Core3) ne doit pas être swappée
        if e.get("name") == "Lia" and needs_yz_swap(x, y, z):
            print("FAIL: Lia ne doit pas être swappée")
            return 1

    print(f"OK: {swapped} entités remappées, {hub_near} near hub buildings (z≈{bz_mean:.0f})")
    if swapped < 5:
        print("WARN: peu de swaps — feed déjà normalisé ?")
    return 0


if __name__ == "__main__":
    sys.exit(main())
