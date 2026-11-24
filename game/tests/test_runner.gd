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
	if suite in ["combat", "all"]:
		await _test_combat()
	if suite in ["mission", "all"]:
		_test_alarm()
		await _test_mission()
	if suite in ["presentation", "all"]:
		await _test_presentation()
	if suite in ["input", "all"]:
		await _test_input()
	if suite in ["navigation", "all"]:
		await _test_navigation()
	if suite in ["dialogue", "all"]:
		await _test_dialogue()
	if assertions == 0:
		check(false, "test suite executes at least one assertion")
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

func _test_dialogue() -> void:
	var mission = load("res://main.tscn").instantiate()
	mission.test_mode = true
	root.add_child(mission)
	current_scene = mission
	await settle()
	var bar = mission.ui.dialogue
	check(bar.intro.size() >= 1, "dialogue data provides intro cards")
	var speakers_ok := true
	for id in bar.lines:
		for line in bar.lines[id]:
			speakers_ok = speakers_ok and bar.speakers.has(String(line[0]))
	check(speakers_ok, "every dialogue speaker has a colour")
	bar.played.clear()
	bar.queue.clear()
	bar.current = []
	check(bar.play("gallery"), "conversation starts")
	check(not bar.play("gallery"), "conversation plays once per run")
	check(bar.is_speaking() and bar.queue.size() == bar.lines["gallery"].size() - 1, "lines queue in order")
	bar._process(30.0)
	check(int(bar.shown) == String(bar.current[1]).length(), "line types out fully")
	var first: Array = bar.current
	bar._process(30.0)
	check(bar.current != first, "line advances after its reading time")
	check(bar.play("alarm", true) and String(bar.current[1]) == String(bar.lines["alarm"][0][1]), "urgent conversation interrupts")
	# Intro cards: shown once per session, then the mission starts.
	mission.phase = "title"
	mission.ui.set_screen("title")
	mission.stats.seen_intro = false
	mission.test_mode = false
	mission.ui._start()
	check(mission.ui.screen_mode == "intro" and mission.phase == "title", "first start shows intro cards")
	for index in range(bar.intro.size()):
		mission.ui._advance_intro()
	check(mission.phase == "playing" and mission.ui.screen_mode == "playing", "intro cards lead into the mission")
	mission.phase = "title"
	mission.ui.set_screen("title")
	mission.ui._start()
	check(mission.ui.screen_mode == "playing", "intro does not repeat in the same session")
	mission.phase = "title"
	mission.ui.set_screen("title")
	mission.stats.seen_intro = false
	mission.ui._start()
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	mission.ui._input(escape)
	check(mission.phase == "playing", "Escape skips the intro")
	mission.test_mode = true
	mission.queue_free()
	current_scene = null
	await process_frame

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

