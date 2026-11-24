extends Control
## Subtitle-style dialogue: one speaker line at a time in a bar above the prompt strip.
## Lines come from data/dialogue.json, type out, hold for a reading time, then advance.
## It never pauses play or takes input, because clicks in this game mean shift/strike.

const DATA_PATH := "res://data/dialogue.json"
const BAR := Rect2(16, 276, 500, 50)
const CHARS_PER_SECOND := 48.0

var display_font: Font
var body_font: Font
var lines: Dictionary = {}
var intro: Array = []
var speakers: Dictionary = {}
var names: Dictionary = {}
var played: Dictionary = {}
var queue: Array = []
var current: Array = []
var shown := 0.0
var hold := 0.0
var can_advance: Callable = func(): return true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body_font = ThemeDB.fallback_font
	var data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if data is Dictionary:
		lines = data.get("lines", {})
		intro = data.get("intro", [])
		names = data.get("names", {})
		for name in data.get("speakers", {}):
			speakers[name] = Color(String(data["speakers"][name]))

## Queues the conversation with this id once per run. Urgent ones replace what is playing.
func play(id: String, urgent: bool = false) -> bool:
	if played.has(id) or not lines.has(id):
		return false
	played[id] = true
	if urgent:
		queue.clear()
		current = []
	for line in lines[id]:
		queue.append(line)
	if current.is_empty():
		_next()
	return true

func is_speaking() -> bool:
	return not current.is_empty()

func _next() -> void:
	current = queue.pop_front() if not queue.is_empty() else []
	shown = 0.0
	if not current.is_empty():
		hold = 1.1 + String(current[1]).length() * 0.045
	queue_redraw()

func _process(delta: float) -> void:
	if current.is_empty():
		return
	# Redraw even while held, so the bar disappears behind menus instead of lingering.
	queue_redraw()
	if get_tree().paused or not can_advance.call():
		return
	var step := delta / maxf(0.01, Engine.time_scale)
	var length := String(current[1]).length()
	if shown < length:
		shown = minf(length, shown + step * CHARS_PER_SECOND)
	else:
		hold -= step
		if hold <= 0.0:
			_next()
	queue_redraw()

func _draw() -> void:
	if current.is_empty() or not can_advance.call():
		return
	var speaker := String(current[0])
	var color: Color = speakers.get(speaker, Color("e9e4f6"))
	draw_rect(BAR, Color(0.02, 0.022, 0.05, 0.92))
	draw_rect(Rect2(BAR.position, Vector2(2, BAR.size.y)), color)
	draw_line(BAR.position + Vector2(2, 0), BAR.position + Vector2(BAR.size.x, 0), Color(0.35, 0.3, 0.45, 0.6), 1)
	draw_string(display_font if display_font else body_font, BAR.position + Vector2(12, 18), String(names.get(speaker, speaker.capitalize())), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
	var text := String(current[1]).substr(0, int(shown))
	draw_multiline_string(body_font, BAR.position + Vector2(12, 34), text, HORIZONTAL_ALIGNMENT_LEFT, BAR.size.x - 24, 11, 2, Color("e9e4f6"))
