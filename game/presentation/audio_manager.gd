extends Node

var enabled := true
var muted := false
var streams: Dictionary = {}
var ambience: AudioStreamPlayer

func _ready() -> void:
	muted = AudioServer.is_bus_mute(0)
	if not enabled:
		return
	for name in ["slash", "shift", "impact", "death", "switch", "door", "key", "alarm", "win", "ambience"]:
		streams[name] = load("res://assets/audio/%s.wav" % name)
	ambience = AudioStreamPlayer.new()
	var pad: AudioStreamWAV = streams["ambience"]
	pad.loop_mode = AudioStreamWAV.LOOP_FORWARD
	pad.loop_begin = 0
	pad.loop_end = int(pad.get_length() * pad.mix_rate)
	ambience.stream = pad
	ambience.volume_db = -23.0
	add_child(ambience)
	ambience.play()

func play(name: String, volume: float = -11.0) -> void:
	if not enabled or not streams.has(name):
		return
	var voice := AudioStreamPlayer.new()
	voice.stream = streams[name]
	voice.volume_db = volume
	add_child(voice)
	voice.finished.connect(voice.queue_free)
	voice.play()

func toggle_mute() -> void:
	muted = not AudioServer.is_bus_mute(0)
	AudioServer.set_bus_mute(0, muted)
