#!/usr/bin/env python3
"""
ws_parser.py — Parseur World Snapshot (.ws) SWGEmu -> JSON
===========================================================
M3.2 : Extrait les positions des bâtiments/objets statiques d'un fichier
        .ws (format IFF SWG) et les exporte en JSON pour le WorldMap Godot.

Usage :
  python ws_parser.py <planet>.ws                  # stdout JSON
  python ws_parser.py <planet>.ws -o out.json      # fichier + envoi UDP Godot
  python ws_parser.py <planet>.ws --godot-port 12345

Format IFF SWG (World Snapshot) :
  FORM SWSN
    FORM 0006
      IHDR (header : version, bounds)
      IROW... (chaque row = un objet)
        FORM NODS
          DATA NODX  (object template path, transform 4x4, cell_id)

Chaque NODX contient :
  - object_template : Pascal string (uint32 len + bytes)
  - transform       : 12 floats (matrix 4x3 row-major) = rotation (3x3) + translation (3x1)
  - cell_id         : int32 (0 = monde ouvert)
  - parent_id       : int64 (0 si pas de parent)
  - appearance      : Pascal string
"""
import struct
import sys
import json
import socket
import argparse
from pathlib import Path
from typing import List, Dict, Optional, Tuple

# ---------------------------------------------------------------------------
# Lecture IFF générique
# ---------------------------------------------------------------------------

class IFFChunk:
    """Représente un chunk IFF SWG (tag 4 bytes + data)"""
    def __init__(self, tag: str, data: bytes):
        self.tag  = tag
        self.data = data

    def __repr__(self):
        return f"IFFChunk({self.tag!r}, {len(self.data)}b)"


def read_chunks(data: bytes, offset: int = 0) -> List[IFFChunk]:
    """Parse récursivement les chunks IFF depuis data[offset:]"""
    chunks = []
    end    = len(data)

    while offset + 8 <= end:
        tag  = data[offset:offset + 4].decode('ascii', errors='replace')
        size = struct.unpack('>I', data[offset + 4:offset + 8])[0]
        body = data[offset + 8:offset + 8 + size]
        offset += 8 + size

        if tag == 'FORM':
            # FORM : 4 bytes sous-tag + sous-chunks récursifs
            sub_tag  = body[0:4].decode('ascii', errors='replace') if len(body) >= 4 else '????'
            sub_data = body[4:]
            chunk    = IFFChunk(f"FORM:{sub_tag}", sub_data)
            chunk.children = read_chunks(sub_data)
        else:
            chunk          = IFFChunk(tag, body)
            chunk.children = []

        chunks.append(chunk)

    return chunks


def find_chunks(chunks: List[IFFChunk], tag: str, recursive: bool = True) -> List[IFFChunk]:
    """Trouve tous les chunks correspondant au tag (recurse dans les FORM)"""
    result = []
    for c in chunks:
        if c.tag == tag or c.tag.endswith(':' + tag):
            result.append(c)
        if recursive and hasattr(c, 'children'):
            result.extend(find_chunks(c.children, tag, recursive=True))
    return result

# ---------------------------------------------------------------------------
# Parser NODX (nœud d'objet World Snapshot)
# ---------------------------------------------------------------------------

def parse_nodx(data: bytes) -> Optional[Dict]:
    """
    Parse un chunk NODX (World Snapshot node).
    Structure (SWGEmu BaselinePacket / WorldSnapshotIff.cpp) :
      uint32  : object_id (bas 32 bits)
      uint32  : parent_id
      string  : object_template  (uint32 len + ASCII bytes)
      float[12] : transform matrix (row-major 4×3 : rot 3×3 + trans 3)
        rows[0..2] = rotation vectors X,Y,Z
        rows[3]    = translation X,Y,Z  <- position dans le monde
      int32   : cell_id (0 = outdoor)
      float   : radius
      uint32  : portalProperty count (skip)
    """
    if len(data) < 8:
        return None

    try:
        off = 0
        obj_id    = struct.unpack('>I', data[off:off + 4])[0]; off += 4
        parent_id = struct.unpack('>I', data[off:off + 4])[0]; off += 4

        # object_template : uint32 length + ASCII
        tmpl_len  = struct.unpack('>I', data[off:off + 4])[0]; off += 4
        tmpl      = data[off:off + tmpl_len].decode('ascii', errors='replace'); off += tmpl_len

        # Transform 4×3 (12 floats big-endian)
        floats = struct.unpack('>' + 'f' * 12, data[off:off + 48]); off += 48
        # Ligne 3 (index 9,10,11) = translation X,Y,Z
        tx, ty, tz = floats[9], floats[10], floats[11]

        cell_id = struct.unpack('>i', data[off:off + 4])[0]; off += 4

        return {
            "id":    obj_id,
            "tmpl":  tmpl,
            "x":     round(tx, 3),
            "y":     round(ty, 3),
            "z":     round(tz, 3),
            "cell":  cell_id,
        }
    except Exception:
        return None

# ---------------------------------------------------------------------------
# Parser principal .ws
# ---------------------------------------------------------------------------

def parse_ws(path: str) -> List[Dict]:
    """
    Parse un fichier .ws SWGEmu et retourne la liste des objets.
    Filtre : cell_id == 0 (objets extérieurs seulement, pas intérieurs de bâtiments).
    """
    data = Path(path).read_bytes()

    # Trouver tous les chunks NODX
    top    = read_chunks(data)
    nodx_chunks = find_chunks(top, 'NODX')

    objects = []
    for chunk in nodx_chunks:
        obj = parse_nodx(chunk.data)
        if obj and obj.get('cell', 0) == 0:
            objects.append(obj)

    # Dédupliquer par obj_id (au cas où)
    seen = set()
    unique = []
    for o in objects:
        if o['id'] not in seen:
            seen.add(o['id'])
            unique.append(o)

    return unique

# ---------------------------------------------------------------------------
# Envoi UDP vers Godot
# ---------------------------------------------------------------------------

def send_to_godot(json_path: str, port: int = 12345) -> None:
    """Envoie le chemin du JSON au NetworkBridge Godot"""
    pkt = json.dumps({"t": "ws", "path": json_path}).encode('utf-8')
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.sendto(pkt, ('127.0.0.1', port))
    sock.close()
    print(f"[ws_parser] Notif envoyée à Godot (port {port}) : {json_path}")

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Parseur World Snapshot .ws -> JSON (SWGEmu)",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument("ws_file",          help="Fichier .ws à parser")
    parser.add_argument("-o", "--output",   default="",
                        help="Fichier JSON de sortie (stdout si vide)")
    parser.add_argument("--godot-port",     type=int, default=0,
                        help="Port UDP Godot (0 = pas d'envoi)")
    parser.add_argument("--max",            type=int, default=0,
                        help="Nombre max d'objets (0 = tous)")
    parser.add_argument("--outdoor-only",   action="store_true", default=True,
                        help="Filtrer les cellules intérieures (cell_id != 0)")
    args = parser.parse_args()

    print(f"[ws_parser] Parsing {args.ws_file} ...")
    objects = parse_ws(args.ws_file)

    if args.max > 0:
        objects = objects[:args.max]

    print(f"[ws_parser] {len(objects)} objets trouvés (outdoor)")

    out_json = json.dumps(objects, indent=2, ensure_ascii=False)

    if args.output:
        Path(args.output).write_text(out_json, encoding='utf-8')
        print(f"[ws_parser] -> {args.output}")
        if args.godot_port:
            send_to_godot(str(Path(args.output).resolve()), args.godot_port)
    else:
        print(out_json)

if __name__ == "__main__":
    main()
