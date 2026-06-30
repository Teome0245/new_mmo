#!/usr/bin/env python3
"""
soe_handshake.py — Client headless SOE/Core3 pour SWGEmu
=========================================================
M1.1 : Handshake UDP SOE (ConnectRequest / ConnectResponse)
M1.2 : Authentification LoginServer → session token → ZoneServer (ClientIdMsg)
M1.3 : Mode console — affichage paquets Delta / ObjectController en temps réel

Usage :
  python soe_handshake.py --host 192.168.0.246 --port 44553 \
                          --user Bot_IA --password lbgiabot \
                          --char 0            # index du perso (0 = premier)
  python soe_handshake.py --no-zone           # arrêter après login (debug)
  python soe_handshake.py --zone-host 192.168.0.246 --zone-port 44463  # forcer ZS
"""
import json
import os
import socket
import struct
import sys
import argparse
import threading
import time
import zlib
from dataclasses import dataclass, field
from typing import Optional, List, Tuple, Dict

# ---------------------------------------------------------------------------
# CRC-32 SOE paquets (BaseProtocol::crcTable — distinct de STRING_HASH_TABLE)
# ---------------------------------------------------------------------------
CRCTABLE = [
    0x00000000, 0x77073096, 0xEE0E612C, 0x990951BA, 0x076DC419, 0x706AF48F, 0xE963A535, 0x9E6495A3,
    0x0EDB8832, 0x79DCB8A4, 0xE0D5E91E, 0x97D2D988, 0x09B64C2B, 0x7EB17CBD, 0xE7B82D07, 0x90BF1D91,
    0x1DB71064, 0x6AB020F2, 0xF3B97148, 0x84BE41DE, 0x1ADAD47D, 0x6DDDE4EB, 0xF4D4B551, 0x83D385C7,
    0x136C9856, 0x646BA8C0, 0xFD62F97A, 0x8A65C9EC, 0x14015C4F, 0x63066CD9, 0xFA0F3D63, 0x8D080DF5,
    0x3B6E20C8, 0x4C69105E, 0xD56041E4, 0xA2677172, 0x3C03E4D1, 0x4B04D447, 0xD20D85FD, 0xA50AB56B,
    0x35B5A8FA, 0x42B2986C, 0xDBBBC9D6, 0xACBCF940, 0x32D86CE3, 0x45DF5C75, 0xDCD60DCF, 0xABD13D59,
    0x26D930AC, 0x51DE003A, 0xC8D75180, 0xBFD06116, 0x21B4F4B5, 0x56B3C423, 0xCFBA9599, 0xB8BDA50F,
    0x2802B89E, 0x5F058808, 0xC60CD9B2, 0xB10BE924, 0x2F6F7C87, 0x58684C11, 0xC1611DAB, 0xB6662D3D,
    0x76DC4190, 0x01DB7106, 0x98D220BC, 0xEFD5102A, 0x71B18589, 0x06B6B51F, 0x9FBFE4A5, 0xE8B8D433,
    0x7807C9A2, 0x0F00F934, 0x9609A88E, 0xE10E9818, 0x7F6A0DBB, 0x086D3D2D, 0x91646C97, 0xE6635C01,
    0x6B6B51F4, 0x1C6C6162, 0x856530D8, 0xF262004E, 0x6C0695ED, 0x1B01A57B, 0x8208F4C1, 0xF50FC457,
    0x65B0D9C6, 0x12B7E950, 0x8BBEB8EA, 0xFCB9887C, 0x62DD1DDF, 0x15DA2D49, 0x8CD37CF3, 0xFBD44C65,
    0x4DB26158, 0x3AB551CE, 0xA3BC0074, 0xD4BB30E2, 0x4ADFA541, 0x3DD895D7, 0xA4D1C46D, 0xD3D6F4FB,
    0x4369E96A, 0x346ED9FC, 0xAD678846, 0xDA60B8D0, 0x44042D73, 0x33031DE5, 0xAA0A4C5F, 0xDD0D7CC9,
    0x5005713C, 0x270241AA, 0xBE0B1010, 0xC90C2086, 0x5768B525, 0x206F85B3, 0xB966D409, 0xCE61E49F,
    0x5EDEF90E, 0x29D9C998, 0xB0D09822, 0xC7D7A8B4, 0x59B33D17, 0x2EB40D81, 0xB7BD5C3B, 0xC0BA6CAD,
    0xEDB88320, 0x9ABFB3B6, 0x03B6E20C, 0x74B1D29A, 0xEAD54739, 0x9DD277AF, 0x04DB2615, 0x73DC1683,
    0xE3630B12, 0x94643B84, 0x0D6D6A3E, 0x7A6A5AA8, 0xE40ECF0B, 0x9309FF9D, 0x0A00AE27, 0x7D079EB1,
    0xF00F9344, 0x8708A3D2, 0x1E01F268, 0x6906C2FE, 0xF762575D, 0x806567CB, 0x196C3671, 0x6E6B06E7,
    0xFED41B76, 0x89D32BE0, 0x10DA7A5A, 0x67DD4ACC, 0xF9B9DF6F, 0x8EBEEFF9, 0x17B7BE43, 0x60B08ED5,
    0xD6D6A3E8, 0xA1D1937E, 0x38D8C2C4, 0x4FDFF252, 0xD1BB67F1, 0xA6BC5767, 0x3FB506DD, 0x48B2364B,
    0xD80D2BDA, 0xAF0A1B4C, 0x36034AF6, 0x41047A60, 0xDF60EFC3, 0xA867DF55, 0x316E8EEF, 0x4669BE79,
    0xCB61B38C, 0xBC66831A, 0x256FD2A0, 0x5268E236, 0xCC0C7795, 0xBB0B4703, 0x220216B9, 0x5505262F,
    0xC5BA3BBE, 0xB2BD0B28, 0x2BB45A92, 0x5CB36A04, 0xC2D7FFA7, 0xB5D0CF31, 0x2CD99E8B, 0x5BDEAE1D,
    0x9B64C2B0, 0xEC63F226, 0x756AA39C, 0x026D930A, 0x9C0906A9, 0xEB0E363F, 0x72076785, 0x05005713,
    0x95BF4A82, 0xE2B87A14, 0x7BB12BAE, 0x0CB61B38, 0x92D28E9B, 0xE5D5BE0D, 0x7CDCEFB7, 0x0BDBDF21,
    0x86D3D2D4, 0xF1D4E242, 0x68DDB3F8, 0x1FDA836E, 0x81BE16CD, 0xF6B9265B, 0x6FB077E1, 0x18B74777,
    0x88085AE6, 0xFF0F6A70, 0x66063BCA, 0x11010B5C, 0x8F659EFF, 0xF862AE69, 0x616BFFD3, 0x166CCF45,
    0xA00AE278, 0xD70DD2EE, 0x4E048354, 0x3903B3C2, 0xA7672661, 0xD06016F7, 0x4969474D, 0x3E6E77DB,
    0xAED16A4A, 0xD9D65ADC, 0x40DF0B66, 0x37D83BF0, 0xA9BCAE53, 0xDEBB9EC5, 0x47B2CF7F, 0x30B5FFE9,
    0xBDBDF21C, 0xCABAC28A, 0x53B39330, 0x24B4A3A6, 0xBAD03605, 0xCDD70693, 0x54DE5729, 0x23D967BF,
    0xB3667A2E, 0xC4614AB8, 0x5D681B02, 0x2A6F2B94, 0xB40BBE37, 0xC30C8EA1, 0x5A05DF1B, 0x2D02EF8D,
]

