extends Node2D

const Data = preload("res://world/level_data.gd")
var floor_cells: Dictionary = {}
var wall_cells: Dictionary = {}
var floor_layer: TileMapLayer
var wall_layer: TileMapLayer
var lights_off := false
var objects_texture: Texture2D = preload("res://assets/environment/objects.png")
var navigation := AStarGrid2D.new()

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
	navigation.region = Rect2i(0, 0, 37, 25)
	navigation.cell_size = Vector2(32, 32)
	navigation.offset = Vector2(16, 16)
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	navigation.update()
	for y in range(25):
		for x in range(37):
			navigation.set_point_solid(Vector2i(x, y), not floor_cells.has(Vector2i(x, y)))
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
	for tile in [Vector2i(1, 10), Vector2i(4, 1), Vector2i(5, 1)]:
		atlas.create_tile(tile)
	tiles.add_source(atlas, 0)
	floor_layer = TileMapLayer.new()
	floor_layer.tile_set = tiles
	floor_layer.scale = Vector2(2, 2)
	floor_layer.z_index = -30
	floor_layer.modulate = Color(0.48, 0.54, 0.68)
	add_child(floor_layer)
	for cell in floor_cells:
		floor_layer.set_cell(cell, 0, Vector2i(1, 10))
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

func navigation_target(from_pos: Vector2, target: Vector2) -> Vector2:
	var start := Vector2i(floori(from_pos.x / 32), floori(from_pos.y / 32))
	var goal := Vector2i(floori(target.x / 32), floori(target.y / 32))
	if not floor_cells.has(start) or not floor_cells.has(goal):
		return target
	var path := navigation.get_point_path(start, goal)
	if path.size() > 1:
		return path[1]
	return target

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
	# Solid atlas center tiles plus quiet stone joints; edge tiles have alpha.
	for cell in floor_cells:
		var at: Vector2 = Vector2(cell) * 32.0
		draw_rect(Rect2(at + Vector2(1, 1), Vector2(30, 30)), Color(0.09, 0.12, 0.19, 0.34), false, 1.0)
		if (cell.x * 13 + cell.y * 7) % 9 == 0:
			draw_line(at + Vector2(9, 19), at + Vector2(14, 21), Color(0.5, 0.55, 0.67, 0.13), 1)
	for rug in [Rect2(480, 320, 96, 400), Rect2(864, 224, 160, 256)]:
		draw_rect(rug, Color(0.24, 0.13, 0.25, 0.75))
		draw_rect(rug.grow(-3), Color(0.54, 0.39, 0.4, 0.65), false, 1)
		draw_rect(rug.grow(-7), Color(0.43, 0.27, 0.34, 0.7), false, 1)
	for room in Data.ROOMS:
		var rectangle: Rect2 = room["rect"]
		draw_rect(rectangle.grow(-7), Color(0.35, 0.4, 0.56, 0.15), false, 1.0)
		draw_string(ThemeDB.fallback_font, rectangle.position + Vector2(14, 24), room["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.55, 0.61, 0.78, 0.5))
	# The manor's authored landmarks provide visual context for the shadow graph.
	draw_circle(Vector2(96, 718), 17, Color("252a3b"))
	draw_arc(Vector2(96, 718), 17, 0, TAU, 24, Color("68718b"), 4)
	draw_circle(Vector2(96, 718), 10, Color("090f20"))
	draw_texture_rect_region(objects_texture, Rect2(144, 656, 64, 64), Rect2(256, 0, 32, 32), Color(0.85, 0.8, 0.9))
	for at in [Vector2(448, 602), Vector2(512, 554)]:
		_draw_statue(at)
	draw_rect(Rect2(584, 548, 48, 14), Color("604957"))
	draw_rect(Rect2(584, 547, 48, 3), Color("95717c"))
	draw_line(Vector2(588, 555), Vector2(628, 555), Color("3a3042"), 1)
	for x in [588, 624]:
		draw_rect(Rect2(x, 561, 4, 5), Color("30293b"))
	draw_texture_rect_region(objects_texture, Rect2(576, 56, 32, 64), Rect2(48, 64, 16, 32), Color(0.9, 0.8, 0.95))
	draw_rect(Rect2(948, 306, 24, 38), Color("4b2f50") if not lights_off else Color("34223e"))
	draw_rect(Rect2(944, 303, 32, 3), Color("b39073"))
	for x in [951, 957, 963, 969]:
		draw_line(Vector2(x, 308), Vector2(x, 342), Color("865174"), 1)
	draw_rect(Rect2(976, 264, 64, 24), Color("563f4e"))
	draw_rect(Rect2(980, 268, 56, 14), Color("956c70"))
	draw_rect(Rect2(984, 269, 12, 10), Color("b8b2ad"))
	draw_line(Vector2(986, 271), Vector2(993, 272), Color("69657c"), 1)
	draw_line(Vector2(986, 274), Vector2(991, 275), Color("69657c"), 1)
	draw_rect(Rect2(1025, 270, 5, 6), Color("2d2840"))
	for at in [Vector2(304, 720), Vector2(416, 704), Vector2(736, 704), Vector2(416, 112), Vector2(848, 480), Vector2(1056, 480)]:
		draw_texture_rect_region(objects_texture, Rect2(at - Vector2(16, 48), Vector2(32, 64)), Rect2(96, 64, 16, 32), Color(0.72, 0.75, 0.9))
	for at in [Vector2(432, 360), Vector2(704, 360), Vector2(848, 224)]:
		draw_texture_rect_region(objects_texture, Rect2(at, Vector2(32, 32)), Rect2(128, 0, 16, 16), Color(0.8, 0.82, 0.95))
	draw_circle(Data.SWITCH, 8, Color("dcaf6c") if not lights_off else Color("7db6c9"))
	draw_line(Data.SWITCH, Data.SWITCH + Vector2(0, -7 if not lights_off else 7), Color("e5dfce"), 3)
	draw_rect(Rect2(1120, 384, 16, 64), Color(0.7, 0.2, 0.3, 0.18))

func _draw_statue(at: Vector2) -> void:
	draw_rect(Rect2(at + Vector2(-13, 8), Vector2(26, 7)), Color("333c52"))
	draw_rect(Rect2(at + Vector2(-11, 7), Vector2(22, 3)), Color("7c859f"))
	draw_rect(Rect2(at + Vector2(-8, -17), Vector2(16, 25)), Color("545f7a"))
	draw_rect(Rect2(at + Vector2(-10, -18), Vector2(20, 6)), Color("6b7690"))
	draw_rect(Rect2(at + Vector2(-6, -31), Vector2(12, 14)), Color("74809a"))
	draw_rect(Rect2(at + Vector2(2, -29), Vector2(4, 11)), Color("525e79"))
	for x in [-6, -1, 4]:
		draw_rect(Rect2(at + Vector2(x, -35), Vector2(3, 5)), Color("9297ac"))
	draw_rect(Rect2(at + Vector2(-6, -23), Vector2(9, 2)), Color("344056"))
	draw_rect(Rect2(at + Vector2(-1, -12), Vector2(2, 13)), Color("abb4c6"))
	draw_rect(Rect2(at + Vector2(-4, -4), Vector2(8, 2)), Color("a0a4b8"))
