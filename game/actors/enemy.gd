extends CharacterBody2D

signal died(enemy, source)
const Rules = preload("res://core/rules.gd")
enum Mode { PATROL, ENGAGE, INVESTIGATE, ALERT, DEAD }

var enemy_id := "guard"
var display_name := "Guard"
var attack_style := "blade"
var visual_role := "guard"
var ai_enabled := true
var is_boss := false
var escape_override := false
var mode := Mode.PATROL
var shadow_system
var shadow_anchor
var visual
var player
var mission
var facing := Vector2.DOWN
var patrol_points: Array[Vector2] = []
var patrol_waits: Array[float] = []
var patrol_faces: Array[Vector2] = []
var patrol_index := 0
var patrol_speed := 48.0
var wait_timer := 0.0
var suspicion := 0.0
var last_seen := Vector2.ZERO
var investigate_time := 0.0
var attack_elapsed := -1.0
var attack_direction := Vector2.RIGHT
var attack_fired := false
var cone_points := PackedVector2Array()
var body_discovered := false

func _ready() -> void:
	add_to_group("enemies")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 4
	collision_mask = 1
	var collider := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	collider.shape = circle
	add_child(collider)
	visual = preload("res://actors/actor_visual.gd").new()
	visual.role = visual_role
	visual.accent = Color("e8bb70") if not is_boss else Color("f7b3d8")
	add_child(visual)
	shadow_anchor = preload("res://world/shadow_anchor.gd").new()
	shadow_anchor.owner_actor = self
	shadow_anchor.anchor_id = enemy_id + "_shadow"
	shadow_anchor.position = Vector2(0, 9)
	add_child(shadow_anchor)
	if is_instance_valid(shadow_system):
		shadow_system.register_anchor(shadow_anchor)

func is_alive() -> bool:
	return mode != Mode.DEAD

func take_hit(source: Node) -> bool:
	if not is_alive():
		return false
	mode = Mode.DEAD
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2.ZERO
	attack_elapsed = -1.0
	visual.dead = true
	visual.attacking = false
	shadow_anchor.set_active(false)
	died.emit(self, source)
	queue_redraw()
	return true

func can_see(point: Vector2) -> bool:
	if not Rules.in_cone(global_position, facing, point, 160.0, 75.0):
		return false
	return get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(global_position, point, 1)).is_empty()

func _physics_process(delta: float) -> void:
	if not is_alive() or not ai_enabled:
		return
	_update_cone()
	var sees_player: bool = is_instance_valid(player) and player.is_alive() and not player.is_hidden() and can_see(player.global_position)
	if sees_player:
		last_seen = player.global_position
		suspicion = minf(1.0, suspicion + delta / 0.3)
		if suspicion >= 1.0:
			mode = Mode.ENGAGE
			if is_instance_valid(mission):
				mission.confirm_detection(self)
	else:
		suspicion = maxf(0.0, suspicion - delta / 0.15)
		if mode == Mode.ENGAGE and attack_elapsed < 0.0:
			mode = Mode.INVESTIGATE
			investigate_time = 3.0
	if escape_override:
		visual.facing = facing
		visual.moving = true
		queue_redraw()
		return
	if attack_elapsed >= 0.0:
		_tick_attack(delta)
	elif mode == Mode.ENGAGE and sees_player:
		var offset: Vector2 = player.global_position - global_position
		facing = offset.normalized()
		var desired_range := 140.0 if attack_style == "shot" else (64.0 if attack_style == "thrust" else 48.0)
		if offset.length() <= desired_range:
			attack_elapsed = 0.0
			attack_direction = facing
			attack_fired = false
			velocity = Vector2.ZERO
		else:
			velocity = facing * 82.0
			move_and_slide()
	elif mode == Mode.INVESTIGATE:
		investigate_time -= delta
		var offset := last_seen - global_position
		if offset.length() > 5.0 and can_see(last_seen):
			facing = offset.normalized()
			velocity = facing * 60.0
			move_and_slide()
		else:
			velocity = Vector2.ZERO
		if investigate_time <= 0.0:
			mode = Mode.ALERT
	else:
		_tick_patrol(delta)
	if is_instance_valid(mission):
		mission.request_guard_door(self)
	visual.facing = facing
	visual.moving = velocity.length_squared() > 4.0
	visual.attacking = attack_elapsed >= 0.0
	queue_redraw()