STRING_HASH_TABLE = [
    0x00000000, 0x04C11DB7, 0x09823B6E, 0x0D4326D9, 0x130476DC, 0x17C56B6B, 0x1A864DB2, 0x1E475005,
    0x2608EDB8, 0x22C9F00F, 0x2F8AD6D6, 0x2B4BCB61, 0x350C9B64, 0x31CD86D3, 0x3C8EA00A, 0x384FBDBD,
    0x4C11DB70, 0x48D0C6C7, 0x4593E01E, 0x4152FDA9, 0x5F15ADAC, 0x5BD4B01B, 0x569796C2, 0x52568B75,
    0x6A1936C8, 0x6ED82B7F, 0x639B0DA6, 0x675A1011, 0x791D4014, 0x7DDC5DA3, 0x709F7B7A, 0x745E66CD,
    0x9823B6E0, 0x9CE2AB57, 0x91A18D8E, 0x95609039, 0x8B27C03C, 0x8FE6DD8B, 0x82A5FB52, 0x8664E6E5,
    0xBE2B5B58, 0xBAEA46EF, 0xB7A96036, 0xB3687D81, 0xAD2F2D84, 0xA9EE3033, 0xA4AD16EA, 0xA06C0B5D,
    0xD4326D90, 0xD0F37027, 0xDDB056FE, 0xD9714B49, 0xC7361B4C, 0xC3F706FB, 0xCEB42022, 0xCA753D95,
    0xF23A8028, 0xF6FB9D9F, 0xFBB8BB46, 0xFF79A6F1, 0xE13EF6F4, 0xE5FFEB43, 0xE8BCCD9A, 0xEC7DD02D,
    0x34867077, 0x30476DC0, 0x3D044B19, 0x39C556AE, 0x278206AB, 0x23431B1C, 0x2E003DC5, 0x2AC12072,
    0x128E9DCF, 0x164F8078, 0x1B0CA6A1, 0x1FCDBB16, 0x018AEB13, 0x054BF6A4, 0x0808D07D, 0x0CC9CDCA,
    0x7897AB07, 0x7C56B6B0, 0x71159069, 0x75D48DDE, 0x6B93DDDB, 0x6F52C06C, 0x6211E6B5, 0x66D0FB02,
    0x5E9F46BF, 0x5A5E5B08, 0x571D7DD1, 0x53DC6066, 0x4D9B3063, 0x495A2DD4, 0x44190B0D, 0x40D816BA,
    0xACA5C697, 0xA864DB20, 0xA527FDF9, 0xA1E6E04E, 0xBFA1B04B, 0xBB60ADFC, 0xB6238B25, 0xB2E29692,
    0x8AAD2B2F, 0x8E6C3698, 0x832F1041, 0x87EE0DF6, 0x99A95DF3, 0x9D684044, 0x902B669D, 0x94EA7B2A,
    0xE0B41DE7, 0xE4750050, 0xE9362689, 0xEDF73B3E, 0xF3B06B3B, 0xF771768C, 0xFA325055, 0xFEF34DE2,
    0xC6BCF05F, 0xC27DEDE8, 0xCF3ECB31, 0xCBFFD686, 0xD5B88683, 0xD1799B34, 0xDC3ABDED, 0xD8FBA05A,
    0x690CE0EE, 0x6DCDFD59, 0x608EDB80, 0x644FC637, 0x7A089632, 0x7EC98B85, 0x738AAD5C, 0x774BB0EB,
    0x4F040D56, 0x4BC510E1, 0x46863638, 0x42472B8F, 0x5C007B8A, 0x58C1663D, 0x558240E4, 0x51435D53,
    0x251D3B9E, 0x21DC2629, 0x2C9F00F0, 0x285E1D47, 0x36194D42, 0x32D850F5, 0x3F9B762C, 0x3B5A6B9B,
    0x0315D626, 0x07D4CB91, 0x0A97ED48, 0x0E56F0FF, 0x1011A0FA, 0x14D0BD4D, 0x19939B94, 0x1D528623,
    0xF12F560E, 0xF5EE4BB9, 0xF8AD6D60, 0xFC6C70D7, 0xE22B20D2, 0xE6EA3D65, 0xEBA91BBC, 0xEF68060B,
    0xD727BBB6, 0xD3E6A601, 0xDEA580D8, 0xDA649D6F, 0xC423CD6A, 0xC0E2D0DD, 0xCDA1F604, 0xC960EBB3,
    0xBD3E8D7E, 0xB9FF90C9, 0xB4BCB610, 0xB07DABA7, 0xAE3AFBA2, 0xAAFBE615, 0xA7B8C0CC, 0xA379DD7B,
    0x9B3660C6, 0x9FF77D71, 0x92B45BA8, 0x9675461F, 0x8832161A, 0x8CF30BAD, 0x81B02D74, 0x857130C3,
    0x5D8A9099, 0x594B8D2E, 0x5408ABF7, 0x50C9B640, 0x4E8EE645, 0x4A4FFBF2, 0x470CDD2B, 0x43CDC09C,
    0x7B827D21, 0x7F436096, 0x7200464F, 0x76C15BF8, 0x68860BFD, 0x6C47164A, 0x61043093, 0x65C52D24,
    0x119B4BE9, 0x155A565E, 0x18197087, 0x1CD86D30, 0x029F3D35, 0x065E2082, 0x0B1D065B, 0x0FDC1BEC,
    0x3793A651, 0x3352BBE6, 0x3E119D3F, 0x3AD08088, 0x2497D08D, 0x2056CD3A, 0x2D15EBE3, 0x29D4F654,
    0xC5A92679, 0xC1683BCE, 0xCC2B1D17, 0xC8EA00A0, 0xD6AD50A5, 0xD26C4D12, 0xDF2F6BCB, 0xDBEE767C,
    0xE3A1CBC1, 0xE760D676, 0xEA23F0AF, 0xEEE2ED18, 0xF0A5BD1D, 0xF464A0AA, 0xF9278673, 0xFDE69BC4,
    0x89B8FD09, 0x8D79E0BE, 0x803AC667, 0x84FBDBD0, 0x9ABC8BD5, 0x9E7D9662, 0x933EB0BB, 0x97FFAD0C,
    0xAFB010B1, 0xAB710D06, 0xA6322BDF, 0xA2F33668, 0xBCB4666D, 0xB8757BDA, 0xB5365D03, 0xB1F740B4,
]

