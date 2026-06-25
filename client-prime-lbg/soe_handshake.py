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
import socket
import struct
import sys
import argparse
import time
from dataclasses import dataclass, field
from typing import Optional, List, Tuple, Dict

# ---------------------------------------------------------------------------
# CRC-32 Table (polynôme 0x04C11DB7 — standard SWG / BaseProtocol)
# ---------------------------------------------------------------------------
CRCTABLE = [
    0x00000000, 0x04C11DB7, 0x09823B6E, 0x0D4326D9, 0x130476DC, 0x17C56B6B,
    0x1A864DB2, 0x1E475005, 0x2608EDB8, 0x22C9F00F, 0x2F8AD6D6, 0x2B4BCB61,
    0x350C9B64, 0x31CD86D3, 0x3C8EA00A, 0x384FBDBD, 0x4C11DB70, 0x48D0C6C7,
    0x4593E01E, 0x4152FDA9, 0x5F15ADAC, 0x5BD4B01B, 0x569796C2, 0x52568B75,
    0x6A1936C8, 0x6ED82B7F, 0x639B0DA6, 0x675A1011, 0x791D4014, 0x7DDC5DA3,
    0x709F7B7A, 0x745E66CD, 0x9823B6E0, 0x9CE2AB57, 0x91A18D8E, 0x95609039,
    0x8B27C03C, 0x8FE6DD8B, 0x82A5FB52, 0x8664E6E5, 0xBE2B5B58, 0xBAEA46EF,
    0xB7A96036, 0xB3687D81, 0xAD2F2D84, 0xA9EE3033, 0xA4AD16EA, 0xA06C0B5D,
    0xD4326D90, 0xD0F37027, 0xDDB056FE, 0xD9714B49, 0xC7361B4C, 0xC3F706FB,
    0xCEB42022, 0xCA753D95, 0xF23A8028, 0xF6FB9D9F, 0xFBB8BB46, 0xFF79A6F1,
    0xE13EF6F4, 0xE5FFEB43, 0xE8BCCD9A, 0xEC7DD02D, 0x34867077, 0x30476DC0,
    0x3D044B19, 0x39C556AE, 0x278206AB, 0x23431B1C, 0x2E003DC5, 0x2AC12072,
    0x128E9DCF, 0x164F8078, 0x1B0CA6A1, 0x1FCDBB16, 0x018AEB13, 0x054BF6A4,
    0x0808D07D, 0x0CC9CDCA, 0x7897AB07, 0x7C56B6B0, 0x71159069, 0x75D48DDE,
    0x6B93DDDB, 0x6F52C06C, 0x6211E6B5, 0x66D0FB02, 0x5E9F46BF, 0x5A5E5B08,
    0x571D7DD1, 0x53DC6066, 0x4D9B3063, 0x495A2DD4, 0x44190B0D, 0x40D816BA,
    0xACA5C697, 0xA864DB20, 0xA527FDF9, 0xA1E6E04E, 0xBFA1B04B, 0xBB60ADFC,
    0xB6238B25, 0xB2E29692, 0x8AAD2B2F, 0x8E6C3698, 0x832F1041, 0x87EE0DF6,
    0x99A95DF3, 0x9D684044, 0x902B669D, 0x94EA7B2A, 0xE0B41DE7, 0xE4750050,
    0xE9362689, 0xEDF73B3E, 0xF3B06B3B, 0xF771768C, 0xFA325055, 0xFEF34DE2,
    0xC6BCF05F, 0xC27DEDE8, 0xCF3ECB31, 0xCBFFD686, 0xD5B88683, 0xD1799B34,
    0xDC3ABDED, 0xD8FBA05A, 0x690CE0EE, 0x6DCDFD59, 0x608EDB80, 0x644FC637,
    0x7A089632, 0x7EC98B85, 0x738AAD5C, 0x774BB0EB, 0x4F040D56, 0x4BC510E1,
    0x46863638, 0x42472B8F, 0x5C007B8A, 0x58C1663D, 0x558240E4, 0x51435D53,
    0x251D3B9E, 0x21DC2629, 0x2C9F00F0, 0x285E1D47, 0x36194D42, 0x32D850F5,
    0x3F9B762C, 0x3B5A6B9B, 0x0315D626, 0x07D4CB91, 0x0A97ED48, 0x0E56F0FF,
    0x1011A0FA, 0x14D0BD4D, 0x19939B94, 0x1D528623, 0xF12F560E, 0xF5EE4BB9,
    0xF8AD6D60, 0xFC6C70D7, 0xE22B20D2, 0xE6EA3D65, 0xEBAB56BE, 0xEF6A4B09,
    0xED286236, 0xE9E97F81, 0xF02C98FA, 0xF4ED854D, 0xF9AFE394, 0xFD6EFD23,
    0xC6238B25, 0xC2E29692, 0xCF21B04B, 0xCB60ADFC, 0xD527FDF9, 0xD1E6E04E,
    0xDC25C697, 0xD8E4DB20, 0xE02B8FA5, 0xE4EA9212, 0xE9A9B4CB, 0xED68A97C,
    0xF32FFA79, 0xF7EEE7CE, 0xFAADC117, 0xFE6CDCA0, 0xAC23C5D5, 0xA8E2D862,
    0xA5A1FEBB, 0xA160E30C, 0xBF27B309, 0xBBE6AEBE, 0xB6A58867, 0xB26495D0,
    0x8C2BEA25, 0x88EA9792, 0x85A9D14B, 0x8168CCFC, 0x9F2F9CFA, 0x9BEE814D,
    0x96AD2794, 0x926C3A23, 0x6C238B25, 0x68E29692, 0x65A1B04B, 0x6160ADFC,
    0x7F27FDF9, 0x7BE6E04E, 0x7625C697, 0x72E4DB20, 0x4C238B25, 0x48E29692,
    0x45A1B04B, 0x4160ADFC, 0x5F27FDF9, 0x5BE6E04E, 0x5625C697, 0x52E4DB20,
    0x1C238B25, 0x18E29692, 0x15A1B04B, 0x1160ADFC, 0x0F27FDF9, 0x0BE6E04E,
    0x0625C697, 0x02E4DB20, 0x3C238B25, 0x38E29692, 0x35A1B04B, 0x3160ADFC,
    0x2F27FDF9, 0x2BE6E04E, 0x2625C697, 0x22E4DB20, 0x1C517D16, 0x189060A1,
    0x15D34678, 0x11125BCF, 0x0F550BC6, 0x0B941671, 0x06D730A8, 0x02162D1F,
    0x3A5990A6, 0x3E988D11, 0x33DBABCB, 0x371A467C, 0x295DE67A, 0x2D9CFBC3,
    0x20DFAF14, 0x241EBEA3, 0x5C517D16, 0x589060A1, 0x55D34678, 0x51125BCF,
    0x4F550BC6, 0x4B941671, 0x06D730A8, 0x02162D1F, 0x7A5990A6, 0x7E988D11,
    0x73DBABCB, 0x771A467C, 0x695DE67A, 0x6D9CFBC3, 0x60DFAF14, 0x641EBEA3,
    0x8C517D16, 0x889060A1, 0x85D34678, 0x81125BCF, 0x9F550BC6, 0x9B941671,
    0x96D730A8, 0x92162D1F, 0xAA5990A6, 0xAE988D11, 0xA3DBABCB, 0xA71A467C,
    0xB95DE67A, 0xBD9CFBC3, 0xB0DFAF14, 0xB41EBEA3, 0xFC517D16, 0xF89060A1,
    0xF5D34678, 0xF1125BCF, 0xEF550BC6, 0xEB941671, 0xE6D730A8, 0xE2162D1F,
    0xDA5990A6, 0xDE988D11, 0xD3DBABCB, 0xD71A467C, 0xC95DE67A, 0xCD9CFBC3,
    0xC0DFAF14, 0xC41EBEA3, 0x5A05DF1B, 0x2D02EF8D,
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

ZONE_DEFAULT_PORT = 44463   # port ZoneServer SWGEmu par défaut

# ---------------------------------------------------------------------------
# Utilitaires crypto / CRC
# ---------------------------------------------------------------------------

def string_hashcode(s: str) -> int:
    """Hash CRC-32 d'un nom de classe SWG (String.h)"""
    crc = 0xFFFFFFFF
    for ch in s:
        idx = ((crc >> 24) ^ ord(ch)) & 0xFF
        crc = (CRCTABLE[idx] ^ (crc << 8)) & 0xFFFFFFFF
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
            build_ascii("20051101-18:00") +
            struct.pack('<I', string_hashcode("SWGEmu")))


