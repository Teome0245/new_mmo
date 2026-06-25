# projection.gd — Projection Core3 -> Godot 2D
# Core3: X=Est, Y=Haut, Z=Nord  →  Godot2D: X=droite, Y=bas
class_name Projection3D2D

const SCALE: float = 0.5   # 1 unite Core3 = 0.5 pixel

static func to_screen(core3_pos: Vector3) -> Vector2:
	return Vector2(core3_pos.x * SCALE, core3_pos.z * SCALE)

static func height_offset(core3_y: float) -> float:
	return -core3_y * SCALE

static func project(core3_pos: Vector3) -> Dictionary:
	return {
		"position": to_screen(core3_pos),
		"offset_y": height_offset(core3_pos.y),
	}

static func from_screen(screen_pos: Vector2) -> Vector3:
	return Vector3(
		screen_pos.x / SCALE,
		0.0,
		screen_pos.y / SCALE,
	)
