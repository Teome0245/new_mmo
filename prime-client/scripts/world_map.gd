# world_map.gd — Fond carte Tatooine calibrée (M4) + grille fallback
extends Node2D
class_name WorldMap

const HALF_SIZE_DEFAULT: float = 6500.0
const CONFIG_PATH: String = "res://assets/maps/tatooine_map_config.json"
const MINIMAP_DIR: String = "res://assets/maps/"
const _BackdropScript: GDScript = preload("res://scripts/planet_backdrop.gd")

@export var planet_name: String = "tatooine"
@export var half_size: float = HALF_SIZE_DEFAULT
@export var show_grid: bool = false
@export var flip_texture_y: bool = false

var _visible_map: bool = true
var _has_texture: bool = false
var _grid_color: Color = Color(0.15, 0.15, 0.25, 0.6)

@onready var _sprite: Sprite2D = $MapSprite
@onready var _poi_layer: PoiLayer = $PoiLayer
@onready var _zone_layers: ZoneLayers = $ZoneLayers
@onready var _ws_layer: WsObjectsLayer = $WsObjectsLayer
@onready var _hub_buildings: HubBuildingsLayer = $HubBuildingsLayer
@onready var _hub_ground: HubGroundLayer = $HubGroundLayer
@onready var _hub_props: HubPropsLayer = $HubPropsLayer

var _backdrop: Node2D = null

func _ready() -> void:
	_load_map_config()
	_setup_backdrop()
	_load_map_texture()
	_apply_scale()
	_apply_world_render()

func _setup_backdrop() -> void:
	if not MapTextureLoader.use_procedural_backdrop():
		return
	_backdrop = get_node_or_null("PlanetBackdrop") as Node2D
	if _backdrop == null:
		if _BackdropScript == null or not _BackdropScript.can_instantiate():
			push_warning("[WorldMap] planet_backdrop.gd illisible — fond procédural désactivé")
			return
		_backdrop = _BackdropScript.new() as Node2D
		_backdrop.name = "PlanetBackdrop"
		_backdrop.z_index = -12
		add_child(_backdrop)
		move_child(_backdrop, 0)
	_backdrop.half_size = half_size
	_backdrop.draw_enabled = true

func _apply_world_render() -> void:
	var city := MapTextureLoader.position_map_city()
	var retail := get_node_or_null("RetailLayoutLayer") as RetailLayoutLayer
	if retail and city != "":
		retail.set_city(city)
		retail.set_visible_layout(true)
	if _hub_buildings and city != "":
		_hub_buildings.visible_buildings = false
		_hub_buildings.show_labels = false
	if _sprite:
		var show_tex := MapTextureLoader.show_planet_texture()
		if not show_tex:
			_sprite.visible = false
		elif _has_texture:
			_sprite.modulate = Color(1, 1, 1, 0.35)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_M and event.ctrl_pressed:
			_visible_map = not _visible_map
			visible = _visible_map
			get_viewport().set_input_as_handled()
		if event.keycode == KEY_P and event.ctrl_pressed and _poi_layer:
			if event.shift_pressed:
				_poi_layer.toggle_detail_pois()
			else:
				_poi_layer.set_visible_pois(not _poi_layer.visible_pois)
		if event.keycode == KEY_W and event.ctrl_pressed and _zone_layers:
			_zone_layers.toggle_water()
		if event.keycode == KEY_C and event.ctrl_pressed and _zone_layers:
			_zone_layers.toggle_collision()
		if event.keycode == KEY_B and event.ctrl_pressed and _ws_layer:
			_ws_layer.set_visible_objects(not _ws_layer.visible_objects)
		if event.keycode == KEY_H and event.ctrl_pressed and _hub_buildings:
			_hub_buildings.set_visible_buildings(not _hub_buildings.visible_buildings)
			var on := _hub_buildings.visible_buildings
			if _hub_ground:
				_hub_ground.set_visible_ground(on)
			if _hub_props:
				_hub_props.set_visible_props(on)
		if event.keycode == KEY_R and event.ctrl_pressed and event.shift_pressed:
			var retail := get_node_or_null("RetailLayoutLayer") as RetailLayoutLayer
			if retail:
				retail.set_visible_layout(not retail.visible_layout)
				get_viewport().set_input_as_handled()

