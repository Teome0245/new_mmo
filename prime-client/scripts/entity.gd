# entity.gd — Entité 2D : sprite IA (top-down) ou cercle fallback + label
extends Node2D
class_name Entity

var object_id:     int     = 0
var entity_key:    String  = ""
var core3_pos:     Vector3 = Vector3.ZERO
var color:         Color   = Color.RED
var radius:        float   = 5.0
var label_text:    String  = ""
var _label_raw:     String  = ""
var height_offset: float   = 0.0
var kind:          String  = "object"

var _use_sprite: bool = false
var _pending_texture: Texture2D = null
var _display_jitter: Vector2 = Vector2.ZERO
var _idle_phase: float = 0.0
var _anchor: Dictionary = {}
var _visual_home: Vector3 = Vector3.ZERO
var _use_visual_override: bool = false
## Orientation affichée (tip du triangle) : 0 = nord écran (+Core3 Z).
var facing_angle: float = 0.0
var _selected: bool = false
var _last_patrol_offset: Vector3 = Vector3.ZERO

const COLOR_PLAYER_OFFICIAL := Color(0.2, 0.4, 1.0, 1.0)
const COLOR_PLAYER_BOT      := Color(0.0, 0.9, 0.4, 1.0)
const COLOR_NPC             := Color(1.0, 0.5, 0.1, 1.0)
const COLOR_OBJECT          := Color(0.7, 0.7, 0.7, 0.8)

static var show_nameplates: bool = false

func set_entity_key(key: String) -> void:
	entity_key = key
	_rebind_anchor()
	_refresh_appearance()

func set_core3_position(pos: Vector3) -> void:
	var prev := core3_pos
	core3_pos     = pos
	height_offset = Projection3D2D.height_offset(pos.y)
	if not _use_visual_override:
		_visual_home = Vector3(pos.x, pos.y, pos.z)
	update_facing_from_move(prev, pos)
	_refresh_screen_pos()
	_update_sprite_offset()
	queue_redraw()

func set_display_jitter(offset: Vector2) -> void:
	_display_jitter = offset
	_refresh_screen_pos()

func set_kind(k: String) -> void:
	kind = k
	set_process(_wants_ambient())

func set_color(c: Color) -> void:
	color = c
	queue_redraw()


func set_selected(selected: bool) -> void:
	_selected = selected
	queue_redraw()


func update_facing_from_move(from: Vector3, to: Vector3) -> void:
	var dx := to.x - from.x
	var dz := to.z - from.z
	if dx * dx + dz * dz < 0.0025:
		return
	# Core3 X est → écran X ; Core3 Z nord → écran -Y
	var screen_dir := Vector2(dx, -dz).normalized()
	facing_angle = screen_dir.angle() + PI * 0.5
	queue_redraw()


func set_facing_from_direction(dir: Vector3) -> void:
	if dir.length_squared() < 0.0001:
		return
	var screen_dir := Vector2(dir.x, -dir.z).normalized()
	facing_angle = screen_dir.angle() + PI * 0.5
	queue_redraw()

func set_label(text: String) -> void:
	_label_raw = text
	label_text = _short_label(text)
	_rebind_anchor()
	_refresh_appearance()
	queue_redraw()

func _refresh_appearance() -> void:
	if kind != "player" and kind != "npc":
		return
	var raw := _label_raw if _label_raw != "" else label_text
	var tex := SpriteRegistry.resolve_texture(kind, raw, entity_key)
	if tex:
		set_sprite_texture(tex, SpriteRegistry.resolve_tint(kind, raw))

static func _short_label(raw: String) -> String:
	var s := raw.strip_edges()
	# "Jax Moro · Fel'Rani (PNJ IA)" → "Jax Moro"
	for sep in [" (PNJ", " · ", " - "]:
		var i := s.find(sep)
		if i > 0:
			s = s.substr(0, i).strip_edges()
			break
	if s.length() > 18:
		s = s.substr(0, 16) + "…"
	return s

static func toggle_nameplates() -> void:
	show_nameplates = not show_nameplates

func set_sprite_texture(tex: Texture2D, tint: Color = Color.WHITE) -> void:
	if not is_inside_tree():
		_pending_texture = tex
		return
	_apply_sprite_texture(tex, tint)

func _ready() -> void:
	_idle_phase = float(object_id % 997) * 0.017
	_rebind_anchor()
	set_process(_wants_ambient())
	if _pending_texture:
		_apply_sprite_texture(_pending_texture, Color.WHITE)
		_pending_texture = null

