extends CharacterBody2D

signal shifted(from_pos: Vector2, to_pos: Vector2)
signal emerged
signal died(source)
signal attack_started

enum State { PHYSICAL, SHADOW, RIDING, DEAD }
var state := State.PHYSICAL
var input_enabled := true
var shadow_system
var mission
var current_anchor
var visual
var aim_direction := Vector2.RIGHT
var last_safe_position := Vector2.ZERO
var attack_buffer := 0.0
var attack_phase := 0.0
var has_gate_key := false
var eject_timer := -1.0

func _ready() -> void:
	add_to_group("player")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 2
	collision_mask = 1
	var collider := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	collider.shape = circle
	add_child(collider)
	visual = preload("res://actors/actor_visual.gd").new()
	add_child(visual)
	last_safe_position = global_position

func is_hidden() -> bool:
	return state == State.SHADOW or state == State.RIDING

func is_alive() -> bool:
	return state != State.DEAD

func request_shift(anchor: Node) -> bool:
	if state == State.DEAD or not is_instance_valid(shadow_system):
		return false
	return shadow_system.try_shift(self, anchor)

func attach_anchor(anchor: Node) -> void:
	var from_pos := global_position
	current_anchor = anchor
	state = State.RIDING if is_instance_valid(anchor.owner_actor) else State.SHADOW
	global_position = anchor.global_position
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	attack_buffer = 0.0
	attack_phase = 0.0
	eject_timer = -1.0
	visual.visible = false
	shifted.emit(from_pos, global_position)

func emerge() -> bool:
	if not is_hidden() or not is_instance_valid(shadow_system):
		return false
	return shadow_system.try_emerge(self)

func finish_emerge(at: Vector2) -> void:
	global_position = at
	last_safe_position = at
	current_anchor = null
	state = State.PHYSICAL
	velocity = Vector2.ZERO
	collision_layer = 2
	collision_mask = 1
	eject_timer = -1.0
	visual.visible = true
	emerged.emit()

func request_attack() -> bool:
	if state != State.PHYSICAL:
		return false
	attack_buffer = 0.12
	return true

func handle_primary(shift_held: bool, target: Vector2) -> void:
	if shift_held:
		attack_buffer = 0.0
		var anchor = shadow_system.anchor_at(target)
		if is_instance_valid(anchor):
			request_shift(anchor)
		else:
			shadow_system.show_feedback("SELECT A SHADOW")
	else:
		request_attack()

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or state == State.DEAD:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		handle_primary(Input.is_physical_key_pressed(KEY_SHIFT), get_global_mouse_position())
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_SPACE:
			request_attack()
		elif event.physical_keycode == KEY_E:
			if is_hidden():
				emerge()
			elif is_instance_valid(mission):
				mission.try_interact(self)
			else:
				for door in get_tree().get_nodes_in_group("doors"):
					if door.try_interact(self):
						break
		elif event.physical_keycode == KEY_R:
			get_tree().reload_current_scene()

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if is_hidden():
		if is_instance_valid(current_anchor):
			global_position = current_anchor.global_position
			if not current_anchor.active and eject_timer < 0.0:
				eject_timer = 1.0
				shadow_system.show_feedback("SHADOW FADING — SHIFT OR EMERGE")
		else:
			eject_timer = 0.0
		if eject_timer >= 0.0:
			eject_timer -= delta
			if eject_timer <= 0.0:
				if not shadow_system.try_emerge(self, true):
					eject_timer = 0.2
		return
	var movement := Vector2.ZERO
	if input_enabled:
		movement.x = float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
		movement.y = float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
		var mouse_offset := get_global_mouse_position() - global_position
		if mouse_offset.length_squared() > 4.0:
			aim_direction = mouse_offset.normalized()
	var target_velocity := movement.normalized() * 140.0
	velocity = velocity.move_toward(target_velocity, (1200.0 if movement != Vector2.ZERO else 1800.0) * delta)
	move_and_slide()
	last_safe_position = global_position
	visual.facing = aim_direction
	visual.moving = velocity.length_squared() > 4.0
