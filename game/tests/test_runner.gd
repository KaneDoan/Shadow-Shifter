extends SceneTree

var assertions := 0
var failures := 0
var suite := "all"

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--suite="):
			suite = argument.trim_prefix("--suite=")
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", description)

func _run() -> void:
	if suite in ["rules", "all"]:
		_test_rules()
	if suite in ["shadow", "all"]:
		await _test_shadow()
	print("TEST RESULT: ", assertions - failures, "/", assertions, " passed; failures=", failures)
	quit(0 if failures == 0 else 1)

func _test_rules() -> void:
	if not FileAccess.file_exists("res://core/rules.gd"):
		check(false, "Rules module exists: shift boundaries, cone geometry and safe emergence are not implemented")
		return
	var rules = load("res://core/rules.gd")
	check(rules.can_shift(Vector2.ZERO, Vector2(96, 0), true, false), "96 px boundary is reachable")
	check(not rules.can_shift(Vector2.ZERO, Vector2(96.01, 0), true, false), "outside range rejected")
	check(not rules.can_shift(Vector2.ZERO, Vector2(20, 0), false, false), "inactive shadow rejected")
	check(not rules.can_shift(Vector2.ZERO, Vector2(20, 0), true, true), "occluded shadow rejected")
	check(rules.can_shift(Vector2(200, 50), Vector2(290, 50), true, false), "range uses current source position")
	check(rules.in_cone(Vector2.ZERO, Vector2.RIGHT, Vector2(100, 0), 160.0, 75.0), "forward target visible")
	check(not rules.in_cone(Vector2.ZERO, Vector2.RIGHT, Vector2(-20, 0), 160.0, 75.0), "behind target invisible")
	check(not rules.in_cone(Vector2.ZERO, Vector2.RIGHT, Vector2(161, 0), 160.0, 75.0), "vision range enforced")
	check(not rules.in_cone(Vector2.ZERO, Vector2.RIGHT, Vector2(50, 100), 160.0, 75.0), "outside cone rejected")
	var points = rules.emergence_candidates(Vector2(100, 50))
	check(points.size() == 9, "emergence tries center plus eight samples")
	check(points[0] == Vector2(100, 50), "center tried first")
	var unique: Dictionary = {}
	for index in range(1, points.size()):
		check(is_equal_approx(points[index].distance_to(Vector2(100, 50)), 24.0), "emergence ring radius 24")
		unique[points[index].round()] = true
	check(unique.size() == 8, "emergence ring points are unique")

func make_wall(at: Vector2, size: Vector2) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.position = at
	wall.collision_layer = 1
	wall.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	shape.shape = rectangle
	wall.add_child(shape)
	return wall

func settle() -> void:
	await physics_frame
	await physics_frame

func _test_shadow() -> void:
	for path in ["res://actors/player.gd", "res://world/shadow_anchor.gd", "res://systems/shadow_system.gd", "res://world/door.gd"]:
		if not FileAccess.file_exists(path):
			check(false, "Shadow physics module exists: " + path)
			return
	var stage := Node2D.new()
	root.add_child(stage)
	var system = load("res://systems/shadow_system.gd").new()
	stage.add_child(system)
	var player = load("res://actors/player.gd").new()
	player.position = Vector2(100, 100)
	player.input_enabled = false
	player.shadow_system = system
	system.player = player
	stage.add_child(player)
	var anchor = load("res://world/shadow_anchor.gd").new()
	anchor.position = Vector2(190, 100)
	stage.add_child(anchor)
	system.register_anchor(anchor)
	var wall := make_wall(Vector2(150, 100), Vector2(16, 80))
	stage.add_child(wall)
	await settle()
	check(not player.request_shift(anchor), "wall blocks otherwise reachable shift")
	wall.queue_free()
	await settle()
	anchor.set_active(false)
	check(not player.request_shift(anchor), "inactive anchor cannot be entered")
	anchor.set_active(true)
	check(player.request_shift(anchor), "clear active anchor accepts player")
	check(player.is_hidden(), "successful shift hides player")
	check(player.collision_layer == 0, "hidden player has no targetable collision layer")
	check(player.emerge(), "clear emergence succeeds")
	check(not player.is_hidden(), "emergence restores physical state")
	player.finish_emerge(Vector2(100, 100))
	var door = load("res://world/door.gd").new()
	door.position = Vector2(150, 100)
	stage.add_child(door)
	await settle()
	check(not player.request_shift(anchor), "closed door blocks shift")
	door.open_for(2.0)
	await settle()
	check(player.request_shift(anchor), "open door permits shift")
	player.finish_emerge(door.position)
	door.remaining = 0.0
	await settle()
	check(door.is_open, "occupied doorway does not close on actor")
	player.finish_emerge(Vector2(100, 100))
	await settle()
	check(not door.is_open, "door closes after occupied doorway clears")
	door.queue_free()
	await settle()
	var owner := Node2D.new()
	owner.position = Vector2(170, 100)
	stage.add_child(owner)
	var moving = load("res://world/shadow_anchor.gd").new()
	moving.owner_actor = owner
	owner.add_child(moving)
	system.register_anchor(moving)
	check(player.request_shift(moving), "moving anchor can be ridden")
	owner.position += Vector2(30, 10)
	await settle()
	check(player.global_position.is_equal_approx(moving.global_position), "rider follows moving owner")
	player.finish_emerge(Vector2(100, 100))
	player.attack_buffer = 0.12
	player.handle_primary(true, anchor.global_position)
	check(player.is_hidden(), "shift-click chooses shift over sword")
	check(player.attack_buffer == 0.0, "shift clears buffered sword input")
	var obstruction := make_wall(anchor.global_position, Vector2(80, 80))
	stage.add_child(obstruction)
	await settle()
	check(not player.emerge(), "fully blocked emergence is refused")
	check(player.is_hidden(), "blocked emergence keeps player safe and hidden")
	obstruction.queue_free()
	await settle()
	var center_block := make_wall(anchor.global_position, Vector2(10, 10))
	stage.add_child(center_block)
	await settle()
	check(player.emerge(), "emergence searches ring when center is blocked")
	check(player.global_position.distance_to(anchor.global_position) >= 23.9, "safe ring location used")
	player.attach_anchor(anchor)
	anchor.set_active(false)
	player._physics_process(0.25)
	check(player.is_hidden(), "invalidated occupied anchor warns before ejecting")
	player._physics_process(0.8)
	check(not player.is_hidden(), "fading occupied anchor safely ejects after warning")
	check(system.position_clear(player, player.global_position), "forced ejection chooses a clear position")
	stage.queue_free()
	await settle()
