# entity_manager.gd — Gestionnaire d'entites monde SWG
extends Node2D
class_name EntityManager

const ENTITY_SCENE := "res://scenes/entity.tscn"

var _entities: Dictionary = {}
var _entity_packed: PackedScene = null

func _ready() -> void:
	# load() retourne Variant — cast explicite PackedScene
	_entity_packed = load(ENTITY_SCENE) as PackedScene
	if _entity_packed == null:
		push_error("EntityManager: impossible de charger " + ENTITY_SCENE)

func spawn(object_id: int, core3_pos: Vector3,
		color: Color = Entity.COLOR_NPC,
		label: String = "",
		kind: String = "object") -> Entity:
	if _entities.has(object_id):
		return _entities[object_id]
	if _entity_packed == null:
		return null
	var entity: Entity = _entity_packed.instantiate()
	entity.object_id = object_id
	add_child(entity)
	entity.set_display_jitter(_jitter_for_oid(object_id))
	entity.set_core3_position(core3_pos)
	entity.set_color(color)
	var tex := SpriteRegistry.resolve_texture(kind, label)
	var tint := SpriteRegistry.resolve_tint(kind, label)
	if tex:
		entity.set_sprite_texture(tex, tint)
	if label != "":
		entity.set_label(label)
	_entities[object_id] = entity
	return entity

static func _jitter_for_oid(oid: int) -> Vector2:
	# Écarte légèrement les entités au même point (hub LH)
	var angle := float(oid % 360) * (PI / 180.0)
	var ring := float(oid % 4)
	var radius := 14.0 + ring * 8.0
	return Vector2(cos(angle), sin(angle)) * radius

func move(object_id: int, core3_pos: Vector3) -> void:
	if not _entities.has(object_id):
		spawn(object_id, core3_pos, Entity.COLOR_OBJECT, "")
		return
	_entities[object_id].set_core3_position(core3_pos)

func despawn(object_id: int) -> void:
	if _entities.has(object_id):
		_entities[object_id].queue_free()
		_entities.erase(object_id)

func clear() -> void:
	for entity in _entities.values():
		entity.queue_free()
	_entities.clear()

func get_entity(object_id: int) -> Entity:
	return _entities.get(object_id, null)

func count() -> int:
	return _entities.size()

func get_all_entities() -> Array:
	return _entities.values()
