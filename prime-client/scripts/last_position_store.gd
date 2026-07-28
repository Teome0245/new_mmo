# last_position_store.gd — Persistance locale dernière position (secours si gateway reset)
extends RefCounted

const PATH := "user://lbg_last_pos.json"


static func save(character_id: int, pos: Vector3) -> void:
	if character_id < 1:
		return
	var doc: Dictionary = _load_all()
	doc[str(character_id)] = {
		"x": pos.x,
		"y": pos.y,
		"z": pos.z,
		"ts": Time.get_unix_time_from_system(),
	}
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(doc))
		f.close()


static func load_pos(character_id: int) -> Vector3:
	if character_id < 1:
		return Vector3.INF
	var doc: Dictionary = _load_all()
	var row: Variant = doc.get(str(character_id), null)
	if not row is Dictionary:
		return Vector3.INF
	var d: Dictionary = row
	return Vector3(float(d.get("x", 0)), float(d.get("y", 0)), float(d.get("z", 0)))


static func _load_all() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return {}
	var raw: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return raw if raw is Dictionary else {}
