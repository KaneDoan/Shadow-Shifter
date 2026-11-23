extends Node2D

signal result_changed
signal feedback_event(kind: String, at: Vector2, direction: Vector2)
const Data = preload("res://world/level_data.gd")

var test_mode := false
var phase := "playing"
var rank := ""
var failure_reason := ""
var elapsed := 0.0
var guards_killed := 0
var lights_off := false
var visited_gallery := false
var key_available := false
var key_position := Vector2.ZERO
var restarting := false
var world: Node2D
var level
var player
var shadow_system
var combat_system
var alarm
var stats
var anchors: Dictionary = {}
var enemies: Dictionary = {}
var doors: Dictionary = {}
var escape_curve: Curve2D
var camera: Camera2D
var fx_manager
var audio_manager
var ui

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--suite="):
			test_mode = true
	stats = get_node("/root/RunStats")
	if test_mode:
		stats.has_started = true
	alarm = preload("res://core/alarm_state.gd").new()
	world = Node2D.new()
	world.name = "World"
	world.y_sort_enabled = true
	add_child(world)
	level = preload("res://world/manor_level.gd").new()
	world.add_child(level)
	level.build(self)
	shadow_system = preload("res://systems/shadow_system.gd").new()
	shadow_system.z_index = 3
	world.add_child(shadow_system)
	combat_system = preload("res://systems/combat_system.gd").new()
	add_child(combat_system)
	for data in Data.anchors():
		var anchor = preload("res://world/shadow_anchor.gd").new()
		anchor.anchor_id = data["id"]
		anchor.position = data["at"]
		anchor.active = data.get("active", true)
		world.add_child(anchor)
		anchors[data["id"]] = anchor
		shadow_system.register_anchor(anchor)
	for data in [{"id": "gate", "at": Vector2(368, 640), "locked": true}, {"id": "study", "at": Vector2(784, 416), "locked": false}]:
		var door = preload("res://world/door.gd").new()
		door.door_id = data["id"]
		door.position = data["at"]
		door.locked = data["locked"]
		world.add_child(door)
		doors[data["id"]] = door
	player = preload("res://actors/player.gd").new()
	player.position = anchors["well"].position
	player.shadow_system = shadow_system
	player.combat_system = combat_system
	player.mission = self
	player.input_enabled = not test_mode
	shadow_system.player = player
	world.add_child(player)
	player.died.connect(_on_player_died)
	for data in Data.guards():
		var enemy = preload("res://actors/enemy.gd").new()
		enemy.enemy_id = data["id"]
		enemy.display_name = data["name"]
		enemy.position = data["at"]
		enemy.attack_style = data["style"]
		enemy.visual_role = data.get("visual", "guard")
		enemy.is_boss = data.get("boss", false)
		enemy.patrol_points.assign(data["points"])
		enemy.patrol_waits.assign(data["waits"])
		enemy.patrol_faces.assign(data["faces"])
		enemy.player = player
		enemy.shadow_system = shadow_system
		enemy.mission = self
		world.add_child(enemy)
		enemy.died.connect(_on_enemy_died)
		enemies[data["id"]] = enemy
	enemies["veyr"].shadow_anchor.set_active(false)
	player.attach_anchor(anchors["well"])
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(Data.BOUNDS.x)
	camera.limit_bottom = int(Data.BOUNDS.y)
	player.add_child(camera)
	audio_manager = preload("res://presentation/audio_manager.gd").new()
	audio_manager.enabled = not test_mode
	add_child(audio_manager)
	fx_manager = preload("res://presentation/fx_manager.gd").new()
	fx_manager.mission = self
	add_child(fx_manager)
	player.shifted.connect(func(from_pos: Vector2, to_pos: Vector2):
		fx_manager.shifted(from_pos, to_pos)
		audio_manager.play("shift", -15.0))
	player.attack_started.connect(func():
		fx_manager.sword()
		audio_manager.play("slash", -15.0))
	feedback_event.connect(_present_feedback)
	var post := CanvasLayer.new()
	post.layer = 9
	add_child(post)
	var vignette := ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = preload("res://presentation/vignette.gdshader")
	vignette.material = material
	post.add_child(vignette)
	var canvas := CanvasLayer.new()
	canvas.layer = 20
	add_child(canvas)
	ui = preload("res://ui/game_ui.gd").new()
	ui.mission = self
	canvas.add_child(ui)
	if not test_mode and not stats.has_started:
		phase = "title"
		player.input_enabled = false
		player.set_physics_process(false)
		for enemy in enemies.values():
			enemy.ai_enabled = false
		ui.set_screen("title")
	else:
		begin_run()

