# hub_props_layer.gd — Chemins + props Lost Heaven (data-driven, _draw)
extends Node2D
class_name HubPropsLayer

const PROPS_PATH := "res://assets/maps/lost_heaven_props.json"

@export var visible_props: bool = true
@export var show_prop_labels: bool = false

var _paths: Array = []
var _props: Array = []
var _defaults: Dictionary = {}
var _gate_exits: Array = []

func _ready() -> void:
	reload()

func reload() -> void:
	_paths.clear()
	_props.clear()
	_defaults.clear()
	if not FileAccess.file_exists(PROPS_PATH):
		push_warning("HubPropsLayer: %s absent" % PROPS_PATH)
		return
	var f := FileAccess.open(PROPS_PATH, FileAccess.READ)
	var raw: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if raw is Dictionary:
		var d: Dictionary = raw
		_defaults = d.get("defaults", {}) if d.get("defaults") is Dictionary else {}
		var p: Variant = d.get("paths", [])
		_paths = p if p is Array else []
		var pr: Variant = d.get("props", [])
		_props = pr if pr is Array else []
		var ge: Variant = d.get("gate_exits", [])
		_gate_exits = ge if ge is Array else []
	_props.sort_custom(func(a: Variant, b: Variant) -> bool:
		return int((a as Dictionary).get("z_draw", 0)) < int((b as Dictionary).get("z_draw", 0))
	)
	queue_redraw()

func _draw() -> void:
	if not visible_props:
		return
	for item: Variant in _paths:
		if item is Dictionary:
			_draw_path(item as Dictionary)
	for item: Variant in _props:
		if item is Dictionary:
			_draw_prop(item as Dictionary)

func _draw_path(p: Dictionary) -> void:
	var kind := str(p.get("kind", "road"))
	var width_m := float(p.get("width_m", _defaults.get("path_width_m", 6.0)))
	var width_px := width_m * Projection3D2D.SCALE
	var alpha := float(_defaults.get("path_alpha", 0.45))
	var fill := _path_color(kind, alpha)
	var pts_raw: Variant = p.get("points", null)
	if not (pts_raw is Array and (pts_raw as Array).size() >= 2):
		return
	var screen := PackedVector2Array()
	for pt: Variant in pts_raw as Array:
		if not pt is Dictionary:
			continue
		var d: Dictionary = pt
		screen.append(Projection3D2D.to_screen(Vector3(float(d.get("x", 0.0)), 0.0, float(d.get("z", 0.0)))))
	if screen.size() < 2:
		return
	if kind == "fence":
		_draw_fence(screen, bool(p.get("closed", false)), fill, pts_raw as Array)
		return
	_stroke_polyline(screen, width_px, fill, bool(p.get("closed", false)))

func _path_color(kind: String, alpha: float) -> Color:
	match kind:
		"plaza":
			return Color(0.72, 0.54, 0.34, alpha + 0.1)
		"alley":
			return Color(0.42, 0.32, 0.22, alpha)
		"fence":
			return Color(0.48, 0.38, 0.28, alpha + 0.15)
	return Color(0.55, 0.42, 0.28, alpha)

func _draw_fence(screen: PackedVector2Array, closed: bool, fill: Color, core3_pts: Array) -> void:
	var n := screen.size()
	var segs := n if closed else n - 1
	for i in range(segs):
		var a: Vector2 = screen[i]
		var b: Vector2 = screen[(i + 1) % n] if closed else screen[i + 1]
		if _fence_segment_is_gate_gap(core3_pts, i, closed):
			_draw_gate_opening(a, b, fill)
			continue
		var dir := b - a
		if dir.length_squared() < 0.01:
			continue
		var along := dir.normalized()
		var perp := Vector2(-along.y, along.x)
		var post_step := 14.0
		var count := maxi(1, int(dir.length() / post_step))
		for j in range(count + 1):
			var t := float(j) / float(count)
			var p := a.lerp(b, t)
			draw_line(p - perp * 3.0, p + perp * 3.0, fill.lightened(0.08), 2.0)
			draw_circle(p, 2.2, Color(fill.r, fill.g, fill.b, 0.85))
		var rail := PackedVector2Array([a + perp * 2.5, b + perp * 2.5, b - perp * 2.5, a - perp * 2.5])
		draw_colored_polygon(rail, Color(fill.r, fill.g, fill.b, 0.18))
	for item: Variant in _gate_exits:
		if item is Dictionary:
			_draw_gate_arch(item as Dictionary, fill)