# ---------------------------------------------------------------------------
# Opcodes applicatifs SWG
# ---------------------------------------------------------------------------
SWG_OPCODE_GAME = 0x0004   # opcode générique messages login + zone
SWG_DELTA       = 0x000F   # DeltaMessage — mise à jour partielle objet
SWG_BASELINE    = 0x0016   # BaselineMessage — état initial objet
SWG_OBJ_CTRL   = 0x001B   # ObjectControllerMessage

# Opcodes M5 — connexion live
SWG_CMD_START_SCENE = 0x0004   # CmdStartScene (planete + pos + obj_id joueur)
SWG_SCENE_CREATE    = 0x0019   # SceneCreateObjectByName (hashed)
SWG_SCENE_DESTROY   = 0x001A   # SceneDestroyObject

# Hash SWGEmu des messages zone critiques
HASH_CMD_START_SCENE = 0x6F46D1D5   # string_hashcode("CmdStartScene")
HASH_SCENE_CREATE    = 0xDDDB9F56   # string_hashcode("SceneCreateObjectByName")
HASH_SCENE_DESTROY   = 0x4C3D2A07   # string_hashcode("SceneDestroyObject")


# Sous-opcodes ObjectController
CTRL_DATA_TRANSFORM             = 0x00F1
CTRL_DATA_TRANSFORM_WITH_PARENT = 0x00F2
CTRL_COMMAND_QUEUE_ENQUEUE      = 0x0071
CTRL_SPATIAL_CHAT               = 0x00CC

CTRL_NAMES: Dict[int, str] = {
    CTRL_DATA_TRANSFORM:             "DataTransform",
    CTRL_DATA_TRANSFORM_WITH_PARENT: "DataTransformWithParent",
    CTRL_COMMAND_QUEUE_ENQUEUE:      "CommandQueueEnqueue",
    CTRL_SPATIAL_CHAT:               "SpatialChat",
    0x0116:                          "CombatSpam",
    0x015A:                          "ImageDesign",
}

ZONE_DEFAULT_PORT = 44563   # port ZoneServer Prime (galaxie 3)

# ---------------------------------------------------------------------------
# Utilitaires crypto / CRC
# ---------------------------------------------------------------------------

def string_hashcode(s: str) -> int:
    """Hash STRING_HASHCODE / String::hashCode (String.h)"""
    crc = 0xFFFFFFFF
    for ch in s:
        idx = ((crc >> 24) ^ ord(ch)) & 0xFF
        crc = (STRING_HASH_TABLE[idx] ^ (crc << 8)) & 0xFFFFFFFF
    return (~crc) & 0xFFFFFFFF


def generate_crc32(data: bytes, seed: int) -> int:
    """CRC-32 avec seed SOE (BaseProtocol::generateCrc)"""
    nCrc = CRCTABLE[(~seed) & 0xFF]
    nCrc ^= 0x00FFFFFF
    nIndex = (seed >> 8) ^ nCrc
    nCrc = (nCrc >> 8) & 0x00FFFFFF
    nCrc ^= CRCTABLE[nIndex & 0xFF]
    nIndex = (seed >> 16) ^ nCrc
    nCrc = (nCrc >> 8) & 0x00FFFFFF
    nCrc ^= CRCTABLE[nIndex & 0xFF]
    nIndex = (seed >> 24) ^ nCrc
    nCrc = (nCrc >> 8) & 0x00FFFFFF
    nCrc ^= CRCTABLE[nIndex & 0xFF]
    for byte in data:
        nIndex = byte ^ nCrc
        nCrc = (nCrc >> 8) & 0x00FFFFFF
        nCrc ^= CRCTABLE[nIndex & 0xFF]
    return (~nCrc) & 0xFFFFFFFF


def encrypt_payload(data: bytes, crc_seed: int) -> bytes:
    """XOR stream cipher SOE (BaseProtocol::encrypt)"""
    buf   = bytearray(data)
    start = 2 if buf[0] == 0x00 else 1
    elen  = len(buf) - start - 2
    blks  = elen // 4
    rest  = elen % 4
    key   = crc_seed
    for i in range(blks):
        off = start + i * 4
        val = struct.unpack('<I', buf[off:off + 4])[0] ^ key
        struct.pack_into('<I', buf, off, val)
        key = val
    for i in range(rest):
        off = start + blks * 4 + i
        buf[off] ^= key & 0xFF
    return bytes(buf)


def decrypt_payload(data: bytes, crc_seed: int) -> bytes:
    """XOR stream decipher SOE (BaseProtocol::decrypt)"""
    buf   = bytearray(data)
    start = 2 if buf[0] == 0x00 else 1
    elen  = len(buf) - start - 2
    blks  = elen // 4
    rest  = elen % 4
    key   = crc_seed
    for i in range(blks):
        off = start + i * 4
        enc = struct.unpack('<I', buf[off:off + 4])[0]
        struct.pack_into('<I', buf, off, enc ^ key)
        key = enc
    for i in range(rest):
        off = start + blks * 4 + i
        buf[off] ^= key & 0xFF
    return bytes(buf)


def build_ascii(s: str) -> bytes:
    """Encode une chaîne ASCII SWG (uint16 len + bytes)"""
    enc = s.encode('ascii')
    return struct.pack('<H', len(enc)) + enc

# ---------------------------------------------------------------------------
# Data classes
# ---------------------------------------------------------------------------

@dataclass
class GalaxyInfo:
    galaxy_id:  int
    name:       str
    host:       str = ""
    port:       int = 0
    status:     int = 0
    population: int = 0

    def __str__(self) -> str:
        s = {0: "DOWN", 1: "LOADING", 2: "UP", 3: "LOCKED"}.get(self.status, f"?{self.status}")
        conn = f"{self.host}:{self.port}" if self.host else "?:?"
        return f"[{self.galaxy_id}] {self.name:<20s} {conn:<22s} [{s}] pop={self.population}"


