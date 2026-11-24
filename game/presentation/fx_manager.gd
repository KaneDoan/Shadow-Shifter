extends Node2D

var mission
var clips: Dictionary = {}
var effects: Array[Dictionary] = []
var occupied_flame: Sprite2D
var hitstop_until_ms := 0
var saved_scale := 1.0
var shake_until_ms := 0
var shake_strength := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 6
	for name in ["slash", "shift", "impact", "shadow", "torch"]:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/fx/%s.json" % name))
		var metadata: Dictionary = data["meta"]["pixelfx"]
		metadata["texture"] = load("res://assets/fx/%s.png" % name)
		clips[name] = metadata
	occupied_flame = spawn("shadow", Vector2.ZERO, 0.27, 1.0, true)
	occupied_flame.modulate.a = 0.8
	for point in [Vector2(64, 480), Vector2(320, 544), Vector2(416, 320), Vector2(736, 320), Vector2(736, 736), Vector2(416, 736), Vector2(416, 64), Vector2(608, 64), Vector2(832, 192), Vector2(1056, 192), Vector2(1056, 512), Vector2(64, 864), Vector2(576, 864), Vector2(704, 864), Vector2(1120, 864)]:
		var torch := spawn("torch", point, 0.32, 1.0, true)
		torch.z_index = -3
		# Loop phases differ deterministically, without affecting gameplay.
		effects.back()["clock"] = fmod(point.x * 0.013 + point.y * 0.019, 2.0)

func spawn(name: String, at: Vector2, factor: float = 0.5, speed: float = 1.0, loop: bool = false, direction: Vector2 = Vector2.RIGHT) -> Sprite2D:
	var clip: Dictionary = clips[name]
	var sprite := Sprite2D.new()
	sprite.texture = clip["texture"]
	sprite.hframes = int(clip["columns"])
	sprite.vframes = ceili(float(clip["frames"]) / float(sprite.hframes))
	sprite.centered = false
	sprite.offset = -Vector2(clip["pivot"][0], clip["pivot"][1])
	sprite.scale = Vector2.ONE * factor
	sprite.rotation = direction.angle()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	sprite.global_position = at
	effects.append({"node": sprite, "clip": clip, "clock": 0.0, "speed": speed, "loop": loop})
	return sprite

func shifted(from_pos: Vector2, to_pos: Vector2) -> void:
	spawn("shift", from_pos, 0.36, 5.0)
	spawn("shift", to_pos, 0.36, 5.0)

func sword() -> void:
	spawn("slash", mission.player.global_position, 0.65, 2.6, false, mission.player.attack_direction)

func impact(at: Vector2, direction: Vector2, _target: Node = null) -> void:
	spawn("impact", at, 0.55, 2.0, false, direction)
	shake_until_ms = Time.get_ticks_msec() + 110
	shake_strength = 2.2
	if not mission.test_mode:
		request_hitstop(0.045)

func request_hitstop(seconds: float) -> void:
	var now := Time.get_ticks_msec()
	if hitstop_until_ms == 0:
		saved_scale = Engine.time_scale
		Engine.time_scale = saved_scale * 0.08
	hitstop_until_ms = maxi(hitstop_until_ms, now + int(seconds * 1000))

func _process(delta: float) -> void:
	var now := Time.get_ticks_msec()
	if hitstop_until_ms > 0 and now >= hitstop_until_ms:
		Engine.time_scale = saved_scale
		hitstop_until_ms = 0
	if get_tree().paused:
		return
	if is_instance_valid(occupied_flame) and is_instance_valid(mission.player):
		occupied_flame.visible = mission.player.is_hidden()
		occupied_flame.global_position = mission.player.global_position + Vector2(0, 3)
	if is_instance_valid(mission.camera):
		var strength := shake_strength * maxf(0.0, float(shake_until_ms - now) / 110.0)
		mission.camera.offset = Vector2(sin(float(now) * 0.071), cos(float(now) * 0.089)) * strength
	for index in range(effects.size() - 1, -1, -1):
		var entry: Dictionary = effects[index]
		var node: Sprite2D = entry["node"]
		if not is_instance_valid(node):
			effects.remove_at(index)
			continue
		entry["clock"] += delta * float(entry["speed"])
		var count: int = entry["clip"]["frames"]
		var frame := int(float(entry["clock"]) * float(entry["clip"]["fps"]))
		if frame >= count and not entry["loop"]:
			node.queue_free()
			effects.remove_at(index)
		else:
			node.frame = frame % count

func _exit_tree() -> void:
	if hitstop_until_ms > 0:
		Engine.time_scale = saved_scale