func _fence_segment_is_gate_gap(core3_pts: Array, seg_index: int, closed: bool) -> bool:
	if _gate_exits.is_empty() or core3_pts.size() < 2:
		return false
	for ge: Variant in _gate_exits:
		if not ge is Dictionary:
			continue
		var g: Dictionary = ge
		var idxs: Variant = g.get("fence_open_segment_indices", [])
		if idxs is Array:
			for idx: Variant in idxs:
				if int(idx) == seg_index:
					return true
	var n := core3_pts.size()
	var i := seg_index
	var j := (i + 1) % n if closed else i + 1
	if j >= n:
		return false
	if not core3_pts[i] is Dictionary or not core3_pts[j] is Dictionary:
		return false
	var a: Dictionary = core3_pts[i]
	var b: Dictionary = core3_pts[j]
	var ax := float(a.get("x", 0.0))
	var az := float(a.get("z", 0.0))
	var bx := float(b.get("x", 0.0))
	var bz := float(b.get("z", 0.0))
	var mx := (ax + bx) * 0.5
	var mz := (az + bz) * 0.5
	for ge: Variant in _gate_exits:
		if not ge is Dictionary:
			continue
		var g: Dictionary = ge
		var c: Variant = g.get("center", {})
		if not c is Dictionary:
			continue
		var cd: Dictionary = c
		var gx := float(cd.get("x", 0.0))
		var gz := float(cd.get("z", 0.0))
		var hw := float(g.get("width_m", 16.0)) * 0.55
		if absf(mx - gx) <= hw and absf(mz - gz) <= 55.0:
			return true
	return false


func _draw_gate_opening(a: Vector2, b: Vector2, fill: Color) -> void:
	var mid := (a + b) * 0.5
	var dir := (b - a).normalized()
	var perp := Vector2(-dir.y, dir.x)
	draw_line(a - perp * 2.0, a + perp * 2.0, fill.lightened(0.2), 3.0)
	draw_line(b - perp * 2.0, b + perp * 2.0, fill.lightened(0.2), 3.0)
	draw_line(mid - perp * 5.0, mid + perp * 5.0, Color(0.85, 0.65, 0.35, 0.75), 2.5)


func _draw_gate_arch(g: Dictionary, fill: Color) -> void:
	var c: Variant = g.get("center", {})
	if not c is Dictionary:
		return
	var cd: Dictionary = c
	var gx := float(cd.get("x", 0.0))
	var gz := float(cd.get("z", 0.0))
	var hw := float(g.get("width_m", 16.0)) * 0.5
	var scr := Projection3D2D.to_screen(Vector3(gx, 0.0, gz))
	var w_px := hw * Projection3D2D.SCALE * 2.0
	draw_line(scr + Vector2(-w_px * 0.5, 0), scr + Vector2(w_px * 0.5, 0), Color(0.75, 0.55, 0.28, 0.9), 3.0)
	draw_arc(scr + Vector2(0, -6), w_px * 0.45, PI, 0.0, 12, Color(0.8, 0.6, 0.32, 0.85), 2.5)

func _stroke_polyline(screen: PackedVector2Array, width_px: float, fill: Color, closed: bool) -> void:
	var n := screen.size()
	var segs := n if closed else n - 1
	for i in range(segs):
		var a: Vector2 = screen[i]
		var b: Vector2 = screen[(i + 1) % n] if closed else screen[i + 1]
		var dir := b - a
		if dir.length_squared() < 0.01:
			continue
		var perp := Vector2(-dir.y, dir.x).normalized() * (width_px * 0.5)
		var quad := PackedVector2Array([a + perp, b + perp, b - perp, a - perp])
		draw_colored_polygon(quad, fill)
	draw_polyline(screen, Color(fill.r, fill.g, fill.b, minf(fill.a + 0.25, 0.85)), 1.2, closed)

