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
var display_font: Font
var dialogue: Control
var intro_index := 0
var intro_clock := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	font = ThemeDB.fallback_font
	# Gothic pixel font for headings, buttons and speaker names; crisp at multiples of 16 px.
	var gothic: FontFile = load("res://assets/fonts/simplified_gothic.otf")
	gothic.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	gothic.hinting = TextServer.HINTING_NONE
	gothic.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	display_font = gothic
	dialogue = preload("res://ui/dialogue_bar.gd").new()
	dialogue.display_font = display_font
	dialogue.can_advance = func(): return screen_mode == "cutscene"
	add_child(dialogue)
	button("Enter the Manor", Rect2(40, 222, 220, 34), ["title"], _start, true)
	button("How to Play", Rect2(40, 268, 140, 27), ["title"], func(): show_help("title"))
	button("Quit", Rect2(192, 268, 68, 27), ["title"], func(): get_tree().quit())
	button("Return to the Dark", Rect2(214, 161, 212, 32), ["pause"], resume_game, true)
	button("Restart Mission", Rect2(214, 202, 212, 30), ["pause"], mission.request_restart)
	button("Controls & Rules", Rect2(214, 241, 212, 30), ["pause"], func(): show_help("pause"))
	button("Back", Rect2(40, 305, 140, 29), ["help"], func(): set_screen(help_return))
	button("Enter Again", Rect2(80, 287, 216, 34), ["won", "lost"], mission.request_restart, true)
	button("Return to Title", Rect2(312, 287, 216, 34), ["won", "lost"], _return_title)
	mission.result_changed.connect(func(): set_screen(mission.phase))
	set_screen("playing")

func button(caption: String, rectangle: Rect2, modes: Array, action: Callable, primary: bool = false) -> void:
	var item := Button.new()
	item.text = caption
	item.position = rectangle.position
	item.size = rectangle.size
	item.add_theme_font_override("font", display_font)
	item.add_theme_font_size_override("font_size", 16)
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
	item.pressed.connect(_ui_sound)
	add_child(item)
	buttons.append({"button": item, "modes": modes})

func set_screen(mode: String) -> void:
	screen_mode = mode
	for item in buttons:
		item["button"].visible = mode in item["modes"]
	Input.set_default_cursor_shape(Input.CURSOR_CROSS if mode == "playing" else Input.CURSOR_ARROW)
	queue_redraw()

func _start() -> void:
	# The story cards play once per session; tests and later runs go straight in.
	if not mission.stats.seen_intro and not mission.test_mode and not dialogue.intro.is_empty():
		mission.stats.seen_intro = true
		intro_index = 0
		intro_clock = 0.0
		set_screen("intro")
		return
	mission.begin_run()
	set_screen("playing")

func _advance_intro() -> void:
	_ui_sound()
	intro_index += 1
	intro_clock = 0.0
	if intro_index >= dialogue.intro.size():
		_start()

func _ui_sound() -> void:
	if is_instance_valid(mission) and is_instance_valid(mission.audio_manager):
		mission.audio_manager.play("switch", -22.0)

func _update_dialogue_triggers() -> void:
	# Dialogue only happens in short cutscenes; automated tests play straight through.
	if screen_mode != "playing" or mission.phase != "playing" or mission.test_mode or mission.alarm.active:
		return
	start_cutscene("mission_start")
	if mission.level.zone_name(mission.player.global_position) == "OSWALD'S STUDY":
		start_cutscene("study")

## Freezes the whole scene (player, guards, timers) until the conversation is dismissed.
func start_cutscene(id: String) -> bool:
	if not dialogue.play(id):
		return false
	get_tree().paused = true
	set_screen("cutscene")
	return true

func end_cutscene() -> void:
	dialogue.skip()
	get_tree().paused = false
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
	if screen_mode == "intro":
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_advance_intro()
		elif event is InputEventKey and event.pressed and not event.echo:
			if event.physical_keycode == KEY_ESCAPE:
				intro_index = dialogue.intro.size() - 1
				_advance_intro()
			elif event.physical_keycode in [KEY_SPACE, KEY_ENTER]:
				_advance_intro()
		get_viewport().set_input_as_handled()
		return
	if screen_mode == "cutscene":
		var pressed: bool = event.is_pressed() and not event.is_echo()
		if pressed and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if not dialogue.advance():
				end_cutscene()
		elif pressed and event is InputEventKey:
			if event.physical_keycode == KEY_ESCAPE:
				end_cutscene()
			elif event.physical_keycode in [KEY_SPACE, KEY_ENTER]:
				if not dialogue.advance():
					end_cutscene()
			elif event.physical_keycode == KEY_R:
				mission.request_restart()
		if event is InputEventMouseButton or event is InputEventKey:
			get_viewport().set_input_as_handled()
		return
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
	intro_clock += delta / maxf(0.01, Engine.time_scale)
	if is_instance_valid(mission):
		_update_dialogue_triggers()
	queue_redraw()

func display(value: String, at: Vector2, size_px: int = 16, color: Color = INK) -> void:
	draw_string(display_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)

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
	elif screen_mode == "cutscene":
		_draw_hud()
		# Letterbox bars mark that play is frozen while characters speak.
		draw_rect(Rect2(0, 0, 640, 48), Color(0, 0, 0, 0.9))
		draw_rect(Rect2(0, 330, 640, 30), Color(0, 0, 0, 0.9))
		label("Esc  Skip", Vector2(574, 349), 9, MUTED)
	elif screen_mode == "title":
		_draw_title()
	elif screen_mode == "intro":
		_draw_intro()
	elif screen_mode == "help":
		_draw_help()
	elif screen_mode == "pause":
		draw_rect(Rect2(0, 0, 640, 360), Color(0.025, 0.03, 0.065, 0.88))
		spaced("TIME HOLDS ITS BREATH", Vector2(214, 87), 9, CYAN)
		display("Paused", Vector2(232, 136), 48)
		label("The manor waits. So do its blades.", Vector2(213, 297), 11, MUTED)
	else:
		_draw_results()

