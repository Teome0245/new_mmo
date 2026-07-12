# entity.gd — Entité 2D : sprite IA (top-down) ou cercle fallback + label
extends Node2D
class_name Entity

var object_id:     int     = 0
var core3_pos:     Vector3 = Vector3.ZERO
var color:         Color   = Color.RED
var radius:        float   = 8.0
var label_text:    String  = ""
var height_offset: float   = 0.0

var _use_sprite: bool = false
var _pending_texture: Texture2D = null
var _display_jitter: Vector2 = Vector2.ZERO

const COLOR_PLAYER_OFFICIAL := Color(0.2, 0.4, 1.0, 1.0)
const COLOR_PLAYER_BOT      := Color(0.0, 0.9, 0.4, 1.0)
const COLOR_NPC             := Color(1.0, 0.5, 0.1, 1.0)
const COLOR_OBJECT          := Color(0.7, 0.7, 0.7, 0.8)

func set_core3_position(pos: Vector3) -> void:
	core3_pos     = pos
	position      = Projection3D2D.to_screen(pos) + _display_jitter
	height_offset = Projection3D2D.height_offset(pos.y)
	_update_sprite_offset()
	queue_redraw()

func set_display_jitter(offset: Vector2) -> void:
	_display_jitter = offset
	set_core3_position(core3_pos)

func set_color(c: Color) -> void:
	color = c
	queue_redraw()

func set_label(text: String) -> void:
	label_text = text
	queue_redraw()

func set_sprite_texture(tex: Texture2D, tint: Color = Color.WHITE) -> void:
	if not is_inside_tree():
		_pending_texture = tex
		return
	_apply_sprite_texture(tex, tint)

func _ready() -> void:
	if _pending_texture:
		_apply_sprite_texture(_pending_texture, Color.WHITE)
		_pending_texture = null

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
	var token_r := SpriteRegistry.display_px() * 0.42 if _use_sprite else radius

	if _use_sprite:
		# Socle type jeton WC3 — cohérence visuelle
		draw_colored_polygon(
			_ellipse_points(draw_pos + Vector2(0, token_r * 0.35), token_r * 1.1, token_r * 0.38, 20),
			Color(0, 0, 0, 0.28)
		)
		draw_arc(draw_pos, token_r, 0.0, TAU, 32, color.lightened(0.15), 1.2, true)
	else:
		draw_circle(draw_pos + Vector2(1.5, 1.5), radius, Color(0, 0, 0, 0.35))
		draw_circle(draw_pos, radius, color)
		draw_arc(draw_pos, radius, 0.0, TAU, 24, color.lightened(0.4), 1.5)
	if abs(height_offset) > 1.0 and abs(height_offset) <= 48.0:
		draw_line(
			Vector2(0.0, 0.0),
			draw_pos,
			Color(color.r, color.g, color.b, 0.45),
			1.0
		)
	if label_text != "":
		var label_y := -radius - 4.0
		if _use_sprite:
			label_y = -SpriteRegistry.display_px() * 0.55
		draw_string(
			ThemeDB.fallback_font,
			draw_pos + Vector2(-label_text.length() * 3.0, label_y),
			label_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			10,
			Color.WHITE
		)


func _ellipse_points(center: Vector2, rx: float, ry: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(segments):
		var a := (float(i) / float(segments)) * TAU
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts
