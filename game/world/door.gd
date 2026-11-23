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
	var box := Rect2(-size * 0.5, size)
	if is_open:
		draw_rect(Rect2(box.position, Vector2(4, size.y)), Color("6c6886"))
		return
	draw_rect(box, Color("272c40"))
	draw_rect(box.grow(-2), Color("51465d"), false, 2.0)
	for y in range(int(-size.y * 0.5) + 4, int(size.y * 0.5), 8):
		draw_line(Vector2(-size.x * 0.5 + 2, y), Vector2(size.x * 0.5 - 2, y), Color("84707c"), 1.0)
	draw_circle(Vector2(0, 0), 2, Color("e3bd68") if locked else Color("a9b3bd"))