func begin_run() -> void:
	if phase not in ["title", "playing"]:
		return
	phase = "playing"
	stats.has_started = true
	player.input_enabled = not test_mode
	player.set_physics_process(true)
	for enemy in enemies.values():
		enemy.ai_enabled = enemy.is_alive()
	ui.set_screen("playing")

func _present_feedback(kind: String, at: Vector2, direction: Vector2) -> void:
	if kind == "kill":
		fx_manager.impact(at, direction)
		audio_manager.play("impact", -9.0)
	elif kind == "death":
		fx_manager.spawn("impact", at, 0.65, 1.7)
		audio_manager.play("death", -8.0)
	else:
		audio_manager.play(kind, -12.0)

func _physics_process(delta: float) -> void:
	if phase != "playing":
		return
	elapsed += delta
	if player.global_position.x >= 384:
		visited_gallery = true
	if key_available and not player.is_hidden() and player.global_position.distance_to(key_position) <= 20.0:
		player.has_gate_key = true
		key_available = false
		shadow_system.show_feedback("GATE KEY TAKEN")
		feedback_event.emit("key", key_position, Vector2.ZERO)
	for body in enemies.values():
		if body.is_alive() or body.body_discovered or body.is_boss:
			continue
		for witness in enemies.values():
			if witness != body and witness.is_alive() and witness.can_see(body.global_position):
				body.body_discovered = true
				var was_active: bool = alarm.active
				alarm.discover_body(body.get_instance_id())
				if not was_active:
					_begin_escape()
				break
	if alarm.active:
		alarm.tick(delta)
		var boss = enemies["veyr"]
		if is_instance_valid(escape_curve) and boss.is_alive():
			var destination := escape_curve.sample_baked(escape_curve.get_baked_length() * alarm.progress)
			var offset: Vector2 = destination - boss.global_position
			if offset.length_squared() > 0.01:
				boss.facing = offset.normalized()
			boss.global_position = destination
		if alarm.remaining <= 0.0:
			fail("Lord Veyr escaped")
	queue_redraw()

func try_interact(actor: Node) -> bool:
	if actor.is_hidden() or phase != "playing":
		return false
	if not lights_off and actor.global_position.distance_to(Data.SWITCH) <= 48.0:
		lights_off = true
		level.lights_off = true
		level.queue_redraw()
		anchors["curtain"].set_active(true)
		enemies["veyr"].shadow_anchor.set_active(true)
		shadow_system.show_feedback("LIGHTS OUT — THE STUDY SHADOWS AWAKEN")
		feedback_event.emit("switch", Data.SWITCH, Vector2.ZERO)
		return true
	for door in doors.values():
		if actor.global_position.distance_to(door.global_position) <= 48.0:
			if door.try_interact(actor):
				feedback_event.emit("door", door.global_position, Vector2.ZERO)
				return true
			shadow_system.show_feedback("THE GATEKEEPER HAS THE KEY")
			return false
	return false

func request_guard_door(guard: Node) -> void:
	var id: String = "gate" if guard.enemy_id == "gatekeeper" else ("study" if guard.enemy_id == "bodyguard" else "")
	if not id.is_empty() and guard.global_position.distance_to(doors[id].global_position) < 80.0:
		if not doors[id].is_open:
			feedback_event.emit("door", doors[id].global_position, Vector2.ZERO)
		doors[id].open_for(2.0)

