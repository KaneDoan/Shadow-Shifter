extends Control

const Data = preload("res://world/level_data.gd")
const INK := Color("e9e4f6")
const MUTED := Color("969bb7")
const VIOLET := Color("ac7cf2")
const CYAN := Color("99e8df")
var mission
var screen_mode := "playing"
var help_return := "title"
var font: Font
var buttons: Array[Dictionary] = []
var clock := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	font = ThemeDB.fallback_font
	button("ENTER THE MANOR", Rect2(40, 222, 220, 34), ["title"], _start, true)
	button("HOW TO PLAY", Rect2(40, 268, 140, 27), ["title"], func(): show_help("title"))
	button("QUIT", Rect2(192, 268, 68, 27), ["title"], func(): get_tree().quit())
	button("RETURN TO THE DARK", Rect2(214, 161, 212, 32), ["pause"], resume_game, true)
	button("RESTART MISSION", Rect2(214, 202, 212, 30), ["pause"], mission.request_restart)
	button("CONTROLS & RULES", Rect2(214, 241, 212, 30), ["pause"], func(): show_help("pause"))
	button("BACK", Rect2(40, 305, 140, 29), ["help"], func(): set_screen(help_return))
	button("ENTER AGAIN", Rect2(80, 287, 216, 34), ["won", "lost"], mission.request_restart, true)
	button("RETURN TO TITLE", Rect2(312, 287, 216, 34), ["won", "lost"], _return_title)
	mission.result_changed.connect(func(): set_screen(mission.phase))
	set_screen("playing")

func button(caption: String, rectangle: Rect2, modes: Array, action: Callable, primary: bool = false) -> void:
	var item := Button.new()
	item.text = caption
	item.position = rectangle.position
	item.size = rectangle.size
	item.add_theme_font_size_override("font_size", 12 if primary else 10)
	item.add_theme_color_override("font_color", INK)
	item.add_theme_color_override("font_hover_color", Color.WHITE)
	item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("66459b") if primary else Color("151a2b")
	normal.border_color = Color("a781db") if primary else Color("41445c")
	normal.set_border_width_all(1)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color("8258bc") if primary else Color("2a2945")
	hover.border_color = CYAN
	var focus: StyleBoxFlat = normal.duplicate()
	focus.border_color = CYAN
	focus.set_border_width_all(2)
	item.add_theme_stylebox_override("normal", normal)
	item.add_theme_stylebox_override("hover", hover)
	item.add_theme_stylebox_override("pressed", hover)
	item.add_theme_stylebox_override("focus", focus)
	item.pressed.connect(action)
	add_child(item)
	buttons.append({"button": item, "modes": modes})

func set_screen(mode: String) -> void:
	screen_mode = mode
	for item in buttons:
		item["button"].visible = mode in item["modes"]
	Input.set_default_cursor_shape(Input.CURSOR_CROSS if mode == "playing" else Input.CURSOR_ARROW)
	queue_redraw()

func _start() -> void:
	mission.begin_run()
	set_screen("playing")

func _return_title() -> void:
	mission.stats.has_started = false
	mission.request_restart()

func pause_game() -> void:
	if mission.phase != "playing":
		return
	get_tree().paused = true
	set_screen("pause")

func resume_game() -> void:
	get_tree().paused = false
	set_screen("playing")

func show_help(return_to: String) -> void:
	help_return = return_to
	set_screen("help")

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode
	if key == KEY_ESCAPE:
		if screen_mode == "playing":
			pause_game()
		elif screen_mode == "pause":
			resume_game()
		elif screen_mode == "help":
			set_screen(help_return)
		get_viewport().set_input_as_handled()
	elif key == KEY_R and screen_mode in ["playing", "pause", "won", "lost"]:
		mission.request_restart()
		get_viewport().set_input_as_handled()
	elif key in [KEY_ENTER, KEY_SPACE] and screen_mode == "title":
		if get_viewport().gui_get_focus_owner() != null:
			return
		_start()
		get_viewport().set_input_as_handled()
	elif key == KEY_F1 and screen_mode == "playing":
		get_tree().paused = true
		show_help("pause")
		get_viewport().set_input_as_handled()
	elif key == KEY_M:
		mission.audio_manager.toggle_mute()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	clock += delta / maxf(0.01, Engine.time_scale)
	queue_redraw()

func label(value: String, at: Vector2, size_px: int = 12, color: Color = INK) -> void:
	draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)

func spaced(value: String, at: Vector2, size_px: int = 10, color: Color = MUTED, tracking: float = 2.0) -> void:
	var x := at.x
	for character in value:
		draw_string(font, Vector2(x, at.y), character, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)
		x += font.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x + tracking