func _tick_patrol(delta: float) -> void:
	velocity = Vector2.ZERO
	if wait_timer > 0.0:
		wait_timer -= delta
		return
	if patrol_points.is_empty():
		return
	var target := patrol_points[patrol_index]
	var offset := target - global_position
	if offset.length() <= maxf(2.0, patrol_speed * delta):
		global_position = target
		wait_timer = patrol_waits[patrol_index] if patrol_index < patrol_waits.size() else 0.4
		if patrol_index < patrol_faces.size() and patrol_faces[patrol_index] != Vector2.ZERO:
			facing = patrol_faces[patrol_index]
		patrol_index = (patrol_index + 1) % patrol_points.size()
	else:
		facing = offset.normalized()
		velocity = facing * patrol_speed
		move_and_slide()

func _tick_attack(delta: float) -> void:
	attack_elapsed += delta
	var windup := 0.65 if attack_style == "shot" else (0.6 if attack_style == "thrust" else 0.45)
	velocity = Vector2.ZERO
	if attack_elapsed >= windup and attack_elapsed < windup + 0.12:
		if attack_style == "shot":
			if not attack_fired:
				var projectile = preload("res://actors/projectile.gd").new()
				projectile.direction = attack_direction
				projectile.source = self
				get_parent().add_child(projectile)
				projectile.global_position = global_position + attack_direction * 14.0
				attack_fired = true
		else:
			velocity = attack_direction * 120.0
			move_and_slide()
			var reach := 52.0 if attack_style == "thrust" else 36.0
			var angle := 40.0 if attack_style == "thrust" else 90.0
			if is_instance_valid(player) and player.is_alive() and not player.is_hidden():
				if Rules.in_cone(global_position, attack_direction, player.global_position, reach, angle) and _clear_attack_line(player.global_position):
					player.take_hit(self)
	if attack_elapsed >= windup + 0.7:
		attack_elapsed = -1.0

func _clear_attack_line(point: Vector2) -> bool:
	return get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(global_position, point, 1)).is_empty()

func _update_cone() -> void:
	cone_points = PackedVector2Array([Vector2.ZERO])
	for index in range(17):
		var angle := facing.angle() + deg_to_rad(-37.5 + 75.0 * float(index) / 16.0)
		var endpoint := global_position + Vector2.from_angle(angle) * 160.0
		var hit := get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(global_position, endpoint, 1))
		if not hit.is_empty():
			endpoint = hit["position"]
		cone_points.append(to_local(endpoint))

func _draw() -> void:
	if not is_alive():
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.55))
		draw_circle(Vector2(0, 5), 9, Color(0.3, 0.05, 0.1, 0.65))
		draw_set_transform(Vector2.ZERO)
		return
	if cone_points.size() >= 3:
		var color := Color(0.9, 0.59, 0.2, 0.07 + suspicion * 0.11)
		if mode == Mode.ENGAGE:
			color = Color(1.0, 0.24, 0.2, 0.17)
		draw_colored_polygon(cone_points, color)
		draw_polyline(cone_points, Color(color.r, color.g, color.b, 0.3), 0.7)
	if suspicion > 0.01:
		draw_rect(Rect2(-10, -31, 20, 2), Color("292638"))
		draw_rect(Rect2(-10, -31, 20 * suspicion, 2), Color("ffb065"))
	if attack_elapsed >= 0.0:
		var windup := 0.65 if attack_style == "shot" else (0.6 if attack_style == "thrust" else 0.45)
		var color := Color("ff654f") if attack_elapsed >= windup else Color("f2b95b")
		var length := 145.0 if attack_style == "shot" else (52.0 if attack_style == "thrust" else 36.0)
		draw_line(attack_direction * 12.0, attack_direction * length, Color(color.r, color.g, color.b, 0.75), 1.5)
		draw_arc(Vector2.ZERO, 11.0, 0, TAU * minf(1.0, attack_elapsed / windup), 20, color, 1.0)