func _rebind_anchor() -> void:
	_anchor.clear()
	_use_visual_override = false
	if kind != "npc":
		return
	if entity_key == "" and label_text == "":
		return
	_anchor = NpcAnchorResolver.resolve(entity_key, _label_raw if _label_raw != "" else label_text)
	if _anchor.is_empty():
		return
	_use_visual_override = bool(_anchor.get("apply_visual_override", false))
	_visual_home = Vector3(
		float(_anchor.get("_home_x", core3_pos.x)),
		core3_pos.y,
		float(_anchor.get("_home_z", core3_pos.z))
	)
	var seed_i: int = int(_anchor.get("_seed", object_id))
	_idle_phase = float(seed_i % 997) * 0.017
	set_process(true)

func _wants_ambient() -> bool:
	return kind == "npc" or kind == "player" or not _anchor.is_empty()

func _process(delta: float) -> void:
	if not _wants_ambient():
		return
	var prev_patrol := _patrol_offset_m()
	_idle_phase += delta
	_refresh_screen_pos()
	var cur_patrol := _patrol_offset_m()
	if kind == "npc":
		var vel := cur_patrol - prev_patrol
		if vel.length_squared() > 1.0e-8:
			set_facing_from_direction(Vector3(vel.x, 0.0, vel.z))
	_last_patrol_offset = cur_patrol
	_update_sprite_offset()
	queue_redraw()

func _refresh_screen_pos() -> void:
	var base := _visual_home if _use_visual_override else core3_pos
	var world := base + _patrol_offset_m()
	var bob_y := _bob_offset_px()
	position = Projection3D2D.to_screen(world) + _display_jitter + Vector2(0.0, bob_y)

func _bob_offset_px() -> float:
	if kind == "player":
		return 0.0
	if not _anchor.has("_bob") or not (_anchor["_bob"] is Dictionary):
		return 0.0
	var bob: Dictionary = _anchor["_bob"]
	if bob.get("enabled", false) != true:
		return 0.0
	var amp := float(bob.get("amplitude_px", 0.8))
	var period := maxf(float(bob.get("period_s", 2.4)), 0.2)
	return sin(_idle_phase * (TAU / period)) * amp

func _patrol_offset_m() -> Vector3:
	# Joueur humain contrôlé : pas de patrol
	if kind == "player" and entity_key == "player:human":
		return Vector3.ZERO
	var pat: Dictionary = {}
	if _anchor.has("_patrol") and (_anchor["_patrol"] is Dictionary):
		pat = _anchor["_patrol"]
	else:
		return Vector3.ZERO
	if pat.get("enabled", true) == false:
		return Vector3.ZERO
	var mode := str(pat.get("mode", "orbit"))
	var seed_i: int = int(_anchor.get("_seed", object_id)) if not _anchor.is_empty() else object_id
	var theta0 := float(seed_i % 360) * (PI / 180.0)
	if mode == "waypoints":
		var wps: Variant = pat.get("waypoints_relative", [])
		if not wps is Array or (wps as Array).is_empty():
			return Vector3.ZERO
		var arr: Array = wps
		var speed := float(pat.get("speed_m_s", 0.4))
		var pause := float(pat.get("pause_at_waypoint_s", 1.2))
		var seg_t := 3.0 / maxf(speed, 0.05) + pause
		var total := seg_t * float(arr.size())
		var t := fposmod(_idle_phase, total)
		var idx := int(t / seg_t) % arr.size()
		var local_t := t - float(idx) * seg_t
		var a: Dictionary = arr[idx] if arr[idx] is Dictionary else {}
		var b: Dictionary = arr[(idx + 1) % arr.size()] if arr[(idx + 1) % arr.size()] is Dictionary else a
		var blend := clampf(local_t / maxf(seg_t - pause, 0.01), 0.0, 1.0)
		var ax := float(a.get("x", 0.0))
		var az := float(a.get("z", 0.0))
		var bx := float(b.get("x", 0.0))
		var bz := float(b.get("z", 0.0))
		return Vector3(lerpf(ax, bx, blend), 0.0, lerpf(az, bz, blend))
	# orbit
	var radius_m := minf(float(pat.get("radius_m", 4.0)), 15.0)
	var speed := float(pat.get("speed_m_s", 0.55))
	var omega := speed / maxf(radius_m, 0.5)
	var theta := theta0 + _idle_phase * omega
	return Vector3(cos(theta) * radius_m, 0.0, sin(theta) * radius_m)

func _sprite_node() -> Sprite2D:
	return get_node_or_null("Sprite2D") as Sprite2D

