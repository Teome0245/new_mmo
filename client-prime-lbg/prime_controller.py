#!/usr/bin/env python3
"""
prime_controller.py — Contrôles de mouvement Core3 (M4)
=========================================================
M4.1 : ZQSD → paquets ObjectController/DataTransform (via commandes UDP Godot)
M4.2 : Espace → saut (impulsion Y Core3, gravité simulée)
M4.3 : Détection eau (Y <= water_level) → état nage + state bits

Architecture :
  Godot player_controller.gd ──UDP:12346──► CommandServer (ici)
                                               │
  PlayerController (physique 20 Hz)            │
       │  DataTransform                        │
       └──► ZoneServer (SOEClient)             │
       │                                       │
       └──UDP:12345──► NetworkBridge Godot (self-position update)

Usage autonome (headless, sans Godot) :
  python prime_controller.py \\
      --host 192.168.0.246 --zone-port 44463 \\
      --obj-id 0x1234 --crc-seed 0xDEADBEEF \\
      --seq-start 1 \\
      [--listen-port 12346] [--godot-port 12345]

Usage intégré : instancié par soe_handshake.py après connexion zone.
"""
import socket
import struct
import math
import time
import threading
import json
import argparse
import sys
from dataclasses import dataclass, field
from enum import Enum
from typing import Optional

try:
    from soe_handshake import (
        SOEClient, generate_crc32, encrypt_payload, decrypt_payload,
        CTRL_DATA_TRANSFORM, CTRL_DATA_TRANSFORM_WITH_PARENT,
        GodotBridge, SWG_OBJ_CTRL,
    )
except ImportError as e:
    print(f"ERREUR import soe_handshake: {e}")
    sys.exit(1)

# ---------------------------------------------------------------------------
# Constantes physique SWGEmu
# ---------------------------------------------------------------------------
SPEED_WALK:     float = 1.45   # m/s marche
SPEED_RUN:      float = 5.00   # m/s course (Shift)
SPEED_SWIM:     float = 1.20   # m/s nage
JUMP_IMPULSE:   float = 4.00   # m/s impulsion verticale (Space)
GRAVITY:        float = 9.80   # m/s² downward
WATER_LEVEL:    float = 0.00   # Y <= WATER_LEVEL → nage
TICK_RATE:      float = 0.05   # 20 Hz (50 ms)
PKT_INTERVAL:   float = 0.10   # envoie DataTransform max toutes les 100 ms

# Flags DataTransform (Core3 PlayerObject locomotion)
FLAG_STOP    = 0x00
FLAG_WALK    = 0x08
FLAG_RUN     = 0x0A
FLAG_JUMP    = 0x20
FLAG_SWIM    = 0x02

# ---------------------------------------------------------------------------
# État du joueur
# ---------------------------------------------------------------------------

class LocomotionState(str, Enum):
    STANDING  = "standing"
    WALKING   = "walking"
    RUNNING   = "running"
    JUMPING   = "jumping"
    FALLING   = "falling"
    SWIMMING  = "swimming"


@dataclass
class PlayerState:
    x: float = 0.0
    y: float = 0.0   # altitude (vertical Core3)
    z: float = 0.0
    heading: float   = 0.0   # radians, 0 = Nord
    vel_y:   float   = 0.0   # vitesse verticale
    speed:   float   = 0.0   # vitesse horizontale courante
    state:   LocomotionState = LocomotionState.STANDING

    # Inputs actifs (set par CommandServer)
    inp_fwd:    bool = False
    inp_back:   bool = False
    inp_left:   bool = False
    inp_right:  bool = False
    inp_run:    bool = False
    inp_jump:   bool = False   # impulsion unique
    inp_swim_up:   bool = False
    inp_swim_down: bool = False

# ---------------------------------------------------------------------------
# Builder DataTransform (client → ZoneServer)
# ---------------------------------------------------------------------------

def build_data_transform(obj_id: int, ps: PlayerState, seq: int) -> bytes:
    """
    Construit un ObjectControllerMessage DataTransform.
    Format (client → ZoneServer, little-endian) :
      uint16 0x001B  (ObjCtrl game opcode)
      uint64 obj_id
      uint32 0x00F1  (DataTransform sub-opcode)
      uint32 seq_num
      float  x
      float  y
      float  z
      float  sin(heading)   (direction de vue)
      float  speed
    """
    flags = _locomotion_flag(ps.state)
    return (
        struct.pack('<H', SWG_OBJ_CTRL) +
        struct.pack('<Q', obj_id) +
        struct.pack('<I', CTRL_DATA_TRANSFORM) +
        struct.pack('<I', seq) +
        struct.pack('<I', flags) +
        struct.pack('<f', ps.x) +
        struct.pack('<f', ps.y) +
        struct.pack('<f', ps.z) +
        struct.pack('<f', math.sin(ps.heading)) +
        struct.pack('<f', ps.speed)
    )


def _locomotion_flag(state: LocomotionState) -> int:
    return {
        LocomotionState.STANDING: FLAG_STOP,
        LocomotionState.WALKING:  FLAG_WALK,
        LocomotionState.RUNNING:  FLAG_RUN,
        LocomotionState.JUMPING:  FLAG_JUMP,
        LocomotionState.FALLING:  FLAG_JUMP,
        LocomotionState.SWIMMING: FLAG_SWIM,
    }.get(state, FLAG_STOP)

