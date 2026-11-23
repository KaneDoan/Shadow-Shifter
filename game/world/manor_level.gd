extends Node2D

const Data = preload("res://world/level_data.gd")
var floor_cells: Dictionary = {}
var wall_cells: Dictionary = {}
var floor_layer: TileMapLayer
var wall_layer: TileMapLayer
var lights_off := false

func build(_mission: Node) -> void:
	for room in Data.ROOMS:
		_add_floor(room["rect"])
	for corridor in Data.CORRIDORS:
		_add_floor(corridor)
	for cell in floor_cells.keys():
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i(-1, -1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(1, 1)]:
			var neighbor: Vector2i = cell + offset
			if not floor_cells.has(neighbor):
				wall_cells[neighbor] = true
	_build_tiles()
	_build_collisions()
	queue_redraw()

func _add_floor(rectangle: Rect2) -> void:
	for y in range(int(rectangle.position.y / 32), int(rectangle.end.y / 32)):
		for x in range(int(rectangle.position.x / 32), int(rectangle.end.x / 32)):
			floor_cells[Vector2i(x, y)] = true

func _build_tiles() -> void:
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(16, 16)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = load("res://assets/environment/walls_floor.png")
	atlas.texture_region_size = Vector2i(16, 16)
	for tile in [Vector2i(0, 9), Vector2i(1, 9), Vector2i(4, 1), Vector2i(5, 1)]:
		atlas.create_tile(tile)
	tiles.add_source(atlas, 0)
	floor_layer = TileMapLayer.new()
	floor_layer.tile_set = tiles
	floor_layer.scale = Vector2(2, 2)
	floor_layer.z_index = -30
	floor_layer.modulate = Color(0.48, 0.54, 0.68)
	add_child(floor_layer)
	for cell in floor_cells:
		floor_layer.set_cell(cell, 0, Vector2i(0, 9) if (cell.x + cell.y * 3) % 7 else Vector2i(1, 9))
	wall_layer = TileMapLayer.new()
	wall_layer.tile_set = tiles
	wall_layer.scale = Vector2(2, 2)
	wall_layer.z_index = -5
	wall_layer.modulate = Color(0.62, 0.67, 0.82)
	add_child(wall_layer)
	for cell in wall_cells:
		wall_layer.set_cell(cell, 0, Vector2i(4 + (cell.x + cell.y) % 2, 1))

func _build_collisions() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	for y in range(-1, 27):
		var x := -1
		while x < 39:
			if not wall_cells.has(Vector2i(x, y)):
				x += 1
				continue
			var start := x
			while wall_cells.has(Vector2i(x, y)):
				x += 1
			var shape := CollisionShape2D.new()
			var rectangle := RectangleShape2D.new()
			rectangle.size = Vector2((x - start) * 32, 32)
			shape.shape = rectangle
			shape.position = Vector2((start + x) * 16, y * 32 + 16)
			body.add_child(shape)

func zone_name(point: Vector2) -> String:
	for room in Data.ROOMS:
		if room["rect"].has_point(point):
			return room["name"]
	return "BLACKGLASS MANOR"

func has_walk_route(from_pos: Vector2, to_pos: Vector2) -> bool:
	var start := Vector2i(floori(from_pos.x / 32), floori(from_pos.y / 32))
	var goal := Vector2i(floori(to_pos.x / 32), floori(to_pos.y / 32))
	var queue: Array[Vector2i] = [start]
	var visited: Dictionary = {start: true}
	var index := 0
	while index < queue.size():
		var current := queue[index]
		index += 1
		if current == goal:
			return true
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor: Vector2i = current + offset
			if floor_cells.has(neighbor) and not visited.has(neighbor):
				visited[neighbor] = true
				queue.append(neighbor)
	return false

func _draw() -> void:
	for room in Data.ROOMS:
		var rectangle: Rect2 = room["rect"]
		draw_rect(rectangle.grow(-7), Color(0.35, 0.4, 0.56, 0.15), false, 1.0)
		draw_string(ThemeDB.fallback_font, rectangle.position + Vector2(14, 24), room["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.55, 0.61, 0.78, 0.5))
	# The manor's authored landmarks provide visual context for the shadow graph.
	draw_circle(Vector2(96, 718), 17, Color("252a3b"))
	draw_arc(Vector2(96, 718), 17, 0, TAU, 24, Color("68718b"), 4)
	draw_circle(Vector2(96, 718), 10, Color("090f20"))
	for at in [Vector2(160, 700), Vector2(184, 700)]:
		draw_rect(Rect2(at - Vector2(10, 10), Vector2(20, 20)), Color("4b3c43"))
		draw_rect(Rect2(at - Vector2(10, 10), Vector2(20, 20)).grow(-2), Color("8b6d68"), false, 1)
		draw_line(at - Vector2(8, 8), at + Vector2(8, 8), Color("705665"), 1)
	for at in [Vector2(448, 602), Vector2(512, 554)]:
		draw_rect(Rect2(at - Vector2(9, 16), Vector2(18, 28)), Color("42475c"))
		draw_rect(Rect2(at - Vector2(12, -9), Vector2(24, 6)), Color("697187"))
		draw_circle(at - Vector2(0, 17), 8, Color("73758b"))
	draw_rect(Rect2(584, 552, 48, 10), Color("604957"))
	draw_rect(Rect2(576, 106, 32, 18), Color("4a3e56"))
	draw_rect(Rect2(581, 108, 22, 14), Color("796375"), false, 1)
	draw_rect(Rect2(948, 306, 24, 38), Color("4b2f50") if not lights_off else Color("34223e"))
	for x in [951, 957, 963, 969]:
		draw_line(Vector2(x, 308), Vector2(x, 342), Color("865174"), 1)
	draw_rect(Rect2(976, 264, 64, 24), Color("563f4e"))
	draw_rect(Rect2(980, 268, 56, 14), Color("956c70"))
	draw_rect(Rect2(984, 269, 12, 10), Color("b8b2ad"))
	draw_circle(Data.SWITCH, 8, Color("dcaf6c") if not lights_off else Color("7db6c9"))
	draw_line(Data.SWITCH, Data.SWITCH + Vector2(0, -7 if not lights_off else 7), Color("e5dfce"), 3)
	draw_rect(Rect2(1120, 384, 16, 64), Color(0.7, 0.2, 0.3, 0.18))
