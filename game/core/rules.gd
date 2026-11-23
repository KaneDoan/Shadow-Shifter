extends RefCounted

static func can_shift(source: Vector2, target: Vector2, active: bool, blocked: bool, reach: float = 96.0) -> bool:
	return active and not blocked and source.distance_squared_to(target) <= reach * reach

static func in_cone(origin: Vector2, forward: Vector2, point: Vector2, reach: float, angle: float) -> bool:
	var offset := point - origin
	if offset.length_squared() > reach * reach:
		return false
	if offset.length_squared() < 0.0001:
		return true
	return forward.normalized().dot(offset.normalized()) >= cos(deg_to_rad(angle * 0.5)) - 0.00001

static func emergence_candidates(origin: Vector2, radius: float = 24.0) -> Array[Vector2]:
	var points: Array[Vector2] = [origin]
	for index in range(8):
		points.append(origin + Vector2.from_angle(TAU * float(index) / 8.0) * radius)
	return points
