extends SceneTree

var view := "title"
var output := ""

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--view="):
			view = argument.trim_prefix("--view=")
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	call_deferred("_capture")

func _capture() -> void:
	var stats = root.get_node("RunStats")
	AudioServer.set_bus_mute(0, true)
	stats.save_path = ""
	stats.has_started = view != "title"
	var mission = load("res://main.tscn").instantiate()
	root.add_child(mission)
	current_scene = mission
	mission.audio_manager.enabled = false
	mission.player.input_enabled = false
	mission.camera.position_smoothing_enabled = false
	if view in ["gallery", "combat", "pause", "results", "dialogue"]:
		mission.player.attach_anchor(mission.anchors["statue"])
	if view == "study":
		mission.lights_off = true
		mission.anchors["curtain"].set_active(true)
		mission.enemies["veyr"].shadow_anchor.set_active(true)
		mission.player.attach_anchor(mission.anchors["curtain"])
	for frame in range(20):
		await process_frame
	if view == "help":
		mission.ui.show_help("title")
	if view == "intro":
		mission.ui.intro_index = 0
		mission.ui.intro_clock = 5.0
		mission.ui.set_screen("intro")
	if view == "dialogue":
		mission.ui.dialogue.played.clear()
		mission.ui.dialogue.queue.clear()
		mission.ui.dialogue.current = []
		mission.ui.dialogue.play("gallery")
		mission.ui.dialogue.shown = 999.0
	if view == "pause":
		mission.ui.pause_game()
	if view == "results":
		mission.elapsed = 94.25
		mission.win()
	if view == "combat":
		mission.player.finish_emerge(Vector2(610, 600))
		mission.player.aim_direction = Vector2.RIGHT
		var victim = mission.enemies["gallery_sentry"]
		victim.global_position = Vector2(644, 600)
		victim.ai_enabled = false
		mission.player.request_attack()
		mission.player._tick_attack(0.07)
	if view in ["gameplay", "gallery", "study"]:
		var shift := InputEventKey.new()
		shift.keycode = KEY_SHIFT
		shift.physical_keycode = KEY_SHIFT
		shift.pressed = true
		Input.parse_input_event(shift)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if output.is_empty():
		output = ProjectSettings.globalize_path("res://../captures/" + view + ".png")
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var result := image.save_png(output)
	print("CAPTURE: ", view, " ", image.get_size(), " -> ", output, " result=", result)
	image = null
	mission.queue_free()
	current_scene = null
	await process_frame
	await process_frame
	quit(0 if result == OK else 1)