func _apply_sprite_texture(tex: Texture2D, tint: Color = Color.WHITE) -> void:
	var sprite := _sprite_node()
	if sprite == null:
		_pending_texture = tex
		return
	if tex == null:
		_use_sprite = false
		sprite.texture = null
		sprite.visible = false
		queue_redraw()
		return
	if MapTextureLoader.entity_marker_style() == "triangle" and (kind == "player" or kind == "npc"):
		_use_sprite = false
		sprite.texture = null
		sprite.visible = false
		queue_redraw()
		return
	_use_sprite = true
	sprite.texture = tex
	sprite.modulate = tint
	sprite.visible = true
	var target := SpriteRegistry.display_px()
	var mul := SpriteRegistry.resolve_scale_multiplier(SpriteRegistry.last_sprite_key())
	var w := float(tex.get_width())
	var h := float(tex.get_height())
	var dim := maxf(w, h)
	if dim > 0.0:
		var s := (target / dim) * mul
		sprite.scale = Vector2(s, s)
	_update_sprite_offset()
	queue_redraw()

func _update_sprite_offset() -> void:
	var sprite := _sprite_node()
	if sprite:
		sprite.position.y = height_offset

func _draw() -> void:
	var draw_pos := Vector2(0.0, height_offset)
	var token_px := SpriteRegistry.display_px()
	var token_r := token_px * 0.38
	var tri_style := MapTextureLoader.entity_marker_style() == "triangle"

	if _use_sprite and not tri_style:
		draw_colored_polygon(
			_ellipse_points(draw_pos + Vector2(0, token_r * 0.55), token_r * 1.05, token_r * 0.32, 16),
			Color(0, 0, 0, 0.22)
		)
		if kind == "player":
			draw_arc(draw_pos, token_r * 1.05, 0.0, TAU, 32, color.lightened(0.2), 1.8, true)
	elif tri_style and (kind == "player" or kind == "npc"):
		_draw_marker_triangle(draw_pos, color, kind == "player")
		if _selected:
			draw_arc(draw_pos, 14.0, 0.0, TAU, 32, Color(1.0, 0.92, 0.35, 0.98), 2.5, true)
			draw_arc(draw_pos, 17.0, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.35), 1.0, true)
	elif kind == "player":
		draw_circle(draw_pos + Vector2(1, 1), radius, Color(0, 0, 0, 0.3))
		draw_circle(draw_pos, radius, color)
		draw_arc(draw_pos, radius, 0.0, TAU, 20, color.lightened(0.35), 1.2, true)
	elif kind == "npc":
		draw_circle(draw_pos + Vector2(0.5, 0.5), 3.5, Color(0, 0, 0, 0.25))
		draw_circle(draw_pos, 3.0, color.darkened(0.15))
	if abs(height_offset) > 1.0 and abs(height_offset) <= 48.0:
		draw_line(
			Vector2(0.0, 0.0),
			draw_pos,
			Color(color.r, color.g, color.b, 0.45),
			1.0
		)
	if show_nameplates and label_text != "":
		var label_y := -token_px * 0.52 if _use_sprite else -radius - 4.0
		var col := Color(1, 1, 1, 0.92) if kind == "player" else Color(0.95, 0.88, 0.75, 0.82)
		draw_string(
			ThemeDB.fallback_font,
			draw_pos + Vector2(-label_text.length() * 2.8, label_y),
			label_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			9,
			col
		)

func _draw_marker_triangle(center: Vector2, col: Color, is_player: bool) -> void:
	var tip := Vector2(0.0, -7.0)
	var p1 := Vector2(-5.0, 4.0)
	var p2 := Vector2(5.0, 4.0)
	tip = tip.rotated(facing_angle) + center
	p1 = p1.rotated(facing_angle) + center
	p2 = p2.rotated(facing_angle) + center
	var fill := col if is_player else Color(1.0, 1.0, 1.0, 0.92)
	draw_colored_polygon(PackedVector2Array([tip, p1, p2]), fill)
	draw_polyline(PackedVector2Array([tip, p1, p2, tip]), col.darkened(0.2), 1.2, true)

func _ellipse_points(center: Vector2, rx: float, ry: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(segments):
		var a := (float(i) / float(segments)) * TAU
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts

func is_interactable() -> bool:
	return kind == "npc"


func is_local_player(local_id: int) -> bool:
	return kind == "player" and object_id == local_id and object_id != 0

func screen_anchor() -> Vector2:
	# Centre visuel du marqueur (triangle / sprite), repère monde 2D + caméra.
	return to_global(Vector2(0.0, height_offset))


func hit_test_screen(mouse_pos: Vector2) -> bool:
	if not visible:
		return false
	if kind != "npc" and kind != "player":
		return false
	var tri := MapTextureLoader.entity_marker_style() == "triangle"
	var token_px := SpriteRegistry.display_px()
	var radius_px := maxf(28.0, token_px * 0.85) if tri else maxf(18.0, token_px * 0.55)
	return screen_anchor().distance_squared_to(mouse_pos) <= radius_px * radius_px
