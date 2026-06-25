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
		label: String = "") -> Entity:
	if _entities.has(object_id):
		return _entities[object_id]
	if _entity_packed == null:
		return null
	var entity: Entity = _entity_packed.instantiate()
	entity.object_id = object_id
	entity.set_core3_position(core3_pos)
	entity.set_color(color)
	if label != "":
		entity.set_label(label)
	add_child(entity)
	_entities[object_id] = entity
	return entity

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