func _draw_intro() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0.012, 0.012, 0.03, 1))
	if intro_index >= dialogue.intro.size():
		return
	var alpha := clampf(intro_clock / 0.6, 0.0, 1.0)
	var text: String = dialogue.intro[intro_index]
	var block := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, 440, 13)
	draw_multiline_string(font, Vector2(100, 180 - block.y * 0.5 + 10), text, HORIZONTAL_ALIGNMENT_CENTER, 440, 13, -1, Color(0.85, 0.82, 0.95, alpha))
	for index in range(dialogue.intro.size()):
		draw_circle(Vector2(304 + index * 16, 318), 2.5, VIOLET if index == intro_index else Color("3b3450"))
	label("Click / Space to continue   -   Esc to skip", Vector2(392, 348), 9, Color(0.42, 0.42, 0.55))

func _draw_title() -> void:
	# Lighter veil than before so the manor shows through behind the menu.
	draw_rect(Rect2(0, 0, 640, 360), Color(0.025, 0.03, 0.065, 0.74))
	draw_rect(Rect2(0, 0, 380, 360), Color(0.02, 0.022, 0.05, 0.55))
	draw_rect(Rect2(40, 54, 3, 19), VIOLET)
	spaced("BLACKGLASS MANOR / MIDNIGHT", Vector2(54, 67), 9, CYAN, 1.7)
	display("SHADOW", Vector2(37, 140), 48)
	var logo_x := 37.0 + display_font.get_string_size("SHADOW", HORIZONTAL_ALIGNMENT_LEFT, -1, 48).x + 4.0
	display("SHIFT", Vector2(logo_x, 140), 48, VIOLET)
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
		var feedback_y := 248.0 if dialogue.is_speaking() else 305.0
		draw_rect(Rect2(16, feedback_y, 490, 21), Color(0.04, 0.035, 0.09, 0.85))
		label(mission.shadow_system.feedback, Vector2(24, feedback_y + 14), 10, CYAN)
	_draw_minimap()
	if mission.player.current_anchor == mission.anchors[Data.START_ANCHOR] and not mission.entered_hall:
		draw_rect(Rect2(18, 61, 322, 66), Color(0.035, 0.04, 0.085, 0.94))
		draw_rect(Rect2(18, 61, 2, 66), VIOLET)
		spaced("01 / LEARN TO DISAPPEAR", Vector2(29, 79), 9, VIOLET, 1)
		label("Hold SHIFT and click the hedge's shadow.", Vector2(29, 99), 11)
		label("Then ride the groundskeeper when his shadow comes near.", Vector2(29, 117), 10, MUTED)

func _draw_minimap() -> void:
	# Uniform scale so rooms keep their shape; the map is taller now the wing extends south.
	var origin := Vector2(545, 225)
	var scale_map := Vector2.ONE * (78.0 / Data.BOUNDS.y)
	draw_rect(Rect2(530, 205, 104, 124), Color(0.025, 0.035, 0.065, 0.88))
	spaced("MANOR", Vector2(541, 218), 8, MUTED, 1)
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
	if mission.enemies["oswald"].is_alive():
		draw_circle(origin + mission.enemies["oswald"].global_position * scale_map, 1.7, Color("e88694"))
	label("%02d:%02d   %d / %d" % [floori(mission.elapsed / 60), int(mission.elapsed) % 60, mission.guards_killed, mission.guard_total()], Vector2(540, 320), 9, MUTED)

func _draw_help() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0.025, 0.03, 0.065, 0.97))
	spaced("THE RULES OF THE DARK", Vector2(40, 43), 9, CYAN)
	display("Move Like a Shadow", Vector2(40, 80), 32)
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
	label("Guards are routes. A body or a witness starts Oswald's escape.", Vector2(40, 283), 11, MUTED)

func _draw_results() -> void:
	var success := screen_mode == "won"
	draw_rect(Rect2(0, 0, 640, 360), Color(0.025, 0.03, 0.065, 0.93))
	spaced("TARGET ELIMINATED" if success else "THE DARK LET GO", Vector2(80, 58), 10, CYAN if success else Color("ef8e89"))
	display(mission.rank if success else "One Hit. One End.", Vector2(78, 110), 32, INK if success else Color("f2c3c6"))
	label("No shadow could hold him." if success else mission.failure_reason, Vector2(80, 135), 12, MUTED)
	draw_line(Vector2(80, 155), Vector2(528, 155), Color("483855"), 1)
	var metrics := [
		["MISSION TIME", "%02d:%05.2f" % [floori(mission.elapsed / 60), fmod(mission.elapsed, 60.0)]],
		["GUARDS KILLED", "%d / %d" % [mission.guards_killed, mission.guard_total()]],
		["BODIES FOUND", str(mission.alarm.bodies_found)],
		["RESTARTS", str(mission.stats.restarts)]
	]
	for index in range(metrics.size()):
		var point := Vector2(80 + (index % 2) * 232, 184 + floori(float(index) / 2) * 45)
		spaced(metrics[index][0], point, 8, MUTED, 1)
		label(metrics[index][1], point + Vector2(0, 23), 20, CYAN if success else Color("dc9eb0"))
	if success and mission.stats.best_times.has(mission.rank):
		label("PERSONAL BEST  %.2f s" % mission.stats.best_times[mission.rank], Vector2(80, 271), 9, VIOLET)
