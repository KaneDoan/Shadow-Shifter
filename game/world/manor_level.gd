extends Node2D

const Data = preload("res://world/level_data.gd")
# Gameplay runs on a 32 px cell grid; manor art is 16 px tiles drawn 1:1, so each cell is 2x2 tiles.
const CELL := 32
const TILE := 16
const NIGHT_FLOOR := Color(0.58, 0.6, 0.78)
const NIGHT_WALL := Color(0.66, 0.66, 0.84)
const NIGHT_PROP := Color(0.78, 0.76, 0.92)
const WALL_TOP := Color("29232f")
const WALL_TRIM := Color("b9a785")
const FLOOR_TILES := {
	"stone": [Vector2i(8, 25)],
	"marble": [Vector2i(9, 24)],
	"parquet": [Vector2i(0, 25), Vector2i(1, 25), Vector2i(2, 25), Vector2i(0, 26), Vector2i(1, 26), Vector2i(2, 26)]
}
const ROOM_FLOORS := {"courtyard": "stone", "gallery": "marble", "alcove": "parquet", "study": "parquet", "hall": "parquet", "garden": "stone"}
const GRID := Vector2i(int(Data.BOUNDS.x / CELL), int(Data.BOUNDS.y / CELL))

var floor_cells: Dictionary = {}
var wall_cells: Dictionary = {}
var floor_layer: TileMapLayer
var wall_art: Node2D
var lights_off := false
var walls_texture: Texture2D = preload("res://assets/environment/manor/walls_floor.png")
var interior_texture: Texture2D = preload("res://assets/environment/manor/interior_objects.png")
var exterior_texture: Texture2D = preload("res://assets/environment/manor/exterior.png")
var fountain_texture: Texture2D = preload("res://assets/environment/manor/fountain.png")
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
	navigation.region = Rect2i(Vector2i.ZERO, GRID)
	navigation.cell_size = Vector2(32, 32)
	navigation.offset = Vector2(16, 16)
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	navigation.update()
	for y in range(GRID.y):
		for x in range(GRID.x):
			navigation.set_point_solid(Vector2i(x, y), not floor_cells.has(Vector2i(x, y)))
	queue_redraw()

func _add_floor(rectangle: Rect2) -> void:
	for y in range(int(rectangle.position.y / 32), int(rectangle.end.y / 32)):
		for x in range(int(rectangle.position.x / 32), int(rectangle.end.x / 32)):
			floor_cells[Vector2i(x, y)] = true

func _floor_kind(cell: Vector2i) -> String:
	var center := Vector2(cell) * CELL + Vector2(CELL, CELL) * 0.5
	for room in Data.ROOMS:
		if room["rect"].has_point(center):
			return ROOM_FLOORS.get(room["id"], "stone")
	return "stone"

func _build_tiles() -> void:
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(TILE, TILE)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = walls_texture
	atlas.texture_region_size = Vector2i(TILE, TILE)
	for kind in FLOOR_TILES:
		for tile in FLOOR_TILES[kind]:
			if not atlas.has_tile(tile):
				atlas.create_tile(tile)
	# The pale marble is far brighter than the rest of the palette; dim it so guards
	# and vision cones stay the most readable things in the gallery.
	atlas.get_tile_data(FLOOR_TILES["marble"][0], 0).modulate = Color(0.52, 0.52, 0.62)
	tiles.add_source(atlas, 0)
	floor_layer = TileMapLayer.new()
	floor_layer.tile_set = tiles
	floor_layer.z_index = -30
	floor_layer.modulate = NIGHT_FLOOR
	add_child(floor_layer)
	for cell in floor_cells:
		var choices: Array = FLOOR_TILES[_floor_kind(cell)]
		for dy in range(2):
			for dx in range(2):
				var tile_cell := Vector2i(cell.x * 2 + dx, cell.y * 2 + dy)
				var tile: Vector2i = choices[0]
				if choices.size() == 6:
					# Parquet is a 3x2 pattern; index it by tile position so planks line up.
					tile = choices[posmod(tile_cell.y, 2) * 3 + posmod(tile_cell.x, 3)]
				floor_layer.set_cell(tile_cell, 0, tile)
	wall_art = Node2D.new()
	wall_art.z_index = -5
	wall_art.modulate = NIGHT_WALL
	wall_art.draw.connect(_draw_walls)
	add_child(wall_art)
	wall_art.queue_redraw()

