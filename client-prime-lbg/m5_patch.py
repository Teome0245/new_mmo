#!/usr/bin/env python3
"""
m5_patch.py — Applique le patch M5 sur soe_handshake.py
=========================================================
M5 : Connexion live complète — le bridge Godot reçoit :
  - CmdStartScene  (0x0004 sub SWG_OPCODE_GAME) → joueur + planète
  - SceneCreateObjectByName → spawn entités
  - SceneDestroyObject      → despawn entités
  - DataTransform déjà bridgé (M3.1)
  - Etat locomotion → label STANDING/RUNNING/JUMPING...
"""
import re, sys

PATH = "/home/sdesh/projects/new_mmo/client-prime-lbg/soe_handshake.py"

with open(PATH, "r") as f:
    src = f.read()

# ── 1. Ajouter les nouveaux opcodes après SWG_OBJ_CTRL ──────────────────────
OLD_OP = 'SWG_OBJ_CTRL   = 0x001B   # ObjectControllerMessage'
NEW_OP = (
    'SWG_OBJ_CTRL   = 0x001B   # ObjectControllerMessage\n'
    '\n'
    '# Opcodes M5 — connexion live\n'
    'SWG_CMD_START_SCENE = 0x0004   # CmdStartScene (planete + pos + obj_id joueur)\n'
    'SWG_SCENE_CREATE    = 0x0019   # SceneCreateObjectByName (hashed)\n'
    'SWG_SCENE_DESTROY   = 0x001A   # SceneDestroyObject\n'
    '\n'
    '# Hash SWGEmu des messages zone critiques\n'
    'HASH_CMD_START_SCENE = 0x6F46D1D5   # string_hashcode("CmdStartScene")\n'
    'HASH_SCENE_CREATE    = 0xDDDB9F56   # string_hashcode("SceneCreateObjectByName")\n'
    'HASH_SCENE_DESTROY   = 0x4C3D2A07   # string_hashcode("SceneDestroyObject")\n'
)
if OLD_OP in src:
    src = src.replace(OLD_OP, NEW_OP, 1)
    print("  ✓ Opcodes M5 ajoutés")
else:
    print("  ! OLD_OP non trouvé — opcodes déjà patchés ou structure changée")

# ── 2. Ajouter helpers de parsing avant _fmt_delta ──────────────────────────
HELPER_MARKER = 'def _fmt_delta(body: bytes) -> str:'
HELPERS = '''\
# ---------------------------------------------------------------------------
# M5 — Helpers parsing protocole SWG
# ---------------------------------------------------------------------------

import math as _math

def _parse_swg_str(data: bytes, offset: int) -> tuple:
    """Parse une chaine ASCII SWG: uint16_len + bytes.
    Retourne (str, new_offset)."""
    if offset + 2 > len(data):
        return "", offset
    length = struct.unpack("<H", data[offset:offset + 2])[0]
    offset += 2
    if offset + length > len(data):
        return "", offset
    text = data[offset:offset + length].decode("ascii", errors="replace")
    return text, offset + length


def _try_coords(data: bytes, offset: int) -> tuple:
    """Tente d'extraire 3 floats valides (coords Core3) à l'offset donné.
    Retourne (x, y, z, True) ou (0, 0, 0, False)."""
    if offset + 12 > len(data):
        return 0.0, 0.0, 0.0, False
    x, y, z = struct.unpack("<fff", data[offset:offset + 12])
    if any(_math.isnan(v) or _math.isinf(v) or abs(v) > 100_000 for v in (x, y, z)):
        return 0.0, 0.0, 0.0, False
    return x, y, z, True


def _parse_cmd_start_scene(app_data: bytes) -> dict:
    """
    Parse CmdStartScene (sub-opcode de SWG_OPCODE_GAME 0x0004).
    Format SWGEmu:
      app_data[0:2]  = uint16 app_op (0x0004)
      app_data[2:6]  = uint32 hash = HASH_CMD_START_SCENE
      app_data[6:14] = uint64 player_obj_id
      app_data[14:?] = unicode planet (uint16 len + ASCII bytes)
      app_data[?:?+12] = float3 position (x, y, z)
      app_data[?+12:?+16] = float heading
    """
    result = {"obj_id": 0, "planet": "unknown", "x": 0.0, "y": 0.0, "z": 0.0}
    try:
        if len(app_data) < 14:
            return result
        result["obj_id"] = struct.unpack("<Q", app_data[6:14])[0]
        planet, off = _parse_swg_str(app_data, 14)
        result["planet"] = planet if planet else "unknown"
        x, y, z, ok = _try_coords(app_data, off)
        if ok:
            result["x"], result["y"], result["z"] = x, y, z
    except Exception as e:
        pass
    return result


def _parse_scene_create(app_data: bytes) -> dict:
    """
    Parse SceneCreateObjectByName.
    Format SWGEmu:
      app_data[0:2]  = uint16 app_op
      app_data[2:6]  = uint32 hash
      app_data[6:14] = uint64 obj_id
      app_data[14:?] = unicode template_name
      app_data[?:?+12] = float3 position
    """
    result = {"obj_id": 0, "tmpl": "", "x": 0.0, "y": 0.0, "z": 0.0}
    try:
        if len(app_data) < 14:
            return result
        result["obj_id"] = struct.unpack("<Q", app_data[6:14])[0]
        tmpl, off = _parse_swg_str(app_data, 14)
        result["tmpl"] = tmpl
        x, y, z, ok = _try_coords(app_data, off)
        if ok:
            result["x"], result["y"], result["z"] = x, y, z
    except Exception:
        pass
    return result


'''