def build_select_character(cluster_id: int, char_struct_id: int) -> bytes:
    return (struct.pack('<H', 0x0004) +
            struct.pack('<I', string_hashcode("SelectCharacter")) +
            struct.pack('<I', cluster_id) +
            struct.pack('<Q', char_struct_id))


def build_client_id_msg(session_token: str, client_version: str = "20051101-18:00") -> bytes:
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
    _OP_DATA_CHANNEL = b'\x09\x00'
    _OP_FRAG_DATA    = b'\x0d\x00'
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
        self._frag_buf:     bytes = b''
        self._frag_total:   int   = 0

    def connect(self) -> bool:
        """Handshake SOE ConnectRequest -> ConnectResponse (M1.1)"""
        pkt = (self._OP_CONNECT_REQ + b'\x00\x00' + b'\x01\x00' +
               struct.pack('<I', 0x12345678))
        print(f"  [SOE] ConnectRequest -> {self.host}:{self.port} ...")
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
        if soe_op == self._OP_DISCONNECT:
            print("  [SOE] Deconnexion recue du serveur")
            return None

        # Verification CRC
        exp_crc  = struct.unpack('>H', data[-2:])[0]
        calc_crc = generate_crc32(data[:-2], self.crc_seed) & 0xFFFF
        if exp_crc != calc_crc:
            return None

        dec    = decrypt_payload(data, self.crc_seed)
        soe_op = dec[0:2]

        if soe_op == self._OP_DATA_CHANNEL:
            srv_seq  = struct.unpack('>H', dec[2:4])[0]
            self._ack(srv_seq)
            app_data = dec[4:-3]
            return (soe_op, app_data)

        if soe_op == self._OP_FRAG_DATA:
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
                assembled        = self._frag_buf[:self._frag_total]
                self._frag_buf   = b''
                self._frag_total = 0
                return (soe_op, assembled)
            return None

        return None

    def close(self) -> None:
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
    if not client.connect():
        return None

    session = LoginSession()

    avm = build_account_version_message(args.user, args.password)
    client.send(avm)
    print(f"  -> AccountVersionMessage envoye ({args.user})")
    print("  Reception des messages Login ...")

    got_token = False
    got_chars = False

    for _ in range(30):
        result = client.recv()
        if result is None:
            if got_token and got_chars:
                break
            continue

        _, app_data = result
        if len(app_data) < 6:
            continue

        app_op = struct.unpack('<H', app_data[0:2])[0]
        if app_op != SWG_OPCODE_GAME:
            continue

        sub_op = struct.unpack('<I', app_data[2:6])[0]
        body   = app_data[6:]

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


