# projection.gd — Projection Core3 -> Godot 2D
# Core3: X=Est, Z=Nord (+Z)  →  Godot2D: X=droite, Y=bas (nord = haut écran = Y négatif)
class_name Projection3D2D

const SCALE: float = 0.5   # 1 unite Core3 = 0.5 pixel

# ~2 m au sol ; même repère que size_m des bâtiments (mètres Core3).
const ENTITY_HEIGHT_M: float = 2.0
const ENTITY_READABILITY: float = 12.0

static func entity_token_px() -> float:
	return ENTITY_HEIGHT_M * SCALE * ENTITY_READABILITY

# Tatooine outdoor : Y monde ~ -4800 ; intérieurs : Y local (petites valeurs).
const TATOOINE_FLOOR_Y: float = -4800.0
const OUTDOOR_Y_THRESHOLD: float = -1000.0

# Remap feeds où le nord est dans `y` et la hauteur dans `z`
# (snapshots ia_bridge / zone_feed). Core3 correct : X est, Y hauteur, Z nord.
const AXIS_SWAP_Z_MAX: float = 50.0
const AXIS_SWAP_Y_MIN: float = 100.0

static func to_screen(core3_pos: Vector3) -> Vector2:
	return Vector2(core3_pos.x * SCALE, -core3_pos.z * SCALE)

static func needs_yz_swap(pos: Vector3) -> bool:
	return absf(pos.z) < AXIS_SWAP_Z_MAX and absf(pos.y) > AXIS_SWAP_Y_MIN

static func normalize_core3_pos(pos: Vector3) -> Vector3:
	if needs_yz_swap(pos):
		return Vector3(pos.x, pos.z, pos.y)
	return pos

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
