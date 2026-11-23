extends Node

signal impact(at: Vector2, direction: Vector2, target)
const Rules = preload("res://core/rules.gd")

func line_clear(from_pos: Vector2, to_pos: Vector2) -> bool:
	var world: World2D = get_viewport().world_2d
	return world.direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(from_pos, to_pos, 1)).is_empty()

func resolve_swing(source: Node, origin: Vector2, direction: Vector2, reach: float, arc: float, hit_ids: Dictionary) -> int:
	var kills := 0
	for target in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(target) or not target.is_alive():
			continue
		var id: int = target.get_instance_id()
		if hit_ids.has(id):
			continue
		if not Rules.in_cone(origin, direction, target.global_position, reach, arc):
			continue
		if not line_clear(origin, target.global_position):
			continue
		hit_ids[id] = true
		if target.take_hit(source):
			kills += 1
			impact.emit(target.global_position, direction, target)
	return kills
