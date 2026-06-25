# entity.gd — Entité 2D dans le visualiseur Prime Client
# =======================================================
# Représente un objet du monde SWG (joueur, NPC, objet).
# Visualisation : cercle coloré + label nom optionnel.
# La hauteur Core3 (Y) est simulée par un offset vertical du dessin.
extends Node2D
class_name Entity

# ---- Données Core3 ----
var object_id:     int     = 0
var core3_pos:     Vector3 = Vector3.ZERO

# ---- Rendu ----
var color:         Color   = Color.RED
var radius:        float   = 8.0
var label_text:    String  = ""
var height_offset: float   = 0.0   # calculé par EntityManager via Projection3D2D

# Couleurs prédéfinies par type d'entité
const COLOR_PLAYER_OFFICIAL := Color(0.2, 0.4, 1.0, 1.0)   # bleu — client SWG officiel
const COLOR_PLAYER_BOT      := Color(0.0, 0.9, 0.4, 1.0)   # vert — agent IA
const COLOR_NPC             := Color(1.0, 0.5, 0.1, 1.0)   # orange — NPC
const COLOR_OBJECT          := Color(0.7, 0.7, 0.7, 0.8)   # gris — objet inerte

## Met à jour la position Core3 et recalcule la projection.
func set_core3_position(pos: Vector3) -> void:
core3_pos     = pos
position      = Projection3D2D.to_screen(pos)
height_offset = Projection3D2D.height_offset(pos.y)
queue_redraw()

## Définit la couleur du cercle.
func set_color(c: Color) -> void:
color = c
queue_redraw()

## Définit le label affiché au-dessus du cercle.
func set_label(text: String) -> void:
label_text = text
queue_redraw()

func _draw() -> void:
# Cercle principal (avec offset hauteur)
var draw_pos := Vector2(0.0, height_offset)

# Ombre
draw_circle(draw_pos + Vector2(1.5, 1.5), radius, Color(0, 0, 0, 0.35))

# Corps
draw_circle(draw_pos, radius, color)

# Contour
var outline_color := color.lightened(0.4)
draw_arc(draw_pos, radius, 0.0, TAU, 24, outline_color, 1.5)

# Trait hauteur (si entité en l'air)
if abs(height_offset) > 1.0:
draw_line(
Vector2(0.0, 0.0),
draw_pos,
Color(color.r, color.g, color.b, 0.5),
1.0
)

# Label
if label_text != "":
var font_size := 10
var text_pos  := draw_pos + Vector2(-label_text.length() * 3, -radius - 4)
draw_string(
ThemeDB.fallback_font,
text_pos,
label_text,
HORIZONTAL_ALIGNMENT_LEFT,
-1,
font_size,
Color.WHITE
)