if HELPER_MARKER in src and 'def _parse_swg_str' not in src:
    src = src.replace(HELPER_MARKER, HELPERS + HELPER_MARKER, 1)
    print("  ✓ Helpers M5 ajoutés")
else:
    print("  ! Helpers déjà présents ou marker non trouvé")

# ── 3. Ajouter connect_player() à GodotBridge ───────────────────────────────
OLD_CLOSE = '''\
    def close(self) -> None:
        self._sock.close()'''
NEW_CLOSE = '''\
    def connect_player(self, obj_id: int, x: float, y: float, z: float,
                       planet: str = "") -> None:
        """M5 : joueur connecté — notifie Godot de son obj_id et sa position."""
        self._send({"t": "cn", "id": obj_id,
                    "x": round(x, 3), "y": round(y, 3), "z": round(z, 3),
                    "pl": planet[:32] if planet else ""})

    def locomotion_state(self, state: str) -> None:
        """Envoie l\'etat de locomotion pour le StateLabel Godot."""
        self._send({"t": "ls", "s": state})

    def close(self) -> None:
        self._sock.close()'''

if OLD_CLOSE in src and 'connect_player' not in src:
    src = src.replace(OLD_CLOSE, NEW_CLOSE, 1)
    print("  ✓ connect_player() + locomotion_state() ajoutés à GodotBridge")
else:
    print("  ! connect_player déjà présent ou OLD_CLOSE non trouvé")

# ── 4. Étendre delta_console_loop_with_bridge ────────────────────────────────
OLD_BASELINE = '''\
            elif app_op == SWG_BASELINE:
                print(f"  [{ts:7.2f}s] -- {_fmt_baseline(body)}")
                pkt_count += 1

    except KeyboardInterrupt:'''

NEW_BASELINE = '''\
            elif app_op == SWG_BASELINE:
                print(f"  [{ts:7.2f}s] -- {_fmt_baseline(body)}")
                pkt_count += 1

            # ── M5 : CmdStartScene → joueur connecté ──────────────────────
            elif app_op == SWG_OPCODE_GAME and len(app_data) >= 6:
                sub_op = struct.unpack("<I", app_data[2:6])[0]

                if sub_op == HASH_CMD_START_SCENE:
                    info = _parse_cmd_start_scene(app_data)
                    oid, planet = info["obj_id"], info["planet"]
                    x, y, z    = info["x"], info["y"], info["z"]
                    print(f"  [{ts:7.2f}s] 🌍 CmdStartScene  obj=0x{oid:016x}  "
                          f"planet={planet}  pos=({x:.1f},{y:.1f},{z:.1f})")
                    bridge.zone_change(planet)
                    bridge.connect_player(oid, x, y, z, planet)
                    pkt_count += 1

                elif sub_op == HASH_SCENE_CREATE:
                    info = _parse_scene_create(app_data)
                    oid  = info["obj_id"]
                    tmpl = info["tmpl"]
                    x, y, z = info["x"], info["y"], info["z"]
                    # Couleur selon template
                    color = "npc"
                    if "player" in tmpl.lower() or "humanoid" in tmpl.lower():
                        color = "green"
                    elif "vehicle" in tmpl.lower():
                        color = "orange"
                    label = tmpl.split("/")[-1].replace(".iff", "")[:16] if tmpl else ""
                    bridge.spawn(oid, x, y, z, color, label)
                    print(f"  [{ts:7.2f}s] ++ Spawn  obj=0x{oid:016x}  {label}  pos=({x:.1f},{y:.1f},{z:.1f})")
                    pkt_count += 1

                elif sub_op == HASH_SCENE_DESTROY:
                    if len(app_data) >= 14:
                        oid = struct.unpack("<Q", app_data[6:14])[0]
                        bridge.despawn(oid)
                        print(f"  [{ts:7.2f}s] -- Despawn  obj=0x{oid:016x}")
                        pkt_count += 1

    except KeyboardInterrupt:'''

if OLD_BASELINE in src and 'HASH_CMD_START_SCENE' not in src[src.find('delta_console_loop_with_bridge'):]:
    src = src.replace(OLD_BASELINE, NEW_BASELINE, 1)
    print("  ✓ Handlers M5 ajoutés à delta_console_loop_with_bridge")
else:
    print("  ! Handlers M5 déjà présents ou marker non trouvé")

with open(PATH, "w") as f:
    f.write(src)

print("\n=== Vérification syntaxe ===")
import ast, subprocess, sys
try:
    ast.parse(src)
    print("  ✓ Syntaxe Python OK")
except SyntaxError as e:
    print(f"  ✗ Erreur syntaxe ligne {e.lineno}: {e.msg}")
    sys.exit(1)

print("\nPatch M5 terminé.")