func _build_collisions() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	for y in range(-1, GRID.y + 2):
		var x := -1
		while x < GRID.x + 2:
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

func _draw_walls() -> void:
	# Pass 1: dark wall tops with a cream lip wherever a wall meets the floor.
	for cell in wall_cells:
		var at: Vector2 = Vector2(cell) * CELL
		wall_art.draw_rect(Rect2(at, Vector2(CELL, CELL)), WALL_TOP)
		if floor_cells.has(cell + Vector2i.LEFT):
			wall_art.draw_rect(Rect2(at, Vector2(3, CELL)), WALL_TRIM)
		if floor_cells.has(cell + Vector2i.RIGHT):
			wall_art.draw_rect(Rect2(at + Vector2(CELL - 3, 0), Vector2(3, CELL)), WALL_TRIM)
		if floor_cells.has(cell + Vector2i.UP):
			wall_art.draw_rect(Rect2(at, Vector2(CELL, 3)), WALL_TRIM)
	# Pass 2: brick-and-window faces on walls that look down onto a floor. The 48 px face
	# is bottom-aligned to the wall cell and overlaps the top half of the cell above.
	for cell in wall_cells:
		if not floor_cells.has(cell + Vector2i.DOWN):
			continue
		var at: Vector2 = Vector2(cell) * CELL
		var source_x := float(posmod(cell.x * CELL, 160))
		wall_art.draw_texture_rect_region(walls_texture, Rect2(at + Vector2(0, CELL - 48), Vector2(CELL, 48)), Rect2(source_x, 160, CELL, 48))

func _prop(texture: Texture2D, region: Rect2, feet: Vector2, tint: Color = NIGHT_PROP) -> void:
	# Places a prop so the bottom-centre of its region sits on the given point.
	draw_texture_rect_region(texture, Rect2(feet - Vector2(region.size.x * 0.5, region.size.y), region.size), region, tint)