func _draw() -> void:
	if not is_instance_valid(mission) or not is_instance_valid(font):
		return
	if screen_mode == "playing":
		_draw_hud()
	elif screen_mode == "title":
		_draw_title()
	elif screen_mode == "help":
		_draw_help()
	elif screen_mode == "pause":
		draw_rect(Rect2(0, 0, 640, 360), Color(0.025, 0.03, 0.065, 0.88))
		spaced("TIME HOLDS ITS BREATH", Vector2(214, 87), 9, CYAN)
		label("PAUSED", Vector2(238, 132), 34)
		label("The manor waits. So do its blades.", Vector2(213, 297), 11, MUTED)
	else:
		_draw_results()

func _draw_title() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0.025, 0.03, 0.065, 0.9))
	draw_rect(Rect2(40, 54, 3, 19), VIOLET)
	spaced("BLACKGLASS MANOR / MIDNIGHT", Vector2(54, 67), 9, CYAN, 1.7)
	label("SHADOW", Vector2(37, 137), 40)
	var logo_x := 37.0 + font.get_string_size("SHADOW", HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x + 2.0
	label("SHIFT", Vector2(logo_x, 137), 40, VIOLET)
	draw_line(Vector2(40, 157), Vector2(348, 157), Color("4b3a65"), 1)
	label("Ride living shadows. Strike once.", Vector2(40, 182), 13, Color("c4bfd7"))
	label("Leave no witness.", Vector2(40, 201), 13, MUTED)
	var center := Vector2(491, 168)
	for radius in [52.0, 70.0, 91.0]:
		draw_arc(center, radius, clock * 0.08 + radius, clock * 0.08 + radius + 4.8, 60, Color(0.5, 0.35, 0.76, 0.24), 1)
	var points := [Vector2(426, 104), Vector2(526, 123), Vector2(557, 211), Vector2(448, 237), center]
	for index in range(points.size()):
		var point: Vector2 = points[index]
		draw_line(point, points[(index + 1) % points.size()], Color(0.52, 0.34, 0.76, 0.33), 1)
		draw_circle(point, 5.0 + sin(clock * 2.0 + index) * 0.8, Color("49335f"))
		draw_arc(point, 6.0, 0, TAU, 20, VIOLET, 1)
		draw_circle(point, 1.5, CYAN)
	draw_circle(center, 22, Color("18152e"))
	draw_arc(center, 22, 0, TAU, 32, VIOLET, 1.5)
	draw_line(center + Vector2(-8, 14), center + Vector2(10, -20), CYAN, 2)
	draw_line(center + Vector2(-8, 2), center + Vector2(6, 9), Color("d8c8f4"), 2)
	spaced("STEALTH / ONE HIT / NO SECOND CHANCES", Vector2(40, 332), 8, MUTED, 1.0)

func _draw_hud() -> void:
	draw_rect(Rect2(0, 0, 640, 48), Color(0.025, 0.035, 0.065, 0.94))
	draw_line(Vector2(0, 47), Vector2(640, 47), Color("40334e"), 1)
	spaced("SHADOWSHIFT", Vector2(14, 18), 10, INK, 1.1)
	label(mission.level.zone_name(mission.player.global_position), Vector2(148, 18), 9, MUTED)
	var hidden: bool = mission.player.is_hidden()
	var state_text := "RIDING" if mission.player.state == mission.player.State.RIDING else ("SHADOW" if hidden else "EXPOSED")
	var state_color := CYAN if hidden else Color("f2b370")
	draw_rect(Rect2(534, 7, 92, 19), Color(0.12, 0.15, 0.22, 1))
	draw_rect(Rect2(534, 7, 2, 19), state_color)
	spaced(state_text, Vector2(544, 20), 9, state_color, 0.9)
	label(mission.objective(), Vector2(14, 38), 11, Color("b7b2cb"))
	if mission.alarm.active:
		var pulse := 0.65 + sin(clock * 6.0) * 0.25
		label("ESCAPE  %05.1f" % mission.alarm.remaining, Vector2(524, 39), 10, Color(1, 0.43, 0.38, pulse))
	draw_rect(Rect2(0, 334, 640, 26), Color(0.025, 0.035, 0.065, 0.95))
	label(mission.context_prompt(), Vector2(14, 350), 10, Color("c3bdd4"))
	if mission.shadow_system.feedback_time > 0.0:
		draw_rect(Rect2(16, 305, 490, 21), Color(0.04, 0.035, 0.09, 0.85))
		label(mission.shadow_system.feedback, Vector2(24, 319), 10, CYAN)
	_draw_minimap()
	if mission.player.current_anchor == mission.anchors["well"] and not mission.visited_gallery:
		draw_rect(Rect2(18, 61, 322, 66), Color(0.035, 0.04, 0.085, 0.94))
		draw_rect(Rect2(18, 61, 2, 66), VIOLET)
		spaced("01 / LEARN TO DISAPPEAR", Vector2(29, 79), 9, VIOLET, 1)
		label("Hold SHIFT and click the crate's shadow.", Vector2(29, 99), 11)
		label("Then ride the guard when his shadow comes near.", Vector2(29, 117), 10, MUTED)

func _draw_minimap() -> void:
	var origin := Vector2(540, 247)
	var scale_map := Vector2(86, 59) / Data.BOUNDS
	draw_rect(Rect2(530, 231, 104, 98), Color(0.025, 0.035, 0.065, 0.88))
	spaced("MANOR", Vector2(541, 242), 8, MUTED, 1)
	for room in Data.ROOMS:
		var rectangle: Rect2 = room["rect"]
		var mapped := Rect2(origin + rectangle.position * scale_map, rectangle.size * scale_map)
		draw_rect(mapped, Color("262c43"))
		draw_rect(mapped, Color("62627e"), false, 0.7)
	for corridor in Data.CORRIDORS:
		draw_rect(Rect2(origin + corridor.position * scale_map, corridor.size * scale_map), Color("515169"))
	for anchor in mission.anchors.values():
		draw_circle(origin + anchor.global_position * scale_map, 1.1, VIOLET if anchor.active else Color("4d465d"))
	draw_circle(origin + mission.player.global_position * scale_map, 2.0, CYAN)
	if mission.enemies["veyr"].is_alive():
		draw_circle(origin + mission.enemies["veyr"].global_position * scale_map, 1.7, Color("e88694"))
	label("%02d:%02d   %d / 6" % [floori(mission.elapsed / 60), int(mission.elapsed) % 60, mission.guards_killed], Vector2(540, 320), 9, MUTED)

func _draw_help() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0.025, 0.03, 0.065, 0.97))
	spaced("THE RULES OF THE DARK", Vector2(40, 43), 9, CYAN)
	label("MOVE LIKE A SHADOW", Vector2(40, 77), 27)
	var rows := [
		["WASD / ARROWS", "Move in physical form. Aim with the mouse."],
		["HOLD SHIFT + CLICK", "Shift to a highlighted shadow. Walls block travel."],
		["E", "Emerge, use the lamp switch, or open a door."],
		["LMB / SPACE", "Strike once. While riding, eliminate your carrier."],
		["R / ESC / M", "Restart instantly / pause / toggle audio."]
	]
	for index in range(rows.size()):
		label(rows[index][0], Vector2(40, 113 + index * 27), 10, VIOLET)
		label(rows[index][1], Vector2(203, 113 + index * 27), 10, INK)
	draw_line(Vector2(40, 241), Vector2(600, 241), Color("3e3550"), 1)
	label("One hit kills. Watch the amber wind-up; move before the red strike.", Vector2(40, 263), 11, CYAN)
	label("Guards are routes. A body or a witness starts Veyr's escape.", Vector2(40, 283), 11, MUTED)