@dataclass
class CharacterInfo:
    name:       str
    struct_id:  int    # object_id (uint64) de l'entité Core3
    cluster_id: int
    char_id:    int

    def __str__(self) -> str:
        return (f"[cluster={self.cluster_id}] {self.name:<24s} "
                f"struct_id=0x{self.struct_id:016x}")


@dataclass
class LoginSession:
    session_token: str = ""
    account_id:    int = 0
    station_id:    int = 0
    username:      str = ""
    galaxies:      List[GalaxyInfo]    = field(default_factory=list)
    characters:    List[CharacterInfo] = field(default_factory=list)

# ---------------------------------------------------------------------------
# Parsers messages Login
# ---------------------------------------------------------------------------

def _galaxy_by_id(session: LoginSession, gid: int) -> GalaxyInfo:
    g = next((x for x in session.galaxies if x.galaxy_id == gid), None)
    if g is None:
        g = GalaxyInfo(galaxy_id=gid, name=f"Galaxy-{gid}")
        session.galaxies.append(g)
    return g


def parse_login_client_token(body: bytes, session: LoginSession) -> None:
    try:
        sess_len = struct.unpack('<I', body[0:4])[0]
        tok_len  = sess_len - 4
        session.session_token = body[4:4 + tok_len].decode('ascii', errors='replace')
        off = 4 + tok_len
        session.account_id = struct.unpack('<I', body[off:off + 4])[0]
        session.station_id = struct.unpack('<I', body[off + 4:off + 8])[0]
        ulen = struct.unpack('<H', body[off + 8:off + 10])[0]
        session.username = body[off + 10:off + 10 + ulen].decode('ascii', errors='replace')
        tok_p = session.session_token[:24] + ("…" if len(session.session_token) > 24 else "")
        print(f"  [LoginClientToken] account={session.account_id}  user={session.username}")
        print(f"      token={tok_p}")
    except Exception as e:
        print(f"  [LoginClientToken] parse error: {e} | raw: {body[:32].hex()}")


def parse_login_enum_cluster(body: bytes, session: LoginSession) -> None:
    try:
        count = struct.unpack('<I', body[0:4])[0]
        print(f"  [LoginEnumCluster] {count} galaxie(s)")
        off = 4
        for _ in range(count):
            gid    = struct.unpack('<I', body[off:off + 4])[0]; off += 4
            nlen   = struct.unpack('<H', body[off:off + 2])[0]; off += 2
            name   = body[off:off + nlen].decode('ascii', errors='replace'); off += nlen
            status = struct.unpack('<I', body[off:off + 4])[0]; off += 4
            g = _galaxy_by_id(session, gid)
            g.name   = name
            g.status = status
            print(f"      {g}")
    except Exception as e:
        print(f"  [LoginEnumCluster] parse error: {e} | raw: {body[:32].hex()}")


def parse_login_cluster_status(body: bytes, session: LoginSession) -> None:
    """
    Format SWGEmu (par galaxie) :
      uint32 cluster_id
      uint16 addr_len + addr_len bytes (ASCII)
      uint16 port
      uint32 status
      20 bytes champs pop (timezone + 4×int32)
    """
    try:
        count = struct.unpack('<I', body[0:4])[0]
        print(f"  [LoginClusterStatus] {count} galaxie(s)")
        off = 4
        for _ in range(count):
            gid  = struct.unpack('<I', body[off:off + 4])[0]; off += 4
            alen = struct.unpack('<H', body[off:off + 2])[0]; off += 2
            addr = body[off:off + alen].decode('ascii', errors='replace'); off += alen
            port = struct.unpack('<H', body[off:off + 2])[0]; off += 2
            status = struct.unpack('<I', body[off:off + 4])[0]; off += 4
            off += 20   # skip timezone + 4 pop fields
            g = _galaxy_by_id(session, gid)
            g.host   = addr
            g.port   = port
            g.status = status
            print(f"      {g}")
    except Exception as e:
        print(f"  [LoginClusterStatus] parse error: {e} | raw: {body[:48].hex()}")
        print(f"  → utilisez --zone-host / --zone-port pour forcer l'adresse ZS")


def parse_enumerate_character_id(body: bytes, session: LoginSession) -> None:
    try:
        count = struct.unpack('<I', body[0:4])[0]
        print(f"  [EnumerateCharacterId] {count} personnage(s)")
        off = 4
        for i in range(count):
            nlen      = struct.unpack('<I', body[off:off + 4])[0]; off += 4
            name      = body[off:off + nlen * 2].decode('utf-16-le', errors='replace'); off += nlen * 2
            struct_id = struct.unpack('<Q', body[off:off + 8])[0]; off += 8
            cluster_id= struct.unpack('<I', body[off:off + 4])[0]; off += 4
            char_id   = struct.unpack('<I', body[off:off + 4])[0]; off += 4
            ch = CharacterInfo(name=name, struct_id=struct_id,
                               cluster_id=cluster_id, char_id=char_id)
            session.characters.append(ch)
            print(f"      [{i}] {ch}")
    except Exception as e:
        print(f"  [EnumerateCharacterId] parse error: {e}")

# ---------------------------------------------------------------------------
# Builders de messages sortants
# ---------------------------------------------------------------------------

def build_account_version_message(user: str, password: str) -> bytes:
    return (struct.pack('<H', 0x0004) +
            struct.pack('<I', 0x41131F96) +
            build_ascii(user) +
            build_ascii(password) +
            build_ascii("20050408-18:00") +
            struct.pack('<I', string_hashcode("SWGEmu")))


def build_select_character(cluster_id: int, char_struct_id: int) -> bytes:
    return (struct.pack('<H', 0x0004) +
            struct.pack('<I', string_hashcode("SelectCharacter")) +
            struct.pack('<I', cluster_id) +
            struct.pack('<Q', char_struct_id))


def build_client_id_msg(session_token: str, client_version: str = "20050408-18:00") -> bytes:
    return (struct.pack('<H', 0x0004) +
            struct.pack('<I', string_hashcode("ClientIdMsg")) +
            build_ascii(session_token) +
            build_ascii(client_version))

# ---------------------------------------------------------------------------
# SOEClient — couche transport SOE (UDP)
# ---------------------------------------------------------------------------

