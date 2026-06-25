# entity.gd — Entite 2D (cercle colore + label + trait hauteur)
extends Node2D
class_name Entity

var object_id:     int     = 0
var core3_pos:     Vector3 = Vector3.ZERO
var color:         Color   = Color.RED
var radius:        float   = 8.0
var label_text:    String  = ""
var height_offset: float   = 0.0

const COLOR_PLAYER_OFFICIAL := Color(0.2, 0.4, 1.0, 1.0)
const COLOR_PLAYER_BOT      := Color(0.0, 0.9, 0.4, 1.0)
const COLOR_NPC             := Color(1.0, 0.5, 0.1, 1.0)
const COLOR_OBJECT          := Color(0.7, 0.7, 0.7, 0.8)

func set_core3_position(pos: Vector3) -> void:
	core3_pos     = pos
	position      = Projection3D2D.to_screen(pos)
	height_offset = Projection3D2D.height_offset(pos.y)
	queue_redraw()

func set_color(c: Color) -> void:
	color = c
	queue_redraw()

func set_label(text: String) -> void:
	label_text = text
	queue_redraw()

func _draw() -> void:
	var draw_pos := Vector2(0.0, height_offset)
	# Ombre
	draw_circle(draw_pos + Vector2(1.5, 1.5), radius, Color(0, 0, 0, 0.35))
	# Corps
	draw_circle(draw_pos, radius, color)
	# Contour
	draw_arc(draw_pos, radius, 0.0, TAU, 24, color.lightened(0.4), 1.5)
	# Trait hauteur si en l'air
	if abs(height_offset) > 1.0:
		draw_line(
			Vector2(0.0, 0.0),
			draw_pos,
			Color(color.r, color.g, color.b, 0.5),
			1.0
		)
	# Label
	if label_text != "":
		draw_string(
			ThemeDB.fallback_font,
			draw_pos + Vector2(-label_text.length() * 3.0, -radius - 4.0),
			label_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			10,
			Color.WHITE
		)
