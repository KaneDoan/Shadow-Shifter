extends Node2D

const Rules = preload("res://core/rules.gd")
var player
var anchors: Array[Node] = []
var reach := 96.0
var feedback := ""
var feedback_time := 0.0
var streak_from := Vector2.ZERO
var streak_to := Vector2.ZERO
var streak_time := 0.0

func register_anchor(anchor: Node) -> void:
	if not anchors.has(anchor):
		anchors.append(anchor)

func line_clear(from_pos: Vector2, to_pos: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from_pos, to_pos, 1)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func can_shift(actor: Node, anchor: Node) -> bool:
	if not is_instance_valid(anchor) or not is_instance_valid(actor):
		return false
	return Rules.can_shift(actor.global_position, anchor.global_position, anchor.active, not line_clear(actor.global_position, anchor.global_position), reach)

func try_shift(actor: Node, anchor: Node) -> bool:
	if not can_shift(actor, anchor):
		show_feedback("SHADOW UNREACHABLE")
		return false
	streak_from = actor.global_position
	streak_to = anchor.global_position
	streak_time = 0.15
	actor.attach_anchor(anchor)
	return true

func anchor_at(point: Vector2):
	var result = null
	var closest := 23.0
	for anchor in anchors:
		if not is_instance_valid(anchor):
			continue
		var distance: float = point.distance_to(anchor.global_position)
		if distance < closest:
			result = anchor
			closest = distance
	return result

func position_clear(actor: Node, point: Vector2) -> bool:
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, point)
	query.collision_mask = 5
	query.exclude = [actor.get_rid()]
	if is_instance_valid(actor.current_anchor):
		var owner = actor.current_anchor.owner_actor
		if owner is CollisionObject2D and owner.has_method("is_alive") and not owner.is_alive():
			query.exclude.append(owner.get_rid())
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()

func try_emerge(actor: Node, forced: bool = false) -> bool:
	var points := Rules.emergence_candidates(actor.global_position)
	if forced:
		for radius in [40.0, 56.0, 72.0, 96.0]:
			points.append_array(Rules.emergence_candidates(actor.global_position, radius))
		points.append(actor.last_safe_position)
	for point in points:
		if position_clear(actor, point):
			actor.finish_emerge(point)
			return true
	show_feedback("EMERGENCE BLOCKED")
	return false

func show_feedback(text: String) -> void:
	feedback = text
	feedback_time = 1.2

func _process(delta: float) -> void:
	feedback_time = maxf(0.0, feedback_time - delta)
	streak_time = maxf(0.0, streak_time - delta)
	if not is_instance_valid(player):
		return
	var showing := Input.is_physical_key_pressed(KEY_SHIFT)
	var hover = anchor_at(get_global_mouse_position()) if showing else null
	for anchor in anchors:
		if not is_instance_valid(anchor):
			continue
		anchor.outlines_visible = showing
		anchor.highlighted = showing and can_shift(player, anchor)
		anchor.hovered = anchor == hover and anchor.highlighted
		anchor.occupied = player.current_anchor == anchor
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(player):
		return
	if Input.is_physical_key_pressed(KEY_SHIFT):
		draw_arc(to_local(player.global_position), reach, 0.0, TAU, 80, Color(0.65, 0.45, 1.0, 0.38), 1.0)
		for anchor in anchors:
			if is_instance_valid(anchor) and anchor.highlighted:
				draw_line(to_local(player.global_position), to_local(anchor.global_position), Color(0.6, 0.4, 0.9, 0.24), 1.0)
	if streak_time > 0.0:
		var alpha := streak_time / 0.15
		draw_line(to_local(streak_from), to_local(streak_to), Color(0.6, 0.3, 1.0, alpha * 0.45), 8.0 * alpha)
		draw_line(to_local(streak_from), to_local(streak_to), Color(0.75, 1.0, 0.95, alpha), 2.0)
