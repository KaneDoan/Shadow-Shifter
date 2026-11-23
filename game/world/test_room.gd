extends Node2D

var carrier: Node2D
var door
var clock := 0.0

func _ready() -> void:
	var system = preload("res://systems/shadow_system.gd").new()
	add_child(system)
	var player = preload("res://actors/player.gd").new()
	player.position = Vector2(100, 180)
	player.shadow_system = system
	system.player = player
	add_child(player)
	for point in [Vector2(100, 180), Vector2(180, 180), Vector2(405, 180), Vector2(500, 180)]:
		var anchor = preload("res://world/shadow_anchor.gd").new()
		anchor.position = point
		add_child(anchor)
		system.register_anchor(anchor)
	for rectangle in [Rect2(0, 0, 640, 24), Rect2(0, 336, 640, 24), Rect2(0, 0, 24, 360), Rect2(616, 0, 24, 360), Rect2(310, 24, 20, 124), Rect2(310, 212, 20, 124)]:
		var wall := StaticBody2D.new()
		wall.position = rectangle.get_center()
		wall.collision_layer = 1
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = rectangle.size
		collision.shape = shape
		wall.add_child(collision)
		add_child(wall)
	door = preload("res://world/door.gd").new()
	door.position = Vector2(320, 180)
	add_child(door)
	carrier = Node2D.new()
	carrier.position = Vector2(230, 180)
	add_child(carrier)
	var visual = preload("res://actors/actor_visual.gd").new()
	visual.role = "guard"
	visual.moving = true
	visual.facing = Vector2.RIGHT
	carrier.add_child(visual)
	var moving = preload("res://world/shadow_anchor.gd").new()
	moving.owner_actor = carrier
	moving.position = Vector2(0, 8)
	carrier.add_child(moving)
	system.register_anchor(moving)
	player.attach_anchor(system.anchors[0])
	queue_redraw()

func _physics_process(delta: float) -> void:
	clock += delta
	carrier.position.x = 320.0 - cos(clock * 0.5) * 100.0
	if absf(carrier.position.x - 320.0) < 55.0:
		door.open_for(2.0)

func _draw() -> void:
	draw_rect(Rect2(24, 24, 592, 312), Color("1c2030"))
	for x in range(32, 616, 32):
		for y in range(32, 328, 32):
			draw_rect(Rect2(x, y, 31, 31), Color("25293b"))
	draw_rect(Rect2(310, 24, 20, 124), Color("4a475e"))
	draw_rect(Rect2(310, 212, 20, 124), Color("4a475e"))
	draw_string(ThemeDB.fallback_font, Vector2(36, 52), "SHADOWSHIFT  /  SHADOW LAB", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("e3d8ff"))
	draw_string(ThemeDB.fallback_font, Vector2(36, 308), "SHIFT + CLICK  travel    E  emerge    WASD  move    R  restart", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("a1a6bf"))
