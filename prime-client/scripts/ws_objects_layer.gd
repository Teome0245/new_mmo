# ws_objects_layer.gd — M4.4 bâtiments statiques (.ws → JSON)
extends Node2D
class_name WsObjectsLayer

const WS_JSON := "res://assets/maps/mos_eisley_ws.json"

@export var visible_objects: bool = true
@export var max_labels: int = 40

var _objects: Array = []

func _ready() -> void:
	reload()

func reload() -> void:
	_objects.clear()
	if not FileAccess.file_exists(WS_JSON):
		push_warning("WsObjectsLayer: %s absent" % WS_JSON)
		return
	var f := FileAccess.open(WS_JSON, FileAccess.READ)
	var raw: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if raw is Array:
		_objects = raw
	queue_redraw()

func _draw() -> void:
	if not visible_objects:
		return
	var labels := 0
	for item: Variant in _objects:
		if not item is Dictionary:
			continue
		var o: Dictionary = item
		var pos := Projection3D2D.to_screen(Vector3(
			float(o.get("x", 0.0)),
			float(o.get("y", 0.0)),
			float(o.get("z", 0.0))
		))
		draw_circle(pos, 3.0, Color(0.55, 0.55, 0.62, 0.85))
		if labels >= max_labels:
			continue
		var tmpl := str(o.get("tmpl", ""))
		if tmpl == "":
			continue
		var short := tmpl.get_file().get_basename()
		if short.begins_with("shared_"):
			short = short.substr(7)
		if short.length() > 14:
			short = short.substr(0, 12) + ".."
		draw_string(ThemeDB.fallback_font, pos + Vector2(4, -3), short, HORIZONTAL_ALIGNMENT_LEFT, -1, 8,
			Color(0.75, 0.75, 0.8, 0.7))
		labels += 1

func set_visible_objects(on: bool) -> void:
	visible_objects = on
	queue_redraw()