func _test_combat() -> void:
	for path in ["res://systems/combat_system.gd", "res://actors/enemy.gd", "res://actors/projectile.gd"]:
		if not FileAccess.file_exists(path):
			check(false, "Combat module exists: " + path)
			return
	var stage := Node2D.new()
	root.add_child(stage)
	var shadows = load("res://systems/shadow_system.gd").new()
	stage.add_child(shadows)
	var combat = load("res://systems/combat_system.gd").new()
	stage.add_child(combat)
	var player = load("res://actors/player.gd").new()
	player.position = Vector2(100, 100)
	player.input_enabled = false
	player.shadow_system = shadows
	player.combat_system = combat
	shadows.player = player
	stage.add_child(player)
	var enemy_script = load("res://actors/enemy.gd")
	var front = enemy_script.new()
	front.position = Vector2(130, 100)
	front.ai_enabled = false
	front.shadow_system = shadows
	stage.add_child(front)
	var behind = enemy_script.new()
	behind.position = Vector2(75, 100)
	behind.ai_enabled = false
	stage.add_child(behind)
	var distant = enemy_script.new()
	distant.position = Vector2(160, 100)
	distant.ai_enabled = false
	stage.add_child(distant)
	await settle()
	var hit_ids: Dictionary = {}
	check(combat.resolve_swing(player, player.global_position, Vector2.RIGHT, 42.0, 110.0, hit_ids) == 1, "sword kills one target in forward arc")
	check(not front.is_alive(), "one sword hit kills enemy")
	check(behind.is_alive() and distant.is_alive(), "behind and out-of-range targets survive")
	check(combat.resolve_swing(player, player.global_position, Vector2.RIGHT, 42.0, 110.0, hit_ids) == 0, "active swing cannot hit the same target twice")
	var protected = enemy_script.new()
	protected.position = Vector2(130, 100)
	protected.ai_enabled = false
	stage.add_child(protected)
	var wall := make_wall(Vector2(116, 100), Vector2(8, 50))
	stage.add_child(wall)
	await settle()
	check(combat.resolve_swing(player, player.global_position, Vector2.RIGHT, 42.0, 110.0, {}) == 0, "wall blocks sword hit")
	check(protected.is_alive(), "enemy behind wall survives")
	wall.queue_free()
	await settle()
	player.aim_direction = Vector2.RIGHT
	player.request_attack()
	player._tick_attack(0.02)
	check(protected.is_alive(), "wind-up is not a damaging interval")
	player._tick_attack(0.04)
	check(not protected.is_alive(), "active interval resolves actual buffered sword")
	player.attach_anchor(front.shadow_anchor)
	check(not player.take_hit(behind), "hidden player ignores hit")
	check(player.is_alive(), "hidden hit is nonlethal")
	player.finish_emerge(Vector2(140, 200))
	var bullet_wall := make_wall(Vector2(115, 200), Vector2(8, 50))
	stage.add_child(bullet_wall)
	await settle()
	var projectile = load("res://actors/projectile.gd").new()
	projectile.position = Vector2(90, 200)
	projectile.direction = Vector2.RIGHT
	stage.add_child(projectile)
	projectile.set_physics_process(false)
	projectile._physics_process(0.25)
	check(player.is_alive(), "swept projectile hits wall before player")
	await settle()
	bullet_wall.queue_free()
	await settle()
	check(player.take_hit(behind), "physical player accepts a lethal hit")
	check(not player.is_alive(), "one enemy hit kills physical player")
	check(not player.take_hit(behind), "dead player cannot be killed or signaled twice")
	stage.queue_free()
	await settle()
	var ride_stage := Node2D.new()
	root.add_child(ride_stage)
	var ride_system = load("res://systems/shadow_system.gd").new()
	ride_stage.add_child(ride_system)
	var rider = load("res://actors/player.gd").new()
	rider.position = Vector2(100, 100)
	rider.input_enabled = false
	rider.shadow_system = ride_system
	ride_system.player = rider
	ride_stage.add_child(rider)
	var victim = enemy_script.new()
	victim.position = Vector2(140, 100)
	victim.ai_enabled = false
	victim.shadow_system = ride_system
	ride_stage.add_child(victim)
	await settle()
	check(rider.request_shift(victim.shadow_anchor), "living enemy can carry rider")
	check(rider.request_attack(), "riding attack performs assassination")
	check(not victim.is_alive() and not victim.shadow_anchor.active, "assassination kills owner and invalidates shadow")
	check(not rider.is_hidden(), "riding kill exposes player immediately")
	check(rider.global_position.distance_to(victim.global_position) < 16.1, "riding kill emerges at body")
	ride_stage.queue_free()
	await settle()
	var attack_stage := Node2D.new()
	root.add_child(attack_stage)
	var target_player = load("res://actors/player.gd").new()
	target_player.position = Vector2(130, 100)
	target_player.input_enabled = false
	attack_stage.add_child(target_player)
	var attacker = enemy_script.new()
	attacker.position = Vector2(100, 100)
	attacker.ai_enabled = false
	attacker.player = target_player
	attack_stage.add_child(attacker)
	await settle()
	check(target_player.is_alive(), "ordinary enemy contact and presence do not cause damage")
	attacker.attack_direction = Vector2.RIGHT
	attacker.attack_elapsed = 0.0
	attacker._tick_attack(0.25)
	check(target_player.is_alive(), "enemy wind-up is a safe reaction window")
	if attacker.has_method("attack_warning_polygon"):
		check(Geometry2D.is_point_in_polygon(Vector2.from_angle(deg_to_rad(30)) * 30.0, attacker.attack_warning_polygon()), "blade warning covers off-axis lethal area")
		attacker.attack_style = "thrust"
		check(Geometry2D.is_point_in_polygon(Vector2.from_angle(deg_to_rad(15)) * 45.0, attacker.attack_warning_polygon()), "thrust warning covers off-axis lethal area")
		attacker.attack_style = "blade"
		attacker.attack_elapsed = 0.58
		check(attacker.attack_warning_polygon().is_empty(), "recovery does not show a lethal warning")
		attacker.attack_elapsed = 0.25
	else:
		check(false, "melee warnings expose matching sector geometry and recovery phase")
	attacker._tick_attack(0.22)
	check(not target_player.is_alive(), "active enemy lunge is one-hit lethal")
	attack_stage.queue_free()
	await settle()
	var shot_stage := Node2D.new()
	root.add_child(shot_stage)
	var shot_target = load("res://actors/player.gd").new()
	shot_target.position = Vector2(140, 100)
	shot_target.input_enabled = false
	shot_stage.add_child(shot_target)
	await settle()
	var clear_shot = load("res://actors/projectile.gd").new()
	clear_shot.position = Vector2(90, 100)
	clear_shot.direction = Vector2.RIGHT
	shot_stage.add_child(clear_shot)
	clear_shot.set_physics_process(false)
	clear_shot._physics_process(0.25)
	check(not shot_target.is_alive(), "unobstructed swept projectile kills exposed player")
	shot_stage.queue_free()
	await settle()