# ---------------------------------------------------------------------------
# Physique (20 Hz)
# ---------------------------------------------------------------------------

class PlayerController:
    """
    Simule la physique client-side et émet les DataTransform vers le ZoneServer.
    """

    def __init__(self, zone: SOEClient, obj_id: int,
                 bridge: Optional[GodotBridge] = None):
        self.zone    = zone
        self.obj_id  = obj_id
        self.bridge  = bridge
        self.ps      = PlayerState()
        self._seq:   int   = 0
        self._last_pkt: float = 0.0
        self._lock   = threading.Lock()
        self._dirty  = False   # position a changé depuis le dernier paquet

    def set_position(self, x: float, y: float, z: float) -> None:
        """Met à jour la position de départ (reçue du serveur à la connexion zone)"""
        with self._lock:
            self.ps.x, self.ps.y, self.ps.z = x, y, z

    def apply_input(self, cmd: dict) -> None:
        """Applique une commande reçue du CommandServer (Godot ou terminal)"""
        t      = cmd.get("t", "")
        active = bool(cmd.get("active", True))
        with self._lock:
            if t == "fwd":    self.ps.inp_fwd    = active
            elif t == "back": self.ps.inp_back   = active
            elif t == "left": self.ps.inp_left   = active
            elif t == "right":self.ps.inp_right  = active
            elif t == "run":  self.ps.inp_run    = active
            elif t == "jump":
                if active and self.ps.state in (
                        LocomotionState.STANDING, LocomotionState.WALKING,
                        LocomotionState.RUNNING,  LocomotionState.SWIMMING):
                    self.ps.inp_jump = True   # impulsion unique
            elif t == "swim_up":   self.ps.inp_swim_up   = active
            elif t == "swim_down": self.ps.inp_swim_down = active
            elif t == "stop":
                self.ps.inp_fwd = self.ps.inp_back = False
                self.ps.inp_left = self.ps.inp_right = False

    def tick(self, dt: float) -> None:
        """Mise à jour physique — appelée à TICK_RATE Hz"""
        with self._lock:
            ps = self.ps
            prev_x, prev_y, prev_z = ps.x, ps.y, ps.z

            # --- Vitesse horizontale ---
            horiz_speed = (SPEED_RUN if ps.inp_run else SPEED_WALK)
            dx, dz = 0.0, 0.0

            if ps.inp_fwd:
                dx += math.sin(ps.heading) * horiz_speed
                dz += math.cos(ps.heading) * horiz_speed
            if ps.inp_back:
                dx -= math.sin(ps.heading) * horiz_speed
                dz -= math.cos(ps.heading) * horiz_speed
            if ps.inp_left:
                ps.heading -= 1.8 * dt   # rotation ~103°/s
            if ps.inp_right:
                ps.heading += 1.8 * dt

            # --- Saut (M4.2) ---
            if ps.inp_jump:
                ps.vel_y    = JUMP_IMPULSE
                ps.inp_jump = False
                ps.state    = LocomotionState.JUMPING

            # --- Eau / nage (M4.3) ---
            if ps.y <= WATER_LEVEL:
                # En eau
                if ps.inp_swim_up:   ps.vel_y =  SPEED_SWIM
                elif ps.inp_swim_down: ps.vel_y = -SPEED_SWIM
                else:                ps.vel_y = max(0.0, ps.vel_y - GRAVITY * dt * 0.5)
                ps.y = max(WATER_LEVEL - 1.5, ps.y + ps.vel_y * dt)
                ps.y = min(WATER_LEVEL, ps.y)
                ps.state = LocomotionState.SWIMMING
            else:
                # Gravité hors eau
                ps.vel_y -= GRAVITY * dt
                ps.y     += ps.vel_y * dt

                # Atterrissage (simplif : ground = y à la connexion)
                if ps.y < 0.0 and ps.vel_y < 0.0:
                    ps.y     = 0.0
                    ps.vel_y = 0.0

            # --- Mise à jour position horizontale ---
            ps.x += dx * dt
            ps.z += dz * dt

            # --- État de locomotion ---
            if ps.state != LocomotionState.SWIMMING:
                if ps.y > 0.05:
                    ps.state = (LocomotionState.JUMPING if ps.vel_y >= 0
                                else LocomotionState.FALLING)
                elif dx != 0 or dz != 0:
                    ps.state = (LocomotionState.RUNNING if ps.inp_run
                                else LocomotionState.WALKING)
                else:
                    ps.state = LocomotionState.STANDING

            ps.speed = math.sqrt(dx * dx + dz * dz)

            # Détecter si la position a changé
            if (abs(ps.x - prev_x) > 0.01 or abs(ps.y - prev_y) > 0.01
                    or abs(ps.z - prev_z) > 0.01 or ps.speed > 0):
                self._dirty = True

        # --- Émission DataTransform ---
        now = time.time()
        if self._dirty and (now - self._last_pkt) >= PKT_INTERVAL:
            self._emit()
            self._last_pkt = now
            self._dirty    = False

    def _emit(self) -> None:
        """Envoie le DataTransform au ZoneServer et notifie Godot"""
        with self._lock:
            pkt = build_data_transform(self.obj_id, self.ps, self._seq)
            self._seq = (self._seq + 1) & 0xFFFF
            x, y, z  = self.ps.x, self.ps.y, self.ps.z
            state_str = self.ps.state.value

        try:
            self.zone.send(pkt)
        except Exception as e:
            print(f"[Controller] Erreur émission DataTransform: {e}")

        if self.bridge:
            self.bridge.move(self.obj_id, x, y, z)

        print(f"  [DT] {state_str:10s}  pos=({x:.2f}, {y:.2f}, {z:.2f})")

    def run_loop(self, stop_event: threading.Event) -> None:
        """Boucle physique — à exécuter dans un thread dédié"""
        print(f"[Controller] Boucle physique démarrée ({int(1/TICK_RATE)} Hz)")
        while not stop_event.is_set():
            t0 = time.time()
            self.tick(TICK_RATE)
            elapsed = time.time() - t0
            sleep   = max(0.0, TICK_RATE - elapsed)
            time.sleep(sleep)
        print("[Controller] Boucle physique arrêtée")

