extends Node2D

var role := "assassin"
var facing := Vector2.DOWN
var moving := false
var attacking := false
var dead := false
var accent := Color("b28aff")
var clock := 0.0
var animation_key := ""
var sheets: Dictionary = {}
var sprite: Sprite2D

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for direction in ["D", "S", "U"]:
		for animation in ["idle", "walk", "attack", "hurt", "death"]:
			var key: String = direction + "_" + animation
			sheets[key] = load("res://assets/characters/%s/%s.png" % [role, key])
	sprite = Sprite2D.new()
	sprite.hframes = 4
	sprite.position = Vector2(0, -10)
	add_child(sprite)

func _process(delta: float) -> void:
	var direction := "S"
	if absf(facing.y) > absf(facing.x) * 0.85:
		direction = "D" if facing.y >= 0.0 else "U"
	var animation := "death" if dead else ("attack" if attacking else ("walk" if moving else "idle"))
	var key: String = direction + "_" + animation
	if key != animation_key:
		animation_key = key
		clock = 0.0
	clock += delta
	sprite.texture = sheets[key]
	sprite.flip_h = direction == "S" and facing.x < 0.0
	var fps := 10.0 if moving else 5.0
	if attacking:
		fps = 12.5
	sprite.frame = mini(3, int(clock * 7.0)) if dead else int(clock * fps) % 4
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 8.0, Color(0.015, 0.02, 0.04, 0.7))
	draw_set_transform(Vector2.ZERO)
	if not dead:
		draw_circle(Vector2(0, 3), 1.5, accent)