func _test_alarm() -> void:
	if not FileAccess.file_exists("res://core/alarm_state.gd"):
		check(false, "Alarm model exists")
		return
	var alarm = load("res://core/alarm_state.gd").new()
	alarm.tick(30.0)
	check(not alarm.active and alarm.remaining == 0.0, "undiscovered body has no timer")
	check(alarm.discover_body(1), "first body discovery is unique")
	check(alarm.active and alarm.remaining == 90.0, "first body starts 90-second escape")
	alarm.tick(20.0)
	var prior_progress: float = alarm.progress
	check(not alarm.discover_body(1), "duplicate body discovery ignored")
	check(alarm.remaining == 70.0 and alarm.bodies_found == 1, "duplicate cannot cap or extend timer")
	alarm.discover_body(2)
	check(alarm.remaining == 45.0, "second body caps remaining at 45 seconds")
	check(alarm.progress == prior_progress, "timer cap does not move Veyr backward")
	alarm.tick(40.0)
	alarm.discover_body(3)
	check(alarm.remaining == 5.0, "later discovery cannot extend short timer")
	alarm.tick(10.0)
	check(alarm.remaining == 0.0 and is_equal_approx(alarm.progress, 1.0), "escape reaches exit at timer zero")
	alarm.reset()
	check(not alarm.active and alarm.remaining == 0.0 and alarm.bodies_found == 0 and alarm.progress == 0.0, "alarm reset clears all state")

func wait_for(condition: Callable, seconds: float = 40.0) -> bool:
	var budget := ceili(seconds * float(Engine.physics_ticks_per_second) / Engine.time_scale) + 4
	for frame in range(budget):
		if condition.call():
			return true
		await physics_frame
	return condition.call()