func confirm_detection(_guard: Node) -> void:
	if phase != "playing" or alarm.active:
		return
	alarm.start()
	_begin_escape()
	shadow_system.show_feedback("SPOTTED — VEYR IS FLEEING")

func _begin_escape() -> void:
	var boss = enemies["veyr"]
	boss.escape_override = true
	escape_curve = Curve2D.new()
	escape_curve.add_point(boss.global_position)
	escape_curve.add_point(Vector2(1008, 416))
	escape_curve.add_point(Data.EXIT)
	feedback_event.emit("alarm", boss.global_position, Vector2.ZERO)

func _on_enemy_died(enemy: Node, source: Node) -> void:
	if phase != "playing":
		return
	feedback_event.emit("kill", enemy.global_position, Vector2.RIGHT if not is_instance_valid(source) else (enemy.global_position - source.global_position).normalized())
	if enemy.is_boss:
		win()
		return
	guards_killed += 1
	if enemy.enemy_id == "gatekeeper":
		key_available = true
		key_position = enemy.global_position + Vector2(12, 0)

func _on_player_died(source: Node) -> void:
	feedback_event.emit("death", player.global_position, Vector2.ZERO)
	var name_text: String = source.display_name if is_instance_valid(source) and source.get("display_name") != null else "a lethal strike"
	fail("Cut down by " + name_text)

func _freeze_actors() -> void:
	player.input_enabled = false
	player.attack_elapsed = -1.0
	player.visual.attacking = false
	player.set_physics_process(false)
	for enemy in enemies.values():
		enemy.ai_enabled = false
	for projectile in get_tree().get_nodes_in_group("projectiles"):
		projectile.queue_free()

func win() -> void:
	if phase != "playing":
		return
	phase = "won"
	rank = "Messy Success" if alarm.active else ("Ghost Assassin" if guards_killed == 0 else "Silent Blade")
	stats.record_result(rank, elapsed)
	audio_manager.play("win", -10.0)
	_freeze_actors()
	result_changed.emit()

func fail(reason: String) -> void:
	if phase != "playing":
		return
	phase = "lost"
	failure_reason = reason
	_freeze_actors()
	result_changed.emit()

func request_restart() -> void:
	if restarting:
		return
	restarting = true
	stats.restarts += 1
	get_tree().paused = false
	if not test_mode:
		Engine.time_scale = 1.0
	call_deferred("_reload_scene")

func _reload_scene() -> void:
	get_tree().reload_current_scene()

func objective() -> String:
	if phase == "won":
		return "Target eliminated. The dark remembers."
	if alarm.active:
		return "Intercept Lord Veyr before he escapes"
	if not visited_gallery:
		return "Ride the gatekeeper through the gate"
	if not lights_off:
		return "Reach the lamp alcove and extinguish the chandelier"
	return "Ride into the study. Eliminate Lord Veyr."

func context_prompt() -> String:
	if player.is_hidden():
		if is_instance_valid(player.current_anchor) and is_instance_valid(player.current_anchor.owner_actor):
			return "SPACE  Eliminate %s   /   E  Emerge   /   SHIFT + CLICK  Travel" % player.current_anchor.owner_actor.display_name
		return "SHIFT + CLICK  Travel   /   E  Emerge"
	if not lights_off and player.global_position.distance_to(Data.SWITCH) <= 48.0:
		return "E  Extinguish chandelier"
	for door in doors.values():
		if player.global_position.distance_to(door.global_position) <= 48.0:
			return "E  Open " + ("gate" if door.door_id == "gate" else "study door")
	return "WASD  Move   /   LMB or SPACE  Strike   /   SHIFT + CLICK  Hide"

func _draw() -> void:
	if key_available:
		draw_circle(key_position, 4.0, Color("e8ca83"))
		draw_line(key_position, key_position + Vector2(10, 0), Color("ffe7a3"), 2.0)
		draw_line(key_position + Vector2(8, 0), key_position + Vector2(8, 4), Color("ffe7a3"), 2.0)
