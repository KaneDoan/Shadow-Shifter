extends RefCounted

var active := false
var remaining := 0.0
var progress := 0.0
var bodies_found := 0
var discovered: Dictionary = {}

func start() -> void:
	if active:
		return
	active = true
	remaining = 90.0
	progress = 0.0

func discover_body(body_id: int) -> bool:
	if discovered.has(body_id):
		return false
	discovered[body_id] = true
	bodies_found += 1
	start()
	if bodies_found >= 2:
		remaining = minf(remaining, 45.0)
	return true

func tick(delta: float) -> void:
	if not active or remaining <= 0.0:
		return
	var step := minf(maxf(delta, 0.0), remaining)
	progress = minf(1.0, progress + (1.0 - progress) * step / remaining)
	remaining = maxf(0.0, remaining - step)

func reset() -> void:
	active = false
	remaining = 0.0
	progress = 0.0
	bodies_found = 0
	discovered.clear()