func _load_map_config() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		return
	var f := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	var raw: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not raw is Dictionary:
		return
	var cfg: Dictionary = raw
	half_size = float(cfg.get("half_size", half_size))
	flip_texture_y = bool(cfg.get("flip_texture_y", flip_texture_y))
	planet_name = str(cfg.get("planet", planet_name))

func _load_map_texture() -> void:
	var tex: Texture2D = MapTextureLoader.load_texture("world")
	if tex:
		_sprite.texture = tex
		_sprite.centered = true
		_has_texture = true
		print("[WorldMap] texture %s" % MapTextureLoader.resolve_path("world"))
		return
	print("[WorldMap] Pas d'image — grille. Lance: python3 tools/map_export/export_tatooine_for_godot.py")
	if _sprite:
		_sprite.visible = false
	show_grid = true
	queue_redraw()

func _texture_core3_rect(cfg: Dictionary) -> Rect2:
	## Emprise Core3 (x, z) couverte par la texture ; défaut = planète entière.
	var b: Variant = cfg.get("texture_core3_bounds", null)
	if b is Dictionary:
		var d: Dictionary = b
		var min_x := float(d.get("min_x", d.get("minX", -half_size)))
		var max_x := float(d.get("max_x", d.get("maxX", half_size)))
		var min_z := float(d.get("min_z", d.get("minZ", -half_size)))
		var max_z := float(d.get("max_z", d.get("maxZ", half_size)))
		return Rect2(min_x, min_z, max_x - min_x, max_z - min_z)
	return Rect2(-half_size, -half_size, 2.0 * half_size, 2.0 * half_size)


func _apply_scale() -> void:
	if not _has_texture or _sprite == null:
		return
	var tex_size: Vector2 = _sprite.texture.get_size()
	if tex_size.x <= 0.0:
		return
	var cfg := MapTextureLoader.load_config()
	var core3_rect := _texture_core3_rect(cfg)
	var span_x: float = core3_rect.size.x * Projection3D2D.SCALE
	var span_z: float = core3_rect.size.y * Projection3D2D.SCALE
	var sx: float = span_x / tex_size.x
	var sz: float = span_z / tex_size.y if tex_size.y > 0.0 else sx
	var sy: float = -sz if flip_texture_y else sz
	_sprite.scale = Vector2(sx, sy)
	var cx: float = core3_rect.position.x + core3_rect.size.x * 0.5
	var cz: float = core3_rect.position.y + core3_rect.size.y * 0.5
	_sprite.position = Vector2.ZERO if MapTextureLoader.use_procedural_backdrop() else Projection3D2D.to_screen(Vector3(cx, 0.0, cz))
	_sprite.centered = true
	print(
		"[WorldMap] texture span Core3 (%.0f,%.0f)-(%.0f,%.0f) px %.0fx%.0f scale=%.4f"
		% [
			core3_rect.position.x,
			core3_rect.position.y,
			core3_rect.position.x + core3_rect.size.x,
			core3_rect.position.y + core3_rect.size.y,
			span_x,
			span_z,
			sx,
		]
	)

func _draw() -> void:
	if _has_texture or not show_grid:
		return
	var world_px: float = half_size * Projection3D2D.SCALE
	var grid_step: float = 512.0 * Projection3D2D.SCALE
	var grid_count: int = int(half_size / 512.0)
	draw_rect(Rect2(-world_px, -world_px, world_px * 2.0, world_px * 2.0),
			Color(0.05, 0.06, 0.1, 0.7))
	for i in range(-grid_count, grid_count + 1):
		var px := i * grid_step
		draw_line(Vector2(-world_px, px), Vector2(world_px, px), _grid_color, 0.5)
		draw_line(Vector2(px, -world_px), Vector2(px, world_px), _grid_color, 0.5)
	draw_line(Vector2(-world_px, 0.0), Vector2(world_px, 0.0), Color(0.3, 0.3, 0.6, 0.8), 1.5)
	draw_line(Vector2(0.0, -world_px), Vector2(0.0, world_px), Color(0.3, 0.3, 0.6, 0.8), 1.5)

func set_planet(name: String, new_half_size: float = HALF_SIZE_DEFAULT) -> void:
	planet_name = name
	half_size = new_half_size
	_has_texture = false
	if _sprite:
		_sprite.texture = null
		_sprite.visible = true
	_load_map_config()
	_load_map_texture()
	_apply_scale()
	queue_redraw()
