## ====================================================================
##  tile_map_layer.gd  •  Godot 4.4.1
##
##  Generates a 2-minute, vertical-zig-zagging cave with:
##    • irregular start / end caverns
##    • 3-tile solid border (never see default background)
##    • tall shafts (≥ 3 cells wide, ~10 s climb)
##    • 1–2 optional branching tunnels that reconnect
##    • 1–2 dead-end tunnels, 75 % chance to contain “loot”
##
##  Collision: Tile-ID 0 = wall (collision rect in TileSet)
##             Tile-ID 1 = water / empty floor (no collision)
##
## ====================================================================

extends TileMapLayer

# --------------------------------------------------------------------
# ░░░  P A R A M E T E R S  ░░░  (tweak in Inspector)  ░░░
# --------------------------------------------------------------------
@export_group("Timing & scale")
@export var target_run_seconds : float = 120.0       # ≈2-minute run
@export var est_avg_speed_px   : int   = 280         # px/s (cruise)

@export_group("Grid resolution")
@export var cell_px            : int   = 24          # tile size in pixels
@export var height_cells       : int   = 128          # vertical span
@export var border_thickness   : int   = 3           # outer rock frame

@export_group("Main tunnel shaping")
@export var main_radius_min    : int   = 4           # floor radius 4-6
@export var main_radius_max    : int   = 6
@export var vertical_bias_up   : int   = 30          # ↑ % (0-100)
@export var vertical_bias_dn   : int   = 30          # ↓ %
@export var main_smooth_steps  : int   = 4           # cellular passes

@export_group("Branches")
@export var reconnect_branches : int   = 2           # optional paths
@export var deadend_branches   : int   = 2
@export var branch_radius_min  : int   = 2
@export var branch_radius_max  : int   = 3
@export_range(0.0,1.0,0.05) var loot_chance        : float = 0.75        # dead-end special

@export_group("Monsters")
@export var max_monsters       : int   = 25
@export var monster_cluster_radius : int = 5
@export var monster_types : Array[Dictionary] = [
	{ "scene": preload("res://world/enemy.tscn"), "weight": 5.0 },
	# { "scene": preload("res://world/enemy_tough.tscn"), "weight": 1.0 },
]

# --------------------------------------------------------------------
# internal fields ----------------------------------------------------
var width_cells : int
var grid        : PackedInt32Array
var rng         : RandomNumberGenerator
@onready var noise := FastNoiseLite.new()

# ====================================================================
func _ready() -> void:
	_compute_width()
	_init_rng()
	_generate_level()        # takes < 2 s desktop / ~3 s mobile
	_bake_to_tilemap()
	_spawn_monsters()
	_place_submarine()

# --------------------------------------------------------------------
func _compute_width() -> void:
	width_cells = int(ceil(est_avg_speed_px * target_run_seconds / cell_px))
	# keep at least 3× taller than wide tunnels
	width_cells = max(width_cells, height_cells * 3)

func _init_rng() -> void:
	rng = RandomNumberGenerator.new()
	rng.randomize()
	noise.seed = rng.randi()
	noise.frequency = 0.06

# =========================  GENERATE  ===============================
func _generate_level() -> void:
	grid = PackedInt32Array()
	grid.resize(width_cells * height_cells)
	grid.fill(0)

	_carve_main_tunnel()
	_carve_branches(reconnect_branches, false)
	_carve_branches(deadend_branches, true)
	for _i in main_smooth_steps:
		_cellular_step()

	_dig_rough_cavern(_start_center(), 20)
	_dig_rough_cavern(_end_center(),   20)

# ---------------- main drunk-walk ----------------------------------
func _pick_random_floor() -> Vector2i:
	for _attempt in 1000:
		var x : int = rng.randi_range(0, width_cells  - 1)
		var y : int = rng.randi_range(0, height_cells - 1)
		if grid[y * width_cells + x] == 1:
			return Vector2i(x, y)
	return Vector2i(width_cells / 2, height_cells / 2)  # fail-safe

func _carve_main_tunnel() -> void:
	var x := 0
	var y := rng.randi_range(height_cells/3, height_cells*2/3)
	while x < width_cells - 1:
		var r := rng.randi_range(main_radius_min, main_radius_max)
		_dig(x, y, r)

		var roll := rng.randi_range(0, 99)
		if roll < 50:                # always some rightward motion
			x += 1
		elif roll < 50 + vertical_bias_up:
			y = clamp(y - 1, 0, height_cells - 1)
		elif roll < 50 + vertical_bias_up + vertical_bias_dn:
			y = clamp(y + 1, 0, height_cells - 1)
		else:
			x += 2                   # occasional 2-step forward