func _draw() -> void:
	# Kitchen garden vegetable beds, kept south of the groundskeeper's path.
	for y in [1088, 1120, 1152]:
		draw_rect(Rect2(768, y, 192, 14), Color(0.17, 0.12, 0.09, 0.9))
		for x in range(776, 960, 16):
			draw_circle(Vector2(x, y + 5), 4, Color(0.22, 0.36, 0.2, 0.85))
	for rug in [Rect2(480, 320, 96, 400), Rect2(864, 224, 160, 256), Rect2(320, 992, 224, 48)]:
		draw_rect(rug, Color(0.36, 0.1, 0.14, 0.82))
		draw_rect(rug.grow(-3), Color(0.72, 0.56, 0.36, 0.7), false, 1)
		draw_rect(rug.grow(-7), Color(0.5, 0.16, 0.2, 0.8), false, 1)
	for room in Data.ROOMS:
		var rectangle: Rect2 = room["rect"]
		draw_string(ThemeDB.fallback_font, rectangle.position + Vector2(14, 24), room["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.86, 0.8, 0.66, 0.55))
	# Courtyard greenery, kept clear of the patrol line and anchors.
	_prop(exterior_texture, Rect2(176, 450, 61, 76), Vector2(80, 540))
	_prop(exterior_texture, Rect2(244, 455, 39, 49), Vector2(320, 760))
	for at in [Vector2(56, 600), Vector2(248, 760), Vector2(328, 470)]:
		_prop(exterior_texture, Rect2(167, 322, 18, 24), at)
	# Kitchen garden trees and shrubs.
	_prop(exterior_texture, Rect2(176, 450, 61, 76), Vector2(752, 920))
	_prop(exterior_texture, Rect2(176, 450, 61, 76), Vector2(1112, 1176))
	for at in [Vector2(712, 1176), Vector2(1000, 872), Vector2(1040, 1176)]:
		_prop(exterior_texture, Rect2(167, 322, 18, 24), at)
	# Shadow-anchor landmarks: the art matches each anchor's label.
	_prop(interior_texture, Rect2(592, 181, 28, 47), Vector2(1104, 888))         # Handcart: crates
	_prop(exterior_texture, Rect2(244, 455, 39, 49), Vector2(1056, 968))         # Hedge
	_prop(interior_texture, Rect2(592, 181, 28, 47), Vector2(688, 968))           # Woodpile
	_prop(interior_texture, Rect2(72, 14, 47, 58), Vector2(580, 958))             # Larder: shelves
	_prop(interior_texture, Rect2(309, 145, 53, 33), Vector2(264, 944))           # Table
	for step in range(4):
		draw_rect(Rect2(232, 834 + step * 6, 48, 4), Color(0.3, 0.24, 0.2, 0.9 - step * 0.15))  # Back stairs
	_prop(fountain_texture, Rect2(8, 1, 81, 79), Vector2(96, 752))                 # Well
	_prop(interior_texture, Rect2(592, 181, 28, 47), Vector2(176, 736))           # Crates
	_prop(interior_texture, Rect2(596, 12, 15, 56), Vector2(448, 630))            # Pillar: suit of armour
	_prop(exterior_texture, Rect2(195, 193, 67, 51), Vector2(512, 588))           # Statue: gargoyle
	_prop(exterior_texture, Rect2(4, 356, 57, 39), Vector2(608, 584))             # Bench
	_prop(interior_texture, Rect2(72, 14, 47, 58), Vector2(592, 134))             # Cupboard: bookshelf
	_prop(interior_texture, Rect2(309, 145, 53, 33), Vector2(1008, 290))          # Oswald's desk
	_prop(interior_texture, Rect2(7, 146, 40, 37), Vector2(1056, 300))
	_prop(interior_texture, Rect2(8, 14, 47, 58), Vector2(880, 220))
	# Study curtain: heavy velvet by the moonlit window; it darkens with the lamp out.
	var velvet := Color("6b1f2c") if not lights_off else Color("3a1626")
	draw_rect(Rect2(946, 302, 28, 44), velvet)
	draw_rect(Rect2(942, 298, 36, 4), Color("c8a46a"))
	for x in [951, 957, 963, 969]:
		draw_line(Vector2(x, 304), Vector2(x, 344), velvet.darkened(0.35), 1)
	# Candelabra stands and vases replace the dungeon torches and urns.
	for at in [Vector2(64, 1056), Vector2(576, 1056), Vector2(304, 720), Vector2(416, 704), Vector2(736, 704), Vector2(416, 112), Vector2(848, 480), Vector2(1056, 480)]:
		_prop(interior_texture, Rect2(166, 248, 19, 30), at + Vector2(0, 14))
	for at in [Vector2(432, 360), Vector2(704, 360), Vector2(848, 224), Vector2(160, 840), Vector2(416, 840)]:
		_prop(interior_texture, Rect2(4, 195, 18, 35), at + Vector2(16, 32))
	# Chandelier switch.
	draw_circle(Data.SWITCH, 8, Color("dcaf6c") if not lights_off else Color("7db6c9"))
	draw_line(Data.SWITCH, Data.SWITCH + Vector2(0, -7 if not lights_off else 7), Color("e5dfce"), 3)
	draw_rect(Rect2(1120, 384, 16, 64), Color(0.7, 0.2, 0.3, 0.18))
