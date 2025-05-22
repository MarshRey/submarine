# world_generator.gd  – Godot 4.4.1
extends TileMapLayer
#
#  Tile IDs (in your TileSet):
#     0  wall  (has collision)
#     1  floor (no collision)
#
# ------------------------------------------------------------
@export var level_length_seconds : int = 300   # 5 min
@export var est_avg_speed_px     : int = 280   # tweak later
@export var cell_px              : int = 32
@export var width_cells          : int = 64 
@export var height_cells         : int = 128 

@export var branch_walks   : int = 6
@export var smooth_steps   : int = 3          # cave-smoothing passes

# -------- monster clusters ----------------------------------
@export var max_monsters     : int = 25
@export var cluster_attempts : int = 5
@export var cluster_radius   : int = 20        # cells

#  List of { scene : PackedScene,  weight : float }
@export var monster_types : Array[Dictionary] = [
	{ "scene": preload("res://world/enemy.tscn"), "weight": 5.0 },
	# { "scene": preload("res://world/enemy_tough.tscn"), "weight": 1.0 },
]

# ------------------------------------------------------------
var grid : PackedInt32Array
var rng  : RandomNumberGenerator

# ------------------------------------------------------------
func _ready() -> void:
	width_cells = int(ceil(est_avg_speed_px * level_length_seconds / cell_px))
	rng = RandomNumberGenerator.new()
	rng.randomize()

	_generate_level()
	print_debug("Level generated")
	_bake_to_tilemap()
	print_debug("Tilemap baked")
	_spawn_monster_clusters()
	print_debug("Monster clusters spawned")

# ====================  CAVE GENERATION  =====================
func _generate_level() -> void:
	grid = PackedInt32Array()
	grid.resize(width_cells * height_cells)
	grid.fill(0)                                   # start all wall

	# --- main drunken walk (left ➜ right) -------------------
	var x := 0
	var y := rng.randi_range(0, height_cells - 1)
	while x < width_cells - 1:
		_dig(x, y, 5)                              # radius-3 corridor
		match rng.randi_range(0, 9):
			0,1,2,3,4,5: x += 1                    # 60 % go right
			6,7:        y = clamp(y - 1, 0, height_cells - 1)
			_:           y = clamp(y + 1, 0, height_cells - 1)
	print_debug("Drunken walk finished at ", x, ", ", y)
	# --- extra branchy walks -------------------------------
	for _i in range(branch_walks):
		var cell := _pick_random_floor()
		var bx := cell.x
		var by := cell.y
		var length := rng.randi_range(12, 24)
		for _j in range(length):
			_dig(bx, by, 2)
			match rng.randi_range(0, 3):
				0: bx = clamp(bx + 1, 0, width_cells - 1)
				1: bx = clamp(bx - 1, 0, width_cells - 1)
				2: by = clamp(by + 1, 0, height_cells - 1)
				_: by = clamp(by - 1, 0, height_cells - 1)
		print_debug("Branch walk finished at ", bx, ", ", by)
	# --- cellular smoothing passes -------------------------
	for _i in range(smooth_steps):
		_cellular_step()
	print_debug("Cellular smoothing finished")
	# --- ensure clear start / finish ---------------------------------
	# pick a y far enough from top/bottom
	var start_y := rng.randi_range(10, height_cells - 7)
	var cavern_radius := 20                         # 6 tiles ≈ 192 px

	# centre of cavern sits (radius+1, start_y) so it’s fully inside
	var cavern_center := Vector2i(cavern_radius + 1, start_y)

	# carve the circle
	for local_y in range(-cavern_radius, cavern_radius + 1):
		for local_x in range(-cavern_radius, cavern_radius + 1):
			if Vector2(local_x, local_y).length() <= cavern_radius:
				var cx := cavern_center.x + local_x
				var cy := cavern_center.y + local_y
				if cx >= 0 and cy >= 0 and cx < width_cells and cy < height_cells:
					grid[cy * width_cells + cx] = 1        # floor
	print_debug("Cavern centre at ", cavern_center.x, ", ", cavern_center.y)
	# --- move the submarine -----------------------------------------
	var sub := get_node("/root/Main/Submarine")
	if sub:
		var tile_center := Vector2i(cavern_center)              
		var world_pos   := to_global( map_to_local( tile_center ) )
		world_pos += Vector2(cell_px * 0.5, cell_px * 0.5)   # centre of the tile
		sub.global_position = world_pos
		print("Submarine moved to ", sub.global_position)

