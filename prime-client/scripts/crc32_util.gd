# crc32_util.gd — CRC32 IEEE, aligné sur Python zlib.crc32 (zone_feed / godot_bridge)
extends RefCounted
class_name Crc32Util

static var _table: PackedInt32Array

static func _ensure_table() -> void:
	if _table != null and _table.size() == 256:
		return
	_table = PackedInt32Array()
	_table.resize(256)
	for i in 256:
		var c: int = i
		for _j in 8:
			if c & 1:
				c = 0xEDB88320 ^ (c >> 1)
			else:
				c = c >> 1
		_table[i] = c

## Même formule que godot_bridge.entity_oid() : zlib.crc32(utf8) & 0x7FFFFFFF
static func entity_oid(s: String) -> int:
	_ensure_table()
	var data: PackedByteArray = s.to_utf8_buffer()
	var crc: int = 0xFFFFFFFF
	for i in data.size():
		crc = _table[(crc ^ data[i]) & 0xFF] ^ (crc >> 8)
	return int((crc ^ 0xFFFFFFFF) & 0x7FFF_FFFF)
