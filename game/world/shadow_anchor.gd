extends Node2D

signal invalidated

var anchor_id := "shadow"
var active := true
var owner_actor
var highlighted := false
var hovered := false
var outlines_visible := false
var occupied := false
var clock := 0.0

func _ready() -> void:
	add_to_group("shadow_anchors")
	z_index = -1
	var area := Area2D.new()
	area.collision_layer = 8
	area.collision_mask = 0
	area.input_pickable = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 15.0
	shape.shape = circle
	area.add_child(shape)
	add_child(area)

func set_active(value: bool) -> void:
	if active == value:
		return
	active = value
	if not active:
		invalidated.emit()
	queue_redraw()

func _process(delta: float) -> void:
	clock += delta
	queue_redraw()

func _draw() -> void:
	if not active and not outlines_visible:
		return
	var tint := Color("8a5de8") if active else Color("5c5970")
	if not active:
		tint.a = 0.45
	var pulse := 0.9 + sin(clock * 3.0) * 0.1
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
	if active:
		draw_circle(Vector2.ZERO, 16.0, Color(0.27, 0.12, 0.47, 0.24))
		draw_circle(Vector2.ZERO, 12.0, Color(0.13, 0.065, 0.22, 0.9))
	draw_arc(Vector2.ZERO, 13.0 * pulse, 0.0, TAU, 32, tint, 1.0)
	if highlighted or occupied:
		draw_arc(Vector2.ZERO, 17.0, 0.0, TAU, 32, Color("d3a5ff") if not occupied else Color("75f5ee"), 1.5)
	if hovered:
		draw_arc(Vector2.ZERO, 21.0, 0.0, TAU, 32, Color("f5d9ff"), 1.0)
	draw_set_transform(Vector2.ZERO)
	if occupied:
		draw_circle(Vector2(0, -2), 2.0, Color("c3fffa"))
