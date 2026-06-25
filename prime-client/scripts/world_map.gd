# world_map.gd — Fond de carte minimap SWG  (Ctrl+M toggle)
extends Node2D
class_name WorldMap

const HALF_SIZE_DEFAULT: float = 8192.0
const MINIMAP_DIR:       String = "res://assets/maps/"
const MAP_IMAGE_SIZE:    int    = 1024

@export var planet_name: String = "tatooine"
@export var half_size:   float  = HALF_SIZE_DEFAULT
@export var show_grid:   bool   = true

var _visible_map: bool  = true
var _has_texture: bool  = false
var _grid_color:  Color = Color(0.15, 0.15, 0.25, 0.6)

@onready var _sprite: Sprite2D = $MapSprite

func _ready() -> void:
	_load_map_texture()
	_apply_scale()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_M and event.ctrl_pressed:
			_visible_map = not _visible_map
			visible      = _visible_map
			get_viewport().set_input_as_handled()

func _load_map_texture() -> void:
	var candidates: Array[String] = [
		MINIMAP_DIR + planet_name + ".png",
		MINIMAP_DIR + planet_name + ".jpg",
		MINIMAP_DIR + "planet_" + planet_name + ".png",
	]
	for path: String in candidates:
		if ResourceLoader.exists(path):
			# load() retourne Variant — cast explicite vers Texture2D
			var tex: Texture2D = load(path) as Texture2D
			if tex:
				_sprite.texture = tex
				_has_texture    = true
				return
	print("[WorldMap] Pas d'image pour '%s' — grille vectorielle" % planet_name)
	if _sprite:
		_sprite.visible = false
	queue_redraw()

func _apply_scale() -> void:
	if not _has_texture or _sprite == null:
		return
	var world_size_px: float = 2.0 * half_size * Projection3D2D.SCALE
	var s: float             = world_size_px / float(MAP_IMAGE_SIZE)
	_sprite.scale    = Vector2(s, s)
	_sprite.position = Vector2.ZERO

func _draw() -> void:
	if _has_texture or not show_grid:
		return
	var world_px:   float = half_size * Projection3D2D.SCALE
	var grid_step:  float = 512.0 * Projection3D2D.SCALE
	var grid_count: int   = int(half_size / 512.0)
	draw_rect(Rect2(-world_px, -world_px, world_px * 2.0, world_px * 2.0),
			Color(0.05, 0.06, 0.1, 0.7))
	for i in range(-grid_count, grid_count + 1):
		var px := i * grid_step
		draw_line(Vector2(-world_px, px), Vector2(world_px, px),  _grid_color, 0.5)
		draw_line(Vector2(px, -world_px), Vector2(px, world_px),  _grid_color, 0.5)
	draw_line(Vector2(-world_px, 0.0), Vector2(world_px, 0.0), Color(0.3, 0.3, 0.6, 0.8), 1.5)
	draw_line(Vector2(0.0, -world_px), Vector2(0.0, world_px), Color(0.3, 0.3, 0.6, 0.8), 1.5)
	draw_rect(Rect2(-world_px, -world_px, world_px * 2.0, world_px * 2.0),
			Color(0.4, 0.4, 0.7, 0.5), false, 1.5)

func set_planet(name: String, new_half_size: float = HALF_SIZE_DEFAULT) -> void:
	planet_name  = name
	half_size    = new_half_size
	_has_texture = false
	if _sprite:
		_sprite.texture = null
		_sprite.visible = true
	_load_map_texture()
	_apply_scale()
	queue_redraw()