class SOEClient:
    """
    Connexion SOE bas niveau vers un serveur SWGEmu (LoginServer ou ZoneServer).
    Gère : ConnectRequest/Response, Data Channel, Fragments, ACK, KeepAlive.
    """
    _OP_CONNECT_REQ  = b'\x00\x01'
    _OP_CONNECT_RESP = b'\x00\x02'
    _OP_DISCONNECT   = b'\x00\x05'
    _OP_KEEPALIVE    = b'\x00\x11'
    _OP_KEEPALIVE_R  = b'\x00\x12'
    _OP_NETSTATUS_REQ  = b'\x00\x07'
    _OP_NETSTATUS_RESP = b'\x00\x08'
    _OP_DATA_CHANNEL = b'\x00\x09'
    _OP_FRAG_DATA    = b'\x00\x0d'
    _OP_ACK          = b'\x00\x15'

    def __init__(self, host: str, port: int, timeout: float = 5.0):
        self.host         = host
        self.port         = port
        self.timeout      = timeout
        self.sock         = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.settimeout(timeout)
        self.connection_id: int   = 0
        self.crc_seed:      int   = 0
        self.client_seq:    int   = 0
        self._net_tick:     int   = 0
        self._frag_buf:     bytes = b''
        self._frag_total:   int   = 0
        self._netstatus_stop: Optional[threading.Event] = None
        self._netstatus_thread: Optional[threading.Thread] = None

    def connect(self) -> bool:
        """Handshake SOE ConnectRequest -> ConnectResponse (M1.1)"""
        conn_id = struct.unpack('<I', os.urandom(4))[0] or 0x12345679
        pkt = (self._OP_CONNECT_REQ + b'\x00\x00' + b'\x01\x00' +
               struct.pack('<I', conn_id))
        print(f"  [SOE] ConnectRequest -> {self.host}:{self.port} (cid=0x{conn_id:08x}) ...")
        self.sock.sendto(pkt, (self.host, self.port))
        try:
            data, _ = self.sock.recvfrom(1024)
        except socket.timeout:
            print("  [SOE] Timeout - serveur injoignable")
            return False
        if len(data) < 10 or data[0:2] != self._OP_CONNECT_RESP:
            print(f"  [SOE] Reponse invalide: {data.hex()}")
            return False
        self.connection_id = struct.unpack('<I', data[2:6])[0]
        self.crc_seed      = struct.unpack('>I', data[6:10])[0]
        print(f"  [SOE] OK ConnID=0x{self.connection_id:08x}  CRCSeed=0x{self.crc_seed:08x}")
        return True

    def _send_netstatus_request(self) -> None:
        """Client NetStatus request (0x0700) — requis toutes les ~5 s (BaseClient.h)."""
        tick = int(time.time() * 1000) & 0xFFFF
        self.sock.sendto(self._OP_NETSTATUS_REQ + struct.pack('>H', tick),
                         (self.host, self.port))

    def start_netstatus_loop(self, interval: float = 4.5, delay: float = 3.0) -> None:
        """Envoie 0x0700 en fond pour éviter netStatusTimeout côté serveur."""
        self.stop_netstatus_loop()
        self._netstatus_stop = threading.Event()
        stop = self._netstatus_stop

        def _loop() -> None:
            if stop.wait(delay):
                return
            self._send_netstatus_request()
            while not stop.wait(interval):
                try:
                    self._send_netstatus_request()
                except OSError:
                    break

        self._netstatus_thread = threading.Thread(target=_loop, daemon=True, name="soe-netstatus")
        self._netstatus_thread.start()

    def stop_netstatus_loop(self) -> None:
        if self._netstatus_stop is not None:
            self._netstatus_stop.set()
        if self._netstatus_thread is not None:
            self._netstatus_thread.join(timeout=1.0)
        self._netstatus_stop = None
        self._netstatus_thread = None

    def _send_netstatus_response(self, tick: int) -> None:
        """Reponse NetStatus (0x0800) a une requete serveur."""
        body = struct.pack('>H', tick & 0xFFFF) + (b'\x00' * 36)
        self.sock.sendto(self._OP_NETSTATUS_RESP + body, (self.host, self.port))

    def send(self, payload: bytes) -> None:
        """Encapsule payload dans un Data Channel SOE, chiffre et envoie"""
        seq = struct.pack('>H', self.client_seq)
        self.client_seq = (self.client_seq + 1) & 0xFFFF
        raw  = self._OP_DATA_CHANNEL + seq + payload + b'\x00' + b'\x00\x00'
        enc  = encrypt_payload(raw, self.crc_seed)
        crc  = generate_crc32(enc[:-2], self.crc_seed) & 0xFFFF
        self.sock.sendto(enc[:-2] + struct.pack('>H', crc), (self.host, self.port))

    def _ack(self, server_seq: int) -> None:
        self.sock.sendto(self._OP_ACK + struct.pack('>H', server_seq),
                         (self.host, self.port))

    def _pong(self) -> None:
        self.sock.sendto(self._OP_KEEPALIVE_R, (self.host, self.port))

    def _unpack_channel_body(self, dec: bytes) -> bytes:
        """Extrait le corps applicatif (décompression zlib si flag 0x01)."""
        if len(dec) < 7:
            return b''
        body = dec[4:-3]
        if dec[-3] == 0x01:
            body = zlib.decompress(body)
        return body

    def recv(self) -> Optional[Tuple[bytes, bytes]]:
        """
        Recoit un paquet SOE.
        Retourne (soe_opcode, app_data) pour les paquets data.
        Retourne None pour les paquets de controle ou en cas de timeout.
        """
        try:
            data, _ = self.sock.recvfrom(8192)
        except socket.timeout:
            return None

        soe_op = data[0:2]

        if soe_op == self._OP_ACK:
            return None
        if soe_op == self._OP_KEEPALIVE:
            self._pong()
            return None
        if soe_op == self._OP_NETSTATUS_REQ and len(data) >= 4:
            tick = struct.unpack('>H', data[2:4])[0]
            self._send_netstatus_response(tick)
            return None
        if soe_op == self._OP_NETSTATUS_RESP:
            return None
        if soe_op == self._OP_DISCONNECT:
            print("  [SOE] Deconnexion recue du serveur")
            return None

        # Verification CRC
        exp_crc  = struct.unpack('>H', data[-2:])[0]
        calc_crc = generate_crc32(data[:-2], self.crc_seed) & 0xFFFF
        if exp_crc != calc_crc:
            if getattr(self, '_debug', False):
                print(f"  [SOE] CRC fail exp={exp_crc:04x} calc={calc_crc:04x} len={len(data)}")
            return None

        dec    = decrypt_payload(data, self.crc_seed)
        soe_op = dec[0:2]

        if soe_op in (self._OP_DATA_CHANNEL, b'\x09\x00'):
            srv_seq  = struct.unpack('>H', dec[2:4])[0]
            self._ack(srv_seq)
            payload = self._unpack_channel_body(dec)
            if len(payload) >= 2 and payload[0:2] == b'\x19\x00':
                out = b''
                off = 2
                while off < len(payload):
                    blk = payload[off]
                    off += 1
                    if blk == 0xFF and off + 1 < len(payload):
                        blk = struct.unpack('>H', payload[off:off + 2])[0]
                        off += 2
                    out += payload[off:off + blk]
                    off += blk
                return (soe_op, out)
            return (soe_op, payload)

        if soe_op in (self._OP_FRAG_DATA, b'\x0d\x00'):
            srv_seq = struct.unpack('>H', dec[2:4])[0]
            self._ack(srv_seq)
            chunk   = dec[4:-3]
            if not self._frag_buf:
                if len(chunk) < 4:
                    return None
                self._frag_total = struct.unpack('>I', chunk[0:4])[0]
                self._frag_buf   = chunk[4:]
            else:
                self._frag_buf += chunk
            if len(self._frag_buf) >= self._frag_total:
                assembled = self._frag_buf[:self._frag_total]
                self._frag_buf   = b''
                self._frag_total = 0
                if assembled and assembled[0:2] == b'\x19\x00':
                    return (soe_op, assembled)
                return (soe_op, assembled)
            return None

        return None

    def close(self) -> None:
        self.stop_netstatus_loop()
        try:
            self.sock.sendto(
                self._OP_DISCONNECT + struct.pack('>H', self.connection_id),
                (self.host, self.port))
        except Exception:
            pass
        self.sock.close()

    def set_timeout(self, t: float) -> None:
        self.timeout = t
        self.sock.settimeout(t)

