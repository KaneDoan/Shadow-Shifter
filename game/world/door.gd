extends StaticBody2D

var door_id := "gate"
var size := Vector2(20, 64)
var is_open := false
var locked := false
var remaining := 0.0
var collider: CollisionShape2D

func _ready() -> void:
	add_to_group("doors")
	collision_layer = 1
	collision_mask = 0
	collider = CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	collider.shape = rectangle
	add_child(collider)
	queue_redraw()

func open_for(seconds: float) -> void:
	is_open = true
	remaining = maxf(remaining, seconds)
	if is_instance_valid(collider):
		collider.set_deferred("disabled", true)
	queue_redraw()

func try_interact(actor: Node) -> bool:
	if global_position.distance_to(actor.global_position) > 48.0:
		return false
	if locked and not actor.has_gate_key:
		return false
	if actor.has_gate_key:
		locked = false
	open_for(2.0)
	return true

func occupied() -> bool:
	# Actor transforms update before the physics broadphase in this frame.
	# Check live positions too, so a just-entered doorway cannot close on them.
	for actor in get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("enemies"):
		if actor is CollisionObject2D and (actor.collision_layer & 6) != 0:
			if Rect2(-size * 0.5, size).grow(7.0).has_point(to_local(actor.global_position)):
				return true
	var rectangle := RectangleShape2D.new()
	rectangle.size = size + Vector2(10, 10)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = rectangle
	query.transform = global_transform
	query.collision_mask = 6
	return not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()

func _physics_process(delta: float) -> void:
	if not is_open:
		return
	remaining = maxf(0.0, remaining - delta)
	if remaining <= 0.0 and not occupied():
		is_open = false
		collider.set_deferred("disabled", false)
		queue_redraw()

func _draw() -> void:
	# Doors stand in vertical doorways; drawn by hand in the manor palette.
	var half := size.y * 0.5
	if door_id == "gate":
		_draw_gate(half)
	else:
		_draw_study_door(half)
	if locked and not is_open:
		draw_rect(Rect2(-4, -3, 8, 7), Color("2a2230"))
		draw_rect(Rect2(-3, -2, 6, 5), Color("e3bd68"))
		draw_arc(Vector2(0, -3), 2.5, PI, TAU, 6, Color("e3bd68"), 1.5)

func _draw_gate(half: float) -> void:
	var iron := Color("2c3346")
	var shine := Color("8ea0c4")
	if is_open:
		# Two leaves swung into the gallery, hinged on the posts.
		for y in [-half + 3.0, half - 3.0]:
			draw_line(Vector2(0, y), Vector2(22, y), iron, 3)
			for x in range(4, 22, 6):
				draw_line(Vector2(x, y - 9), Vector2(x, y), iron, 2)
				draw_line(Vector2(x, y - 9), Vector2(x, y - 7), shine, 1)
	else:
		draw_line(Vector2(0, -half), Vector2(0, half), iron, 3)
		for y in range(int(-half) + 4, int(half), 6):
			draw_line(Vector2(-1, y - 10), Vector2(-1, y), iron, 2)
			draw_line(Vector2(-1, y - 10), Vector2(-1, y - 8), shine, 1)
	for y in [-half, half]:
		draw_rect(Rect2(-4, y - 4, 8, 8), Color("5d6378"))
		draw_rect(Rect2(-3, y - 6, 6, 3), Color("b9a785"))

func _draw_study_door(half: float) -> void:
	var wood := Color("5a3426")
	var dark := Color("3a2019")
	var brass := Color("c8a46a")
	if is_open:
		for y in [-half, half - 7.0]:
			draw_rect(Rect2(0, y, 28, 7), wood)
			draw_rect(Rect2(0, y, 28, 7), dark, false, 1)
			draw_rect(Rect2(24, y + 2, 2, 3), brass)
	else:
		draw_rect(Rect2(-4, -half, 8, size.y), wood)
		draw_rect(Rect2(-4, -half, 8, size.y), dark, false, 1)
		draw_line(Vector2(0, -half), Vector2(0, half), dark, 1)
		draw_rect(Rect2(1, -4, 2, 3), brass)
		draw_rect(Rect2(-3, 1, 2, 3), brass)
	draw_rect(Rect2(-5, -half - 2, 10, 3), brass)
	draw_rect(Rect2(-5, half - 1, 10, 3), brass)