func _test_mission() -> void:
	if not FileAccess.file_exists("res://systems/mission.gd"):
		check(false, "Complete manor mission exists")
		return
	var packed = load("res://main.tscn")
	var mission = packed.instantiate()
	mission.test_mode = true
	root.add_child(mission)
	current_scene = mission
	await settle()
	Engine.time_scale = 8.0
	check(mission.enemies.size() == 11, "ten guards plus Lord Veyr exist")
	check(mission.player.is_hidden() and mission.player.current_anchor == mission.anchors["cart"], "mission starts safely hidden in the kitchen garden")
	check(not mission.anchors["curtain"].active and not mission.enemies["veyr"].shadow_anchor.active, "study shadows start inactive")
	var ghost_ok: bool = await complete_ghost_route(mission)
	check(ghost_ok and mission.phase == "won", "actual shadow-riding ghost route completes")
	check(mission.guards_killed == 0 and not mission.alarm.active, "ghost completion has no guard kills or alarm")
	check(mission.rank == "Ghost Assassin", "ghost result rank correct")
	var prior_restarts: int = mission.stats.restarts
	mission.request_restart()
	await settle()
	await settle()
	mission = current_scene
	check(is_instance_valid(mission) and mission.phase == "playing", "restart reloads actual mission scene")
	check(mission.stats.restarts == prior_restarts + 1, "restart counter survives reload")
	check(not mission.lights_off and not mission.alarm.active and mission.guards_killed == 0, "restart resets switch, alarm and kills")
	check(mission.player.is_hidden() and not mission.player.has_gate_key, "restart restores hidden spawn and clears key")
	check(not mission.doors["gate"].is_open and mission.doors["gate"].locked, "restart restores locked gate")
	var all_alive := true
	for enemy in mission.enemies.values():
		all_alive = all_alive and enemy.is_alive()
	check(all_alive, "restart restores all actors")
	var lethal_ok: bool = await complete_lethal_gate_route(mission)
	check(lethal_ok and mission.phase == "won", "lethal key route completes after killing gatekeeper")
	check(mission.guards_killed >= 1, "lethal route records guard death")
	mission.request_restart()
	await settle()
	await settle()
	mission = current_scene
	mission.enemies["watchman"].take_hit(mission.player)
	mission.enemies["bodyguard"].take_hit(mission.player)
	check(not mission.enemies["watchman"].shadow_anchor.active and not mission.enemies["bodyguard"].shadow_anchor.active, "dead route carriers lose moving anchors")
	mission.enemies["groundskeeper"].take_hit(mission.player)
	mission.enemies["steward"].take_hit(mission.player)
	check(mission.level.has_walk_route(Vector2(1104, 880), Vector2(96, 736)), "walkable fallback from garden to courtyard survives guard deaths")
	check(mission.level.has_walk_route(Vector2(96, 736), Vector2(592, 96)), "walkable fallback to lamp survives guard deaths")
	check(mission.level.has_walk_route(Vector2(592, 96), Vector2(1008, 304)), "walkable fallback to target survives guard deaths")
	check(not mission.doors["study"].locked, "study fallback remains physically openable")
	Engine.time_scale = 1.0
	mission.queue_free()
	current_scene = null
	await settle()

func shift_when_reachable(mission: Node, anchor: Node, seconds: float = 40.0) -> bool:
	var available: bool = await wait_for(func(): return mission.player.is_alive() and mission.shadow_system.can_shift(mission.player, anchor), seconds)
	if not available:
		printerr("SCENARIO: no route to ", anchor.anchor_id)
		return false
	return mission.player.request_shift(anchor)

func finish_from_statue(mission: Node) -> bool:
	var player = mission.player
	if not await shift_when_reachable(mission, mission.enemies["watchman"].shadow_anchor):
		return false
	if not await shift_when_reachable(mission, mission.anchors["cupboard"]):
		return false
	if not player.emerge() or not mission.try_interact(player):
		printerr("SCENARIO: lamp interaction failed")
		return false
	check(mission.lights_off and mission.anchors["curtain"].active and mission.enemies["veyr"].shadow_anchor.active, "lamp activates curtain and Veyr anchors")
	if not player.request_shift(mission.anchors["cupboard"]):
		return false
	if not await shift_when_reachable(mission, mission.enemies["watchman"].shadow_anchor):
		return false
	if not await shift_when_reachable(mission, mission.anchors["statue"]):
		return false
	if not player.request_shift(mission.anchors["bench"]):
		return false
	if not await shift_when_reachable(mission, mission.enemies["bodyguard"].shadow_anchor):
		return false
	if not await shift_when_reachable(mission, mission.anchors["curtain"]):
		return false
	if not await shift_when_reachable(mission, mission.enemies["veyr"].shadow_anchor):
		return false
	return player.request_attack()