# ---------------------------------------------------------------------------
# Cache hashcodes (calcules une seule fois)
# ---------------------------------------------------------------------------
_HASHES: Dict[str, int] = {}

def _h(name: str) -> int:
    if name not in _HASHES:
        _HASHES[name] = string_hashcode(name)
    return _HASHES[name]

# ---------------------------------------------------------------------------
# Phase Login  (M1.1 + M1.2a)
# ---------------------------------------------------------------------------

def _login_message_body_len(sub_op: int, body: bytes) -> int:
    """Taille du corps d'un message login (pour découper un buffer concaténé)."""
    try:
        if sub_op == _h("LoginClientToken") and len(body) >= 4:
            n = struct.unpack('<I', body[0:4])[0]
            token_len = max(0, n - 4)
            base = 4 + token_len + 8
            if len(body) < base + 2:
                return len(body)
            ulen = struct.unpack('<H', body[base:base + 2])[0]
            return min(len(body), base + 2 + ulen)
        if sub_op == _h("LoginEnumCluster") and len(body) >= 4:
            count = struct.unpack('<I', body[0:4])[0]
            off = 4
            for _ in range(count):
                if off + 6 > len(body):
                    break
                off += 4 + 2 + struct.unpack('<H', body[off + 4:off + 6])[0] + 4
            return min(len(body), off)
        if sub_op == _h("LoginClusterStatus") and len(body) >= 4:
            count = struct.unpack('<I', body[0:4])[0]
            off = 4
            for _ in range(count):
                if off + 8 > len(body):
                    break
                alen = struct.unpack('<H', body[off + 4:off + 6])[0]
                off += 4 + 2 + alen + 2 + 4 + 20
            return min(len(body), off)
        if sub_op == _h("EnumerateCharacterId") and len(body) >= 4:
            count = struct.unpack('<I', body[0:4])[0]
            off = 4
            for _ in range(count):
                if off + 4 > len(body):
                    break
                nlen = struct.unpack('<I', body[off:off + 4])[0]
                off += 4 + nlen * 2 + 8 + 4 + 4
            return min(len(body), off)
    except Exception:
        pass
    return len(body)


def _iter_login_messages(blob: bytes):
    off = 0
    while off + 6 <= len(blob):
        if struct.unpack('<H', blob[off:off + 2])[0] != SWG_OPCODE_GAME:
            off += 1
            continue
        sub_op = struct.unpack('<I', blob[off + 2:off + 6])[0]
        body = blob[off + 6:]
        blen = _login_message_body_len(sub_op, body)
        yield sub_op, body[:blen]
        off += 6 + blen


def _split_game_packets(blob: bytes) -> List[bytes]:
    """Découpe un buffer SOE pouvant contenir plusieurs messages 0x0004."""
    out: List[bytes] = []
    off = 0
    while off + 6 <= len(blob):
        if struct.unpack('<H', blob[off:off + 2])[0] != SWG_OPCODE_GAME:
            off += 1
            continue
        nxt = len(blob)
        for i in range(off + 6, len(blob) - 1):
            if struct.unpack('<H', blob[i:i + 2])[0] == SWG_OPCODE_GAME:
                nxt = i
                break
        out.append(blob[off:nxt])
        off = nxt
    return out


def login_phase(args) -> Optional[LoginSession]:
    """
    M1.1 : Handshake SOE avec le LoginServer.
    M1.2a: Envoie AccountVersionMessage, recoit token + liste persos,
           puis envoie SelectCharacter.
    """
    print("=" * 60)
    print(" M1.1 + M1.2a  --  LoginServer")
    print("=" * 60)

    client = SOEClient(args.host, args.port)
    client._debug = getattr(args, 'debug', False)
    if not client.connect():
        return None

    session = LoginSession()

    avm = build_account_version_message(args.user, args.password)
    client.send(avm)
    client.start_netstatus_loop()
    print(f"  -> AccountVersionMessage envoye ({args.user})")
    print("  Reception des messages Login ...")

    got_token = False
    got_chars = False

    deadline = time.time() + 90.0
    while time.time() < deadline:
        result = client.recv()
        if result is None:
            if got_token and got_chars:
                break
            continue

        _, app_data = result
        if getattr(client, '_debug', False):
            print(f"  [debug] recv {len(app_data)} bytes")
        for sub_op, body in _iter_login_messages(app_data):
            if getattr(client, '_debug', False):
                print(f"  [debug] sub_op=0x{sub_op:08x} body_len={len(body)}")

            if sub_op == _h("LoginClientToken"):
                parse_login_client_token(body, session)
                got_token = True
            elif sub_op == _h("LoginEnumCluster"):
                parse_login_enum_cluster(body, session)
            elif sub_op == _h("LoginClusterStatus"):
                parse_login_cluster_status(body, session)
            elif sub_op == _h("EnumerateCharacterId"):
                parse_enumerate_character_id(body, session)
                got_chars = True

    if not got_token:
        print("  [Login] ECHEC : aucun token recu")
        client.close()
        return None

    if not session.characters:
        print("  [Login] Aucun personnage disponible")
        client.close()
        return session

    idx  = min(args.char_index, len(session.characters) - 1)
    char = session.characters[idx]
    print(f"\n  Selection personnage [{idx}] : {char.name}")
    client.send(build_select_character(char.cluster_id, char.struct_id))
    time.sleep(0.3)

    client.close()
    print("  [Login] OK connexion LoginServer terminee\n")
    return session

