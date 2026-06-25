# projection.gd — Formule de projection Core3 -> Godot 2D
# =========================================================
# Axe M2.3 : mapping coordonnées monde SWG -> écran Godot 2D
#
# Core3 (SWG) :
#   X = Est    (+x = droite)
#   Y = Haut   (+y = vers le ciel)
#   Z = Nord   (+z = loin, vers le haut de la carte)
#
# Godot 2D :
#   X = droite (+x = droite)
#   Y = bas    (+y = vers le bas de l'écran)  ← INVERSÉ par rapport à SWG Z
#
# Formule (plan.md M2.3) :
#   Screen.x       = Core3.x   * SCALE
#   Screen.y       = Core3.z   * SCALE   (Z SWG = profondeur = Y Godot)
#   sprite_offset_y = -Core3.y * SCALE   (hauteur = offset vertical du sprite)
class_name Projection3D2D

# 1 unité Core3 = SCALE pixels à l'écran.
# Tatooine fait ~8192 x 8192 unités → avec 0.5, ~4096px × 4096px
const SCALE: float = 0.5

## Convertit une position 3D Core3 en position 2D écran Godot.
static func to_screen(core3_pos: Vector3) -> Vector2:
return Vector2(core3_pos.x * SCALE, core3_pos.z * SCALE)

## Hauteur Core3 Y -> offset vertical du sprite (simulation saut/nage).
## Un personnage en l'air monte visuellement sur l'écran (offset négatif).
static func height_offset(core3_y: float) -> float:
return -core3_y * SCALE

## Retourne {position: Vector2, offset_y: float} pour une position Core3 complète.
static func project(core3_pos: Vector3) -> Dictionary:
return {
"position": to_screen(core3_pos),
"offset_y": height_offset(core3_pos.y),
}

## Inverse : position 2D écran -> coordonnées Core3 (Y=0 supposé).
static func from_screen(screen_pos: Vector2) -> Vector3:
return Vector3(
screen_pos.x / SCALE,
0.0,
screen_pos.y / SCALE,
)