func cross_servants_wing(mission: Node) -> bool:
	# Opening act: garden -> servants' hall -> courtyard, riding only shadows.
	var player = mission.player
	if not player.request_shift(mission.anchors["hedge"]):
		return false
	if not await shift_when_reachable(mission, mission.enemies["groundskeeper"].shadow_anchor):
		return false
	if not await shift_when_reachable(mission, mission.anchors["woodpile"]):
		return false
	if not player.request_shift(mission.anchors["larder"]):
		return false
	await settle()
	check(mission.entered_hall and mission.objective().contains("courtyard"), "entering the servants' hall advances the objective")
	if not await shift_when_reachable(mission, mission.enemies["steward"].shadow_anchor):
		return false
	if not await shift_when_reachable(mission, mission.anchors["table"]):
		return false
	if not player.request_shift(mission.anchors["stairs"]):
		return false
	if not player.request_shift(mission.anchors["ivy"]):
		return false
	await settle()
	check(mission.reached_courtyard and not mission.alarm.active, "servants' wing crossed unseen")
	return true

func complete_ghost_route(mission: Node) -> bool:
	if not await cross_servants_wing(mission):
		return false
	if not mission.player.request_shift(mission.anchors["crate"]):
		return false
	if not await shift_when_reachable(mission, mission.enemies["gatekeeper"].shadow_anchor):
		return false
	if not await shift_when_reachable(mission, mission.anchors["statue"]):
		return false
	return await finish_from_statue(mission)

func walk_to(player: Node, destination: Vector2, seconds: float = 10.0) -> bool:
	# At 8x, a keyboard-driven step can skip a five-pixel arrival region.
	# Walk at 2x while retaining real player acceleration and collisions.
	var previous_scale := Engine.time_scale
	Engine.time_scale = 2.0
	var budget := ceili(seconds * 60.0 / Engine.time_scale) + 4
	for frame in range(budget):
		if not player.is_alive():
			printerr("SCENARIO: walking player died at ", player.global_position, " reason=", player.mission.failure_reason)
			player.movement_override = Vector2.ZERO
			Engine.time_scale = previous_scale
			return false
		if player.global_position.distance_to(destination) < 5.0:
			player.movement_override = Vector2.ZERO
			Engine.time_scale = previous_scale
			return true
		player.movement_override = (destination - player.global_position).normalized()
		await physics_frame
	printerr("SCENARIO: walk timeout position=", player.global_position, " target=", destination, " velocity=", player.velocity)
	player.movement_override = Vector2.ZERO
	Engine.time_scale = previous_scale
	return false

func complete_lethal_gate_route(mission: Node) -> bool:
	var player = mission.player
	if not await cross_servants_wing(mission):
		return false
	if not player.request_shift(mission.anchors["crate"]):
		return false
	if not await shift_when_reachable(mission, mission.enemies["gatekeeper"].shadow_anchor):
		return false
	player.request_attack()
	await settle()
	check(not mission.enemies["gatekeeper"].is_alive() and player.has_gate_key, "dead gatekeeper drops recoverable key")
	if not await walk_to(player, Vector2(336, 640)):
		printerr("SCENARIO: walk to gate failed")
		return false
	if not mission.try_interact(player):
		return false
	if not await walk_to(player, Vector2(400, 640)):
		return false
	if not player.request_shift(mission.anchors["foyer"]):
		return false
	if not player.request_shift(mission.anchors["statue"]):
		return false
	return await finish_from_statue(mission)