# ---------------------------------------------------------------------------
# Phase ZoneServer  (M1.2b)
# ---------------------------------------------------------------------------

def zone_connect_phase(session: LoginSession, zone_host: str, zone_port: int) -> Optional[SOEClient]:
    """
    M1.2b : Nouveau handshake SOE avec le ZoneServer + ClientIdMsg.
    Attend SceneCreateObjectByName pour confirmer l'entree en zone.
    """
    print("=" * 60)
    print(f" M1.2b  --  ZoneServer  {zone_host}:{zone_port}")
    print("=" * 60)

    zone = SOEClient(zone_host, zone_port, timeout=8.0)
    if not zone.connect():
        return None

    zone.send(build_client_id_msg(session.session_token))
    zone.start_netstatus_loop()
    print("  -> ClientIdMsg envoye")
    print("  Attente SceneCreateObjectByName ...")

    H_SCENE = _h("SceneCreateObjectByName")

    for _ in range(50):
        result = zone.recv()
        if result is None:
            continue
        _, app_data = result
        if len(app_data) < 6:
            continue

        app_op = struct.unpack('<H', app_data[0:2])[0]
        if app_op != SWG_OPCODE_GAME:
            continue
        sub_op = struct.unpack('<I', app_data[2:6])[0]
        if sub_op != H_SCENE:
            continue

        try:
            off     = 6
            tlen    = struct.unpack('<H', app_data[off:off + 2])[0]; off += 2
            terrain = app_data[off:off + tlen].decode('ascii', errors='replace'); off += tlen
            slen    = struct.unpack('<H', app_data[off:off + 2])[0]; off += 2
            scene   = app_data[off:off + slen].decode('ascii', errors='replace')
        except Exception:
            terrain, scene = "?", "?"

        print(f"  Scene : {scene}  |  Terrain : {terrain}")
        print("  [Zone] OK connexion ZoneServer etablie\n")
        return zone

    print("  [Zone] SceneCreateObjectByName non recu (timeout)")
    print("  -> Mode Delta-only (M1.3 continuera quand meme)\n")
    return zone

# ---------------------------------------------------------------------------
# M1.3  --  Console Delta
# ---------------------------------------------------------------------------

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


def _fmt_delta(body: bytes) -> str:
    if len(body) < 14:
        return f"[Delta] court: {body.hex()}"
    obj_id   = struct.unpack('<Q', body[0:8])[0]
    var_type = struct.unpack('<H', body[8:10])[0]
    version  = struct.unpack('<H', body[10:12])[0]
    upd_cnt  = struct.unpack('<I', body[12:16])[0] if len(body) >= 16 else '?'
    return (f"[Delta] obj=0x{obj_id:016x}  "
            f"type=0x{var_type:04x}  ver={version}  #upd={upd_cnt}")


def _fmt_obj_ctrl(body: bytes) -> str:
    if len(body) < 12:
        return f"[ObjCtrl] court: {body.hex()}"
    obj_id  = struct.unpack('<Q', body[0:8])[0]
    ctrl_op = struct.unpack('<I', body[8:12])[0]
    name    = CTRL_NAMES.get(ctrl_op, f"0x{ctrl_op:04x}")
    extra   = ""
    # DataTransform : [8 obj][4 op][4 seq][4 flags][3x float pos][float heading][float speed]
    if ctrl_op == CTRL_DATA_TRANSFORM and len(body) >= 36:
        x = struct.unpack('<f', body[16:20])[0]
        y = struct.unpack('<f', body[20:24])[0]
        z = struct.unpack('<f', body[24:28])[0]
        extra = f"  pos=({x:.2f}, {y:.2f}, {z:.2f})"
    elif ctrl_op == CTRL_DATA_TRANSFORM_WITH_PARENT and len(body) >= 44:
        x = struct.unpack('<f', body[24:28])[0]
        y = struct.unpack('<f', body[28:32])[0]
        z = struct.unpack('<f', body[32:36])[0]
        extra = f"  pos=({x:.2f}, {y:.2f}, {z:.2f})"
    return f"[ObjCtrl/{name}] obj=0x{obj_id:016x}{extra}"


def _fmt_baseline(body: bytes) -> str:
    if len(body) < 10:
        return "[Baseline] court"
    obj_id   = struct.unpack('<Q', body[0:8])[0]
    var_type = struct.unpack('<H', body[8:10])[0]
    data_len = struct.unpack('<I', body[10:14])[0] if len(body) >= 14 else '?'
    return f"[Baseline] obj=0x{obj_id:016x}  type=0x{var_type:04x}  len={data_len}"


