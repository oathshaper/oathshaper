extends RefCounted
## One fit for the supplied mesh, its simple collision, and its map drawing.
## Measurements below use the original 9.2-scale import's metre coordinates.
const ENLARGEMENT := 1.7
const ALIGNMENT_DEGREES := 4.5
const SOURCE_MOUTH := Vector3(32.4, 0.2, -1.78)
const MOUTH := Vector3(32.0, 0.2, -2.0)
const REGION := Rect2i(38, -14, 24, 20)
const CAUSEWAY := Rect2i(30, -4, 8, 4)
const TERRACE := Rect2(36.4, -7.2, 13.0, 10.4)
const PATHS := [Rect2(36.4, -3.1, 12.8, 2.6), Rect2(41.3, -7.0, 2.2, 10.0)]
const BEDS := [
	["WestNorthBed", 39.0, -5.3, 3.1, 2.7],
	["WestSouthBed", 39.0, 1.2, 3.1, 2.7],
	["EastNorthBed", 44.7, -5.3, 3.1, 2.7],
	["EastSouthBed", 44.7, 1.2, 3.1, 2.7],
]


static func fit() -> Transform3D:
	var basis := Basis(Vector3.UP, deg_to_rad(ALIGNMENT_DEGREES)).scaled(Vector3.ONE * ENLARGEMENT)
	return Transform3D(basis, MOUTH - basis * SOURCE_MOUTH)


static func point(at: Vector3) -> Vector3:
	return fit() * at


static func polygon(area: Rect2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for corner in [area.position, Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y)]:
		var world := point(Vector3(corner.x, 0.0, corner.y))
		result.append(Vector2(world.x, world.z))
	return result
