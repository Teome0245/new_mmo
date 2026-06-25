# world_map.gd — Fond de carte minimap SWG dans Godot 2D
# ========================================================
# M3.3 : Charge l'image minimap SWG (TGA/PNG) comme Sprite2D de fond.
#         Scalée pour que les coordonnées Core3 se superposent directement
#         aux entités de l'EntityManager.
#
# Activation : Ctrl+M (toggle) — identique au raccourci SWG in-game.
#
# Les images minimap SWG sont dans le client à :
#   <SWG>/snapshot/<planet>.ws        (positions bâtiments — parsées par ws_parser.py)
#   <SWG>/terrain/<planet>.trn        (bounds de la carte — halfSize)
#   Minimap PNG/TGA extraites depuis les .tre :
#     ui/map/planet_tatooine.png      (ou .tga selon version)
#
# Si l'image n'est pas disponible, un fond grille vectoriel est dessiné.
extends Node2D
class_name WorldMap

# Demi-taille du monde en unités Core3 (même pour toutes les planètes SWG standard)
const HALF_SIZE_DEFAULT: float = 8192.0

# Chemin vers le dossier contenant les images minimap extraites
const MINIMAP_DIR: String = "res://assets/maps/"

# Taille en pixels de l'image minimap (généralement 512 ou 1024 pour SWG)
const MAP_IMAGE_SIZE: int = 1024

@export var planet_name: String = "tatooine"
@export var half_size:   float  = HALF_SIZE_DEFAULT
@export var show_grid:   bool   = true    # grille de debug si pas d'image

var _visible_map: bool = true
var _has_texture: bool = false
var _grid_color:  Color = Color(0.15, 0.15, 0.25, 0.6)

@onready var _sprite: Sprite2D = $MapSprite

func _ready() -> void:
_load_map_texture()
_apply_scale()

func _unhandled_input(event: InputEvent) -> void:
# Ctrl+M : toggle minimap (comme dans SWG)
if event is InputEventKey and event.pressed:
if event.keycode == KEY_M and event.ctrl_pressed:
_visible_map = not _visible_map
visible = _visible_map
get_viewport().set_input_as_handled()

# ---------------------------------------------------------------------------
# Chargement de la texture minimap
# ---------------------------------------------------------------------------
func _load_map_texture() -> void:
var candidates := [
MINIMAP_DIR + planet_name + ".png",
MINIMAP_DIR + planet_name + ".jpg",
MINIMAP_DIR + "planet_" + planet_name + ".png",
MINIMAP_DIR + "planet_" + planet_name + ".tga",
]
for path in candidates:
if ResourceLoader.exists(path):
var tex := load(path) as Texture2D
if tex:
_sprite.texture = tex
_has_texture    = true
print("[WorldMap] Minimap chargée : " + path)
return

# Fallback : grille vectorielle
print("[WorldMap] Pas d'image pour '%s' — affichage grille vectorielle" % planet_name)
_sprite.visible = false
queue_redraw()

func _apply_scale() -> void:
if not _has_texture:
return
# On veut que l'image couvre exactement [-half_size..+half_size] en Core3
# Avec Projection3D2D.SCALE, ça donne [-half_size*SCALE..+half_size*SCALE] en pixels
var world_size_px := 2.0 * half_size * Projection3D2D.SCALE
var img_size      := float(MAP_IMAGE_SIZE)
var s             := world_size_px / img_size
_sprite.scale   = Vector2(s, s)
# Centrer l'image : le point (0,0) de la carte Core3 = centre de l'image
_sprite.position = Vector2.ZERO

# ---------------------------------------------------------------------------
# Fallback : grille vectorielle (si pas d'image)
# ---------------------------------------------------------------------------
func _draw() -> void:
if _has_texture or not show_grid:
return

var world_px   := half_size * Projection3D2D.SCALE
var grid_step  := 512.0 * Projection3D2D.SCALE  # une ligne tous les 512 Core3 units
var grid_count := int(half_size / 512.0)

# Fond sombre
draw_rect(Rect2(-world_px, -world_px, world_px * 2.0, world_px * 2.0),
  Color(0.05, 0.06, 0.1, 0.7))

# Lignes de grille
for i in range(-grid_count, grid_count + 1):
var px := i * grid_step
draw_line(Vector2(-world_px, px),  Vector2(world_px, px),  _grid_color, 0.5)
draw_line(Vector2(px, -world_px),  Vector2(px, world_px),  _grid_color, 0.5)

# Axes principaux (plus épais)
draw_line(Vector2(-world_px, 0.0), Vector2(world_px, 0.0),
  Color(0.3, 0.3, 0.6, 0.8), 1.5)
draw_line(Vector2(0.0, -world_px), Vector2(0.0, world_px),
  Color(0.3, 0.3, 0.6, 0.8), 1.5)

# Bordure
draw_rect(Rect2(-world_px, -world_px, world_px * 2.0, world_px * 2.0),
  Color(0.4, 0.4, 0.7, 0.5), false, 1.5)

# ---------------------------------------------------------------------------
# API publique
# ---------------------------------------------------------------------------

## Change de planète (zone change réseau → M3 bridge).
func set_planet(name: String, new_half_size: float = HALF_SIZE_DEFAULT) -> void:
planet_name = name
half_size   = new_half_size
_has_texture = false
if _sprite:
_sprite.texture = null
_sprite.visible = true
_load_map_texture()
_apply_scale()
queue_redraw()