def delta_console_loop(zone: SOEClient, bridge: Optional["GodotBridge"] = None) -> None:
    """
    M1.3 : Boucle principale d'ecoute.
    Affiche Delta (0x000F), ObjCtrl (0x001B) et Baseline (0x0016) en temps reel.
    Si ``bridge`` est fourni (M3.1), transmet aussi les mouvements/spawns vers Godot.
    """
    zone.set_timeout(0.5)

    print("-" * 60)
    if bridge is not None and bridge._active:
        print("  M1.3+M3.1  --  Console + Bridge Godot  (Ctrl+C pour quitter)")
        print(f"  Godot UDP : localhost:{bridge.port}")
    else:
        print("  M1.3  --  MODE CONSOLE  (Ctrl+C pour quitter)")
    print("-" * 60)

    pkt_count  = 0
    start_time = time.time()

    try:
        while True:
            result = zone.recv()
            if result is None:
                continue

            _, app_data = result
            if len(app_data) < 2:
                continue

            app_op = struct.unpack('<H', app_data[0:2])[0]
            body   = app_data[2:]
            ts     = time.time() - start_time

            if app_op == SWG_DELTA:
                print(f"  [{ts:7.2f}s] >> {_fmt_delta(body)}")
                pkt_count += 1
            elif app_op == SWG_OBJ_CTRL:
                line = _fmt_obj_ctrl(body)
                print(f"  [{ts:7.2f}s] ** {line}")
                pkt_count += 1
                if bridge is not None and len(body) >= 12:
                    ctrl_op = struct.unpack('<I', body[8:12])[0]
                    obj_id  = struct.unpack('<Q', body[0:8])[0]
                    if ctrl_op == CTRL_DATA_TRANSFORM and len(body) >= 36:
                        x = struct.unpack('<f', body[16:20])[0]
                        y = struct.unpack('<f', body[20:24])[0]
                        z = struct.unpack('<f', body[24:28])[0]
                        bridge.move(obj_id, x, y, z)
                    elif ctrl_op == CTRL_DATA_TRANSFORM_WITH_PARENT and len(body) >= 44:
                        x = struct.unpack('<f', body[24:28])[0]
                        y = struct.unpack('<f', body[28:32])[0]
                        z = struct.unpack('<f', body[32:36])[0]
                        bridge.move(obj_id, x, y, z)
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
                    if bridge is not None:
                        bridge.zone_change(planet)
                        bridge.connect_player(oid, x, y, z, planet)
                    pkt_count += 1

                elif sub_op == HASH_SCENE_CREATE:
                    info = _parse_scene_create(app_data)
                    oid  = info["obj_id"]
                    tmpl = info["tmpl"]
                    x, y, z = info["x"], info["y"], info["z"]
                    color = "npc"
                    if "player" in tmpl.lower() or "humanoid" in tmpl.lower():
                        color = "green"
                    elif "vehicle" in tmpl.lower():
                        color = "orange"
                    label = tmpl.split("/")[-1].replace(".iff", "")[:16] if tmpl else ""
                    if bridge is not None:
                        bridge.spawn(oid, x, y, z, color, label)
                    print(f"  [{ts:7.2f}s] ++ Spawn  obj=0x{oid:016x}  {label}  pos=({x:.1f},{y:.1f},{z:.1f})")
                    pkt_count += 1

                elif sub_op == HASH_SCENE_DESTROY:
                    if len(app_data) >= 14:
                        oid = struct.unpack("<Q", app_data[6:14])[0]
                        if bridge is not None:
                            bridge.despawn(oid)
                        print(f"  [{ts:7.2f}s] -- Despawn  obj=0x{oid:016x}")
                        pkt_count += 1

    except KeyboardInterrupt:
        elapsed = time.time() - start_time
        rate    = f"{pkt_count / elapsed:.1f} pkt/s" if elapsed > 0 else ""
        print(f"\n  Arret. {pkt_count} paquets en {elapsed:.1f}s {rate}")
    finally:
        if bridge is not None:
            bridge.close()


# ---------------------------------------------------------------------------
# M3.1 — GodotBridge : forward des paquets SOE parsés vers Godot (UDP local)
# ---------------------------------------------------------------------------

class GodotBridge:
    """
    Envoie des paquets JSON compacts via UDP local vers le NetworkBridge Godot.
    Port par défaut : 12345 (localhost uniquement).
    """
    def __init__(self, port: int = 12345):
        self.port    = port
        self._sock   = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self._active = port > 0

    def _send(self, obj: dict) -> None:
        if not self._active:
            return
        try:
            data = json.dumps(obj, separators=(',', ':')).encode('utf-8')
            self._sock.sendto(data, ('127.0.0.1', self.port))
        except Exception:
            pass

    def move(self, obj_id: int, x: float, y: float, z: float) -> None:
        self._send({"t": "mv", "id": obj_id,
                    "x": round(x, 3), "y": round(y, 3), "z": round(z, 3)})

    def spawn(self, obj_id: int, x: float, y: float, z: float,
              color: str = "npc", label: str = "") -> None:
        pkt: dict = {"t": "sp", "id": obj_id,
                     "x": round(x, 3), "y": round(y, 3), "z": round(z, 3),
                     "c": color}
        if label:
            pkt["l"] = label[:20]
        self._send(pkt)

    def despawn(self, obj_id: int) -> None:
        self._send({"t": "dp", "id": obj_id})

    def zone_change(self, scene: str) -> None:
        self._send({"t": "zc", "scene": scene})

    def connect_player(self, obj_id: int, x: float, y: float, z: float,
                       planet: str = "") -> None:
        self._send({"t": "cn", "id": obj_id,
                    "x": round(x, 3), "y": round(y, 3), "z": round(z, 3),
                    "pl": planet[:32] if planet else ""})

    def locomotion_state(self, state: str) -> None:
        self._send({"t": "ls", "s": state})

    def close(self) -> None:
        self._sock.close()


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="SOE/Core3 headless client -- SWGEmu (M1.1 + M1.2 + M1.3)",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument("--host",       default="192.168.0.246",
                        help="LoginServer host")
    parser.add_argument("--port",       type=int, default=44553,
                        help="LoginServer port")
    parser.add_argument("--user",       default="Bot_IA",
                        help="Compte SWGEmu")
    parser.add_argument("--password",   default="lbgiabot",
                        help="Mot de passe")
    parser.add_argument("--char",       type=int, default=0, dest="char_index",
                        help="Index du personnage (0 = premier)")
    parser.add_argument("--zone-host",  default="",
                        help="ZoneServer host (auto si vide)")
    parser.add_argument("--zone-port",  type=int, default=0,
                        help="ZoneServer port (auto si 0)")
    parser.add_argument("--godot-port", type=int, default=0,
                        help="Port UDP Godot pour le bridge (0 = desactive, defaut 12345 si >0)")
    parser.add_argument("--no-zone",    action="store_true",
                        help="Arreter apres login (ne pas connecter au ZoneServer)")
    parser.add_argument("--debug",      action="store_true",
                        help="Logs SOE (CRC, paquets recus)")
    args = parser.parse_args()

    session = login_phase(args)
    if session is None:
        sys.exit(1)

    if args.no_zone:
        print("[--no-zone] Arret apres login.")
        sys.exit(0)

    if not session.characters:
        print("Aucun personnage -- impossible de rejoindre une zone.")
        sys.exit(1)

    zone_host = args.zone_host
    zone_port = args.zone_port

    if not zone_host or not zone_port:
        idx    = min(args.char_index, len(session.characters) - 1)
        target = session.characters[idx].cluster_id
        galaxy = next((g for g in session.galaxies if g.galaxy_id == target), None)

        if galaxy and galaxy.host and galaxy.port:
            zone_host = galaxy.host
            zone_port = galaxy.port
        else:
            zone_host = args.host
            zone_port = ZONE_DEFAULT_PORT
            print(f"[Zone] Adresse non trouvee -> fallback {zone_host}:{zone_port}")

    zone = zone_connect_phase(session, zone_host, zone_port)
    if zone is None:
        print("[Zone] Connexion ZoneServer echouee")
        sys.exit(1)

    godot_port = args.godot_port if args.godot_port > 0 else 0
    bridge = GodotBridge(godot_port) if godot_port else None
    delta_console_loop(zone, bridge)
    zone.close()


if __name__ == "__main__":
    main()
