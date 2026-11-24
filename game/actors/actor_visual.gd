extends Node2D

var role := "assassin"
var facing := Vector2.DOWN
var moving := false
var attacking := false
var dead := false
var accent := Color("b28aff")
var tint := Color.WHITE
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
	# 64 px frames drawn 1:1 with the 16 px manor tiles; feet sit 13 px below frame centre.
	sprite.position = Vector2(0, -10)
	sprite.modulate = tint
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
	var texture: Texture2D = sheets[key]
	if sprite.texture != texture:
		sprite.texture = texture
		# Sheets are horizontal strips of square frames with 2, 4, 6 or 8 frames.
		sprite.hframes = maxi(1, texture.get_width() / texture.get_height())
		sprite.frame = 0
	sprite.flip_h = direction == "S" and facing.x < 0.0
	var count := sprite.hframes
	# Fixed loop durations keep timing stable whatever the frame count of a sheet.
	var fps := 10.0 if moving else float(count) / 1.4
	if attacking:
		fps = float(count) / 0.32
	if dead:
		sprite.frame = mini(count - 1, int(clock * float(count) / 0.6))
	else:
		sprite.frame = int(clock * fps) % count
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 8.0, Color(0.015, 0.02, 0.04, 0.7))
	draw_set_transform(Vector2.ZERO)
	if not dead:
		draw_circle(Vector2(0, 3), 1.5, accent)