func _draw_results() -> void:
	var success := screen_mode == "won"
	draw_rect(Rect2(0, 0, 640, 360), Color(0.025, 0.03, 0.065, 0.93))
	spaced("TARGET ELIMINATED" if success else "THE DARK LET GO", Vector2(80, 58), 10, CYAN if success else Color("ef8e89"))
	label(mission.rank.to_upper() if success else "ONE HIT. ONE END.", Vector2(78, 108), 31, INK if success else Color("f2c3c6"))
	label("No shadow could hold him." if success else mission.failure_reason, Vector2(80, 135), 12, MUTED)
	draw_line(Vector2(80, 155), Vector2(528, 155), Color("483855"), 1)
	var metrics := [
		["MISSION TIME", "%02d:%05.2f" % [floori(mission.elapsed / 60), fmod(mission.elapsed, 60.0)]],
		["GUARDS KILLED", str(mission.guards_killed) + " / 6"],
		["BODIES FOUND", str(mission.alarm.bodies_found)],
		["RESTARTS", str(mission.stats.restarts)]
	]
	for index in range(metrics.size()):
		var point := Vector2(80 + (index % 2) * 232, 184 + floori(float(index) / 2) * 45)
		spaced(metrics[index][0], point, 8, MUTED, 1)
		label(metrics[index][1], point + Vector2(0, 23), 20, CYAN if success else Color("dc9eb0"))
	if success and mission.stats.best_times.has(mission.rank):
		label("PERSONAL BEST  %.2f s" % mission.stats.best_times[mission.rank], Vector2(80, 271), 9, VIOLET)
