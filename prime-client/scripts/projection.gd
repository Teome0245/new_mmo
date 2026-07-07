# projection.gd — Projection Core3 -> Godot 2D
# Core3: X=Est, Z=Nord (+Z)  →  Godot2D: X=droite, Y=bas (nord = haut écran = Y négatif)
class_name Projection3D2D

const SCALE: float = 0.5   # 1 unite Core3 = 0.5 pixel

# Tatooine outdoor : Y monde ~ -4800 ; intérieurs : Y local (petites valeurs).
const TATOOINE_FLOOR_Y: float = -4800.0
const OUTDOOR_Y_THRESHOLD: float = -1000.0

static func to_screen(core3_pos: Vector3) -> Vector2:
	return Vector2(core3_pos.x * SCALE, -core3_pos.z * SCALE)

static func height_offset(core3_y: float) -> float:
	var local_y := core3_y
	if core3_y < OUTDOOR_Y_THRESHOLD:
		local_y = core3_y - TATOOINE_FLOOR_Y
	return clampf(-local_y * SCALE, -64.0, 64.0)

static func project(core3_pos: Vector3) -> Dictionary:
	return {
		"position": to_screen(core3_pos),
		"offset_y": height_offset(core3_pos.y),
	}

static func from_screen(screen_pos: Vector2) -> Vector3:
	return Vector3(
		screen_pos.x / SCALE,
		0.0,
		-screen_pos.y / SCALE,
	)