# ------------------------------------------------------------
func _dig(cx:int, cy:int, r:int) -> void:
	for yy in range(cy - r, cy + r + 1):
		for xx in range(cx - r, cx + r + 1):
			if xx < 0 or yy < 0 or xx >= width_cells or yy >= height_cells:
				continue
			grid[yy * width_cells + xx] = 1

func _cellular_step() -> void:
	var new_grid := grid.duplicate()
	for y in range(height_cells):
		for x in range(width_cells):
			var walls := _count_wall_neighbours(x, y)
			var idx   := y * width_cells + x
			if walls >= 5:
				new_grid[idx] = 0      # wall
			else:
				new_grid[idx] = 1      # floor
	grid = new_grid

func _count_wall_neighbours(x:int, y:int) -> int:
	var c := 0
	for ny in range(y - 1, y + 2):
		for nx in range(x - 1, x + 2):
			if nx == x and ny == y:
				continue
			if nx < 0 or ny < 0 or nx >= width_cells or ny >= height_cells:
				c += 1
			elif grid[ny * width_cells + nx] == 0:
				c += 1
	return c

# ====================  TILEMAP BAKING  ======================
func _bake_to_tilemap() -> void:
	clear()
	tile_set.tile_size = Vector2i(cell_px, cell_px)

	for y in range(height_cells):
		for x in range(width_cells):
			var source_id := grid[y * width_cells + x]      # 0 wall, 1 floor
			 # Every single-tile source uses atlas (0,0)
			set_cell(
				Vector2i(x, y),         # coords in the map
				source_id,              # source entry (0 or 1)
				Vector2i.ZERO           # atlas-coords inside that entry
			)
	_pad_outer_frame(2)

# ====================  MONSTER CLUSTERS  ====================
func _spawn_monster_clusters() -> void:
	var spawned := 0
	for _i in range(cluster_attempts):
		if spawned >= max_monsters:
			break
		var centre := _pick_random_floor()

		var members := rng.randi_range(3, 6)
		for _j in range(members):
			if spawned >= max_monsters:
				break
			var off := Vector2(
				rng.randf_range(-cluster_radius, cluster_radius),
				rng.randf_range(-cluster_radius, cluster_radius)
			).round()
			var cell := centre + Vector2i(off)
			if not _is_floor(cell):
				continue

			var scene := _pick_monster_scene()
			var m := scene.instantiate()
			m.position = (Vector2(cell) + Vector2(0.5, 0.5)) * cell_px
			add_child(m)
			spawned += 1

func _pick_monster_scene() -> PackedScene:
	var total := 0.0
	for t in monster_types:
		total += float(t.weight)
	var r := rng.randf() * total
	for t in monster_types:
		r -= float(t.weight)
		if r <= 0.0:
			return t.scene
	return monster_types.back().scene    # fallback

# ====================  FLOOR HELPERS  =======================
func _pick_random_floor() -> Vector2i:
	for _i in range(1000):
		var x := rng.randi_range(0, width_cells - 1)
		var y := rng.randi_range(0, height_cells - 1)
		if grid[y * width_cells + x] == 1:
			print("picked random floor at ", x, ", ", y)
			return Vector2i(x, y)
	return Vector2i(width_cells / 2, height_cells / 2)

func _is_floor(c: Vector2i) -> bool:
	return (
		c.x >= 0 and c.y >= 0 and
		c.x < width_cells and c.y < height_cells and
		grid[c.y * width_cells + c.x] == 1
	)

func _pad_outer_frame(frame:int = 2) -> void:
	# draw solid-wall ring 'frame' tiles thick around map
	for y in range(-frame, height_cells + frame):
		for x in range(-frame, width_cells + frame):
			# skip interior we've already filled
			if x >= 0 and y >= 0 and x < width_cells and y < height_cells:
				continue
			set_cell(Vector2i(x, y), 0, Vector2i.ZERO)   # wall tile-id 0
