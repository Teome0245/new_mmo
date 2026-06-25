# entity_manager.gd — Gestionnaire d'entités du monde SWG
# =========================================================
# Instancie, met à jour et détruit les entités visuelles (cercles 2D)
# à partir des données réseau SOE/Core3 parsées par le bridge.
#
# Architecture M2/M3 :
#   NetworkBridge (UDP local) -> EntityManager -> Entity (Node2D)
extends Node2D
class_name EntityManager

const ENTITY_SCENE := "res://scenes/entity.tscn"

# Dictionnaire object_id (int) -> Entity (Node2D)
var _entities: Dictionary = {}

# Référence à la scène Entity préchargée (initialisée dans _ready)
var _entity_packed: PackedScene = null

func _ready() -> void:
_entity_packed = load(ENTITY_SCENE)
if _entity_packed == null:
push_error("EntityManager: impossible de charger " + ENTITY_SCENE)

# ---------------------------------------------------------------------------
# API publique — appelée par NetworkBridge ou les scripts de test
# ---------------------------------------------------------------------------

## Crée une entité (si elle n'existe pas encore) et la positionne.
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

## Met à jour la position Core3 d'une entité existante (Delta / DataTransform).
func move(object_id: int, core3_pos: Vector3) -> void:
if not _entities.has(object_id):
spawn(object_id, core3_pos)
return
_entities[object_id].set_core3_position(core3_pos)

## Supprime une entité (déconnexion ou destruction Core3).
func despawn(object_id: int) -> void:
if _entities.has(object_id):
_entities[object_id].queue_free()
_entities.erase(object_id)

## Supprime toutes les entités (reset de zone).
func clear() -> void:
for entity in _entities.values():
entity.queue_free()
_entities.clear()

## Retourne l'entité par object_id, ou null.
func get_entity(object_id: int) -> Entity:
return _entities.get(object_id, null)

## Retourne le nombre d'entités actuellement trackées.
func count() -> int:
return _entities.size()