# ---------------- branches -----------------------------------------
func _carve_branches(count:int, dead_end:bool) -> void:
	for _b in count:
		var src := _pick_random_floor()
		var bx  := src.x
		var by  := src.y
		var length := rng.randi_range(width_cells/8, width_cells/6)
		for _step in length:
			var br := rng.randi_range(branch_radius_min, branch_radius_max)
			_dig(bx, by, br)
			match rng.randi_range(0,3):
				0: bx = clamp(bx + 1, 0, width_cells - 1)
				1: bx = clamp(bx - 1, 0, width_cells - 1)
				2: by = clamp(by + 1, 0, height_cells - 1)
				_: by = clamp(by - 1, 0, height_cells - 1)
		if dead_end and rng.randf() < loot_chance:
			_mark_loot_spot(Vector2i(bx, by))

# ---------------- helpers ------------------------------------------
func _start_center() -> Vector2i:
	return Vector2i(20 + border_thickness, height_cells/2)

func _end_center() -> Vector2i:
	return Vector2i(width_cells - (20 + border_thickness), height_cells/2)

func _dig_rough_cavern(c:Vector2i, radius:int) -> void:
	for y in range(-radius, radius+1):
		for x in range(-radius, radius+1):
			if Vector2(x,y).length() <= radius and rng.randf() > 0.18:
				_dig(c.x + x, c.y + y, 0)

func _dig(cx:int, cy:int, r:int) -> void:
	for yy in range(cy-r, cy+r+1):
		for xx in range(cx-r, cx+r+1):
			if xx<0 or yy<0 or xx>=width_cells or yy>=height_cells:
				continue
			grid[yy*width_cells+xx] = 1

func _cellular_step() -> void:
	var newg := grid.duplicate()
	for y in range(height_cells):
		for x in range(width_cells):
			var walls := _count_wall_neigh(x,y)
			var idx := y*width_cells+x
			if walls >= 5:
				newg[idx] = 0     # wall
			else:
				newg[idx] = 1     # floor
	grid = newg

func _count_wall_neigh(x:int,y:int) -> int:
	var c := 0
	for ny in range(y-1,y+2):
		for nx in range(x-1,x+2):
			if nx==x and ny==y: continue
			if nx<0 or ny<0 or nx>=width_cells or ny>=height_cells: c+=1
			elif grid[ny*width_cells+nx]==0: c+=1
	return c

func _mark_loot_spot(cell:Vector2i) -> void:
	# placeholder – later you can instance a pickup here
	grid[cell.y*width_cells+cell.x] = 2   # tile ID 2 reserved for loot

# =======================  TILEMAP BAKE  =============================
func _bake_to_tilemap() -> void:
	clear()
	tile_set.tile_size = Vector2i(cell_px, cell_px)

	for y in range(height_cells):
		for x in range(width_cells):
			var id : int = min(grid[y * width_cells + x], 1)   # 0/1
			set_cell(Vector2i(x, y), id, Vector2i.ZERO)
	_pad_outer_frame(border_thickness)

func _pad_outer_frame(f:int) -> void:
	for y in range(-f, height_cells+f):
		for x in range(-f, width_cells+f):
			if x>=0 and y>=0 and x<width_cells and y<height_cells:
				continue
			set_cell(Vector2i(x,y), 0, Vector2i.ZERO)

# =======================  MONSTER SPAWN  ============================
func _spawn_monsters() -> void:
	var floor_cells : Array[Vector2i] = []
	for y in range(height_cells):
		for x in range(width_cells):
			if grid[y*width_cells + x] == 1:
				floor_cells.append(Vector2i(x,y))
	floor_cells.shuffle()

	var spawned := 0
	for centre in floor_cells:
		if spawned >= max_monsters:
			break
		if rng.randf() > 0.02:
			continue
		var members := rng.randi_range(3,6)
		for _i in members:
			if spawned >= max_monsters:
				break
			var off := Vector2i(
				rng.randi_range(-monster_cluster_radius, monster_cluster_radius),
				rng.randi_range(-monster_cluster_radius, monster_cluster_radius))
			var cell := centre + off
			if not _is_floor(cell):
				continue
			_instance_monster(cell)
			spawned += 1

func _pick_monster_scene() -> PackedScene:
	var tot := 0.0
	for t in monster_types: tot += float(t.weight)
	var r := rng.randf() * tot
	for t in monster_types:
		r -= float(t.weight)
		if r <= 0: return t.scene
	return monster_types.back().scene

func _instance_monster(cell:Vector2i) -> void:
	var m := _pick_monster_scene().instantiate()
	m.position = (Vector2(cell)+Vector2(0.5,0.5))*cell_px
	add_child(m)

func _is_floor(c:Vector2i) -> bool:
	return (
		c.x>=0 and c.y>=0 and c.x<width_cells and c.y<height_cells and
		grid[c.y*width_cells+c.x] == 1)

# =======================  SUBMARINE SPAWN  ==========================
func _place_submarine() -> void:
	var sub := get_node_or_null("/root/Main/Submarine")
	if sub:
		var world := map_to_local(_start_center()) + Vector2(cell_px*0.5, cell_px*0.5)
		sub.global_position = to_global(world)
