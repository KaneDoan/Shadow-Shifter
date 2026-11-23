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