def delta_console_loop(zone: SOEClient) -> None:
    """
    M1.3 : Boucle principale d'ecoute.
    Affiche Delta (0x000F), ObjCtrl (0x001B) et Baseline (0x0016) en temps reel.
    """
    zone.set_timeout(0.5)

    print("-" * 60)
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
                print(f"  [{ts:7.2f}s] ** {_fmt_obj_ctrl(body)}")
                pkt_count += 1
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

    except KeyboardInterrupt:
        elapsed = time.time() - start_time
        rate    = f"{pkt_count / elapsed:.1f} pkt/s" if elapsed > 0 else ""
        print(f"\n  Arret. {pkt_count} paquets en {elapsed:.1f}s {rate}")

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
                        help="Port UDP Godot pour le bridge (0 = desactive)")
    parser.add_argument("--no-zone",    action="store_true",
                        help="Arreter apres login (ne pas connecter au ZoneServer)")
    args = parser.parse_args()

    # M1.1 + M1.2a
    session = login_phase(args)
    if session is None:
        sys.exit(1)

    if args.no_zone:
        print("[--no-zone] Arret apres login.")
        sys.exit(0)

    if not session.characters:
        print("Aucun personnage -- impossible de rejoindre une zone.")
        sys.exit(1)

    # Resoudre adresse ZoneServer
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

    # M1.2b
    zone = zone_connect_phase(session, zone_host, zone_port)
    if zone is None:
        print("[Zone] Connexion ZoneServer echouee")
        sys.exit(1)

    # M1.3 + M3.1
    bridge = GodotBridge(args.godot_port)
    if args.godot_port:
        delta_console_loop_with_bridge(zone, bridge)
    else:
        delta_console_loop(zone)
    zone.close()