func _draw_prop(p: Dictionary) -> void:
	var cx := float(p.get("x", 0.0))
	var cz := float(p.get("z", 0.0))
	var center := Projection3D2D.to_screen(Vector3(cx, 0.0, cz))
	var kind := str(p.get("kind", "crate"))
	var fill := _color_for_kind(kind)
	if p.has("color") and typeof(p.get("color")) == TYPE_STRING:
		fill = Color.html(str(p.get("color")))
	match kind:
		"crate_stack":
			_draw_crate_stack(center, fill)
		"stall":
			_draw_stall(center, p, fill)
		"lamp":
			_draw_lamp(center, p, fill)
		"bench":
			_draw_bench(center, p, fill)
		"table":
			_draw_table(center, p, fill)
		"barrier":
			_draw_barrier(center, p, fill)
		"monument":
			_draw_monument(center, fill)
		_:
			var fp: Variant = p.get("footprint", null)
			if fp is Dictionary:
				_draw_footprint(center, fp as Dictionary, fill, kind)
			else:
				var size_m := float(p.get("size_m", 4.0))
				var half_px := size_m * 0.5 * Projection3D2D.SCALE
				var rect := Rect2(center - Vector2(half_px, half_px), Vector2(half_px * 2.0, half_px * 2.0))
				draw_rect(rect, Color(fill.r, fill.g, fill.b, 0.4))
				draw_rect(rect, fill, false, 1.2)
	if show_prop_labels:
		var label := str(p.get("label", ""))
		if label != "":
			draw_string(
				ThemeDB.fallback_font,
				center + Vector2(-label.length() * 3.0, -10.0),
				label,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				10,
				Color(0.95, 0.9, 0.8, 0.75)
			)

func _draw_crate_stack(center: Vector2, fill: Color) -> void:
	var s := 5.0 * Projection3D2D.SCALE
	var offsets := [Vector2.ZERO, Vector2(s * 0.35, -s * 0.2), Vector2(-s * 0.3, s * 0.25)]
	for off in offsets:
		var rect := Rect2(center + off - Vector2(s, s) * 0.5, Vector2(s, s))
		draw_rect(rect, Color(fill.r * 0.7, fill.g * 0.7, fill.b * 0.7, 0.85))
		draw_rect(rect, fill, false, 1.0)

func _draw_stall(center: Vector2, p: Dictionary, fill: Color) -> void:
	var fp: Dictionary = p.get("footprint", {"w_m": 6.0, "h_m": 4.0})
	var w := float(fp.get("w_m", 6.0)) * Projection3D2D.SCALE
	var h := float(fp.get("h_m", 4.0)) * Projection3D2D.SCALE
	var yaw := deg_to_rad(float(fp.get("yaw_deg", 0.0)))
	var xf := Transform2D(yaw, center)
	var base := PackedVector2Array([
		Vector2(-w * 0.5, -h * 0.5), Vector2(w * 0.5, -h * 0.5),
		Vector2(w * 0.5, h * 0.5), Vector2(-w * 0.5, h * 0.5),
	])
	for i in base.size():
		base[i] = xf * base[i]
	draw_colored_polygon(base, Color(fill.r, fill.g, fill.b, 0.55))
	draw_polyline(base, fill, 1.5, true)
	var awning := PackedVector2Array([
		xf * Vector2(-w * 0.55, -h * 0.5),
		xf * Vector2(w * 0.55, -h * 0.5),
		xf * Vector2(w * 0.35, -h * 0.5 - h * 0.45),
		xf * Vector2(-w * 0.35, -h * 0.5 - h * 0.45),
	])
	draw_colored_polygon(awning, Color(fill.r, fill.g * 0.85, fill.b * 0.7, 0.7))
	draw_polyline(awning, fill.lightened(0.15), 1.2, true)

func _draw_lamp(center: Vector2, p: Dictionary, fill: Color) -> void:
	var r := float((p.get("footprint", {}) as Dictionary).get("radius_m", 1.2)) * Projection3D2D.SCALE
	r = maxf(r, 3.0)
	draw_circle(center, r * 2.2, Color(fill.r, fill.g, fill.b, 0.12))
	draw_line(center + Vector2(0, r), center + Vector2(0, -r * 1.8), Color(0.35, 0.32, 0.28, 0.9), 1.5)
	draw_circle(center + Vector2(0, -r * 1.8), r * 0.55, fill)
	draw_arc(center + Vector2(0, -r * 1.8), r * 0.75, 0.0, TAU, 16, fill.lightened(0.2), 1.0)

func _draw_bench(center: Vector2, p: Dictionary, fill: Color) -> void:
	var fp: Dictionary = p.get("footprint", {"w_m": 4.0, "h_m": 1.2})
	var w := float(fp.get("w_m", 4.0)) * Projection3D2D.SCALE
	var h := float(fp.get("h_m", 1.2)) * Projection3D2D.SCALE
	var rect := Rect2(center - Vector2(w, h) * 0.5, Vector2(w, h))
	draw_rect(rect, Color(fill.r, fill.g, fill.b, 0.75))
	draw_rect(rect, fill.darkened(0.15), false, 1.0)
	draw_line(rect.position + Vector2(0, h * 0.35), rect.end - Vector2(0, h * 0.35), fill.darkened(0.25), 1.0)

