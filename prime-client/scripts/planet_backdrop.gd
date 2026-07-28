# planet_backdrop.gd — Fond Scrapaltai Prime (desert + vallons), repere Core3 +-half_size
extends Node2D
class_name PlanetBackdrop

## Meme echelle que Projection3D2D.SCALE (evite erreur parse si global class pas encore charge).
const CORE3_TO_PX: float = 0.5

@export var half_size: float = 6500.0
@export var draw_enabled: bool = true

const _SEED := 0x7A4F00

func _draw() -> void:
	if not draw_enabled:
		return
	var px := half_size * CORE3_TO_PX
	var rect := Rect2(-px, -px, px * 2.0, px * 2.0)
	# Base sable chaud
	draw_rect(rect, Color(0.20, 0.14, 0.09, 1.0))
	_draw_radial_warmth(rect)
	_draw_canyons(rect)
	_draw_dune_bands(rect)
	_draw_grain(rect)

func _draw_radial_warmth(rect: Rect2) -> void:
	var c := rect.get_center()
	var rings := 6
	for i in range(rings):
		var t := float(i) / float(rings)
		var r := rect.size.x * (0.35 + t * 0.55)
		var a := 0.06 * (1.0 - t)
		draw_arc(c, r, 0.0, TAU, 48, Color(0.55, 0.38, 0.22, a), -1.0)

func _draw_canyons(rect: Rect2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _SEED
	var count := 42
	for i in range(count):
		rng.seed = _SEED + i * 7919
		var sx := rng.randf_range(rect.position.x, rect.end.x)
		var sy := rng.randf_range(rect.position.y, rect.end.y)
		var angle := rng.randf_range(-0.4, 0.4)
		var length := rng.randf_range(rect.size.x * 0.08, rect.size.x * 0.22)
		var dir := Vector2(cos(angle), sin(angle))
		var w := rng.randf_range(2.5, 7.0)
		var depth := rng.randf_range(0.35, 0.65)
		var col := Color(0.08, 0.05, 0.04, 0.25 + depth * 0.2)
		var pts := PackedVector2Array()
		var p := Vector2(sx, sy)
		pts.append(p)
		for _s in range(4):
			dir = dir.rotated(rng.randf_range(-0.35, 0.35))
			p += dir * (length / 4.0)
			pts.append(p)
		draw_polyline(pts, col, w, false)
		# paroi canyon (lumière)
		draw_polyline(pts, Color(0.42, 0.30, 0.18, 0.12), maxf(1.0, w * 0.35), false)

func _draw_dune_bands(rect: Rect2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _SEED ^ 0xDUNE
	for _i in range(18):
		var y := rng.randf_range(rect.position.y, rect.end.y)
		var x0 := rect.position.x
		var x1 := rect.end.x
		var wave := rng.randf_range(8.0, 22.0)
		var pts := PackedVector2Array()
		var steps := 24
		for s in range(steps + 1):
			var t := float(s) / float(steps)
			var x := lerpf(x0, x1, t)
			var off := sin(t * TAU * 2.0 + rng.randf() * 3.0) * wave
			pts.append(Vector2(x, y + off))
		draw_polyline(pts, Color(0.38, 0.26, 0.16, 0.14), 3.0, false)

func _draw_grain(rect: Rect2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99173
	var n := clampi(int(rect.get_area() / 2200.0), 120, 520)
	for _i in range(n):
		var p := Vector2(
			rng.randf_range(rect.position.x, rect.end.x),
			rng.randf_range(rect.position.y, rect.end.y)
		)
		var g := rng.randf_range(0.05, 0.14)
		draw_circle(p, rng.randf_range(0.4, 1.4), Color(g, g * 0.82, g * 0.55, 0.22))

func set_half_size(v: float) -> void:
	half_size = v
	queue_redraw()