# ---------------------------------------------------------------------------
# CommandServer — écoute commandes UDP depuis Godot (port 12346)
# ---------------------------------------------------------------------------

class CommandServer:
    """
    Écoute sur localhost:listen_port les commandes JSON de Godot
    ou d'un terminal pour piloter le PlayerController.

    Protocol (Godot player_controller.gd -> ici) :
      {"t":"fwd",  "active":true}   appui touche Z/W
      {"t":"back", "active":false}  relâchement S
      {"t":"left", "active":true}   Q/A
      {"t":"right","active":true}   D
      {"t":"run",  "active":true}   Shift
      {"t":"jump"}                  Espace
      {"t":"stop"}                  tout arrêter
      {"t":"pos",  "x":f,"y":f,"z":f}  position initiale depuis serveur
    """

    def __init__(self, controller: PlayerController, port: int = 12346):
        self.controller = controller
        self.port       = port
        self._sock      = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self._sock.bind(('127.0.0.1', port))
        self._sock.settimeout(0.1)
        print(f"[CommandServer] En écoute sur 127.0.0.1:{port}")

    def run(self, stop_event: threading.Event) -> None:
        while not stop_event.is_set():
            try:
                data, _ = self._sock.recvfrom(1024)
                cmd = json.loads(data.decode('utf-8'))
                if cmd.get("t") == "pos":
                    self.controller.set_position(
                        float(cmd.get("x", 0)),
                        float(cmd.get("y", 0)),
                        float(cmd.get("z", 0)),
                    )
                else:
                    self.controller.apply_input(cmd)
            except socket.timeout:
                continue
            except Exception as e:
                print(f"[CommandServer] Erreur: {e}")
        self._sock.close()

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Prime Controller M4 — ZQSD/Saut/Nage -> DataTransform ZoneServer",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument("--host",         default="192.168.0.246")
    parser.add_argument("--zone-port",    type=int, default=44463)
    parser.add_argument("--obj-id",       type=lambda x: int(x, 0), required=True,
                        help="Object ID du personnage (hex ou décimal)")
    parser.add_argument("--crc-seed",     type=lambda x: int(x, 0), required=True,
                        help="CRC seed de la session SOE")
    parser.add_argument("--listen-port",  type=int, default=12346,
                        help="Port UDP pour commandes depuis Godot")
    parser.add_argument("--godot-port",   type=int, default=12345,
                        help="Port UDP Godot pour self-position (0=off)")
    parser.add_argument("--start-x",      type=float, default=0.0)
    parser.add_argument("--start-y",      type=float, default=0.0)
    parser.add_argument("--start-z",      type=float, default=0.0)
    args = parser.parse_args()

    # Connexion zone (reconnexion légère — seed déjà connu)
    zone = SOEClient(args.host, args.zone_port)
    zone.crc_seed = args.crc_seed
    print(f"[Controller] ZoneServer {args.host}:{args.zone_port}  "
          f"obj=0x{args.obj_id:016x}  seed=0x{args.crc_seed:08x}")

    bridge = GodotBridge(args.godot_port)
    ctrl   = PlayerController(zone, args.obj_id, bridge)
    ctrl.set_position(args.start_x, args.start_y, args.start_z)

    stop = threading.Event()
    cmd_server = CommandServer(ctrl, args.listen_port)

    t_phys = threading.Thread(target=ctrl.run_loop,   args=(stop,), daemon=True)
    t_cmd  = threading.Thread(target=cmd_server.run,  args=(stop,), daemon=True)
    t_phys.start()
    t_cmd.start()

    print("[Controller] Prêt. Ctrl+C pour quitter.")
    try:
        while True:
            time.sleep(0.5)
    except KeyboardInterrupt:
        print("\n[Controller] Arrêt.")
        stop.set()
        bridge.close()

if __name__ == "__main__":
    main()
