# retail_layout_layer.gd — Emprises vertes + triangles PNJ (retail + serveur 246 live)
extends Node2D
class_name RetailLayoutLayer

const RETAIL_DIR := "res://assets/maps/retail/tatooine/"

@export var visible_layout: bool = false
@export var city_id: String = "mos_eisley"
@export var show_buildings: bool = true
@export var show_npcs: bool = true
@export var show_server_npcs: bool = true
@export var show_terminals: bool = true
@export var max_labels: int = 96

var _buildings: Array = []
var _npcs_layout: Array = []
var _npcs_server: Dictionary = {}
var _markers: Array = []

func _ready() -> void:
	reload()

func reload() -> void:
	_buildings.clear()
	_npcs_layout.clear()
	_markers.clear()
	var path := _resolve_layout_path()
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		push_warning("RetailLayoutLayer: %s absent" % path)
		queue_redraw()
		return
	var f := FileAccess.open(path, FileAccess.READ)
	var raw: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if raw is Dictionary:
		var doc: Dictionary = raw
		_buildings = doc.get("buildings", []) if doc.get("buildings") is Array else []
		_markers = doc.get("markers", []) if doc.get("markers") is Array else []
		var all_npc: Variant = doc.get("npcs", [])
		if all_npc is Array:
			for item: Variant in all_npc:
				if not item is Dictionary:
					continue
				var n: Dictionary = item
				if str(n.get("source", "")) == "server_npc_snapshots":
					_npcs_server[str(n.get("id", ""))] = n
				else:
					_npcs_layout.append(n)
	queue_redraw()

func _server_npc_cfg() -> Dictionary:
	var wr := MapTextureLoader.world_render_cfg()
	var sn: Variant = wr.get("server_npcs", null)
	return sn if sn is Dictionary else {}

func merge_zone_entities(entities: Array, your_character_id: int = 0) -> void:
	if not show_server_npcs:
		return
	var cfg := _server_npc_cfg()
	if cfg.get("enabled", true) == false:
		return
	if not bool(cfg.get("merge_ws_zone_state", true)):
		return
	var ax := float(cfg.get("anchor_x", 4749.0))
	var az := float(cfg.get("anchor_z", -737.0))
	var radius := float(cfg.get("radius_m", 800.0))
	var r2 := radius * radius
	var changed := false
	for ent: Variant in entities:
		if not ent is Dictionary:
			continue
		var d: Dictionary = ent
		if str(d.get("kind", "")) != "npc":
			continue
		var name := str(d.get("name", ""))
		if name.begins_with("Vous") or name.to_lower() == "you":
			continue
		var pos := _entity_core3(d)
		var dx := pos.x - ax
		var dz := pos.z - az
		if dx * dx + dz * dz > r2:
			continue
		var eid := str(d.get("id", name))
		if eid == str(your_character_id):
			continue
		_npcs_server[eid] = {
			"id": eid,
			"label": name if name != "" else eid,
			"kind": "npc",
			"x": pos.x,
			"y": pos.y,
			"z": pos.z,
			"heading_deg": 0.0,
			"source": "server_ws_zone_state",
			"online": true,
		}
		changed = true
	if changed:
		queue_redraw()

func _entity_core3(d: Dictionary) -> Vector3:
	var pos_raw = d.get("pos")
	if pos_raw is Array and (pos_raw as Array).size() >= 3:
		var a: Array = pos_raw
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3(float(d.get("x", 0)), float(d.get("y", 0)), float(d.get("z", 0)))

func _resolve_layout_path() -> String:
	var explicit := str(MapTextureLoader.world_render_cfg().get("position_map_json", "")).strip_edges()
	if explicit != "" and ResourceLoader.exists(explicit):
		return explicit
	return RETAIL_DIR + "%s_retail_layout.json" % city_id

func set_city(city: String) -> void:
	city_id = city
	reload()

func set_visible_layout(on: bool) -> void:
	visible_layout = on
	queue_redraw()

func server_npc_count() -> int:
	return _npcs_server.size()

func _draw() -> void:
	if not visible_layout:
		return
	var labels := 0
	if show_buildings:
		for item: Variant in _buildings:
			if item is Dictionary:
				_draw_building(item as Dictionary)
				labels += _draw_label(item as Dictionary, labels)
	if show_npcs:
		for item: Variant in _npcs_layout:
			if item is Dictionary:
				_draw_npc_triangle(item as Dictionary, Color(1.0, 1.0, 1.0, 0.92))
				labels += _draw_label(item as Dictionary, labels)
	if show_server_npcs:
		for _id in _npcs_server:
			var item: Variant = _npcs_server[_id]
			if item is Dictionary:
				_draw_npc_triangle(item as Dictionary, Color(0.45, 0.95, 1.0, 0.95))
				labels += _draw_label(item as Dictionary, labels, Color(0.75, 0.95, 1.0, 0.9))
	if show_terminals:
		for item: Variant in _markers:
			if item is Dictionary:
				_draw_building(item as Dictionary, Color(0.35, 0.85, 1.0, 0.35))

func _draw_building(b: Dictionary, fill: Color = Color(0.25, 0.95, 0.35, 0.42)) -> void:
	var cx := float(b.get("x", 0.0))
	var cz := float(b.get("z", 0.0))
	var size_m := float(b.get("size_m", 24.0))
	var half := size_m * 0.5 * Projection3D2D.SCALE
	var center := Projection3D2D.to_screen(Vector3(cx, float(b.get("y", 0.0)), cz))
	var rect := Rect2(center - Vector2(half, half), Vector2(half * 2.0, half * 2.0))
	draw_rect(rect, fill)
	draw_rect(rect, Color(0.4, 1.0, 0.5, 0.85), false, 1.2)

func _draw_npc_triangle(n: Dictionary, fill: Color) -> void:
	var cx := float(n.get("x", 0.0))
	var cz := float(n.get("z", 0.0))
	var center := Projection3D2D.to_screen(Vector3(cx, float(n.get("y", 0.0)), cz))
	var heading := float(n.get("heading_deg", 0.0)) * (PI / 180.0)
	var fwd := Vector2(sin(heading), -cos(heading))
	var left := Vector2(-fwd.y, fwd.x)
	var tip := center + fwd * 6.0
	var p1 := center - fwd * 3.0 + left * 4.0
	var p2 := center - fwd * 3.0 - left * 4.0
	draw_colored_polygon(PackedVector2Array([tip, p1, p2]), fill)

func _draw_label(item: Dictionary, labels: int, col: Color = Color(1.0, 1.0, 1.0, 0.88)) -> int:
	if labels >= max_labels:
		return 0
	var lbl := str(item.get("label", ""))
	if lbl == "":
		lbl = str(item.get("name", ""))
	if lbl == "":
		return 0
	var cx := float(item.get("x", 0.0))
	var cz := float(item.get("z", 0.0))
	var center := Projection3D2D.to_screen(Vector3(cx, float(item.get("y", 0.0)), cz))
	draw_string(
		ThemeDB.fallback_font,
		center + Vector2(6, -8),
		lbl,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		9,
		col
	)
	return 1