func _test_presentation() -> void:
	for path in ["res://presentation/fx_manager.gd", "res://ui/game_ui.gd"]:
		if not FileAccess.file_exists(path):
			check(false, "Presentation module exists: " + path)
			return
	var mission = load("res://main.tscn").instantiate()
	mission.test_mode = true
	root.add_child(mission)
	current_scene = mission
	await settle()
	mission.confirm_detection(mission.enemies["gatekeeper"])
	var shot = load("res://actors/projectile.gd").new()
	shot.position = Vector2(512, 600)
	mission.world.add_child(shot)
	await settle()
	var timer_before: float = mission.alarm.remaining
	var guard_before: Vector2 = mission.enemies["gatekeeper"].global_position
	var shot_before: Vector2 = shot.global_position
	mission.ui.pause_game()
	await create_timer(0.12, true, false, true).timeout
	check(paused, "pause UI pauses scene tree")
	check(mission.alarm.remaining == timer_before, "pause freezes escape timer")
	check(mission.enemies["gatekeeper"].global_position == guard_before, "pause freezes enemy motion")
	check(shot.global_position == shot_before, "pause freezes projectiles")
	mission.ui.resume_game()
	check(not paused, "pause UI resumes scene tree")
	mission.fx_manager.request_hitstop(0.045)
	check(Engine.time_scale < 1.0, "impact hit-stop begins")
	await create_timer(0.09, true, false, true).timeout
	check(is_equal_approx(Engine.time_scale, 1.0), "hit-stop restores time scale using real time")
	mission.fx_manager.set_process(false)
	mission.fx_manager.request_hitstop(0.001)
	await create_timer(0.02, true, false, true).timeout
	mission.fx_manager.request_hitstop(0.001)
	await create_timer(0.02, true, false, true).timeout
	mission.fx_manager._process(0.0)
	check(is_equal_approx(Engine.time_scale, 1.0), "overlapping impacts preserve baseline after missed render restoration")
	Engine.time_scale = 1.0
	mission.fx_manager.set_process(true)
	mission.player.finish_emerge(Vector2(100, 720))
	mission.player.request_attack()
	mission.player._tick_attack(0.06)
	mission.fx_manager.request_hitstop(0.045)
	var restart_before: int = mission.stats.restarts
	mission.ui.pause_game()
	mission.request_restart()
	await settle()
	await settle()
	mission = current_scene
	check(not paused and is_equal_approx(Engine.time_scale, 1.0), "restart during paused hit-stop remains responsive")
	check(mission.phase == "playing" and mission.player.is_hidden(), "restart restores playable hidden spawn")
	check(mission.player.attack_elapsed < 0.0 and not mission.alarm.active, "restart clears attack and alarm")
	check(get_nodes_in_group("projectiles").is_empty(), "restart removes old projectiles")
	check(mission.stats.restarts == restart_before + 1, "paused restart counted once")
	mission.queue_free()
	current_scene = null
	await settle()

