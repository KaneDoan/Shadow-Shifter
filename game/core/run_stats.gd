extends Node

var restarts := 0
var has_started := false
var best_times: Dictionary = {}
var save_path := "user://shadowshift_progress.cfg"

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--suite="):
			save_path = ""
	if save_path.is_empty():
		return
	var file := ConfigFile.new()
	if file.load(save_path) == OK:
		for rank in file.get_section_keys("best"):
			best_times[rank] = float(file.get_value("best", rank))

func record_result(rank: String, seconds: float) -> void:
	if not best_times.has(rank) or seconds < float(best_times[rank]):
		best_times[rank] = seconds
	if save_path.is_empty():
		return
	var file := ConfigFile.new()
	for key in best_times:
		file.set_value("best", key, best_times[key])
	file.save(save_path)
