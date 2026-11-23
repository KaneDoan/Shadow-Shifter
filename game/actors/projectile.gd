extends Node2D

var direction := Vector2.RIGHT
var speed := 260.0
var source
var lifetime := 3.0

func _ready() -> void:
	add_to_group("projectiles")
	z_index = 5

func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	var destination := global_position + direction * speed * delta
	var query := PhysicsRayQueryParameters2D.create(global_position, destination, 3)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var target = hit["collider"]
		if is_instance_valid(target) and target.has_method("take_hit"):
			target.take_hit(source)
		queue_free()
		return
	global_position = destination
	queue_redraw()

func _draw() -> void:
	draw_line(-direction * 9, Vector2.ZERO, Color("f6775c"), 3.0)
	draw_line(-direction * 5, direction * 2, Color("fff2be"), 1.0)