func emit_key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func emit_mouse(point: Vector2, pressed: bool, shift: bool = false) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.position = point
	event.global_position = point
	event.pressed = pressed
	event.shift_pressed = shift
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _test_input() -> void:
	var mission = load("res://main.tscn").instantiate()
	mission.test_mode = true
	root.add_child(mission)
	current_scene = mission
	await settle()
	mission.phase = "title"
	mission.ui.set_screen("title")
	emit_mouse(Vector2(150, 239), true)
	emit_mouse(Vector2(150, 239), false)
	await process_frame
	check(mission.phase == "playing", "title button receives mouse press and release")
	mission.player.attach_anchor(mission.anchors["well"])
	mission.camera.reset_smoothing()
	await settle()
	mission.phase = "title"
	mission.ui.set_screen("title")
	mission.ui.buttons[1]["button"].grab_focus()
	emit_key(KEY_ENTER, true)
	emit_key(KEY_ENTER, false)
	await process_frame
	check(mission.ui.screen_mode == "help", "Enter activates the focused title action")
	mission.ui.buttons[1]["button"].release_focus()
	mission.phase = "title"
	mission.ui.set_screen("title")
	emit_key(KEY_ENTER, true)
	emit_key(KEY_ENTER, false)
	await process_frame
	check(mission.phase == "playing" and mission.ui.screen_mode == "playing", "Enter input starts title screen")
	mission.player.input_enabled = true
	emit_key(KEY_E, true)
	emit_key(KEY_E, false)
	await settle()
	check(not mission.player.is_hidden(), "E input emerges from shadow")
	var before_x: float = mission.player.global_position.x
	emit_key(KEY_D, true)
	for frame in range(12):
		await physics_frame
	emit_key(KEY_D, false)
	await settle()
	check(mission.player.global_position.x > before_x + 3.0, "D input drives actual physical movement")
	var point: Vector2 = mission.get_viewport().get_canvas_transform() * (mission.player.global_position + Vector2(30, 0))
	emit_mouse(point, true)
	emit_mouse(point, false)
	await process_frame
	check(mission.player.attack_elapsed >= 0.0, "mouse input starts sword action")
	emit_key(KEY_SHIFT, true)
	var anchor_point: Vector2 = mission.get_viewport().get_canvas_transform() * mission.anchors["crate"].global_position
	emit_mouse(anchor_point, true, true)
	emit_mouse(anchor_point, false, true)
	await settle()
	check(mission.player.current_anchor == mission.anchors["crate"], "Shift plus mouse input selects clicked world anchor")
	check(mission.player.attack_elapsed < 0.0 and mission.player.attack_buffer == 0.0, "shift input cancels sword and its buffer")
	for index in range(2):
		mission.player.attach_anchor(mission.anchors["crate"])
		var original = mission.enemies["watchman"]
		original.ai_enabled = false
		original.global_position = mission.anchors["crate"].global_position
		if index == 1:
			mission.player.attach_anchor(original.shadow_anchor)
		var carrier = mission.enemies["gatekeeper" if index == 0 else "bodyguard"]
		carrier.ai_enabled = false
		carrier.global_position = mission.anchors["crate"].global_position + (Vector2(48, 0) if index == 0 else Vector2(0, -48))
		await settle()
		var carrier_point: Vector2 = mission.get_viewport().get_canvas_transform() * carrier.shadow_anchor.global_position
		if index == 1:
			emit_key(KEY_SPACE, true)
		emit_mouse(carrier_point, true, true)
		if index == 0:
			emit_key(KEY_SPACE, true)
		emit_key(KEY_SPACE, false)
		emit_mouse(carrier_point, false, true)
		check(carrier.is_alive() and original.is_alive() and mission.player.current_anchor == carrier.shadow_anchor and mission.player.attack_buffer == 0.0, "shift gesture wins over Space in event order " + str(index))
	emit_key(KEY_SHIFT, false)
	emit_key(KEY_ESCAPE, true)
	emit_key(KEY_ESCAPE, false)
	await process_frame
	check(paused and mission.ui.screen_mode == "pause", "Escape input opens pause")
	emit_key(KEY_ESCAPE, true)
	emit_key(KEY_ESCAPE, false)
	await process_frame
	check(not paused and mission.ui.screen_mode == "playing", "Escape input resumes while paused")
	var before_restarts: int = mission.stats.restarts
	emit_key(KEY_R, true)
	emit_key(KEY_R, false)
	await settle()
	await settle()
	mission = current_scene
	check(mission.stats.restarts == before_restarts + 1, "R input requests exactly one restart")
	check(mission.player.is_hidden() and mission.phase == "playing", "R input restores safe playable spawn")
	mission.queue_free()
	current_scene = null
	await settle()

func _test_navigation() -> void:
	var mission = load("res://main.tscn").instantiate()
	mission.test_mode = true
	root.add_child(mission)
	current_scene = mission
	await settle()
	Engine.time_scale = 8.0
	var guard = mission.enemies["bodyguard"]
	guard.global_position = Vector2(592, 128)
	guard.patrol_points.assign([Vector2(688, 528)])
	guard.patrol_waits.assign([0.2])
	guard.patrol_faces.assign([Vector2.DOWN])
	guard.patrol_index = 0
	guard.wait_timer = 0.0
	guard.mode = guard.Mode.ALERT
	var returned: bool = await wait_for(func(): return guard.global_position.distance_to(Vector2(688, 528)) < 8.0, 25.0)
	check(returned, "alert guard routes out of alcove around walls to resume patrol")
	Engine.time_scale = 1.0
	mission.queue_free()
	current_scene = null
	await settle()