if __name__ == "__main__":
    main()

# ===========================================================================
# M3.1 — GodotBridge : forward des paquets SOE parsés vers Godot (UDP local)
# ===========================================================================

class GodotBridge:
    """
    Envoie des paquets JSON compacts via UDP local vers le NetworkBridge Godot.
    Port par défaut : 12345 (localhost uniquement).
    Protocole :
      {"t":"mv","id":int,"x":f,"y":f,"z":f}   DataTransform
      {"t":"sp","id":int,"x":f,"y":f,"z":f,"c":"blue","l":"name"}  Spawn
      {"t":"dp","id":int}                       Despawn
      {"t":"zc","scene":"tatooine"}             Zone change
    """
    def __init__(self, port: int = 12345):
        self.port    = port
        self._sock   = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self._active = port > 0

    def _send(self, obj: dict) -> None:
        if not self._active:
            return
        try:
            import json as _json
            data = _json.dumps(obj, separators=(',', ':')).encode('utf-8')
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
        """M5 : joueur connecté — notifie Godot de son obj_id et sa position."""
        self._send({"t": "cn", "id": obj_id,
                    "x": round(x, 3), "y": round(y, 3), "z": round(z, 3),
                    "pl": planet[:32] if planet else ""})

    def locomotion_state(self, state: str) -> None:
        """Envoie l'etat de locomotion pour le StateLabel Godot."""
        self._send({"t": "ls", "s": state})

    def close(self) -> None:
        self._sock.close()


# ===========================================================================
# Surcharge de delta_console_loop pour inclure le bridge Godot
# ===========================================================================

def delta_console_loop_with_bridge(zone: SOEClient, bridge: GodotBridge) -> None:
    """
    M1.3 + M3.1 : Boucle delta étendue — affiche ET formate vers Godot.
    Remplace delta_console_loop() quand --godot-port est fourni.
    """
    zone.set_timeout(0.5)

    print("-" * 60)
    print("  M1.3+M3.1  --  Console + Bridge Godot  (Ctrl+C pour quitter)")
    if bridge._active:
        print(f"  Godot UDP : localhost:{bridge.port}")
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

                # Transmettre DataTransform a Godot
                if len(body) >= 12:
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

    except KeyboardInterrupt:
        elapsed = time.time() - start_time
        rate    = f"{pkt_count / elapsed:.1f} pkt/s" if elapsed > 0 else ""
        print(f"\n  Arret. {pkt_count} paquets en {elapsed:.1f}s {rate}")
    finally:
        bridge.close()