func _draw_table(center: Vector2, p: Dictionary, fill: Color) -> void:
	var fp: Dictionary = p.get("footprint", {"w_m": 2.5, "h_m": 2.5})
	var w := float(fp.get("w_m", 2.5)) * Projection3D2D.SCALE
	draw_circle(center, w * 0.5, Color(fill.r, fill.g, fill.b, 0.65))
	draw_arc(center, w * 0.5, 0.0, TAU, 14, fill.darkened(0.1), 1.2)

func _draw_barrier(center: Vector2, p: Dictionary, fill: Color) -> void:
	var fp: Dictionary = p.get("footprint", {"w_m": 12.0, "h_m": 2.0})
	var w := float(fp.get("w_m", 12.0)) * Projection3D2D.SCALE
	var h := float(fp.get("h_m", 2.0)) * Projection3D2D.SCALE
	var rect := Rect2(center - Vector2(w, h) * 0.5, Vector2(w, h))
	draw_rect(rect, Color(fill.r, fill.g, fill.b, 0.65))
	var stripes := int(w / 8.0)
	for i in range(stripes):
		var x0 := rect.position.x + float(i) * (w / float(stripes))
		draw_line(Vector2(x0, rect.position.y), Vector2(x0 + 4.0, rect.end.y), Color(0.9, 0.75, 0.3, 0.55), 1.5)

func _draw_monument(center: Vector2, fill: Color) -> void:
	draw_circle(center, 8.0, Color(fill.r, fill.g, fill.b, 0.35))
	draw_circle(center, 5.0, fill)
	draw_line(center + Vector2(0, 5), center + Vector2(0, -14), Color(fill.r, fill.g, fill.b, 0.85), 2.0)
	draw_circle(center + Vector2(0, -14), 3.5, fill.lightened(0.1))

func _draw_footprint(center: Vector2, fp: Dictionary, fill: Color, kind: String) -> void:
	var shape := str(fp.get("shape", "rect"))
	var fa := float(_defaults.get("prop_fill_alpha", 0.35))
	var sa := float(_defaults.get("prop_stroke_alpha", 0.9))
	if shape == "circle":
		var r := float(fp.get("radius_m", 2.0)) * Projection3D2D.SCALE
		draw_circle(center, r, Color(fill.r, fill.g, fill.b, fa))
		draw_arc(center, r, 0.0, TAU, 20, Color(fill.r, fill.g, fill.b, sa), 1.2)
		return
	var w := float(fp.get("w_m", 4.0)) * Projection3D2D.SCALE
	var h := float(fp.get("h_m", 4.0)) * Projection3D2D.SCALE
	var yaw := deg_to_rad(float(fp.get("yaw_deg", 0.0)))
	var xf := Transform2D(yaw, center)
	var pts := PackedVector2Array([
		Vector2(-w * 0.5, -h * 0.5), Vector2(w * 0.5, -h * 0.5),
		Vector2(w * 0.5, h * 0.5), Vector2(-w * 0.5, h * 0.5),
	])
	for i in pts.size():
		pts[i] = xf * pts[i]
	draw_colored_polygon(pts, Color(fill.r, fill.g, fill.b, fa))
	if kind == "fence" or kind == "barrier":
		draw_polyline(pts, Color(fill.r, fill.g, fill.b, sa), 0.8, true)
	else:
		draw_polyline(pts, Color(fill.r, fill.g, fill.b, sa), 1.2, true)

func _color_for_kind(kind: String) -> Color:
	match kind:
		"crate", "crate_stack":
			return Color(0.55, 0.4, 0.22, 1.0)
		"lamp":
			return Color(0.95, 0.85, 0.45, 1.0)
		"fence", "barrier":
			return Color(0.45, 0.4, 0.35, 1.0)
		"bench", "table":
			return Color(0.5, 0.32, 0.18, 1.0)
		"stall":
			return Color(0.77, 0.52, 0.23, 1.0)
		"monument":
			return Color(0.7, 0.48, 0.28, 1.0)
		"tank":
			return Color(0.4, 0.63, 0.66, 1.0)
	return Color(0.6, 0.55, 0.45, 1.0)

func set_visible_props(on: bool) -> void:
	visible_props = on
	queue_redraw()
